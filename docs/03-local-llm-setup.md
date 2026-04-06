# Local LLM Setup: Run Models on Your Ubuntu Machine via Ollama

Local LLMs eliminate API costs for simple, repetitive sub-tasks. This guide covers
installing Ollama on Ubuntu and integrating it with OpenClaw so that lightweight
agents run entirely on your personal machine.

---

## When to Use a Local LLM vs Cloud API

| Task | Local LLM | Cloud API |
|---|---|---|
| File reading and summarisation | ✅ Best choice | Expensive overkill |
| Simple code formatting / linting suggestions | ✅ Best choice | Expensive overkill |
| Boilerplate / template generation | ✅ Good | Usable |
| Routing decisions between agents | ✅ Good | Usable |
| Unit test generation for known patterns | ✅ Good | Usable |
| Complex multi-file refactoring | ❌ Too slow/weak | ✅ Use Sonnet |
| Deep architectural decisions | ❌ Not reliable | ✅ Use Opus |
| Creative marketing copy | ⚠️ Acceptable | ✅ Better quality |

**Rule of thumb:** If a human intern could do it in under 5 minutes, a local 7B model
can probably handle it.

---

## Hardware Requirements for Local LLMs

| RAM Available | Suitable Models | Performance |
|---|---|---|
| 8 GB | 7B parameter models (Q4 quantised) | Usable, ~5–15 tok/s CPU |
| 16 GB | 7B–14B models (Q8 quantised) | Good, faster on GPU |
| 32 GB | Up to 34B models | Very good |
| GPU (8 GB VRAM) | Any 7B model on GPU | Fast, ~50–100 tok/s |
| GPU (16–24 GB VRAM) | 13B–34B on GPU | Excellent |

> Without a GPU, Ollama uses CPU inference. It works but is noticeably slower.
> An **NVIDIA GTX 1080 or RTX 3060** (both common and affordable used) make a
> significant difference.

---

## 1. Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Verify Ollama is running:

```bash
ollama --version
systemctl status ollama   # should show "active (running)"
```

---

## 2. Choose and Pull a Model

### Best Models for OpenClaw Sub-Agents (2026)

| Model | RAM Required | Coding Score | Speed | Best For |
|---|---|---|---|---|
| `qwen2.5-coder:7b` | 8 GB | ⭐⭐⭐⭐⭐ | Fast | Code generation, edits |
| `qwen2.5:14b` | 16 GB | ⭐⭐⭐⭐⭐ | Good | Code + general tasks |
| `llama3.3:8b` | 8 GB | ⭐⭐⭐⭐ | Fast | General tasks, routing |
| `mistral:7b` | 8 GB | ⭐⭐⭐ | Fastest | Quick repetitive tasks |
| `phi4` | 6 GB | ⭐⭐⭐⭐ | Very fast | Logic, small reasoning |

**Recommended starting point** — pull `qwen2.5-coder:7b` for coding agents and
`llama3.3:8b` as a general-purpose assistant:

```bash
ollama pull qwen2.5-coder:7b
ollama pull llama3.3:8b
```

Test locally:

```bash
ollama run qwen2.5-coder:7b "Write a Python function that checks if a number is prime."
```

---

## 3. Connect Ollama to OpenClaw

### Option A — Use Ollama for a Specific Agent

Edit the agent's configuration in `~/.openclaw/agents/<agentId>/agent/config.json`:

```json
{
  "model": {
    "provider": "ollama",
    "name": "qwen2.5-coder:7b",
    "baseUrl": "http://127.0.0.1:11434"
  }
}
```

### Option B — Set Ollama as the Global Subagent Model

Add to `~/.openclaw/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_SUBAGENT_MODEL": "ollama:qwen2.5-coder:7b",
    "OLLAMA_BASE_URL": "http://127.0.0.1:11434"
  }
}
```

### Option C — Interactive Onboarding

Re-run the provider setup wizard and select Ollama:

```bash
openclaw config set provider.type "ollama"
openclaw config set provider.model "qwen2.5-coder:7b"
openclaw config set provider.baseUrl "http://127.0.0.1:11434"
```

---

## 4. Verify the Connection

```bash
openclaw doctor   # should show "Ollama: connected" alongside any cloud providers

# Or send a direct test
openclaw chat --provider ollama "Say hello"
```

---

## 5. Hybrid Setup (Recommended)

The most cost-effective approach is a **hybrid model routing strategy**:

```
Orchestrator (Claude Opus or Sonnet)
    ↓ simple sub-tasks
Local Ollama models (qwen2.5-coder:7b, llama3.3:8b)
    ↓ complex sub-tasks
Cloud model (Claude Sonnet)
```

Configuration in `~/.openclaw/openclaw.json` (see `configs/openclaw.json` for the
full multi-agent template):

```json
{
  "modelRouting": {
    "rules": [
      { "taskType": "file_read",        "provider": "ollama", "model": "llama3.3:8b" },
      { "taskType": "code_edit_simple", "provider": "ollama", "model": "qwen2.5-coder:7b" },
      { "taskType": "code_edit_complex","provider": "anthropic", "model": "claude-sonnet-4-5" },
      { "taskType": "orchestration",    "provider": "anthropic", "model": "claude-opus-4-5" }
    ]
  }
}
```

---

## 6. Keeping Models Updated

```bash
# Update a specific model
ollama pull qwen2.5-coder:7b

# List installed models and their sizes
ollama list

# Remove a model you no longer use
ollama rm mistral:7b
```

---

## 7. Running Ollama as a System Service

Ollama installs a systemd service by default. To ensure it auto-starts and restarts
on failure:

```bash
sudo systemctl enable ollama
sudo systemctl restart ollama
sudo journalctl -u ollama -f   # watch logs
```

---

## 8. Optional: Open WebUI (Browser Interface for Local Models)

If you want a ChatGPT-like interface to test models directly:

```bash
docker run -d \
  --name open-webui \
  -p 8080:8080 \
  -v open-webui:/app/backend/data \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  ghcr.io/open-webui/open-webui:main
```

Open `http://localhost:8080` in your browser.

---

## Next Steps

- Configure your full multi-agent team with role-based model routing →
  `docs/04-multi-agent-setup.md`
- See whether the economics work for your use case → `docs/05-cost-analysis.md`
