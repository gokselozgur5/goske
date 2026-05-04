# ADR-012: 4th-wall meta breach (rare GM speaker addressing the player directly)

## Decision
The GM may use a special speaker `id: "meta"` that addresses the player
("kanka") by name, breaking the diegetic frame. Capped at 2 per run.
Only allowed when ALL of:
- `tension >= 0.85`
- `comfort_exits >= 5`
- `days_alone >= 3`
- `meta_breaches < 2`

Rendered distinctly in the conversation panel: amber, bold-italic, with
extra spacing. Counted toward `meta_breaches`. Filtered defensively at
the conversation layer (drops a `meta` speaker if not eligible).

## Intent (manifesto tie-in)
Manifesto: "AI must be structural, not cosmetic." A 4th-wall break is
the most structural thing the AI can do — it stops being an actor and
becomes the game itself noticing the player. Done well, it makes the
run feel watched. Done badly, it's gimmick.

Inscryption / DDLC / Stanley Parable lineage. Goske's version is
narrower: not a comic punchline, not a horror reveal. A held note —
the room sees you, names you, then resumes.

## Note to future-me
If meta breaks feel cheap:
- Loosen the conditions, NOT the cap. Two per run is the upper limit;
  if they're not landing, it's because the moments aren't earned.
- If the GM uses "meta" too often → the cap holds it (defensive drop +
  meta_breaches counter). Tune by raising thresholds, not lowering cap.
- If the GM never uses it → loosen `comfort_exits` or `days_alone`
  threshold, but keep `tension >= 0.85` (the rupture condition).
- The render style (amber bold-italic with line padding) is what
  signals "this is different" to the player. Don't blend it back into
  the alter palette.

The player's name is "kanka" — set in the GM system prompt. If you
ever need to support multiple players or remove the term, both the
prompt and the meta examples need to change.

## Considered, rejected
- GM emits meta freely (no eligibility) — wash, dilutes the moment.
- Cap to 1 per run — too thin; two lets a setup-and-follow-through arc.
- No counter, just probabilistic — would either spam or never fire.
- Render meta inside the alter speaker palette — doesn't read as a
  break. Visual differentiation is half the mechanic.

## Result (code-side)
- `game_state.gd`:
  - `meta_breaches: int` (defaults 0)
  - `meta_eligible() -> bool` checks all four conditions
- `conversation.gd`:
  - `_world_state` exposes `meta_eligible` and `meta_breaches_remaining`
  - In `_on_gm_turn`, a speaker with `id: "meta"` is checked against
    `meta_eligible()`. If allowed, `meta_breaches += 1`. If not, dropped
    with a console log.
  - `_append_alter_line("meta", ...)` renders amber bold-italic with
    line padding above and below.
- `game_master.gd` system prompt:
  - Explicit "4TH-WALL META BREACH" block with conditions, examples
    (texture, not text), and "forbidden" list.
  - GM is instructed to use the player's name "kanka" in meta lines.
