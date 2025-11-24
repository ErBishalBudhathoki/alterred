import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/chat_message.dart';
import 'dart:math';
import 'dart:convert';

final baseUrlProvider = Provider<String>((ref) => const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000'));
final tokenProvider = StateProvider<String?>((ref) => null);
final localeProvider = StateProvider<Locale?>((ref) => null);
final savedLocaleProvider = FutureProvider<Locale?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString('locale_code');
  if (code == null) return null;
  final parts = code.split('_');
  return parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
});
final apiClientProvider = Provider<ApiClient>((ref) {
  final base = ref.watch(baseUrlProvider);
  final tok = ref.watch(tokenProvider);
  return ApiClient(baseUrl: base, token: tok);
});

final chatSessionIdProvider = StateProvider<String?>((ref) => null);

final ensureChatSessionIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('chat_session_id');
  if (id == null || id.isEmpty) {
    final rnd = Random();
    final ts = DateTime.now().millisecondsSinceEpoch;
    // Avoid JS bitwise pitfalls and nextInt(0) by using a safe literal < 2^32
    final salt = rnd.nextInt(0xFFFFFFFF).toRadixString(16);
    id = 'adk-' + ts.toString() + '-' + salt;
    await prefs.setString('chat_session_id', id);
  }
  ref.read(chatSessionIdProvider.notifier).state = id;
  return id;
});

class ContextMemory {
  Future<List<Map<String, dynamic>>> _loadRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_history');
    if (raw == null || raw.isEmpty) return [];
    return List<Map<String, dynamic>>.from((jsonDecode(raw) as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map)));
  }

  Future<void> _saveRaw(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_history', jsonEncode(list));
  }

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

  Future<void> add(ChatMessage m, {int maxItems = 200}) async {
    final list = await _loadRaw();
    list.add({
      'role': m.role,
      'content': m.content,
      'time': m.time.toIso8601String()
    });
    if (list.length > maxItems) {
      final drop = list.length - maxItems;
      list.removeRange(0, drop);
    }
    await _saveRaw(list);
    await _updateHighlights(m);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_history');
    await prefs.remove('chat_highlights');
  }

  Future<List<ChatMessage>> retrieve(String query, {int window = 12}) async {
    final all = await loadAll();
    if (query.trim().isEmpty) {
      return all.length <= window ? all : all.sublist(all.length - window);
    }
    final q = query.toLowerCase();
    final scored = <ChatMessage, int>{};
    for (final m in all) {
      final c = m.content.toLowerCase();
      var s = 0;
      for (final w in q.split(RegExp(r"\s+"))) {
        if (w.isEmpty) continue;
        if (c.contains(w)) s += 1;
      }
      if (s > 0) scored[m] = s;
    }
    final top = scored.keys.toList()
      ..sort((a, b) => scored[b]!.compareTo(scored[a]!));
    final base = all.length <= window ? all : all.sublist(all.length - window);
    final merged = <ChatMessage>[]..addAll(base);
    for (final m in top) {
      if (!merged.contains(m)) merged.add(m);
      if (merged.length >= window * 2) break;
    }
    return merged;
  }

  Future<void> _updateHighlights(ChatMessage m) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_highlights');
    final list = raw == null || raw.isEmpty
        ? <String>[]
        : List<String>.from(
            (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()));
    final c = m.content.trim();
    if (m.role == 'assistant') {
      if (RegExp(
              r"\b(timer set|schedule created|energy match|external brain|today's events)\b",
              caseSensitive: false)
          .hasMatch(c)) {
        list.add(c.length > 160 ? c.substring(0, 160) : c);
      }
    }
    if (list.length > 40) {
      final drop = list.length - 40;
      list.removeRange(0, drop);
    }
    await prefs.setString('chat_highlights', jsonEncode(list));
  }
}

final contextMemoryProvider = Provider<ContextMemory>((ref) => ContextMemory());
