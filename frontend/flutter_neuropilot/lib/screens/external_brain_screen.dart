import 'package:flutter/material.dart';
import 'package:altered/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/session_state.dart';
import '../core/design_tokens.dart';
import '../core/components/np_text_field.dart';
import '../core/components/np_button.dart';
import '../core/components/np_app_bar.dart';
import '../core/components/np_snackbar.dart';

/// Screen for capturing and viewing "External Brain" notes.
///
/// Allows users to quickly jot down thoughts or tasks, which are then processed by the backend.
///
/// Implementation Details:
/// - Uses [NpTextField] for input and [NpButton] for actions.
/// - Fetches existing notes on load via [ApiClient].
/// - Displays captured task ID and updated notes list upon successful submission.
///
/// Design Decisions:
/// - Simple list layout prioritizes quick capture and review.
/// - Uses [NpSnackbar] for feedback to avoid blocking the UI with dialogs.
///
/// Behavioral Specifications:
/// - [initState]: Fetches initial list of external notes.
/// - [Capture]: Sends transcript to backend, updates UI with result.
/// - [Refresh]: Manually reloads the notes list.
/// - [Clear]: Resets the input field and task ID display.
class ExternalBrainScreen extends ConsumerStatefulWidget {
  const ExternalBrainScreen({super.key});
  @override
  ConsumerState<ExternalBrainScreen> createState() =>
      _ExternalBrainScreenState();
}

class _ExternalBrainScreenState extends ConsumerState<ExternalBrainScreen> {
  final _transcript = TextEditingController();
  String? _taskId;
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final api = ref.read(apiClientProvider);
        final list = await api.externalNotes();
        setState(() => _notes = list.cast<Map<String, dynamic>>());
      } catch (_) {}
    });
  }

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
                if (!context.mounted) return;
                setState(() => _taskId = res['task_id'] as String?);
                try {
                  final list = await api.externalNotes();
                  if (!context.mounted) return;
                  setState(() => _notes = list.cast<Map<String, dynamic>>());
                } catch (_) {}
              } catch (e) {
                if (context.mounted) {
                  NpSnackbar.show(context, '$e', type: NpSnackType.destructive);
                }
              }
            },
            label: l.capture,
            icon: Icons.library_add,
            type: NpButtonType.success,
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          if (_taskId != null) Text('Captured task: $_taskId'),
          const SizedBox(height: DesignTokens.spacingMd),
          Row(children: [
            Expanded(
                child: Text('Captured notes',
                    style: Theme.of(context).textTheme.titleMedium)),
            NpButton(
                label: 'Refresh',
                icon: Icons.refresh,
                type: NpButtonType.secondary,
                onPressed: () async {
                  try {
                    final list = await api.externalNotes();
                    if (!context.mounted) return;
                    setState(() => _notes = list.cast<Map<String, dynamic>>());
                  } catch (e) {
                    if (context.mounted) {
                      NpSnackbar.show(context, '$e', type: NpSnackType.warning);
                    }
                  }
                }),
          ]),
          const SizedBox(height: DesignTokens.spacingSm),
          Expanded(
            child: ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (ctx, i) {
                final n = _notes[i];
                final ttl = (n['title'] as String?) ?? 'Untitled';
                final when = (n['created_at'] as String?) ?? '';
                return ListTile(
                  leading: const Icon(Icons.note),
                  title: Text(ttl),
                  subtitle: Text(when),
                );
              },
            ),
          ),
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
