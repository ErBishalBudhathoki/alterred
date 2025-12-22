# Notion Integration

This document describes how the Notion integration works in NeuroPilot.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Flutter App    │────▶│  Backend API    │────▶│  Notion API     │
│  (Web/Mobile)   │     │  (FastAPI)      │     │  api.notion.com │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │
        │                       │
        ▼                       ▼
   User's Token            Proxy Request
   (Stored locally)        (Adds headers)
```

## Authentication Methods

### 1. Internal Integration Token (Current - Development)

Users create their own Notion integration and paste the token:

1. User goes to https://www.notion.so/my-integrations
2. Creates a new **Internal** integration
3. Copies the "Internal Integration Secret" (starts with `ntn_`)
4. Pastes it in NeuroPilot Settings → Notion Integration
5. Shares Notion pages with the integration

**Pros:**
- No OAuth setup required
- Works immediately
- Each user has their own workspace

**Cons:**
- Users must manually create integration
- Token management is user's responsibility

### 2. Public OAuth (Future - Production)

For a seamless user experience with OAuth:

1. Create a **Public** integration at https://www.notion.so/my-integrations
2. Configure OAuth settings:
   - Redirect URI: `neuropilot://notion-auth` (mobile) or `https://your-domain.com/notion-callback` (web)
   - Privacy Policy URL: Required
   - Terms of Service URL: Required
   - Website URL: Required
3. Add credentials to environment:
   ```
   NOTION_CLIENT_ID=your-oauth-client-id
   NOTION_CLIENT_SECRET=secret_xxx
   ```

## Backend Proxy

Flutter Web cannot make direct calls to `api.notion.com` due to CORS restrictions.
The backend provides proxy endpoints at `/notion/*`:

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/notion/search` | POST | Search pages and databases |
| `/notion/pages` | POST | Create a new page |
| `/notion/pages/{id}` | GET | Get a page |
| `/notion/pages/{id}` | PATCH | Update a page |
| `/notion/blocks/{id}/children` | GET | Get block children |
| `/notion/blocks/{id}/children` | PATCH | Append blocks |
| `/notion/databases` | POST | Create a database |
| `/notion/databases/{id}` | GET | Get a database |
| `/notion/databases/{id}/query` | POST | Query a database |
| `/notion/users/me` | GET | Get bot user info |
| `/notion/health` | GET | Health check |

### Authentication

The Flutter app sends the user's Notion token via:
- `Authorization: Bearer <token>` header, or
- `X-Notion-Token: <token>` header

### Rate Limiting

- 30 requests per minute per IP
- Configurable via environment variables

## Flutter Service

The `NotionService` automatically routes requests:
- **Web**: Through backend proxy (`/notion/*`)
- **Mobile/Desktop**: Direct to Notion API

```dart
// Automatic routing based on platform
final pages = await NotionService.instance.searchPages(query: 'meeting notes');
```

## Configuration

### Environment Variables

**Backend (.env):**
```bash
# No Notion-specific config needed for proxy mode
# The user's token is passed from the Flutter app
```

**Flutter (--dart-define):**
```bash
# Backend URL for proxy requests
--dart-define=API_BASE_URL=http://localhost:8000

# Optional: OAuth credentials (for public integration)
--dart-define=NOTION_CLIENT_ID=your-client-id
--dart-define=NOTION_CLIENT_SECRET=secret_xxx

# Optional: Internal token (for development only)
--dart-define=NOTION_INTEGRATION_TOKEN=ntn_xxx
```

### Run Script (scripts/run_local.sh)

The run script loads from `.env` and passes to Flutter:
```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=NOTION_CLIENT_ID=${NOTION_CLIENT_ID:-} \
  --dart-define=NOTION_CLIENT_SECRET=${NOTION_CLIENT_SECRET:-} \
  --dart-define=NOTION_INTEGRATION_TOKEN=${NOTION_INTEGRATION_TOKEN:-}
```

## Usage in App

### Connecting Notion

1. Go to Settings → Notion Integration
2. Click "Connect Notion"
3. Enter your Internal Integration Token
4. Click "Connect"

### Features Available

Once connected:
- **Metrics Sync**: Export productivity metrics to Notion
- **Tasks Sync**: Sync tasks with Notion databases
- **Memory Sync**: Save context snapshots to Notion
- **Templates**: Create ADHD-focused templates

## Troubleshooting

### "Failed to fetch" Error

This occurs when making direct API calls from Flutter Web. Ensure:
1. Backend server is running (`python api_server.py`)
2. `API_BASE_URL` is correctly set
3. Backend proxy endpoints are accessible

### "Not authenticated" Error

The token is missing or invalid:
1. Check token starts with `ntn_`
2. Verify integration has access to target pages
3. Try disconnecting and reconnecting

### "Rate limited" Error

Too many requests:
1. Wait a minute before retrying
2. Reduce request frequency in app

## Future Improvements

1. **OAuth Flow**: Implement full OAuth for seamless user experience
2. **Token Refresh**: Handle token expiration gracefully
3. **Offline Support**: Queue operations when offline
4. **Webhook Support**: Real-time sync via Notion webhooks
