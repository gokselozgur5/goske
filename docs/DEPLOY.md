# Deploying Goske as a web demo

Two pieces ship:

1. **The Worker** — proxies game requests to Anthropic, holds the API key as a server secret, enforces rate limits. See [worker/README.md](../worker/README.md).
2. **The web build** — Godot HTML5 export, served from Cloudflare Pages.

The Worker must exist first because the web build needs its URL.

---

## 1. Deploy the Worker (one time)

Follow [worker/README.md](../worker/README.md). After step 5 you'll have a URL like:

```
https://goske-proxy.<account>.workers.dev
```

Copy that. You'll paste it into `secrets.cfg` next.

---

## 2. Configure proxy mode in the project

`secrets.cfg` (project root, gitignored) for the **demo build**:

```ini
[anthropic]
api_url = "https://goske-proxy.<account>.workers.dev"
api_key = ""
```

For local dev you can keep using your direct Anthropic key (omit `api_url`, paste `api_key`).

---

## 3. Install the Godot Web export template (one time)

Open the project in Godot Editor.

**Editor → Manage Export Templates → Download and Install**

Pick the matching version (4.6.x stable). This downloads ~250MB of templates including Web. After install, the "Web" preset in `export_presets.cfg` is runnable.

---

## 4. Build

From the project root:

```bash
bash scripts/build_web.sh
```

This runs `godot --headless --export-release "Web" web/index.html` and copies `public/_headers` into `web/`. Output goes to `web/`.

If `godot` isn't on PATH, the script will fail — set up an alias or use the full path. For a quick check:

```bash
which godot      # /opt/homebrew/bin/godot or similar
godot --version  # 4.6.x.stable
```

---

## 5. Deploy to Cloudflare Pages

You only need to do the project create step once.

```bash
# One-time: create the Pages project (interactive — pick "Direct upload")
wrangler pages project create goske --production-branch=main

# Every deploy:
wrangler pages deploy web --project-name=goske
```

Wrangler returns a deploy URL like:

```
https://<hash>.goske.pages.dev   (preview)
https://goske.pages.dev          (production, after first deploy)
```

That production URL is what you share with the CS/EEE friends.

---

## 6. Smoke-test the demo

1. Open `https://goske.pages.dev` in a private/incognito window (so cached state doesn't fool you).
2. Title screen → press a key → main scene.
3. Walk to a pod, press E. The first conversation turn proves the Worker chain is live.
4. If you see a long pause then nothing, open DevTools → Network and check the request to your Worker URL. 4xx/5xx means rate-limit or upstream issue; the Worker README has the response shape.

---

## 7. Updating the demo

Change code → repeat steps 4 and 5:

```bash
bash scripts/build_web.sh
wrangler pages deploy web --project-name=goske
```

Worker only needs redeploy if you edited `worker/src/index.js`:

```bash
cd worker && wrangler deploy
```

---

## Cost / abuse notes

- Worker rate limits are aggressive on purpose (see `worker/src/index.js` constants). The bill is on Goksel's Anthropic account.
- Anyone with the Pages URL can play. There's no auth. If a determined abuser shows up, tighten `HOURLY_PER_IP` and `DAILY_GLOBAL` in the Worker, or move to email-gate / passcode.
- Cloudflare Pages free tier: 500 builds/month, unlimited requests. Won't be the bottleneck.
- If you blow the daily Anthropic cap mid-demo, the Worker returns 503 with `"demo daily cap reached, try tomorrow"`. The game shows that as a turn error.

---

## Troubleshooting

**"Godot Web export template not found"** — step 3 wasn't done.

**CORS error in browser console** — Worker isn't returning the right headers, or you forgot to flip `api_url` to the Worker URL and the game is calling Anthropic directly (which CORS-rejects browser origins).

**429 every turn** — your IP hit `HOURLY_PER_IP=60`. Either you're playing very fast or another player on your network triggered the limit. Wait the hour or raise the cap.

**`page.goske.pages.dev` shows "Site Not Found"** — first deploy hasn't propagated, or you used `--branch=preview` instead of production. Check `wrangler pages deployment list --project-name=goske`.

**Game loads but no conversations work** — Worker URL typo in `secrets.cfg`, or `wrangler secret put ANTHROPIC_API_KEY` was skipped. Check the Worker Tail in Cloudflare dashboard:

```bash
cd worker && wrangler tail
```

Then play a turn and watch the live log.
