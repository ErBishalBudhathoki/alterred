import os
from typing import Dict, Any
from dotenv import load_dotenv
from google.genai import Client

from neuropilot_starter_code import (
    analyze_brain_state,
    atomize_task,
    estimate_real_time,
    detect_hyperfocus,
    match_task_to_energy,
    reduce_options,
    restore_context,
)
from services.calendar_mcp import create_calendar_event_intent, create_calendar_event, list_events_today, delete_event, _parse_time_natural, _parse_duration_minutes, update_event


def _genai_client() -> Client:
    load_dotenv()
    return Client(api_key=os.getenv("GOOGLE_API_KEY"))


def respond(user_message: str, memory, session_id: str = "session") -> Dict[str, Any]:
    brain = analyze_brain_state(user_message)

    results: Dict[str, Any] = {"brain": brain, "calls": []}

    lower = user_message.lower()

    if any(k in lower for k in ["task", "report", "start", "do"]):
        tf = atomize_task(user_message)
        results["calls"].append({"taskflow": tf})

        factor = memory.get_time_estimation_factor() if memory else 1.8
        tp = estimate_real_time(user_message, tf.get("estimated_time_minutes", 25), factor)
        results["calls"].append({"time": tp})

        ds = reduce_options(["Start now", "Plan first", "Defer"], 3)
        results["calls"].append({"decision": ds})

    if any(k in lower for k in ["time", "minutes", "hours", "meeting"]):
        tp2 = estimate_real_time(user_message, 30, memory.get_time_estimation_factor() if memory else 1.8)
        results["calls"].append({"time": tp2})

    if any(k in lower for k in ["coding", "hyperfocus", "long", "hours"]):
        hf = detect_hyperfocus(180, 120)
        results["calls"].append({"hyperfocus": hf})

    if any(k in lower for k in ["tired", "low energy", "exhausted", "drained"]):
        en = match_task_to_energy(["emails", "organize files", "write code"], 3)
        results["calls"].append({"energy": en})

    client = _genai_client()
    prompt = (
        "You are NeuroPilot, an empathetic executive function companion. Given the user's message and tool outputs, "
        "compose a concise, supportive response with 2-4 actionable micro-steps and clear next check-in. "
        "Avoid long paragraphs. Celebrate small wins."
    )

    # Calendar MCP intent detection and execution
    if any(k in lower for k in ["calendar", "calender", "appointment", "schedule", "event", "add", "create", "book", "set up", "put on"]):
        title = None
        parts = lower.split("event")
        if len(parts) > 1:
            before_from = parts[1].split("from")[0].strip()
            if before_from:
                title = before_from
        intent = create_calendar_event_intent(user_message, default_title=(title or "Event"))
        results["calls"].append({"calendar_intent": intent})
        if intent.get("ok") and intent.get("intent"):
            i = intent["intent"]
            if any(k in lower for k in ["yes", "ok", "okay", "confirm", "do it", "please add", "sure"]):
                cal_res = create_calendar_event(i["summary"], i["start"], i["end"], i.get("location"), i.get("description"))
                results["calls"].append({"calendar_create": cal_res})
            else:
                if memory:
                    memory.store_pending_action({"type": "calendar_create", "intent": i})

    if any(k in lower for k in ["appointments", "events", "today", "schedule today"]):
        list_res = list_events_today("primary")
        results["calls"].append({"calendar_list_today": list_res})
        if list_res.get("ok") and list_res.get("result"):
            events = list_res["result"].get("events", [])
            if memory:
                memory.store_calendar_events_today(events)
            conv_msgs = memory.get_recent_messages("session", limit=8) if memory else []
            conv_excerpt = [{"role": m.get("role"), "text": m.get("text")} for m in conv_msgs]
            results["calls"].append({"conversation_excerpt": conv_excerpt})

    deletion_synonyms = [
        "remove", "delete", "cancel", "drop", "clear", "take off", "scrap", "erase",
        "call off", "dismiss", "pull off", "nix"
    ]
    if any(s in lower for s in deletion_synonyms):
        events = memory.get_calendar_events_today() if memory else []
        if not events:
            list_res = list_events_today("primary")
            results["calls"].append({"calendar_list_today": list_res})
            if list_res.get("ok") and list_res.get("result"):
                events = list_res["result"].get("events", [])
                if memory:
                    memory.store_calendar_events_today(events)
        target = None
        if events:
            if len(events) == 1:
                target = events[0]
            else:
                # Try to match by summary substring
                for ev in events:
                    summary = (ev.get("summary") or "").lower()
                    if summary and summary in lower:
                        target = ev
                        break
                # Try to match by time mention like 9:15
                if not target:
                    import re
                    tm = re.search(r"(\d{1,2}:\d{2})", lower)
                    if tm:
                        tstr = tm.group(1)
                        for ev in events:
                            start = ev.get("start", {}).get("dateTime", "")
                            if tstr in start:
                                target = ev
                                break
                    if not target:
                        tm2 = re.search(r"(\d{1,2})\s*(am|pm)", lower)
                        if tm2:
                            tstr2 = tm2.group(1)
                            ampm = tm2.group(2)
                            for ev in events:
                                start = ev.get("start", {}).get("dateTime", "").lower()
                                if f"{tstr2}:" in start and ampm in start:
                                    target = ev
                                    break
        if target and target.get("id"):
            del_res = delete_event("primary", target["id"])
            results["calls"].append({"calendar_delete": del_res, "deleted_event": target})

    resched_syn = ["reschedule", "move to", "shift to", "change time", "push to", "delay to"]
    if any(s in lower for s in resched_syn):
        events = memory.get_calendar_events_today() if memory else []
        target = None
        if not events:
            lr = list_events_today("primary")
            results["calls"].append({"calendar_list_today": lr})
            if lr.get("ok") and lr.get("result"):
                events = lr["result"].get("events", [])
                if memory:
                    memory.store_calendar_events_today(events)
        if events:
            if len(events) == 1:
                target = events[0]
            else:
                for ev in events:
                    summary = (ev.get("summary") or "").lower()
                    if summary and summary in lower:
                        target = ev
                        break
        parsed = _parse_time_natural(user_message)
        dur = _parse_duration_minutes(user_message)
        if target and parsed:
            start_iso = parsed["start"]
            from datetime import datetime, timedelta
            end_iso = (datetime.fromisoformat(start_iso) + timedelta(minutes=dur)).isoformat()
            upd = update_event("primary", target["id"], start_iso, end_iso, None)
            results["calls"].append({"calendar_update": upd, "updated_event": target})

    history = []
    try:
        history = memory.get_recent_messages(session_id) if memory else []
    except Exception:
        history = []
    formatted_history = "\n".join([f"{h.get('role')}: {h.get('text')}" for h in history])
    contents = [
        {"role": "user", "parts": [{"text": "You are NeuroPilot. Use the conversation history to maintain context. Render both real calendar events (from tools) and a brief conversation excerpt relevant to the user's request."}]},
        {"role": "user", "parts": [{"text": f"Conversation History:\n{formatted_history}"}]},
        {"role": "user", "parts": [{"text": user_message}]},
        {"role": "user", "parts": [{"text": f"TOOL_OUTPUTS:\n{results}"}]},
    ]

    try:
        gen = client.models.generate_content(model=os.getenv("DEFAULT_MODEL", "gemini-flash-latest"), contents=contents)
        text = getattr(gen, "text", "")
    except Exception:
        text = "I attempted to process your request. Based on the tools: \n" + str(results)[:800]

    return {"text": text, "tool_results": [brain] + results.get("calls", [])}


def summarize_history(memory, session_id: str):
    try:
        msgs = memory.get_recent_messages(session_id, limit=20)
        if not msgs:
            return
        formatted = "\n".join([f"{m.get('role')}: {m.get('text')}" for m in msgs])
        client = _genai_client()
        resp = client.models.generate_content(
            model=os.getenv("DEFAULT_MODEL", "gemini-flash-latest"),
            contents=[{"role": "user", "parts": [{"text": f"Summarize concisely:\n{formatted}"}]}]
        )
        summary = getattr(resp, "text", "")
        if summary:
            memory.store_message(session_id, "summary", summary)
    except Exception:
        return
    if any(k in lower for k in ["yes", "ok", "okay", "confirm", "do it", "please add", "sure"]):
        pa = memory.get_pending_action() if memory else None
        if pa and pa.get("type") == "calendar_create":
            i = pa.get("intent")
            if i:
                cal_res = create_calendar_event(i.get("summary"), i.get("start"), i.get("end"), i.get("location"), i.get("description"))
                results["calls"].append({"calendar_create": cal_res, "from_pending": True})
                if memory:
                    memory.clear_pending_action()

    follow_up_phrases = [
        "have you added", "did you add", "was it added", "did you schedule", "have you scheduled",
        "did we create", "is it created", "did you remove", "was it removed"
    ]
    if any(p in lower for p in follow_up_phrases):
        last = memory.find_last_calendar_action(session_id) if memory else None
        if last:
            results["calls"].append({"last_calendar_action": last})