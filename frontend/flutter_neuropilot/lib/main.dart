import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_neuropilot/l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/routes.dart';
import 'core/design_tokens.dart';
import 'state/session_state.dart';
import 'state/auth_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: NeuroPilotApp()));
}

class NeuroPilotApp extends ConsumerWidget {
  const NeuroPilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Note: authUserProvider is accessed in SplashScreen after Firebase is initialized
    final locale = ref.watch(localeProvider);
    final saved = ref.watch(savedLocaleProvider).value;
    return MaterialApp(
      title: 'NeuroPilot',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: DesignTokens.primarySeed,
          primary: DesignTokens.primary,
          onPrimary: DesignTokens.onPrimary,
          secondary: DesignTokens.secondary,
          onSecondary: DesignTokens.onSecondary,
          surface: DesignTokens.surface,
          onSurface: DesignTokens.onSurface,
          onSurfaceVariant: DesignTokens.onSurfaceVariant,
          error: DesignTokens.error,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: DesignTokens.background,
        appBarTheme: const AppBarTheme(
          backgroundColor:
              DesignTokens.background, // Blend with background for clean look
          foregroundColor: DesignTokens.onSurface,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: DesignTokens.surface,
          elevation: DesignTokens.elevationSm,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(DesignTokens.radiusMd)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: DesignTokens.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacingLg,
            vertical: DesignTokens.spacingMd,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: DesignTokens.primarySeed,
          primary: DesignTokens.primaryDark,
          onPrimary: DesignTokens.onPrimaryDark,
          secondary: DesignTokens.secondaryDark,
          onSecondary: DesignTokens.onSecondaryDark,
          surface: DesignTokens.surfaceDark,
          onSurface: DesignTokens.onSurfaceDark,
          onSurfaceVariant: DesignTokens.onSurfaceVariantDark,
          error: DesignTokens.error,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: DesignTokens.backgroundDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: DesignTokens.backgroundDark,
          foregroundColor: DesignTokens.onSurfaceDark,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: DesignTokens.surfaceDark,
          elevation: DesignTokens.elevationSm,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(DesignTokens.radiusMd)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: DesignTokens.surfaceDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacingLg,
            vertical: DesignTokens.spacingMd,
          ),
        ),
      ),
      locale: locale ?? saved,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: Routes.splash,
      routes: Routes.map,
    );
  }
}
