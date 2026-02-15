<div align="center">

# openclaw-on-rpi

**Provision a Raspberry Pi as an always-on AI agent in one command.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-4B%20%7C%205-C51A4A?logo=raspberrypi&logoColor=white)](https://www.raspberrypi.com/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/hackur/openclaw-on-rpi/pulls)

[Quick Start](#quick-start) · [What You Get](#what-you-get) · [Local API](#local-ai-api) · [Commands](#commands) · [FAQ](#faq)

</div>

---

I wanted an AI agent running 24/7 on my network -- something that can browse the web, run shell commands, talk to me on Telegram, and expose an API I can hit from any device in the house. Not a chatbot. An actual agent with tools.

A Raspberry Pi is perfect for this. Low power, always on, dirt cheap. But setting one up from scratch is tedious. So I automated it.

`openclaw-on-rpi` takes a fresh Pi and installs everything needed to run an [OpenClaw](https://openclaw.ai) agent: Node.js, Chromium for headless browsing, Docker, systemd services, and an OpenAI-compatible API proxy that lets any app on your LAN talk to the agent.

```bash
./openclaw-rpi setup 192.168.1.100
```

That's the whole thing. About 15 minutes and your Pi is an agent.

## What it can do

- Browse websites with headless Chromium (click, type, screenshot, scrape)
- Run shell commands, manage Docker containers, interact with git
- Chat via Discord, Telegram, Signal, or SSH
- Expose an OpenAI-compatible API on your local network (port 11435)
- Auto-start on boot, survive power loss, restart on crash
- Call Claude, Gemini, or OpenAI for inference -- the Pi handles execution

The Pi doesn't run models. It *calls* them. Cloud does the thinking, Pi does the doing. That's why it works on $35 hardware.

## Quick Start

**You need:** A Raspberry Pi 4B (4GB+) or Pi 5, flashed with [Raspberry Pi OS Lite 64-bit](https://www.raspberrypi.com/software/), SSH enabled.

```bash
git clone https://github.com/hackur/openclaw-on-rpi.git
cd openclaw-on-rpi

# Guided SD card flashing (if you haven't already)
./openclaw-rpi flash

# Full setup: provision, configure, verify
./openclaw-rpi setup 192.168.1.100
```

Or do it in steps:

```bash
./openclaw-rpi provision 192.168.1.100    # Install dependencies
./openclaw-rpi configure 192.168.1.100    # AI provider + chat + services
./openclaw-rpi verify 192.168.1.100       # Health check
```

## What You Get

| Component | What it does |
|-----------|-------------|
| **OpenClaw** | Agent runtime -- sessions, tools, memory, cron |
| **Node.js LTS** | Runtime (via nvm) |
| **Chromium** | Headless browser for web automation |
| **Docker** | Container support (optional, skip with `SKIP_DOCKER=1`) |
| **openclaw-proxy** | OpenAI-compatible API on your LAN |
| **Zsh + Oh My Zsh** | Shell that doesn't make you sad |
| git, jq, rg, gh, ffmpeg | The usual suspects |

The provisioner configures one of these as your AI backend:

| Provider | Notes |
|----------|-------|
| **Claude** (Anthropic) | Best reasoning and tool use. My default. |
| **Gemini** (Google) | Free tier. Solid for general tasks. |
| **OpenAI** (GPT-4o) | Works well. You know the deal. |

## Local AI API

This is the part I'm most excited about. The Pi runs an OpenAI-compatible proxy on port 11435. Any device on your network can hit it -- phones, laptops, scripts, Open WebUI, whatever.

```bash
curl http://PI_IP:11435/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"openclaw-agent","messages":[{"role":"user","content":"what is on hacker news right now"}]}'
```

```python
from openai import OpenAI

client = OpenAI(base_url="http://PI_IP:11435/v1", api_key="not-needed")
resp = client.chat.completions.create(
    model="openclaw-agent",
    messages=[{"role": "user", "content": "Browse example.com and summarize it"}]
)
```

It speaks both OpenAI and Ollama protocols. Streaming works. The difference from hitting a normal LLM endpoint: this one has an agent behind it with browser access, shell access, and tools. It can actually *do* things, not just talk about them.

Full docs: [proxy/README.md](proxy/README.md)

## Architecture

```
  Your LAN
  ----------------------------------------
  Laptop / Phone / Script / Open WebUI
       |
       |  OpenAI API (:11435)
       v
  +-------------------------------------+
  |          Raspberry Pi               |
  |                                     |
  |  +----------------+                |
  |  | openclaw-proxy | <-- /v1/chat   |
  |  +-------+--------+                |
  |          |                          |
  |  +-------v--------+  +-----------+ |
  |  |    OpenClaw    |--| Chromium  | |
  |  |     Agent      |  | (headless)| |
  |  |                |  +-----------+ |
  |  |  Claude /      |  +-----------+ |
  |  |  Gemini /      |--| Shell     | |
  |  |  OpenAI        |  | Docker    | |
  |  |                |  +-----------+ |
  |  |                |  +-----------+ |
  |  |                |--| Telegram  | |
  |  |                |  | Discord   | |
  |  +----------------+  +-----------+ |
  +-------------------------------------+
```

## Commands

```
openclaw-rpi flash              SD card flashing guide
openclaw-rpi provision <ip>     Install everything on the Pi
openclaw-rpi configure <ip>     AI provider, chat, systemd setup
openclaw-rpi verify <ip>        Health check
openclaw-rpi setup <ip>         All three above in sequence
openclaw-rpi ssh <ip>           SSH in
openclaw-rpi status <ip>        System + agent status
openclaw-rpi logs <ip>          Tail agent logs
openclaw-rpi update <ip>        Update packages + OpenClaw
openclaw-rpi browser-test <ip>  Verify Chromium works
```

## Configuration

```bash
export PI_USER=pi                                    # SSH user
export PI_HOSTNAME=openclaw-pi                       # Hostname
export SKIP_DOCKER=1                                 # No Docker
export INSTALL_OLLAMA=1                              # Opt-in: local models
export OLLAMA_MODELS="qwen2.5:1.5b gemma2:2b"       # Which models
```

<details>
<summary><strong>Full provisioning steps</strong></summary>

1. System update (`apt upgrade`)
2. Base packages: git, jq, ripgrep, curl, build-essential, gh, ffmpeg, tmux, htop
3. Chromium for headless browsing
4. Zsh + Oh My Zsh
5. Docker (optional)
6. Node.js LTS via nvm
7. OpenClaw agent framework
8. OpenClaw proxy (OpenAI-compatible API)
9. Ollama (opt-in with `INSTALL_OLLAMA=1`)
10. Systemd services (optional, prompted during configure)

</details>

## Use Cases

Some things I use it for, or plan to:

- **Package tracking** -- "did my Amazon order ship?" and the agent browses the tracking page
- **Always-on Discord bot** -- real browser access, not just API calls
- **Dev monitoring** -- watches repos, runs tests on push, alerts on failure
- **Research** -- "find me the cheapest flight to Vegas next weekend" and it actually searches
- **Home API** -- hit it from Shortcuts on my phone, get real answers with web access

## FAQ

<details>
<summary><strong>Pi 3?</strong></summary>

No. 32-bit, 1GB RAM. Chromium alone will eat that. Pi 4B 4GB minimum.
</details>

<details>
<summary><strong>Pi 5?</strong></summary>

Works great. Faster CPU, more RAM. Same provisioner.
</details>

<details>
<summary><strong>Headless only?</strong></summary>

Yeah, that's the point. Flash the card with SSH, find the IP, provision over the network. No monitor.
</details>

<details>
<summary><strong>Cost?</strong></summary>

Pi: $35-80. Power: about $5/year. AI API: depends on usage. Claude and Gemini both have reasonable pricing. You can also use Ollama locally if you want free (slower).
</details>

<details>
<summary><strong>Survives reboot?</strong></summary>

If you enable the systemd service during setup, yes. Auto-starts, auto-restarts on crash. Back online in about 30 seconds after power loss.
</details>

<details>
<summary><strong>Multiple Pis?</strong></summary>

Run setup for each IP. Each Pi gets its own independent agent.
</details>

<details>
<summary><strong>Linux host?</strong></summary>

Should work -- it's just SSH and SCP. Tested on macOS. PRs welcome if something breaks on Linux.
</details>

## Troubleshooting

```bash
# Find the Pi
arp -na | grep -i "b8:27:eb\|dc:a6:32\|e4:5f:01\|2c:cf:67\|d8:3a:dd"
ping openclaw-pi.local

# Browser broken?
./openclaw-rpi ssh <ip> "chromium --headless --disable-gpu --dump-dom https://example.com"

# Check resources
./openclaw-rpi status <ip>

# Logs
./openclaw-rpi logs <ip>
```

## Roadmap

- [x] One-command provisioning
- [x] AI provider configuration (Claude, Gemini, OpenAI)
- [x] Headless browser automation
- [x] OpenAI-compatible local API proxy
- [x] Systemd auto-start
- [ ] Pi 5 optimized path
- [ ] Fleet provisioning (multiple Pis)
- [ ] Pre-built SD card images
- [ ] Ansible alternative
- [ ] Pi Zero 2 W minimal mode
- [ ] Web dashboard
- [ ] OTA updates

## Contributing

PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

Things I'd especially appreciate help with:
- Testing on Pi 5 and other ARM boards
- Provisioning from Linux/WSL
- Chat integration walkthroughs (Discord bot setup, Telegram BotFather flow)

## License

[MIT](LICENSE)

---

<div align="center">

Built on [OpenClaw](https://openclaw.ai) for [Raspberry Pi](https://raspberrypi.com).

</div>
