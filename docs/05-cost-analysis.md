# Cost Analysis: Is Running OpenClaw on a Personal Ubuntu VM Worth It?

This guide breaks down the economics of different OpenClaw deployment approaches so
you can make an informed decision for your situation.

---

## Baseline: Current State (No Optimization)

If you are currently using Claude Opus with default settings and getting ~50 000
tokens per question:

| Item | Value |
|---|---|
| Tokens per question | ~50 000 |
| Opus input cost (Apr 2026) | ~$15 per 1M tokens |
| Opus output cost (Apr 2026) | ~$75 per 1M tokens |
| Approx. cost per question | ~$0.75 – $1.50 |
| 50 questions/day | ~$37 – $75/day |
| Monthly (weekdays only) | ~$800 – $1 600/month |

> Exact pricing varies. Check https://anthropic.com/pricing for current rates.

---

## Scenario 1: Optimized Cloud-Only (Anthropic API)

Apply all settings from `docs/02-token-optimization.md` — model routing, reduced
thinking budget, early compaction, MCP limits.

| Item | Value |
|---|---|
| Tokens per question (typical) | ~8 000 – 15 000 |
| Orchestrator model | Claude Opus (sparingly) |
| Sub-agent model | Claude Sonnet / Haiku |
| Approx. cost per question | ~$0.05 – $0.20 |
| 50 questions/day | ~$2.50 – $10/day |
| Monthly | ~$55 – $220/month |
| **Savings vs baseline** | **~85%** |

**Verdict:** Recommended for anyone starting out. No hardware investment required.
The optimization settings alone are transformative.

---

## Scenario 2: Ubuntu VM + Optimized Cloud + Local LLM (Hybrid)

Run OpenClaw on a personal Ubuntu VM and offload simple sub-tasks to a local Ollama
model.

### One-Time Hardware Costs

| Setup | Cost | Suitable For |
|---|---|---|
| Existing PC with 16 GB RAM, no GPU | $0 | Slow but functional local inference |
| Add NVIDIA RTX 3060 12 GB (used) | ~$200–$300 | 7B–14B models at good speed |
| Dedicated mini-PC (Ryzen, 32 GB RAM) | ~$400–$600 | Always-on, quiet home server |
| Used workstation with RTX 3080 | ~$500–$800 | 34B models, fast inference |

### Monthly Running Costs (Hybrid)

| Item | Cloud-Only | Hybrid (VM + Local) |
|---|---|---|
| API calls (cloud models) | $55 – $220 | $20 – $80 (fewer cloud calls) |
| Electricity (VM, 24/7) | $0 | ~$5 – $15/month |
| Hardware amortised (over 2 years) | $0 | ~$15 – $30/month |
| **Total monthly** | **$55 – $220** | **$40 – $125** |

### What Tasks Go Local

| Task | Local Model | Monthly API Call Savings |
|---|---|---|
| File reading and summarisation | llama3.3:8b | ~$15–$30 |
| Boilerplate code generation | qwen2.5-coder:7b | ~$10–$20 |
| Test generation (known patterns) | qwen2.5-coder:7b | ~$5–$15 |
| Routing decisions | llama3.3:8b | ~$5–$10 |
| Simple formatting/linting | qwen2.5-coder:7b | ~$3–$8 |

**Hybrid total API savings:** ~$35–$80/month vs optimized cloud-only.

**Verdict:** Worth it if you are already running a home PC or have a spare machine.
The GPU investment pays back in 2–6 months depending on usage volume.

---

## Scenario 3: Fully Local (No Cloud API)

Run only local models, no Anthropic API at all.

| Aspect | Assessment |
|---|---|
| Cost | Near-zero (electricity only) |
| Privacy | Maximum — no data leaves your machine |
| Quality (coding) | 70–80% of Claude Sonnet for most tasks |
| Quality (orchestration) | Noticeably weaker for complex reasoning |
| Setup complexity | Higher — model management, RAM limits |
| Speed without GPU | Slow (5–15 tokens/second CPU) |
| Speed with GPU | Good (50–100 tokens/second) |

**Best fully-local models as of 2026:**
- `qwen2.5-coder:14b` — best coding quality on 16 GB RAM
- `llama3.3:70b` — best overall quality, needs 48+ GB RAM or GPU offloading
- `mistral:7b` — fastest and lightest, weakest reasoning

**Verdict:** Not recommended as the sole setup for product development work.
Quality drops significantly for orchestration, architecture decisions, and complex
multi-file reasoning. Use as a supplement, not a replacement, for the orchestrator.

---

## Decision Guide

```
Are you doing < 20 questions/day?
  → Cloud-only with optimization. Hardware not worth it yet.

Are you doing 20–100 questions/day?
  → Hybrid: Ubuntu VM + Ollama for simple tasks + Sonnet for complex.
  → ROI breakeven in 3–6 months if you have an 8–16 GB PC already.

Are you doing > 100 questions/day or have a team?
  → Hybrid with GPU. Buy a used RTX 3060–3080.
  → Consider a mini home server (Ryzen + 32 GB RAM) for always-on operation.

Do you have strict data-privacy requirements?
  → Fully local for sensitive tasks, hybrid for everything else.
```

---

## Is the Ubuntu VM Overhead Worth It?

**Yes, for the following reasons:**

1. **Isolation** — OpenClaw agents can execute shell commands. Running in a VM or
   container prevents any mishaps from affecting your main OS.
2. **Always-on** — A VM or dedicated machine can run 24/7 without keeping your main
   workstation busy.
3. **Snapshots** — VMs support snapshots, making it easy to roll back if a
   misconfigured agent causes issues.
4. **Local networking** — Ollama and OpenClaw communicate over localhost, which is
   faster and more private than cloud round-trips.
5. **No licensing costs** — Ubuntu + Docker + Ollama are all free.

**Watch out for:**
- VM overhead: allocate at least 8 GB RAM to the VM or Ollama models will be slow
- Disk space: 7B models are ~4 GB each; plan for 20–50 GB of model storage
- GPU pass-through: requires specific hypervisor setup (VirtualBox does not support
  NVIDIA CUDA pass-through well; use VMware Workstation or KVM/QEMU instead)

---

## Recommended Setup for a Personal Machine (2026)

| Component | Recommendation | Notes |
|---|---|---|
| Hypervisor | KVM/QEMU (via `virt-manager`) | Full GPU pass-through support |
| VM OS | Ubuntu 24.04 LTS | Latest stable, good driver support |
| VM RAM | 12–16 GB | 8 GB for OS, 4–8 GB for models |
| Model runtime | Ollama | Simplest install, auto GPU detection |
| Starting models | qwen2.5-coder:7b, llama3.3:8b | ~8 GB disk combined |
| Cloud orchestrator | Claude Sonnet (not Opus) | Reserve Opus for hard problems only |
| Monthly budget target | $30 – $80 | Achievable with this stack |

---

## Summary Table

| Approach | Monthly Cost | Quality | Privacy | Setup Effort |
|---|---|---|---|---|
| Unoptimized cloud (current) | $800–$1600 | Highest | Low | None |
| Optimized cloud-only | $55–$220 | Very high | Low | Low |
| Hybrid (VM + Local + Cloud) | $40–$125 | High | Medium | Medium |
| Fully local | ~$5–$15 | Good | Highest | High |

**The hybrid approach is the sweet spot for personal product development work.**
It captures ~85% cost reduction over the baseline while maintaining high quality
for complex tasks and eliminating API calls for routine ones.
