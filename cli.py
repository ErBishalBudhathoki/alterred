import os
import sys
import logging
from dotenv import load_dotenv

from services.firebase_client import init_firebase
from services.memory_bank import FirestoreMemoryBank
from services.calendar_mcp import check_mcp_ready
from sessions.firestore_session_storage import FirestoreSessionStorage
from datetime import datetime
from services.history_service import yesterday_range, get_sessions_by_date, get_events_for_session
from services.timer_store import store_countdown
from services.external_brain_store import store_voice_task, get_context
from services.a2a_service import connect_partner, post_update
from services.compaction_service import compact_session, maybe_auto_compact
from services.metrics_service import compute_daily_overview, record_agent_latency
from services.slack_mcp import check_ready as slack_check_ready, list_channels as slack_list_channels, post_message as slack_post_message
from services.jira_mcp import check_ready as jira_check_ready, list_projects as jira_list_projects, create_issue as jira_create_issue, list_issues as jira_list_issues
from services.ambient_sound import list_tracks as sound_list_tracks, start_track as sound_start_track
from adk_app import adk_respond


def main():
    load_dotenv()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    logger = logging.getLogger("cli")

    try:
        from adk_app import adk_respond as _adk_respond
        globals()["adk_respond"] = _adk_respond
        adk_ok = True
    except Exception as e:
        adk_ok = False
        logger.warning("ADK orchestrator unavailable: %s", e)
        def _fallback(user_id: str, session_id: str, text: str):
            return ("Agent unavailable", [])
        globals()["adk_respond"] = _fallback

    db = init_firebase()
    user_id = os.getenv("USER") or "terminal_user"
    session_id = f"session_{user_id}"

    memory = FirestoreMemoryBank(user_id)
    memory.ensure_profile()

    print("Altered (Terminal) — type /quit to exit")
    print(f"Firebase connected: {bool(db)}")
    mcp_status = check_mcp_ready()
    if mcp_status.get("ok"):
        print(f"Calendar MCP ready, tools: {mcp_status.get('tools')}")
    else:
        print(f"Calendar MCP error: {mcp_status.get('error')}")
    if not adk_ok:
        print("ADK orchestrator not loaded; chat will degrade gracefully.")

    try:
        initial_count = memory.get_message_count(session_id)
        print(f"Session: {session_id} (messages: {initial_count})")
    except Exception:
        print(f"Session: {session_id}")

    storage = FirestoreSessionStorage()

    while True:
        try:
            user_message = input("You: ").strip()
        except EOFError:
            break

        if not user_message:
            continue
        if user_message.lower() in {"quit", "/quit", "exit"}:
            break

        if user_message.lower().startswith("/history"):
            try:
                msgs = memory.get_recent_messages(session_id, limit=20)
                print("-- Conversation History (latest 20) --")
                for m in msgs:
                    role = m.get("role")
                    text = m.get("text")
                    print(f"[{role}] {text}")
                print("-- End History --")
            except Exception as e:
                print(f"History unavailable: {e}")
            continue

        if user_message.lower().startswith("/session "):
            new_id = user_message.split(" ", 1)[1].strip()
            if new_id:
                session_id = new_id
                try:
                    count = memory.get_message_count(session_id)
                except Exception:
                    count = 0
                print(f"Switched to session: {session_id} (messages: {count})")
            continue

        if user_message.lower().startswith("/cleanup expired"):
            try:
                marked = storage.expire_sessions(datetime.utcnow())
                deleted = 0
                if "delete" in user_message.lower():
                    deleted = storage.delete_expired()
                print(f"Expired marked: {marked}. Deleted: {deleted}")
            except Exception as e:
                print(f"Cleanup error: {e}")
            continue

        if user_message.lower().startswith("/yesterday conversations"):
            try:
                start, end = yesterday_range()
                uid = user_id
                sessions = get_sessions_by_date(uid, "altered", start, end)
                print(f"Yesterday sessions ({len(sessions)}):")
                for m in sessions:
                    sid = m.get("session_id")
                    print(f"- {sid} last_activity={m.get('last_activity')}")
            except Exception as e:
                print(f"Yesterday conversations error: {e}")
            continue

        if user_message.lower().startswith("/yesterday tasks"):
            try:
                from datetime import datetime, timedelta
                y = (datetime.utcnow().date() - timedelta(days=1)).isoformat()
                logs = memory.get_tasks_by_date(y)
                print(f"Yesterday tasks ({len(logs)}):")
                for l in logs:
                    print(f"- [{l.get('status')}] {l.get('title')} (session {l.get('session_id')})")
            except Exception as e:
                print(f"Yesterday tasks error: {e}")
            continue

        if user_message.lower().startswith("/resume "):
            new_id = user_message.split(" ", 1)[1].strip()
            if new_id:
                try:
                    sess = storage.get_session("altered", user_id, new_id)
                    print(f"Resumed session: {new_id} (events={len(sess.get('events', []))})")
                    session_id = new_id
                except Exception as e:
                    print(f"Resume error: {e}")
            continue

        if user_message.lower().startswith("/compact now "):
            sid = user_message.split(" ", 2)[2].strip()
            try:
                res = compact_session(user_id, "altered", sid)
                print(f"Compaction: {res.get('ok')} summary length={len(res.get('summary', ''))}")
            except Exception as e:
                print(f"Compaction error: {e}")
            continue

        if user_message.lower().startswith("/metrics overview"):
            from datetime import datetime
            dk = datetime.utcnow().date().isoformat()
            try:
                ov = compute_daily_overview(user_id, dk)
                print(f"Metrics {dk}: {ov}")
            except Exception as e:
                print(f"Metrics error: {e}")
            continue

        if user_message.lower().startswith("/slack ready"):
            import asyncio
            res = asyncio.run(slack_check_ready())
            print(f"Slack MCP ready: {res}")
            continue

        if user_message.lower().startswith("/slack channels"):
            import asyncio
            res = asyncio.run(slack_list_channels())
            print(f"Channels: {res}")
            continue

        if user_message.lower().startswith("/slack post "):
            parts = user_message.split(" ", 3)
            if len(parts) >= 4:
                chan = parts[2]
                text = parts[3]
                import asyncio
                res = asyncio.run(slack_post_message(chan, text))
                print(f"Posted: {res}")
            else:
                print("Usage: /slack post <channel> <text>")
            continue

        if user_message.lower().startswith("/jira ready"):
            import asyncio
            res = asyncio.run(jira_check_ready())
            print(f"Jira MCP ready: {res}")
            continue

        if user_message.lower().startswith("/jira projects"):
            import asyncio
            res = asyncio.run(jira_list_projects())
            print(f"Projects: {res}")
            continue

        if user_message.lower().startswith("/jira issues "):
            parts = user_message.split(" ", 2)
            if len(parts) >= 3:
                import asyncio
                res = asyncio.run(jira_list_issues(parts[2]))
                print(f"Issues: {res}")
            else:
                print("Usage: /jira issues <projectKey>")
            continue

        if user_message.lower().startswith("/jira create "):
            parts = user_message.split(" ", 3)
            if len(parts) >= 4:
                proj = parts[2]
                try:
                    summary, description = parts[3].split("|", 1)
                except ValueError:
                    summary, description = parts[3], ""
                import asyncio
                res = asyncio.run(jira_create_issue(proj, summary.strip(), description.strip()))
                print(f"Issue created: {res}")
            else:
                print("Usage: /jira create <projectKey> <summary>|<description>")
            continue

        if user_message.lower().startswith("/sound list"):
            print(f"Tracks: {sound_list_tracks()}")
            continue

        if user_message.lower().startswith("/sound start "):
            name = user_message.split(" ", 2)[2].strip()
            res = sound_start_track(name)
            print(f"Sound: {res}")
            continue

        if user_message.lower().startswith("/capture "):
            transcript = user_message.split(" ", 1)[1].strip()
            title = transcript.split(".")[0]
            task_id = store_voice_task(title, "captured", transcript)
            print(f"Captured task {task_id}: {title}")
            continue

        if user_message.lower().startswith("/context "):
            tid = user_message.split(" ", 1)[1].strip()
            ctx = get_context(tid)
            if ctx:
                print(f"Context for {tid}: {ctx}")
            else:
                print("No context found.")
            continue

        if user_message.lower().startswith("/a2a connect "):
            pid = user_message.split(" ", 2)[2].strip()
            res = connect_partner(pid)
            print(f"A2A: connected to {res.get('partner_id')}")
            continue

        if user_message.lower().startswith("/a2a update "):
            parts = user_message.split(" ", 3)
            if len(parts) >= 4:
                pid = parts[2]
                upd = parts[3]
                res = post_update(pid, {"message": upd})
                print("A2A: update posted")
            else:
                print("Usage: /a2a update <partner_id> <message>")
            continue

        memory.store_message(session_id, "user", user_message)
        import time
        start_ms = int(time.time() * 1000)
        try:
            text, tools_called = adk_respond(user_id, session_id, user_message)
        except Exception as e:
            logger.error("ADK respond failed: %s", e)
            text, tools_called = (str(e), [])
        end_ms = int(time.time() * 1000)
        record_agent_latency(end_ms - start_ms)

        try:
            maybe_auto_compact(user_id, "altered", session_id)
        except Exception:
            pass

        print(f"altered: {text}")

        memory.store_message(session_id, "assistant", text, tools_called)
        tool_results = tools_called

        if tool_results:
            for res in tool_results:
                if isinstance(res, dict):
                    if "brain_state" in res:
                        state = res.get("brain_state")
                        memory.store_brain_state(state, user_message)
                    if res.get("kind") == "task_workflow":
                        memory.store_strategy_success("taskflow", res)
                    if res.get("kind") == "monitors":
                        memory.store_strategy_success("monitors", res)
                    if "presence" in res:
                        memory.store_taskflow_event("body_double", res)
                    if "reframe" in res:
                        memory.store_taskflow_event("dopamine_reframe", res)
                    if "prompt" in res:
                        memory.store_taskflow_event("jit_prompt", res)
                    if "ordered" in res:
                        memory.store_taskflow_event("schedule", res)
                    if "target" in res and "warnings" in res:
                        tid = store_countdown(res.get("target"), res.get("warnings"))
                        print(f"Timer scheduled: {tid} -> {res.get('target')}")
                    if "overload" in res and res.get("overload"):
                        memory.add_sensory_trigger(user_message)
                    if "task" in res and isinstance(res.get("task"), dict):
                        t = res["task"]
                        title = t.get("title")
                        status = t.get("status", "captured")
                        if title:
                            task_id = store_voice_task(title, status, user_message)
                            print(f"Captured task {task_id}: {title}")
                    if "reduced_options" in res:
                        memory.store_decision_event("reduce_options", res)
                    if "default" in res:
                        memory.store_decision_event("default_generator", res)
                    if "motivation" in res:
                        memory.store_decision_event("motivation_matcher", res)
                    if "deadline_seconds" in res and "auto_decide" in res:
                        memory.store_decision_event("paralysis_protocol", res)

        try:
            if memory.get_message_count(session_id) >= 10:
                from runtime.coordinator_runtime import summarize_history
                summarize_history(memory, session_id)
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
