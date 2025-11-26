import 'package:flutter/material.dart';
import '../design_tokens.dart';

/// A thin horizontal line for separating content.
///
/// Implementation Details:
/// - Wraps the standard [Divider] widget.
/// - Sets a low-opacity color for subtle visual separation.
///
/// Design Decisions:
/// - Default indentation matches standard layout grid.
///
/// Behavioral Specifications:
/// - Static height (1 logical pixel thickness).
class NpDivider extends StatelessWidget {
  final double? indent;
  final double? endIndent;
  const NpDivider({super.key, this.indent, this.endIndent});

  @override
  Widget build(BuildContext context) {
    return Divider(
      thickness: 1,
      indent: indent ?? DesignTokens.spacingLg,
      endIndent: endIndent ?? DesignTokens.spacingLg,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
    );
  }
}