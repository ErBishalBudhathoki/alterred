import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_tokens.dart';
import '../core/components/character_avatar.dart';
import '../state/user_settings_store.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);
    final selectedStyle = CharacterStyle.values.firstWhere(
      (e) => e.toString().split('.').last == settings.characterStyle,
      orElse: () => CharacterStyle.tech,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignTokens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: DesignTokens.spacingXl),
            // Profile Avatar
            CharacterAvatar(
              style: selectedStyle,
              size: 160,
              primaryColor: Theme.of(context).colorScheme.primary,
              secondaryColor: Theme.of(context).colorScheme.surface,
            ),
            const SizedBox(height: DesignTokens.spacingLg),
            Text(
              'Customize Your Avatar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: DesignTokens.spacingMd),
            Text(
              'Select a character template:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DesignTokens.spacingLg),

            // Character Selector
            Wrap(
              spacing: DesignTokens.spacingMd,
              runSpacing: DesignTokens.spacingMd,
              alignment: WrapAlignment.center,
              children: CharacterStyle.values.map((style) {
                final isSelected = style == selectedStyle;
                return GestureDetector(
                  onTap: () {
                    ref.read(userSettingsProvider.notifier).update(
                          (s) => s.copyWith(
                              characterStyle: style.toString().split('.').last),
                        );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? DesignTokens.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: CharacterAvatar(
                      style: style,
                      size: 60,
                      primaryColor: isSelected
                          ? DesignTokens.primary
                          : DesignTokens.secondary,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: DesignTokens.spacing2Xl),

            // Additional Options
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Theme Settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navigate to theme settings or open modal
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.security_outlined),
              title: const Text('Security & Privacy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navigate to security settings
              },
            ),
          ],
        ),
      ),
    );
  }
}
