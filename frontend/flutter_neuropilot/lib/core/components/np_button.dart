import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum NpButtonType { primary, secondary, success, warning, destructive }

class NpButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NpButtonType type;
  final bool loading;
  const NpButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.type = NpButtonType.primary,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = switch (type) {
      NpButtonType.primary => DesignTokens.primary,
      NpButtonType.secondary => DesignTokens.background,
      NpButtonType.success => DesignTokens.success,
      NpButtonType.warning => DesignTokens.warning,
      NpButtonType.destructive => DesignTokens.error,
    };
    final fg = switch (type) {
      NpButtonType.secondary => DesignTokens.onSurface,
      _ => DesignTokens.onPrimary,
    };
    final enabled = onPressed != null && !loading;
    return FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: loading
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
          : Icon(icon ?? Icons.arrow_forward, color: fg),
      label: Text(label, style: TextStyle(color: fg)),
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingXl,
          vertical: DesignTokens.spacingSm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        ),
      ),
    );
  }
}