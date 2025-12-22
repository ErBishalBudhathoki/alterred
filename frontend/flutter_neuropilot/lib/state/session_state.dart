import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/chat_message.dart';
import 'dart:math';
import 'dart:convert';
import '../services/location_service.dart';

/// Manages the state of the chat session, including context memory and user preferences.
///
/// Implementation Details:
/// - Uses Riverpod for state management (Providers, StateProviders, FutureProviders).
/// - Persists chat history and session ID to SecureStorage.
/// - Provides access to the [ApiClient] with the current base URL and auth token.
///
/// Design Decisions:
/// - ContextMemory is implemented as a separate class to encapsulate storage logic.
/// - Chat history is stored as a JSON string in SecureStorage.
/// - A random session ID is generated if one doesn't exist to track conversations.
///
/// Behavioral Specifications:
/// - [ensureChatSessionIdProvider]: Generates a new session ID if none exists.
/// - [ContextMemory]: Loads, saves, adds, clears, and retrieves chat messages.
/// - [retrieve]: Performs a simple keyword-based search on chat history.

final baseUrlProvider = Provider<String>((ref) => const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000'));
final tokenProvider = StateProvider<String?>((ref) => null);
final localeProvider = StateProvider<Locale?>((ref) => null);

/// Provider for SecureStorage to allow mocking and dependency injection.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

/// Loads the saved locale from SecureStorage.
final savedLocaleProvider = FutureProvider<Locale?>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final code = await storage.read(key: 'locale_code');
  if (code == null) return null;
  final parts = code.split('_');
  return parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
});

final locationServiceProvider = Provider((ref) => LocationService());

/// Provider to create a simple ApiClient for bootstrapping (no token/country needed).
final bootstrapApiClientProvider = Provider<ApiClient>((ref) {
  final base = ref.watch(baseUrlProvider);
  return ApiClient(baseUrl: base);
});

/// Holds the current country code (ISO 3166-1 alpha-2).
/// Defaults to null to avoid incorrect assumptions based on device locale (e.g. en_GB in Australia).
final countryCodeProvider = StateProvider<String?>((ref) => null);

/// Triggers location detection on startup.
final locationInitializerProvider = FutureProvider<void>((ref) async {
  final service = ref.read(locationServiceProvider);
  String? code;

  try {
    debugPrint(
        'Device Locale: ${ui.PlatformDispatcher.instance.locale.countryCode}');
  } catch (_) {}

  // Strategy: Explicitly check for permission/service availability first.
  // If available and granted, use GPS.
  // If NOT available or denied, use IP directly (not as a fallback error handler).

  bool useGps = await service.hasPermission();
  if (!useGps) {
    // If not already granted, try requesting once.
    // Note: Requesting permission might show a dialog.
    useGps = await service.requestPermission();
  }

  if (useGps) {
    try {
      code = await service.getCurrentCountryCode();
    } catch (e) {
      debugPrint('GPS Location failed despite permission: $e');
    }
  }

  // Fallback to IP if GPS failed or permission denied
  if (code == null) {
    try {
      final client = ref.read(bootstrapApiClientProvider);
      final geoData = await client.getGeoIp();

      if (geoData['country_code'] != null) {
        code = geoData['country_code'];
        debugPrint('Using IP geolocation: $code');
      }
    } catch (e) {
      debugPrint('IP geolocation failed: $e');
    }
  }

  if (code != null) {
    ref.read(countryCodeProvider.notifier).state = code;
  }
});

/// Provides an instance of [ApiClient] configured with the current base URL and token.
final apiClientProvider = Provider<ApiClient>((ref) {
  final base = ref.watch(baseUrlProvider);
  final tok = ref.watch(tokenProvider);
  final countryCode = ref.watch(countryCodeProvider);

  return ApiClient(baseUrl: base, token: tok, countryCode: countryCode);
});

final chatSessionIdProvider = StateProvider<String?>((ref) => null);

/// Ensures a chat session ID exists, generating one if necessary.
final ensureChatSessionIdProvider = FutureProvider<String>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  var id = await storage.read(key: 'chat_session_id');
  if (id == null || id.isEmpty) {
    final rnd = Random();
    final ts = DateTime.now().millisecondsSinceEpoch;
    // Avoid JS bitwise pitfalls and nextInt(0) by using a safe literal < 2^32
    final salt = rnd.nextInt(0xFFFFFFFF).toRadixString(16);
    id = 'adk-$ts-$salt';
    await storage.write(key: 'chat_session_id', value: id);
  }
  ref.read(chatSessionIdProvider.notifier).state = id;
  return id;
});

/// Manages local storage of chat messages and highlights.
class ContextMemory {
  final FlutterSecureStorage _storage;

  ContextMemory(this._storage);

  /// Loads raw message data from SecureStorage.
  Future<List<Map<String, dynamic>>> _loadRaw() async {
    final raw = await _storage.read(key: 'chat_history');
    if (raw == null || raw.isEmpty) return [];
    try {
      return List<Map<String, dynamic>>.from((jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      return [];
    }
  }

  /// Saves raw message data to SecureStorage.
  Future<void> _saveRaw(List<Map<String, dynamic>> list) async {
    await _storage.write(key: 'chat_history', value: jsonEncode(list));
  }

  /// Loads all chat messages as [ChatMessage] objects.
  Future<List<ChatMessage>> loadAll() async {
    final raw = await _loadRaw();
    return raw
        .map((e) => ChatMessage(
              role: (e['role'] as String?) ?? 'user',
              content: (e['content'] as String?) ?? '',
              time: DateTime.tryParse((e['time'] as String?) ?? '') ??
                  DateTime.now(),
            ))
        .toList();
  }

  /// Adds a message to history, maintaining a maximum size.
  Future<void> add(ChatMessage m, {int maxItems = 200}) async {
    final list = await _loadRaw();
    list.add({
      'role': m.role,
      'content': m.content,
      'time': m.time.toIso8601String(),
    });

    if (list.length > maxItems) {
      list.removeRange(0, list.length - maxItems);
    }
    await _saveRaw(list);
  }

  /// Clears chat history.
  Future<void> clear() async {
    await _storage.delete(key: 'chat_history');
  }

  /// Simple semantic search (keyword match) for demonstration.
  Future<List<ChatMessage>> retrieve(String query, {int limit = 5}) async {
    final all = await loadAll();
    final q = query.toLowerCase();
    final matches = all
        .where((m) => m.content.toLowerCase().contains(q))
        .take(limit)
        .toList();
    return matches;
  }
}

final contextMemoryProvider = Provider((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ContextMemory(storage);
});
