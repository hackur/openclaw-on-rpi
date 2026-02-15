<div align="center">

# 🤖 openclaw-on-rpi

### Turn a Raspberry Pi into a 24/7 AI agent in one command

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-4B%20%7C%205-C51A4A?logo=raspberrypi&logoColor=white)](https://www.raspberrypi.com/)
[![OpenClaw](https://img.shields.io/badge/Powered%20by-OpenClaw-blue)](https://openclaw.ai)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/hackur/openclaw-on-rpi/pulls)

**One script. One Pi. Always-on AI that browses the web, runs commands, and talks to you on Discord/Telegram/Signal.**

[Quick Start](#-quick-start) · [What You Get](#-what-you-get) · [Commands](#-commands) · [FAQ](#-faq) · [Contributing](CONTRIBUTING.md)

</div>

---

## Why?

Cloud AI costs money and goes down. A Raspberry Pi costs $35 and sits on your desk forever.

**openclaw-on-rpi** provisions a Pi as a fully autonomous [OpenClaw](https://openclaw.ai) agent — an AI that can:

- 🌐 **Browse the web** — headless Chromium, click/type/screenshot anything
- 💬 **Chat with you** — Discord, Telegram, Signal, or SSH
- 🖥️ **Run commands** — full shell access, Docker, git, the works
- 🧠 **Use any AI** — Claude, Gemini, OpenAI — calls cloud APIs, runs locally
- ⏰ **Work 24/7** — systemd service, auto-restarts, survives reboots

- 🔌 **Expose an API** — OpenAI-compatible endpoint on your local network

All from one command:

```bash
./openclaw-rpi setup 192.168.1.100
```

## ⚡ Quick Start

### Prerequisites

- A **Raspberry Pi 4B** (4GB+) or **Pi 5** with an SD card
- **Raspberry Pi OS 64-bit Lite** (Bookworm) flashed via [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
- SSH enabled, Pi on your network
- A Mac or Linux machine to run the provisioner

### Install

```bash
git clone https://github.com/hackur/openclaw-on-rpi.git
cd openclaw-on-rpi
```

### Flash (guided wizard)

```bash
./openclaw-rpi flash
```

### Provision + Configure + Verify

```bash
# All-in-one (takes ~15 minutes)
./openclaw-rpi setup 192.168.1.100
```

Or step by step:

```bash
./openclaw-rpi provision 192.168.1.100    # Install everything
./openclaw-rpi configure 192.168.1.100    # Set up AI provider + chat
./openclaw-rpi verify 192.168.1.100       # Health check
```

That's it. Your Pi is now an AI agent.

## 📦 What You Get

| Component | Purpose | Size |
|-----------|---------|------|
| **OpenClaw** | AI agent runtime | ~50MB |
| **Node.js LTS** | Runtime (via nvm) | ~80MB |
| **Chromium** | Headless browser control | ~200MB |
| **Docker** | Container support | ~300MB |
| **Zsh + Oh My Zsh** | Better shell | ~30MB |
| **openclaw-proxy** | OpenAI-compatible API server | ~1MB |
| git, jq, rg, gh, ffmpeg | Dev/media tools | ~100MB |

> **Total:** ~600MB without Docker. Fits easily on a 16GB card.

### AI Providers

The Pi doesn't run models — it *calls* them. All inference happens in the cloud. The Pi is the always-on agent that orchestrates everything.

| Provider | Cost | Best For |
|----------|------|----------|
| **Claude** (Anthropic) | API key | Complex reasoning, coding, tool use |
| **Gemini** (Google) | Free tier available | General tasks, research |
| **OpenAI** (GPT-4) | API key | Broad capability |

> 💡 **The Pi's job is execution, not inference.** It calls whichever cloud AI you configure, then acts on the response — browsing, running commands, sending messages. That's what makes it powerful on $35 hardware.

## 🎮 Commands

```
openclaw-rpi flash              Guided SD card flashing
openclaw-rpi provision <ip>     Install all dependencies
openclaw-rpi configure <ip>     Interactive AI + chat setup
openclaw-rpi verify <ip>        Health check (all green = good)
openclaw-rpi setup <ip>         Full pipeline (provision + configure + verify)
openclaw-rpi ssh <ip>           SSH into the Pi
openclaw-rpi status <ip>        System + OpenClaw status
openclaw-rpi logs <ip>          Tail agent logs
openclaw-rpi update <ip>        Update everything
openclaw-rpi browser-test <ip>  Test headless Chromium
```

## ⚙️ Configuration

Override defaults with environment variables:

```bash
export PI_USER=pi                                    # SSH username
export PI_HOSTNAME=openclaw-pi                       # Hostname
export SKIP_DOCKER=1                                 # Skip Docker
export INSTALL_OLLAMA=1                              # Opt-in: local models via Ollama
export OLLAMA_MODELS="qwen2.5:1.5b gemma2:2b"       # Models (if Ollama enabled)
```

## 🏗️ Architecture

```
┌───────────────────────────────────────────────────────────┐
│                    Your Network                            │
│                                                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                │
│  │  Laptop  │  │  Phone   │  │ Open     │  Any device     │
│  │  Script  │  │  App     │  │ WebUI    │  on your LAN    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                │
│       │              │              │                      │
│       └──────────────┼──────────────┘                      │
│                      │ OpenAI API (:11435)                 │
│                      ▼                                     │
│   ┌──────────────────────────────────────────────┐        │
│   │              Raspberry Pi                     │        │
│   │                                               │        │
│   │   ┌────────────────┐                          │        │
│   │   │ openclaw-proxy │ ← OpenAI + Ollama API   │        │
│   │   └───────┬────────┘                          │        │
│   │           │                                   │        │
│   │   ┌───────▼────────┐  ┌──────────────────┐   │        │
│   │   │    OpenClaw    │──│ Chromium (headless│   │        │
│   │   │     Agent      │  └──────────────────┘   │        │
│   │   │                │  ┌──────────────────┐   │        │
│   │   │  Claude/Gemini │──│ Shell / Docker   │   │        │
│   │   │  Ollama local  │  └──────────────────┘   │        │
│   │   │                │  ┌──────────────────┐   │        │
│   │   │                │──│ Discord/Telegram │   │        │
│   │   └────────────────┘  └──────────────────┘   │        │
│   └──────────────────────────────────────────────┘        │
└───────────────────────────────────────────────────────────┘
```

## 🔧 What It Actually Does

<details>
<summary><strong>Click to see the full provisioning steps</strong></summary>

1. **System update** — `apt upgrade` to latest
2. **Base packages** — git, jq, ripgrep, curl, build-essential, gh, ffmpeg, tmux, htop
3. **Chromium** — headless browser for web automation
4. **Zsh + Oh My Zsh** — better shell experience
5. **Docker** — container runtime (optional, `SKIP_DOCKER=1` to skip)
6. **Node.js LTS** — via nvm, with npm global directory configured
7. **OpenClaw** — AI agent framework
8. **Ollama** — local LLM runtime (opt-in with `INSTALL_OLLAMA=1`)
9. **Systemd service** — auto-start on boot (optional during configure)

</details>

## 🔌 Local AI API (OpenAI-compatible)

The killer feature: your Pi exposes an **OpenAI-compatible API** on your local network. Any app, script, or UI that speaks OpenAI can use your agent.

```bash
# From any device on your network
curl http://YOUR_PI_IP:11435/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"openclaw-agent","messages":[{"role":"user","content":"Search for the latest news"}]}'
```

```python
# Python — just change the base URL
from openai import OpenAI
client = OpenAI(base_url="http://YOUR_PI_IP:11435/v1", api_key="not-needed")
response = client.chat.completions.create(
    model="openclaw-agent",
    messages=[{"role": "user", "content": "Browse example.com and summarize it"}]
)
```

Works with **Open WebUI**, **TypingMind**, **Chatbox**, **any OpenAI SDK**, and even **Ollama-compatible clients**. It's not just a language model — it's a full agent with browser, shell, and tool access behind a standard API.

> See [proxy/README.md](proxy/README.md) for full documentation.

## 💡 Use Cases

- **Home automation assistant** — "Check if my package shipped" → browses tracking site
- **Discord/Telegram bot** — always-on AI in your server with real browser access
- **Dev assistant** — monitors repos, runs tests, manages deployments
- **Research agent** — scrapes sites, summarizes content, saves to files
- **Security monitor** — watches logs, checks for anomalies, alerts you
- **Personal API** — SSH in and ask questions from your phone

## ❓ FAQ

<details>
<summary><strong>Will it work on a Pi 3?</strong></summary>

Not recommended. Pi 3 is 32-bit and only has 1GB RAM. You'll hit memory limits quickly, especially with Chromium. Pi 4B with 4GB+ is the minimum.
</details>

<details>
<summary><strong>Does it work on Pi 5?</strong></summary>

Yes! Pi 5 is even better — faster CPU, more RAM options. The provisioner works the same way.
</details>

<details>
<summary><strong>Can I run it headless (no monitor)?</strong></summary>

That's the intended use. Flash the SD card with SSH enabled, find the Pi's IP, and provision over the network. No monitor needed.
</details>

<details>
<summary><strong>How much does it cost to run?</strong></summary>

Hardware: ~$35-80 for the Pi. Power: ~$5/year. AI API: depends on usage (Claude/Gemini have free tiers or pay-per-use). Ollama: completely free but slower.
</details>

<details>
<summary><strong>Can I provision from Linux?</strong></summary>

The provisioner should work from any machine with SSH and SCP. It's been tested on macOS. Linux should work — PRs welcome if you find issues.
</details>

<details>
<summary><strong>Can I provision multiple Pis?</strong></summary>

Yes! Run `./openclaw-rpi setup <ip>` for each one. Each Pi gets its own independent agent.
</details>

<details>
<summary><strong>What if I lose power?</strong></summary>

If you enabled the systemd service during configuration, OpenClaw auto-starts on boot. Your agent comes back online within ~30 seconds of power restoration.
</details>

## 🐛 Troubleshooting

```bash
# Can't find Pi on network
arp -na | grep -i "b8:27:eb\|dc:a6:32\|e4:5f:01\|2c:cf:67\|d8:3a:dd"

# Or try mDNS
ping openclaw-pi.local

# Browser won't start
./openclaw-rpi ssh <ip> "chromium --headless --disable-gpu --dump-dom https://example.com"

# Check system resources
./openclaw-rpi status <ip>

# View agent logs
./openclaw-rpi logs <ip>
```

## 🗺️ Roadmap

- [x] One-command provisioning
- [x] AI provider setup (Claude, Gemini, OpenAI, Ollama)
- [x] Headless browser automation
- [x] Systemd auto-start
- [ ] Pi 5 optimized path
- [ ] Fleet provisioning (multiple Pis at once)
- [ ] Ansible playbook alternative
- [ ] Pre-built SD card images
- [ ] Pi Zero 2 W support (minimal mode)
- [ ] Web dashboard for management
- [ ] OTA updates

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Areas that need help:**
- Testing on Pi 5 and other ARM SBCs
- Non-Mac provisioning (Linux, WSL)
- Ollama model benchmarks on different Pi models
- Chat integration setup guides

## 📜 License

[MIT](LICENSE) — do whatever you want with it.

---

<div align="center">

**Built with [OpenClaw](https://openclaw.ai) · Made for [Raspberry Pi](https://raspberrypi.com)**

If this saved you time, give it a ⭐

</div>
