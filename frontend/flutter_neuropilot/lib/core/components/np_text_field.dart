import 'package:flutter/material.dart';
import '../design_tokens.dart';

/// A standard single-line text input field.
///
/// Implementation Details:
/// - Wraps the standard [TextField] widget.
/// - Configurable for different input types (text, email, number).
///
/// Design Decisions:
/// - Uniform border radius and padding via [DesignTokens].
/// - Outline border style provides clear boundaries.
///
/// Behavioral Specifications:
/// - Updates the [controller] text as user types.
/// - Triggers [onSubmitted] when "Done" or "Enter" is pressed.
class NpTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  const NpTextField(
      {super.key,
      required this.controller,
      required this.label,
      this.keyboardType,
      this.onSubmitted,
      this.textInputAction,
      this.focusNode});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
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
