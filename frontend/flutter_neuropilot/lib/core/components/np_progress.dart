import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum NpProgressType { primary, success, warning, destructive }

/// A linear progress indicator with semantic coloring.
///
/// Implementation Details:
/// - Wraps [LinearProgressIndicator].
/// - Maps [NpProgressType] to theme colors.
///
/// Design Decisions:
/// - Semantic colors allow indicating status (e.g., error vs loading) implicitly.
///
/// Behavioral Specifications:
/// - Indeterminate animation if [value] is null.
class NpLinearProgress extends StatelessWidget {
  final double? value;
  final NpProgressType type;
  const NpLinearProgress({super.key, this.value, this.type = NpProgressType.primary});

  Color _color(BuildContext context) => switch (type) {
        NpProgressType.primary => Theme.of(context).colorScheme.primary,
        NpProgressType.success => DesignTokens.success,
        NpProgressType.warning => DesignTokens.warning,
        NpProgressType.destructive => DesignTokens.error,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color(context);
    return LinearProgressIndicator(
      value: value,
      color: c,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

/// A circular progress indicator with semantic coloring.
///
/// Implementation Details:
/// - Wraps [CircularProgressIndicator].
/// - Maps [NpProgressType] to theme colors.
///
/// Design Decisions:
/// - Consistent stroke width and coloring with linear variant.
///
/// Behavioral Specifications:
/// - Indeterminate animation if [value] is null.
class NpCircularProgress extends StatelessWidget {
  final double? value;
  final NpProgressType type;
  const NpCircularProgress({super.key, this.value, this.type = NpProgressType.primary});

  Color _color(BuildContext context) => switch (type) {
        NpProgressType.primary => Theme.of(context).colorScheme.primary,
        NpProgressType.success => DesignTokens.success,
        NpProgressType.warning => DesignTokens.warning,
        NpProgressType.destructive => DesignTokens.error,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color(context);
    return CircularProgressIndicator(
      value: value,
      color: c,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      strokeWidth: 3,
    );
  }
}