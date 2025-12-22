# Multi-Agent Orchestration System

A comprehensive system for coordinating multiple AI agents to provide intelligent, context-aware ADHD support.

## Architecture Overview

### Core Components

1. **Agent Registry** - Central registry of all available agents
2. **Orchestration Engine** - Executes complex multi-step workflows  
3. **Workflow Definitions** - Declarative workflow configurations
4. **Safety Monitor** - Proactive monitoring and intervention
5. **Execution Manager** - Handles parallel/sequential execution
6. **Integration Layer** - Connects with existing UI components

### Agent Types

#### Reactive Agents
- **External Brain Agent** - Capture thoughts, context, working memory
- **Task Prioritization Agent** - Prioritize and organize tasks
- **Decision Helper Agent** - Reduce decision paralysis
- **Time Estimation Agent** - Provide realistic time estimates

#### Proactive Agents  
- **Energy Assessment Agent** - Monitor energy levels and mood
- **Hyperfocus Detection Agent** - Detect and manage hyperfocus
- **Break Enforcement Agent** - Force breaks when needed
- **Calendar Guardian Agent** - Appointment and schedule management

#### Workflow Agents
- **Morning Routine Agent** - Orchestrate morning startup
- **Focus Session Agent** - Manage focused work periods
- **Transition Agent** - Handle context switching

### Execution Patterns

#### Sequential Execution
```
Energy Assessment → Task Planning → Time Estimation → Execution
```

#### Parallel Execution  
```
Energy Assessment + Calendar Check + Working Memory Review
```

#### Conditional Execution
```
IF energy_low THEN gentle_tasks ELSE challenging_tasks
```

#### Interrupt Execution
```
Hyperfocus Detection → INTERRUPT → Force Break
```

## Test Scenarios

### 1. Morning Routine Workflow
```
1. Energy Assessment Agent - Check sleep, mood, energy
2. Calendar Guardian Agent - Review today's appointments  
3. Task Prioritization Agent - Plan day based on energy/calendar
4. Time Estimation Agent - Provide realistic time blocks
5. External Brain Agent - Capture any overnight thoughts
```

### 2. Decision Paralysis Detection & Resolution
```
1. Decision Helper Agent - Detect paralysis patterns
2. Task Prioritization Agent - Reduce options to 2-3 choices
3. Time Estimation Agent - Add time pressure for decision
4. External Brain Agent - Capture decision for future reference
```

### 3. Hyperfocus Protection System
```
1. Hyperfocus Detection Agent - Monitor work patterns
2. Break Enforcement Agent - Interrupt when threshold reached
3. Energy Assessment Agent - Check fatigue levels
4. External Brain Agent - Capture context for resumption
```

## Safety Features

- **Interrupt Capability** - Safety agents can override any workflow
- **Fallback Handling** - Graceful degradation when agents fail
- **User Override** - User can always take manual control
- **Privacy Protection** - Sensitive data handling
- **Rate Limiting** - Prevent agent spam/overload

## Integration Points

### UI Integration
- **Dashboard Orchestration Panel** - Central control and monitoring
- **Chat Mode Integration** - Orchestration suggestions in chat
- **Voice Mode Integration** - Voice-triggered workflows
- **Background Monitoring** - Proactive agent triggers

### Backend Integration
- **Existing API Compatibility** - Works with current backend
- **Agent Service Layer** - New orchestration endpoints
- **State Synchronization** - Consistent state across agents
- **Logging & Analytics** - Full workflow observability

## File Structure

```
lib/core/orchestration/
├── README.md                          # This file
├── models/                           # Data models
│   ├── agent_model.dart
│   ├── workflow_model.dart
│   └── execution_context.dart
├── agents/                           # Agent implementations
│   ├── base/
│   │   ├── agent_base.dart
│   │   ├── reactive_agent.dart
│   │   └── proactive_agent.dart
│   ├── energy_assessment_agent.dart
│   ├── decision_helper_agent.dart
│   ├── hyperfocus_detection_agent.dart
│   ├── time_estimation_agent.dart
│   └── break_enforcement_agent.dart
├── engine/                           # Core orchestration
│   ├── orchestration_engine.dart
│   ├── workflow_executor.dart
│   ├── agent_registry.dart
│   └── safety_monitor.dart
├── workflows/                        # Workflow definitions
│   ├── morning_routine_workflow.dart
│   ├── decision_paralysis_workflow.dart
│   └── hyperfocus_protection_workflow.dart
├── state/                           # State management
│   └── orchestration_provider.dart
└── ui/                              # UI components
    ├── orchestration_dashboard.dart
    ├── workflow_progress_widget.dart
    └── agent_status_panel.dart
```

## Key Benefits

1. **Intelligent Coordination** - Agents work together, not in isolation
2. **Context Awareness** - Decisions based on full user context
3. **Proactive Support** - Anticipates needs before user asks
4. **Safety First** - Built-in protections and overrides
5. **ADHD Optimized** - Designed specifically for ADHD challenges
6. **Extensible** - Easy to add new agents and workflows
7. **Observable** - Full visibility into system behavior