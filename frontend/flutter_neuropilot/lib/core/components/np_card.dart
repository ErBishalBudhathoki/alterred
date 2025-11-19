import 'package:flutter/material.dart';
import '../design_tokens.dart';

class NpCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const NpCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: DesignTokens.elevationMd,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusMd)),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingLg),
          child: child,
        ),
      ),
    );
  }
}