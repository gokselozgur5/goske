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
| Talk to a pod / neighbor | walk into them — conversation opens automatically |
| Pick a reply | click one of the suggestions |
| Type freely | **F** (toggles your own input) |
| Send your line | **Enter** |
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
