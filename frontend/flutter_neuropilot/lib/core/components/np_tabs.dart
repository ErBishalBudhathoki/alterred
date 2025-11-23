import 'package:flutter/material.dart';
import '../design_tokens.dart';

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
