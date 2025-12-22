from typing import Dict, List, Any, Optional, cast
import os
import json
import re
from sessions.firestore_session_storage import FirestoreSessionStorage
from services.memory_bank import FirestoreMemoryBank
from services.external_brain_store import get_context

# ============================================================================
# CUSTOM TOOLS (Migrated from neuropilot_starter_code.py)
# ============================================================================

def analyze_brain_state(user_message: str) -> Dict[str, Any]:
    """
    Analyzes user's message to detect current brain state.
    
    Args:
        user_message: The user's input text
        
    Returns:
        Dictionary with brain_state, energy_level, and indicators
    """
    # Simplified analysis - in production, this would use ML/NLP
    indicators = {
        "overwhelmed": ["can't", "too much", "stuck", "help", "overwhelmed", "drowning"],
        "scattered": ["jumping", "distracted", "tabs open", "forgot", "bored", "wandering"],
        "focused": ["working on", "making progress", "done with", "flow", "zone"],
    }
    
    energy_keywords = {
        1: ["exhausted", "drained", "dead", "can't move", "burnout"],
        3: ["tired", "sleepy", "low energy", "slow"],
        5: ["okay", "fine", "neutral", "normal"],
        7: ["good", "awake", "ready", "up for it"],
        9: ["energetic", "pumped", "hyper", "wired", "excited"]
    }

    message_lower = user_message.lower()
    
    # Estimate energy
    estimated_energy = 5
    for level, keywords in energy_keywords.items():
        if any(k in message_lower for k in keywords):
            estimated_energy = level
            break

    for state, keywords in indicators.items():
        if any(keyword in message_lower for keyword in keywords):
            return {
                "brain_state": state,
                "energy_level": estimated_energy,
                "confidence": 0.7,
                "detected_keywords": [k for k in keywords if k in message_lower]
            }
    
    return {
        "brain_state": "neutral",
        "energy_level": estimated_energy,
        "confidence": 0.5,
        "detected_keywords": []
    }


def atomize_task(task_description: str, country_code: Optional[str] = None) -> Dict[str, Any]:
    """
    Breaks down a large task into micro-steps that are actually doable.
    
    Args:
        task_description: The overwhelming task to break down
        country_code: Optional country code to provide location-specific context (e.g. for tax tasks)
        
    Returns:
        Dictionary with micro_steps and estimated time
    """
    fallback = {
        "original_task": task_description,
        "micro_steps": [
            "Open the relevant application/document",
            "Review what you already have (2 min)",
            "Identify the first specific action",
            "Set a 5-minute timer",
            "Do just that one action",
            "Take a 2-minute break",
            "Repeat with next micro-step",
        ],
        "estimated_time_minutes": 25,
        "dopamine_hack": "Focus on just the first 5 minutes. That's all.",
    }

    try:
        from services.country_service import get_country_info

        desc = (task_description or "").strip()
        if not desc:
            return fallback

        # Construct system prompt with optional country context
        system_instruction = "You are an expert ADHD Task Coach specializing in executive function scaffolding."
        
        if country_code:
            info = get_country_info(country_code)
            if info and "name" in info:
                system_instruction += f"\nIMPORTANT LOCATION CONTEXT: The user is located in {info['name']} ({country_code}). "
                system_instruction += f"Currency: {info.get('currency')}. "
                if info.get("tax_info"):
                    system_instruction += f"Tax Authority/Info: {info.get('tax_info')} "
                system_instruction += f"For any legal, tax, or bureaucratic tasks, YOU MUST USE {info.get('name')} regulations and terminology. DO NOT use USA default."

        prompt = (
            f"{system_instruction}\n"
            "The user is feeling stuck/overwhelmed by a task. Your goal is to lower the barrier to entry.\n"
            "\n"
            f'User Task: "{desc}"\n'
            "\n"
            "Instructions:\n"
            "1. BREAK IT DOWN: Create 5-9 ultra-granular, concrete micro-steps.\n"
            "   - Step 1 MUST be a 'no-brainer' setup action (e.g., 'Open laptop', 'Find a pen').\n"
            "   - Use clear, imperative verbs (e.g., 'Write', 'Call', 'Search').\n"
            "   - Avoid vague steps like 'Plan project'. Instead use 'List 3 goals'.\n"
            "2. DOPAMINE HACK: Suggest ONE creative, specific way to gamify this task or make it novel.\n"
            "   - Examples: 'Play Mario Kart music', 'Use a silly font', 'Reward with chocolate after step 3'.\n"
            "3. TIME ESTIMATE: Be realistic but optimistic. Include setup time.\n"
            "\n"
            "Output Format: JSON ONLY (no markdown blocks, just raw JSON).\n"
            "{\n"
            f'  "original_task": "{desc}",\n'
            '  "micro_steps": ["step 1", "step 2", ...],\n'
            '  "estimated_time_minutes": <int>,\n'
            '  "dopamine_hack": "<string>"\n'
            "}"
        )

        try:
            from agents.adk_model import get_adk_model
            # Use ADK model for generation
            model = get_adk_model()
            # Direct usage of the underlying client to ensure synchronous execution
            resp = model.api_client.models.generate_content(
                model=model.model,
                contents=prompt
            )
            if resp and resp.text:
                raw = resp.text
        except Exception as e:
            print(f"ADK atomize_task generation failed: {e}")
            raw = None

        if raw is None:
            return fallback

        text = raw.strip()
        if "```" in text:
            if "```json" in text:
                text = text.split("```json", 1)[1]
            else:
                text = text.split("```", 1)[1]
            text = text.split("```", 1)[0].strip()

        obj: Optional[Dict[str, Any]] = None
        try:
            obj = json.loads(text)
        except Exception:
            m = re.search(r"\{[\s\S]*\}", text)
            if m:
                try:
                    obj = json.loads(m.group(0))
                except Exception:
                    obj = None

        if not isinstance(obj, dict):
            return fallback

        steps_raw = obj.get("micro_steps")
        steps: List[str] = []
        if isinstance(steps_raw, list):
            steps = [str(s).strip() for s in steps_raw if str(s).strip()]

        est_raw = obj.get("estimated_time_minutes")
        est: Optional[int] = None
        if isinstance(est_raw, int):
            est = est_raw
        else:
            try:
                est = int(str(est_raw).strip())
            except Exception:
                est = None

        dopamine = obj.get("dopamine_hack")
        dopamine_str = str(dopamine).strip() if dopamine is not None else ""

        if not steps:
            return fallback

        if est is None or est < 5 or est > 180:
            est = cast(int, fallback["estimated_time_minutes"])

        if not dopamine_str:
            dopamine_str = cast(str, fallback["dopamine_hack"])

        return {
            "original_task": desc,
            "micro_steps": steps[:9],
            "estimated_time_minutes": est,
            "dopamine_hack": dopamine_str,
        }
    except Exception:
        return fallback


def estimate_real_time(task: str, user_estimate_minutes: int, historical_accuracy: float = 1.8) -> Dict:
    """
    Corrects user's time estimate based on their historical accuracy pattern.
    
    Args:
        task: Task description
        user_estimate_minutes: What user thinks it will take
        historical_accuracy: User's typical estimation ratio (1.0 = perfect, 2.0 = takes 2x longer)
        
    Returns:
        Corrected time estimate with explanation
    """
    corrected_estimate = int(user_estimate_minutes * historical_accuracy)
    
    return {
        "user_estimate": user_estimate_minutes,
        "realistic_estimate": corrected_estimate,
        "accuracy_factor": historical_accuracy,
        "explanation": f"Based on your history, tasks you estimate at {user_estimate_minutes} min usually take {corrected_estimate} min.",
        "buffer_recommendation": int(corrected_estimate * 0.2)  # 20% buffer
    }


def detect_hyperfocus(work_duration_minutes: int, last_break_minutes_ago: int) -> Dict:
    """
    Detects when user is in hyperfocus and needs intervention.
    
    Args:
        work_duration_minutes: How long they've been working
        last_break_minutes_ago: Time since last break
        
    Returns:
        Intervention level and recommendations
    """
    if work_duration_minutes > 180 or last_break_minutes_ago > 120:
        intervention_level = "URGENT"
        message = "🚨 HYPERFOCUS ALERT: You've been working too long. Stop NOW. Bathroom, water, food - in that order."
    elif work_duration_minutes > 120:
        intervention_level = "HIGH"
        message = "You're in deep work mode. Take a 15-min break in the next 10 minutes."
    elif work_duration_minutes > 60:
        intervention_level = "MODERATE"
        message = "Consider a 5-minute break soon. Your brain needs it."
    else:
        intervention_level = "NONE"
        message = "You're in healthy work flow. Keep going!"
    
    return {
        "intervention_level": intervention_level,
        "work_duration": work_duration_minutes,
        "message": message,
        "should_interrupt": intervention_level in ["URGENT", "HIGH"]
    }


def match_task_to_energy(task_list: List[str], current_energy: int) -> Dict:
    """
    Matches available tasks to current energy level.
    
    Args:
        task_list: List of available tasks
        current_energy: Energy level 1-10 (1=exhausted, 10=peak)
        
    Returns:
        Recommended task with reasoning
    """
    # Simplified task matching - production would use learned patterns
    energy_task_map = {
        (8, 10): "high_cognitive",  # Peak: complex problem-solving
        (5, 7): "medium_cognitive",  # Moderate: routine work, emails
        (3, 4): "low_cognitive",     # Low: organizing, easy tasks
        (1, 2): "rest"               # Exhausted: nothing, rest needed
    }
    
    for (low, high), task_type in energy_task_map.items():
        if low <= current_energy <= high:
            return {
                "recommended_task_type": task_type,
                "energy_level": current_energy,
                "reasoning": f"Your energy is {current_energy}/10 - best suited for {task_type} tasks",
                "should_rest": task_type == "rest"
            }
    
    return {"recommended_task_type": "medium_cognitive", "energy_level": current_energy}


def reduce_options(options: List[str], max_options: int = 3, context: str = "") -> Dict:
    """
    Reduces overwhelming number of choices to manageable set.
    Uses LLM for smart reduction if available, otherwise simple slicing.
    
    Args:
        options: All available options
        max_options: Maximum to return (default 3)
        context: Optional context to guide selection
        
    Returns:
        Reduced options with reasoning
    """
    # Fallback response
    fallback = {
        "original_count": len(options),
        "reduced_options": options[:max_options],
        "removed_count": max(0, len(options) - max_options),
        "reasoning": f"Reduced from {len(options)} to {max_options} to prevent analysis paralysis.",
        "decision_deadline": "60 seconds or I'll choose for you"
    }

    if len(options) <= max_options:
        fallback["reasoning"] = "Options are already manageable."
        return fallback

    # Try LLM-based reduction if context or options are complex
    try:
        from agents.adk_model import get_adk_model
        
        prompt = (
            f"Context: {context}\n"
            f"Options: {options}\n"
            f"Task: Select the best {max_options} options to reduce decision paralysis. "
            "Prioritize options that are high-impact but low-friction.\n"
            f"Output JSON: {{'reduced_options': ['opt1', ...], 'reasoning': 'string'}}"
        )
        
        model = get_adk_model()
        resp = model.api_client.models.generate_content(
            model=model.model,
            contents=prompt
        )
        
        if resp and resp.text:
            text = resp.text.strip()
            if "```json" in text:
                text = text.split("```json")[1].split("```")[0].strip()
            elif "```" in text:
                text = text.split("```")[1].split("```")[0].strip()
            
            obj = json.loads(text)
            reduced = obj.get("reduced_options", [])
            
            if reduced and isinstance(reduced, list):
                return {
                    "original_count": len(options),
                    "reduced_options": reduced[:max_options],
                    "removed_count": max(0, len(options) - len(reduced[:max_options])),
                    "reasoning": obj.get("reasoning", fallback["reasoning"]),
                    "decision_deadline": "60 seconds or I'll choose for you"
                }
    except Exception as e:
        print(f"Smart reduce_options failed: {e}")
        
    return fallback


def restore_context(task_id: str) -> Dict:
    uid = os.getenv("USER") or "terminal_user"
    storage = FirestoreSessionStorage()
    try:
        sessions = storage.list_sessions(uid, "altered", limit=1)
    except Exception:
        sessions = []
    session_id = sessions[0].session_id if sessions else "session_" + uid
    try:
        sess = storage.get_session("altered", uid, session_id)
    except Exception:
        sess = {"meta": {}, "state": {}, "events": []}
    last_worked_on = sess.get("meta", {}).get("last_activity") or sess.get("meta", {}).get("created_at")
    mem = FirestoreMemoryBank(uid)
    try:
        recent = mem.get_recent_messages(session_id, limit=8)
    except Exception:
        recent = []
    last_user = next((m for m in reversed(recent) if m.get("role") == "user" and m.get("text")), None)
    last_assistant = next((m for m in reversed(recent) if m.get("role") == "assistant" and m.get("text")), None)
    progress = "" if not last_assistant else str(last_assistant.get("text"))
    if not progress and last_user:
        progress = f"Last you said: {last_user.get('text')}"
    steps = []
    if progress:
        lines = [line.strip() for line in str(progress).split("\n") if line.strip()]
        steps = lines[:3]
    if not steps:
        steps = [
            "Review the last message",
            "Define the next micro-step",
            "Work for 5 minutes"
        ]
    ctx = None
    try:
        ctx = get_context(task_id)
    except Exception:
        ctx = None
    task_name = (ctx or {}).get("title") or "Untitled"
    events = sess.get("events") or []
    last_tools = []
    if events:
        try:
            tc = events[-1].tool_calls if hasattr(events[-1], "tool_calls") else events[-1].get("tool_calls", [])
            if isinstance(tc, list):
                for t in tc:
                    name = t.get("tool_name") if isinstance(t, dict) else None
                    if name:
                        last_tools.append(name)
        except Exception:
            last_tools = []
    return {
        "ui_mode": "resume_chip",
        "task_id": task_id,
        "task_name": task_name,
        "last_worked_on": last_worked_on,
        "progress": progress or "",
        "next_steps": steps,
        "relevant_files": [],
        "last_tool": (last_tools[-1] if last_tools else None),
        "last_tools": last_tools,
        "brain_dump_notes": (last_user or {}).get("text") or ""
    }
