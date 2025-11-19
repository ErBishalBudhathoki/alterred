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