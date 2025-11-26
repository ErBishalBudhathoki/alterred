import 'package:flutter/material.dart';
import '../design_tokens.dart';

/// A container for grouping related content.
///
/// Implementation Details:
/// - Wraps [Card] with [InkWell] for optional interactivity.
/// - Enforces consistent padding and border radius.
///
/// Design Decisions:
/// - Elevation and rounding are standardized via [DesignTokens].
/// - [InkWell] splash effect provides touch feedback.
///
/// Behavioral Specifications:
/// - Triggers [onTap] if provided.
/// - Renders arbitrary [child] content.
class NpCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const NpCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: DesignTokens.elevationMd,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusMd)),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingLg),
          child: child,
        ),
      ),
    );
  }
}