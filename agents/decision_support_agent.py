"""
Decision Support Agent
======================
Helps users overcome analysis paralysis and decision fatigue.

Implementation Details:
- Uses a Large Language Model (Gemini) to generate choices and recommendations.
- Defines specific tools for reducing options and matching motivation.
- Implements "Paralysis Protocol" to detect stuck states and intervene.

Design Decisions:
- 'Paralysis Protocol' offers a structured way to force a decision when stuck.
- Motivation matching helps frame tasks in a way that appeals to the user's current state (urgency vs. novelty).
- Choice reduction uses LLM to semantically group and select the best options.

Behavioral Specifications:
- Analyzes user input to detect decision blocks.
- Suggests simplified options or defaults to reduce cognitive load.
- Auto-decides if the user stalls (via UI instruction).
"""
import os
import json
from typing import List, Dict, Any, Optional
from google.adk.agents import LlmAgent
from agents.adk_model import get_adk_model
from agents.tools import reduce_options
from agents.common import auto_compact_callback

def default_generator(context: str, options: List[str] = []) -> Dict[str, Any]:
    """
    Generates a default option for a given context using LLM reasoning.
    
    Args:
        context (str): The situation requiring a decision.
        options (list): Optional list of available choices.

    Returns:
        dict: A dictionary containing the context and a recommended default action.
    """
    prompt = (
        f"Context: {context}\n"
        f"Options: {options}\n"
        "Task: Identify the SINGLE best default action for an ADHD user who is stuck. "
        "The default should be low-friction and safe.\n"
        "Output JSON: {'default_action': 'string', 'reasoning': 'string'}"
    )
    
    try:
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
            return json.loads(text)
    except Exception as e:
        print(f"Default generator failed: {e}")
        
    return {"context": context, "default": "Pick the simplest acceptable option.", "reasoning": "Fallback default."}


def motivation_matcher(state: str) -> Dict[str, Any]:
    """
    Identifies the user's current motivational state using keyword analysis.
    
    Args:
        state (str): The user's described state or feeling.

    Returns:
        dict: A dictionary classifying the motivation as 'urgency', 'novelty', 'interest', or 'challenge'.
    """
    s = state.lower()
    if any(x in s for x in ["urgent", "deadline", "late", "panic", "now"]):
        return {"motivation": "urgency", "strategy": "Focus on the immediate consequence and the relief of finishing."}
    if any(x in s for x in ["new", "novel", "bored", "different", "change"]):
        return {"motivation": "novelty", "strategy": "Try a new approach or environment to stimulate interest."}
    if any(x in s for x in ["hard", "complex", "impossible", "challenge"]):
        return {"motivation": "challenge", "strategy": "Gamify the difficulty - treat it like a boss battle."}
    if any(x in s for x in ["interest", "curious", "fun", "cool"]):
        return {"motivation": "interest", "strategy": "Follow your curiosity, but timebox it."}
        
    return {"motivation": "interest", "strategy": "Find one interesting aspect to hook into."}


def paralysis_protocol(options: List[str], context: str = "") -> Dict[str, Any]:
    """
    Initiates a protocol to break analysis paralysis.
    
    Args:
        options (list): A list of available choices.
        context (str): Context for the decision.

    Returns:
        dict: Instructions to reduce options, set a deadline, and auto-decide.
    """
    # 1. Reduce Options (using shared tool)
    reduction = reduce_options(options, max_options=3, context=context)
    reduced = reduction.get("reduced_options", options[:3])
    
    # 2. Generate Default
    default_res = default_generator(context, reduced)
    default_opt = default_res.get("default_action", reduced[0] if reduced else "None")

    result = {
        "ui_mode": "paralysis_breaker",
        "reduce_to": 3,
        "deadline_seconds": 60,
        "auto_decide": True,
        "default_action": default_opt,
        "options": reduced,
        "message": f"I've narrowed it down to these 3. You have 60 seconds to pick, or I'll go with: **{default_opt}**."
    }

    # Capture tool output for UI rendering
    from agents.context import current_tool_outputs
    try:
        outputs = current_tool_outputs.get()
        print(f"DEBUG: paralysis_protocol executing. Context outputs: {outputs}")
        if outputs is not None:
            outputs.append({
                "tool": "paralysis_protocol",
                "result": result,
                "ui_mode": "paralysis_breaker"
            })
            print(f"DEBUG: Appended output to context. New list: {outputs}")
    except Exception as e:
        print(f"DEBUG: Failed to access contextvars in tool: {e}")

    return result


def reevaluate_options(options: List[str], context: str = "") -> Dict[str, Any]:
    """
    Performs a comprehensive re-evaluation of options for ADHD users.
    
    This tool is used when the user explicitly requests a "deep dive", "analysis", 
    or "re-evaluation" instead of a quick decision. It provides structure to the
    thinking process without overwhelming the user.
    
    Args:
        options (list): A list of available choices.
        context (str): Context for the decision.

    Returns:
        dict: A structured analysis including pros/cons, patterns, and recommendation.
    """
    # Use the LLM to generate the analysis
    prompt = (
        f"Context: {context}\n"
        f"Options: {options}\n"
        "Task: Perform a supportive, ADHD-friendly re-evaluation of these options.\n"
        "Requirements:\n"
        "1. Contextual Anchor: Briefly validate why this decision matters.\n"
        "2. Analysis: For each option, list 1 Pro (why it helps) and 1 Con (effort required).\n"
        "3. Pattern Recognition: Mention if this fits a common ADHD trap (e.g., perfectionism, avoidance).\n"
        "4. Recommendation: Pick one based on 'Lowest Friction' or 'Highest Impact'.\n"
        "Output JSON: {'analysis': [{'option': 'string', 'pro': 'string', 'con': 'string'}], 'pattern_note': 'string', 'recommendation': 'string', 'rationale': 'string'}"
    )
    
    analysis_result = {}
    try:
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
            analysis_result = json.loads(text)
    except Exception as e:
        print(f"Re-evaluation generator failed: {e}")
        analysis_result = {
            "analysis": [],
            "pattern_note": "Unable to analyze patterns right now.",
            "recommendation": options[0] if options else "None",
            "rationale": "Defaulting to first option due to error."
        }

    # Format the output for the user
    formatted_analysis = "**Re-evaluation Analysis**\n\n"
    if analysis_result.get("pattern_note"):
        formatted_analysis += f"🧠 **Pattern Note:** {analysis_result['pattern_note']}\n\n"
    
    for item in analysis_result.get("analysis", []):
        formatted_analysis += f"**{item['option']}**\n"
        formatted_analysis += f"✅ {item['pro']}\n"
        formatted_analysis += f"⚠️ {item['con']}\n\n"
        
    formatted_analysis += f"👉 **Recommendation:** {analysis_result.get('recommendation')}\n"
    formatted_analysis += f"_{analysis_result.get('rationale')}_"

    result = {
        "ui_mode": "reevaluation_report",
        "structured_analysis": analysis_result,
        "message": formatted_analysis
    }

    # Capture tool output for UI rendering
    from agents.context import current_tool_outputs
    try:
        outputs = current_tool_outputs.get()
        if outputs is not None:
            outputs.append({
                "tool": "reevaluate_options",
                "result": result,
                "ui_mode": "reevaluation_report"
            })
    except Exception:
        pass

    return result


decision_support_agent = LlmAgent(
    model=get_adk_model(),
    name="decision_support_agent",
    description="Decision support delegation agent",
    instruction=(
        "You are the Decision Support Agent. Your goal is to help the user make decisions FAST. "
        "Detect analysis paralysis (stuck, overwhelmed, too many options). "
        "If the user says 'reduce: [options]', extract the options list and IMMEDIATELY run 'paralysis_protocol' on them. "
        "Use 'paralysis_protocol' to force a decision when the user is stuck. "
        "Use 'reduce_options' to filter long lists. "
        "Use 'motivation_matcher' to frame the decision correctly. "
        "Always provide a 'default' option if the user doesn't choose. "
        "Be direct and authoritative but supportive.\n\n"
        "EXCEPTION: If the user explicitly asks to 're-evaluate', 'analyze', 'compare', or 'deep dive' into options, "
        "do NOT use 'paralysis_protocol'. Instead, use the 'reevaluate_options' tool to provide the requested detailed analysis. "
        "This is important for users who need to process information before deciding."
    ),
    tools=[paralysis_protocol, reduce_options, motivation_matcher, default_generator, reevaluate_options],
    after_agent_callback=auto_compact_callback,
)
