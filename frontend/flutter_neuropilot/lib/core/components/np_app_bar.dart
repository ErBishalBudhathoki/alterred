import 'package:flutter/material.dart';
import '../design_tokens.dart';

class NpAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const NpAppBar({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      actions: actions
          ?.map((w) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacingSm),
                child: w,
              ))
          .toList(),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}