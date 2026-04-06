# Step-by-Step: Installing OpenClaw on Ubuntu (VM or Physical Machine)

This guide covers a complete, verified installation of OpenClaw on Ubuntu 22.04 / 24.04,
running either inside a virtual machine (VirtualBox, VMware, Hyper-V) or directly on a
personal computer.

---

## 1. Hardware Requirements

| Component | Minimum | Recommended |
|---|---|---|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8–16 GB |
| Disk | 20 GB free | 50+ GB SSD |
| GPU | Not required | NVIDIA with 8+ GB VRAM (for local LLMs) |
| OS | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |

> **VM Tip:** If using VirtualBox or VMware, allocate at least 8 GB RAM and enable
> hardware virtualisation (VT-x/AMD-V) in your BIOS/UEFI.

---

## 2. Prepare Ubuntu

Open a terminal and bring the system fully up to date:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git build-essential
```

Create a dedicated non-root user if you are running as root (strongly recommended):

```bash
sudo adduser openclaw_user
sudo usermod -aG sudo openclaw_user
su - openclaw_user
```

---

## 3. Install Node.js (Required)

OpenClaw requires **Node.js v22 or v24**. Use NVM for easy version management:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc

nvm install 24
nvm use 24
nvm alias default 24
```

Verify:

```bash
node -v   # should print v24.x.x
npm -v    # should print 11.x.x or higher
```

---

## 4. Install Docker (Recommended for Production Use)

Running OpenClaw in Docker provides isolation and makes upgrades trivial.

```bash
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker          # apply group change without logout
docker --version       # verify
```

---

## 5. Install OpenClaw

### Option A — Official Installer Script (Simplest)

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

The installer detects your Node version, downloads OpenClaw, and runs the onboarding
wizard automatically.

### Option B — Docker Compose (Recommended for Long-Running Setups)

Create a project directory and a `docker-compose.yml`:

```bash
mkdir ~/openclaw && cd ~/openclaw
```

```yaml
# ~/openclaw/docker-compose.yml
version: "3.8"

services:
  openclaw:
    image: openclaw/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - ~/.openclaw:/root/.openclaw
    env_file:
      - .env
```

Create a minimal `.env` file:

```bash
# ~/openclaw/.env
ANTHROPIC_API_KEY=your_api_key_here
```

Start the container:

```bash
docker compose up -d
docker compose logs -f   # watch logs
```

---

## 6. Onboarding Wizard

Run the interactive setup (or it starts automatically after installation):

```bash
openclaw onboard
```

You will be prompted to:
1. **Select AI provider** — choose `Anthropic` for Claude models (or `Ollama` for local)
2. **Enter your API key** — stored locally in `~/.openclaw/`
3. **Name your first agent** — e.g. `orchestrator`
4. **Choose default model** — see token-optimization guidance in
   `docs/02-token-optimization.md` before picking Opus

---

## 7. Verify Installation

```bash
openclaw --version
openclaw doctor          # checks all dependencies and connectivity
openclaw gateway status  # confirms the gateway is listening
```

Send a quick test prompt:

```bash
openclaw chat "Hello, are you working?"
```

You should receive a response from your configured LLM.

---

## 8. Directory Layout After Install

```
~/.openclaw/
├── openclaw.json          # main configuration (agents, bindings, models)
├── settings.json          # runtime tuning (token limits, compaction, etc.)
├── agents/
│   └── <agentId>/
│       ├── agent/         # agent-specific config and SOUL.md persona
│       ├── memory/        # persistent memory store
│       └── sessions/      # session history
├── skills/                # shared skills / plugins
└── workspace-*/           # per-agent working directories
```

---

## 9. Keeping OpenClaw Updated

```bash
# Script installer update
curl -fsSL https://openclaw.ai/install.sh | bash

# Docker update
cd ~/openclaw
docker compose pull
docker compose up -d
```

---

## 10. Security Checklist

- [ ] Never run OpenClaw as `root`
- [ ] Store API keys in `.env` only — never hard-code them in config files
- [ ] Restrict Docker port `3000` to `127.0.0.1` if you are not exposing a public endpoint
- [ ] Review which tools (shell exec, file read/write) each agent is allowed to use
- [ ] Use a dedicated VM or container for any agent that executes untrusted code

---

## Next Steps

- **Reduce token costs** → `docs/02-token-optimization.md`
- **Add a local LLM** → `docs/03-local-llm-setup.md`
- **Build your agent team** → `docs/04-multi-agent-setup.md`
