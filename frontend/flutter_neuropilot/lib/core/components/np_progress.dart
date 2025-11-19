import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum NpProgressType { primary, success, warning, destructive }

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