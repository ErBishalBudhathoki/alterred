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