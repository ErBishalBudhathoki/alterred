import 'package:flutter/material.dart';
import '../design_tokens.dart';

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