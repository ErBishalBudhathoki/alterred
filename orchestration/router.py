from typing import List, Dict, Any, Optional, Tuple
import re

class AgentRouter:
    """
    Handles intelligent routing of user requests to appropriate specialized agents.
    Supports identifying single or multiple intents for parallel execution.
    """
    
    def __init__(self):
        # Define regex patterns for each agent to allow for more flexible matching
        self.routes = {
            "time_perception_agent": {
                "patterns": [
                    r"\b(timer|countdown|alarm)\b",
                    r"\b(minutes?|hours?|seconds?)\b",
                    r"\b(how long|time left|time estimate|estimation)\b",
                    r"\b(schedule|calendar|when|meeting)\b",
                    r"\b(reality check|time optimism|usually wrong)\b",
                    r"\b(hyperfocus|break|transition)\b",
                    r"\b(focus session|deep work|pomodoro)\b",
                    r"\b(time management|time perception)\b",
                    r"\b(conflicts|upcoming|next event)\b"
                ],
                "priority": 10
            },
            "energy_sensory_agent": {
                "patterns": [
                    r"\b(tired|exhausted|drained|burnout)\b",
                    r"\b(energy|battery) (is )?(low|empty)\b",
                    r"\b(loud|bright|noisy|crowded)\b",
                    r"\b(overstimulated|sensory|overload)\b"
                ],
                "priority": 20
            },
            "decision_support_agent": {
                "patterns": [
                    r"\b(choose|decide|pick)\b",
                    r"\b(options|choices|alternatives)\b",
                    r"\b(stuck|paralysis|cant decide)\b",
                    r"\b(too many|overwhelmed)\b",
                    r"\b(what should i do|help me select)\b",
                    r"\b(which one|make up my mind)\b",
                    r"\b(decision fatigue)\b",
                    r"\b(reduce)\b"
                ],
                "priority": 15
            },
            "external_brain_agent": {
                "patterns": [
                    r"\b(capture|note|record|save)\b",
                    r"\b(remember|remind)\b",
                    r"\b(voice|transcript)\b",
                    r"\b(partner|accountability|connect)\b",
                    r"\b(restore|context)\b"
                ],
                "priority": 5
            },
            "taskflow_agent": {
                "patterns": [
                    r"\b(task|todo|job|project)\b",
                    r"\b(break down|atomize|steps)\b",
                    r"\b(start|begin|focus)\b",
                    r"\b(body doubl(e|ing))\b",
                    r"\b(boring|tedious|hard)\b"
                ],
                "priority": 25
            }
        }

    def determine_routes(self, text: str) -> List[str]:
        """
        Analyzes the text and returns a list of agent names to handle the request.
        If multiple distinct intents are detected, returns multiple agents.
        """
        text_lower = text.lower()
        
        # Immediate routing for Dopamine Card selections to ensure low latency
        # and prevent parallel agent confusion
        if text_lower.startswith("i choose:"):
            return ["taskflow_agent"]

        # Calendar-first routing: let the coordinator handle calendar queries
        # to ensure MCP tools are available
        if (
            ("calendar" in text_lower) or
            ("events" in text_lower) or
            ("schedule" in text_lower) or
            ("meeting" in text_lower)
        ):
            return []
        matched_agents = set()
        
        # Check for specific multi-agent scenarios (heuristics)
        # E.g., "Set a timer and break down this task" -> Time + Task
        
        for agent_name, config in self.routes.items():
            for pattern in config["patterns"]:
                if re.search(pattern, text_lower):
                    matched_agents.add(agent_name)
                    break
        
        # Refinement: If "body double" is present, TaskFlow is mandatory/primary
        if "body double" in text_lower or "body doubling" in text_lower:
            return ["taskflow_agent"] # Body doubling is a specific mode, usually exclusive
            
        # If no specific agents matched, return empty list (implies Coordinator)
        if not matched_agents:
            return []
            
        # Sort by priority if we want to limit parallel execution, 
        # but for now, return all matched for potential parallel processing
        # (The manager will decide whether to run parallel or sequential)
        
        return list(matched_agents)

    def get_routing_reason(self, text: str, agent_name: str) -> str:
        """Returns a human-readable reason why an agent was selected."""
        if agent_name not in self.routes:
            return "Default routing"
            
        text_lower = text.lower()
        for pattern in self.routes[agent_name]["patterns"]:
            if re.search(pattern, text_lower):
                return f"Detected keyword matching pattern: {pattern}"
        return "Manual selection"
