# Notion Integration

## Description
Integrates Notion for note-taking, knowledge management, and syncing NeuroPilot data to user workspaces.

## Architecture
- **Backend Proxy:** `routers/notion_routes.py` - Proxies requests to Notion API (required for Flutter Web CORS)
- **Flutter Services:**
  - `notion_auth_service.dart` - OAuth 2.0 + PKCE authentication
  - `notion_service.dart` - Core API operations
  - `notion_sync_service.dart` - Firestore ↔ Notion sync
  - `notion_template_service.dart` - Pre-built templates

## Configuration
Environment variables (`.env`):
```
# OAuth (for multi-user public integration)
NOTION_CLIENT_ID=<uuid>
NOTION_CLIENT_SECRET=secret_xxx

# Development only (single workspace)
NOTION_INTEGRATION_TOKEN=ntn_xxx
```

## Authentication Methods

### 1. Internal Integration Token (Development)
- User creates integration at notion.so/my-integrations
- Pastes token in Settings → Notion → Connect
- Token stored securely on device

### 2. OAuth Flow (Production)
- Requires public Notion integration
- User authorizes via OAuth popup
- Backend exchanges code for access token

## API Endpoints (Backend Proxy)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/notion/search` | POST | Search pages/databases |
| `/notion/pages` | POST | Create page |
| `/notion/pages/{id}` | GET/PATCH | Get/update page |
| `/notion/databases/{id}/query` | POST | Query database |
| `/notion/users/me` | GET | Validate token |

## Features
- Quick note capture
- Template-based page creation (Daily Reflection, Task List, etc.)
- Metrics export to Notion
- Bidirectional sync with Firestore

## Testing
1. Get integration token from notion.so/my-integrations
2. Share a page with your integration
3. Connect via Settings → Notion
4. Test search/create operations

## Known Limitations
- OAuth requires public integration approval from Notion
- Rate limited to 30 requests/minute per IP
- Pages must be explicitly shared with integration

---

# MCP Integrations (Slack)

## Description
Integrates Slack via MCP to list channels, post messages, and list messages.

## Configuration
- Environment variables:
  - `MCP_SLACK_COMMAND` (default `npx`)
  - `MCP_SLACK_ARGS` (default `@mcp/slack`)
  - `SLACK_MCP_TOKEN_PATH` (path to Slack token JSON or env-based authentication as required by the MCP server)

## CLI Usage
- `/slack ready` → prints tool availability
- `/slack channels` → lists channels
- `/slack post <channel> <text>` → posts a message to the given channel

## Technical Specs
- Wrapper: `services/slack_mcp.py` using MCP stdio client
- Tools expected: `list-channels`, `post-message`, `list-messages`

## Testing Procedures
- Configure MCP Slack server per its documentation
- Run CLI commands above and verify results

## Known Limitations
- Requires MCP Slack server availability and proper credentials
- Tool names depend on the MCP server implementation; adjust `MCP_SLACK_ARGS` accordingly

# MCP Integrations (Jira)

## Description
Integrates Jira via MCP to list projects, list issues, and create issues.

## Configuration
- Environment variables:
  - `MCP_JIRA_COMMAND` (default `npx`)
  - `MCP_JIRA_ARGS` (default `@mcp/jira`)
  - `JIRA_MCP_TOKEN_PATH` (path to Jira token/credentials per MCP server instructions)

## CLI Usage
- `/jira ready` → prints tool availability
- `/jira projects` → lists projects
- `/jira issues <projectKey>` → lists issues
- `/jira create <projectKey> <summary>|<description>` → creates an issue

## Technical Specs
- Wrapper: `services/jira_mcp.py` using MCP stdio client
- Tools expected: `list-projects`, `list-issues`, `create-issue`

## Testing Procedures
- Configure MCP Jira server and credentials
- Run CLI commands above and verify results

## Known Limitations
- Depends on MCP server availability and tool names; adjust `MCP_JIRA_ARGS` accordingly