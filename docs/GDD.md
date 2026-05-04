# Goske — Game Design Document

> One-pager. The manifesto sets the vision; this sets the shape.

## Premise

A 2.5D isometric, AI-driven, narrative game. Goske wakes in an unfamiliar pod. Around him: twelve more pods, three of which contain other versions of himself. Beyond the pod room: three neighbors at the edge of his world, behind glass. The player chooses which versions to wake, talks to them in free text, and lives with the consequences.

## Core fantasy (one sentence)

*"You wake up surrounded by versions of yourself, and the only way out is through the way they refuse to agree on who you are."*

## Theme

Alienation as a structural reality, not a stat. The jar metaphor: even when surrounded, even when functioning, even when warm, Goske is behind glass. Camus's Meursault was depressed-affect alienation — Goske is hyperaware-affect alienation. Inspirations: *L'Étranger* (anti-thesis), *Beau Is Afraid* (the flat as pressure cooker), *Disco Elysium* (skill voices, narrator), *Sekiro* (Dragonrot infection mechanic), *The Alters* (multiple selves).

## Pillars (from manifesto)

1. **Trust** — alters earn or lose it through what's said.
2. **Interpretation** — every situation has more than one valid read.
3. **Presence** — where Goske stands, what he looks at, how long he stays, all matter.
4. **Memory drift** — events don't replay identically; alters and Goske remember differently.
5. **Conversational action** — speech is action. A line can calm, mislead, close a path.

## Player loop (current vertical slice)

```
spawn → look around →
  open pod(s) → wake alter(s) → conversation begins →
  type freely → GM dispatches multi-speaker turn →
  trust shifts, exhaustion accrues, narrator weaves atmosphere →
  optionally rest at carpet (clears exhaustion, advances days_alone) →
  conversation deepens, jar metaphor surfaces →
  (eventual) ending shaped by R/G/B trust + days_alone + comfort_exits + npc_intensity
```

## Camera & control

- 2.5D isometric (Disco Elysium / Citizen Sleeper damar)
- Goske moves with arrow keys
- Pods open with Space when in range
- Conversation is free text; Enter sends
- ESC closes the conversation panel (history persists)
- `/reset` clears history and trust (escape hatch for safety-loop or test)

## Cast (vertical slice)

- **Goske (player)** — software developer, "hybrid", on the inside of the jar.
- **Red alter** — angry, honest, unfiltered. Says what Goske avoids saying.
- **Blue alter** — analytical, cold, numeric. Speaks in ratios.
- **Green alter** — hopeful, naive, censored-positive view. Easy to manipulate.
- **Narrator** — voice of the game, BG3+Disco Elysium tone, second-person atmospheric.
- **Three neighbors** — visual, no spoken dialogue. They drain (Dragonrot) when exhaustion spreads.
- **Goske's "alone zone"** — the carpet at scene center.

## Mechanics summary

- **Pod opening** — choose how many alters to wake (sealed alters never speak; see ADR-003).
- **Multi-alter free-text dialogue** — single Game Master LLM dispatches multi-speaker JSON per turn (ADR-001).
- **Trust** — int 0–100 per alter, GM emits `trust_delta` per speaker.
- **Exhaustion** — int 0–100, +5 per alter line. ≥70 forces black mesh on Goske; ≥90 silences highest-trust alter (Sekiro Dragonrot).
- **Comfort zone** — yellow ring at origin radius 5; outside it, Goske flips to black mesh (mirrors exhaustion).
- **Rest** — stand on carpet + Space. Clears exhaustion, advances `days_alone` (ADR-005).
- **Mystery thread** — two layers, surface (pod) and deep (jar), GM-driven, never resolved in dialogue (ADR-006).
- **NPC infection** — `npc_affected` event drains a neighbor's color toward gray (ADR-004).
- **Asymmetric info access** — each alter sees a filtered subset of world state (red/blue full; green censored to neutral/positive).
- **Alone-time accumulation** — `days_alone` is visible to the GM; it ages alters' tone over runs.

## Endings (planned, Iter 4)

17 endings, partitioned in (red_trust, blue_trust, green_trust) 3D space using a Voronoi/k-means scheme (see Iter Stack memory). Asymmetric: (R,0,0) ≠ (0,0,B); each region carries its own theme, not just a numeric label. Threshold-based, not continuous. Side-axes: `days_alone`, `comfort_exits`, `npc_intensity`. Resolution belongs to the ending screen, not in-conversation dialogue.

## Out of scope (this slice)

- Multiple physical locations (home / work / metro)
- Saturation post-process for monotony
- Combat (Disco Elysium-style skill check encounters)
- NPC dialogue
- 4th-wall breaks
- Save/load

These live in the Iter Stack memory; they're real plans, not deferred fantasies.

## Tech

- Godot 4.6
- Anthropic Claude Haiku 4.5 (Game Master)
- Godotiq MCP (development assistance)
- Single LLM call per turn, max_tokens 2500, JSON-structured output
- Project layout: `scripts/`, `scenes/`, `addons/godotiq/`, `docs/`
- Secrets: `secrets.cfg` (gitignored) holds the Anthropic key

## Quality bar

- Every system either carries theme or is cut.
- "Density > volume" — short, sharp, repeatable beats over long unique content.
- Every mechanic that exists in conventional RPGs (mana, dialog wheels, quest markers) must justify itself thematically before entering. So far we've only re-used: trust, exhaustion (renamed thematically), text input.
