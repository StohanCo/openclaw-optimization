# Multi-Agent Setup: UX, Marketing, Coding, Engineering and More

This guide walks through building a production-ready multi-agent team in OpenClaw,
where each specialist agent has its own workspace, persona, model assignment, and
communication channel — and a central orchestrator delegates tasks between them.

---

## Architecture Overview

```
User / Slack / Discord
        │
        ▼
┌─────────────────────┐
│   ORCHESTRATOR      │  Claude Opus / Sonnet
│   (Project Manager) │  Reads intent, routes tasks
└──────────┬──────────┘
           │ delegates
    ┌──────┴───────────────────────────┐
    │              │                   │
    ▼              ▼                   ▼
┌────────┐  ┌───────────┐  ┌────────────────┐
│  UX    │  │ Marketing │  │    Coding      │
│ Agent  │  │  Agent    │  │    Agent       │
│Sonnet  │  │  Sonnet   │  │  Sonnet/Local  │
└────────┘  └───────────┘  └───────┬────────┘
                                   │ spawns
                          ┌────────┴─────────┐
                          ▼                  ▼
                   ┌────────────┐  ┌─────────────────┐
                   │Engineering │  │  QA / Testing   │
                   │  Agent     │  │    Agent        │
                   │ Local LLM  │  │   Local LLM     │
                   └────────────┘  └─────────────────┘
```

**Key principle:** Only the Orchestrator needs a premium model. Specialist agents use
Sonnet or a local model appropriate to their task complexity.

---

## 1. Plan Your Agent Roster

Before configuring, decide on a minimal but complete agent team:

| Agent ID | Role | Model | Channel Binding |
|---|---|---|---|
| `orchestrator` | Routes tasks, synthesises results | Claude Opus (sparingly) | All channels |
| `ux` | Wireframes, user research, design feedback | Claude Sonnet | Slack #design |
| `marketing` | Copy, campaigns, analytics, SEO | Claude Sonnet | Slack #marketing |
| `coding` | Feature development, code review | Claude Sonnet / Local | Discord #dev |
| `engineering` | Architecture, infra, CI/CD | Claude Sonnet / Local | Discord #engineering |
| `qa` | Test generation, bug triage | Local LLM | Automated |

---

## 2. Create Each Agent

```bash
# Add each agent with an interactive wizard
openclaw agents add orchestrator
openclaw agents add ux
openclaw agents add marketing
openclaw agents add coding
openclaw agents add engineering
openclaw agents add qa

# Confirm all agents are registered
openclaw agents list
```

---

## 3. Configure the Main openclaw.json

Copy `configs/openclaw.json` from this repo to `~/.openclaw/openclaw.json`, then
edit the channel IDs and API keys to match your setup.

The key sections are:

```json
{
  "agents": {
    "list": [
      { "id": "orchestrator", "name": "Project Manager",
        "workspace": "~/.openclaw/workspace-orchestrator" },
      { "id": "ux",           "name": "UX Designer",
        "workspace": "~/.openclaw/workspace-ux" },
      { "id": "marketing",    "name": "Marketing Lead",
        "workspace": "~/.openclaw/workspace-marketing" },
      { "id": "coding",       "name": "Senior Developer",
        "workspace": "~/.openclaw/workspace-coding" },
      { "id": "engineering",  "name": "Platform Engineer",
        "workspace": "~/.openclaw/workspace-engineering" },
      { "id": "qa",           "name": "QA Analyst",
        "workspace": "~/.openclaw/workspace-qa" }
    ]
  },
  "bindings": [
    { "agentId": "orchestrator", "match": { "channel": "slack",   "accountId": "main"        } },
    { "agentId": "ux",           "match": { "channel": "slack",   "accountId": "design"      } },
    { "agentId": "marketing",    "match": { "channel": "slack",   "accountId": "marketing"   } },
    { "agentId": "coding",       "match": { "channel": "discord", "accountId": "dev"         } },
    { "agentId": "engineering",  "match": { "channel": "discord", "accountId": "engineering" } }
  ]
}
```

---

## 4. Set Per-Agent Model and Persona

Each agent has its own directory under `~/.openclaw/agents/<id>/agent/`.

### Orchestrator — `SOUL.md`

```markdown
# Orchestrator

You are the project manager for a product team.
Your job is to:
- Understand the user's high-level goal
- Break it into concrete sub-tasks
- Delegate each sub-task to the appropriate specialist agent
- Collect results and synthesise a clear summary

You DO NOT do the work yourself. You route and coordinate.
Keep your own context minimal — compact after every delegation round.
```

### UX Agent — `SOUL.md`

```markdown
# UX Designer

You specialise in user experience, interface design, and usability.
You produce wireframe descriptions, user flows, accessibility notes,
and design feedback grounded in established UX principles.
You do not write production code.
```

### Coding Agent — `SOUL.md`

```markdown
# Senior Developer

You write clean, well-tested code. You read only the files you need.
When editing, make surgical changes. Always include or update tests.
After completing work, summarise what changed and why.
Do not explore the codebase speculatively — wait for explicit instructions.
```

### Per-Agent Model Config — `config.json`

```json
{
  "model": {
    "provider": "anthropic",
    "name": "claude-sonnet-4-5"
  }
}
```

For the `qa` and `engineering` agents on simple tasks, use Ollama:

```json
{
  "model": {
    "provider": "ollama",
    "name": "qwen2.5-coder:7b",
    "baseUrl": "http://127.0.0.1:11434"
  }
}
```

---

## 5. Orchestration Patterns

### Pattern A — Hub and Spoke (Recommended for Most Teams)

The orchestrator receives every message and explicitly delegates:

```
User: "Build a landing page for our new feature."

Orchestrator →
  UX Agent:         "Create a wireframe and copy structure for a landing page
                     targeting developers. Include hero, features, and CTA sections."
  Marketing Agent:  "Write conversion-focused copy for the sections the UX agent defined."
  Coding Agent:     "Implement the landing page in React based on the UX wireframe
                     and marketing copy provided."
  QA Agent:         "Write Playwright tests for the landing page that verify the CTA
                     and hero section render correctly."
```

### Pattern B — Sequential Pipeline

One agent hands off directly to the next:

```
UX → Coding → QA → Marketing
```

Configure handoffs in each agent's SOUL.md:

```markdown
After completing your work, output a JSON summary:
{ "status": "complete", "next_agent": "coding", "handoff_notes": "..." }
```

### Pattern C — Parallel Sub-Agents

The orchestrator spawns background sub-agents for concurrent research:

```bash
# Inside an orchestrator session
/spawn engineering "Audit the current CI/CD pipeline and list bottlenecks"
/spawn marketing   "Research competitor landing pages for our category"
```

Results are collected when both sub-agents complete.

---

## 6. Shared Skills and Memory

Place shared prompts and knowledge in `~/.openclaw/skills/`:

```
~/.openclaw/skills/
├── brand-guidelines.md    # loaded by marketing and UX agents
├── coding-standards.md    # loaded by coding and engineering agents
└── product-context.md     # loaded by all agents (who we are, what we build)
```

Agents reference skills in their config:

```json
{
  "skills": ["product-context", "coding-standards"]
}
```

---

## 7. Testing Your Multi-Agent Setup

```bash
# Verify all agents are reachable
openclaw agents list --status

# Send a task that requires the orchestrator to delegate
openclaw chat --agent orchestrator \
  "We need a one-paragraph product description for our homepage. Route this to the right agent."

# Check which agent handled it
openclaw agents log --last 10
```

---

## 8. Expanding the Team

Once the core six-agent team is stable, common additions include:

| Agent | Responsibilities | Suggested Model |
|---|---|---|
| `data` | Analytics queries, dashboard summaries | Local LLM |
| `legal` | Contract review, compliance checks | Claude Sonnet |
| `support` | Customer query triage and draft responses | Claude Haiku |
| `devops` | Infrastructure scripts, monitoring alerts | Local LLM |

---

## Next Steps

- Understand the economics before scaling up → `docs/05-cost-analysis.md`
- Apply token optimizations to every agent → `docs/02-token-optimization.md`
