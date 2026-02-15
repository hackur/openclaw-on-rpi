#!/bin/bash
#
# configure.sh — Interactive OpenClaw configuration (runs ON THE PI)
#
set -euo pipefail

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
export PATH=~/.npm-global/bin:$PATH

log()  { echo -e "\033[0;32m✓\033[0m $*"; }
info() { echo -e "\033[0;34m→\033[0m $*"; }
warn() { echo -e "\033[1;33m⚠\033[0m $*"; }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ⚙️  OpenClaw Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── AI Provider ──────────────────────────────────────────

echo "Select your AI provider:"
echo ""
echo "  1) Claude (Anthropic) — Most capable, recommended"
echo "  2) Gemini (Google)    — Free tier available"
echo "  3) OpenAI (GPT-4)    — Widely supported"
echo "  4) Ollama (Local)    — Private, no API key needed"
echo "  5) Skip for now"
echo ""
read -p "Choice [1-5]: " AI_CHOICE

case "${AI_CHOICE:-5}" in
    1)
        info "Setting up Claude..."
        read -p "Anthropic API key: " ANTHROPIC_KEY
        if [[ -n "$ANTHROPIC_KEY" ]]; then
            echo "export ANTHROPIC_API_KEY='$ANTHROPIC_KEY'" >> ~/.zshrc
            export ANTHROPIC_API_KEY="$ANTHROPIC_KEY"
            log "Anthropic API key saved"
        fi
        ;;
    2)
        info "Setting up Gemini..."
        read -p "Google AI API key: " GOOGLE_KEY
        if [[ -n "$GOOGLE_KEY" ]]; then
            echo "export GOOGLE_API_KEY='$GOOGLE_KEY'" >> ~/.zshrc
            export GOOGLE_API_KEY="$GOOGLE_KEY"
            log "Google API key saved"
        fi
        ;;
    3)
        info "Setting up OpenAI..."
        read -p "OpenAI API key: " OPENAI_KEY
        if [[ -n "$OPENAI_KEY" ]]; then
            echo "export OPENAI_API_KEY='$OPENAI_KEY'" >> ~/.zshrc
            export OPENAI_API_KEY="$OPENAI_KEY"
            log "OpenAI API key saved"
        fi
        ;;
    4)
        info "Using Ollama (local models)"
        echo "Available models:"
        ollama list 2>/dev/null || warn "Ollama not running — start with: ollama serve"
        ;;
    5)
        info "Skipping AI provider setup"
        ;;
esac

# ── OpenClaw Setup ───────────────────────────────────────

echo ""
info "Running OpenClaw configuration..."
if command -v openclaw &>/dev/null; then
    openclaw configure 2>/dev/null || {
        warn "openclaw configure not available — set up manually"
        echo "  Run: openclaw gateway start"
    }
else
    warn "OpenClaw not found in PATH. Try: source ~/.zshrc && openclaw configure"
fi

# ── Browser ──────────────────────────────────────────────

echo ""
info "Testing browser control..."
CHROME=$(which chromium 2>/dev/null || which chromium-browser 2>/dev/null || echo "")
if [[ -n "$CHROME" ]]; then
    echo "Chromium found: $CHROME"
    echo "Version: $($CHROME --version 2>/dev/null)"
    log "Browser ready for headless automation"
else
    warn "Chromium not found — browser automation won't work"
fi

# ── Systemd Service ──────────────────────────────────────

echo ""
read -p "Enable OpenClaw auto-start on boot? [y/N]: " AUTOSTART
if [[ "${AUTOSTART:-n}" =~ ^[Yy]$ ]]; then
    mkdir -p ~/.config/systemd/user

    cat > ~/.config/systemd/user/openclaw.service << EOF
[Unit]
Description=OpenClaw AI Agent Gateway
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
    log "OpenClaw service enabled (starts on boot)"
    echo "  Start now: systemctl --user start openclaw"
    echo "  View logs: journalctl --user -u openclaw -f"
else
    info "Skipped auto-start. Start manually: openclaw gateway start"
fi

# ── Chat Integration ─────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📱 Chat Integration (optional)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Connect a chat platform to talk to your agent:"
echo ""
echo "  Discord:  Create a bot at discord.com/developers"
echo "            Add token to openclaw config"
echo ""
echo "  Telegram: Talk to @BotFather, create bot, get token"
echo "            Add token to openclaw config"
echo ""
echo "  Signal:   Link as secondary device"
echo ""
echo "Configure via: openclaw config"
echo ""

# ── Done ─────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Configuration Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Quick start:"
echo "  openclaw gateway start    # Start the agent"
echo "  openclaw chat             # Interactive chat"
echo "  openclaw status           # Check status"
echo ""
