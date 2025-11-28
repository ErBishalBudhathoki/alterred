import 'package:flutter/material.dart';

/// Centralized design system constants for the application.
///
/// Implementation Details:
/// - Defines color palettes for light and dark modes.
/// - Standardizes spacing, border radii, and typography sizing.
///
/// Design Decisions:
/// - Uses a "Slate & Blue" palette for a calming, focused aesthetic suitable for neurodiverse users.
/// - Prefers flat design (low elevation) to reduce visual noise.
/// - Softer border radii create a more organic, welcoming feel.
///
/// Behavioral Specifications:
/// - Static constants accessed globally to ensure UI consistency.
/// - Changes here propagate across the entire app.
class DesignTokens {
  // Calming, focused color palette (Slate & Blue)
  // Light Mode Colors
  static const Color primarySeed = Color(0xFF2563EB); // Blue 600
  static const Color primary = Color(0xFF2563EB);
  static const Color onPrimary = Colors.white;
  
  static const Color secondary = Color(0xFF64748B); // Slate 500
  static const Color onSecondary = Colors.white;

  static const Color background = Color(0xFFF8FAFC); // Slate 50 - Lighter, fresher
  static const Color surface = Colors.white;
  static const Color onSurface = Color(0xFF1E293B); // Slate 800
  static const Color onSurfaceVariant = Color(0xFF64748B); // Slate 500

  // Dark Mode Colors
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color onSurfaceDark = Color(0xFFF1F5F9); // Slate 100
  static const Color onSurfaceVariantDark = Color(0xFF94A3B8); // Slate 400
  
  static const Color primaryDark = Color(0xFF3B82F6); // Blue 500 - Slightly lighter for dark mode
  static const Color onPrimaryDark = Colors.white;
  
  static const Color secondaryDark = Color(0xFF475569); // Slate 600
  static const Color onSecondaryDark = Color(0xFFF1F5F9); // Slate 100

  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error = Color(0xFFEF4444); // Red 500
  
  // Spacing
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 24;
  static const double spacing2Xl = 32;

  // Radius - Softer, more organic feel
  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  // Typography
  static const double titleLargeSize = 24;
  static const FontWeight titleLargeWeight = FontWeight.w600;
  static const double bodySize = 16;

  // Elevation
  static const double elevationSm = 0; // Flat design preference
  static const double elevationMd = 2;
  static const double elevationLg = 4;
}

/// Standardized animation constants for consistent motion.
class MotionTokens {
  static const Duration durationShort = Duration(milliseconds: 200);
  static const Duration durationMedium = Duration(milliseconds: 400);
  static const Duration durationLong = Duration(milliseconds: 600);
  static const Duration durationXLong = Duration(milliseconds: 800);

  static const Curve curveIdle = Curves.easeInOutSine;
  static const Curve curveAction = Curves.easeOutCubic;
  static const Curve curveBounce = Curves.elasticOut;
}

/// Glassmorphism styles for premium UI elements.
class GlassTokens {
  static const double blurSm = 5.0;
  static const double blurMd = 10.0;
  static const double blurLg = 20.0;
  
  static const double opacityLow = 0.1;
  static const double opacityMedium = 0.3;
  static const double opacityHigh = 0.7;
}
