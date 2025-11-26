"""
Slack MCP Service
=================
Provides integration with Slack using the Model Context Protocol (MCP).
Allows the agent to list channels, post messages, and read history.

Implementation Details:
- Uses `mcp` Python SDK to communicate with the `@mcp/slack` server.
- Configures the MCP server command via environment variables (`MCP_SLACK_COMMAND`, `MCP_SLACK_ARGS`).
- Passes the Slack token via `SLACK_MCP_TOKEN_PATH`.

Design Decisions:
- Similar to Jira and Calendar MCP services, uses a context manager (`_with_session`) for connection handling.
- Maps high-level operations (post message, list channels) to specific MCP tools.
- Provides a `check_ready` function for health checks.

Behavioral Specifications:
- `list_channels`: Retrieves available Slack channels.
- `post_message`: Sends a message to a specific channel.
- `list_messages`: Retrieves recent messages from a channel.
"""
import os
from typing import Dict, Any, List

try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
except Exception:
    ClientSession = None  # type: ignore


def _params():
    cmd = os.getenv("MCP_SLACK_COMMAND", "npx")
    args = os.getenv("MCP_SLACK_ARGS", "@mcp/slack").split()
    env = {}
    token_path = os.getenv("SLACK_MCP_TOKEN_PATH")
    if token_path:
        env["SLACK_MCP_TOKEN_PATH"] = token_path
    return StdioServerParameters(command=cmd, args=args, env=env)


async def _with_session(fn):
    params = _params()
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            return await fn(session)


async def list_channels() -> Dict[str, Any]:
    async def _fn(session):
        tools = await session.list_tools()
        names = [t.name for t in tools.tools]
        if "list-channels" not in names:
            return {"ok": False, "error": "list-channels tool not available"}
        res = await session.call_tool("list-channels", {})
        return {"ok": True, "result": res.content}
    return await _with_session(_fn)


async def post_message(channel: str, text: str) -> Dict[str, Any]:
    async def _fn(session):
        tools = await session.list_tools()
        names = [t.name for t in tools.tools]
        if "post-message" not in names:
            return {"ok": False, "error": "post-message tool not available"}
        res = await session.call_tool("post-message", {"channel": channel, "text": text})
        return {"ok": True, "result": res.content}
    return await _with_session(_fn)


async def list_messages(channel: str, limit: int = 20) -> Dict[str, Any]:
    async def _fn(session):
        tools = await session.list_tools()
        names = [t.name for t in tools.tools]
        if "list-messages" not in names:
            return {"ok": False, "error": "list-messages tool not available"}
        res = await session.call_tool("list-messages", {"channel": channel, "limit": limit})
        return {"ok": True, "result": res.content}
    return await _with_session(_fn)


async def check_ready() -> Dict[str, Any]:
    try:
        async def _fn(session):
            tools = await session.list_tools()
            names = [t.name for t in tools.tools]
            return {"ok": True, "tools": names}
        return await _with_session(_fn)
    except Exception as e:
        return {"ok": False, "error": str(e)}