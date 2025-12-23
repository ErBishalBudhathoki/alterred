import 'package:flutter/material.dart';

/// A radio group inherited widget to pass down group value and change handler.
class NpRadioGroup<T> extends InheritedWidget {
  final T? groupValue;
  final ValueChanged<T?> onChanged;

  const NpRadioGroup({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required super.child,
  });

  static NpRadioGroup<T>? of<T>(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NpRadioGroup<T>>();
  }

  @override
  bool updateShouldNotify(NpRadioGroup<T> oldWidget) {
    return groupValue != oldWidget.groupValue ||
        onChanged != oldWidget.onChanged;
  }
}

/// A single radio button component.
///
/// Implementation Details:
/// - Wraps the Material [Radio] widget.
/// - Uses [activeColor] from the theme.
/// - Consumes [NpRadioGroup] for group value and callbacks.
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
    final group = NpRadioGroup.of<T>(context);
    // If used outside a NpRadioGroup, this will throw or be disabled.
    // Ideally we should assert group != null, but for now we handle gracefully if possible
    // or let standard Radio fail if params are null (Radio requires groupValue/onChanged).

    final cs = Theme.of(context).colorScheme;
    // ignore: deprecated_member_use
    return Radio<T>(
      value: value,
      // ignore: deprecated_member_use
      groupValue: group?.groupValue,
      // ignore: deprecated_member_use
      onChanged: group?.onChanged,
      enabled: enabled,
      activeColor: cs.primary,
    );
  }
}
