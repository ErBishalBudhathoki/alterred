from typing import Dict, Any, List, Optional
import re

class SafetyMonitor:
    """
    Monitors agent interactions for safety concerns relevant to neurodivergent users.
    - Prevents burnout-inducing suggestions
    - Detects distress signals
    - Ensures tone is appropriate
    """
    
    def __init__(self):
        self.burnout_patterns = [
            r"push through",
            r"just do it",
            r"don'?t stop",
            r"work (all|every) night",
            r"skip (sleep|meals?|break)"
        ]
        self.distress_patterns = [
            r"panic attack",
            r"can'?t breathe",
            r"having a meltdown",
            r"in shutdown mode",
            r"scared for my safety",
            r"harm myself"
        ]

    def pre_execution_check(self, user_input: str) -> Dict[str, Any]:
        """
        Checks user input for distress signals before agent execution.
        Returns a dict with 'safe': bool and optional 'override_response'.
        """
        text_lower = user_input.lower()
        
        for pattern in self.distress_patterns:
            if re.search(pattern, text_lower):
                return {
                    "safe": False,
                    "reason": "distress_detected",
                    "override_response": (
                        "I hear that you're in distress. Let's pause everything. "
                        "Please take a slow breath. Do you need to step away from the screen for a moment? "
                        "I'm here, and we don't need to do anything right now."
                    )
                }
        
        return {"safe": True}

    def post_execution_check(self, agent_response: str) -> str:
        """
        Sanitizes agent response to ensure it doesn't encourage unhealthy behaviors.
        Returns the (potentially modified) response.
        """
        text_lower = agent_response.lower()
        
        for pattern in self.burnout_patterns:
            if re.search(pattern, text_lower):
                # Replace with a gentler suggestion
                agent_response = (
                    f"{agent_response}\n\n(Safety Note: Please remember to prioritize your well-being. "
                    "It's okay to take a break if you need one.)"
                )
                break
                
        return agent_response

safety_monitor = SafetyMonitor()
