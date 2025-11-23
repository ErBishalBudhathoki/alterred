import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_neuropilot/l10n/app_localizations.dart';
import '../core/components/np_app_bar.dart';
import '../core/components/np_button.dart';
import '../core/design_tokens.dart';
import '../state/session_state.dart';
import '../state/auth_state.dart';
import '../core/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _pulseSpeedMs = 900;
  int _pulseThresholdPercent = 20;
  double _pulseMaxFreq = 3.0;
  int? _pulseBaseColor;
  int? _pulseAlertColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = await SharedPreferences.getInstance();
      setState(() {
        _pulseSpeedMs = p.getInt('pulse_speed_ms') ?? 900;
        _pulseThresholdPercent = p.getInt('pulse_threshold_percent') ?? 20;
        _pulseMaxFreq = p.getDouble('pulse_max_freq') ?? 3.0;
        _pulseBaseColor = p.getInt('pulse_base_color');
        _pulseAlertColor = p.getInt('pulse_alert_color');
      });
    });
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('pulse_speed_ms', _pulseSpeedMs);
    await p.setInt('pulse_threshold_percent', _pulseThresholdPercent);
    await p.setDouble('pulse_max_freq', _pulseMaxFreq);
    if (_pulseBaseColor != null) {
      await p.setInt('pulse_base_color', _pulseBaseColor!);
    }
    if (_pulseAlertColor != null) {
      await p.setInt('pulse_alert_color', _pulseAlertColor!);
    }
  }

  Future<void> _logout() async {
    final ctl = ref.read(authControllerProvider);
    await ctl.signOut();
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(Routes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final user = ref.watch(authUserProvider).value;

    return Scaffold(
      appBar: NpAppBar(title: l.settingsTitle),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Section
            if (user != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: user.photoURL != null
                                ? NetworkImage(user.photoURL!)
                                : null,
                            child: user.photoURL == null
                                ? Text(
                                    user.displayName?.isNotEmpty == true
                                        ? user.displayName![0].toUpperCase()
                                        : user.email![0].toUpperCase(),
                                    style: const TextStyle(fontSize: 24))
                                : null,
                          ),
                          const SizedBox(width: DesignTokens.spacingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName ?? 'User',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  user.email ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DesignTokens.spacingMd),
                      NpButton(
                        label: 'Logout',
                        icon: Icons.logout,
                        type: NpButtonType.destructive,
                        onPressed: _logout,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spacingLg),
            ],
            Text(l.languageLabel,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: DesignTokens.spacingMd),
            RadioGroup<Locale>(
              groupValue: locale,
              onChanged: (v) async {
                ref.read(localeProvider.notifier).state = v;
                final p = await SharedPreferences.getInstance();
                if (v != null) {
                  await p.setString('locale_code',
                      '${v.languageCode}${v.countryCode != null ? '_${v.countryCode}' : ''}');
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<Locale>(
                    title: Text(l.languageEnglish),
                    value: const Locale('en'),
                    selected: locale == const Locale('en'),
                  ),
                  RadioListTile<Locale>(
                    title: Text(l.languageHindi),
                    value: const Locale('hi'),
                    selected: locale == const Locale('hi'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacingLg),
            Text('Timer Pulse', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: DesignTokens.spacingMd),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Threshold %: $_pulseThresholdPercent'),
                      Slider(
                        min: 5,
                        max: 50,
                        divisions: 45,
                        value: _pulseThresholdPercent.toDouble(),
                        onChanged: (v) =>
                            setState(() => _pulseThresholdPercent = v.round()),
                        onChangeEnd: (_) => _savePrefs(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pulse speed ms: $_pulseSpeedMs'),
                      Slider(
                        min: 300,
                        max: 1500,
                        divisions: 12,
                        value: _pulseSpeedMs.toDouble(),
                        onChanged: (v) =>
                            setState(() => _pulseSpeedMs = v.round()),
                        onChangeEnd: (_) => _savePrefs(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Max frequency: ${_pulseMaxFreq.toStringAsFixed(1)}x'),
                      Slider(
                        min: 1.0,
                        max: 4.0,
                        divisions: 30,
                        value: _pulseMaxFreq,
                        onChanged: (v) => setState(() => _pulseMaxFreq = v),
                        onChangeEnd: (_) => _savePrefs(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Base color'),
                      DropdownButton<int?>(
                        value: _pulseBaseColor,
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Default')),
                          DropdownMenuItem(
                              value: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .toARGB32(),
                              child: Row(children: [
                                Container(
                                    width: 16,
                                    height: 16,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                const Text('Primary')
                              ])),
                          DropdownMenuItem(
                              value: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .toARGB32(),
                              child: Row(children: [
                                Container(
                                    width: 16,
                                    height: 16,
                                    color:
                                        Theme.of(context).colorScheme.outline),
                                const SizedBox(width: 8),
                                const Text('Outline')
                              ])),
                        ],
                        onChanged: (v) async {
                          setState(() => _pulseBaseColor = v);
                          await _savePrefs();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DesignTokens.spacingLg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Alert color'),
                      DropdownButton<int?>(
                        value: _pulseAlertColor,
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Default')),
                          DropdownMenuItem(
                              value: Theme.of(context)
                                  .colorScheme
                                  .error
                                  .toARGB32(),
                              child: Row(children: [
                                Container(
                                    width: 16,
                                    height: 16,
                                    color: Theme.of(context).colorScheme.error),
                                const SizedBox(width: 8),
                                const Text('Error')
                              ])),
                          DropdownMenuItem(
                              value: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .toARGB32(),
                              child: Row(children: [
                                Container(
                                    width: 16,
                                    height: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary),
                                const SizedBox(width: 8),
                                const Text('Secondary')
                              ])),
                        ],
                        onChanged: (v) async {
                          setState(() => _pulseAlertColor = v);
                          await _savePrefs();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacingSm),
            Align(
              alignment: Alignment.centerRight,
              child: NpButton(
                  label: 'Save',
                  icon: Icons.save,
                  onPressed: () async {
                    await _savePrefs();
                  }),
            ),
          ],
        ),
      ),
    );
  }
}
