import 'package:flutter/material.dart';
import 'package:flutter_neuropilot/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/session_state.dart';
import '../core/design_tokens.dart';
import '../core/components/np_text_field.dart';
import '../core/components/np_button.dart';
import '../core/components/np_app_bar.dart';
import '../core/components/np_list_tile.dart';
import '../core/components/np_snackbar.dart';

class DecisionScreen extends ConsumerStatefulWidget {
  const DecisionScreen({super.key});
  @override
  ConsumerState<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends ConsumerState<DecisionScreen> {
  final _options = TextEditingController();
  List<dynamic> _reduced = [];

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: NpAppBar(title: l.decisionTitle),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLg),
        child: Column(children: [
          NpTextField(controller: _options, label: l.optionsLabel),
          const SizedBox(height: DesignTokens.spacingMd),
          NpButton(
            onPressed: () async {
              try {
                final opts = _options.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                final res = await api.reduceOptions(opts, 3);
                setState(() => _reduced = res['reduced_options'] ?? []);
              } catch (e) {
                NpSnackbar.show(context, '$e', type: NpSnackType.destructive);
              }
            },
            label: l.reduceTo3,
            icon: Icons.filter_alt,
            type: NpButtonType.secondary,
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Expanded(
            child: ListView(children: _reduced.map((e) => NpListTile(title: '$e')).toList()),
          )
          ,
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
                      _options.clear();
                    },
                  ),
                ),
                const SizedBox(width: DesignTokens.spacingSm),
                Expanded(
                  child: NpButton(
                    label: l.resetLabel,
                    icon: Icons.restore,
                    type: NpButtonType.destructive,
                    onPressed: () {
                      setState(() => _reduced = []);
                    },
                  ),
                ),
              ],
            ),
          )
        ]),
      ),
    );
  }
}