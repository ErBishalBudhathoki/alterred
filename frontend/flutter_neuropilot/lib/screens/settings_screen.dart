import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:altered/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/components/np_avatar.dart';
import '../core/design_tokens.dart';
import '../state/session_state.dart';
import '../state/auth_state.dart';
import '../core/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/chat_store.dart';
import '../state/user_settings_store.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/oauth_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Screen for application settings and configuration.
///
/// Implementation Details:
/// - Manages user preferences using [SharedPreferences].
/// - Handles Google Calendar integration via OAuth flow.
/// - Allows configuration of API keys and UI preferences (e.g., pulse animation).
///
/// Design Decisions:
/// - Uses [ConsumerStatefulWidget] to reactively update UI based on provider state.
/// - Separates sections (Profile, Calendar, API) for clarity.
/// - OAuth flow handles both web (redirect) and mobile (deep link) scenarios.
///
/// Behavioral Specifications:
/// - Loads preferences on init.
/// - Saves preferences immediately on change or explicit save action.
/// - Manages OAuth callback handling for calendar connection.
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
  bool _mcpReady = false;
  bool _hasCalendarTokens = false;
  String? _calendarExpiresAt;
  String? _calendarValidateStatus;
  bool _calendarShowDetails = false;
  String? _calendarBannerMessage;
  String? _googleEmail;
  bool _loadingGoogleEmail = false;

  // Credit balance state
  int _creditBalance = 0;
  bool _loadingCreditBalance = true;

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
      // Load settings from store (cloud-first if logged in)
      if (!mounted) return;
      final store = ref.read(userSettingsStoreProvider);
      final settings = await store.loadSettings();

      if (!mounted) return;
      setState(() {
        _pulseSpeedMs = settings.pulseSpeedMs;
        _pulseThresholdPercent = settings.pulseThresholdPercent;
        _pulseMaxFreq = settings.pulseMaxFreq;
        _pulseBaseColor = settings.pulseBaseColor;
        _pulseAlertColor = settings.pulseAlertColor;
        _googleSearchEnabled = settings.googleSearchEnabled;
        _firestoreSyncEnabled = settings.firestoreSyncEnabled;
      });

      ref.read(googleSearchEnabledProvider.notifier).state =
          _googleSearchEnabled;
      ref.read(firestoreSyncEnabledProvider.notifier).state =
          _firestoreSyncEnabled;
      ref.read(userSettingsProvider.notifier).state = settings;

      // Attach listener for real-time sync if enabled
      if (_firestoreSyncEnabled) {
        await store.attachListener((updatedSettings) {
          if (!mounted) return;
          setState(() {
            _pulseSpeedMs = updatedSettings.pulseSpeedMs;
            _pulseThresholdPercent = updatedSettings.pulseThresholdPercent;
            _pulseMaxFreq = updatedSettings.pulseMaxFreq;
            _pulseBaseColor = updatedSettings.pulseBaseColor;
            _pulseAlertColor = updatedSettings.pulseAlertColor;
            _googleSearchEnabled = updatedSettings.googleSearchEnabled;
            _firestoreSyncEnabled = updatedSettings.firestoreSyncEnabled;
          });
          ref.read(googleSearchEnabledProvider.notifier).state =
              _googleSearchEnabled;
          ref.read(firestoreSyncEnabledProvider.notifier).state =
              _firestoreSyncEnabled;
          ref.read(userSettingsProvider.notifier).state = updatedSettings;
        });
      }

      // Load calendar status
      _loadCalendarStatus();

      // Load credit balance
      _loadCreditBalance();

      // Load API key status
      _loadApiKeyStatus();
    });
  }

  Future<void> _savePrefs() async {
    final store = ref.read(userSettingsStoreProvider);
    final currentSettings = ref.read(userSettingsProvider);

    final updatedSettings = currentSettings.copyWith(
      pulseSpeedMs: _pulseSpeedMs,
      pulseThresholdPercent: _pulseThresholdPercent,
      pulseMaxFreq: _pulseMaxFreq,
      pulseBaseColor: _pulseBaseColor,
      pulseAlertColor: _pulseAlertColor,
      googleSearchEnabled: _googleSearchEnabled,
      firestoreSyncEnabled: _firestoreSyncEnabled,
    );

    await store.saveSettings(updatedSettings);
    ref.read(userSettingsProvider.notifier).state = updatedSettings;
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await ref
          .read(apiClientProvider)
          .get('/auth/google/calendar/status?_=$timestamp');
      if (mounted && response['ok'] == true) {
        setState(() {
          _calendarConnected = response['connected'] == true;
          _loadingCalendarStatus = false;
          final d = response['details'] ?? {};
          _hasCalendarTokens = d['has_tokens'] == true;
          _calendarExpiresAt = d['expires_at'];
          _mcpReady = d['mcp_ready'] == true;
        });
        if (_calendarConnected) {
          _loadGoogleEmail();
        } else {
          setState(() => _googleEmail = null);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCalendarStatus = false);
      }
    }
  }

  Future<void> _connectCalendar() async {
    try {
      // Ensure auth token is available
      await ref.read(idTokenSyncProvider.future);
      // Determine platform
      const platform = kIsWeb ? 'web' : 'mobile';

      // Get authorization URL from backend
      final response = await ref
          .read(apiClientProvider)
          .get('/auth/google/calendar?platform=$platform');

      if (response['ok'] == true && response['authorization_url'] != null) {
        final authUrl = response['authorization_url'];

        // Launch OAuth flow
        final launched = await _oauthService.startOAuthFlow(authUrl);

        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to open authorization page')),
          );
        }

        // For web flows where callback returns to backend, poll connection status
        if (mounted && kIsWeb) {
          var attempts = 0;
          const maxAttempts = 30; // ~60 seconds
          while (attempts < maxAttempts) {
            await Future.delayed(const Duration(seconds: 2));
            try {
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final status = await ref
                  .read(apiClientProvider)
                  .get('/auth/google/calendar/status?_=$timestamp');
              if (status['ok'] == true && status['connected'] == true) {
                if (!mounted) break;
                setState(() => _calendarConnected = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Calendar connected successfully!')),
                );
                _loadGoogleEmail();
                break;
              }
            } catch (_) {}
            attempts++;
          }
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

  Future<void> _validateCalendar() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .get('/auth/google/calendar/validate');
      if (!mounted) return;
      if (response['ok'] == true) {
        setState(() {
          _calendarValidateStatus = response['status'];
          _calendarConnected = response['connected'] == true;
          _calendarBannerMessage = _calendarConnected
              ? 'Calendar connected successfully'
              : 'Re-authentication required';
        });
        await _loadCalendarStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_calendarBannerMessage!)),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Validation error: $e')),
      );
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
      final response = await ref
          .read(apiClientProvider)
          .get('/auth/google/calendar/callback?code=$code&state=$state');

      if (response['ok'] == true) {
        setState(() {
          _calendarConnected = true;
          _calendarBannerMessage = 'Calendar connected successfully!';
        });
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
      setState(() => _googleEmail = null);
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

  Future<void> _loadGoogleEmail() async {
    try {
      setState(() => _loadingGoogleEmail = true);
      final r = await ref.read(apiClientProvider).get('/auth/google/userinfo');
      if (!mounted) return;
      if (r['ok'] == true) {
        setState(() {
          _googleEmail = r['email'] as String?;
          _loadingGoogleEmail = false;
        });
      } else {
        setState(() {
          _googleEmail = null;
          _loadingGoogleEmail = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingGoogleEmail = false);
    }
  }

  Future<void> _loadCreditBalance() async {
    try {
      final response =
          await ref.read(apiClientProvider).get('/credits/balance');
      if (mounted && response['ok'] == true) {
        setState(() {
          _creditBalance = (response['balance'] ?? 0).toInt();
          _loadingCreditBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCreditBalance = false);
      }
    }
  }

  Future<void> _loadApiKeyStatus() async {
    try {
      final response =
          await ref.read(apiClientProvider).get('/settings/api-key/status');
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
            SnackBar(
                content: Text(response['error'] ?? 'Failed to save API key')),
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(l.settingsTitle),
            centerTitle: false,
            surfaceTintColor: Colors.transparent,
            floating: true,
            snap: true,
          ),
          SliverPadding(
            padding:
                const EdgeInsets.symmetric(horizontal: DesignTokens.spacingLg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // User Profile
                if (user != null)
                  _SettingsSection(
                    title: 'Profile',
                    icon: Icons.person_outline,
                    delay: 0.ms,
                    children: [
                      _buildProfileCard(context, user, projectId),
                    ],
                  ),

                // Calendar
                if (user != null)
                  _SettingsSection(
                    title: 'Calendar',
                    icon: Icons.calendar_today_outlined,
                    delay: 100.ms,
                    children: [
                      _buildCalendarCard(context),
                    ],
                  ),

                // Usage
                if (user != null)
                  _SettingsSection(
                    title: 'Usage & Credits',
                    icon: Icons.stars_outlined,
                    delay: 200.ms,
                    children: [
                      _buildUsageCard(context),
                    ],
                  ),

                // API Key
                if (user != null)
                  _SettingsSection(
                    title: 'API Configuration',
                    icon: Icons.key_outlined,
                    delay: 300.ms,
                    children: [
                      _buildApiKeyCard(context),
                    ],
                  ),

                // Language
                _SettingsSection(
                  title: l.languageLabel,
                  icon: Icons.language_outlined,
                  delay: 400.ms,
                  children: [
                    _buildLanguageCard(context, locale, l),
                  ],
                ),

                // Preferences
                _SettingsSection(
                  title: 'Preferences',
                  icon: Icons.tune_outlined,
                  delay: 500.ms,
                  children: [
                    _buildPreferencesCard(context, user),
                  ],
                ),

                // Advanced Visuals (Pulse)
                _SettingsSection(
                  title: 'Visuals',
                  icon: Icons.visibility_outlined,
                  delay: 600.ms,
                  children: [
                    _buildPulseSettingsCard(context),
                  ],
                ),

                const SizedBox(height: 100), // Bottom padding
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
      BuildContext context, dynamic user, String projectId) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: _glassDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Hero(
                tag: 'profile_avatar',
                child: NpAvatar(
                  name: user.displayName ?? user.email,
                  imageUrl: user.photoURL,
                  size: 64,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(width: DesignTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName ?? 'User',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      user.email ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Logout',
                style: IconButton.styleFrom(
                  foregroundColor: DesignTokens.error,
                  backgroundColor: DesignTokens.error.withOpacity(0.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          const SizedBox(height: DesignTokens.spacingXs),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     Text(
          //       'Project ID',
          //       style: Theme.of(context).textTheme.labelSmall,
          //     ),
          //     Text(
          //       projectId,
          //       style: Theme.of(context).textTheme.labelSmall?.copyWith(
          //             fontFamily: 'monospace',
          //             color: Theme.of(context).colorScheme.primary,
          //           ),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: _glassDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _calendarConnected
                      ? DesignTokens.success.withOpacity(0.1)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: _calendarConnected
                      ? DesignTokens.success
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              )
                  .animate(target: _calendarConnected ? 1 : 0)
                  .scale(curve: Curves.easeOutBack),
              const SizedBox(width: DesignTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Calendar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _calendarConnected ? 'Connected' : 'Not Connected',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _calendarConnected
                                ? DesignTokens.success
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontWeight: _calendarConnected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                    ).animate(target: _calendarConnected ? 1 : 0).fadeIn(),
                  ],
                ),
              ),
              if (_loadingCalendarStatus)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Text(
            _calendarConnected
                ? 'Your calendar is synced. The AI can help you manage your schedule.'
                : 'Connect to enable AI scheduling assistance.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          if (_calendarConnected) ...[
            if (_googleEmail != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _googleEmail!,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: DesignTokens.spacingMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _disconnectCalendar,
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text('Disconnect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesignTokens.error,
                      side: const BorderSide(color: DesignTokens.error),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _connectCalendar,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Connect Calendar'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: DesignTokens.onPrimary,
                ),
              ),
            ),

          // Validation & More
          if (_calendarConnected) ...[
            const SizedBox(height: DesignTokens.spacingSm),
            ExpansionTile(
              title: Text('Connection Details',
                  style: Theme.of(context).textTheme.labelMedium),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              shape: const Border(),
              children: [
                _buildDetailRow(
                    'Tokens', _hasCalendarTokens ? 'Present' : 'Missing'),
                if (_calendarExpiresAt != null)
                  _buildDetailRow('Expires', _calendarExpiresAt!),
                _buildDetailRow(
                    'MCP Status', _mcpReady ? 'Ready' : 'Unavailable'),
                if (_calendarValidateStatus != null)
                  _buildDetailRow('Validation', _calendarValidateStatus!),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _validateCalendar,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Validate Connection'),
                    ),
                  ],
                )
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildUsageCard(BuildContext context) {
    final color = _creditBalance > 2
        ? DesignTokens.success
        : _creditBalance > 0
            ? DesignTokens.warning
            : DesignTokens.error;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: _glassDecoration(context),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Free Credits',
                  style: Theme.of(context).textTheme.titleMedium),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 16, color: color),
                    const SizedBox(width: 4),
                    Text(
                      '$_creditBalance',
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.bold),
                    )
                        .animate(key: ValueKey(_creditBalance))
                        .scale(duration: 200.ms, curve: Curves.easeOutBack),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          LinearProgressIndicator(
            value: (_creditBalance / 10)
                .clamp(0.0, 1.0), // Assuming 10 is max for visual
            backgroundColor: Theme.of(context).dividerColor.withOpacity(0.1),
            color: color,
            borderRadius: BorderRadius.circular(4),
          ).animate(key: ValueKey(_creditBalance)).shimmer(duration: 1000.ms),
          const SizedBox(height: DesignTokens.spacingSm),
          Text(
            _creditBalance > 0
                ? 'Each interaction uses 1 credit.'
                : 'You have used all your free credits.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: _glassDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _hasCustomApiKey
                    ? Icons.vpn_key_rounded
                    : Icons.vpn_key_off_rounded,
                color: _hasCustomApiKey
                    ? DesignTokens.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: DesignTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasCustomApiKey
                          ? 'Custom API Key Active'
                          : 'Using System Key',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _hasCustomApiKey
                          ? 'Unlimited usage enabled'
                          : 'Limited to free quota',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          if (_hasCustomApiKey)
            OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove API Key?'),
                    content: const Text(
                        'This will revert to the limited system quota.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
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
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove Custom Key'),
              style:
                  OutlinedButton.styleFrom(foregroundColor: DesignTokens.error),
            )
          else
            Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Gemini API Key',
                    hintText: 'AIza...',
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusSm)),
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surface.withOpacity(0.5),
                  ),
                  obscureText: true,
                  onChanged: (v) => _apiKeyInput = v,
                ),
                const SizedBox(height: DesignTokens.spacingSm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _validatingApiKey ? null : _saveApiKey,
                    child: _validatingApiKey
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save API Key'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(
      BuildContext context, Locale? locale, AppLocalizations l) {
    return Container(
      decoration: _glassDecoration(context),
      child: Column(
        children: [
          RadioListTile<Locale>(
            title: Text(l.languageEnglish),
            value: const Locale('en'),
            groupValue: locale,
            onChanged: (v) => _updateLocale(v),
            activeColor: DesignTokens.primary,
          ),
          Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.1)),
          RadioListTile<Locale>(
            title: Text(l.languageHindi),
            value: const Locale('hi'),
            groupValue: locale,
            onChanged: (v) => _updateLocale(v),
            activeColor: DesignTokens.primary,
          ),
        ],
      ),
    );
  }

  Future<void> _updateLocale(Locale? v) async {
    if (v == null) return;
    ref.read(localeProvider.notifier).state = v;

    final store = ref.read(userSettingsStoreProvider);
    final currentSettings = ref.read(userSettingsProvider);

    final updatedSettings = currentSettings.copyWith(
      localeCode:
          '${v.languageCode}${v.countryCode != null ? '_${v.countryCode}' : ''}',
    );

    await store.saveSettings(updatedSettings);
    ref.read(userSettingsProvider.notifier).state = updatedSettings;
  }

  Widget _buildPreferencesCard(BuildContext context, dynamic user) {
    return Container(
      decoration: _glassDecoration(context),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Google Search'),
            subtitle: const Text('Allow AI to search the web'),
            value: _googleSearchEnabled,
            onChanged: (v) async {
              setState(() => _googleSearchEnabled = v);
              ref.read(googleSearchEnabledProvider.notifier).state = v;
              await _savePrefs();
            },
            activeColor: DesignTokens.primary,
          ),
          Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.1)),
          SwitchListTile(
            title: const Text('Firestore Sync'),
            subtitle: Text(user == null
                ? 'Sign in required'
                : 'Sync settings & chats across devices'),
            value: _firestoreSyncEnabled,
            onChanged: user == null
                ? null
                : (v) async {
                    setState(() => _firestoreSyncEnabled = v);
                    ref.read(firestoreSyncEnabledProvider.notifier).state = v;

                    final chatStore = ref.read(chatStoreProvider);
                    final settingsStore = ref.read(userSettingsStoreProvider);

                    if (v) {
                      // Enable sync: migrate settings to cloud and attach listeners
                      try {
                        await settingsStore.migrateToCloud();
                        await settingsStore.attachListener((updatedSettings) {
                          if (mounted) {
                            setState(() {
                              _pulseSpeedMs = updatedSettings.pulseSpeedMs;
                              _pulseThresholdPercent =
                                  updatedSettings.pulseThresholdPercent;
                              _pulseMaxFreq = updatedSettings.pulseMaxFreq;
                              _pulseBaseColor = updatedSettings.pulseBaseColor;
                              _pulseAlertColor =
                                  updatedSettings.pulseAlertColor;
                              _googleSearchEnabled =
                                  updatedSettings.googleSearchEnabled;
                              _firestoreSyncEnabled =
                                  updatedSettings.firestoreSyncEnabled;
                            });
                            ref
                                .read(googleSearchEnabledProvider.notifier)
                                .state = _googleSearchEnabled;
                            ref
                                .read(firestoreSyncEnabledProvider.notifier)
                                .state = _firestoreSyncEnabled;
                            ref.read(userSettingsProvider.notifier).state =
                                updatedSettings;
                          }
                        });
                        await chatStore.attachSessionsListener();
                      } catch (_) {}
                    } else {
                      // Disable sync: dispose listeners
                      await settingsStore.disposeListener();
                      await chatStore.disposeListeners();
                    }
                    await _savePrefs();
                  },
            activeColor: DesignTokens.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPulseSettingsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: _glassDecoration(context),
      child: Column(
        children: [
          _buildSliderRow(
              'Sensitivity',
              '$_pulseThresholdPercent%',
              _pulseThresholdPercent.toDouble(),
              5,
              50,
              (v) => setState(() => _pulseThresholdPercent = v.round())),
          const SizedBox(height: DesignTokens.spacingMd),
          _buildSliderRow(
              'Speed',
              '${_pulseSpeedMs}ms',
              _pulseSpeedMs.toDouble(),
              300,
              1500,
              (v) => setState(() => _pulseSpeedMs = v.round())),
          const SizedBox(height: DesignTokens.spacingMd),
          _buildSliderRow(
              'Max Frequency',
              '${_pulseMaxFreq.toStringAsFixed(1)}x',
              _pulseMaxFreq,
              1.0,
              4.0,
              (v) => setState(() => _pulseMaxFreq = v)),
        ],
      ),
    );
  }

  Widget _buildSliderRow(String label, String valueLabel, double value,
      double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(valueLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: DesignTokens.primary)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: DesignTokens.primary,
            inactiveTrackColor: DesignTokens.primary.withOpacity(0.2),
            thumbColor: DesignTokens.primary,
            overlayColor: DesignTokens.primary.withOpacity(0.1),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: (_) => _savePrefs(),
          ),
        ),
      ],
    );
  }

  BoxDecoration _glassDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      border: Border.all(
        color: Colors.white.withOpacity(0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Duration delay;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: DesignTokens.spacingSm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          )
              .animate()
              .fadeIn(delay: delay, duration: 400.ms)
              .slideX(begin: -0.1, end: 0),
          const SizedBox(height: DesignTokens.spacingSm),
          ...children.map((child) => child
              .animate()
              .fadeIn(delay: delay + 100.ms, duration: 500.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad)),
        ],
      ),
    );
  }
}
