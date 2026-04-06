#!/bin/bash
# =================================================================
# OpenClaw Hybrid Setup Script for Ubuntu VM
# This script installs OpenClaw + Ollama with hybrid model routing
# =================================================================

set -e

echo "========================================="
echo "  OpenClaw Hybrid Setup for Ubuntu VM"
echo "========================================="
echo ""

# ---- Step 1: System Update ----
echo "[1/8] Updating system packages..."
sudo apt update && sudo apt upgrade -y

# ---- Step 2: Install Dependencies ----
echo "[2/8] Installing dependencies..."
sudo apt install -y curl wget git build-essential python3 python3-pip

# ---- Step 3: Install Node.js 24 ----
echo "[3/8] Installing Node.js 24..."
if ! command -v node &> /dev/null || [[ $(node -v | cut -d. -f1 | tr -d 'v') -lt 22 ]]; then
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo apt install -y nodejs
fi
echo "  Node.js version: $(node --version)"
echo "  npm version: $(npm --version)"

# ---- Step 4: Install OpenClaw ----
echo "[4/8] Installing OpenClaw..."
npm install -g openclaw@latest
echo "  OpenClaw version: $(openclaw --version)"

# ---- Step 5: Install Ollama ----
echo "[5/8] Installing Ollama..."
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
fi

# Start Ollama service
echo "  Starting Ollama service..."
ollama serve &
sleep 3

# ---- Step 6: Pull Local Models ----
echo "[6/8] Pulling local LLM models..."

# Detect available RAM
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
echo "  Detected RAM: ${TOTAL_RAM_GB}GB"

if [ "$TOTAL_RAM_GB" -ge 32 ]; then
    echo "  High-RAM system detected. Pulling larger models..."
    ollama pull qwen3.5:27b
    ollama pull llama3.3:8b
    ollama pull mistral:7b
    echo "  (Optional: run 'ollama pull deepseek-r1:32b' for advanced reasoning)"
elif [ "$TOTAL_RAM_GB" -ge 16 ]; then
    echo "  Standard system detected. Pulling mid-size models..."
    ollama pull qwen3.5:9b
    ollama pull llama3.3:8b
    ollama pull mistral:7b
else
    echo "  Low-RAM system detected. Pulling lightweight models..."
    ollama pull mistral:7b
    ollama pull llama3.3:8b
fi

echo "  Installed models:"
ollama list

# ---- Step 7: Set Environment Variables ----
echo "[7/8] Configuring environment variables..."

# Check if already configured
if ! grep -q "OLLAMA_API_KEY" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# OpenClaw + Ollama Configuration
export OLLAMA_API_KEY="ollama-local"
export OLLAMA_MAX_LOADED_MODELS=2
export OLLAMA_NUM_PARALLEL=2
EOF
    echo "  Environment variables added to ~/.bashrc"
fi

# Prompt for Anthropic API key
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo ""
    echo "  IMPORTANT: You need an Anthropic API key for cloud fallback."
    echo "  Get one at: https://console.anthropic.com/"
    echo ""
    read -p "  Enter your Anthropic API key (or press Enter to skip): " API_KEY
    if [ -n "$API_KEY" ]; then
        echo "export ANTHROPIC_API_KEY=\"$API_KEY\"" >> ~/.bashrc
        export ANTHROPIC_API_KEY="$API_KEY"
        echo "  API key saved to ~/.bashrc"
    else
        echo "  Skipped. Add it later: export ANTHROPIC_API_KEY=\"your-key\""
    fi
fi

source ~/.bashrc 2>/dev/null || true

# ---- Step 8: Copy Config Template ----
echo "[8/8] Setting up OpenClaw configuration..."

# Run onboarding if not already done
if [ ! -d "$HOME/.openclaw" ]; then
    echo "  Running OpenClaw onboarding..."
    openclaw onboard --install-daemon
fi

# Copy hybrid config template
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/openclaw-hybrid.json" ]; then
    echo "  Hybrid config template available at: $SCRIPT_DIR/openclaw-hybrid.json"
    echo "  To apply: cp $SCRIPT_DIR/openclaw-hybrid.json ~/.openclaw/openclaw.json"
fi

echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Review and apply config:  cp configs/openclaw-hybrid.json ~/.openclaw/openclaw.json"
echo "  2. Create agents:            openclaw agents add orchestrator"
echo "  3. Test local model:          openclaw chat 'Hello from hybrid setup!'"
echo "  4. Install token optimizer:  openclaw skills install anthropic-token-optimizer"
echo ""
echo "Estimated monthly savings: 70-85% vs all-Opus setup"
echo ""
