import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_neuropilot/l10n/app_localizations.dart';
import 'core/theme.dart';
import 'core/routes.dart';
import 'state/session_state.dart';

void main() {
  runApp(const ProviderScope(child: NeuroPilotApp()));
}

class NeuroPilotApp extends ConsumerWidget {
  const NeuroPilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final saved = ref.watch(savedLocaleProvider).value;
    return MaterialApp(
      title: 'NeuroPilot',
      theme: NeuroPilotTheme.light,
      darkTheme: NeuroPilotTheme.dark,
      locale: locale ?? saved,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: Routes.chat,
      routes: Routes.map,
    );
  }
}