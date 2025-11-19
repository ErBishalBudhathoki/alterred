import 'package:flutter/material.dart';
import '../design_tokens.dart';

class NpDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    String? primaryLabel,
    String? secondaryLabel,
    VoidCallback? onPrimary,
    VoidCallback? onSecondary,
  }) {
    final actions = <Widget>[];
    if (secondaryLabel != null) {
      actions.add(TextButton(
        onPressed: () {
          onSecondary?.call();
          Navigator.of(context).pop();
        },
        child: Text(secondaryLabel),
      ));
    }
    if (primaryLabel != null) {
      actions.add(FilledButton(
        onPressed: () {
          onPrimary?.call();
          Navigator.of(context).pop();
        },
        child: Text(primaryLabel),
      ));
    }
    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: content,
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingLg,
          vertical: DesignTokens.spacingSm,
        ),
        actions: actions,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        ),
      ),
    );
  }
}