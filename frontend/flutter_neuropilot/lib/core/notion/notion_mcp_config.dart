import 'package:flutter/foundation.dart';

/// Notion MCP server configuration
class NotionMCPConfig {
  static const String serverName = 'notion-mcp';
  static const String serverCommand = 'uvx';
  static const List<String> serverArgs = ['notion-mcp-server@latest'];

  /// Notion Internal Integration Token from environment
  /// This is the token starting with 'ntn_' from your Notion integration
  /// Set via: --dart-define=NOTION_INTEGRATION_TOKEN=ntn_xxx
  static const String notionIntegrationToken = String.fromEnvironment(
    'NOTION_INTEGRATION_TOKEN',
    defaultValue: '',
  );

  /// Notion OAuth Client ID from environment (for public OAuth flow)
  /// Set via: --dart-define=NOTION_CLIENT_ID=your_client_id
  static const String notionClientId = String.fromEnvironment(
    'NOTION_CLIENT_ID',
    defaultValue: '',
  );

  /// Notion OAuth Client Secret from environment (for backend use)
  /// Set via: --dart-define=NOTION_CLIENT_SECRET=your_client_secret
  static const String notionClientSecret = String.fromEnvironment(
    'NOTION_CLIENT_SECRET',
    defaultValue: '',
  );

  /// Check if Internal Integration Token is configured (preferred for internal use)
  static bool get hasIntegrationToken => notionIntegrationToken.isNotEmpty;

  /// Check if Notion OAuth is properly configured (for public integrations)
  static bool get isOAuthConfigured => notionClientId.isNotEmpty;

  /// Check if any Notion authentication method is available
  static bool get isConfigured => hasIntegrationToken || isOAuthConfigured;

  /// Environment variables for Notion MCP server
  static Map<String, String> getEnvironment({
    required String notionToken,
    String? logLevel,
  }) {
    return {
      'NOTION_TOKEN': notionToken,
      'FASTMCP_LOG_LEVEL': logLevel ?? (kDebugMode ? 'DEBUG' : 'ERROR'),
    };
  }

  /// MCP server configuration for .kiro/settings/mcp.json
  static Map<String, dynamic> getMCPConfig({
    required String notionToken,
    bool disabled = false,
    List<String> autoApprove = const [],
  }) {
    return {
      'mcpServers': {
        serverName: {
          'command': serverCommand,
          'args': serverArgs,
          'env': getEnvironment(notionToken: notionToken),
          'disabled': disabled,
          'autoApprove': autoApprove,
        },
      },
    };
  }

  /// Default auto-approve list for common Notion operations
  static const List<String> defaultAutoApprove = [
    'create_page',
    'update_page',
    'create_database_entry',
    'update_database_entry',
    'search_pages',
    'get_page',
    'get_database',
    'append_blocks',
  ];

  /// Notion API configuration
  static const String notionApiVersion = '2022-06-28';
  static const String notionApiBaseUrl = 'https://api.notion.com/v1';
  
  /// OAuth configuration
  static const String notionOAuthUrl = 'https://api.notion.com/v1/oauth/authorize';
  static const String notionTokenUrl = 'https://api.notion.com/v1/oauth/token';
  
  /// Required OAuth scopes
  static const List<String> requiredScopes = [
    'read',
    'write',
    'create',
    'update',
  ];

  /// Notion integration capabilities
  static const Map<String, String> integrationCapabilities = {
    'pages': 'Create and manage pages',
    'databases': 'Create and manage databases',
    'blocks': 'Create and manage content blocks',
    'search': 'Search across workspace',
    'users': 'Access user information',
    'comments': 'Manage comments',
  };

  /// Rate limiting configuration
  static const int maxRequestsPerSecond = 3;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  
  /// Cache configuration
  static const Duration cacheExpiry = Duration(minutes: 15);
  static const int maxCacheSize = 1000;
}