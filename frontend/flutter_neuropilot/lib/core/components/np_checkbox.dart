import 'package:flutter/material.dart';

/// A custom checkbox component.
///
/// Implementation Details:
/// - Wraps the Material [Checkbox] widget.
/// - Adds semantic labeling for accessibility.
///
/// Design Decisions:
/// - Uses the primary color from the theme for the active state to maintain brand consistency.
///
/// Behavioral Specifications:
/// - [onChanged] is called with the new boolean value when tapped.
/// - [value] determines the current checked state.
class NpCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  const NpCheckbox({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      checked: value,
      child: Checkbox(
        value: value,
        onChanged: onChanged,
        activeColor: cs.primary,
      ),
    );
  }
}
