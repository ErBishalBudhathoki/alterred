import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:altered/l10n/app_localizations.dart';
import '../core/components/np_avatar.dart';
import '../core/design_tokens.dart';
import '../state/session_state.dart';
import '../state/auth_state.dart';
import '../state/navigation_state.dart';
import '../core/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/chat_store.dart';
import '../state/user_settings_store.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/oauth_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../state/notion_provider.dart';
import '../core/notion/notion_mcp_config.dart';
import 'notion_settings_screen.dart';
import 'profile_screen.dart';

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
  bool _voiceLockDuringSession = false;

  // Calendar OAuth state
  bool _calendarConnected = false;
  bool _loadingCalendarStatus = true;
  bool _mcpReady = false;
  bool _hasCalendarTokens = false;
  String? _calendarExpiresAt;
  String? _calendarValidateStatus;
  String? _calendarBannerMessage;
  String? _googleEmail;

  // Credit balance String? _googleEmail;
  int _creditBalance = 0;
  List<dynamic> _availableVoices = [];
  bool _loadingVoices = false;
  String? _selectedVoice;
  String? _selectedQuality;
  String _sttProvider = 'device';

  // API Key state
  bool _hasCustomApiKey = false;
  String _apiKeyInput = '';
  bool _validatingApiKey = false;
  String _runtimeMode = 'unknown';
  String? _vertexProject;
  String? _vertexLocation;
  String? _runtimeEndpoint;

  final TextEditingController _partnerCtrl = TextEditingController();
  bool _a2aConnecting = false;
  String? _a2aStatus;
  List<String> _partnerUpdates = [];
  List<String> _partners = [];
  String? _selectedPartner;
  String? _partnerId;
  final GlobalKey _qrKey = GlobalKey();
  Map<String, String> _partnerStatusById = {};
  String? _defaultPartnerId;
  bool _isDefaultPartner = false;
  String? _ownPartnerId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _a2aSub;

  // OAuth service
  final _oauthService = OAuthService();

  @override
  void initState() {
    super.initState();

    // Initialize OAuth service with callback handler
    _oauthService.initialize(onCallback: _handleOAuthCallback);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    // Load settings from store (cloud-first if logged in)
    if (!mounted) return;
    try {
      // Ensure we have a valid token before making API calls
      try {
        await ref.read(idTokenSyncProvider.future);
      } catch (e) {
        debugPrint('Token sync failed: $e');
        // Continue anyway as some settings might be local, but API calls will likely fail
      }

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
        _selectedVoice = settings.ttsVoice;
        _selectedQuality = settings.ttsQuality;
        _sttProvider = settings.sttProvider;
        _voiceLockDuringSession = settings.voiceLockDuringSession;
      });

      // Load all status checks
      await Future.wait([
        _loadCalendarStatus(retryCount: 2),
        _loadCreditBalance(),
        _loadApiKeyStatus(),
        _loadRuntimeStatus(),
      ]);

      if (!mounted) return;

      // Restore A2A partner selection and list
      await _restoreA2APrefs();
      if (!mounted) return;

      // Attach real-time A2A listener
      _attachA2AListener();

      // Load available voices
      await _loadVoices();

      if (_selectedVoice != null) {
        try {
          final api = ref.read(apiClientProvider);
          await api.post('/tts/prewarm', {
            'voice': _selectedVoice,
            'quality': _selectedQuality ?? 'low',
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error refreshing settings data: $e');
    }
  }

  Future<void> _loadVoices() async {
    if (!mounted) return;
    setState(() => _loadingVoices = true);
    try {
      final response = await ref.read(apiClientProvider).get('/tts/voices');
      if (mounted && response['voices'] != null) {
        setState(() {
          _availableVoices = response['voices'] as List<dynamic>;
        });
      }
    } catch (_) {
      // Ignore errors
    } finally {
      if (mounted) setState(() => _loadingVoices = false);
    }
  }

  @override
  void dispose() {
    _partnerCtrl.dispose();
    try {
      _a2aSub?.cancel();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _savePrefs() async {
    ref.read(userSettingsProvider.notifier).update((s) => s.copyWith(
          pulseSpeedMs: _pulseSpeedMs,
          pulseThresholdPercent: _pulseThresholdPercent,
          pulseMaxFreq: _pulseMaxFreq,
          pulseBaseColor: _pulseBaseColor,
          pulseAlertColor: _pulseAlertColor,
          googleSearchEnabled: _googleSearchEnabled,
          firestoreSyncEnabled: _firestoreSyncEnabled,
          ttsVoice: _selectedVoice,
          ttsQuality: _selectedQuality,
          sttProvider: _sttProvider,
          voiceLockDuringSession: _voiceLockDuringSession,
        ));
  }

  Future<void> _logout() async {
    final ctl = ref.read(authControllerProvider);
    final store = ref.read(chatStoreProvider);
    try {
      await store.disposeListeners();
    } catch (_) {}
    setState(() => _firestoreSyncEnabled = false);
    ref
        .read(userSettingsProvider.notifier)
        .update((s) => s.copyWith(firestoreSyncEnabled: false));
    await _savePrefs();
    await ctl.signOut();
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(Routes.login, (route) => false);
    }
  }

  Future<void> _loadCalendarStatus({int retryCount = 0}) async {
    int attempts = 0;
    while (attempts <= retryCount) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final response = await ref
            .read(apiClientProvider)
            .get('/auth/google/calendar/status?_=$timestamp');

        if (!mounted) return;

        if (response['ok'] == true) {
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
          return; // Success
        }
      } catch (e) {
        debugPrint(
            'Calendar status check failed (attempt ${attempts + 1}): $e');
        if (attempts == retryCount) {
          if (mounted) {
            setState(() => _loadingCalendarStatus = false);
          }
        }
      }
      attempts++;
      if (attempts <= retryCount) {
        await Future.delayed(Duration(milliseconds: 500 * attempts));
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
      if (!mounted) return;
      setState(() => _calendarConnected = false);
      setState(() => _googleEmail = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendar disconnected')),
      );
      _loadCalendarStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _connectNotion() async {
    try {
      final authService = ref.read(notionAuthServiceProvider);

      // OAuth flow - allows each user to connect their own Notion workspace
      if (NotionMCPConfig.isOAuthConfigured) {
        await authService.startOAuthFlow(
          clientId: NotionMCPConfig.notionClientId,
          redirectUri: 'neuropilot://notion-auth',
          clientSecret: NotionMCPConfig.notionClientSecret.isNotEmpty
              ? NotionMCPConfig.notionClientSecret
              : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening Notion authorization...')),
          );
        }
        return;
      }

      // No OAuth configured - show manual token entry dialog
      await _showNotionTokenDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to Notion: $e')),
        );
      }
    }
  }

  Future<void> _showNotionTokenDialog() async {
    final tokenController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Your Notion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To connect your Notion workspace:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('1. Go to notion.so/my-integrations'),
            const Text('2. Click "New integration"'),
            const Text('3. Name it "Altered"'),
            const Text('4. Copy the "Internal Integration Secret"'),
            const Text('5. Paste it below'),
            const SizedBox(height: 8),
            const Text(
              '6. Share pages with your integration in Notion',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'Integration Token',
                hintText: 'ntn_...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, tokenController.text),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        final authService = ref.read(notionAuthServiceProvider);
        await authService.connectWithToken(result);

        // Refresh the notion provider to update UI
        ref.invalidate(notionProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connected to Notion!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect: $e')),
          );
        }
      }
    }
  }

  Future<void> _disconnectNotion() async {
    try {
      final authService = ref.read(notionAuthServiceProvider);
      await authService.disconnect();

      // Refresh the notion provider to update UI
      ref.invalidate(notionProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disconnected from Notion')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error disconnecting from Notion: $e')),
        );
      }
    }
  }

  void _openNotionSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotionSettingsScreen(),
      ),
    );
  }

  Future<void> _loadGoogleEmail() async {
    try {
      final r = await ref.read(apiClientProvider).get('/auth/google/userinfo');
      if (!mounted) return;
      if (r['ok'] == true) {
        setState(() {
          _googleEmail = r['email'] as String?;
        });
      } else {
        setState(() {
          _googleEmail = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
    }
  }

  Future<void> _loadCreditBalance() async {
    try {
      final response =
          await ref.read(apiClientProvider).get('/credits/balance');
      if (mounted && response['ok'] == true) {
        setState(() {
          _creditBalance = (response['balance'] ?? 0).toInt();
        });
      }
    } catch (e) {
      if (mounted) {}
    }
  }

  Future<void> _loadApiKeyStatus() async {
    try {
      final response =
          await ref.read(apiClientProvider).get('/settings/api-key/status');
      if (mounted && response['ok'] == true) {
        setState(() {
          _hasCustomApiKey = response['has_custom_key'] == true;
        });
      }
    } catch (e) {
      if (mounted) {}
    }
  }

  Future<void> _loadRuntimeStatus() async {
    try {
      final r = await ref.read(apiClientProvider).get('/runtime/status');
      if (!mounted) return;
      if (r['ok'] == true) {
        setState(() {
          _runtimeMode = (r['mode'] ?? 'unknown') as String;
          final v = r['vertex'] ?? {};
          _vertexProject = v['project'] as String?;
          _vertexLocation = v['location'] as String?;
          _runtimeEndpoint = r['endpoint'] as String?;
        });
      }
    } catch (_) {}
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

      if (!mounted) return;
      setState(() => _validatingApiKey = false);

      if (response['ok'] == true) {
        setState(() {
          _hasCustomApiKey = true;
          _apiKeyInput = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key saved successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(response['error'] ?? 'Failed to save API key')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _validatingApiKey = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteApiKey() async {
    try {
      await ref.read(apiClientProvider).delete('/settings/api-key');
      if (!mounted) return;
      setState(() {
        _hasCustomApiKey = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key removed')),
      );
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
    // Listen for navigation changes to refresh data when Settings tab is selected
    ref.listen(navigationIndexProvider, (previous, next) {
      if (next == 4) {
        _refreshData();
      }
    });

    // Listen for auth changes to refresh data when user logs in
    ref.listen(authUserProvider, (previous, next) {
      if (previous?.value == null && next.value != null) {
        _refreshData();
      }
    });

    final l = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final user = ref.watch(authUserProvider).value;
    final projectId = (user != null && Firebase.apps.isNotEmpty)
        ? Firebase.app().options.projectId
        : '';
    final settings = ref.watch(userSettingsProvider);

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
                      _buildProfileCard(context, user, projectId, settings),
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

                // Notion Integration
                if (user != null)
                  _SettingsSection(
                    title: 'Notion Integration',
                    icon: Icons.note_outlined,
                    delay: 150.ms,
                    children: [
                      _buildNotionCard(context),
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
                      //add padding
                      const SizedBox(height: DesignTokens.spacingMd),
                      _buildRuntimeCard(context),
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

                // Accountability
                if (user != null)
                  _SettingsSection(
                    title: 'Accountability',
                    icon: Icons.group_outlined,
                    delay: 350.ms,
                    children: [
                      _buildAccountabilityCard(context),
                      //add padding
                      const SizedBox(height: DesignTokens.spacingMd),
                      _buildPartnerIdCard(context),
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

                // Voice
                _SettingsSection(
                  title: 'Voice Settings',
                  icon: Icons.record_voice_over_outlined,
                  delay: 450.ms,
                  children: [
                    _buildVoiceCard(context),
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

  Widget _buildVoiceCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: _glassDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadingVoices)
            const Center(child: CircularProgressIndicator())
          else if (_availableVoices.isEmpty)
            const Text('No voices available')
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Voice'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedVoice,
                      isExpanded: true,
                      isDense: true,
                      items: _availableVoices.map((v) {
                        final provider =
                            v['provider'] == 'google' ? ' (Cloud)' : '';
                        return DropdownMenuItem<String>(
                          value: v['key'] as String,
                          child:
                              Text('${v['name']} (${v['language']})$provider'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _selectedVoice = val;
                          // Reset quality if not available for new voice
                          final voice = _availableVoices
                              .firstWhere((v) => v['key'] == val);
                          final qualities =
                              (voice['qualities'] as List).cast<String>();
                          if (_selectedQuality == null ||
                              !qualities.contains(_selectedQuality)) {
                            _selectedQuality = voice['default_quality'];
                          }
                        });
                        _savePrefs();
                        () async {
                          try {
                            final api = ref.read(apiClientProvider);
                            final voice = _availableVoices.firstWhere(
                                (v) => v['key'] == _selectedVoice,
                                orElse: () => {});
                            final dq = voice.isNotEmpty
                                ? (voice['default_quality'] as String)
                                : 'low';
                            await api.post('/tts/prewarm', {
                              'voice': _selectedVoice,
                              'quality': _selectedQuality ?? dq,
                            });
                          } catch (_) {}
                        }();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: DesignTokens.spacingMd),
                Row(
                  children: [
                    Expanded(
                        child: Text('Lock Voice During Session',
                            style: Theme.of(context).textTheme.titleMedium)),
                    Switch(
                        value: _voiceLockDuringSession,
                        onChanged: (v) {
                          setState(() => _voiceLockDuringSession = v);
                          _savePrefs();
                        }),
                  ],
                ),
                const SizedBox(height: DesignTokens.spacingMd),
                if (_selectedVoice != null)
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Quality'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedQuality ??
                            (() {
                              final voice = _availableVoices.firstWhere(
                                  (v) => v['key'] == _selectedVoice,
                                  orElse: () => {});
                              return voice.isNotEmpty
                                  ? voice['default_quality']
                                  : null;
                            })(),
                        isExpanded: true,
                        isDense: true,
                        items: (() {
                          final voice = _availableVoices.firstWhere(
                              (v) => v['key'] == _selectedVoice,
                              orElse: () => {});
                          if (voice.isEmpty) {
                            return <DropdownMenuItem<String>>[];
                          }
                          final qualities =
                              (voice['qualities'] as List).cast<String>();
                          return qualities.map((q) {
                            return DropdownMenuItem<String>(
                              value: q,
                              child: Text(q.toUpperCase()),
                            );
                          }).toList();
                        })(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedQuality = val);
                          _savePrefs();
                          () async {
                            try {
                              final api = ref.read(apiClientProvider);
                              await api.post('/tts/prewarm', {
                                'voice': _selectedVoice,
                                'quality': val,
                              });
                            } catch (_) {}
                          }();
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: DesignTokens.spacingMd),
                InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Speech-to-Text Provider'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sttProvider,
                      isExpanded: true,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(
                            value: 'device',
                            child: Text('Device (Web Speech)')),
                        DropdownMenuItem(
                            value: 'cloud', child: Text('Google Cloud')),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => _sttProvider = val);
                        _savePrefs();
                      },
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAccountabilityCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: _glassDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accountability Partner',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DesignTokens.spacingSm),
          LayoutBuilder(builder: (ctx, constraints) {
            final maxW = constraints.maxWidth;
            final tfW = maxW.clamp(0, 480).toDouble();
            return Wrap(
              spacing: DesignTokens.spacingSm,
              runSpacing: DesignTokens.spacingSm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: tfW,
                  child: TextField(
                    controller: _partnerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Partner ID',
                    ),
                    onChanged: (v) {
                      if (!_partners.contains(v)) {
                        setState(() => _selectedPartner = null);
                      } else {
                        setState(() => _selectedPartner = v);
                      }
                    },
                  ),
                ),
                if (_partners.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _partners.contains(_selectedPartner)
                          ? _selectedPartner
                          : null,
                      hint: const Text('Select Partner'),
                      items: _partners
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: (() {
                                          final st = _partnerStatusById[p]
                                                  ?.toLowerCase() ??
                                              '';
                                          if (st.contains('connect')) {
                                            return Colors.green;
                                          } else if (st.contains('disconn') ||
                                              st.contains('fail')) {
                                            return Colors.red;
                                          }
                                          return Colors.grey;
                                        })(),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(p,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    if (_defaultPartnerId != null &&
                                        _defaultPartnerId == p)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Icon(Icons.star,
                                            size: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                      ),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (v) async {
                        setState(() {
                          _selectedPartner = v;
                          _partnerCtrl.text = v ?? '';
                          _isDefaultPartner = (_defaultPartnerId != null &&
                              _defaultPartnerId == v);
                        });
                        final id = _partnerCtrl.text.trim();
                        if (id.isNotEmpty) await _loadPartnerUpdates(id);
                        try {
                          await ref.read(apiClientProvider).post(
                              '/a2a/selected-partner', {'partner_id': id});
                          await _saveSelectedPartner(id);
                        } catch (_) {}
                      },
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _isDefaultPartner,
                      onChanged: (val) async {
                        final id = _partnerCtrl.text.trim();
                        if (val == true) {
                          if (id.isEmpty) return;
                          try {
                            await ref.read(apiClientProvider).post(
                                '/a2a/default-partner', {'partner_id': id});
                            setState(() {
                              _defaultPartnerId = id;
                              _isDefaultPartner = true;
                            });
                            await _saveDefaultPartnerLocal(id);
                          } catch (_) {}
                        } else {
                          try {
                            await ref.read(apiClientProvider).post(
                                '/a2a/default-partner', {'partner_id': ''});
                            setState(() {
                              _isDefaultPartner = false;
                              _defaultPartnerId = null;
                            });
                            await _saveDefaultPartnerLocal('');
                          } catch (_) {}
                        }
                      },
                    ),
                    const Text('Set as default'),
                  ],
                ),
                ElevatedButton(
                  onPressed: _a2aConnecting
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final id = _partnerCtrl.text.trim();
                          if (id.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text('Enter a partner ID')),
                            );
                            return;
                          }
                          setState(() => _a2aConnecting = true);
                          try {
                            final r = await ref
                                .read(apiClientProvider)
                                .post('/a2a/connect', {'partner_id': id});
                            setState(() => _a2aStatus =
                                r['ok'] == true ? 'Connected' : 'Failed');
                            setState(() {
                              if (!_partners.contains(id)) {
                                _partners = [..._partners, id];
                              }
                              _partnerStatusById[id] = 'connected';
                            });
                            final msg = _a2aStatus ?? '';
                            messenger.showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                            await _loadPartnerUpdates(id);
                            await _loadPartners();
                            await _saveSelectedPartner(id);
                            if (_isDefaultPartner) {
                              try {
                                await ref.read(apiClientProvider).post(
                                    '/a2a/default-partner', {'partner_id': id});
                                setState(() => _defaultPartnerId = id);
                                await _saveDefaultPartnerLocal(id);
                              } catch (_) {}
                            }
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          } finally {
                            if (mounted) setState(() => _a2aConnecting = false);
                          }
                        },
                  child: _a2aConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Connect'),
                ),
              ],
            );
          }),
          const SizedBox(height: DesignTokens.spacingSm),
          Wrap(
              spacing: DesignTokens.spacingSm,
              runSpacing: DesignTokens.spacingSm,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final id = _partnerCtrl.text.trim();
                    if (id.isEmpty) return;
                    try {
                      await ref
                          .read(apiClientProvider)
                          .delete('/a2a/connection?partner_id=$id');
                      setState(() => _a2aStatus = 'Disconnected');
                      setState(() {
                        _partnerStatusById[id] = 'disconnected';
                      });
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Disconnected')),
                      );
                      await _saveSelectedPartner('');
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  },
                  child: const Text('Disconnect'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final id = _partnerCtrl.text.trim();
                    if (id.isEmpty) return;
                    await _loadPartnerUpdates(id);
                  },
                  child: const Text('Refresh Updates'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    await _loadPartners();
                  },
                  child: const Text('Refresh Partners'),
                ),
              ]),
          if (_partnerUpdates.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.spacingSm),
            Text('Updates', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: DesignTokens.spacingXs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _partnerUpdates
                  .map((u) => Text('• $u',
                      style: Theme.of(context).textTheme.bodySmall))
                  .toList(),
            ),
          ],
          if (_a2aStatus != null) ...[
            const SizedBox(height: DesignTokens.spacingSm),
            Text('Status: ${_a2aStatus!}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildPartnerIdCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: _glassDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Partner ID',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DesignTokens.spacingSm),
          Row(children: [
            Expanded(
              child: Text(_partnerId ?? 'Not generated',
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: 'Copy',
              onPressed: (_partnerId == null)
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: _partnerId!));
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download QR',
              onPressed: (_partnerId == null) ? null : _downloadQrPng,
            ),
          ]),
          const SizedBox(height: DesignTokens.spacingSm),
          Align(
            alignment: Alignment.center,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: RepaintBoundary(
                key: _qrKey,
                child: QrImageView(
                  data: _partnerId ?? '',
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Align(
            alignment: Alignment.center,
            child: ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final r =
                      await ref.read(apiClientProvider).get('/a2a/partner-id');
                  setState(() => _partnerId = r['partner_id'] as String?);
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              },
              child: const Text('Generate/Show Partner ID'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPartnerUpdates(String id) async {
    try {
      final r =
          await ref.read(apiClientProvider).get('/a2a/updates?partner_id=$id');
      final updates = (r['updates'] as List<dynamic>? ?? [])
          .map((e) {
            if (e is Map<String, dynamic>) {
              final u = e['update'];
              final ts = e['timestamp'];
              final payload = u is Map ? jsonEncode(u) : (u?.toString() ?? '');
              final label = ts != null && ts.toString().isNotEmpty
                  ? '[${ts.toString()}] $payload'
                  : payload;
              return label;
            }
            return e.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList();
      if (mounted) setState(() => _partnerUpdates = updates);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _downloadQrPng() async {
    try {
      final rb =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (rb == null) return;
      final img = await rb.toImage(pixelRatio: 3.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final data = bytes.buffer.asUint8List();
      if (kIsWeb) {
        final b64 = base64Encode(data);
        final uri = 'data:image/png;base64,$b64';
        await launchUrlString(uri);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/partner_id.png');
        await file.writeAsBytes(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved: ${file.path}')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _attachA2AListener() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      _a2aSub?.cancel();
      final stream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('a2a')
          .snapshots()
          .handleError((e) {
        debugPrint('A2A listener error: $e');
      });
      _a2aSub = stream.listen((snap) async {
        final prefs = await SharedPreferences.getInstance();
        final savedDefault = prefs.getString('a2a_default_partner') ?? '';
        final partners = <String>[];
        final statusMap = <String, String>{};
        for (final d in snap.docs) {
          final id = d.id;
          if (id == 'meta') continue;
          final data = d.data();
          final pid = (data['partner_id'] as String?) ?? id;
          if (pid.isEmpty) continue;
          if (_ownPartnerId != null && pid == _ownPartnerId) continue;
          final st = (data['status'] as String?) ?? '';
          final include = st.isNotEmpty ||
              pid == _selectedPartner ||
              pid == _defaultPartnerId;
          if (include) partners.add(pid);
          if (st.isNotEmpty) statusMap[pid] = st;
        }
        if (!mounted) return;
        setState(() {
          _partners = partners.toSet().toList();
          _partnerStatusById = statusMap;
          if (savedDefault.isNotEmpty) {
            _defaultPartnerId = savedDefault;
            _isDefaultPartner = _partnerCtrl.text.trim() == savedDefault ||
                _selectedPartner == savedDefault;
          }
          final sp = _selectedPartner;
          if (sp != null && statusMap.containsKey(sp)) {
            final st = statusMap[sp]!.toLowerCase();
            _a2aStatus = st.contains('connect')
                ? 'Connected'
                : (st.contains('disconn') || st.contains('fail'))
                    ? 'Disconnected'
                    : st;
          }
        });
      }, onError: (e) {
        debugPrint('A2A listener onError: $e');
      });
    } catch (_) {}
  }

  Future<void> _loadPartners() async {
    try {
      final r = await ref.read(apiClientProvider).get('/a2a/partners');
      final pairs = (r['partners'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final list = pairs
          .map((e) => e['partner_id']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('a2a_selected_partner') ?? '';
      final savedDefault = prefs.getString('a2a_default_partner') ?? '';
      setState(() {
        final filtered = _ownPartnerId == null
            ? list
            : list.where((p) => p != _ownPartnerId).toList();
        final connectedOrRelevant = pairs
            .map((e) => e['partner_id']?.toString() ?? '')
            .where((pid) => pid.isNotEmpty)
            .where((pid) {
          final match = pairs.firstWhere(
              (x) => (x['partner_id']?.toString() ?? '') == pid,
              orElse: () => <String, dynamic>{});
          final sv = match['status'];
          final st = sv is String
              ? sv.toLowerCase()
              : (sv?.toString() ?? '').toLowerCase();
          return st.isNotEmpty ||
              pid == _selectedPartner ||
              pid == _defaultPartnerId;
        }).toList();
        final merged = {...filtered, ...connectedOrRelevant}.toList();
        _partners = merged.toSet().toList();
        _partnerStatusById = {
          for (final p in pairs)
            (p['partner_id']?.toString() ?? ''): (p['status']?.toString() ?? '')
        }..removeWhere((k, v) => k.isEmpty);
        if (savedDefault.isNotEmpty) {
          _defaultPartnerId = savedDefault;
          _isDefaultPartner = _partnerCtrl.text.trim() == savedDefault ||
              _selectedPartner == savedDefault;
        }
        if (saved.isNotEmpty && _partners.contains(saved)) {
          _selectedPartner = saved;
          _partnerCtrl.text = saved;
          final match = pairs.firstWhere(
              (p) => (p['partner_id']?.toString() ?? '') == saved,
              orElse: () => <String, dynamic>{});
          final st = match['status'];
          if (st is String && st.isNotEmpty) {
            _a2aStatus = st == 'connected' ? 'Connected' : st;
          }
        } else {
          _selectedPartner =
              _partners.contains(_selectedPartner) ? _selectedPartner : null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _restoreA2APrefs() async {
    try {
      final api = ref.read(apiClientProvider);
      final cloud = await api.get('/a2a/selected-partner');
      if (!mounted) return;
      final pid = (cloud['partner_id'] as String?) ?? '';
      try {
        final def = await api.get('/a2a/default-partner');
        if (!mounted) return;
        final dp = (def['partner_id'] as String?) ?? '';
        if (dp.isNotEmpty) {
          setState(() {
            _defaultPartnerId = dp;
            _isDefaultPartner = (_partnerCtrl.text.trim() == dp) ||
                (_selectedPartner == dp) ||
                (pid == dp);
          });
        }
      } catch (_) {}
      try {
        final me = await api.get('/a2a/partner-id');
        if (!mounted) return;
        final mine = (me['partner_id'] as String?) ?? '';
        if (mine.isNotEmpty) {
          setState(() {
            _ownPartnerId = mine;
            _partnerId = mine; // reflect in "Your Partner ID" card
          });
        }
      } catch (_) {}
      if (pid.isNotEmpty) {
        if (_ownPartnerId != null && pid == _ownPartnerId) {
          setState(() {
            _selectedPartner = null;
          });
        } else {
          setState(() {
            _selectedPartner = pid;
            _partnerCtrl.text = pid;
          });
          await _loadPartnerUpdates(pid);
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        final saved = prefs.getString('a2a_selected_partner');
        if (saved != null && saved.isNotEmpty) {
          if (_ownPartnerId != null && saved == _ownPartnerId) {
            setState(() {
              _selectedPartner = null;
            });
          } else {
            setState(() {
              _selectedPartner = saved;
              _partnerCtrl.text = saved;
            });
            await _loadPartnerUpdates(saved);
          }
        }
      }
      if (mounted) await _loadPartners();
    } catch (_) {}
  }

  Future<void> _saveSelectedPartner(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id.isNotEmpty) {
      await prefs.setString('a2a_selected_partner', id);
    } else {
      await prefs.remove('a2a_selected_partner');
    }
  }

  Future<void> _saveDefaultPartnerLocal(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id.isNotEmpty) {
      await prefs.setString('a2a_default_partner', id);
    } else {
      await prefs.remove('a2a_default_partner');
    }
  }

  Widget _buildProfileCard(BuildContext context, dynamic user, String projectId,
      UserSettings settings) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: _glassDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Hero(
                        tag: 'profile_avatar',
                        child: NpAvatar(
                          name: user.displayName ?? user.email,
                          imageUrl: user.photoURL,
                          characterStyle: settings.characterStyle,
                          size: 64,
                        ),
                      )
                          .animate()
                          .scale(duration: 400.ms, curve: Curves.easeOutBack),
                      const SizedBox(width: DesignTokens.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? 'User',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              user.email ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Logout',
                style: IconButton.styleFrom(
                  foregroundColor: DesignTokens.error,
                  backgroundColor: DesignTokens.error.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
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
                      ? DesignTokens.success.withValues(alpha: 0.1)
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
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  border: Border.all(
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.1)),
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

  Widget _buildNotionCard(BuildContext context) {
    final notionStatus = ref.watch(notionIntegrationStatusProvider);
    final isConnected = notionStatus['is_connected'] as bool;
    final workspaceName = notionStatus['workspace_name'] as String?;
    final connectionState = notionStatus['connection_state'] as String;
    final autoSyncEnabled = notionStatus['auto_sync_enabled'] as bool;
    final syncFeatures =
        notionStatus['sync_features'] as Map<String, dynamic>? ?? {};
    final enabledTemplatesCount =
        notionStatus['enabled_templates_count'] as int? ?? 0;
    final error = notionStatus['error'] as String?;

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
                  color: isConnected
                      ? DesignTokens.success.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.note_outlined,
                  color: isConnected
                      ? DesignTokens.success
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              )
                  .animate(target: isConnected ? 1 : 0)
                  .scale(curve: Curves.easeOutBack),
              const SizedBox(width: DesignTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notion Integration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      isConnected
                          ? (workspaceName != null
                              ? 'Connected to $workspaceName'
                              : 'Connected')
                          : connectionState == 'loading'
                              ? 'Connecting...'
                              : 'Not Connected',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isConnected
                                ? DesignTokens.success
                                : connectionState == 'loading'
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                            fontWeight: isConnected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                    ).animate(target: isConnected ? 1 : 0).fadeIn(),
                  ],
                ),
              ),
              if (connectionState == 'loading')
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Text(
            isConnected
                ? 'Your Notion workspace is connected. Altered can save notes, sync metrics, and create ADHD-focused templates.'
                : 'Connect to enable note-taking, metrics export, and ADHD-focused templates in Notion.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (error != null) ...[
            const SizedBox(height: DesignTokens.spacingSm),
            Container(
              padding: const EdgeInsets.all(DesignTokens.spacingSm),
              decoration: BoxDecoration(
                color: DesignTokens.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                border: Border.all(
                    color: DesignTokens.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: DesignTokens.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DesignTokens.error,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: DesignTokens.spacingMd),
          if (isConnected) ...[
            // Sync features status
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (syncFeatures['metrics'] == true)
                  _buildFeatureChip(
                      context, 'Metrics', Icons.analytics_outlined, true),
                if (syncFeatures['tasks'] == true)
                  _buildFeatureChip(
                      context, 'Tasks', Icons.task_outlined, true),
                if (syncFeatures['memory'] == true)
                  _buildFeatureChip(
                      context, 'Memory', Icons.memory_outlined, true),
                if (enabledTemplatesCount > 0)
                  _buildFeatureChip(context, '$enabledTemplatesCount Templates',
                      Icons.description_outlined, true),
                if (autoSyncEnabled)
                  _buildFeatureChip(
                      context, 'Auto-Sync', Icons.sync_outlined, true),
              ],
            ),
            const SizedBox(height: DesignTokens.spacingMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openNotionSettings(context),
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Settings'),
                  ),
                ),
                const SizedBox(width: DesignTokens.spacingSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _disconnectNotion,
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
                onPressed: _connectNotion,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Connect Notion'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: DesignTokens.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(
      BuildContext context, String label, IconData icon, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? DesignTokens.success.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        border: Border.all(
          color: enabled
              ? DesignTokens.success.withValues(alpha: 0.3)
              : Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: enabled
                ? DesignTokens.success
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: enabled
                      ? DesignTokens.success
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
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
                  color: color.withValues(alpha: 0.1),
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
            backgroundColor:
                Theme.of(context).dividerColor.withValues(alpha: 0.1),
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

  Widget _buildRuntimeCard(BuildContext context) {
    final m = _runtimeMode;
    final isVertex = m == 'vertex_ai';
    final isByok = m == 'byok';
    final color = isVertex
        ? DesignTokens.primary
        : isByok
            ? DesignTokens.success
            : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: _glassDecoration(context),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Provider Status',
                style: Theme.of(context).textTheme.titleMedium),
            Row(children: [
              Icon(
                  isVertex
                      ? Icons.cloud_done_rounded
                      : isByok
                          ? Icons.vpn_key_rounded
                          : Icons.warning_amber_rounded,
                  color: color),
              const SizedBox(width: 6),
              Text(
                isVertex
                    ? 'Vertex AI'
                    : isByok
                        ? 'BYOK'
                        : 'Unconfigured',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ])
          ],
        ),
        const SizedBox(height: DesignTokens.spacingSm),
        _buildDetailRow('Region', _vertexLocation ?? '—'),
        _buildDetailRow('Project', _vertexProject ?? '—'),
        _buildDetailRow('Endpoint', _runtimeEndpoint ?? '—'),
      ]),
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
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.5),
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
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l.languageLabel, style: Theme.of(context).textTheme.titleMedium),
          DropdownButton<Locale>(
            value: locale ?? const Locale('en'),
            onChanged: (v) => _updateLocale(v),
            items: [
              DropdownMenuItem(
                value: const Locale('en'),
                child: Text(l.languageEnglish),
              ),
              DropdownMenuItem(
                value: const Locale('hi'),
                child: Text(l.languageHindi),
              ),
            ],
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
    ref.read(userSettingsProvider.notifier).updateFromCloud(updatedSettings);
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
              ref
                  .read(userSettingsProvider.notifier)
                  .update((s) => s.copyWith(googleSearchEnabled: v));
              await _savePrefs();
            },
            // use theme defaults
          ),
          Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
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
                    ref
                        .read(userSettingsProvider.notifier)
                        .update((s) => s.copyWith(firestoreSyncEnabled: v));

                    final chatStore = ref.read(chatStoreProvider);
                    final settingsStore = ref.read(userSettingsStoreProvider);

                    if (v) {
                      try {
                        await settingsStore.migrateToCloud();
                        await chatStore.attachSessionsListener();
                      } catch (_) {}
                    } else {
                      await chatStore.disposeListeners();
                    }
                    await _savePrefs();
                  },
            // use theme defaults
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
            inactiveTrackColor: DesignTokens.primary.withValues(alpha: 0.2),
            thumbColor: DesignTokens.primary,
            overlayColor: DesignTokens.primary.withValues(alpha: 0.1),
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
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
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
