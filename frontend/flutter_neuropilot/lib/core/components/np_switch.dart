import 'package:flutter/material.dart';

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