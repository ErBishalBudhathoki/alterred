# Notion Integration

This document describes how the Notion integration works in NeuroPilot.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Flutter App    │────▶│  Backend API    │────▶│  Notion API     │
│  (Web/Mobile)   │     │  (FastAPI)      │     │  api.notion.com │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       ▲
        │                       │                       │
        ▼                       ▼                       │
   User's Token            Proxy Request          Agent Service
   (Stored locally)        (Adds headers)    (services/notion_service.py)
                                                       │
                                ┌──────────────────────┘
                                │
                          ┌─────┴─────┐
                          │ AI Agents │
                          │ (ADK)     │
                          └───────────┘
```

The architecture supports two access patterns:
1. **Frontend Proxy**: Flutter app → Backend proxy → Notion API
2. **Agent Service**: AI Agents → NotionService → Notion API (using stored user tokens)

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
| `/notion/connect` | POST | Save Notion token to Firestore (requires Firebase auth) |
| `/notion/disconnect` | POST | Remove Notion token from Firestore (requires Firebase auth) |
| `/notion/status` | GET | Check if user has Notion connected (requires Firebase auth) |

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

## Agent Service (Backend)

The `services/notion_service.py` module provides Notion operations for AI agents. Unlike the proxy routes (which forward frontend requests), this service allows agents to directly interact with Notion using the user's stored token from Firestore.

### Available Functions

| Function | Description |
|----------|-------------|
| `search_notion_pages(user_id, query, page_size)` | Search pages in user's workspace |
| `create_notion_page(user_id, title, content, parent_page_id)` | Create a new page |
| `append_to_notion_page(user_id, page_id, content)` | Append content to existing page |
| `get_notion_databases(user_id)` | List databases in workspace |
| `add_to_notion_database(user_id, database_id, title, properties)` | Add item to database |

### Usage in Agents

```python
from services.notion_service import search_notion_pages, create_notion_page

# Search for pages
result = await search_notion_pages(user_id, "meeting notes", page_size=10)
if result.get("ok"):
    pages = result["pages"]

# Create a new page
result = await create_notion_page(
    user_id=user_id,
    title="Daily Reflection",
    content="## Today's Focus\n- Task 1\n- Task 2"
)
```

### Content Formatting

The service automatically converts plain text to Notion blocks:
- `# Heading` → Heading 1
- `## Heading` → Heading 2
- `### Heading` → Heading 3
- `- Item` or `• Item` → Bulleted list
- `1. Item` → Numbered list
- Regular text → Paragraph

### Token Storage

The agent service retrieves the user's Notion token from Firestore via `UserSettings.get_notion_token()`. This requires:
1. User has connected Notion in the app settings
2. Token is stored in Firestore under the user's settings document

The token sync is handled by dedicated backend endpoints:
- `POST /notion/connect` - Validates and stores the token in Firestore
- `POST /notion/disconnect` - Removes the token from Firestore
- `GET /notion/status` - Checks if a token is stored for the user

These endpoints require Firebase authentication (`Authorization: Bearer <firebase_id_token>`).

## Notion Agent

The Notion Agent (`agents/notion_agent.py`) is a dedicated specialized agent for handling all Notion-related operations. Unlike other integrations that run through the Coordinator, Notion has its own agent to support complex multi-turn conversations.

### Why a Dedicated Agent?

1. **Multi-turn Conversations**: Notion operations often require back-and-forth (e.g., "write to Notion" → "what title?" → user provides title → create page)
2. **Context Preservation**: The agent maintains state across messages to remember pending operations
3. **Specialized Instructions**: Dedicated prompts for handling Notion-specific workflows

### Agent Definition

```python
# agents/notion_agent.py
notion_agent = LlmAgent(
    model=get_adk_model(),
    name="notion_agent",
    description="Specialized agent for Notion operations",
    instruction="...",  # Detailed instructions for multi-turn handling
    tools=[
        tool_notion_create_page,
        tool_notion_search,
        tool_notion_append,
        tool_notion_list_databases,
        tool_notion_add_to_database,
    ],
)
```

### Routing Behavior

Notion requests are routed to the Notion Agent when detected. The router in `orchestration/router.py` identifies Notion-related messages and delegates to this specialized agent.

## ADK Agent Tools

The Notion Agent uses tools defined in `agents/adk_tools.py`. These tools wrap the `notion_service.py` functions.

| Tool | Description | Example Prompts |
|------|-------------|-----------------|
| `tool_notion_create_page(title, content)` | Create a new Notion page (auto-generates title if not provided) | "Write a note to Notion about today's meeting", "Save this to Notion: My project ideas..." |
| `tool_notion_search(query)` | Search for pages in workspace | "Search Notion for meeting notes" |
| `tool_notion_append(page_id, content)` | Append content to existing page | "Add this to my meeting notes page" |
| `tool_notion_list_databases()` | List all databases in workspace | "Show my Notion databases" |
| `tool_notion_add_to_database(database_id, title)` | Add item to a database | "Add 'Buy groceries' to my tasks database" |

### Tool Parameters

#### `tool_notion_create_page`
```python
async def tool_notion_create_page(title: str, content: str) -> Dict[str, Any]:
    """
    Args:
        title: The title for the new Notion page. If empty or generic (e.g., "note", 
               "untitled"), a title is auto-generated from the first few words of content.
        content: Content supporting plain text, bullet points (- item), 
                 numbered lists (1. item), and headings (# Heading)
    
    Returns:
        {"ok": True, "page": {"id": "...", "url": "...", "title": "..."}, "ui_mode": "notion_page_created"}
    
    Note:
        The agent will automatically generate a reasonable title from the content
        if the user doesn't explicitly provide one. This avoids prompting users
        for titles and enables faster note capture.
    """
```

#### `tool_notion_search`
```python
async def tool_notion_search(query: str) -> Dict[str, Any]:
    """
    Args:
        query: Search query to find pages
    
    Returns:
        {"ok": True, "pages": [...], "count": N, "ui_mode": "notion_search_results"}
    """
```

#### `tool_notion_append`
```python
async def tool_notion_append(page_id: str, content: str) -> Dict[str, Any]:
    """
    Args:
        page_id: The ID of the Notion page to append to
        content: The content to append
    
    Returns:
        {"ok": True, "message": "Content appended to Notion page"}
    """
```

#### `tool_notion_list_databases`
```python
async def tool_notion_list_databases() -> Dict[str, Any]:
    """
    Returns:
        {"ok": True, "databases": [{"id": "...", "title": "...", "url": "..."}], "count": N}
    """
```

#### `tool_notion_add_to_database`
```python
async def tool_notion_add_to_database(database_id: str, title: str) -> Dict[str, Any]:
    """
    Args:
        database_id: The ID of the database to add to
        title: The title/name for the new item
    
    Returns:
        {"ok": True, "item": {"id": "...", "url": "...", "title": "..."}, "message": "Added '...' to Notion database"}
    """
```

### UI Modes

The tools return `ui_mode` values that the frontend can use to render appropriate UI:
- `notion_page_created`: Show success message with link to new page
- `notion_search_results`: Display list of found pages

### Error Handling

All tools return consistent error responses when Notion is not connected:
```python
{
    "ok": False,
    "error": "Notion is not connected. Please connect Notion in Settings → Notion Integration."
}
```
