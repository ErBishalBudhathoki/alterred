import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/session_state.dart';
import '../core/design_tokens.dart';
import 'package:flutter_neuropilot/l10n/app_localizations.dart';
import '../core/components/np_text_field.dart';
import '../core/components/np_button.dart';
import '../core/components/np_app_bar.dart';
import '../core/components/np_list_tile.dart';
import '../core/components/np_snackbar.dart';

class TaskFlowScreen extends ConsumerStatefulWidget {
  const TaskFlowScreen({super.key});
  @override
  ConsumerState<TaskFlowScreen> createState() => _TaskFlowScreenState();
}

class _TaskFlowScreenState extends ConsumerState<TaskFlowScreen> {
  final _controller = TextEditingController();
  Map<String, dynamic>? _atomized;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: NpAppBar(title: l.taskflowTitle),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLg),
        child: Column(
          children: [
            NpTextField(controller: _controller, label: l.taskDescriptionLabel),
            const SizedBox(height: DesignTokens.spacingMd),
            NpButton(
              onPressed: () async {
                try {
                  final res = await api.atomizeTask(_controller.text);
                  setState(() => _atomized = res);
              } catch (e) {
                NpSnackbar.show(context, '$e', type: NpSnackType.destructive);
              }
              },
              label: l.atomize,
              icon: Icons.auto_awesome,
              type: NpButtonType.primary,
            ),
            const SizedBox(height: DesignTokens.spacingMd),
            if (_atomized != null)
              Expanded(
                child: ListView(
                  children: [
                    Text(l.microSteps),
                    ...((_atomized!['micro_steps'] as List<dynamic>? ?? [])
                        .map((e) => NpListTile(leading: const Icon(Icons.check), title: '$e'))),
                  ],
                ),
              ),
            const SizedBox(height: DesignTokens.spacingMd),
            FocusTraversalGroup(
              child: Row(
                children: [
                  Expanded(
                    child: NpButton(
                      label: l.clearLabel,
                      icon: Icons.clear,
                      type: NpButtonType.warning,
                      onPressed: () {
                        _controller.clear();
                        setState(() => _atomized = null);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}