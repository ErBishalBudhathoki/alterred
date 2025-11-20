import 'package:flutter/material.dart';

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
  const NpRadioGroup({super.key, required this.groupValue, required this.onChanged, required this.child});

  @override
  Widget build(BuildContext context) {
    return RadioGroup<T>(groupValue: groupValue, onChanged: onChanged, child: child);
  }
}