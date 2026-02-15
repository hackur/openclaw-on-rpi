#!/bin/bash
#
# configure.sh - Interactive OpenClaw configuration wizard.
#
# This script runs ON THE PI (uploaded via SCP by the openclaw-rpi CLI).
# It walks through AI provider setup, browser verification, systemd
# service creation, and API proxy enablement.
#
set -euo pipefail

# Load nvm so node/npm/openclaw are on PATH.
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
export PATH=~/.npm-global/bin:$PATH

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

log()  { echo -e "\033[0;32m+\033[0m $*"; }
info() { echo -e "\033[0;34m>\033[0m $*"; }
warn() { echo -e "\033[1;33m!\033[0m $*"; }

echo ""
echo "--------------------------------------------"
echo "  OpenClaw Configuration"
echo "--------------------------------------------"
echo ""

# ---------------------------------------------------------------------------
# AI Provider
#
# The Pi calls cloud APIs for inference. This step saves the chosen
# provider's API key to ~/.zshrc so it persists across sessions.
# ---------------------------------------------------------------------------

echo "The Pi calls cloud APIs for inference. Choose a provider:"
echo ""
echo "  1) Claude (Anthropic) - most capable, recommended"
echo "  2) Gemini (Google)    - free tier available"
echo "  3) OpenAI (GPT-4o)   - widely supported"
echo "  4) Skip for now"
echo ""
read -p "Choice [1-4]: " AI_CHOICE

case "${AI_CHOICE:-4}" in
    1)
        info "Setting up Claude..."
        read -p "Anthropic API key: " ANTHROPIC_KEY
        if [[ -n "$ANTHROPIC_KEY" ]]; then
            echo "export ANTHROPIC_API_KEY='$ANTHROPIC_KEY'" >> ~/.zshrc
            export ANTHROPIC_API_KEY="$ANTHROPIC_KEY"
            log "Anthropic API key saved to ~/.zshrc"
        fi
        ;;
    2)
        info "Setting up Gemini..."
        read -p "Google AI API key: " GOOGLE_KEY
        if [[ -n "$GOOGLE_KEY" ]]; then
            echo "export GOOGLE_API_KEY='$GOOGLE_KEY'" >> ~/.zshrc
            export GOOGLE_API_KEY="$GOOGLE_KEY"
            log "Google API key saved to ~/.zshrc"
        fi
        ;;
    3)
        info "Setting up OpenAI..."
        read -p "OpenAI API key: " OPENAI_KEY
        if [[ -n "$OPENAI_KEY" ]]; then
            echo "export OPENAI_API_KEY='$OPENAI_KEY'" >> ~/.zshrc
            export OPENAI_API_KEY="$OPENAI_KEY"
            log "OpenAI API key saved to ~/.zshrc"
        fi
        ;;
    4)
        info "Skipping AI provider setup"
        ;;
esac

# ---------------------------------------------------------------------------
# OpenClaw initial configuration
# ---------------------------------------------------------------------------

echo ""
info "Running OpenClaw configuration..."
if command -v openclaw &>/dev/null; then
    openclaw configure 2>/dev/null || {
        warn "openclaw configure not available yet"
        echo "  Start manually with: openclaw gateway start"
    }
else
    warn "OpenClaw not found in PATH. Try: source ~/.zshrc && openclaw configure"
fi

# ---------------------------------------------------------------------------
# Browser verification
# ---------------------------------------------------------------------------

echo ""
info "Checking browser..."
CHROME=$(which chromium 2>/dev/null || which chromium-browser 2>/dev/null || echo "")
if [[ -n "$CHROME" ]]; then
    echo "  Chromium: $CHROME"
    echo "  Version:  $($CHROME --version 2>/dev/null)"
    log "Browser ready for headless automation"
else
    warn "Chromium not found. Browser automation will not work."
fi

# ---------------------------------------------------------------------------
# Systemd service for OpenClaw (auto-start on boot)
#
# Creates a user-level systemd unit that starts the OpenClaw gateway
# in foreground mode. Uses loginctl enable-linger so the service
# runs even when the user is not logged in.
# ---------------------------------------------------------------------------

echo ""
read -p "Enable OpenClaw auto-start on boot? [y/N]: " AUTOSTART
if [[ "${AUTOSTART:-n}" =~ ^[Yy]$ ]]; then
    mkdir -p ~/.config/systemd/user

    cat > ~/.config/systemd/user/openclaw.service << EOF
[Unit]
Description=OpenClaw Agent Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$HOME/.npm-global/bin/openclaw gateway start --foreground
Restart=on-failure
RestartSec=10
Environment=PATH=$HOME/.npm-global/bin:$HOME/.nvm/versions/node/$(node --version)/bin:/usr/local/bin:/usr/bin:/bin
Environment=HOME=$HOME
Environment=NVM_DIR=$HOME/.nvm
WorkingDirectory=$HOME/.openclaw/workspace

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable openclaw
    loginctl enable-linger "$USER" 2>/dev/null || sudo loginctl enable-linger "$USER"
    log "OpenClaw service enabled"
    echo "  Start now:  systemctl --user start openclaw"
    echo "  View logs:  journalctl --user -u openclaw -f"
else
    info "Skipped. Start manually: openclaw gateway start"
fi

# ---------------------------------------------------------------------------
# API Proxy (OpenAI-compatible endpoint on port 11435)
#
# Creates a user-level systemd unit for the proxy server. Binds to
# 0.0.0.0 so any device on the LAN can reach it.
# ---------------------------------------------------------------------------

echo ""
read -p "Enable OpenAI-compatible API proxy on port 11435? [Y/n]: " ENABLE_PROXY
if [[ "${ENABLE_PROXY:-y}" =~ ^[Yy]$ ]] || [[ -z "$ENABLE_PROXY" ]]; then
    mkdir -p ~/.config/systemd/user

    NVM_NODE="$HOME/.nvm/versions/node/$(node --version)/bin"
    cat > ~/.config/systemd/user/openclaw-proxy.service << EOF
[Unit]
Description=OpenClaw API Proxy (OpenAI-compatible)
After=network-online.target openclaw.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=$NVM_NODE/node /opt/openclaw-proxy/server.js
Restart=on-failure
RestartSec=5
Environment=PORT=11435
Environment=BIND=0.0.0.0
Environment=PATH=$NVM_NODE:/usr/local/bin:/usr/bin:/bin
WorkingDirectory=/opt/openclaw-proxy

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable openclaw-proxy
    systemctl --user start openclaw-proxy 2>/dev/null || true
    log "API proxy enabled on port 11435"
    echo "  Test: curl http://\$(hostname -I | awk '{print \$1}'):11435/health"
    echo "  Use:  base_url=http://PI_IP:11435/v1 with any OpenAI client"
else
    info "Skipped API proxy"
fi

# ---------------------------------------------------------------------------
# Chat integration notes
# ---------------------------------------------------------------------------

echo ""
echo "--------------------------------------------"
echo "  Chat Integration (optional)"
echo "--------------------------------------------"
echo ""
echo "Connect a chat platform to talk to your agent:"
echo ""
echo "  Discord:   Create a bot at discord.com/developers, add token to openclaw config"
echo "  Telegram:  Talk to @BotFather, create bot, add token to openclaw config"
echo "  Signal:    Link as secondary device"
echo ""
echo "Configure via: openclaw config"
echo ""

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

echo "--------------------------------------------"
echo "  Configuration Complete"
echo "--------------------------------------------"
echo ""
echo "  openclaw gateway start    Start the agent"
echo "  openclaw chat             Interactive chat"
echo "  openclaw status           Check status"
echo ""
