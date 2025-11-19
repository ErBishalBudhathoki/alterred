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