import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import 'session_state.dart';

/// Manages the backend health status.
///
/// Implementation Details:
/// - Uses a StreamProvider to periodically poll the health endpoint.
/// - Updates state only when the health status actually changes.
/// - Isolates health check logic from UI components.
class BackendHealthNotifier extends StateNotifier<bool> {
  final ApiClient _api;
  Timer? _timer;

  BackendHealthNotifier(this._api) : super(false) {
    if (_isTestEnv) {
      _checkHealth();
    } else {
      _startPolling();
    }
  }

  bool get _isTestEnv {
    final t = WidgetsBinding.instance.runtimeType.toString();
    return t.contains('TestWidgetsFlutterBinding') ||
        t.contains('LiveTestWidgetsFlutterBinding') ||
        t.contains('AutomatedTestWidgetsFlutterBinding');
  }

  void _startPolling() {
    _checkHealth(); // Check immediately
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkHealth());
  }

  Future<void> _checkHealth() async {
    try {
      final r = await _api.health();
      if (!mounted) return;
      final isOk = r['ok'] == true || r['status'] == 'ok';
      if (state != isOk) {
        state = isOk;
      }
    } catch (_) {
      if (!mounted) return;
      if (state != false) {
        state = false;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final backendHealthProvider =
    StateNotifierProvider<BackendHealthNotifier, bool>((ref) {
  final api = ref.watch(apiClientProvider);
  return BackendHealthNotifier(api);
});
