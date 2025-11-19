import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_neuropilot/l10n/app_localizations.dart';
import '../core/components/np_app_bar.dart';
import '../core/design_tokens.dart';
import '../state/session_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: NpAppBar(title: l.settingsTitle),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.languageLabel, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: DesignTokens.spacingMd),
            RadioListTile<Locale>(
              title: Text(l.languageEnglish),
              value: const Locale('en'),
              groupValue: locale,
              onChanged: (v) async {
                ref.read(localeProvider.notifier).state = v;
                final p = await SharedPreferences.getInstance();
                await p.setString('locale_code', '${v!.languageCode}${v.countryCode != null ? '_${v.countryCode}' : ''}');
              },
            ),
            RadioListTile<Locale>(
              title: Text(l.languageHindi),
              value: const Locale('hi'),
              groupValue: locale,
              onChanged: (v) async {
                ref.read(localeProvider.notifier).state = v;
                final p = await SharedPreferences.getInstance();
                await p.setString('locale_code', '${v!.languageCode}${v.countryCode != null ? '_${v.countryCode}' : ''}');
              },
            ),
          ],
        ),
      ),
    );
  }
}