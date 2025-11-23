import 'package:flutter/material.dart';
import '../design_tokens.dart';

class NpTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  const NpTextField({super.key, required this.controller, required this.label, this.keyboardType, this.onSubmitted, this.textInputAction});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingLg,
          vertical: DesignTokens.spacingSm,
        ),
      ),
    );
  }
}
