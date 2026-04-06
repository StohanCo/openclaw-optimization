# Token Optimization: From ~50 000 to ~10 000 Tokens per Session

A default Claude Opus install with no tuning regularly consumes 40 000–60 000 tokens
per question. This guide explains exactly why that happens and what to change.

---

## Why Token Counts Are So High

| Source | Typical Token Count | Notes |
|---|---|---|
| Internal "thinking" budget | 20 000–32 000 | Hidden reasoning, not visible in output |
| MCP / tool definitions | 5 000–15 000 | Loaded on every request |
| Session context (history) | 5 000–20 000 | Grows with conversation length |
| Your prompt + file content | 1 000–10 000 | Your actual question |
| Model response | 500–3 000 | The answer you see |

The biggest single lever is the **hidden thinking budget** — it can alone account for
more than half your token bill.

---

## Optimization 1 — Model Selection (saves 60%+)

Use **Claude Opus only for orchestration-level decisions**. Push routine tasks to
cheaper, faster models.

Edit `~/.openclaw/settings.json`:

```json
{
  "model": "claude-sonnet-4-5",
  "env": {
    "CLAUDE_CODE_SUBAGENT_MODEL": "claude-haiku-4-5"
  }
}
```

| Task type | Recommended model | Cost vs Opus |
|---|---|---|
| Top-level orchestration | Claude Opus (only when needed) | baseline |
| Feature planning, code review | Claude Sonnet | ~80% cheaper |
| File reading, search, simple edits | Claude Haiku | ~95% cheaper |
| Simple repetitive tasks | Local LLM (Ollama) | Free |

> **Rule of thumb:** If the task does not require deep multi-step reasoning across
> many files, it does not need Opus.

---

## Optimization 2 — Reduce Thinking Token Budget (saves ~70% of thinking cost)

By default Claude reserves up to 32 000 tokens for internal reasoning per request.
For most coding and product tasks 8 000–10 000 is more than enough.

```json
{
  "env": {
    "MAX_THINKING_TOKENS": "10000"
  }
}
```

Only raise this value when you are tackling genuinely large architectural problems
(e.g. refactoring an entire codebase, complex algorithmic design).

---

## Optimization 3 — Earlier Context Compaction (saves 10–20%)

OpenClaw auto-compacts the context window when it reaches 95% full.
By then, thousands of now-irrelevant tokens have already been sent to the model.
Set the threshold to 50% to compact earlier and keep the active context lean.

```json
{
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50"
  }
}
```

**Trigger manual compaction** at natural breakpoints in your work:

```bash
# Inside an OpenClaw session
/compact
```

Good moments to compact:
- After completing a research phase
- After finishing a feature or fixing a bug
- Before switching to a completely different task
- Whenever you hit a dead end and want to restart reasoning

---

## Optimization 4 — Limit MCP Servers and Tool Definitions (saves 30–50%)

Every enabled MCP server injects its tool definitions into the context on every
request. If you have 10 MCP servers active, you may be paying for 10 000–20 000
tokens of tool schema before your prompt even starts.

**Actions:**
1. List active MCP servers: `openclaw mcp list`
2. Disable any not needed for your current work session
3. Consider routing all MCPs through a gateway (e.g. Bifrost) to deduplicate
   tool definitions

```bash
# Disable an MCP server for current session
openclaw mcp disable <server-name>

# Permanently disable in config
openclaw config set mcp.<server-name>.enabled false
```

---

## Optimization 5 — Prompt Hygiene

Small prompt changes have a surprisingly large compounding effect over many sessions.

| Do | Avoid |
|---|---|
| Name exact files to read | "Look at all the code" |
| Specify exact changes to make | "Fix the bugs you find" |
| Break large tasks into steps | Sending 5 000-line files as context |
| Batch related edits in one prompt | Making 10 separate small requests |
| Use `/compact` between phases | Letting context grow unbounded |

**Example — inefficient prompt:**
> "Read through the whole codebase and find any issues, then write tests for everything."

**Example — efficient prompt:**
> "Read `src/auth/login.ts` lines 45–90. The `validateToken` function does not check
> expiry. Fix it and add two Jest tests: one for expired tokens, one for valid ones."

---

## All-in-One Settings File

Apply all optimizations at once by copying `configs/settings.json` from this repo
to `~/.openclaw/settings.json`.

Summary of what that file sets:

```json
{
  "model": "claude-sonnet-4-5",
  "env": {
    "CLAUDE_CODE_SUBAGENT_MODEL": "claude-haiku-4-5",
    "MAX_THINKING_TOKENS": "10000",
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50"
  }
}
```

---

## Expected Results

| Scenario | Before | After optimization | Saving |
|---|---|---|---|
| Routine coding task | 50 000 tokens | 8 000–12 000 tokens | ~80% |
| Feature planning session | 50 000 tokens | 12 000–18 000 tokens | ~65% |
| Deep architectural review | 50 000 tokens | 25 000–35 000 tokens | ~35% |

---

## Monitoring Token Usage

```bash
# Check cost of current session
/cost

# View per-agent usage breakdown
openclaw usage --breakdown

# Set a spending limit (prevents runaway costs)
openclaw config set limits.monthly_usd 50
```

---

## Next Steps

- Add free local LLM inference for the cheapest sub-tasks → `docs/03-local-llm-setup.md`
- Configure your multi-agent team to use the right model per role →
  `docs/04-multi-agent-setup.md`
