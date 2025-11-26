import 'package:flutter/material.dart';
import '../design_tokens.dart';

/// A set of tab buttons for navigation within a screen.
///
/// Implementation Details:
/// - Wraps [TabBar] with custom styling.
/// - Requires a [TabController] to manage state.
///
/// Design Decisions:
/// - Uses a custom underline indicator with specific insets.
/// - Clearly distinguishes selected vs unselected tabs via color.
///
/// Behavioral Specifications:
/// - Updates the [controller] index on tap.
/// - Animates the indicator between tabs.
class NpTabs extends StatelessWidget {
  final List<Tab> tabs;
  final TabController controller;
  const NpTabs({super.key, required this.tabs, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      tabs: tabs,
      labelColor: Theme.of(context).colorScheme.primary,
      unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3),
        insets: const EdgeInsets.symmetric(horizontal: DesignTokens.spacingLg),
      ),
    );
  }
}
