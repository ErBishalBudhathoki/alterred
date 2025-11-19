import 'package:flutter/material.dart';
import 'design_tokens.dart';

class NeuroPilotTheme {
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: DesignTokens.primarySeed),
        useMaterial3: true,
        textTheme: const TextTheme().copyWith(
          titleLarge: const TextStyle().copyWith(
            fontSize: DesignTokens.titleLargeSize,
            fontWeight: DesignTokens.titleLargeWeight,
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: DesignTokens.primarySeed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
}