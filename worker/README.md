# Goske API proxy (Cloudflare Worker)

Sits between the web build of the game and Anthropic's Messages API.

Why this exists:
- Web export ships everything client-side. If the Anthropic key is in the browser, anyone hitting Network tab can steal it.
- Worker holds the key as a server-side secret. Game talks to Worker; Worker talks to Anthropic.
- Worker also enforces aggressive per-IP and global rate limits so a single bad actor or an enthusiastic CS friend can't drain the bill.

## One-time setup

```bash
# 1. Install Wrangler (Cloudflare Worker CLI)
npm install -g wrangler

# 2. Log in (opens browser, OAuth)
wrangler login

# 3. Create the KV namespace used for rate-limit counters
cd worker
wrangler kv namespace create RATE
# Copy the returned `id = "..."` into wrangler.toml

# 4. Set the Anthropic key as a secret (paste when prompted)
wrangler secret put ANTHROPIC_API_KEY

# 5. Deploy
wrangler deploy
```

After step 5 you get a URL like `https://goske-proxy.<account>.workers.dev`.

## Wire it into the game

In `secrets.cfg` (project root, gitignored):

```ini
[anthropic]
api_url = "https://goske-proxy.<account>.workers.dev"
api_key = ""   ; can be empty in proxy mode; Worker injects the real key
```

The game detects `api_url` and switches to proxy mode automatically.

## Rate limits (current)

Edit constants at the top of `src/index.js` and redeploy with `wrangler deploy`.

| Limit              | Default | Rationale                                  |
|--------------------|---------|--------------------------------------------|
| Per IP per hour    | 60      | One conversation turn per minute, bursty   |
| Per IP per day     | 200     | A determined player can finish a real run  |
| Global per day     | 5000    | Cap a single bad day at ~$5-15 on Haiku    |

Also enforced server-side (clients can't bypass):
- Model is forced to `claude-haiku-4-5-*` (no Sonnet/Opus billing surprises)
- `max_tokens` capped at 4000

## Local dev

For local dev `secrets.cfg` should keep `api_url` empty (or remove it) — the game falls back to direct Anthropic calls using the `api_key` field. Only the deployed web build needs the proxy.

## Cost ceiling

`5000 requests/day × ~$0.0015 avg (Haiku 4.5)` ≈ $7.50/day worst case.
Per IP: 200 requests × $0.0015 ≈ $0.30/player/day.

Tune lower if you're sharing the demo widely.
