import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;

/// User preferences model for cross-platform settings sync.
///
/// Implementation Details:
/// - Stores all user-configurable settings (pulse visuals, toggles, locale).
/// - Provides serialization methods for Firestore and SharedPreferences.
///
/// Design Decisions:
/// - Nullable colors allow for "use default" state.
/// - All settings have sensible defaults.
class UserSettings {
  final int pulseSpeedMs;
  final int pulseThresholdPercent;
  final double pulseMaxFreq;
  final int? pulseBaseColor;
  final int? pulseAlertColor;
  final bool googleSearchEnabled;
  final bool firestoreSyncEnabled;
  final String? localeCode;

  UserSettings({
    this.pulseSpeedMs = 900,
    this.pulseThresholdPercent = 20,
    this.pulseMaxFreq = 3.0,
    this.pulseBaseColor,
    this.pulseAlertColor,
    this.googleSearchEnabled = false,
    this.firestoreSyncEnabled = false,
    this.localeCode,
  });

  /// Converts settings to a map for Firestore storage.
  Map<String, dynamic> toMap() => {
        'pulse_speed_ms': pulseSpeedMs,
        'pulse_threshold_percent': pulseThresholdPercent,
        'pulse_max_freq': pulseMaxFreq,
        'pulse_base_color': pulseBaseColor,
        'pulse_alert_color': pulseAlertColor,
        'google_search_enabled': googleSearchEnabled,
        'firestore_sync_enabled': firestoreSyncEnabled,
        'locale_code': localeCode,
        'updated_at': DateTime.now().toIso8601String(),
      };

  /// Creates settings from a Firestore map.
  static UserSettings fromMap(Map<String, dynamic> map) => UserSettings(
        pulseSpeedMs: (map['pulse_speed_ms'] as num?)?.toInt() ?? 900,
        pulseThresholdPercent:
            (map['pulse_threshold_percent'] as num?)?.toInt() ?? 20,
        pulseMaxFreq: (map['pulse_max_freq'] as num?)?.toDouble() ?? 3.0,
        pulseBaseColor: map['pulse_base_color'] as int?,
        pulseAlertColor: map['pulse_alert_color'] as int?,
        googleSearchEnabled: map['google_search_enabled'] as bool? ?? false,
        firestoreSyncEnabled: map['firestore_sync_enabled'] as bool? ?? false,
        localeCode: map['locale_code'] as String?,
      );

  /// Creates a copy with updated fields.
  UserSettings copyWith({
    int? pulseSpeedMs,
    int? pulseThresholdPercent,
    double? pulseMaxFreq,
    int? pulseBaseColor,
    int? pulseAlertColor,
    bool? googleSearchEnabled,
    bool? firestoreSyncEnabled,
    String? localeCode,
  }) =>
      UserSettings(
        pulseSpeedMs: pulseSpeedMs ?? this.pulseSpeedMs,
        pulseThresholdPercent:
            pulseThresholdPercent ?? this.pulseThresholdPercent,
        pulseMaxFreq: pulseMaxFreq ?? this.pulseMaxFreq,
        pulseBaseColor: pulseBaseColor ?? this.pulseBaseColor,
        pulseAlertColor: pulseAlertColor ?? this.pulseAlertColor,
        googleSearchEnabled: googleSearchEnabled ?? this.googleSearchEnabled,
        firestoreSyncEnabled: firestoreSyncEnabled ?? this.firestoreSyncEnabled,
        localeCode: localeCode ?? this.localeCode,
      );
}

/// Manages user settings with local cache and Firestore sync.
///
/// Implementation Details:
/// - Dual-write: SharedPreferences (local) + Firestore (cloud).
/// - Real-time listener for cross-device sync.
/// - Follows the same pattern as ChatStore for consistency.
///
/// Design Decisions:
/// - Settings sync is optional and controlled by user preference.
/// - Local storage is the source of truth for offline capability.
/// - Cloud-first on initial load when user is authenticated.
///
/// Behavioral Specifications:
/// - [loadSettings]: Loads from cloud if available, else local.
/// - [saveSettings]: Saves to both local and cloud if sync enabled.
/// - [attachListener]: Sets up real-time sync from other devices.
/// - [migrateToCloud]: Uploads local settings to cloud (one-time migration).
class UserSettingsStore {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;

  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Loads settings from cloud (if authenticated) or local storage.
  ///
  /// Priority: Cloud > Local > Defaults
  Future<UserSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Try cloud first if user is logged in
    if (_uid != null) {
      try {
        final doc = await _fs
            .collection('users')
            .doc(_uid)
            .collection('settings')
            .doc('preferences')
            .get();

        if (doc.exists && doc.data() != null) {
          debugPrint('LoadSettings: Loaded from Firestore for uid=$_uid');
          final settings = UserSettings.fromMap(doc.data()!);
          // Cache locally
          await _saveToLocal(settings, prefs);
          return settings;
        }
      } catch (e) {
        debugPrint('LoadSettings: Firestore error: $e, falling back to local');
      }
    }

    // Fallback to local storage
    return UserSettings(
      pulseSpeedMs: prefs.getInt('pulse_speed_ms') ?? 900,
      pulseThresholdPercent: prefs.getInt('pulse_threshold_percent') ?? 20,
      pulseMaxFreq: prefs.getDouble('pulse_max_freq') ?? 3.0,
      pulseBaseColor: prefs.getInt('pulse_base_color'),
      pulseAlertColor: prefs.getInt('pulse_alert_color'),
      googleSearchEnabled: prefs.getBool('google_search_enabled') ?? false,
      firestoreSyncEnabled: prefs.getBool('firestore_sync_enabled') ?? false,
      localeCode: prefs.getString('locale_code'),
    );
  }

  /// Saves settings to local storage and Firestore (if sync enabled).
  Future<void> saveSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    // Always save locally
    await _saveToLocal(settings, prefs);

    // Save to cloud if sync enabled and user is authenticated
    if (settings.firestoreSyncEnabled && _uid != null) {
      try {
        await _fs
            .collection('users')
            .doc(_uid)
            .collection('settings')
            .doc('preferences')
            .set(settings.toMap(), SetOptions(merge: true));
        debugPrint('SaveSettings: Saved to Firestore for uid=$_uid');
      } catch (e) {
        debugPrint('SaveSettings: Firestore error: $e');
      }
    }
  }

  /// Saves settings to local SharedPreferences.
  Future<void> _saveToLocal(
      UserSettings settings, SharedPreferences prefs) async {
    await prefs.setInt('pulse_speed_ms', settings.pulseSpeedMs);
    await prefs.setInt('pulse_threshold_percent', settings.pulseThresholdPercent);
    await prefs.setDouble('pulse_max_freq', settings.pulseMaxFreq);
    if (settings.pulseBaseColor != null) {
      await prefs.setInt('pulse_base_color', settings.pulseBaseColor!);
    } else {
      await prefs.remove('pulse_base_color');
    }
    if (settings.pulseAlertColor != null) {
      await prefs.setInt('pulse_alert_color', settings.pulseAlertColor!);
    } else {
      await prefs.remove('pulse_alert_color');
    }
    await prefs.setBool('google_search_enabled', settings.googleSearchEnabled);
    await prefs.setBool('firestore_sync_enabled', settings.firestoreSyncEnabled);
    if (settings.localeCode != null) {
      await prefs.setString('locale_code', settings.localeCode!);
    } else {
      await prefs.remove('locale_code');
    }
  }

  /// Migrates local settings to Firestore (for existing users).
  ///
  /// Called when user enables sync for the first time.
  Future<void> migrateToCloud() async {
    if (_uid == null) return;

    try {
      // Check if cloud settings already exist
      final doc = await _fs
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('preferences')
          .get();

      if (!doc.exists) {
        // Upload local settings to cloud
        final settings = await loadSettings();
        await _fs
            .collection('users')
            .doc(_uid)
            .collection('settings')
            .doc('preferences')
            .set(settings.toMap());
        debugPrint('MigrateToCloud: Uploaded local settings for uid=$_uid');
      } else {
        debugPrint('MigrateToCloud: Cloud settings already exist for uid=$_uid');
      }
    } catch (e) {
      debugPrint('MigrateToCloud: Error: $e');
    }
  }

  /// Attaches a real-time listener for settings changes from other devices.
  Future<void> attachListener(Function(UserSettings) onUpdate) async {
    if (_uid == null) return;

    try {
      _settingsSub?.cancel();
      _settingsSub = _fs
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('preferences')
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists && snapshot.data() != null) {
          final settings = UserSettings.fromMap(snapshot.data()!);
          final prefs = await SharedPreferences.getInstance();
          await _saveToLocal(settings, prefs);
          onUpdate(settings);
          debugPrint('SettingsListener: Updated from Firestore for uid=$_uid');
        }
      }, onError: (e) {
        debugPrint('SettingsListener: Error: $e');
      });
    } catch (e) {
      debugPrint('AttachListener: Error: $e');
    }
  }

  /// Cancels the real-time listener.
  Future<void> disposeListener() async {
    await _settingsSub?.cancel();
    _settingsSub = null;
  }
}

/// Riverpod provider for UserSettingsStore.
final userSettingsStoreProvider = Provider<UserSettingsStore>((ref) => UserSettingsStore());

/// Riverpod provider for current user settings.
final userSettingsProvider = StateProvider<UserSettings>((ref) => UserSettings());
