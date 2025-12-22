import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum NpChipType { input, filter, choice }

/// A compact element for representing an attribute, action, or filter.
///
/// Implementation Details:
/// - Uses [ChoiceChip] for the underlying interaction model.
/// - Supports different semantic types (input, filter, choice) via [NpChipType].
///
/// Design Decisions:
/// - Selected state inverts colors (primary background, white text) for strong visual feedback.
/// - Rounded corners match the "organic" feel of the design system.
///
/// Behavioral Specifications:
/// - Triggers [onTap] when selected.
/// - Updates visual appearance based on [selected] state.
class NpChip extends StatelessWidget {
  final String label;
  final NpChipType type;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  const NpChip({
    super.key,
    required this.label,
    this.type = NpChipType.filter,
    this.selected = false,
    this.onTap,
    this.semanticsLabel,
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
      label: semanticsLabel ?? label,
      selected: selected,
      button: true,
      child: chip,
    );
  }
}