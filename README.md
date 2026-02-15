# OpenClaw on Raspberry Pi

One-command provisioning of a Raspberry Pi as a 24/7 OpenClaw AI agent with browser control, chat integrations, and optional local models.

## Requirements

- **Mac** with SSH access to the Pi
- **Raspberry Pi 4B** (4GB+, 8GB recommended for local models)
- **SD card** flashed with **Raspberry Pi OS 64-bit Lite** (Bookworm)
- Pi on the same network, SSH enabled

## Quick Start

```bash
# 1. Flash SD card (interactive wizard)
./openclaw-rpi flash

# 2. Provision the Pi (installs everything)
./openclaw-rpi provision 192.168.1.100

# 3. Configure OpenClaw (AI provider, chat services)
./openclaw-rpi configure 192.168.1.100

# 4. Verify everything works
./openclaw-rpi verify 192.168.1.100
```

Or do it all at once:

```bash
./openclaw-rpi setup 192.168.1.100
```

## What Gets Installed

| Component | Purpose |
|-----------|---------|
| Node.js LTS (via nvm) | OpenClaw runtime |
| OpenClaw | AI agent framework |
| Chromium | Headless browser automation |
| Docker | Container support |
| Ollama | Local LLM inference (optional) |
| Zsh + Oh My Zsh | Better shell |
| git, jq, ripgrep, gh, ffmpeg | Dev tools |

## Commands

```
openclaw-rpi flash              Interactive SD card flashing guide
openclaw-rpi provision <ip>     Install all dependencies on the Pi
openclaw-rpi configure <ip>     Configure OpenClaw (AI provider, chat, browser)
openclaw-rpi verify <ip>        Health check — verify everything works
openclaw-rpi setup <ip>         Full pipeline: provision + configure + verify
openclaw-rpi ssh <ip>           SSH into the Pi
openclaw-rpi status <ip>        Check OpenClaw service status
openclaw-rpi logs <ip>          Tail OpenClaw logs
openclaw-rpi update <ip>        Update OpenClaw + system packages
openclaw-rpi browser-test <ip>  Test headless Chromium
```

## Configuration

Set environment variables or pass as flags:

```bash
export PI_USER=pi              # SSH username (default: pi)
export PI_HOSTNAME=openclaw-pi # Pi hostname (default: openclaw-pi)
export WIFI_SSID=MyNetwork     # For flash wizard
export WIFI_PASSWORD=secret    # For flash wizard
export OLLAMA_MODELS="qwen2.5:1.5b gemma2:2b"  # Models to pull
export SKIP_OLLAMA=1           # Skip Ollama install
export SKIP_DOCKER=1           # Skip Docker install
```

## Performance Notes

- Use cloud APIs (Claude/Gemini) for complex tasks — much faster than local models
- Local models (qwen2.5:1.5b) work but are slow on 4GB RAM
- Chromium headless is well-optimized on ARM64
- Browser automation uses the isolated `openclaw` profile

## Troubleshooting

```bash
# Can't find Pi on network
arp -na | grep -i "b8:27:eb\|dc:a6:32\|e4:5f:01\|2c:cf:67\|d8:3a:dd"

# Browser won't start
./openclaw-rpi ssh <ip> "chromium --headless --disable-gpu --dump-dom https://example.com"

# Check resources
./openclaw-rpi ssh <ip> "free -h && df -h && uptime"
```
