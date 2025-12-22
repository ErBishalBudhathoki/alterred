import asyncio
from typing import List, Dict, Any, Tuple, Optional
from google.adk.agents import LlmAgent
from orchestration.router import AgentRouter
from orchestration.safety import safety_monitor
from services.a2a_service import send_message, MessagePriority, connect_partner, get_or_create_partner_id

class OrchestrationManager:
    """
    Manages the execution of agents, including:
    - Routing requests
    - Parallel execution of multiple agents
    - Safety checks
    - Result aggregation
    - Agent-to-Agent communication via A2A Service
    """
    
    def __init__(self, agents: Dict[str, LlmAgent], runner_factory):
        self.router = AgentRouter()
        self.agents = agents
        self.runner_factory = runner_factory # Function to create a Runner for an agent
        
        # Ensure Orchestrator has a partner ID
        self.ensure_orchestrator_identity()

    def ensure_orchestrator_identity(self):
        """Ensure the orchestrator has a valid partner ID for A2A communication."""
        res = get_or_create_partner_id()
        if res.get("ok"):
            self.partner_id = res.get("partner_id")
            # print(f"Orchestrator initialized with Partner ID: {self.partner_id}")
        else:
            print("Failed to initialize Orchestrator Partner ID")

    async def _communicate_with_agent(self, agent_name: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Sends a message to a specific agent via the A2A service.
        Note: In a real distributed system, agents would have their own Partner IDs.
        Here, we simulate it or assume agents are addressable by name if we map them to PIDs.
        For now, since agents are local objects, we might still run them directly but use A2A for logging/queuing side effects.
        
        However, if we want to truly use A2A, we need target Partner IDs.
        Let's assume for this integration that we are logging the intent to communicate.
        """
        # Placeholder for mapping agent names to Partner IDs if they were remote.
        # For now, we just use the local execution flow but could log via A2A if needed.
        pass

    async def process_request(self, uid: str, session_id: str, text: str, run_agent_func) -> Tuple[str, List[Dict[str, Any]]]:
        """
        Process a user request through the orchestration layer.
        
        Args:
            uid: User ID
            session_id: Session ID
            text: User input text
            run_agent_func: The existing _run function from adk_app (dependency injection for now)
        """
        
        # 1. Pre-execution Safety Check
        safety_result = safety_monitor.pre_execution_check(text)
        if not safety_result["safe"]:
            return safety_result["override_response"], [{"ui_mode": "safety_override", "reason": safety_result["reason"]}]

        # 2. Determine Routes
        target_agents = self.router.determine_routes(text)
        
        # 3. Execution Strategy
        if not target_agents:
            # Default to Coordinator (handled by calling _run without override)
            response, tools = await run_agent_func(uid, session_id, text, override_agent=None)
            return safety_monitor.post_execution_check(response), tools
            
        if len(target_agents) == 1:
            # Single agent delegation
            agent_name = target_agents[0]
            agent = self.agents.get(agent_name)
            if agent:
                # INTEGRATION: Log/Queue the delegation via A2A service
                # We use a dummy PID for the internal agent for demonstration of the pattern
                # In a real setup, 'agent_name' would resolve to a remote PID.
                dummy_pid = f"PART-INT-{agent_name.upper()}"
                
                # Attempt to connect (idempotent) just to ensure structure exists
                # connect_partner(dummy_pid) 
                
                # Send async status message (fire and forget)
                await send_message(
                    partner_id=dummy_pid, 
                    message={
                        "type": "delegation", 
                        "user_id": uid, 
                        "session_id": session_id, 
                        "input": text
                    },
                    priority=MessagePriority.NORMAL,
                    sync=False
                )

                response, tools = await run_agent_func(uid, session_id, text, override_agent=agent)
                return safety_monitor.post_execution_check(response), tools
            else:
                # Fallback to coordinator if agent not found
                response, tools = await run_agent_func(uid, session_id, text, override_agent=None)
                return safety_monitor.post_execution_check(response), tools
        
        else:
            # Parallel Execution
            # We will run multiple agents and aggregate their responses.
            # Note: This assumes the _run function is safe to call concurrently.
            
            tasks = []
            for agent_name in target_agents:
                agent = self.agents.get(agent_name)
                if agent:
                    # INTEGRATION: Queue message for parallel execution
                    dummy_pid = f"PART-INT-{agent_name.upper()}"
                    await send_message(
                        partner_id=dummy_pid, 
                        message={
                            "type": "parallel_delegation", 
                            "user_id": uid, 
                            "session_id": session_id, 
                            "input": text
                        },
                        priority=MessagePriority.HIGH, # Parallel usually implies higher complexity/importance
                        sync=False
                    )
                    tasks.append(run_agent_func(uid, session_id, text, override_agent=agent))
            
            if not tasks:
                response, tools = await run_agent_func(uid, session_id, text, override_agent=None)
                return safety_monitor.post_execution_check(response), tools

            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            # Aggregate Results
            combined_text = ""
            combined_tools = []
            
            for i, res in enumerate(results):
                agent_name = target_agents[i]
                if isinstance(res, Exception):
                    combined_tools.append({"error": str(res), "agent": agent_name})
                    # INTEGRATION: Log failure
                    dummy_pid = f"PART-INT-{agent_name.upper()}"
                    await send_message(
                        partner_id=dummy_pid,
                        message={"type": "error", "error": str(res)},
                        priority=MessagePriority.HIGH,
                        sync=False
                    )
                    continue
                    
                resp_text, resp_tools = res
                
                # Format the combined text clearly
                agent_display_name = agent_name.replace("_", " ").title()
                combined_text += f"**{agent_display_name}**:\n{resp_text}\n\n"
                combined_tools.extend(resp_tools)
            
            return safety_monitor.post_execution_check(combined_text.strip()), combined_tools

