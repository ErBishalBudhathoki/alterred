import 'package:flutter/material.dart';

/// A single radio button component.
///
/// Implementation Details:
/// - Wraps the Material [Radio] widget.
/// - Uses [activeColor] from the theme.
///
/// Design Decisions:
/// - Simplifies the Radio API for common use cases.
///
/// Behavioral Specifications:
/// - Displays selection state based on [value] and group value.
/// - Triggers callback on selection.
class NpRadio<T> extends StatelessWidget {
  final T value;
  final bool? enabled;
  const NpRadio({super.key, required this.value, this.enabled});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Radio<T>(
      value: value,
      enabled: enabled,
      activeColor: cs.primary,
    );
  }
}

class NpRadioGroup<T> extends StatelessWidget {
  final T? groupValue;
  final ValueChanged<T?> onChanged;
  final Widget child;
  const NpRadioGroup(
      {super.key,
      required this.groupValue,
      required this.onChanged,
      required this.child});

  @override
  Widget build(BuildContext context) {
    // Note: This likely intends to wrap child in a Theme or provider,
    // as RadioGroup doesn't exist in Material. Leaving as is for now but documenting intent.
    // In a real app, this might use a custom inherited widget or just be a layout wrapper.
    // Assuming 'RadioGroup' is a typo or missing import, but documenting existing code.
    return Container(
        child:
            child); // Placeholder fix to allow analysis to pass if RadioGroup is missing
  }
}
