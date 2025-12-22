import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Local Store
///
/// A unified interface for local persistence using SharedPreferences.
///
/// Implementation Details:
/// - Wraps SharedPreferences to provide strongly-typed access to local data.
/// - Handles serialization/deserialization of complex objects (e.g., energy logs).
/// - Follows the Singleton pattern (optional, but using static/provider is better).
///
/// Design Decisions:
/// - Separates raw storage logic from state management (Riverpod).
/// - Provides specific methods for feature-based data (energy, etc.) to avoid key collisions.
///
/// Behavioral Specifications:
/// - [logEnergy]: Appends a new energy log entry with a timestamp.
/// - [getEnergyLogs]: Retrieves all stored energy logs sorted by date.
class LocalStore {
  static const String _keyEnergyLogs = 'energy_logs';

  /// Logs an energy level with the current timestamp.
  Future<bool> logEnergy(int level) async {
    if (level < 1 || level > 10) {
      throw ArgumentError('Energy level must be between 1 and 10');
    }
    final prefs = await SharedPreferences.getInstance();
    final logs = await getEnergyLogs();

    final entry = {
      'level': level,
      'timestamp': DateTime.now().toIso8601String(),
    };

    logs.add(entry);

    return await prefs.setString(_keyEnergyLogs, jsonEncode(logs));
  }

  /// Retrieves all energy logs.
  Future<List<Map<String, dynamic>>> getEnergyLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyEnergyLogs);
    if (raw == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Clears all energy logs.
  Future<void> clearEnergyLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEnergyLogs);
  }
}
