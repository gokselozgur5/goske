// Goske API proxy — Cloudflare Worker.
//
// Sits between the game (web build) and Anthropic. Holds the Anthropic key
// as a Worker secret so it never ships to the browser. Enforces aggressive
// per-IP and global rate limits because demo runs on Goksel's own billing.
//
// Required bindings (see wrangler.toml + setup steps in worker/README.md):
//   env.ANTHROPIC_API_KEY  (secret, set via `wrangler secret put`)
//   env.RATE               (KV namespace, for rate-limit counters)

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

// Aggressive defaults — Goksel pays the bill.
const HOURLY_PER_IP = 60;     // ~1 turn per minute, burst-tolerant
const DAILY_PER_IP = 200;     // a determined player can finish a run
const DAILY_GLOBAL = 5000;    // cap a single bad day

const ALLOWED_MODEL_PREFIX = "claude-haiku-4-5"; // refuse non-Haiku to bound cost
const MAX_TOKENS_CEILING = 4000;

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }
    if (request.method !== "POST") {
      return jsonResponse({ error: "method not allowed" }, 405);
    }

    if (!env.ANTHROPIC_API_KEY) {
      return jsonResponse({ error: "proxy not configured (missing key)" }, 503);
    }

    // Rate limit windows (UTC).
    const now = new Date();
    const hour = now.toISOString().slice(0, 13); // YYYY-MM-DDTHH
    const day = hour.slice(0, 10);
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";

    const ipHourKey = `ip-h:${ip}:${hour}`;
    const ipDayKey = `ip-d:${ip}:${day}`;
    const globalDayKey = `global-d:${day}`;

    const [ipHour, ipDay, globalDay] = await Promise.all([
      env.RATE.get(ipHourKey),
      env.RATE.get(ipDayKey),
      env.RATE.get(globalDayKey),
    ]);
    const ipHourN = parseInt(ipHour || "0", 10);
    const ipDayN = parseInt(ipDay || "0", 10);
    const globalDayN = parseInt(globalDay || "0", 10);

    if (ipHourN >= HOURLY_PER_IP) {
      return jsonResponse({ error: "rate limit: too many requests this hour" }, 429);
    }
    if (ipDayN >= DAILY_PER_IP) {
      return jsonResponse({ error: "rate limit: daily per-player cap reached" }, 429);
    }
    if (globalDayN >= DAILY_GLOBAL) {
      return jsonResponse({ error: "demo daily cap reached, try tomorrow" }, 503);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return jsonResponse({ error: "invalid json" }, 400);
    }

    // Hard guardrails on the request body so a clever client can't burn
    // credits with sonnet/opus or 8k tokens.
    if (typeof body.model !== "string" || !body.model.startsWith(ALLOWED_MODEL_PREFIX)) {
      body.model = "claude-haiku-4-5-20251001";
    }
    if (typeof body.max_tokens !== "number" || body.max_tokens > MAX_TOKENS_CEILING) {
      body.max_tokens = MAX_TOKENS_CEILING;
    }

    // Increment counters (best-effort; demo cap doesn't need atomicity).
    ctx.waitUntil(
      Promise.all([
        env.RATE.put(ipHourKey, String(ipHourN + 1), { expirationTtl: 7200 }),
        env.RATE.put(ipDayKey, String(ipDayN + 1), { expirationTtl: 172800 }),
        env.RATE.put(globalDayKey, String(globalDayN + 1), { expirationTtl: 172800 }),
      ])
    );

    let upstream;
    try {
      upstream = await fetch(ANTHROPIC_URL, {
        method: "POST",
        headers: {
          "x-api-key": env.ANTHROPIC_API_KEY,
          "anthropic-version": ANTHROPIC_VERSION,
          "content-type": "application/json",
        },
        body: JSON.stringify(body),
      });
    } catch (e) {
      return jsonResponse({ error: "upstream fetch failed", detail: String(e) }, 502);
    }

    const text = await upstream.text();
    return new Response(text, {
      status: upstream.status,
      headers: { "content-type": "application/json", ...corsHeaders() },
    });
  },
};

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "content-type, x-api-key, anthropic-version",
    "Access-Control-Max-Age": "86400",
  };
}

function jsonResponse(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json", ...corsHeaders() },
  });
}
