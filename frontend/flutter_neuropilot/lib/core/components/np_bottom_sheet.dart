import 'package:flutter/material.dart';
import '../design_tokens.dart';

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