import 'package:flutter/material.dart';
import 'package:flutter_neuropilot/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/session_state.dart';
import '../core/design_tokens.dart';
import '../core/components/np_text_field.dart';
import '../core/components/np_button.dart';
import '../core/components/np_app_bar.dart';
import '../core/components/np_snackbar.dart';

class ExternalBrainScreen extends ConsumerStatefulWidget {
  const ExternalBrainScreen({super.key});
  @override
  ConsumerState<ExternalBrainScreen> createState() => _ExternalBrainScreenState();
}

class _ExternalBrainScreenState extends ConsumerState<ExternalBrainScreen> {
  final _transcript = TextEditingController();
  String? _taskId;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: NpAppBar(title: l.externalTitle),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLg),
        child: Column(children: [
          NpTextField(controller: _transcript, label: l.transcriptLabel), 
          const SizedBox(height: DesignTokens.spacingMd),
          NpButton(
            onPressed: () async {
              try {
                final res = await api.captureExternal(_transcript.text);
                setState(() => _taskId = res['task_id'] as String?);
              } catch (e) {
                NpSnackbar.show(context, '$e', type: NpSnackType.destructive);
              }
            },
            label: l.capture,
            icon: Icons.library_add,
            type: NpButtonType.success,
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          if (_taskId != null) Text('Captured task: $_taskId'),
          const SizedBox(height: DesignTokens.spacingMd),
          NpButton(
            label: l.clearLabel,
            icon: Icons.clear,
            type: NpButtonType.warning,
            onPressed: () {
              _transcript.clear();
              setState(() => _taskId = null);
            },
          ),
        ]),
      ),
    );
  }
}