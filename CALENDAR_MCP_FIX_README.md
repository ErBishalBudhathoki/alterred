# Calendar MCP Validation Fix

## Overview
This document details the resolution for the recurring calendar MCP validation issues (specifically "Invalid Grant" errors and `datetime` deprecation warnings).

## Root Cause Analysis
The persistent MCP validation failures were caused by:
1.  **Invalid Grant Loop**: When a refresh token became invalid (revoked or expired), the system attempted to refresh it, failed, but didn't clean up the invalid credentials. Subsequent attempts continued to use the bad token, leading to a loop of failures.
2.  **Timezone Naive Datetimes**: The codebase mixed timezone-naive `datetime` with timezone-aware datetimes, leading to potential calculation errors and deprecation warnings.
3.  **Lack of Visibility**: Error logging was minimal, making it difficult to diagnose why the MCP tool check was failing silently or with generic errors.

## Solution Implemented

### 1. Robust Token Management
- **Automatic Cleanup**: Modified `services/calendar_mcp.py` to catch "invalid_grant" errors explicitly. When detected, the invalid OAuth tokens are immediately deleted from `UserSettings`.
- **Force Re-authentication**: By deleting invalid tokens, the system forces a fresh login flow on the next attempt, resolving the "death loop".

### 2. Timezone Awareness
- Replaced all instances of `datetime` with `datetime.now(timezone)` in:
    - `services/calendar_mcp.py`
    - `services/oauth_handlers.py`
    - `tests/test_calendar_mcp_auth.py`
- Added logic to handle legacy tokens stored without timezone information by attaching UTC timezone before comparison.

### 3. Comprehensive Logging
- Added structured logging (Info/Warning/Error) to all core MCP operations in `services/calendar_mcp.py`:
    - `check_mcp_ready`
    - `_create_event_async`
    - `_list_events_async`
    - `_update_event_async`
    - `_delete_event_async`
- Logs now capture the start of operations, specific failure reasons (e.g., "mcp Python SDK not installed", "No credentials found"), and success states.

### 4. Authentication Precedence (New)
To ensure seamless operation and backward compatibility, the MCP tool now uses a 3-tier authentication priority system:

1.  **User Settings (Priority 1)**: 
    - Checks for an authenticated user connection stored in `UserSettings`.
    - Uses `user_id` to retrieve tokens.
    - Automatically refreshes expired tokens.
    - **Note**: This is the preferred method for agent-initiated actions.

2.  **Credentials Directory (Fallback 1)**:
    - If no active user connection is found, it scans `/Users/pratikshatiwari/Documents/trae_projects/altered/credentials` for known key files:
        - `oauth-neuropilot.json` (Primary fallback)
        - `gcp-oauth.keys.json`
        - `gcp-oauth.keys-desktop.json`
        - `google-services-prod(altered).json`
    - Maintains backward compatibility for existing setups.

3.  **Environment Variable (Fallback 2)**:
    - Checks `GOOGLE_OAUTH_CREDENTIALS` environment variable as a final fallback.

Logs now explicitly state which authentication method is being used:
`Calendar MCP using authentication method: user_settings (Path: /tmp/oauth_...)`
or
`Calendar MCP using authentication method: fallback_file_gcp-oauth.keys.json ...`

### 5. Credential Validation (New)
To prevent MCP server crashes and "access blocked" errors, strict validation is now applied to all credential files (both in the fallback directory and via `GOOGLE_OAUTH_CREDENTIALS`).

The validation checks for:
- Valid JSON structure.
- Required OAuth fields:
  - For `installed`/`web` apps: `redirect_uris`.
  - For `authorized_user`: `client_id`, `client_secret`, and `refresh_token`.

Invalid files are logged as warnings and skipped, ensuring the system doesn't try to use broken credentials.

## Configuration Changes
No new environment variables are required. Ensure the following existing variables are set in your `.env` file for Google OAuth:
- `GOOGLE_OAUTH_CLIENT_ID`
- `GOOGLE_OAUTH_CLIENT_SECRET`
- `OAUTH_REDIRECT_URI`

## Verification

### Automated Tests
Run the new test suite to verify credential handling, validation, and token refresh logic:
```bash
python3 -m unittest tests/test_calendar_mcp_auth.py
```

### Manual Verification
1.  **Trigger Invalid Grant**: Manually revoke the app's access in your Google Account permissions.
2.  **Run MCP Check**: Attempt to use a calendar feature.
3.  **Verify Log**: Check logs to see "Invalid grant detected. Revoking/Deleting tokens".
4.  **Re-auth**: The system should prompt for re-authentication (or return a clear error asking for it).
