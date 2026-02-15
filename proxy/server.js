#!/usr/bin/env node
/**
 * openclaw-proxy - OpenAI-compatible API server backed by an OpenClaw agent.
 *
 * Exposes /v1/chat/completions (OpenAI) and /api/chat (Ollama) endpoints
 * that route requests through the local OpenClaw Gateway. Any client that
 * speaks the OpenAI protocol can use the agent, including Open WebUI,
 * the Python openai SDK, curl, and Ollama-compatible tools.
 *
 * The key difference from a raw LLM endpoint: this has an agent behind it
 * with browser access, shell access, and tools. It can act, not just talk.
 *
 * Environment:
 *   PORT            Listen port (default: 11435)
 *   BIND            Bind address (default: 0.0.0.0)
 *   OPENCLAW_HOST   Gateway host (default: 127.0.0.1)
 *   OPENCLAW_PORT   Gateway port (default: 18800)
 *   OPENCLAW_TOKEN  Gateway auth token (optional)
 *   MODEL_NAME      Model name exposed to clients (default: openclaw-agent)
 */

import { createServer } from "node:http";
import { randomUUID } from "node:crypto";

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const PORT = parseInt(process.env.PORT || "11435", 10);
const BIND = process.env.BIND || "0.0.0.0";
const OPENCLAW_HOST = process.env.OPENCLAW_HOST || "127.0.0.1";
const OPENCLAW_PORT = parseInt(process.env.OPENCLAW_PORT || "18800", 10);
const OPENCLAW_TOKEN = process.env.OPENCLAW_TOKEN || "";
const MODEL_NAME = process.env.MODEL_NAME || "openclaw-agent";
const MAX_BODY = 1024 * 1024; // 1MB request body limit

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function jsonResponse(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, { "Content-Type": "application/json", ...CORS_HEADERS });
  res.end(body);
}

function sseChunk(res, data) {
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

function openaiError(res, status, message, type = "invalid_request_error") {
  jsonResponse(res, status, {
    error: { message, type, param: null, code: null },
  });
}

/**
 * Read the full request body, enforcing MAX_BODY size.
 * Rejects if the body exceeds the limit.
 */
function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY) {
        reject(new Error("Request body too large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString()));
    req.on("error", reject);
  });
}

// ---------------------------------------------------------------------------
// OpenClaw Gateway client
// ---------------------------------------------------------------------------

/**
 * Send a message to the OpenClaw Gateway and wait for a reply.
 * Uses the sessions/send endpoint which creates or reuses a labeled session.
 */
async function sendToGateway(message, sessionLabel) {
  const url = `http://${OPENCLAW_HOST}:${OPENCLAW_PORT}/api/sessions/send`;
  const headers = { "Content-Type": "application/json" };
  if (OPENCLAW_TOKEN) {
    headers["Authorization"] = `Bearer ${OPENCLAW_TOKEN}`;
  }

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

// ---------------------------------------------------------------------------
// Message formatting
// ---------------------------------------------------------------------------

/**
 * Convert an OpenAI-style messages array into a single text prompt
 * suitable for the Gateway session. System messages become bracketed
 * context; user and assistant messages are preserved as conversation.
 */
function formatMessages(messages) {
  if (!Array.isArray(messages)) return String(messages);

  return messages
    .map((msg) => {
      const role = msg.role || "user";

      // Handle multimodal content arrays (text parts only).
      const content =
        typeof msg.content === "string"
          ? msg.content
          : Array.isArray(msg.content)
            ? msg.content
                .filter((p) => p.type === "text")
                .map((p) => p.text)
                .join("\n")
            : JSON.stringify(msg.content);

      if (role === "system") return `[System] ${content}`;
      if (role === "assistant") return `[Assistant] ${content}`;
      return content;
    })
    .join("\n\n");
}

// ---------------------------------------------------------------------------
// Route handlers
// ---------------------------------------------------------------------------

/**
 * POST /v1/chat/completions
 *
 * Implements the OpenAI chat completions API. Supports both streaming
 * (SSE) and non-streaming responses. The model field is accepted but
 * ignored since all requests route to the same OpenClaw agent.
 */
async function handleChatCompletions(req, res, body) {
  const { messages, stream, model } = body;

  if (!messages || !Array.isArray(messages)) {
    return openaiError(res, 400, "messages is required and must be an array");
  }

  const prompt = formatMessages(messages);
  const requestId = `chatcmpl-${randomUUID().replace(/-/g, "").slice(0, 29)}`;
  const sessionLabel = body.user || `proxy-${model || MODEL_NAME}`;
  const created = Math.floor(Date.now() / 1000);

  if (stream) {
    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
      ...CORS_HEADERS,
    });

    try {
      const reply = await sendToGateway(prompt, sessionLabel);

      // Chunk the reply into small pieces to simulate token-by-token streaming.
      const chunkSize = 4;
      for (let i = 0; i < reply.length; i += chunkSize) {
        sseChunk(res, {
          id: requestId,
          object: "chat.completion.chunk",
          created,
          model: model || MODEL_NAME,
          choices: [{ index: 0, delta: { content: reply.slice(i, i + chunkSize) }, finish_reason: null }],
        });
      }

      // Send the final chunk with finish_reason.
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
        choices: [{ index: 0, delta: { content: `Error: ${err.message}` }, finish_reason: "stop" }],
      });
      res.write("data: [DONE]\n\n");
    }
    res.end();
    return;
  }

  // Non-streaming: wait for the full reply, return as a single object.
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

/**
 * GET /v1/models
 * Returns the list of available "models" (just the agent name).
 */
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
    ],
  });
}

/**
 * GET /api/tags
 * Ollama-compatible model listing.
 */
function handleOllamaTags(req, res) {
  jsonResponse(res, 200, {
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

/**
 * GET /health
 * Basic health check with uptime and gateway info.
 */
function handleHealth(req, res) {
  jsonResponse(res, 200, {
    status: "ok",
    version: "1.0.0",
    gateway: `${OPENCLAW_HOST}:${OPENCLAW_PORT}`,
    model: MODEL_NAME,
    uptime: process.uptime(),
  });
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname;

  // CORS preflight
  if (req.method === "OPTIONS") {
    res.writeHead(204, CORS_HEADERS);
    return res.end();
  }

  try {
    // OpenAI-compatible endpoints
    if (path === "/v1/chat/completions" && req.method === "POST") {
      const raw = await readBody(req);
      return handleChatCompletions(req, res, JSON.parse(raw));
    }

    if (path === "/v1/models" && req.method === "GET") {
      return handleModels(req, res);
    }

    // Ollama-compatible endpoints
    if (path === "/api/chat" && req.method === "POST") {
      const raw = await readBody(req);
      const body = JSON.parse(raw);
      // Normalize Ollama format: move prompt into messages if needed.
      if (!body.messages) body.messages = [];
      if (body.prompt) {
        body.messages.push({ role: "user", content: body.prompt });
      }
      return handleChatCompletions(req, res, body);
    }

    if (path === "/api/tags" && req.method === "GET") {
      return handleOllamaTags(req, res);
    }

    // Health check
    if (path === "/" || path === "/health" || path === "/v1") {
      return handleHealth(req, res);
    }

    openaiError(res, 404, `Unknown endpoint: ${req.method} ${path}`);
  } catch (err) {
    console.error(`[ERROR] ${req.method} ${path}:`, err.message);
    openaiError(res, 500, err.message, "server_error");
  }
});

server.listen(PORT, BIND, () => {
  const addr = BIND === "0.0.0.0" ? "all interfaces" : BIND;
  console.log(`openclaw-proxy v1.0.0`);
  console.log(`  Listening on ${addr}, port ${PORT}`);
  console.log(`  Gateway:     ${OPENCLAW_HOST}:${OPENCLAW_PORT}`);
  console.log(`  Model:       ${MODEL_NAME}`);
  console.log(`  Endpoints:   /v1/chat/completions, /v1/models, /api/chat, /api/tags, /health`);
  console.log(``);
});

server.on("error", (err) => {
  if (err.code === "EADDRINUSE") {
    console.error(`Port ${PORT} already in use. Try: PORT=${PORT + 1} node server.js`);
  } else {
    console.error("Server error:", err);
  }
  process.exit(1);
});
