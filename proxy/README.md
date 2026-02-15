# openclaw-proxy

OpenAI and Ollama compatible API proxy that routes through your OpenClaw agent.

Any app that speaks the OpenAI API can talk to your Pi's agent -- with browser control, shell access, and tools. Not just a language model.

## Endpoints

| Path | Method | Format | Description |
|------|--------|--------|-------------|
| `/v1/chat/completions` | POST | OpenAI | Chat completions (streaming and non-streaming) |
| `/v1/models` | GET | OpenAI | List available models |
| `/api/chat` | POST | Ollama | Chat (Ollama format) |
| `/api/tags` | GET | Ollama | List models (Ollama format) |
| `/health` | GET | -- | Health check |

## Quick Start

```bash
cd proxy
node server.js
```

## Usage

### curl

```bash
curl http://PI_IP:11435/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openclaw-agent",
    "messages": [{"role": "user", "content": "What time is it?"}]
  }'
```

### Python

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://PI_IP:11435/v1",
    api_key="not-needed"
)

response = client.chat.completions.create(
    model="openclaw-agent",
    messages=[{"role": "user", "content": "Search the web for today's news"}]
)
print(response.choices[0].message.content)
```

### JavaScript

```js
const response = await fetch("http://PI_IP:11435/v1/chat/completions", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "openclaw-agent",
    messages: [{ role: "user", content: "Check my calendar" }],
    stream: true
  })
});
```

### Ollama-compatible clients

```bash
OLLAMA_HOST=http://PI_IP:11435 ollama run openclaw-agent
```

### Open WebUI, TypingMind, Chatbox, etc.

Set the API base URL to `http://PI_IP:11435/v1` and use any API key.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `11435` | Listen port |
| `BIND` | `0.0.0.0` | Bind address |
| `OPENCLAW_HOST` | `127.0.0.1` | OpenClaw Gateway host |
| `OPENCLAW_PORT` | `18800` | OpenClaw Gateway port |
| `OPENCLAW_TOKEN` | -- | Gateway auth token (if configured) |
| `MODEL_NAME` | `openclaw-agent` | Model name exposed to clients |

## Why not just hit Ollama or the cloud API directly?

Those give you a raw language model. This proxy gives you an agent. It can:

- Browse websites and interact with them
- Run shell commands
- Read and write files
- Search the internet
- Access chat history and memory
- Set reminders and cron jobs
- Manage Docker containers

Same API format, much more capability.
