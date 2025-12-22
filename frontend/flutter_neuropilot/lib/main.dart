import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:altered/l10n/app_localizations.dart';

import 'core/routes.dart';
import 'core/firebase_env.dart';
import 'core/design_tokens.dart';
import 'core/observability/observability_manager.dart';
import 'state/session_state.dart';
import 'state/auth_state.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

/// Entry point of the application.
///
/// Implementation Details:
/// - Initializes Flutter binding and Firebase.
/// - Wraps the app in a `ProviderScope` for Riverpod state management.
/// - Sets up the material theme using `DesignTokens`.
///
/// Design Decisions:
/// - Uses a consumer widget `_AuthGate` to handle initial routing based on auth state.
/// - Applies a custom theme derived from a seed color for consistency.
/// - Configures localization delegates for multi-language support.
///
/// Behavioral Specifications:
/// - Shows `SplashScreen` while checking auth status.
/// - Redirects to `LoginScreen` if unauthenticated.
/// - Redirects to `MainScreen` (was ChatScreen) if authenticated.
void main() async {
  // Force rebuild: v1.1
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();

  // Initialize observability system
  await ObservabilityManager.instance.initialize();

  // Initialize Notion services
  await _initializeNotionServices();

  runApp(const ProviderScope(child: NeuroPilotApp()));
}

/// Initialize Notion services for MCP integration
Future<void> _initializeNotionServices() async {
  try {
    // Services will be initialized when first accessed via providers
    // This ensures proper dependency injection and lifecycle management
    // print('[Notion] Services ready for initialization'); // Unused
  } catch (e) {
    // print('[Notion] Initialization warning: $e'); // Unused
    // Non-blocking - Notion integration is optional
  }
}

/// AuthGate handles initial routing without showing splash on refresh
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navAsync = ref.watch(navigationProvider);

    return navAsync.when(
      data: (route) {
        // Directly show the target screen without splash
        if (route == '/chat' || route == '/') {
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
      loading: () => const SplashScreen(), // Show splash only while loading
      error: (_, __) => const LoginScreen(), // Fallback to login on error
    );
  }
}

class NeuroPilotApp extends ConsumerWidget {
  const NeuroPilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Note: authUserProvider is accessed in SplashScreen after Firebase is initialized
    final locale = ref.watch(localeProvider);
    final saved = ref.watch(savedLocaleProvider).value;

    // Trigger location detection
    ref.watch(locationInitializerProvider);

    return MaterialApp(
      title: 'Altered',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('hi'), // Hindi
      ],
      locale: saved ?? locale,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'NotoSans',
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
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoSansDevanagari', 'NotoSansDevanagariUI'],
          ),
          bodyMedium: TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoSansDevanagari', 'NotoSansDevanagariUI'],
          ),
          bodySmall: TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoSansDevanagari', 'NotoSansDevanagariUI'],
          ),
          titleLarge: TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoSansDevanagari', 'NotoSansDevanagariUI'],
          ),
          titleMedium: TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoSansDevanagari', 'NotoSansDevanagariUI'],
          ),
          titleSmall: TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoSansDevanagari', 'NotoSansDevanagariUI'],
          ),
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
        fontFamily: 'NotoSans',
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
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoSansDevanagari', 'NotoSansDevanagariUI'],
          ),
          bodyMedium: TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoSansDevanagari', 'NotoSansDevanagariUI'],
          ),
          bodySmall: TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoSansDevanagari', 'NotoSansDevanagariUI'],
          ),
          titleLarge: TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoSansDevanagari', 'NotoSansDevanagariUI'],
          ),
          titleMedium: TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoSansDevanagari', 'NotoSansDevanagariUI'],
          ),
          titleSmall: TextStyle(
            fontFamily: 'NotoSans',
            fontFamilyFallback: ['NotoSansDevanagari', 'NotoSansDevanagariUI'],
          ),
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
      home: const _AuthGate(),
      routes: Routes.map,
    );
  }
}
