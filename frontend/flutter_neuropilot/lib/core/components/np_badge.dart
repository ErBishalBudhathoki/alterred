import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum NpBadgeType { neutral, success, warning, destructive }

/// A small status indicator or label.
///
/// Implementation Details:
/// - Renders a colored container with text.
/// - Uses [NpBadgeType] to determine color scheme (neutral, success, warning, destructive).
///
/// Design Decisions:
/// - Compact padding and rounded corners for a modern look.
/// - Semantic colors align with [DesignTokens] for consistency.
///
/// Behavioral Specifications:
/// - Adapts text color based on background contrast.
class NpBadge extends StatelessWidget {
  final String text;
  final NpBadgeType type;
  const NpBadge(
      {super.key, required this.text, this.type = NpBadgeType.neutral});

  Color _bg(BuildContext context) => switch (type) {
        NpBadgeType.neutral =>
          Theme.of(context).colorScheme.surfaceContainerHighest,
        NpBadgeType.success => DesignTokens.success,
        NpBadgeType.warning => DesignTokens.warning,
        NpBadgeType.destructive => DesignTokens.error,
      };

  Color _fg(BuildContext context) => type == NpBadgeType.neutral
      ? Theme.of(context).colorScheme.onSurface
      : DesignTokens.onPrimary;

  @override
  Widget build(BuildContext context) {
    final bg = _bg(context);
    final fg = _fg(context);
    return Semantics(
      label: text,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingSm,
          vertical: DesignTokens.spacingXs,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        ),
        child: Text(text,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
