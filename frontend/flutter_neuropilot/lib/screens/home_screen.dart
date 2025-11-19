import 'package:flutter/material.dart';
import '../core/routes.dart';
import '../core/design_tokens.dart';
import '../core/components/np_card.dart';
import '../core/components/np_app_bar.dart';
import 'package:flutter_neuropilot/l10n/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: NpAppBar(title: l.appTitle),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLg),
        child: GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          crossAxisSpacing: DesignTokens.spacingMd,
          mainAxisSpacing: DesignTokens.spacingMd,
          children: [
            _tile(context, l.homeTaskFlow, Routes.taskflow, Icons.checklist),
            _tile(context, l.homeTime, Routes.time, Icons.timer),
            _tile(context, l.homeDecision, Routes.decision, Icons.assignment),
            _tile(context, l.homeExternal, Routes.external, Icons.library_books),
            _tile(context, l.settingsTitle, Routes.settings, Icons.settings),
            _tile(context, l.healthTitle, Routes.health, Icons.health_and_safety),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext ctx, String title, String route, IconData icon) => NpCard(
        onTap: () => Navigator.of(ctx).pushNamed(route),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: DesignTokens.spacingSm),
            Text(title),
          ],
        ),
      );
}