import os
from typing import Dict, Any

try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
except Exception:
    ClientSession = None  # type: ignore


def _params():
    cmd = os.getenv("MCP_JIRA_COMMAND", "npx")
    args = os.getenv("MCP_JIRA_ARGS", "@mcp/jira").split()
    env = {}
    token_path = os.getenv("JIRA_MCP_TOKEN_PATH")
    if token_path:
        env["JIRA_MCP_TOKEN_PATH"] = token_path
    return StdioServerParameters(command=cmd, args=args, env=env)


async def _with_session(fn):
    params = _params()
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            return await fn(session)


async def check_ready() -> Dict[str, Any]:
    try:
        async def _fn(session):
            tools = await session.list_tools()
            names = [t.name for t in tools.tools]
            return {"ok": True, "tools": names}
        return await _with_session(_fn)
    except Exception as e:
        return {"ok": False, "error": str(e)}


async def list_projects() -> Dict[str, Any]:
    async def _fn(session):
        tools = await session.list_tools()
        names = [t.name for t in tools.tools]
        if "list-projects" not in names:
            return {"ok": False, "error": "list-projects tool not available"}
        res = await session.call_tool("list-projects", {})
        return {"ok": True, "result": res.content}
    return await _with_session(_fn)


async def create_issue(project_key: str, summary: str, description: str) -> Dict[str, Any]:
    async def _fn(session):
        tools = await session.list_tools()
        names = [t.name for t in tools.tools]
        if "create-issue" not in names:
            return {"ok": False, "error": "create-issue tool not available"}
        res = await session.call_tool("create-issue", {
            "projectKey": project_key,
            "summary": summary,
            "description": description,
        })
        return {"ok": True, "result": res.content}
    return await _with_session(_fn)


async def list_issues(project_key: str) -> Dict[str, Any]:
    async def _fn(session):
        tools = await session.list_tools()
        names = [t.name for t in tools.tools]
        if "list-issues" not in names:
            return {"ok": False, "error": "list-issues tool not available"}
        res = await session.call_tool("list-issues", {"projectKey": project_key})
        return {"ok": True, "result": res.content}
    return await _with_session(_fn)