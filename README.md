# Goske

A 2.5D isometric, AI-driven, narrative prototype.

Goske is a consciousness. Inside there are different voices; outside, a distant world. The player writes freely; the voices respond, a narrator weaves the atmosphere. Trust, exhaustion, silence — all shaped within the conversation itself. Each run follows its own trajectory.

## Play in browser

**▶ [gokselozgur.itch.io/goske](https://gokselozgur.itch.io/goske)**

No install. Click "Run game" on the page. Bring headphones if you have them.

### Controls

| Action | Key |
|---|---|
| Move | **W A S D** (or arrow keys) |
| Dash | **Space** |
| Open a pod / interact | **E** when in range |
| Pick a reply | click one of the suggestions |
| Type freely | **F** (toggles your own input) |
| Send your line | **Enter** |
| Skip narrator voice | **N** |
| Close conversation | **Esc** |
| Restart after ending | **Enter** |

There's no jump, no combat, no inventory. The whole game is movement + conversation.

## Stack

- Godot 4
- Anthropic Claude (one "Game Master" LLM handles all characters)
- Godotiq MCP (development)

## Run locally

Create `secrets.cfg` at project root (gitignored):

```
[anthropic]
api_key = "sk-ant-..."
```

Open with Godot 4 → run (Cmd+R / F5).

For deploying your own demo (Cloudflare Worker proxy + web export + Pages/Itch), see [docs/DEPLOY.md](docs/DEPLOY.md).

## Status

Prototype. Mechanic skeleton in place, content writing ongoing.

## License

**All Rights Reserved.** The source is published here for transparency and portfolio display only — see [LICENSE](LICENSE) for the full terms.

You are free to read and study the code. You are **not** free to copy, modify, redistribute, host, fork, or otherwise reuse it (including for "non-commercial" projects) without prior written permission.

Third-party assets (3D models, audio, fonts) carry their own licenses — see [assets/sketchfab/CREDITS.md](assets/sketchfab/CREDITS.md).

For licensing inquiries: <g.ozgur@archangelautonomy.com>
