#!/bin/bash
#
# provision.sh - Install all dependencies on a Raspberry Pi for OpenClaw.
#
# This script runs ON THE PI (uploaded via SCP by the openclaw-rpi CLI).
# It expects Raspberry Pi OS 64-bit Lite (Bookworm) and an arm64 CPU.
#
# Environment variables:
#   SKIP_DOCKER=1      Skip Docker installation
#   INSTALL_OLLAMA=1   Opt-in: install Ollama for local model inference
#   OLLAMA_MODELS      Space-separated list of models to pull (requires INSTALL_OLLAMA=1)
#
set -euo pipefail

SKIP_DOCKER="${SKIP_DOCKER:-0}"
INSTALL_OLLAMA="${INSTALL_OLLAMA:-0}"
OLLAMA_MODELS="${OLLAMA_MODELS:-qwen2.5:1.5b gemma2:2b}"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

log()  { echo -e "\033[0;32m+\033[0m $*"; }
info() { echo -e "\033[0;34m>\033[0m $*"; }
warn() { echo -e "\033[1;33m!\033[0m $*"; }

header() {
    echo ""
    echo "--------------------------------------------"
    echo "  $*"
    echo "--------------------------------------------"
}

# ---------------------------------------------------------------------------
# System update
# ---------------------------------------------------------------------------

header "System Update"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
log "System updated"

# ---------------------------------------------------------------------------
# Timezone and locale
# ---------------------------------------------------------------------------

header "System Configuration"
sudo timedatectl set-timezone America/Los_Angeles 2>/dev/null || true
sudo raspi-config nonint do_wifi_country US 2>/dev/null || true
log "Timezone and locale configured"

# ---------------------------------------------------------------------------
# Base packages
# ---------------------------------------------------------------------------

header "Base Packages"
sudo apt-get install -y -qq \
    git jq ripgrep curl wget build-essential \
    vim htop tmux \
    gh ffmpeg \
    chromium \
    zsh
log "Base packages installed"

# ---------------------------------------------------------------------------
# Zsh + Oh My Zsh
# ---------------------------------------------------------------------------

header "Zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
fi
sudo chsh -s "$(which zsh)" "$USER" 2>/dev/null || true
log "Zsh configured"

# ---------------------------------------------------------------------------
# Docker (optional)
# ---------------------------------------------------------------------------

if [[ "$SKIP_DOCKER" != "1" ]]; then
    header "Docker"
    if ! command -v docker &>/dev/null; then
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "$USER"
        log "Docker installed (reboot required for group membership)"
    else
        log "Docker already installed"
    fi
fi

# ---------------------------------------------------------------------------
# Node.js via nvm
# ---------------------------------------------------------------------------

header "Node.js"
export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install --lts
nvm use --lts
nvm alias default node
log "Node $(node --version) installed"

# Configure npm global directory to avoid sudo for global installs.
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'

for rc in ~/.zshrc ~/.bashrc; do
    if ! grep -q 'npm-global' "$rc" 2>/dev/null; then
        echo 'export PATH=~/.npm-global/bin:$PATH' >> "$rc"
    fi
done
export PATH=~/.npm-global/bin:$PATH

# Ensure nvm loads in zsh sessions.
if ! grep -q 'NVM_DIR' ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'NVMRC'

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
NVMRC
fi

# ---------------------------------------------------------------------------
# OpenClaw
# ---------------------------------------------------------------------------

header "OpenClaw"
if command -v openclaw &>/dev/null; then
    log "OpenClaw already installed: $(openclaw --version 2>/dev/null || echo 'unknown')"
else
    info "Installing OpenClaw..."
    curl -fsSL https://openclaw.bot/install.sh | bash || {
        warn "Installer script failed, falling back to npm..."
        npm install -g openclaw
    }
    log "OpenClaw installed"
fi

# ---------------------------------------------------------------------------
# OpenClaw Proxy (OpenAI-compatible API)
#
# Clones this repo to grab proxy/server.js and proxy/package.json,
# then copies them to /opt/openclaw-proxy. The proxy exposes the
# OpenClaw agent as a standard /v1/chat/completions endpoint.
# ---------------------------------------------------------------------------

header "OpenClaw Proxy"
PROXY_DIR="/opt/openclaw-proxy"
if [[ ! -d "$PROXY_DIR" ]]; then
    sudo mkdir -p "$PROXY_DIR"
    sudo chown "$USER:$USER" "$PROXY_DIR"

    REPO_TMP=$(mktemp -d)
    git clone --depth 1 https://github.com/hackur/openclaw-on-rpi.git "$REPO_TMP" 2>/dev/null || true
    if [[ -d "$REPO_TMP/proxy" ]]; then
        cp "$REPO_TMP/proxy/server.js" "$PROXY_DIR/"
        cp "$REPO_TMP/proxy/package.json" "$PROXY_DIR/"
    fi
    rm -rf "$REPO_TMP"
    log "Proxy installed at $PROXY_DIR"
else
    log "Proxy already installed"
fi

# ---------------------------------------------------------------------------
# Ollama (opt-in)
#
# The default path uses cloud APIs (Claude, Gemini, OpenAI). Ollama is
# only installed when explicitly requested via INSTALL_OLLAMA=1. Useful
# for offline or privacy-sensitive workloads.
# ---------------------------------------------------------------------------

if [[ "${INSTALL_OLLAMA}" == "1" ]]; then
    header "Ollama (opt-in)"
    if ! command -v ollama &>/dev/null; then
        curl -fsSL https://ollama.com/install.sh | sh
    fi
    log "Ollama installed"

    if ! pgrep -x ollama &>/dev/null; then
        ollama serve &>/dev/null &
        sleep 3
    fi

    for model in $OLLAMA_MODELS; do
        info "Pulling model: $model"
        ollama pull "$model" || warn "Failed to pull $model"
    done
    log "Models ready"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

header "Provisioning Complete"
echo ""
echo "Installed:"
echo "  Node.js:   $(node --version)"
echo "  npm:       $(npm --version)"
echo "  Git:       $(git --version | cut -d' ' -f3)"
echo "  Chromium:  $(chromium --version 2>/dev/null || chromium-browser --version 2>/dev/null || echo 'installed')"
[[ "$SKIP_DOCKER" != "1" ]] && echo "  Docker:    $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
[[ "${INSTALL_OLLAMA}" == "1" ]] && echo "  Ollama:    $(ollama --version 2>/dev/null || echo 'installed')"
echo "  OpenClaw:  $(openclaw --version 2>/dev/null || echo 'installed')"
echo "  Proxy:     /opt/openclaw-proxy (port 11435)"
echo "  Shell:     $(zsh --version)"
echo ""
echo "The Pi calls cloud APIs for inference (Claude, Gemini, OpenAI)."
echo "It doesn't run models locally unless Ollama was explicitly installed."
echo ""
echo "Reboot recommended for Docker group and Zsh changes."
