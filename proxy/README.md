# openclaw-proxy

OpenAI + Ollama compatible API proxy that routes through your OpenClaw agent.

Any app that speaks the OpenAI API can now talk to your Pi's AI agent — complete with browser control, tool use, and memory.

## Endpoints

| Path | Method | Compat | Description |
|------|--------|--------|-------------|
| `/v1/chat/completions` | POST | OpenAI | Chat completions (streaming + non-streaming) |
| `/v1/models` | GET | OpenAI | List available models |
| `/api/chat` | POST | Ollama | Chat (Ollama format) |
| `/api/tags` | GET | Ollama | List models (Ollama format) |
| `/health` | GET | — | Health check |

## Quick Start

```bash
cd proxy
node server.js
```

## Usage Examples

### curl

```bash
curl http://YOUR_PI_IP:11435/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openclaw-agent",
    "messages": [{"role": "user", "content": "What time is it?"}]
  }'
```

### Python (openai library)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://YOUR_PI_IP:11435/v1",
    api_key="not-needed"
)

response = client.chat.completions.create(
    model="openclaw-agent",
    messages=[{"role": "user", "content": "Search the web for today's news"}]
)
print(response.choices[0].message.content)
```

### JavaScript/TypeScript

```js
const response = await fetch("http://YOUR_PI_IP:11435/v1/chat/completions", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "openclaw-agent",
    messages: [{ role: "user", content: "Check my calendar" }],
    stream: true
  })
});
```

### Ollama CLI (drop-in)

```bash
# Point Ollama clients at the proxy
OLLAMA_HOST=http://YOUR_PI_IP:11435 ollama run openclaw-agent
```

### Open WebUI / ChatGPT-compatible UIs

Set the API base URL to `http://YOUR_PI_IP:11435/v1` and use any API key.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `11435` | Proxy listen port |
| `BIND` | `0.0.0.0` | Bind address (0.0.0.0 = all interfaces) |
| `OPENCLAW_HOST` | `127.0.0.1` | OpenClaw Gateway host |
| `OPENCLAW_PORT` | `18800` | OpenClaw Gateway port |
| `OPENCLAW_TOKEN` | — | Gateway auth token (if configured) |
| `MODEL_NAME` | `openclaw-agent` | Model name exposed to clients |

## Why Not Just Use Ollama Directly?

Ollama gives you a raw LLM. This proxy gives you an **agent** — it can:

- 🌐 Browse the web and interact with pages
- 🖥️ Run shell commands on the Pi
- 📁 Read and write files
- 🔍 Search the internet
- 💬 Access chat history and memory
- ⏰ Set reminders and cron jobs
- 🐳 Manage Docker containers

Same API, way more capability.
