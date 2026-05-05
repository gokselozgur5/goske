# ADR-014: Drama escalation — tension + monotony as system pressure

## Decision
Two new floats live in `GameState` and feed the GM as world-state context, the conversation as mechanical effect, and the visual layer as atmosphere.

**Tension (0..1)** — drama escalation:
- GM emits `{type: "tension", level: 0..1}` when a moment escalates (vulnerability, push, "moment of truth"). When no event fires, decays 0.06/turn.
- Trust deltas are amplified: `roundi(delta * (1 + tension))`. At full rupture, trust shifts hit ~2x harder.
- GM is told: at >=0.6 fewer alter lines + more narrator beats; at >=0.85 rupture (drastic shifts feel earned, alters may lash/withhold/break). Don't name "tension" in dialog.

**Monotony (0..1)** — routine pressure:
- Auto-tracked by mechanics: +0.018 per response × speakers, +0.05 per rest, -0.04 per comfort_exit, -0.08 per whisper.
- Drives a global desaturation post-process (`environment.adjustment_saturation = 1.0 - monotony`). At 1.0, the world is grayscale.
- GM gets it as `world_state.monotony` and is told to color voices: low → noticing color/sound/texture; high → flat references, repetition.

Both are exposed in `_world_state` so the GM tints language without naming them.

## Intent (manifesto tie-in)
Manifesto: "tension comes from interpretation, trust, presence, and consequence rather than routine combat."

Tension is the manifesto's pressure axis without combat. We didn't want a Disco Elysium-style click-options stake either (ADR-013). So tension lives as a SCALAR the GM modulates and the system amplifies — drama you feel through pacing, prose density, and trust-shift weight, not through a UI bar.

Monotony is the player's idea: alienation is a two-sided pressure. Social presence costs (exhaustion → black mesh → silence). Isolation also costs (alters drift, neighbors fade, color drains). The saturation post-process makes the second cost legible without a stat readout.

Together: every turn nudges one or both axes. The run's TEXTURE follows from these nudges without us scripting beats.

## Note to future-me
If tension never fires:
- The GM prompt's emit conditions are written in prose ("when a moment escalates" etc). If the model is too cautious, tighten it: "at trust delta sums beyond ±5, emit tension >= 0.5". Numerical anchors usually unstick it.
- Tension decay is 0.06/turn. If you want longer-burning drama, drop to 0.03; if you want quicker resets, 0.10.

If monotony grays everything too fast / too slow:
- The constants in GameState (`MONOTONY_PER_RESPONSE`, etc.) are first-pass. Tune by playing.
- If grayscale ends the run feeling, you might want a floor on saturation (1.0 - clamp(m, 0, 0.85)). Right now full white-out is reachable.

If trust deltas feel weird (too big / too small):
- The amplifier is `(1 + tension)`. Max 2x at full rupture. If 2x is too violent, cap at 1.5x; if 2x is too tame, raise to (1 + 1.5 * tension) for 2.5x peak.
- GM must NOT see the multiplier — it works in deltas of -5..+5 and the system multiplies after.

If the player notices "tension" or "monotony" being named in dialog:
- Prompt failure. The names exist in world_state and should NEVER appear in alter speech. Sharpen the "don't name them" line.

## Considered, rejected
- Tension as a visible bar in the HUD — kills the felt-not-seen quality. Trust labels are already showing more than I'd like.
- Tension as an enum (calm/tense/rupture) — discrete states wash out mid-tones. Float gives prose a continuous knob.
- Monotony as a player-facing stat — diegetic only, no number readout. Saturation does the work.
- Combine tension + monotony into one "pressure" float — they're orthogonal (one rises with social heat, the other with routine), shouldn't be collapsed.

## Result (code-side)
- `game_state.gd`:
  - `tension: float`, `set_tension`, `decay_tension`, `tension_multiplier()`
  - `monotony: float`, `adjust_monotony`, MONOTONY constants
  - `tension_changed`, `monotony_changed` signals
- `scripts/world_environment_manager.gd`: hooks `monotony_changed` → sets `environment.adjustment_saturation = 1.0 - monotony`. Attached to the WorldEnvironment node.
- `conversation.gd`:
  - `_apply_world_event` handles `tension`, `monotony_delta` events
  - Trust delta amplified via `tension_multiplier()`
  - Auto-decays tension when GM doesn't emit a tension event that turn
  - Adjusts monotony per turn / per rest / per whisper / per comfort_exit
- `game_master.gd` system prompt:
  - World event list updated to include `tension` and (accepted) `monotony_delta`
  - Pacing block at >=0.6 / >=0.85 tension
  - Monotony coloring guidance (low/high voice texture)
