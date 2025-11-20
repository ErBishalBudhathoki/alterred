import 'package:flutter/material.dart';
import '../screens/taskflow_screen.dart';
import '../screens/time_screen.dart';
import '../screens/decision_screen.dart';
import '../screens/external_brain_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/health_screen.dart';
import '../screens/chat_screen.dart';

class Routes {
  static const home = '/';
  static const chat = '/';
  static const taskflow = '/taskflow';
  static const time = '/time';
  static const decision = '/decision';
  static const external = '/external';
  static const settings = '/settings';
  static const health = '/health';

  static Map<String, WidgetBuilder> get map => {
        home: (_) => const ChatScreen(),
        taskflow: (_) => const TaskFlowScreen(),
        time: (_) => const TimeScreen(),
        decision: (_) => const DecisionScreen(),
        external: (_) => const ExternalBrainScreen(),
        settings: (_) => const SettingsScreen(),
        health: (_) => const HealthScreen(),
      };
}