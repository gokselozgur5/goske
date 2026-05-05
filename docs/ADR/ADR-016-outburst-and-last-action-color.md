# ADR-016: Goske outburst + last-action color (engine starts, GM colors)

## Decision
Two related additions that put the manifesto's "engine = body, LLM = mind" line into actual mechanics:

**Outburst on neighbor approach.**
- Approaching a neighbor (the existing once-per-run whisper trigger) now produces TWO speakers: `goske_outburst` (the unfiltered line that escapes Goske before they think) followed by `<npc_id>` (brief reaction).
- The GM is briefed with a randomized "self-mix" — current trust ± 30 per channel — and writes the outburst in the dominant channel's voice (high R = abrasive, high G = naive/tender, high B = cold/analytical, mixed = blended).
- Side effects on emit: `exhaustion += 15`, optional `npc_affected` emission, alter trust shift on the channel that "spoke through" Goske.

**`last_action` color on every interaction.**
- `GameState.record_action(label)` rolls a self-mix RGB (current trust ± 30, clamp 0..100) and stores `{label, color}` in `last_action`.
- Hooked from: pod opening (`unlock_alter`), rest (`rest()`), comfort exit (`record_comfort_exit`), alter approach (alter.gd `_on_body_entered`).
- Exposed via `world_state.last_action`. The GM is told to color the NEXT turn's speakers by this RGB — without naming it.
- Visible to the player as a top-left HUD label `<action> · R47  B62  G33`, tinted by the dominant channel.

## Intent (manifesto tie-in)
Manifesto: "engine is responsible for movement execution, pathfinding, animation state. LLM is responsible for interpretation, intention, language, social strategy."

We were running this implicitly — pod opens are mechanical, the GM responds in the next turn. The new layer makes it EXPLICIT: every engine-side action drops a colored stone in the GM's hand, and the GM colors the response. The result is that "doing a thing" and "having the alters react to that thing" are bound, and the binding is asymmetric — kanka's run trajectory tints the random nudge.

The outburst version of this is the most visible moment: kanka approached a neighbor with no scripted intention, but Goske said something. That something was decided by which voice was loudest in Goske's head right then. Camus's Meursault never had a moment like this. Goske does.

## Note to future-me
If outbursts feel arbitrary:
- The anchor is `current trust`. If the player has run with red trust 80, outbursts skew red on average (with random escape rooms via the ±30 nudge). That's the design — not bug. If you want pure randomness, drop the anchor.
- The `±30` window can flex. Tighten to `±20` for less surprise; widen to `±50` for chaos.
- The GM is asked to attribute outbursts to channels for trust delta. Right now we apply the delta to "red" by default in `whisper.gd._on_gm_response`. If you want true attribution, parse a hint field (e.g. `voice_channel: "blue"`) from the speaker JSON.

If `last_action` colors don't visibly affect dialog:
- The GM may be ignoring it. The prompt says "don't name it; let it bleed". If voice tone feels uniform across action types, sharpen the prompt or rotate the example block.
- The HUD label is feedback for the player too — they can see if a "comfort_exit · R72" was followed by a sharp red alter line. If the prose doesn't change at all, the prompt is being ignored.

If exhaustion or trust shifts from outbursts feel wrong:
- Outburst exhaustion is a flat +15 (in `whisper.gd`). Trust shift comes from the GM's `trust_delta` field, applied to red by default. Both are tunable, both are first-pass.

## Considered, rejected
- **Pre-show RGB roll then ask kanka to "commit" or "abort"** — gives back agency, kills the "voice escaped" feeling. Whole point is that kanka DIDN'T choose.
- **Use raw random (no trust anchor)** — feels disconnected from the run. Hybrid is the manifesto-right answer (run trajectory exists, but doesn't fully determine).
- **Apply outburst trust deltas to all three alters proportionally** — split-attribution muddied the signal. Single-channel default is louder.
- **Hide the roll from the player** — first version did this; player asked "where is the dice?". The HUD label gives a glimpse without spelling out the full system.

## Result (code-side)
- `game_state.gd`:
  - `last_action: Dictionary` + `record_action(label)` + `action_recorded` signal
  - Hooks: `unlock_alter`, `rest()`, `record_comfort_exit()` all call `record_action` now
- `alter.gd`: `_on_body_entered` calls `gs.record_action("approached_<id>")` before opening conversation
- `whisper.gd`:
  - 2-speaker mode: `goske_outburst` + `<npc_id>` reaction
  - Random self-mix prompt to the GM
  - `_show_two_lines` does sequential reveal of outburst then reaction
  - `+15 exhaustion`, applies trust deltas (default to red), respects `npc_affected`
- `conversation.gd`: `_world_state` exposes `last_action`. `_on_action_recorded` updates the new HUD label.
- `game_master.gd`: system prompt has a `LAST ACTION FLAVOR` block telling the GM to color voices, and the outburst prompt explains the self-mix.
- `scenes/main.tscn`: `RollLabel` added under `DaysAloneLabel` in the top-left HUD.
