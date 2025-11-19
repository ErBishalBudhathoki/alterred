from agents.taskflow_agent import taskflow_agent
from agents.time_perception_agent import time_perception_agent
from agents.energy_sensory_agent import energy_sensory_agent
from agents.decision_support_agent import decision_support_agent
from agents.external_brain_agent import external_brain_agent


def test_agents_exist():
    assert taskflow_agent is not None
    assert time_perception_agent is not None
    assert energy_sensory_agent is not None
    assert decision_support_agent is not None
    assert external_brain_agent is not None