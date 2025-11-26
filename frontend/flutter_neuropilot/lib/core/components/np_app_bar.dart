import 'package:flutter/material.dart';
import '../design_tokens.dart';

/// A custom app bar implementing the NeuroPilot design language.
///
/// Implementation Details:
/// - Extends [StatelessWidget] and implements [PreferredSizeWidget].
/// - Wraps the Material [AppBar] with custom styling and spacing.
///
/// Design Decisions:
/// - Consistent height and title typography.
/// - Standardized action padding via [DesignTokens].
///
/// Behavioral Specifications:
/// - Displays a back button if [showBack] is true.
/// - Renders [actions] with uniform spacing.
class NpAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  const NpAppBar(
      {super.key, required this.title, this.actions, this.showBack = true});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBack,
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      actions: actions
          ?.map((w) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacingSm),
                child: w,
              ))
          .toList(),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
