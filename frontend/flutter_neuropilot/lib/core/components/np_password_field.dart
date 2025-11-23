import 'package:flutter/material.dart';
import '../design_tokens.dart';

class NpPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const NpPasswordField({super.key, required this.controller, required this.label});

  @override
  State<NpPasswordField> createState() => _NpPasswordFieldState();
}

class _NpPasswordFieldState extends State<NpPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        labelText: widget.label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingLg,
          vertical: DesignTokens.spacingSm,
        ),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
