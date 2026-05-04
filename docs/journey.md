# Player journey — current vertical slice

> What a single run looks like, end-to-end. Lives next to the GDD; this is the flow, that's the shape.

## State / event flow

```mermaid
flowchart TD
  Spawn[Goske spawns at origin\non rest carpet, comfort circle] --> Look[Player looks around\n— 13 pods + 3 neighbors visible]

  Look --> Choice{Open which pods?}
  Choice -->|none yet| Wander[Wander, exit comfort,\nreturn to carpet, etc.]
  Wander --> Choice
  Choice -->|approach pod + Space| Open[Pod opens\nlid tweens up\nalter rises]

  Open --> Awaken[Awakening request\nNO prior history sent]
  Awaken --> Convo[Conversation opens\nalter delivers fresh first line]

  Convo --> Type[Player types freely]
  Type --> GMTurn[GM single LLM call\n→ multi-speaker JSON]
  GMTurn --> Apply[Apply: history append\ntrust deltas\nexhaustion accrual\nworld_events]
  Apply --> Drift[Material/UI updates\nTrust labels\nExhaustion HUD\nNeighbor color drain]
  Drift --> Continue{Continue?}

  Continue -->|type more| Type
  Continue -->|ESC| Closed[Convo closed\nhistory persists]
  Continue -->|approach new pod + Space| AnotherPod[Open another pod\n→ that alter joins\nhistory persists]
  AnotherPod --> Convo

  Closed --> Restable{Stand on carpet?}
  Restable -->|Space on carpet| Rest[Rest action\nexhaustion → 0\ndays_alone++\nhistory gets day marker]
  Rest --> Continue

  Continue -->|exhaustion ≥ 70| Black[Goske mesh → black\nauto, regardless of comfort]
  Black --> Continue
  Continue -->|exhaustion ≥ 90| Silence[Top-trust alter silenced\nback in pod, drops out]
  Silence --> Continue

  Continue -->|"/reset" typed| Reset[History cleared\ntrust → 50\ngreeted_alters cleared]
  Reset --> Type
```

## Pressure axes

Two opposite costs press on the player:

- **Social presence cost** → exhaustion goes up, room dims, alters silence themselves.
- **Isolation cost** → days_alone goes up, alters drift, neighbors fade further.

Neither side is "the safe one". Optimal play is calibrated tension.

## Hidden axes the GM sees

Every turn the GM gets:

- `trust` per alter
- `exhaustion`
- `unlocked_alters`, `silenced_alters`
- `comfort_exits` (how often Goske left the yellow circle)
- `play_seconds`
- `npc_intensity` per neighbor
- `days_alone`

Plus the canon facts (13 pods, 3 functional, 10 sealed, 3 neighbors) and the mystery thread block. The GM uses these to pace the dialog, decide who speaks, and emit world events.

## Out-of-band escape hatches

- `/reset` — wipes history, trust, greeted_alters. Sole purpose: rescue stuck-in-safety-loop runs (when the LLM has anchored on a refusal and won't move). Not a player-facing mechanic; the player can use it but it's primarily a dev tool.
- `ESC` — closes panel without losing state. Resume by approaching any unlocked alter or its pod.

## What the slice does NOT cover (yet)

- Endings (planned Iter 4, RGB Voronoi)
- Multiple physical contexts (home / work / metro)
- NPC dialogue (intentionally absent — see ADR-004)
- Combat / skill check encounters
- Save/load
