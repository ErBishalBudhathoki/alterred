import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:altered/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/components/np_app_bar.dart';
import '../core/components/np_button.dart';
import '../core/design_tokens.dart';
import '../state/session_state.dart';
import '../state/auth_state.dart';
import '../core/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/chat_store.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/oauth_service.dart';

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
  bool _googleSearchEnabled = false;
  bool _firestoreSyncEnabled = false;
  
  // Calendar OAuth state
  bool _calendarConnected = false;
  bool _loadingCalendarStatus = true;
  
  // API Key state
  bool _hasCustomApiKey = false;
  bool _loadingApiKeyStatus = true;
  String _apiKeyInput = '';
  bool _validatingApiKey = false;
  
  // OAuth service
  final _oauthService = OAuthService();

  @override
  void initState() {
    super.initState();
    
    // Initialize OAuth service with callback handler
    _oauthService.initialize(onCallback: _handleOAuthCallback);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = await SharedPreferences.getInstance();
      setState(() {
        _pulseSpeedMs = p.getInt('pulse_speed_ms') ?? 900;
        _pulseThresholdPercent = p.getInt('pulse_threshold_percent') ?? 20;
        _pulseMaxFreq = p.getDouble('pulse_max_freq') ?? 3.0;
        _pulseBaseColor = p.getInt('pulse_base_color');
        _pulseAlertColor = p.getInt('pulse_alert_color');
        _googleSearchEnabled = p.getBool('google_search_enabled') ?? false;
        _firestoreSyncEnabled = p.getBool('firestore_sync_enabled') ?? false;
      });
      ref.read(googleSearchEnabledProvider.notifier).state =
          _googleSearchEnabled;
      ref.read(firestoreSyncEnabledProvider.notifier).state =
          _firestoreSyncEnabled;
      
      // Load calendar status
      _loadCalendarStatus();
      
      // Load API key status
      _loadApiKeyStatus();
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
    await p.setBool('google_search_enabled', _googleSearchEnabled);
    await p.setBool('firestore_sync_enabled', _firestoreSyncEnabled);
  }

  Future<void> _logout() async {
    final ctl = ref.read(authControllerProvider);
    final store = ref.read(chatStoreProvider);
    try {
      await store.disposeListeners();
    } catch (_) {}
    setState(() => _firestoreSyncEnabled = false);
    ref.read(firestoreSyncEnabledProvider.notifier).state = false;
    await _savePrefs();
    await ctl.signOut();
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(Routes.login, (route) => false);
    }
  }

  Future<void> _loadCalendarStatus() async {
    try {
      final response = await ref.read(apiClientProvider).get('/auth/google/calendar/status');
      if (mounted && response['ok'] == true) {
        setState(() {
          _calendarConnected = response['connected'] == true;
          _loadingCalendarStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCalendarStatus = false);
      }
    }
  }

  Future<void> _connectCalendar() async {
    try {
      // Determine platform
      final platform = kIsWeb ? 'web' : 'mobile';
      
      // Get authorization URL from backend
      final response = await ref.read(apiClientProvider).get(
        '/auth/google/calendar?platform=$platform'
      );
      
      if (response['ok'] == true && response['authorization_url'] != null) {
        final authUrl = response['authorization_url'];
        
        // Launch OAuth flow
        final launched = await _oauthService.startOAuthFlow(authUrl);
        
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to open authorization page')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Handle OAuth callback from deep link or redirect
  Future<void> _handleOAuthCallback(Uri callbackUri) async {
    try {
      // Extract authorization code
      final code = _oauthService.handleWebCallback(callbackUri);
      final state = _oauthService.extractState(callbackUri);
      final error = _oauthService.extractError(callbackUri);
      
      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OAuth error: $error')),
          );
        }
        return;
      }
      
      if (code == null || state == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid OAuth callback')),
          );
        }
        return;
      }
      
      // Exchange code for tokens on backend
      final response = await ref.read(apiClientProvider).get(
        '/auth/google/calendar/callback?code=$code&state=$state'
      );
      
      if (response['ok'] == true) {
        setState(() => _calendarConnected = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Calendar connected successfully!')),
          );
        }
        _loadCalendarStatus();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect: ${response['error']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _disconnectCalendar() async {
    try {
      await ref.read(apiClientProvider).delete('/auth/google/calendar');
      setState(() => _calendarConnected = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calendar disconnected')),
        );
      }
      _loadCalendarStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _loadApiKeyStatus() async {
    try {
      final response = await ref.read(apiClientProvider).get('/settings/api-key/status');
      if (mounted && response['ok'] == true) {
        setState(() {
          _hasCustomApiKey = response['has_custom_key'] == true;
          _loadingApiKeyStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingApiKeyStatus = false);
      }
    }
  }

  Future<void> _saveApiKey() async {
    if (_apiKeyInput.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API key')),
      );
      return;
    }

    setState(() => _validatingApiKey = true);
    
    try {
      final response = await ref.read(apiClientProvider).post(
        '/settings/api-key',
        {'api_key': _apiKeyInput.trim()},
      );
      
      setState(() => _validatingApiKey = false);
      
      if (response['ok'] == true) {
        setState(() {
          _hasCustomApiKey = true;
          _apiKeyInput = '';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('API key saved successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['error'] ?? 'Failed to save API key')),
          );
        }
      }
    } catch (e) {
      setState(() => _validatingApiKey = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteApiKey() async {
    try {
      await ref.read(apiClientProvider).delete('/settings/api-key');
      setState(() {
        _hasCustomApiKey = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final user = ref.watch(authUserProvider).value;
    final projectId = Firebase.app().options.projectId;

    return Scaffold(
      appBar: NpAppBar(title: l.settingsTitle),
      body: SingleChildScrollView(
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
                      const SizedBox(height: DesignTokens.spacingSm),
                      Text('Firebase: uid=${user.uid} project=$projectId',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spacingLg),
            ],
            
            // Calendar Integration Section
            if (user != null) ...[
              Text('Calendar Integration',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: DesignTokens.spacingMd),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 32),
                          const SizedBox(width: DesignTokens.spacingMd),
                          Expanded(
                            child: Text(
                              'Google Calendar',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (_loadingCalendarStatus)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _calendarConnected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _calendarConnected ? 'Connected' : 'Not Connected',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: _calendarConnected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: DesignTokens.spacingMd),
                      Text(
                        _calendarConnected
                            ? 'Your calendar is connected. The app can create and read events from your Google Calendar.'
                            : 'Connect your Google Calendar to enable calendar features like creating events and viewing your schedule.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: DesignTokens.spacingMd),
                      if (_calendarConnected)
                        NpButton(
                          label: 'Disconnect Calendar',
                          icon: Icons.link_off,
                          type: NpButtonType.secondary,
                          onPressed: _disconnectCalendar,
                        )
                      else
                        NpButton(
                          label: 'Connect Google Calendar',
                          icon: Icons.link,
                          onPressed: _connectCalendar,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spacingLg),
            ],
            
            // API Key Configuration Section
            if (user != null) ...[
              Text('API Configuration',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: DesignTokens.spacingMd),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.key, size: 32),
                          const SizedBox(width: DesignTokens.spacingMd),
                          Expanded(
                            child: Text(
                              'Gemini API Key',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (_loadingApiKeyStatus)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _hasCustomApiKey
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _hasCustomApiKey ? 'Custom Key' : 'System Default',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: _hasCustomApiKey
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: DesignTokens.spacingMd),
                      Text(
                        _hasCustomApiKey
                            ? 'You are using your own Gemini API key. This ensures your usage is separate from the shared quota.'
                            : 'Using the system default API key. You can provide your own key for dedicated quota.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: DesignTokens.spacingMd),
                      if (_hasCustomApiKey) ...[
                        Row(
                          children: [
                            Expanded(
                              child: NpButton(
                                label: 'Remove Custom Key',
                                icon: Icons.delete_outline,
                                type: NpButtonType.destructive,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Remove API Key?'),
                                      content: const Text(
                                        'This will remove your custom API key and fall back to the system default.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _deleteApiKey();
                                          },
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Enter your Gemini API Key',
                            hintText: 'AIza...',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          onChanged: (value) => _apiKeyInput = value,
                        ),
                        const SizedBox(height: DesignTokens.spacingSm),
                        Text(
                          'Get your API key from Google AI Studio',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: DesignTokens.spacingMd),
                        Row(
                          children: [
                            Expanded(
                              child: NpButton(
                                label: _validatingApiKey ? 'Validating...' : 'Save API Key',
                                icon: _validatingApiKey ? null : Icons.save,
                                onPressed: _validatingApiKey ? null : _saveApiKey,
                              ),
                            ),
                          ],
                        ),
                      ],
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
            Row(children: [
              Expanded(
                child: SwitchListTile(
                  title: const Text('Google Search'),
                  value: _googleSearchEnabled,
                  onChanged: (v) async {
                    setState(() => _googleSearchEnabled = v);
                    ref.read(googleSearchEnabledProvider.notifier).state = v;
                    await _savePrefs();
                  },
                ),
              ),
            ]),
            const SizedBox(height: DesignTokens.spacingMd),
            Row(children: [
              Expanded(
                child: SwitchListTile(
                  title: const Text('Firestore Sync'),
                  value: _firestoreSyncEnabled,
                  subtitle:
                      user == null ? const Text('Sign in required') : null,
                  onChanged: user == null
                      ? null
                      : (v) async {
                          setState(() => _firestoreSyncEnabled = v);
                          ref
                              .read(firestoreSyncEnabledProvider.notifier)
                              .state = v;
                          final store = ref.read(chatStoreProvider);
                          if (v) {
                            try {
                              await store.attachSessionsListener();
                            } catch (_) {}
                          } else {
                            await store.disposeListeners();
                          }
                          await _savePrefs();
                        },
                ),
              ),
            ]),
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
