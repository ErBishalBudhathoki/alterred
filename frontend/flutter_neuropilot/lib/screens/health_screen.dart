import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_neuropilot/l10n/app_localizations.dart';
import '../core/design_tokens.dart';
import '../state/session_state.dart';
import '../core/components/np_button.dart';
import '../core/components/np_app_bar.dart';
import '../core/components/np_snackbar.dart';

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});
  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  Map<String, dynamic>? _health;
  int? _latencyMs;
  bool? _mcpReady;

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
              onPressed: () async {
                try {
                  final r = await api.health();
                  if (!context.mounted) return;
                  setState(() => _health = r);
                } catch (e) {
                  if (context.mounted) {
                    NpSnackbar.show(context, '$e',
                        type: NpSnackType.destructive);
                  }
                }
              },
            ),
            const SizedBox(height: DesignTokens.spacingMd),
            if (_health != null)
              Text('${l.statusLabel}: ${_health!['status'] ?? _health}'),
            const SizedBox(height: DesignTokens.spacingMd),
            NpButton(
              label: l.checkLatency,
              icon: Icons.speed,
              type: NpButtonType.warning,
              onPressed: () async {
                try {
                  final t0 = DateTime.now();
                  await api.health();
                  final dt = DateTime.now().difference(t0).inMilliseconds;
                  if (!context.mounted) return;
                  setState(() => _latencyMs = dt);
                } catch (e) {
                  if (context.mounted) {
                    NpSnackbar.show(context, '$e',
                        type: NpSnackType.destructive);
                  }
                }
              },
            ),
            const SizedBox(height: DesignTokens.spacingSm),
            if (_latencyMs != null) Text('${l.latencyLabel}: $_latencyMs ms'),
            const SizedBox(height: DesignTokens.spacingMd),
            NpButton(
              label: l.checkMcp,
              icon: Icons.extension,
              type: NpButtonType.secondary,
              onPressed: () async {
                try {
                  final r = await api.health();
                  final ready = r['mcp_ready'] == true ||
                      r.containsKey('tools') ||
                      r.containsKey('calendar') ||
                      r.containsKey('mcp');
                  if (!context.mounted) return;
                  setState(() => _mcpReady = ready);
                } catch (e) {
                  if (context.mounted) {
                    NpSnackbar.show(context, '$e',
                        type: NpSnackType.destructive);
                  }
                }
              },
            ),
            const SizedBox(height: DesignTokens.spacingSm),
            if (_mcpReady != null)
              Text(_mcpReady! ? l.mcpReady : l.mcpNotReady),
            if (_mcpReady == null) Text(l.unknownLabel),
          ],
        ),
      ),
    );
  }
}
