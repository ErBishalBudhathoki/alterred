import 'package:flutter/material.dart';

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