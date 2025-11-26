import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum NpSnackType { info, success, warning, destructive }

/// A lightweight message with an optional action which briefly displays at the bottom of the screen.
///
/// Implementation Details:
/// - Static method [show] uses [ScaffoldMessenger] to display a [SnackBar].
/// - Custom styling based on [NpSnackType].
///
/// Design Decisions:
/// - Floating behavior prevents blocking the bottom navigation bar or FAB.
/// - Semantic colors ensure the message intent is immediately clear.
///
/// Behavioral Specifications:
/// - Automatically dismisses after a timeout.
/// - Can be dismissed by swiping or tapping an action (if added).
class NpSnackbar {
  static void show(BuildContext context, String message, {NpSnackType type = NpSnackType.info}) {
    final bg = switch (type) {
      NpSnackType.info => Theme.of(context).colorScheme.surface,
      NpSnackType.success => DesignTokens.success,
      NpSnackType.warning => DesignTokens.warning,
      NpSnackType.destructive => DesignTokens.error,
    };
    final fg = type == NpSnackType.info ? Theme.of(context).colorScheme.onSurface : DesignTokens.onPrimary;
    final snack = SnackBar(
      content: Semantics(liveRegion: true, child: Text(message, style: TextStyle(color: fg))),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusMd)),
      margin: const EdgeInsets.all(DesignTokens.spacingLg),
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }
}