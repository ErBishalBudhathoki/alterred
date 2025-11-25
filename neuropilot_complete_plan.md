# Altered - Executive Function Companion for Neurodivergent Adults
## Complete Development Plan (Nov 15 - Nov 29, 2025)

---

## 🎯 PROJECT OVERVIEW

**Track**: Agents for Good (Accessibility/Healthcare)

**Problem Statement**: 
Neurodivergent adults (ADHD, Autism, Executive Dysfunction) struggle with task initiation, time blindness, decision paralysis, working memory, and sensory overload. Traditional productivity tools fail because they don't understand how neurodivergent brains actually work - they add cognitive load instead of reducing it.

**Solution**:
NeuroPilot is an AI-powered executive function prosthetic that works WITH your brain, not against it. It's a multi-agent system that learns your unique neurotype patterns, provides body-doubling support, breaks through decision paralysis, compensates for time blindness, and prevents burnout while respecting both structure needs and novelty cravings.

**Unique Value**:
- First productivity tool designed FOR neurodivergent executive function, not neurotypical planning
- Learns YOUR specific dysfunction patterns and compensates automatically
- Provides emotional support without judgment during shutdowns/meltdowns
- Combines ADHD's need for novelty with autism's need for predictability

---

## 📅 14-DAY DEVELOPMENT TIMELINE

### **Phase 1: Foundation & Setup (Days 1-3: Nov 15-17)**

#### Day 1 (Nov 15) - Project Setup & Architecture Design
**Time: 4-6 hours**
- [ ] Set up development environment (Python 3.9+, ADK installation)
- [ ] Create GitHub repository with proper structure
- [ ] Initialize ADK project: `adk create neuropilot`
- [ ] Set up Google Cloud project for Gemini API
- [ ] Configure .env file with API keys
- [ ] Design complete system architecture diagram
- [ ] Write detailed agent interaction flowchart
- [ ] Create project documentation structure

**Deliverables**: 
- Working dev environment
- GitHub repo with README skeleton
- Architecture diagrams (draw.io or Lucidchart)
- Project roadmap document

#### Day 2 (Nov 16) - Core Agent #1: Coordinator + Basic Tools
**Time: 6-8 hours**
- [ ] Implement **NeuroBrain Orchestrator** (main agent)
  - Basic LLM agent with Gemini
  - Conversation state management
  - User profile initialization
- [ ] Create first 2 custom tools:
  - `analyze_brain_state()` - detects focus/scattered/overwhelmed from text
  - `get_current_context()` - retrieves what user was working on
- [ ] Implement InMemorySessionService
- [ ] Test orchestrator with simple queries
- [ ] Add logging for observability

**Code Focus**:
```python
# agents/coordinator_agent.py
from google.adk.agents.llm_agent import Agent
from google.adk.sessions import InMemorySessionService

root_agent = Agent(
    model='gemini-2.0-flash-001',
    name='neuropilot_coordinator',
    instruction="""You are NeuroPilot, an executive function companion for 
    neurodivergent adults. Analyze the user's brain state, understand their 
    specific executive function challenges, and route to appropriate agents.""",
    tools=[analyze_brain_state, get_current_context]
)
```

#### Day 3 (Nov 17) - Agent #2: TaskFlow Agent
**Time: 6-8 hours**
- [ ] Implement **TaskFlow Agent** with Loop workflow
- [ ] Create task breakdown tool: `atomize_task()`
- [ ] Implement body-doubling mode (constant presence responses)
- [ ] Add dopamine optimizer: `reframe_task()`
- [ ] Create sequential workflow for task management
- [ ] Test task breakdown for complex projects
- [ ] Add code execution tool for task priority calculations

**Key Features**:
- Breaks "write report" into 15 micro-tasks
- Provides encouragement without being patronizing
- Uses ADHD-friendly language (urgency, novelty, interest)

---

### **Phase 2: Core Agents Development (Days 4-7: Nov 18-21)**

#### Day 4 (Nov 18) - Agent #3: Time Perception Agent
**Time: 6-8 hours**
- [ ] Implement **Time Perception Agent** (Parallel execution)
- [ ] Create custom tools:
  - `estimate_real_time()` - corrects time optimism
  - `create_countdown()` - visual time remaining
  - `detect_hyperfocus()` - monitors time spent on task
- [ ] Implement time tracking with Code Execution
- [ ] Add transition helpers (leaving reminders)
- [ ] Test with real-world scenarios (meetings, deadlines)
- [ ] Add calendar integration via MCP (Google Calendar)

**Innovation**: Learns YOUR time estimation errors and auto-corrects

#### Day 5 (Nov 19) - Agent #4: Energy/Sensory Management
**Time: 6-8 hours**
- [ ] Implement **Energy Management Agent** (Loop + Memory Bank)
- [ ] Create Memory Bank for long-term pattern storage
- [ ] Build energy tracking system
- [ ] Implement sensory overload detection from text patterns
- [ ] Add routine vs novelty balancer
- [ ] Create custom tool: `match_task_to_energy()`
- [ ] Test pattern recognition across multiple sessions

**Memory Bank Stores**:
- Peak productivity hours
- Sensory triggers
- Energy depletion patterns
- Successful strategies

#### Day 6 (Nov 20) - Agent #5: Decision Support Agent
**Time: 5-7 hours**
- [ ] Implement **Decision Support Agent** (Sequential)
- [ ] Create choice reduction algorithms
- [ ] Implement paralysis breaker with timeout
- [ ] Add default action generator
- [ ] Test with decision paralysis scenarios
- [ ] Add motivation type matcher (ADHD: urgency/novelty)
- [ ] Implement context engineering for option summarization

**Key Feature**: Reduces 20 options to 3, auto-decides if user stalls 60 sec

#### Day 7 (Nov 21) - Agent #6: External Brain Agent + A2A
**Time: 6-8 hours**
- [ ] Implement **External Brain Agent** (Long-running + A2A)
- [ ] Create universal capture system (voice → structured tasks)
- [ ] Implement context restoration for interrupted tasks
- [ ] Add A2A protocol setup for accountability partners
- [ ] Create appointment guardian with Google Calendar
- [ ] Implement working memory support tools
- [ ] Test A2A communication between two agent instances

**A2A Innovation**: Connect user's agent with friend/coach's agent for accountability

---

### **Phase 3: Integration & Advanced Features (Days 8-10: Nov 22-24)**

#### Day 8 (Nov 22) - Multi-Agent Orchestration
**Time: 7-9 hours**
- [ ] Integrate all 6 agents into coordinated system
- [ ] Implement intelligent agent routing
- [ ] Add parallel agent execution where appropriate
- [ ] Create agent delegation logic
- [ ] Test complete workflows end-to-end
- [ ] Implement safety callbacks
- [ ] Add error handling and fallbacks

**Test Scenarios**:
1. Morning routine: Energy assessment → Task planning → Time estimation
2. Decision paralysis: Detect → Reduce options → Auto-decide
3. Hyperfocus protection: Detect → Interrupt → Force break

#### Day 9 (Nov 23) - Observability & Evaluation
**Time: 6-8 hours**
- [ ] Implement comprehensive logging system
- [ ] Add tracing for all agent interactions
- [ ] Create metrics dashboard:
  - Task completion rate
  - Time estimation accuracy
  - Decision paralysis resolution time
  - Burnout prevention triggers
- [ ] Implement agent evaluation framework
- [ ] Create before/after comparison metrics
- [ ] Add performance monitoring
- [ ] Test observability stack

**Metrics to Track**:
- Tasks completed vs abandoned
- Time accuracy improvement
- Stress level changes (text sentiment)
- Strategy effectiveness

#### Day 10 (Nov 24) - Context Engineering & Memory Optimization
**Time: 5-7 hours**
- [ ] Implement context compaction for long sessions
- [ ] Optimize Memory Bank queries
- [ ] Add context window management
- [ ] Implement smart summarization
- [ ] Test memory persistence across sessions
- [ ] Add memory retrieval optimization
- [ ] Create memory cleanup routines

---

### **Phase 4: Deployment & Documentation (Days 11-12: Nov 25-26)**

#### Day 11 (Nov 25) - Deployment to Agent Engine
**Time: 6-8 hours**
- [ ] Containerize application with Docker
- [ ] Deploy to Vertex AI Agent Engine
- [ ] Configure Cloud Run for API server
- [ ] Test deployed agents
- [ ] Set up monitoring and logging
- [ ] Configure authentication
- [ ] Test A2A protocol in production
- [ ] Create deployment documentation

**Deployment Architecture**:
```
User Interface (CLI/Web)
    ↓
FastAPI Server (Cloud Run)
    ↓
Agent Engine (Vertex AI)
    ↓
6 Specialized Agents
    ↓
Tools: MCP (Calendar), Memory Bank, Code Execution
```

#### Day 12 (Nov 26) - Documentation & Code Quality
**Time: 6-8 hours**
- [ ] Write comprehensive README.md
- [ ] Document architecture with diagrams
- [ ] Add inline code comments
- [ ] Create setup instructions
- [ ] Write API documentation
- [ ] Add usage examples
- [ ] Create troubleshooting guide
- [ ] Record code walkthrough for video

**README Structure**:
1. Problem & Solution
2. Architecture Overview (with diagram)
3. Installation & Setup
4. Usage Guide
5. Agent Descriptions
6. Technical Implementation
7. Evaluation Results
8. Future Enhancements

---

### **Phase 5: Video & Writeup (Days 13-14: Nov 27-29)**

#### Day 13 (Nov 27) - Video Production
**Time: 4-6 hours**
- [ ] Write video script (under 3 minutes)
- [ ] Create demo scenarios
- [ ] Record screen demos:
  - Task breakdown demo
  - Time blindness compensation
  - Decision paralysis breaker
  - Body doubling mode
- [ ] Record voice narration
- [ ] Edit video (iMovie, DaVinci Resolve, or CapCut)
- [ ] Add architecture diagrams
- [ ] Export and upload to YouTube

**Video Structure (3 min)**:
- 0:00-0:30 - Problem Statement (neurodivergent struggles)
- 0:30-1:00 - Why Agents? (multi-faceted solution)
- 1:00-1:45 - Architecture & Agent Roles
- 1:45-2:30 - Live Demo (3 scenarios)
- 2:30-3:00 - Tech Stack & Impact

#### Day 14 (Nov 28-29) - Final Writeup & Submission
**Time: 4-6 hours**
- [ ] Write complete project writeup (< 1500 words)
- [ ] Create compelling title and subtitle
- [ ] Design thumbnail image
- [ ] Finalize GitHub repository
- [ ] Test all code one final time
- [ ] Proofread documentation
- [ ] **SUBMIT on Kaggle by Dec 1, 11:59 AM PT**

---

## 🏗️ TECHNICAL ARCHITECTURE

### **System Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    USER INTERFACE                           │
│              (CLI / Web UI / Mobile)                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              ALTERED COORDINATOR                         │
│         (Main Orchestrator - Gemini 2.0)                    │
│  • Analyzes brain state                                     │
│  • Routes to specialized agents                             │
│  • Manages conversation flow                               │
└──┬────────┬──────────┬──────────┬──────────┬───────────────┘
   │        │          │          │          │
   ▼        ▼          ▼          ▼          ▼
┌─────┐ ┌──────┐ ┌─────────┐ ┌────────┐ ┌──────────┐
│Task │ │Time  │ │Energy/  │ │Decision│ │External  │
│Flow │ │Percep│ │Sensory  │ │Support │ │Brain     │
│Agent│ │tion  │ │Agent    │ │Agent   │ │Agent     │
└──┬──┘ └──┬───┘ └────┬────┘ └───┬────┘ └────┬─────┘
   │       │          │           │           │
   ▼       ▼          ▼           ▼           ▼
┌─────────────────────────────────────────────────────────────┐
│                    TOOLS LAYER                              │
│  • MCP: Google Calendar, Task Management                    │
│  • Code Execution: Time calculations, Priority ranking      │
│  • Custom Tools: Task atomizer, Energy matcher             │
│  • Google Search: Resources, Support groups                │
└─────────────────────────────────────────────────────────────┘
   │                                              │
   ▼                                              ▼
┌────────────────────┐                 ┌──────────────────┐
│ SESSION MANAGEMENT │                 │   MEMORY BANK    │
│ (InMemorySession)  │                 │ (Long-term       │
│ • Current state    │                 │  patterns)       │
│ • Today's context  │                 │ • User behaviors │
└────────────────────┘                 │ • Strategies     │
                                       │ • Preferences    │
                                       └──────────────────┘
```

### **Agent Workflow Types**

1. **Sequential**: Coordinator → TaskFlow → Time Perception → Decision
2. **Parallel**: Energy + Sensory monitoring alongside task execution
3. **Loop**: TaskFlow continuously checks progress, adjusts strategy
4. **Long-running**: External Brain persists across days/weeks

### **Memory Architecture**

```python
# Short-term (Session)
InMemorySessionService:
  - current_task
  - brain_state: "focused" | "scattered" | "overwhelmed"
  - energy_level: 1-10
  - tasks_today: []

# Long-term (Memory Bank)
MemoryBank:
  - time_estimation_error_pattern: {actual: [], estimated: []}
  - peak_hours: ["9-11am", "3-5pm"]
  - sensory_triggers: ["fluorescent lights", "loud spaces"]
  - successful_strategies: {
      "task_initiation": ["5-min timer", "body doubling"],
      "decision_making": ["reduce to 2 options"]
    }
  - hyperfocus_patterns: ["coding", "gaming", "research"]
```

---

## 📊 EVALUATION FRAMEWORK

### **Quantitative Metrics**
1. **Task Completion Rate**: Track % of started tasks completed
2. **Time Accuracy**: Compare estimated vs actual time (reduce error by 40%)
3. **Decision Speed**: Measure time to resolve choice paralysis (target: <2 min)
4. **Burnout Prevention**: Track overwhelm episodes (reduce by 50%)
5. **Agent Response Time**: Target <2 seconds per agent invocation

### **Qualitative Assessment**
1. **User Stress Level**: Text sentiment analysis over time
2. **Strategy Effectiveness**: Which interventions work best?
3. **Engagement**: Daily active usage, feature adoption

### **Before/After Comparison**
- Week 1 (no NeuroPilot): Baseline productivity metrics
- Week 2-4 (with NeuroPilot): Improved metrics
- Survey: User-reported quality of life improvement

---

## 🛠️ DEVELOPMENT RESOURCES

### **Essential Documentation**
1. **ADK Documentation**: https://google.github.io/adk-docs/
2. **ADK Python GitHub**: https://github.com/google/adk-python
3. **ADK Samples**: https://github.com/google/adk-samples
4. **A2A Protocol**: https://a2a-protocol.org/latest/
5. **Gemini API Docs**: https://ai.google.dev/gemini-api/docs

### **Code References**
1. **Multi-Agent Tutorial**: https://google.github.io/adk-docs/tutorials/
2. **Memory Bank Example**: https://github.com/google/adk-samples/tree/main/python
3. **MCP Integration**: https://google.github.io/adk-docs/features/mcp/
4. **A2A Setup**: https://github.com/a2aproject/a2a-python

### **Tools & Libraries**
```python
# requirements.txt
google-adk>=0.3.0
google-genai>=1.0.0
fastapi>=0.104.0
uvicorn>=0.24.0
pydantic>=2.5.0
python-dotenv>=1.0.0
```

### **Development Tools**
- **IDE**: VS Code with Python extension
- **Testing**: `adk web` for interactive testing
- **Deployment**: Docker, Cloud Run, Agent Engine
- **Diagramming**: Draw.io, Lucidchart, or Excalidraw
- **Video**: ScreenFlow, OBS Studio, or Loom

---

## 🎯 SCORING OPTIMIZATION

### **Category 1: The Pitch (30 points)**

**Core Concept & Value (15 points)**
- ✅ Clear, urgent problem (executive dysfunction affects 15% of adults)
- ✅ Novel solution (first tool built FOR neurodivergent brains)
- ✅ Agent-centric (6 specialized agents, each essential)
- ✅ Measurable impact (40% productivity increase, 50% burnout reduction)

**Writeup (15 points)**
- ✅ Compelling narrative with personal connection
- ✅ Clear architecture explanation
- ✅ Journey from problem → solution → impact
- ✅ Well-structured, under 1500 words

### **Category 2: Implementation (70 points)**

**Technical Implementation (50 points)**
Meeting ALL requirements:
- ✅ Multi-agent system: 6 specialized agents
- ✅ Agent types: LLM, Parallel, Sequential, Loop
- ✅ Tools: MCP (Calendar), Custom (10+), Code Execution, Google Search
- ✅ Long-running: External Brain persists across days
- ✅ Sessions: InMemorySessionService
- ✅ Memory: Memory Bank for long-term patterns
- ✅ Context Engineering: Compaction of long sessions
- ✅ Observability: Logging, Tracing, Metrics dashboard
- ✅ Evaluation: Before/after metrics
- ✅ A2A Protocol: Accountability partner connection
- ✅ Clean, commented code

**Documentation (20 points)**
- ✅ Comprehensive README with setup instructions
- ✅ Architecture diagrams
- ✅ Agent interaction flowcharts
- ✅ Code comments explaining design decisions
- ✅ Troubleshooting guide

### **Bonus Points (20 points max → 100 total)**

- ✅ **Gemini Usage (5 pts)**: All agents powered by Gemini 2.0
- ✅ **Deployment (5 pts)**: Deployed to Agent Engine + Cloud Run
- ✅ **YouTube Video (10 pts)**: 3-min demo with architecture
- **Total Bonus**: 20 points

**Projected Score**: 95-100 points

---

## 💡 IMPLEMENTATION TIPS

### **Start Simple, Iterate**
- Day 1-3: Get ONE agent working perfectly
- Day 4-7: Add agents incrementally
- Day 8-10: Polish and integrate
- Don't try to build everything at once!

### **Testing Strategy**
- Test each agent individually with `adk web`
- Create test scenarios for each use case
- Use real neurodivergent examples (Reddit posts)
- Test memory persistence across sessions

### **Common Pitfalls to Avoid**
1. **Over-engineering**: Start with working code, optimize later
2. **Memory leaks**: Clear session data appropriately
3. **Context overflow**: Implement compaction early
4. **API quotas**: Monitor Gemini API usage
5. **Deployment issues**: Test locally thoroughly first

### **Time Management**
- Allocate 6-8 hours per day (realistic for working developer)
- Use Pomodoro: 50 min work, 10 min break
- Don't skip documentation - it's 20% of score!
- Buffer last 2 days for unexpected issues

---

## 🚀 POST-SUBMISSION OPPORTUNITIES

If this project succeeds:
1. **Open Source Community**: Release on GitHub, build community
2. **Research Paper**: Publish findings on neurodivergent productivity
3. **Startup Potential**: 15% of adults = $5B+ market
4. **Google Partnership**: Potential feature in Agent Engine examples
5. **Accessibility Impact**: Help millions of neurodivergent individuals

---

## 📝 NEXT STEPS

1. **Start Today (Nov 15)**: Set up environment, create GitHub repo
2. **Join Kaggle Discord**: Connect with other participants
3. **Get API Keys**: Google AI Studio, Vertex AI
4. **Review ADK Docs**: Spend 1-2 hours reading tutorials
5. **Create Architecture Diagram**: Visual planning before coding

**YOU CAN DO THIS!** 14 days is tight but achievable. Focus on building a WORKING system that demonstrates the concepts, even if not perfectly polished. Judges value innovation and execution over perfection.

---

## 📞 SUPPORT RESOURCES

- **ADK Reddit**: r/agentdevelopmentkit
- **Kaggle Discord**: Connect with capstone participants
- **Google AI Studio**: For testing Gemini
- **Stack Overflow**: Tag questions with `google-adk`

**Remember**: The goal is to showcase your learning, not build a production-ready product. Focus on demonstrating the 3+ required features with clean, commented code!

Good luck! 🎉
