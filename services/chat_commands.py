from typing import Dict, Any, List, Tuple
from datetime import datetime, timedelta

from services.metrics_service import compute_daily_overview
from services.history_service import yesterday_range, get_sessions_by_date
from services.memory_bank import FirestoreMemoryBank
from sessions.firestore_session_storage import FirestoreSessionStorage
from services.compaction_service import compact_session
from services.external_brain_store import store_voice_task, get_context
from services.a2a_service import connect_partner, post_update
from services.slack_mcp import list_channels as slack_list_channels, post_message as slack_post_message
from services.jira_mcp import list_projects as jira_list_projects, create_issue as jira_create_issue, list_issues as jira_list_issues
from services.ambient_sound import list_tracks as sound_list_tracks, start_track as sound_start_track


def _suggestions() -> List[str]:
    return [
        "Show yesterday's conversations",
        "Show yesterday's tasks",
        "Resume session <id>",
        "Compact session <id>",
        "Metrics overview",
        "Slack: list channels",
        "Slack: post to <channel> <text>",
        "Jira: list projects",
        "Jira: list issues in <PROJECT>",
        "Jira: create issue in <PROJECT> <summary>|<description>",
        "Sound: list",
        "Sound: start <name>",
        "Capture <note>",
        "Context <taskId>",
        "A2A: connect <partnerId>",
        "A2A: update <partnerId> <message>",
        "Help",
    ]


def help() -> Dict[str, Any]:
    return {
        "ok": True,
        "help": {
            "commands": _suggestions(),
            "notes": "Use natural phrases; parameters in angle brackets should be replaced."
        },
        "suggestions": _suggestions(),
    }


def parse(text: str) -> Tuple[str, List[str]]:
    t = text.strip().lower()
    if t in {"help", "commands", "?"}:
        return ("help", [])
    if "yesterday" in t and "conversation" in t:
        return ("yesterday_conversations", [])
    if "yesterday" in t and "task" in t:
        return ("yesterday_tasks", [])
    if t.startswith("resume session ") or "resume session" in t:
        sid = text.split("resume session", 1)[1].strip()
        return ("resume_session", [sid])
    if t.startswith("compact session ") or t.startswith("compact now "):
        sid = text.split(" ")[-1].strip()
        return ("compact_session", [sid])
    if "metrics" in t and "overview" in t:
        return ("metrics_overview", [])
    if t.startswith("slack: list channels") or ("slack" in t and "channels" in t):
        return ("slack_channels", [])
    if t.startswith("slack: post") or ("slack" in t and "post" in t):
        parts = text.split()
        try:
            ci = parts.index("post") + 1
            channel = parts[ci]
            message = " ".join(parts[ci + 1:])
            return ("slack_post", [channel, message])
        except Exception:
            return ("slack_post", [])
    if t.startswith("jira: list projects") or ("jira" in t and "projects" in t):
        return ("jira_projects", [])
    if t.startswith("jira: list issues") or ("jira" in t and "issues" in t):
        try:
            proj = text.split()[-1].strip()
            return ("jira_issues", [proj])
        except Exception:
            return ("jira_issues", [])
    if t.startswith("jira: create issue") or ("jira" in t and "create" in t and "issue" in t):
        try:
            parts = text.split()
            proj = parts[parts.index("in") + 1]
            rem = text.split(proj, 1)[1].strip()
            if "|" in rem:
                summary, description = rem.split("|", 1)
            else:
                summary, description = rem, ""
            return ("jira_create", [proj, summary.strip(), description.strip()])
        except Exception:
            return ("jira_create", [])
    if t.startswith("sound: list") or ("sound" in t and "list" in t):
        return ("sound_list", [])
    if t.startswith("sound: start") or ("sound" in t and "start" in t):
        try:
            name = text.split()[-1].strip()
            return ("sound_start", [name])
        except Exception:
            return ("sound_start", [])
    if t.startswith("capture "):
        return ("capture", [text.split(" ", 1)[1].strip()])
    if t.startswith("context "):
        return ("context", [text.split(" ", 1)[1].strip()])
    if t.startswith("a2a: connect "):
        return ("a2a_connect", [text.split(" ", 2)[2].strip()])
    if t.startswith("a2a: update "):
        parts = text.split(" ", 3)
        if len(parts) >= 4:
            return ("a2a_update", [parts[2], parts[3]])
        return ("a2a_update", [])
    if t.startswith("cleanup expired"):
        delete = "delete" in t
        return ("cleanup_expired", [str(delete)])
    return ("unknown", [])


def execute(user_id: str, session_id: str, command: str, args: List[str], tz_name: str | None = None) -> Dict[str, Any]:
    memory = FirestoreMemoryBank(user_id)
    storage = FirestoreSessionStorage()
    try:
        if command == "help":
            return help()
        if command == "yesterday_conversations":
            start, end = yesterday_range(tz_name)
            sessions = get_sessions_by_date(user_id, "neuropilot", start, end)
            return {"ok": True, "sessions": sessions, "suggestions": ["Resume session <id>"]}
        if command == "yesterday_tasks":
            try:
                if tz_name:
                    from zoneinfo import ZoneInfo
                    now = datetime.now(ZoneInfo(tz_name)).replace(microsecond=0)
                else:
                    now = datetime.now().astimezone().replace(microsecond=0)
            except Exception:
                now = datetime.now().astimezone().replace(microsecond=0)
            y = (now.date() - timedelta(days=1)).isoformat()
            logs = memory.get_tasks_by_date(y)
            return {"ok": True, "tasks": logs}
        if command == "resume_session" and args:
            sid = args[0]
            sess = storage.get_session("neuropilot", user_id, sid)
            return {"ok": True, "resumed": sid, "events": len(sess.get("events", []))}
        if command == "compact_session" and args:
            sid = args[0]
            res = compact_session(user_id, "neuropilot", sid)
            return {"ok": res.get("ok", False), "summary_len": len(res.get("summary", ""))}
        if command == "metrics_overview":
            try:
                if tz_name:
                    from zoneinfo import ZoneInfo
                    now = datetime.now(ZoneInfo(tz_name)).replace(microsecond=0)
                else:
                    now = datetime.now().astimezone().replace(microsecond=0)
            except Exception:
                now = datetime.now().astimezone().replace(microsecond=0)
            dk = now.date().isoformat()
            return {"ok": True, "overview": compute_daily_overview(user_id, dk)}
        if command == "slack_channels":
            import asyncio
            res = asyncio.run(slack_list_channels())
            return res
        if command == "slack_post" and len(args) == 2:
            import asyncio
            return asyncio.run(slack_post_message(args[0], args[1]))
        if command == "jira_projects":
            import asyncio
            return asyncio.run(jira_list_projects())
        if command == "jira_issues" and args:
            import asyncio
            return asyncio.run(jira_list_issues(args[0]))
        if command == "jira_create" and len(args) >= 2:
            import asyncio
            proj, summary = args[0], args[1]
            description = args[2] if len(args) >= 3 else ""
            return asyncio.run(jira_create_issue(proj, summary, description))
        if command == "sound_list":
            return {"ok": True, "tracks": sound_list_tracks()}
        if command == "sound_start" and args:
            return sound_start_track(args[0])
        if command == "capture" and args:
            transcript = args[0]
            title = transcript.split(".")[0]
            tid = store_voice_task(title, "captured", transcript)
            return {"ok": True, "task_id": tid, "title": title}
        if command == "context" and args:
            ctx = get_context(args[0])
            return {"ok": True, "context": ctx}
        if command == "a2a_connect" and args:
            return connect_partner(args[0])
        if command == "a2a_update" and len(args) == 2:
            return post_update(args[0], {"message": args[1]})
        if command == "cleanup_expired":
            delete = args and args[0] == "True"
            try:
                if tz_name:
                    from zoneinfo import ZoneInfo
                    now = datetime.now(ZoneInfo(tz_name))
                else:
                    now = datetime.now().astimezone()
            except Exception:
                now = datetime.now().astimezone()
            marked = storage.expire_sessions(now)
            deleted = storage.delete_expired() if delete else 0
            return {"ok": True, "expired_marked": marked, "deleted": deleted}
        return {"ok": False, "error": "unknown_command", "suggestions": _suggestions()}
    except Exception as e:
        return {"ok": False, "error": str(e)}
