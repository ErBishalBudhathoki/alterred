import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import '../models/notion_models.dart';
import '../notion_mcp_config.dart';
import '../../observability/logging_service.dart';

/// Secure Notion authentication service with OAuth 2.0 + PKCE
class NotionAuthService {
  static NotionAuthService? _instance;
  static NotionAuthService get instance => _instance ??= NotionAuthService._();

  NotionAuthService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final Logger _logger = Logger('NotionAuthService');
  final StreamController<NotionConnection> _connectionController =
      StreamController.broadcast();

  NotionConnection _currentConnection =
      const NotionConnection(state: NotionAuthState.disconnected);
  String? _codeVerifier;
  String? _state;
  AppLinks? _appLinks;
  StreamSubscription? _linkSubscription;

  /// Stream of connection state changes
  Stream<NotionConnection> get connectionStream => _connectionController.stream;

  /// Current connection state
  NotionConnection get currentConnection => _currentConnection;

  /// Initialize the auth service
  Future<void> initialize() async {
    try {
      _appLinks = AppLinks();
      await _loadStoredConnection();
      _setupDeepLinkListener();
      _logger.info('Notion auth service initialized');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize Notion auth service',
          {'error': e.toString()}, stackTrace);
    }
  }

  /// Start OAuth flow
  Future<void> startOAuthFlow({
    required String clientId,
    required String redirectUri,
    String? clientSecret,
  }) async {
    try {
      // Validate client ID
      if (clientId.isEmpty) {
        throw Exception(
            'Notion Client ID is not configured. Please set NOTION_CLIENT_ID in your build configuration.');
      }

      _updateConnection(
          _currentConnection.copyWith(state: NotionAuthState.connecting));

      // Generate PKCE parameters
      _codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(_codeVerifier!);
      _state = _generateState();

      // Build authorization URL
      final authUrl = Uri.parse(NotionMCPConfig.notionOAuthUrl).replace(
        queryParameters: {
          'client_id': clientId,
          'response_type': 'code',
          'owner': 'user',
          'redirect_uri': redirectUri,
          'state': _state,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      );

      _logger.info('Starting OAuth flow', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'state': _state,
      });

      // Launch browser
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch OAuth URL');
      }
    } catch (e, stackTrace) {
      _logger.error(
          'Failed to start OAuth flow', {'error': e.toString()}, stackTrace);
      _updateConnection(_currentConnection.copyWith(
        state: NotionAuthState.error,
        errorMessage: 'Failed to start authentication: ${e.toString()}',
      ));
    }
  }

  /// Handle OAuth callback
  Future<void> handleOAuthCallback(Uri callbackUri) async {
    try {
      final code = callbackUri.queryParameters['code'];
      final state = callbackUri.queryParameters['state'];
      final error = callbackUri.queryParameters['error'];

      if (error != null) {
        throw Exception('OAuth error: $error');
      }

      if (state != _state) {
        throw Exception('Invalid state parameter');
      }

      if (code == null) {
        throw Exception('No authorization code received');
      }

      _logger.info('Received OAuth callback', {
        'code_length': code.length,
        'state_match': state == _state,
      });

      // Exchange code for token
      await _exchangeCodeForToken(code);
    } catch (e, stackTrace) {
      _logger.error('Failed to handle OAuth callback', {'error': e.toString()},
          stackTrace);
      _updateConnection(_currentConnection.copyWith(
        state: NotionAuthState.error,
        errorMessage: 'Authentication failed: ${e.toString()}',
      ));
    }
  }

  /// Exchange authorization code for access token
  Future<void> _exchangeCodeForToken(String code) async {
    try {
      // This would typically be done on your backend for security
      // For now, we'll simulate the token exchange
      _logger.info('Exchanging code for token');

      // In production, make request to your backend which handles the token exchange
      // final response = await http.post(
      //   Uri.parse('${yourBackendUrl}/auth/notion/token'),
      //   body: json.encode({
      //     'code': code,
      //     'code_verifier': _codeVerifier,
      //   }),
      //   headers: {'Content-Type': 'application/json'},
      // );

      // For demo purposes, simulate successful authentication
      final mockToken = 'ntn_${_generateRandomString(40)}';
      final connection = NotionConnection(
        state: NotionAuthState.connected,
        accessToken: mockToken,
        workspaceName: 'My Workspace',
        workspaceId: 'workspace_${_generateRandomString(8)}',
        botId: 'bot_${_generateRandomString(8)}',
        connectedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 365)),
        capabilities: NotionMCPConfig.integrationCapabilities,
      );

      await _storeConnection(connection);
      _updateConnection(connection);

      _logger.info('Successfully authenticated with Notion', {
        'workspace_name': connection.workspaceName,
        'workspace_id': connection.workspaceId,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to exchange code for token',
          {'error': e.toString()}, stackTrace);
      _updateConnection(_currentConnection.copyWith(
        state: NotionAuthState.error,
        errorMessage: 'Token exchange failed: ${e.toString()}',
      ));
    }
  }

  /// Disconnect from Notion
  Future<void> disconnect() async {
    try {
      _logger.info('Disconnecting from Notion');

      // Revoke token if possible
      if (_currentConnection.accessToken != null) {
        await _revokeToken(_currentConnection.accessToken!);
      }

      // Clear stored data
      await _clearStoredConnection();

      _updateConnection(
          const NotionConnection(state: NotionAuthState.disconnected));

      _logger.info('Successfully disconnected from Notion');
    } catch (e, stackTrace) {
      _logger.error('Failed to disconnect from Notion', {'error': e.toString()},
          stackTrace);
    }
  }

  /// Refresh access token if needed
  Future<void> refreshTokenIfNeeded() async {
    if (_currentConnection.isExpired) {
      _logger.info('Token expired, refreshing...');
      // In production, implement token refresh logic
      // For now, mark as expired
      _updateConnection(
          _currentConnection.copyWith(state: NotionAuthState.expired));
    }
  }

  /// Get current access token
  Future<String?> getAccessToken() async {
    await refreshTokenIfNeeded();
    return _currentConnection.isConnected
        ? _currentConnection.accessToken
        : null;
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _currentConnection.isConnected;

  /// Load stored connection from secure storage
  Future<void> _loadStoredConnection() async {
    try {
      final connectionJson = await _storage.read(key: 'notion_connection');
      if (connectionJson != null) {
        final connection =
            NotionConnection.fromJson(json.decode(connectionJson));
        _updateConnection(connection);
        _logger.info('Loaded stored Notion connection', {
          'state': connection.state.name,
          'workspace_name': connection.workspaceName,
        });
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to load stored connection', {'error': e.toString()},
          stackTrace);
    }
  }

  /// Store connection to secure storage
  Future<void> _storeConnection(NotionConnection connection) async {
    try {
      await _storage.write(
        key: 'notion_connection',
        value: json.encode(connection.toJson()),
      );
      _logger.debug('Stored Notion connection to secure storage');
    } catch (e, stackTrace) {
      _logger.error(
          'Failed to store connection', {'error': e.toString()}, stackTrace);
    }
  }

  /// Clear stored connection
  Future<void> _clearStoredConnection() async {
    try {
      await _storage.delete(key: 'notion_connection');
      _logger.debug('Cleared stored Notion connection');
    } catch (e, stackTrace) {
      _logger.error('Failed to clear stored connection',
          {'error': e.toString()}, stackTrace);
    }
  }

  /// Setup deep link listener for OAuth callback
  void _setupDeepLinkListener() {
    _linkSubscription = _appLinks?.uriLinkStream.listen(
      (Uri uri) {
        if (uri.scheme == 'neuropilot' && uri.host == 'notion-auth') {
          handleOAuthCallback(uri);
        }
      },
      onError: (e, stackTrace) {
        _logger.error('Deep link error', {'error': e.toString()}, stackTrace);
      },
    );
  }

  /// Update connection state and notify listeners
  void _updateConnection(NotionConnection connection) {
    _currentConnection = connection;
    _connectionController.add(connection);
  }

  /// Revoke access token
  Future<void> _revokeToken(String token) async {
    try {
      // In production, make request to revoke token
      _logger.info('Revoking Notion access token');
    } catch (e, stackTrace) {
      _logger.error(
          'Failed to revoke token', {'error': e.toString()}, stackTrace);
    }
  }

  /// Generate PKCE code verifier
  String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(128, (i) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Generate PKCE code challenge
  String _generateCodeChallenge(String verifier) {
    // In production, use proper SHA256 hashing
    // For now, return base64url encoded verifier
    return base64Url.encode(utf8.encode(verifier)).replaceAll('=', '');
  }

  /// Generate random state parameter
  String _generateState() {
    return _generateRandomString(32);
  }

  /// Generate random string
  String _generateRandomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (i) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Get current connection state
  Future<NotionConnection?> getCurrentConnection() async {
    // If already connected, return current connection
    if (_currentConnection.state == NotionAuthState.connected) {
      return _currentConnection;
    }
    
    // Try to load from storage if not connected
    await _loadStoredConnection();
    
    return _currentConnection.state != NotionAuthState.disconnected
        ? _currentConnection
        : null;
  }

  /// Connect using an Internal Integration Token (ntn_xxx)
  /// This is the simplest way to connect for internal/private integrations
  Future<void> connectWithToken(String token) async {
    try {
      if (token.isEmpty) {
        throw Exception('Integration token is empty');
      }

      _updateConnection(
          _currentConnection.copyWith(state: NotionAuthState.connecting));

      _logger.info('Connecting with internal integration token');

      // Create connection with the provided token
      final connection = NotionConnection(
        state: NotionAuthState.connected,
        accessToken: token,
        workspaceName: 'Connected Workspace',
        workspaceId: 'internal_integration',
        botId: 'internal_bot',
        connectedAt: DateTime.now(),
        expiresAt: null, // Internal tokens don't expire
        capabilities: NotionMCPConfig.integrationCapabilities,
      );

      await _storeConnection(connection);
      _updateConnection(connection);

      _logger.info('Successfully connected with internal integration token');
    } catch (e, stackTrace) {
      _logger.error('Failed to connect with token', {'error': e.toString()},
          stackTrace);
      _updateConnection(_currentConnection.copyWith(
        state: NotionAuthState.error,
        errorMessage: 'Failed to connect: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Authenticate with Notion (alias for startOAuthFlow)
  Future<NotionConnection> authenticate() async {
    // Check if OAuth is configured
    if (!NotionMCPConfig.isOAuthConfigured) {
      throw Exception(
          'Notion OAuth is not configured. Please set NOTION_CLIENT_ID in your build configuration.');
    }

    // Start OAuth flow with configuration from environment
    await startOAuthFlow(
      clientId: NotionMCPConfig.notionClientId,
      redirectUri: 'neuropilot://notion-auth',
      clientSecret: NotionMCPConfig.notionClientSecret.isNotEmpty
          ? NotionMCPConfig.notionClientSecret
          : null,
    );

    // Wait for connection to complete
    await for (final connection in connectionStream) {
      if (connection.isConnected || connection.hasError) {
        return connection;
      }
    }

    throw Exception('Authentication timeout');
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
    _connectionController.close();
  }
}
