"""
Agent Workflows
===============
Defines orchestration workflows that compose specialized agents.

Implementation Details:
- `task_execution_workflow`: Sequential pipeline for task breakdown → time management → decision support.
- `continuous_monitors`: Parallel monitors for ongoing time and energy tracking.

Design Decisions:
- Use composition over complex single-agent logic to keep responsibilities clear and testable.
"""
from google.adk.agents import SequentialAgent, ParallelAgent
from agents.taskflow_agent import taskflow_agent
from agents.time_perception_agent import time_perception_agent
from agents.energy_sensory_agent import energy_sensory_agent
from agents.decision_support_agent import decision_support_agent


task_execution_workflow = SequentialAgent(
    name="task_execution_workflow",
    agents=[taskflow_agent, time_perception_agent, decision_support_agent],
)


continuous_monitors = ParallelAgent(
    name="continuous_monitors",
    agents=[time_perception_agent, energy_sensory_agent],
)
