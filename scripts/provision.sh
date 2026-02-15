#!/bin/bash
#
# provision.sh — Runs ON THE PI to install all dependencies
#
set -euo pipefail

SKIP_OLLAMA="${SKIP_OLLAMA:-0}"
SKIP_DOCKER="${SKIP_DOCKER:-0}"
OLLAMA_MODELS="${OLLAMA_MODELS:-qwen2.5:1.5b gemma2:2b}"

log()  { echo -e "\033[0;32m✓\033[0m $*"; }
info() { echo -e "\033[0;34m→\033[0m $*"; }
warn() { echo -e "\033[1;33m⚠\033[0m $*"; }

header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $*"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ── System Update ──────────────────────────────────────────

header "📦 System Update"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
log "System updated"

# ── Timezone & Locale ──────────────────────────────────────

header "⚙️  System Configuration"
sudo timedatectl set-timezone America/Los_Angeles 2>/dev/null || true
sudo raspi-config nonint do_wifi_country US 2>/dev/null || true
log "Timezone and locale set"

# ── Base Packages ──────────────────────────────────────────

header "📚 Base Packages"
sudo apt-get install -y -qq \
    git jq ripgrep curl wget build-essential \
    vim htop tmux \
    gh ffmpeg \
    chromium \
    zsh
log "Base packages installed"

# ── Zsh ────────────────────────────────────────────────────

header "🐚 Zsh + Oh My Zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
fi
sudo chsh -s "$(which zsh)" "$USER" 2>/dev/null || true
log "Zsh configured"

# ── Docker ─────────────────────────────────────────────────

if [[ "$SKIP_DOCKER" != "1" ]]; then
    header "🐳 Docker"
    if ! command -v docker &>/dev/null; then
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "$USER"
        log "Docker installed (reboot needed for group)"
    else
        log "Docker already installed"
    fi
fi

# ── Node.js via nvm ───────────────────────────────────────

header "📦 Node.js (via nvm)"
export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install --lts
nvm use --lts
nvm alias default node
log "Node $(node --version) installed"

# npm global without sudo
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'

# Ensure PATH in all shells
for rc in ~/.zshrc ~/.bashrc; do
    if ! grep -q 'npm-global' "$rc" 2>/dev/null; then
        echo 'export PATH=~/.npm-global/bin:$PATH' >> "$rc"
    fi
done
export PATH=~/.npm-global/bin:$PATH

# ── NVM in Zsh ─────────────────────────────────────────────

if ! grep -q 'NVM_DIR' ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'NVMRC'

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
NVMRC
fi

# ── OpenClaw ───────────────────────────────────────────────

header "🤖 OpenClaw"
if command -v openclaw &>/dev/null; then
    log "OpenClaw already installed: $(openclaw --version 2>/dev/null || echo 'unknown')"
else
    info "Installing OpenClaw..."
    curl -fsSL https://openclaw.bot/install.sh | bash || {
        warn "Installer failed, trying npm..."
        npm install -g openclaw
    }
    log "OpenClaw installed"
fi

# ── OpenClaw Proxy (OpenAI-compatible API) ─────────────

header "🔌 OpenClaw Proxy"
PROXY_DIR="/opt/openclaw-proxy"
if [[ ! -d "$PROXY_DIR" ]]; then
    sudo mkdir -p "$PROXY_DIR"
    sudo chown "$USER:$USER" "$PROXY_DIR"
    # Clone just the proxy directory
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

# ── Ollama (opt-in only) ───────────────────────────────────
# The Pi calls cloud APIs by default. Ollama is opt-in for
# offline/private use cases. Enable with INSTALL_OLLAMA=1.

if [[ "${INSTALL_OLLAMA:-0}" == "1" ]]; then
    header "🦙 Ollama (Local LLMs — opt-in)"
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

# ── Summary ────────────────────────────────────────────────

header "✅ Provisioning Complete!"
echo ""
echo "Installed:"
echo "  Node.js:   $(node --version)"
echo "  npm:       $(npm --version)"
echo "  Git:       $(git --version | cut -d' ' -f3)"
echo "  Chromium:  $(chromium --version 2>/dev/null || chromium-browser --version 2>/dev/null || echo 'installed')"
[[ "$SKIP_DOCKER" != "1" ]] && echo "  Docker:    $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
[[ "${INSTALL_OLLAMA:-0}" == "1" ]] && echo "  Ollama:    $(ollama --version 2>/dev/null || echo 'installed')"
echo "  OpenClaw:  $(openclaw --version 2>/dev/null || echo 'installed')"
echo "  Proxy:     /opt/openclaw-proxy (port 11435)"
echo "  Shell:     $(zsh --version)"
echo ""
echo "The Pi calls cloud AI APIs (Claude, Gemini, OpenAI)."
echo "It doesn't run models locally — it runs the agent."
echo ""
echo "⚠ Reboot recommended for Docker group + Zsh changes"
