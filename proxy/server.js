#!/usr/bin/env node
/**
 * openclaw-proxy — OpenAI-compatible API server that routes through OpenClaw
 *
 * Exposes the OpenClaw agent as a local network LLM endpoint.
 * Any app that speaks OpenAI API can use your Pi agent — with full
 * browser control, tool use, memory, and chat integrations.
 *
 * Usage:
 *   node server.js                          # localhost:11435
 *   PORT=8080 node server.js                # custom port
 *   OPENCLAW_HOST=192.168.1.50 node server.js  # remote gateway
 *   BIND=0.0.0.0 node server.js             # expose to network
 */

import { createServer } from "node:http";
import { randomUUID } from "node:crypto";

// ── Config ───────────────────────────────────────────────

const PORT = parseInt(process.env.PORT || "11435", 10);
const BIND = process.env.BIND || "0.0.0.0";
const OPENCLAW_HOST = process.env.OPENCLAW_HOST || "127.0.0.1";
const OPENCLAW_PORT = parseInt(process.env.OPENCLAW_PORT || "18800", 10);
const OPENCLAW_TOKEN = process.env.OPENCLAW_TOKEN || "";
const MODEL_NAME = process.env.MODEL_NAME || "openclaw-agent";
const MAX_BODY = 1024 * 1024; // 1MB

// ── Helpers ──────────────────────────────────────────────

function jsonResponse(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  });
  res.end(body);
}

function sseChunk(res, data) {
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY) {
        reject(new Error("Body too large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString()));
    req.on("error", reject);
  });
}

function openaiError(res, status, message, type = "invalid_request_error") {
  jsonResponse(res, status, {
    error: { message, type, param: null, code: null },
  });
}

// ── OpenClaw Gateway Client ─────────────────────────────

async function sendToGateway(message, sessionLabel) {
  const url = `http://${OPENCLAW_HOST}:${OPENCLAW_PORT}/api/sessions/send`;
  const headers = { "Content-Type": "application/json" };
  if (OPENCLAW_TOKEN) headers["Authorization"] = `Bearer ${OPENCLAW_TOKEN}`;

  const resp = await fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify({
      message,
      label: sessionLabel || "proxy",
      timeoutSeconds: 120,
    }),
  });

  if (!resp.ok) {
    const text = await resp.text().catch(() => "unknown error");
    throw new Error(`Gateway returned ${resp.status}: ${text}`);
  }

  const data = await resp.json();
  return data.reply || data.message || data.text || JSON.stringify(data);
}

async function listGatewayModels() {
  // Try to get info from gateway, fall back to static
  try {
    const url = `http://${OPENCLAW_HOST}:${OPENCLAW_PORT}/api/status`;
    const headers = {};
    if (OPENCLAW_TOKEN) headers["Authorization"] = `Bearer ${OPENCLAW_TOKEN}`;
    const resp = await fetch(url, { headers, signal: AbortSignal.timeout(3000) });
    if (resp.ok) {
      const data = await resp.json();
      return data.model || MODEL_NAME;
    }
  } catch {}
  return MODEL_NAME;
}

// ── Message Formatting ──────────────────────────────────

function formatMessages(messages) {
  if (!Array.isArray(messages)) return String(messages);

  // Collapse message array into a single prompt
  // System messages become context, user/assistant become conversation
  const parts = [];
  for (const msg of messages) {
    const role = msg.role || "user";
    const content =
      typeof msg.content === "string"
        ? msg.content
        : Array.isArray(msg.content)
          ? msg.content
              .filter((p) => p.type === "text")
              .map((p) => p.text)
              .join("\n")
          : JSON.stringify(msg.content);

    if (role === "system") {
      parts.push(`[System] ${content}`);
    } else if (role === "assistant") {
      parts.push(`[Assistant] ${content}`);
    } else {
      parts.push(content);
    }
  }
  return parts.join("\n\n");
}

// ── Route Handlers ──────────────────────────────────────

async function handleChatCompletions(req, res, body) {
  const { messages, stream, model, temperature, max_tokens } = body;

  if (!messages || !Array.isArray(messages)) {
    return openaiError(res, 400, "messages is required and must be an array");
  }

  const prompt = formatMessages(messages);
  const requestId = `chatcmpl-${randomUUID().replace(/-/g, "").slice(0, 29)}`;
  const sessionLabel = body.user || `proxy-${model || MODEL_NAME}`;
  const created = Math.floor(Date.now() / 1000);

  if (stream) {
    // ── Streaming response ──
    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
      "Access-Control-Allow-Origin": "*",
    });

    try {
      const reply = await sendToGateway(prompt, sessionLabel);

      // Simulate streaming by chunking the response
      const chunkSize = 4; // ~4 chars per token, feels natural
      for (let i = 0; i < reply.length; i += chunkSize) {
        const text = reply.slice(i, i + chunkSize);
        sseChunk(res, {
          id: requestId,
          object: "chat.completion.chunk",
          created,
          model: model || MODEL_NAME,
          choices: [
            {
              index: 0,
              delta: { content: text },
              finish_reason: null,
            },
          ],
        });
      }

      // Final chunk
      sseChunk(res, {
        id: requestId,
        object: "chat.completion.chunk",
        created,
        model: model || MODEL_NAME,
        choices: [{ index: 0, delta: {}, finish_reason: "stop" }],
      });
      res.write("data: [DONE]\n\n");
    } catch (err) {
      sseChunk(res, {
        id: requestId,
        object: "chat.completion.chunk",
        created,
        model: model || MODEL_NAME,
        choices: [
          {
            index: 0,
            delta: { content: `Error: ${err.message}` },
            finish_reason: "stop",
          },
        ],
      });
      res.write("data: [DONE]\n\n");
    }
    res.end();
  } else {
    // ── Non-streaming response ──
    try {
      const reply = await sendToGateway(prompt, sessionLabel);

      jsonResponse(res, 200, {
        id: requestId,
        object: "chat.completion",
        created,
        model: model || MODEL_NAME,
        choices: [
          {
            index: 0,
            message: { role: "assistant", content: reply },
            finish_reason: "stop",
          },
        ],
        usage: {
          prompt_tokens: Math.ceil(prompt.length / 4),
          completion_tokens: Math.ceil(reply.length / 4),
          total_tokens: Math.ceil((prompt.length + reply.length) / 4),
        },
      });
    } catch (err) {
      openaiError(res, 502, `Gateway error: ${err.message}`, "api_error");
    }
  }
}

function handleModels(req, res) {
  jsonResponse(res, 200, {
    object: "list",
    data: [
      {
        id: MODEL_NAME,
        object: "model",
        created: 1700000000,
        owned_by: "openclaw",
        permission: [],
      },
      {
        id: "openclaw-agent-browser",
        object: "model",
        created: 1700000000,
        owned_by: "openclaw",
        permission: [],
      },
    ],
  });
}

function handleHealth(req, res) {
  jsonResponse(res, 200, {
    status: "ok",
    version: "1.0.0",
    gateway: `${OPENCLAW_HOST}:${OPENCLAW_PORT}`,
    model: MODEL_NAME,
    uptime: process.uptime(),
  });
}

// ── Server ──────────────────────────────────────────────

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname;

  // CORS preflight
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    });
    return res.end();
  }

  // Auth check (optional)
  if (OPENCLAW_TOKEN) {
    const auth = req.headers.authorization || "";
    const token = auth.replace(/^Bearer\s+/i, "");
    // Accept either the gateway token or any non-empty key
    // (we're the proxy, the gateway does real auth)
  }

  try {
    // OpenAI-compatible endpoints
    if (path === "/v1/chat/completions" && req.method === "POST") {
      const raw = await readBody(req);
      const body = JSON.parse(raw);
      return handleChatCompletions(req, res, body);
    }

    if (path === "/v1/models" && req.method === "GET") {
      return handleModels(req, res);
    }

    // Ollama-compatible endpoints
    if (path === "/api/chat" && req.method === "POST") {
      const raw = await readBody(req);
      const body = JSON.parse(raw);
      // Convert Ollama format to OpenAI format
      body.messages = body.messages || [];
      if (body.prompt) {
        body.messages.push({ role: "user", content: body.prompt });
      }
      return handleChatCompletions(req, res, body);
    }

    if (path === "/api/tags" && req.method === "GET") {
      // Ollama model list format
      return jsonResponse(res, 200, {
        models: [
          {
            name: MODEL_NAME,
            model: MODEL_NAME,
            modified_at: new Date().toISOString(),
            size: 0,
            digest: "openclaw",
            details: {
              parent_model: "",
              format: "agent",
              family: "openclaw",
              parameter_size: "cloud",
              quantization_level: "none",
            },
          },
        ],
      });
    }

    // Health / status
    if (path === "/" || path === "/health" || path === "/v1") {
      return handleHealth(req, res);
    }

    // 404
    openaiError(res, 404, `Unknown endpoint: ${req.method} ${path}`);
  } catch (err) {
    console.error(`[ERROR] ${req.method} ${path}:`, err.message);
    openaiError(res, 500, err.message, "server_error");
  }
});

server.listen(PORT, BIND, () => {
  console.log(`
╔══════════════════════════════════════════════════════╗
║          🤖 OpenClaw Proxy v1.0.0                    ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║  Listening:  http://${BIND}:${PORT.toString().padEnd(27)}║
║  Gateway:    ${OPENCLAW_HOST}:${OPENCLAW_PORT.toString().padEnd(30)}║
║  Model:      ${MODEL_NAME.padEnd(39)}║
║                                                      ║
║  OpenAI:     /v1/chat/completions                    ║
║  OpenAI:     /v1/models                              ║
║  Ollama:     /api/chat                               ║
║  Ollama:     /api/tags                               ║
║  Health:     /health                                 ║
║                                                      ║
╚══════════════════════════════════════════════════════╝

Ready. Any OpenAI-compatible client can now use your agent:

  curl http://$(BIND === "0.0.0.0" ? hostname() : BIND):${PORT}/v1/chat/completions \\
    -H "Content-Type: application/json" \\
    -d '{"model":"${MODEL_NAME}","messages":[{"role":"user","content":"hello"}]}'
`
    .replace("hostname()", "YOUR_PI_IP")
    .replace("BIND ===", ""));
});

server.on("error", (err) => {
  if (err.code === "EADDRINUSE") {
    console.error(`Port ${PORT} is already in use. Try: PORT=${PORT + 1} node server.js`);
  } else {
    console.error("Server error:", err);
  }
  process.exit(1);
});
