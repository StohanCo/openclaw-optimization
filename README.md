# OpenClaw Optimization — Complete Implementation Guide

> **Goal**: Optimize OpenClaw.ai token usage, deploy on a local Ubuntu VM with hybrid local/cloud LLM routing, and configure a multi-agent product team (UX, Marketing, Coding, Engineering, and more) for maximum efficiency and minimum cost.

## Table of Contents

- [1. Current Problem Analysis](#1-current-problem-analysis)
- [2. Cost Breakdown & Why Optimization Matters](#2-cost-breakdown--why-optimization-matters)
- [3. Recommended Architecture](#3-recommended-architecture)
- [4. Full Installation Walkthrough](#4-full-installation-walkthrough)
- [5. Local LLM Setup with Ollama](#5-local-llm-setup-with-ollama)
- [6. Hybrid Model Routing](#6-hybrid-model-routing)
- [7. Multi-Agent Product Team Setup](#7-multi-agent-product-team-setup)
- [8. Token Optimization Techniques](#8-token-optimization-techniques)
- [9. Is It Worth It? — Cost-Benefit Analysis](#9-is-it-worth-it--cost-benefit-analysis)
- [10. Reference Links](#10-reference-links)

---

## 1. Current Problem Analysis

### The Issue
You are using **Anthropic Claude Opus** as the main orchestrator in OpenClaw, consuming **~50,000 tokens per question**. This is extremely expensive because:

- Opus is the most expensive Anthropic model ($5/1M input tokens, $25/1M output tokens)
- Every agent interaction sends full context (SOUL.md, MEMORY.md, AGENTS.md, conversation history, tool results)
- Multi-agent setups multiply this — each subagent call triggers its own full-context LLM request
- No compaction, pruning, or caching is configured by default

### Where Tokens Go (Breakdown of a Typical 50K Token Request)

| Component | Estimated Tokens | Purpose |
|-----------|-----------------|---------|
| System prompt + SOUL.md | 500–2,000 | Agent persona and instructions |
| AGENTS.md | 200–500 | Multi-agent routing rules |
| MEMORY.md | 200–800 | Persistent memory |
| Conversation history | 5,000–20,000 | Full chat context |
| Tool calls & results | 5,000–15,000 | Shell output, file contents, web results |
| Workspace file injections | 2,000–10,000 | Project files loaded into context |
| LLM response (output) | 1,000–5,000 | The actual answer |
| **Total** | **~14,000–53,000** | **Per interaction** |

---

## 2. Cost Breakdown & Why Optimization Matters

### Anthropic Claude API Pricing (April 2026)

| Model | Input (per 1M tokens) | Output (per 1M tokens) | Best For |
|-------|----------------------|------------------------|----------|
| **Claude Opus 4.6** | $5.00 | $25.00 | Complex reasoning, orchestration |
| **Claude Sonnet 4.6** | $3.00 | $15.00 | Good balance of quality/cost |
| **Claude Haiku 4.5** | $0.80 | $4.00 | Fast, cheap, simple tasks |

### What 50K Tokens Per Question Costs You

Assuming a typical split of ~40K input + ~10K output per question with Opus:

| Metric | Cost |
|--------|------|
| **Per question** | $0.20 input + $0.25 output = **~$0.45** |
| **100 questions/day** | **~$45/day** |
| **Monthly (3,000 questions)** | **~$1,350/month** |

With multiple subagents (UX, Marketing, Coding, Engineering), each triggering their own Opus calls, costs can **2x–5x** easily → **$2,700–$6,750/month**.

### After Optimization (Hybrid Local + Cloud)

| Metric | Cost |
|--------|------|
| **Simple tasks (80%) via local Ollama** | **$0** |
| **Complex tasks (20%) via Sonnet/Opus** | **~$270/month** |
| **Estimated monthly total** | **~$270–$500/month** |
| **Savings** | **~70–85%** |

---

## 3. Recommended Architecture

```
┌─────────────────────────────────────────────────────────┐
│                 Ubuntu VM (Your PC)                       │
│                                                           │
│  ┌──────────┐    ┌───────────────────────────────────┐   │
│  │  Ollama   │    │         OpenClaw Gateway          │   │
│  │  Server   │◄──►│                                   │   │
│  │           │    │  ┌─────────┐  ┌────────────────┐  │   │
│  │ Models:   │    │  │  Main   │  │   Subagents    │  │   │
│  │ • Qwen    │    │  │ Orches- │  │ • UX Agent     │  │   │
│  │   3.5 27B │    │  │ trator  │  │ • Marketing    │  │   │
│  │ • Llama   │    │  │ (Opus)  │  │ • Coding       │  │   │
│  │   3.3 8B  │    │  │         │  │ • Engineering  │  │   │
│  │ • Mistral │    │  └────┬────┘  └───────┬────────┘  │   │
│  │   7B      │    │       │               │            │   │
│  └──────────┘    │       ▼               ▼            │   │
│                   │  ┌─────────────────────────────┐   │   │
│                   │  │    Model Router              │   │   │
│                   │  │  Primary: ollama/qwen3.5:27b │   │   │
│                   │  │  Fallback: anthropic/sonnet   │   │   │
│                   │  │  Override: anthropic/opus      │   │   │
│                   │  └─────────────────────────────┘   │   │
│                   └───────────────────────────────────┘   │
│                                                           │
│  ┌──────────────────────┐  ┌──────────────────────────┐  │
│  │ Telegram / Discord   │  │  Web Dashboard           │  │
│  │ WhatsApp / Slack     │  │  http://127.0.0.1:18789  │  │
│  └──────────────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼ (only complex tasks)
              ┌──────────────────┐
              │  Anthropic API   │
              │  (Cloud - Opus/  │
              │   Sonnet/Haiku)  │
              └──────────────────┘
```

---

## 4. Full Installation Walkthrough

### Prerequisites

- **Ubuntu 22.04+ or 24.04 LTS** (VM or bare metal)
- **Hardware minimum**: 16GB RAM, 4+ CPU cores, 50GB disk
- **Recommended**: 32GB RAM, GPU with 16–24GB VRAM (e.g., RTX 3090/4090), SSD
- **Node.js 22.14+** (24+ recommended)
- **Python 3.11+**

### Step 1: Prepare Ubuntu VM

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git build-essential python3 python3-pip

# Install Node.js 24 (via NodeSource)
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installations
node --version   # Should be v24.x+
npm --version
python3 --version  # Should be 3.11+
```

### Step 2: Install OpenClaw

```bash
# Install OpenClaw globally
npm install -g openclaw@latest

# Verify installation
openclaw --version

# Run the onboarding wizard (interactive setup)
openclaw onboard --install-daemon
```

The onboarding wizard will:
1. Create `~/.openclaw/` directory structure
2. Set up your initial agent
3. Configure your first LLM provider
4. Create SOUL.md and workspace files
5. Optionally connect chat platforms (Telegram, Discord, etc.)

### Step 3: Directory Structure After Install

```
~/.openclaw/
├── openclaw.json              # Main configuration file
├── workspace-default/          # Default agent workspace
│   ├── SOUL.md                # Agent persona
│   ├── AGENTS.md              # Multi-agent routing
│   └── MEMORY.md              # Persistent memory
├── agents/
│   └── default/
│       └── agent/             # Agent state, auth, sessions
└── logs/                      # Gateway logs
```

---

## 5. Local LLM Setup with Ollama

### Why Use Local Models?

| Benefit | Detail |
|---------|--------|
| **Zero token cost** | No per-token API fees after hardware setup |
| **Full privacy** | Data never leaves your machine |
| **No rate limits** | Run as many queries as hardware allows |
| **Offline capable** | Works without internet |
| **Low latency** | No network round-trip for simple tasks |

### Install Ollama

```bash
# One-line install
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama service
ollama serve &

# Verify it's running
curl http://localhost:11434/api/tags
```

### Which Local Models to Install?

Choose based on your hardware:

#### For 16GB RAM (no dedicated GPU)

```bash
# Best all-around for simple tasks (3.8 GB)
ollama pull llama3.3:8b

# Fast and lightweight (4.1 GB)
ollama pull mistral:7b

# Good for coding tasks (3.8 GB)
ollama pull qwen3.5:9b
```

#### For 32GB RAM or 16GB+ VRAM GPU

```bash
# Excellent quality — best local model for most tasks (16 GB)
ollama pull qwen3.5:27b

# Strong reasoning and coding (19 GB)
ollama pull deepseek-r1:32b

# Great general purpose (14 GB)
ollama pull llama3.3:14b
```

#### For 48GB+ VRAM (High-End GPU Server)

```bash
# Near cloud-quality for coding (41 GB)
ollama pull qwen-coder-plus:72b

# Top-tier general purpose (40 GB)
ollama pull llama3.3:70b
```

### Recommended Model Selection for OpenClaw Agents

| Agent Role | Recommended Local Model | Why |
|-----------|------------------------|-----|
| **Coding Agent** | `qwen3.5:27b` or `qwen3.5:9b` | Best coding benchmarks locally |
| **UX/Marketing Agent** | `llama3.3:8b` or `mistral:7b` | Good at natural language, fast |
| **Engineering Agent** | `deepseek-r1:32b` | Strongest reasoning locally |
| **General/Simple Tasks** | `mistral:7b` | Fastest, lowest resource |
| **Orchestrator (simple routing)** | `qwen3.5:27b` | Best overall quality locally |
| **Orchestrator (complex decisions)** | `anthropic/claude-opus` (cloud) | When local isn't enough |

### Verify Models Work

```bash
# Test a model
ollama run qwen3.5:27b "Write a brief product description for a SaaS dashboard"

# Check loaded models
ollama ps

# List installed models
ollama list
```

### Performance Tuning for Ollama

```bash
# Limit to 1 loaded model to save RAM
export OLLAMA_MAX_LOADED_MODELS=1

# Allow 2 parallel requests
export OLLAMA_NUM_PARALLEL=2

# Pre-load model for faster first response
ollama run qwen3.5:27b ""
```

---

## 6. Hybrid Model Routing

This is the **key optimization** — route simple tasks locally, complex tasks to cloud.

### Configure OpenClaw for Hybrid Routing

Edit `~/.openclaw/openclaw.json`:

```json
{
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://127.0.0.1:11434/v1",
        "apiKey": "ollama-local",
        "api": "openai-responses",
        "models": [
          {
            "id": "qwen3.5:27b",
            "name": "Qwen 3.5 27B (Local)",
            "contextWindow": 32768,
            "maxOutput": 8192
          },
          {
            "id": "llama3.3:8b",
            "name": "Llama 3.3 8B (Local)",
            "contextWindow": 32768,
            "maxOutput": 4096
          },
          {
            "id": "mistral:7b",
            "name": "Mistral 7B (Local)",
            "contextWindow": 32768,
            "maxOutput": 4096
          }
        ]
      },
      "anthropic": {
        "apiKey": "${ANTHROPIC_API_KEY}",
        "models": [
          {
            "id": "claude-opus-4-6",
            "name": "Claude Opus 4.6",
            "contextWindow": 200000,
            "maxOutput": 32768
          },
          {
            "id": "claude-sonnet-4-6",
            "name": "Claude Sonnet 4.6",
            "contextWindow": 200000,
            "maxOutput": 32768
          },
          {
            "id": "claude-haiku-4-5",
            "name": "Claude Haiku 4.5",
            "contextWindow": 200000,
            "maxOutput": 16384
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/qwen3.5:27b",
        "fallbacks": [
          "anthropic/claude-sonnet-4-6",
          "anthropic/claude-opus-4-6"
        ]
      },
      "compaction": {
        "mode": "safeguard",
        "model": "ollama/llama3.3:8b"
      },
      "contextPruning": {
        "mode": "cache-ttl",
        "ttl": "1h"
      }
    }
  }
}
```

### Set Environment Variables

```bash
# Add to ~/.bashrc or ~/.profile
export ANTHROPIC_API_KEY="sk-ant-your-key-here"
export OLLAMA_API_KEY="ollama-local"
export OLLAMA_MAX_LOADED_MODELS=2
export OLLAMA_NUM_PARALLEL=2
```

### Routing Strategy

| Task Type | Route To | Cost |
|-----------|----------|------|
| Simple Q&A, summaries | `ollama/qwen3.5:27b` | **$0** |
| Code generation (routine) | `ollama/qwen3.5:27b` | **$0** |
| Marketing copy drafts | `ollama/llama3.3:8b` | **$0** |
| UX research summaries | `ollama/mistral:7b` | **$0** |
| Complex architecture decisions | `anthropic/claude-opus-4-6` | ~$0.45/query |
| Multi-step reasoning | `anthropic/claude-sonnet-4-6` | ~$0.20/query |
| Context compaction | `ollama/llama3.3:8b` | **$0** |

---

## 7. Multi-Agent Product Team Setup

### Create Specialized Agents

```bash
# Create agents for each role
openclaw agents add orchestrator
openclaw agents add ux-designer
openclaw agents add marketer
openclaw agents add coder
openclaw agents add engineer
openclaw agents add qa-tester
```

### Agent-Specific Configuration

#### Orchestrator Agent (the "brain")

**`~/.openclaw/workspace-orchestrator/SOUL.md`:**
```markdown
# Orchestrator

You are the lead coordinator for a product development team.
Your job is to:
- Break down product requirements into tasks
- Delegate to specialist agents (UX, Marketing, Coding, Engineering, QA)
- Review and synthesize results from subagents
- Make architectural decisions

Keep responses concise. Delegate rather than do.
```

**Model override in `openclaw.json`:**
```json
{
  "agents": {
    "orchestrator": {
      "model": {
        "primary": "anthropic/claude-sonnet-4-6",
        "fallbacks": ["anthropic/claude-opus-4-6"]
      }
    }
  }
}
```

> **Note:** The orchestrator is the one agent worth keeping on a cloud model because it makes high-level decisions. Use Sonnet (not Opus) as the default — it's 40% cheaper with comparable coordination ability.

#### UX Designer Agent

**`~/.openclaw/workspace-ux-designer/SOUL.md`:**
```markdown
# UX Designer Agent

You are a senior UX/UI designer specializing in:
- User research analysis
- Wireframe descriptions and specifications
- Usability heuristic evaluation
- Design system documentation
- Accessibility (WCAG) compliance

Output structured deliverables. Use bullet lists for specifications.
```

**Model:** `ollama/llama3.3:8b` (natural language tasks, fast)

#### Marketing Agent

**`~/.openclaw/workspace-marketer/SOUL.md`:**
```markdown
# Marketing Agent

You are a growth marketing specialist. Your expertise:
- Copywriting (landing pages, ads, emails, social media)
- SEO keyword research and content strategy
- Campaign planning and A/B testing frameworks
- Market research and competitive analysis
- Brand voice and messaging guidelines

Keep copy punchy and actionable.
```

**Model:** `ollama/llama3.3:8b` (good at creative writing, fast)

#### Coding Agent

**`~/.openclaw/workspace-coder/SOUL.md`:**
```markdown
# Coding Agent

You are a senior full-stack developer. Your expertise:
- Write clean, production-ready code
- Debug and optimize existing code
- Create tests (unit, integration, e2e)
- Set up CI/CD pipelines
- Review PRs and suggest improvements

Always include error handling. Follow project conventions.
```

**Model:** `ollama/qwen3.5:27b` (best local coding model) with fallback to `anthropic/claude-sonnet-4-6`

#### Engineering Agent

**`~/.openclaw/workspace-engineer/SOUL.md`:**
```markdown
# Engineering Agent

You are a systems architect and DevOps engineer. Your expertise:
- Infrastructure design (cloud, on-prem, hybrid)
- Database schema design and optimization
- API design (REST, GraphQL, gRPC)
- Performance profiling and optimization
- Security architecture and threat modeling

Think in systems. Document trade-offs.
```

**Model:** `ollama/deepseek-r1:32b` (strongest reasoning) or `ollama/qwen3.5:27b`

#### QA Agent

**`~/.openclaw/workspace-qa-tester/SOUL.md`:**
```markdown
# QA Agent

You are a quality assurance specialist. Your expertise:
- Test plan creation
- Bug report writing
- Edge case identification
- Regression testing strategies
- Performance testing guidelines

Be thorough and systematic. Think about what could break.
```

**Model:** `ollama/mistral:7b` (fast, sufficient for structured analysis)

### Per-Agent Model Overrides in `openclaw.json`

```json
{
  "agents": {
    "orchestrator": {
      "model": {
        "primary": "anthropic/claude-sonnet-4-6",
        "fallbacks": ["anthropic/claude-opus-4-6"]
      }
    },
    "ux-designer": {
      "model": {
        "primary": "ollama/llama3.3:8b",
        "fallbacks": ["anthropic/claude-haiku-4-5"]
      }
    },
    "marketer": {
      "model": {
        "primary": "ollama/llama3.3:8b",
        "fallbacks": ["anthropic/claude-haiku-4-5"]
      }
    },
    "coder": {
      "model": {
        "primary": "ollama/qwen3.5:27b",
        "fallbacks": ["anthropic/claude-sonnet-4-6"]
      }
    },
    "engineer": {
      "model": {
        "primary": "ollama/qwen3.5:27b",
        "fallbacks": ["anthropic/claude-sonnet-4-6"]
      }
    },
    "qa-tester": {
      "model": {
        "primary": "ollama/mistral:7b",
        "fallbacks": ["anthropic/claude-haiku-4-5"]
      }
    }
  }
}
```

### Orchestration Workflow Example

```
User → "Build a landing page for our new SaaS product"
  │
  ▼
Orchestrator (Sonnet - cloud, $0.20)
  │ Breaks down into tasks:
  ├─→ UX Agent: "Create wireframe specs" (local Llama 8B, $0)
  ├─→ Marketing Agent: "Write hero copy and CTAs" (local Llama 8B, $0)
  ├─→ Coder: "Build React component from specs" (local Qwen 27B, $0)
  ├─→ Engineer: "Set up hosting and CI/CD" (local Qwen 27B, $0)
  └─→ QA: "Create test plan for the page" (local Mistral 7B, $0)
  │
  ▼
Orchestrator synthesizes results ($0.20)
  │
  ▼
User gets complete deliverable

Total cost: ~$0.40 (vs ~$2.25+ with all-Opus)
```

---

## 8. Token Optimization Techniques

### 8.1 Context Compaction

Use a cheap model to summarize conversation history before it's sent to the main model.

```json
"compaction": {
  "mode": "safeguard",
  "model": "ollama/llama3.3:8b"
}
```

**Impact:** Reduces context from ~20K tokens to ~3K tokens. **Free** when using local model.

### 8.2 Context Pruning

Automatically trim old context after a time-to-live period.

```json
"contextPruning": {
  "mode": "cache-ttl",
  "ttl": "1h"
}
```

**Impact:** Prevents unbounded context growth. Saves ~30–50% of input tokens.

### 8.3 Prompt Caching (for Cloud Models)

When using Anthropic API, enable long cache retention to avoid re-processing the same system prompts.

```json
"params": {
  "cacheRetention": "long"
}
```

**Impact:** Up to 90% reduction on repeated input tokens for Anthropic.

### 8.4 Cache Heartbeat

Keep prompt cache warm to avoid expensive recomputation.

```json
"heartbeat": {
  "every": "55m"
}
```

### 8.5 Lean Workspace Files

Keep injected files minimal:

| File | Target Size | Tips |
|------|-------------|------|
| SOUL.md | < 250 tokens | Concise persona, bullet points |
| AGENTS.md | < 500 tokens | Only routing rules |
| MEMORY.md | < 400 tokens | Key facts only, prune regularly |

### 8.6 Install Token Optimizer Skill

```bash
# Install the Anthropic token optimizer from ClawHub
openclaw skills install anthropic-token-optimizer
```

This skill automatically:
- Monitors token usage per agent
- Suggests compaction opportunities
- Reports cost per conversation
- Auto-prunes redundant memory entries

### 8.7 Manual Compaction

After finishing a conversation thread, run:
```
/compact
```
This summarizes the entire history and trims excess context.

---

## 9. Is It Worth It? — Cost-Benefit Analysis

### Cost Comparison: All-Cloud vs Hybrid

| Scenario | Monthly Cost | Notes |
|----------|-------------|-------|
| **Current (All Opus, 50K tokens/query)** | **$1,350–$6,750** | 5 agents, 100 queries/day |
| **Optimized Cloud-Only (Sonnet + Haiku + caching)** | **$400–$800** | Smart model routing, no local |
| **Hybrid (Local + Cloud fallback)** | **$200–$500** | 80% local, 20% cloud |
| **Fully Local (Ollama only)** | **~$30–$50** | Electricity only; reduced quality on hard tasks |

### Hardware Investment

| Component | Cost (One-Time) | Useful Life |
|-----------|-----------------|-------------|
| 32GB RAM upgrade | $60–$120 | 5+ years |
| RTX 3090 (24GB VRAM, used) | $600–$800 | 3–5 years |
| RTX 4090 (24GB VRAM, new) | $1,600–$2,000 | 5+ years |
| 1TB NVMe SSD | $60–$100 | 5+ years |
| **Total (budget)** | **$720–$1,020** | — |
| **Total (high-end)** | **$1,720–$2,220** | — |

### Break-Even Analysis

With current spending of ~$1,350/month on Opus:
- **Budget GPU setup** pays for itself in **< 1 month**
- **High-end setup** pays for itself in **~1–2 months**
- After that, ongoing savings of **$850–$1,100/month**

### Quality Trade-Offs

| Task | Local Model Quality | Cloud Model Quality | Verdict |
|------|-------------------|-------------------|---------|
| Simple Q&A | ★★★★☆ | ★★★★★ | Local is fine |
| Code generation (routine) | ★★★★☆ | ★★★★★ | Local is fine |
| Marketing copy | ★★★★☆ | ★★★★★ | Local is fine |
| Complex architecture | ★★★☆☆ | ★★★★★ | Use cloud |
| Multi-step reasoning | ★★☆☆☆ | ★★★★★ | Use cloud |
| Code review (deep) | ★★★☆☆ | ★★★★★ | Use cloud for critical |

### Verdict: **Yes, It's Worth It**

✅ **The hybrid approach is the clear winner:**
- 80% of agent tasks (simple queries, drafts, code generation, summaries) work well with local models
- 20% of tasks (complex reasoning, critical decisions) still use cloud models
- Monthly costs drop from $1,350+ to $200–$500
- Hardware investment pays off within 1–2 months
- Privacy bonus: most data stays local
- No rate limits on local models

❌ **Fully local (no cloud) is NOT recommended** for production work because:
- Complex multi-step reasoning quality drops significantly
- The orchestrator needs strong reasoning for task decomposition
- Some edge cases need cloud-quality models

---

## 10. Reference Links

### Official Documentation
- [OpenClaw Docs](https://docs.openclaw.ai/)
- [OpenClaw Multi-Agent Routing](https://docs.openclaw.ai/concepts/multi-agent)
- [OpenClaw Ollama Provider](https://docs.openclaw.ai/providers/ollama)
- [Anthropic Claude Pricing](https://platform.claude.com/docs/en/about-claude/pricing)

### Setup Guides
- [OpenClaw LLM Setup: Local and Cloud Models](https://blog.laozhang.ai/en/posts/openclaw-llm-setup)
- [OpenClaw + Ollama Setup](https://openclawai.io/guides/ollama-setup/)
- [OpenClaw Multi-Agent Configuration](https://www.heyuan110.com/posts/ai/2026-04-02-openclaw-multi-agent-setup-guide/)
- [Best Ollama Models for OpenClaw](https://haimaker.ai/blog/best-local-models-for-openclaw/)

### Token Optimization
- [Anthropic Token Optimizer Skill](https://llmbase.ai/openclaw/anthropic-token-optimizer/)
- [OpenClaw API Model Configuration](https://ofox.ai/blog/openclaw-api-model-configuration-guide-2026/)
- [Setting up Anthropic Claude with OpenClaw](https://open-claw.bot/docs/providers/anthropic/)

### Local LLM Resources
- [Ollama Official](https://ollama.com)
- [Best Local LLM Models 2026](https://www.aitooldiscovery.com/how-to/best-local-llm-models)
- [Run Local LLMs Guide](https://www.sitepoint.com/run-local-llms-2026-complete-developer-guide/)

---

## Quick Start Checklist

```
□ 1. Set up Ubuntu VM (22.04+ or 24.04 LTS)
□ 2. Install Node.js 24+ and Python 3.11+
□ 3. Install OpenClaw: npm install -g openclaw@latest
□ 4. Run onboarding: openclaw onboard --install-daemon
□ 5. Install Ollama: curl -fsSL https://ollama.com/install.sh | sh
□ 6. Pull local models: ollama pull qwen3.5:27b && ollama pull llama3.3:8b
□ 7. Configure hybrid routing in ~/.openclaw/openclaw.json
□ 8. Set ANTHROPIC_API_KEY environment variable
□ 9. Create specialized agents: openclaw agents add <role>
□ 10. Configure SOUL.md for each agent
□ 11. Set per-agent model overrides
□ 12. Install token optimizer: openclaw skills install anthropic-token-optimizer
□ 13. Enable compaction, pruning, and caching
□ 14. Test: openclaw chat "Hello from hybrid setup!"
□ 15. Monitor costs and adjust routing
```

---

*Last updated: April 2026*
