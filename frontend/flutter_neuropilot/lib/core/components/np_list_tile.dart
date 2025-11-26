import 'package:flutter/material.dart';
import '../design_tokens.dart';

/// A single fixed-height row that typically contains some text as well as a leading or trailing icon.
///
/// Implementation Details:
/// - Wraps the standard [ListTile] widget.
/// - Adds custom padding and border radius.
///
/// Design Decisions:
/// - Consistent typography scaling via [Theme.textTheme].
/// - Enforces spacing guidelines from [DesignTokens].
///
/// Behavioral Specifications:
/// - Supports tap interaction via [onTap].
/// - Handles optional leading/trailing widgets.
class NpListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  const NpListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingLg,
        vertical: DesignTokens.spacingSm,
      ),
      leading: leading,
      title: Text(title, style: t.titleLarge),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
    );
    return semanticsLabel == null
        ? tile
        : Semantics(
            label: semanticsLabel,
            button: onTap != null,
            child: tile,
          );
  }
}