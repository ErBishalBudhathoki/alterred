import 'package:flutter/material.dart';
import '../design_tokens.dart';

/// Utility for showing modal bottom sheets with consistent styling.
///
/// Implementation Details:
/// - Static helper method [show] wraps [showModalBottomSheet].
/// - Applies standard border radius and padding.
///
/// Design Decisions:
/// - Handles safe area and keyboard insets automatically.
/// - consistent rounding matches other surface components.
///
/// Behavioral Specifications:
/// - Returns a [Future] that resolves when the sheet is closed.
/// - Supports scrollable content via [isScrollControlled].
class NpBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: DesignTokens.spacingLg,
          right: DesignTokens.spacingLg,
          top: DesignTokens.spacingLg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + DesignTokens.spacingLg,
        ),
        child: child,
      ),
    );
  }
}