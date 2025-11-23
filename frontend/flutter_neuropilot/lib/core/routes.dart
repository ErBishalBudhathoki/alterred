import 'package:flutter/material.dart';

import '../screens/external_brain_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/health_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';

class Routes {
  static const home = '/';
  static const chat = '/';
  static const splash = '/splash';
  static const login = '/login';
  static const signup = '/signup';

  static const external = '/external';
  static const settings = '/settings';
  static const health = '/health';

  static Map<String, WidgetBuilder> get map => {
        home: (_) => const ChatScreen(),
        splash: (_) => const SplashScreen(),
        login: (_) => const LoginScreen(),
        signup: (_) => const SignupScreen(),

        external: (_) => const ExternalBrainScreen(),
        settings: (_) => const SettingsScreen(),
        health: (_) => const HealthScreen(),
      };
}
