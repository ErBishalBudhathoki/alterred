import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../services/local_store.dart';
import 'user_settings_store.dart';

/// Energy Store
///
/// Manages the state of energy logging and retrieval, with optional cloud sync.
///
/// Implementation Details:
/// - Uses [LocalStore] for local persistence (source of truth).
/// - Syncs to Firestore if [userSettingsProvider] indicates sync is enabled.
/// - Follows the "Fire-and-forget" pattern for sync to avoid blocking UI.
///
/// Design Decisions:
/// - Decouples UI from direct storage access.
/// - Matches [ChatStore] and [UserSettingsStore] dual-write pattern.
class EnergyStore {
  final LocalStore _store;
  final Ref _ref;

  EnergyStore(this._store, this._ref);

  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Logs an energy level (1-10) locally and optionally syncs to cloud.
  Future<void> logEnergy(int level) async {
    // 1. Log locally
    await _store.logEnergy(level);

    // 2. Sync to cloud if enabled
    try {
      final settings = _ref.read(userSettingsProvider);
      if (settings.firestoreSyncEnabled && _uid != null) {
        await _syncToFirestore(level);
      }
    } catch (e) {
      debugPrint('EnergyStore: Sync failed - $e');
    }
  }

  /// Syncs a single entry to Firestore.
  Future<void> _syncToFirestore(int level) async {
    final timestamp = DateTime.now().toIso8601String();
    await _fs.collection('users').doc(_uid).collection('energy_logs').add({
      'level': level,
      'timestamp': timestamp,
      'source': 'mobile_app',
    });
  }

  /// Retrieves the history of energy logs.
  Future<List<Map<String, dynamic>>> getHistory() async {
    return await _store.getEnergyLogs();
  }
}

/// Provider for the LocalStore instance.
final localStoreProvider = Provider<LocalStore>((ref) => LocalStore());

/// Provider for the EnergyStore instance.
final energyStoreProvider = Provider<EnergyStore>((ref) {
  final store = ref.watch(localStoreProvider);
  return EnergyStore(store, ref);
});
