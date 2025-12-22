import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:altered/l10n/app_localizations.dart';
import '../core/design_tokens.dart';
import '../state/session_state.dart';
import '../core/components/np_button.dart';
import '../core/components/np_app_bar.dart';
import '../core/components/np_snackbar.dart';

/// Screen for checking backend health and latency.
///
/// Implementation Details:
/// - Uses [ApiClient] to ping the backend health endpoint.
/// - Measures round-trip latency.
/// - Checks for MCP (Model Context Protocol) capability availability.
/// - Implements optimized state management with loading indicators.
///
/// Design Decisions:
/// - Separate checks for health, latency, and MCP allow focused debugging.
/// - Visual indicators (status text) update dynamically based on check results.
///
/// Behavioral Specifications:
/// - [Check Health]: Pings the server and displays the returned status.
/// - [Check Latency]: Measures time taken for a health check call.
/// - [Check MCP]: Verifies if the backend reports MCP tool availability.
/// - Transition animations smooth out UI updates.
class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});
  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  Map<String, dynamic>? _health;
  int? _latencyMs;
  bool? _mcpReady;
  bool _isLoading = false;

  Future<void> _runCheck(Future<void> Function() check) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await check();
    } catch (e) {
      if (mounted) {
        NpSnackbar.show(context, '$e', type: NpSnackType.destructive);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final api = ref.watch(apiClientProvider);
    final base = ref.watch(baseUrlProvider);
    final tok = ref.watch(tokenProvider);

    return Scaffold(
      appBar: NpAppBar(title: l.healthTitle),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l.baseUrlLabel}: $base'),
            const SizedBox(height: DesignTokens.spacingSm),
            Text(
                '${l.tokenLabel}: ${tok != null ? l.presentLabel : l.absentLabel}'),
            const SizedBox(height: DesignTokens.spacingMd),
            NpButton(
              label: l.checkHealth,
              icon: Icons.sync,
              type: NpButtonType.primary,
              loading: _isLoading,
              onPressed: () => _runCheck(() async {
                final r = await api.health();
                if (mounted) setState(() => _health = r);
              }),
            ),
            const SizedBox(height: DesignTokens.spacingMd),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _health != null
                  ? Text(
                      '${l.statusLabel}: ${_health!['status'] ?? _health}',
                      key: ValueKey(_health.toString()),
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: DesignTokens.spacingMd),
            NpButton(
              label: l.checkLatency,
              icon: Icons.speed,
              type: NpButtonType.warning,
              loading: _isLoading,
              onPressed: () => _runCheck(() async {
                final t0 = DateTime.now();
                await api.health();
                final dt = DateTime.now().difference(t0).inMilliseconds;
                if (mounted) setState(() => _latencyMs = dt);
              }),
            ),
            const SizedBox(height: DesignTokens.spacingSm),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _latencyMs != null
                  ? Text(
                      '${l.latencyLabel}: $_latencyMs ms',
                      key: ValueKey(_latencyMs),
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: DesignTokens.spacingMd),
            NpButton(
              label: l.checkMcp,
              icon: Icons.extension,
              type: NpButtonType.secondary,
              loading: _isLoading,
              onPressed: () => _runCheck(() async {
                final r = await api.health();
                final ready = r['mcp_ready'] == true ||
                    r['mcp_calendar'] == 'available' ||
                    r['search_tool'] == 'available';
                if (mounted) setState(() => _mcpReady = ready);
              }),
            ),
            const SizedBox(height: DesignTokens.spacingSm),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _mcpReady != null
                  ? Text(
                      _mcpReady! ? l.mcpReady : l.mcpNotReady,
                      key: ValueKey(_mcpReady),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _mcpReady!
                                ? DesignTokens.success
                                : DesignTokens.error,
                            fontWeight: FontWeight.bold,
                          ),
                    )
                  : _mcpReady == null
                      ? Text(l.unknownLabel)
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
