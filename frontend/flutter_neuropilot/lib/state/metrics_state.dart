import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_state.dart';

/// Fetches the daily metrics overview.
///
/// Returns a map containing keys like:
/// - tasks_completed
/// - avg_time_accuracy
/// - avg_agent_latency_ms
/// - avg_decision_resolution_seconds
/// - hyperfocus_interrupts
/// - avg_stress_level
/// - strategy_stats
final metricsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return await api.metricsOverview();
});
