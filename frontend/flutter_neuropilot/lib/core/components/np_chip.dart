import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum NpChipType { input, filter, choice }

class NpChip extends StatelessWidget {
  final String label;
  final NpChipType type;
  final bool selected;
  final VoidCallback? onTap;
  const NpChip({
    super.key,
    required this.label,
    this.type = NpChipType.filter,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface;
    final fg = selected ? DesignTokens.onPrimary : Theme.of(context).colorScheme.onSurface;
    final chip = ChoiceChip(
      label: Text(label, style: TextStyle(color: fg)),
      selected: selected,
      onSelected: (_) => onTap?.call(),
      selectedColor: bg,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusSm)),
    );
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: chip,
    );
  }
}