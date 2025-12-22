# Energy & Sensory Management

## Description
Learns energy patterns, detects sensory overload from text, and balances routine vs novelty.

## Technical Specs
- Agent: `agents/energy_sensory_agent.py`
- Tools:
  - `match_task_to_energy(task_list, current_energy)`
  - `detect_sensory_overload(text)`
  - `routine_vs_novelty_balancer(day_context)`
- Memory updates via `services/memory_bank.py`:
  - `add_sensory_trigger(trigger)` appends triggers in `memory_bank.sensory_triggers`
  - `record_energy_level(level)` stores daily energy logs
  - `add_successful_strategy(category, strategy)` updates strategies

## Configuration
- Uses `DEFAULT_MODEL`
- No additional env keys

## Testing Procedures
- Trigger `detect_sensory_overload('The room is loud and bright')` → expect `overload=True`
- Verify CLI stores sensory triggers to Firestore memory_bank
- Call `match_task_to_energy(['email','code'], 3)` → expect `low_cognitive` recommendation

## Known Limitations
- Overload detection is keyword-based; future improvement will use learned patterns and signals.