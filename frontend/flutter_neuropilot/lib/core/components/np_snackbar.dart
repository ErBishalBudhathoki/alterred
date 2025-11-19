import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum NpSnackType { info, success, warning, destructive }

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