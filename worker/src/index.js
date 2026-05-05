// Goske API proxy — Cloudflare Worker.
//
// Routes:
//   POST /              → Anthropic Messages (Game Master turns)
//   POST /tts           → ElevenLabs TTS (narrator voice, MP3 stream)
//
// Holds both keys as Worker secrets so they never ship to the browser.
// Enforces aggressive per-IP and global rate limits because the demo
// runs on Goksel's own billing — TTS is the expensive one.
//
// Required bindings (see wrangler.toml + setup steps in worker/README.md):
//   env.ANTHROPIC_API_KEY    (secret)
//   env.ELEVENLABS_API_KEY   (secret)
//   env.RATE                 (KV namespace, rate-limit counters)

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

const ELEVENLABS_URL_BASE = "https://api.elevenlabs.io/v1/text-to-speech";
const ELEVENLABS_VOICE_ID = "ZpZFluT2CT4qmjlNJEpu"; // narrator voice (Goksel's pick)
const ELEVENLABS_MODEL = "eleven_multilingual_v2";   // stable, dramatic; bump to v3 if available
const TTS_MAX_CHARS = 600;                            // server cap per request

// LLM rate limits (Anthropic)
const HOURLY_PER_IP = 60;
const DAILY_PER_IP = 200;
const DAILY_GLOBAL = 5000;

const ALLOWED_MODEL_PREFIX = "claude-haiku-4-5";
const MAX_TOKENS_CEILING = 4000;

// TTS rate limits (ElevenLabs is char-billed; aggressive on purpose)
const TTS_HOURLY_PER_IP = 30;     // 30 narrator lines per IP per hour
const TTS_DAILY_PER_IP = 80;
const TTS_DAILY_GLOBAL = 1500;    // ~150k chars/day cap; tier-up plan if hit

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }
    if (request.method !== "POST") {
      return jsonResponse({ error: "method not allowed" }, 405);
    }

    const url = new URL(request.url);
    if (url.pathname === "/tts") {
      return handleTTS(request, env, ctx);
    }
    return handleAnthropic(request, env, ctx);
  },
};

async function handleAnthropic(request, env, ctx) {
  if (!env.ANTHROPIC_API_KEY) {
    return jsonResponse({ error: "proxy not configured (missing anthropic key)" }, 503);
  }

  const ip = clientIP(request);
  const { hour, day } = timeWindows();

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

  if (typeof body.model !== "string" || !body.model.startsWith(ALLOWED_MODEL_PREFIX)) {
    body.model = "claude-haiku-4-5-20251001";
  }
  if (typeof body.max_tokens !== "number" || body.max_tokens > MAX_TOKENS_CEILING) {
    body.max_tokens = MAX_TOKENS_CEILING;
  }

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
}

async function handleTTS(request, env, ctx) {
  if (!env.ELEVENLABS_API_KEY) {
    return jsonResponse({ error: "tts not configured (missing elevenlabs key)" }, 503);
  }

  const ip = clientIP(request);
  const { hour, day } = timeWindows();

  const ipHourKey = `tts-h:${ip}:${hour}`;
  const ipDayKey = `tts-d:${ip}:${day}`;
  const globalDayKey = `tts-global-d:${day}`;

  const [ipHour, ipDay, globalDay] = await Promise.all([
    env.RATE.get(ipHourKey),
    env.RATE.get(ipDayKey),
    env.RATE.get(globalDayKey),
  ]);
  const ipHourN = parseInt(ipHour || "0", 10);
  const ipDayN = parseInt(ipDay || "0", 10);
  const globalDayN = parseInt(globalDay || "0", 10);

  if (ipHourN >= TTS_HOURLY_PER_IP) {
    return jsonResponse({ error: "tts rate limit: hourly cap" }, 429);
  }
  if (ipDayN >= TTS_DAILY_PER_IP) {
    return jsonResponse({ error: "tts rate limit: daily per-player cap" }, 429);
  }
  if (globalDayN >= TTS_DAILY_GLOBAL) {
    return jsonResponse({ error: "tts daily global cap reached, try tomorrow" }, 503);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "invalid json" }, 400);
  }

  let text = String(body.text || "").trim();
  if (text === "") {
    return jsonResponse({ error: "empty text" }, 400);
  }
  if (text.length > TTS_MAX_CHARS) {
    text = text.slice(0, TTS_MAX_CHARS);
  }

  // Optional per-request voice_id override (so the game can A/B voices
  // without a Worker redeploy). Falls back to the configured default.
  const voiceId = typeof body.voice_id === "string" && /^[a-zA-Z0-9]+$/.test(body.voice_id)
    ? body.voice_id
    : ELEVENLABS_VOICE_ID;

  ctx.waitUntil(
    Promise.all([
      env.RATE.put(ipHourKey, String(ipHourN + 1), { expirationTtl: 7200 }),
      env.RATE.put(ipDayKey, String(ipDayN + 1), { expirationTtl: 172800 }),
      env.RATE.put(globalDayKey, String(globalDayN + 1), { expirationTtl: 172800 }),
    ])
  );

  const ttsUrl = `${ELEVENLABS_URL_BASE}/${voiceId}?output_format=mp3_44100_64`;
  let upstream;
  try {
    upstream = await fetch(ttsUrl, {
      method: "POST",
      headers: {
        "xi-api-key": env.ELEVENLABS_API_KEY,
        "content-type": "application/json",
        "accept": "audio/mpeg",
      },
      body: JSON.stringify({
        text,
        model_id: ELEVENLABS_MODEL,
        voice_settings: {
          stability: 0.45,         // a bit dramatic, not flat
          similarity_boost: 0.75,
          style: 0.55,             // expressive narration
          use_speaker_boost: true,
        },
      }),
    });
  } catch (e) {
    return jsonResponse({ error: "tts upstream fetch failed", detail: String(e) }, 502);
  }

  if (!upstream.ok) {
    const errText = await upstream.text();
    return jsonResponse(
      { error: "tts upstream error", status: upstream.status, detail: errText.slice(0, 500) },
      502
    );
  }

  // Stream MP3 bytes straight back to the client.
  return new Response(upstream.body, {
    status: 200,
    headers: {
      "content-type": "audio/mpeg",
      "cache-control": "no-store",
      ...corsHeaders(),
    },
  });
}

function clientIP(request) {
  return request.headers.get("CF-Connecting-IP") || "unknown";
}

function timeWindows() {
  const now = new Date();
  const hour = now.toISOString().slice(0, 13);
  const day = hour.slice(0, 10);
  return { hour, day };
}

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
