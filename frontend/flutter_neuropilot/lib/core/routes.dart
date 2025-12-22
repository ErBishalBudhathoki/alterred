import 'package:flutter/material.dart';

import '../screens/external_brain_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/health_screen.dart';
import '../screens/chat_history_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/metrics_screen.dart';
import '../screens/main_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/task_prioritization_screen.dart';
import '../screens/notion_settings_screen.dart';
import '../screens/notion_library_screen.dart';

/// Centralized route definitions and navigation map.
///
/// Defines the route strings and the builder map for `MaterialApp`.
///
/// Implementation Details:
/// - Static constants for route names to prevent typos.
/// - Static [map] getter returns the `WidgetBuilder` map.
///
/// Design Decisions:
/// - Centralization makes it easy to see all available screens and manage navigation logic.
/// - The home route `/` is typically handled by the `home` property of `MaterialApp` (or an `_AuthGate`), but is defined here for completeness.
///
/// Behavioral Specifications:
/// - [map]: Returns a map associating route strings with their corresponding screen widgets.
class Routes {
  static const home = '/';
  static const chat = '/chat';
  static const chats = '/chats';
  static const splash = '/splash';
  static const login = '/login';
  static const signup = '/signup';

  static const external = '/external';
  static const settings = '/settings';
  static const health = '/health';
  static const metrics = '/metrics';
  static const dashboard = '/neuro-dashboard';
  static const taskPrioritization = '/task-prioritization';
  static const notionSettings = '/notion-settings';
  static const notionLibrary = '/notion-library';

  /// Returns the route map for the application.
  static Map<String, WidgetBuilder> get map => {
        // Note: '/' is handled by MaterialApp's home parameter
        chat: (_) => const MainScreen(),
        chats: (_) => const ChatHistoryScreen(),
        splash: (_) => const SplashScreen(),
        login: (_) => const LoginScreen(),
        signup: (_) => const SignupScreen(),

        external: (_) => const ExternalBrainScreen(),
        settings: (_) => const SettingsScreen(),
        health: (_) => const HealthScreen(),
        metrics: (_) => const MetricsScreen(),
        dashboard: (_) => const NeuroPilotDashboard(),
        taskPrioritization: (_) => const TaskPrioritizationScreen(),
        notionSettings: (_) => const NotionSettingsScreen(),
        notionLibrary: (_) => const NotionLibraryScreen(),
      };
}
