import 'package:flutter/material.dart';

/// A toggle switch for boolean settings.
///
/// Implementation Details:
/// - Wraps the standard [Switch] widget.
/// - Adds semantic labeling for accessibility.
///
/// Design Decisions:
/// - Uses the primary color for the active thumb to ensure visibility.
///
/// Behavioral Specifications:
/// - Toggles between on/off states when tapped.
/// - Calls [onChanged] with the new value.
class NpSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const NpSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      toggled: value,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: cs.primary,
      ),
    );
  }
}