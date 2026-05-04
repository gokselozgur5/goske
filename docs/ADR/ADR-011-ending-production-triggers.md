# ADR-011: Ending production triggers (when does a run actually end?)

## Decision
A run ends automatically when any of these conditions hits, in order
of precedence:
1. All woken alters are silenced (Dragonrot total — the jar closed)
2. `days_alone >= 30` (isolation extreme)
3. `mystery_phase == "late"` AND any of: `days_alone >= 7`, `comfort_exits >= 15`, `silenced_alters.size() >= 2`
4. Any unlocked alter's trust >= 92 or <= 8 (commitment moment)

`/ending` stays as a debug-only manual trigger. Production fires once,
guarded by `ending_shown` flag.

## Intent (manifesto tie-in)
Manifesto: "no canonical run, no repeatable truth" — but a run still has
to STOP somewhere. The endings system is meaningless if it never fires
or if it fires arbitrarily. These triggers each correspond to a thematic
limit: the jar closed, isolation took, the mystery resolved, a trust
extreme made a commitment irreversible.

The conditions are NOT XP-style milestones; they're each a recognizable
narrative shape. Hitting trust 92 with red doesn't mean "win", it means
"the run has chosen its trajectory clearly enough that we should mark
it." Same with a 30-day isolation arc — that's already an ending, the
overlay just names it.

## Note to future-me
If the run ends "too early" or "too late":
- The numbers (30, 7, 15, 92, 8) are first-pass calibration. Tune by
  playing, not by theory. If runs end on turn 5 something's wrong.
- Multiple conditions stack — first match wins. Ordering matters: total
  Dragonrot is more decisive than late-phase wandering.
- `ending_shown` is a one-shot guard. If a run should be replayable
  without restart, you'd need a "reset_run" path that clears it.
- Side axes (npc_intensity, monotony) are NOT in the trigger conditions
  yet. They're allowed to be. Add as needed.

If you want a player-driven ending action (e.g., "stay 30s on the rest
carpet to commit"), add it as condition #5 and document it here.

## Considered, rejected
- Single trigger ("after N turns, ending fires") — arbitrary, not
  thematic.
- GM emits an "end_run" world_event itself — too much authority to
  the model; runs would end based on prose feel, not state.
- Player presses a button in UI — manifesto says no preset trees;
  same intuition for endings.

## Result (code-side)
- `game_state.gd`:
  - `ending_shown: bool` one-shot guard
  - `check_ending_trigger() -> String` returns a reason id or ""
- `conversation.gd`:
  - In `_on_gm_turn`, after applying world_events, calls the check
  - On a non-empty reason, calls `_trigger_ending_with_reason(reason)`
    which sets `ending_shown = true`, logs, and shows the overlay
- `/ending` debug command unchanged — bypasses the guard for testing
- Side axes (days_alone, comfort_exits, npc_intensity) NOT in the
  Voronoi partition itself; they're trigger conditions, not coordinates
