import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/session_state.dart';
import '../core/design_tokens.dart';
import 'package:flutter_neuropilot/l10n/app_localizations.dart';
import '../core/components/np_text_field.dart';
import '../core/components/np_button.dart';
import '../core/components/np_app_bar.dart';
import '../core/components/np_snackbar.dart';

class TimeScreen extends ConsumerStatefulWidget {
  const TimeScreen({super.key});
  @override
  ConsumerState<TimeScreen> createState() => _TimeScreenState();
}

class _TimeScreenState extends ConsumerState<TimeScreen> {
  final _target = TextEditingController();
  Map<String, dynamic>? _timer;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: NpAppBar(title: l.timeTitle),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLg),
        child: Column(
          children: [
            NpTextField(controller: _target, label: l.targetIsoLabel), 
            const SizedBox(height: DesignTokens.spacingMd),
            NpButton(
              onPressed: () async {
                try {
                  final res = await api.createCountdown(_target.text);
                  setState(() => _timer = res);
              } catch (e) {
                NpSnackbar.show(context, '$e', type: NpSnackType.destructive);
              }
              },
              label: l.createCountdown,
              icon: Icons.timer,
              type: NpButtonType.primary,
            ),
            const SizedBox(height: DesignTokens.spacingMd),
            if (_timer != null) Text('Timer: ${_timer!['timer_id']} warnings=${_timer!['warnings']}'),
            const SizedBox(height: DesignTokens.spacingMd),
            NpButton(
              label: l.cancelTimer,
              icon: Icons.cancel,
              type: NpButtonType.destructive,
              onPressed: () {
                setState(() => _timer = null);
              },
            ),
          ],
        ),
      ),
    );
  }
}