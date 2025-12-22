import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  final String? ttsVoice;
  final String? ttsQuality;
  final String sttProvider; // 'device' or 'cloud'
  final bool voiceLockDuringSession;
  final String characterStyle; // 'tech', 'street', 'space', 'mythic'

  // Notification Preferences
  final bool taskRemindersEnabled;
  final bool timeBlindnessEnabled;
  final bool energyAlertsEnabled;
  final bool decisionSupportEnabled;
  final bool bodyDoublingEnabled;
  final bool systemPushEnabled;

  UserSettings({
    this.pulseSpeedMs = 900,
    this.pulseThresholdPercent = 20,
    this.pulseMaxFreq = 3.0,
    this.pulseBaseColor,
    this.pulseAlertColor,
    this.googleSearchEnabled = false,
    this.firestoreSyncEnabled = true,
    this.localeCode,
    this.ttsVoice,
    this.ttsQuality,
    this.sttProvider = 'device',
    this.voiceLockDuringSession = true,
    this.characterStyle = 'tech',
    this.taskRemindersEnabled = true,
    this.timeBlindnessEnabled = true,
    this.energyAlertsEnabled = false,
    this.decisionSupportEnabled = true,
    this.bodyDoublingEnabled = false,
    this.systemPushEnabled = true,
  });

  Map<String, dynamic> toMap() => {
        'pulse_speed_ms': pulseSpeedMs,
        'pulse_threshold_percent': pulseThresholdPercent,
        'pulse_max_freq': pulseMaxFreq,
        'pulse_base_color': pulseBaseColor,
        'pulse_alert_color': pulseAlertColor,
        'google_search_enabled': googleSearchEnabled,
        'firestore_sync_enabled': firestoreSyncEnabled,
        'locale_code': localeCode,
        'tts_voice': ttsVoice,
        'tts_quality': ttsQuality,
        'stt_provider': sttProvider,
        'voice_lock': voiceLockDuringSession,
        'character_style': characterStyle,
        'task_reminders_enabled': taskRemindersEnabled,
        'time_blindness_enabled': timeBlindnessEnabled,
        'energy_alerts_enabled': energyAlertsEnabled,
        'decision_support_enabled': decisionSupportEnabled,
        'body_doubling_enabled': bodyDoublingEnabled,
        'system_push_enabled': systemPushEnabled,
        'updated_at': DateTime.now().toIso8601String(),
      };

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
        ttsVoice: map['tts_voice'] as String?,
        ttsQuality: map['tts_quality'] as String?,
        sttProvider: map['stt_provider'] as String? ?? 'device',
        voiceLockDuringSession: map['voice_lock'] as bool? ?? true,
        characterStyle: map['character_style'] as String? ?? 'tech',
        taskRemindersEnabled: map['task_reminders_enabled'] as bool? ?? true,
        timeBlindnessEnabled: map['time_blindness_enabled'] as bool? ?? true,
        energyAlertsEnabled: map['energy_alerts_enabled'] as bool? ?? false,
        decisionSupportEnabled:
            map['decision_support_enabled'] as bool? ?? true,
        bodyDoublingEnabled: map['body_doubling_enabled'] as bool? ?? false,
        systemPushEnabled: map['system_push_enabled'] as bool? ?? true,
      );

  UserSettings copyWith({
    int? pulseSpeedMs,
    int? pulseThresholdPercent,
    double? pulseMaxFreq,
    int? pulseBaseColor,
    int? pulseAlertColor,
    bool? googleSearchEnabled,
    bool? firestoreSyncEnabled,
    String? localeCode,
    String? ttsVoice,
    String? ttsQuality,
    String? sttProvider,
    bool? voiceLockDuringSession,
    String? characterStyle,
    bool? taskRemindersEnabled,
    bool? timeBlindnessEnabled,
    bool? energyAlertsEnabled,
    bool? decisionSupportEnabled,
    bool? bodyDoublingEnabled,
    bool? systemPushEnabled,
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
        ttsVoice: ttsVoice ?? this.ttsVoice,
        ttsQuality: ttsQuality ?? this.ttsQuality,
        sttProvider: sttProvider ?? this.sttProvider,
        voiceLockDuringSession:
            voiceLockDuringSession ?? this.voiceLockDuringSession,
        characterStyle: characterStyle ?? this.characterStyle,
        taskRemindersEnabled: taskRemindersEnabled ?? this.taskRemindersEnabled,
        timeBlindnessEnabled: timeBlindnessEnabled ?? this.timeBlindnessEnabled,
        energyAlertsEnabled: energyAlertsEnabled ?? this.energyAlertsEnabled,
        decisionSupportEnabled:
            decisionSupportEnabled ?? this.decisionSupportEnabled,
        bodyDoublingEnabled: bodyDoublingEnabled ?? this.bodyDoublingEnabled,
        systemPushEnabled: systemPushEnabled ?? this.systemPushEnabled,
      );
}

/// Manages user settings with secure local cache and Firestore sync.
class UserSettingsStore {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<UserSettings> loadSettings() async {
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
          await _saveToLocal(settings);
          return settings;
        }
      } catch (e) {
        debugPrint('LoadSettings: Firestore error: $e, falling back to local');
      }
    }

    // Fallback to local secure storage
    final all = await _storage.readAll();
    return UserSettings(
      pulseSpeedMs: int.tryParse(all['pulse_speed_ms'] ?? '') ?? 900,
      pulseThresholdPercent:
          int.tryParse(all['pulse_threshold_percent'] ?? '') ?? 20,
      pulseMaxFreq: double.tryParse(all['pulse_max_freq'] ?? '') ?? 3.0,
      pulseBaseColor: int.tryParse(all['pulse_base_color'] ?? ''),
      pulseAlertColor: int.tryParse(all['pulse_alert_color'] ?? ''),
      googleSearchEnabled: (all['google_search_enabled'] ?? 'false') == 'true',
      firestoreSyncEnabled:
          (all['firestore_sync_enabled'] ?? 'false') == 'true',
      localeCode: all['locale_code'],
      ttsVoice: all['tts_voice'],
      ttsQuality: all['tts_quality'],
      sttProvider: all['stt_provider'] ?? 'device',
      voiceLockDuringSession: (all['voice_lock'] ?? 'true') == 'true',
      characterStyle: all['character_style'] ?? 'tech',
      taskRemindersEnabled: (all['task_reminders_enabled'] ?? 'true') == 'true',
      timeBlindnessEnabled: (all['time_blindness_enabled'] ?? 'true') == 'true',
      energyAlertsEnabled: (all['energy_alerts_enabled'] ?? 'false') == 'true',
      decisionSupportEnabled:
          (all['decision_support_enabled'] ?? 'true') == 'true',
      bodyDoublingEnabled: (all['body_doubling_enabled'] ?? 'false') == 'true',
      systemPushEnabled: (all['system_push_enabled'] ?? 'true') == 'true',
    );
  }

  Future<void> saveSettings(UserSettings settings) async {
    await _saveToLocal(settings);

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

  Future<void> _saveToLocal(UserSettings s) async {
    await _storage.write(
        key: 'pulse_speed_ms', value: s.pulseSpeedMs.toString());
    await _storage.write(
        key: 'pulse_threshold_percent',
        value: s.pulseThresholdPercent.toString());
    await _storage.write(
        key: 'pulse_max_freq', value: s.pulseMaxFreq.toString());
    if (s.pulseBaseColor != null) {
      await _storage.write(
          key: 'pulse_base_color', value: s.pulseBaseColor.toString());
    }
    if (s.pulseAlertColor != null) {
      await _storage.write(
          key: 'pulse_alert_color', value: s.pulseAlertColor.toString());
    }
    await _storage.write(
        key: 'google_search_enabled', value: s.googleSearchEnabled.toString());
    await _storage.write(
        key: 'firestore_sync_enabled',
        value: s.firestoreSyncEnabled.toString());
    if (s.localeCode != null) {
      await _storage.write(key: 'locale_code', value: s.localeCode!);
    }
    if (s.ttsVoice != null) {
      await _storage.write(key: 'tts_voice', value: s.ttsVoice!);
    }
    if (s.ttsQuality != null) {
      await _storage.write(key: 'tts_quality', value: s.ttsQuality!);
    }
    await _storage.write(key: 'stt_provider', value: s.sttProvider);
    await _storage.write(
        key: 'voice_lock', value: s.voiceLockDuringSession.toString());
    await _storage.write(key: 'character_style', value: s.characterStyle);
    await _storage.write(
        key: 'task_reminders_enabled',
        value: s.taskRemindersEnabled.toString());
    await _storage.write(
        key: 'time_blindness_enabled',
        value: s.timeBlindnessEnabled.toString());
    await _storage.write(
        key: 'energy_alerts_enabled', value: s.energyAlertsEnabled.toString());
    await _storage.write(
        key: 'decision_support_enabled',
        value: s.decisionSupportEnabled.toString());
    await _storage.write(
        key: 'body_doubling_enabled', value: s.bodyDoublingEnabled.toString());
    await _storage.write(
        key: 'system_push_enabled', value: s.systemPushEnabled.toString());
  }

  void attachListener(Ref ref,
      StateNotifierProvider<UserSettingsNotifier, UserSettings> provider) {
    if (_uid == null) return;

    _settingsSub?.cancel();
    _settingsSub = _fs
        .collection('users')
        .doc(_uid)
        .collection('settings')
        .doc('preferences')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final remote = UserSettings.fromMap(doc.data()!);
        ref.read(provider.notifier).updateFromCloud(remote);
        _saveToLocal(remote);
      }
    });
  }

  void dispose() {
    _settingsSub?.cancel();
  }

  void disposeListener() => dispose();

  Future<void> migrateToCloud() async {
    if (_uid == null) return;
    final settings = await loadSettings();
    await saveSettings(settings.copyWith(firestoreSyncEnabled: true));
  }
}

class UserSettingsNotifier extends StateNotifier<UserSettings> {
  final UserSettingsStore _store;

  UserSettingsNotifier(this._store) : super(UserSettings()) {
    _load();
  }

  Future<void> _load() async {
    state = await _store.loadSettings();
  }

  Future<void> update(UserSettings Function(UserSettings) cb) async {
    final newState = cb(state);
    state = newState;
    await _store.saveSettings(newState);
  }

  void updateFromCloud(UserSettings remote) {
    state = remote;
  }
}

final userSettingsStoreProvider = Provider((ref) => UserSettingsStore());

final StateNotifierProvider<UserSettingsNotifier, UserSettings>
    userSettingsProvider =
    StateNotifierProvider<UserSettingsNotifier, UserSettings>((ref) {
  final store = ref.watch(userSettingsStoreProvider);
  final notifier = UserSettingsNotifier(store);
  Future.microtask(() => store.attachListener(ref, userSettingsProvider));
  return notifier;
});
