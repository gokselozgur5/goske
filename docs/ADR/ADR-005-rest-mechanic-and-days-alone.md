# ADR-005: Rest mechanic + days_alone counter (BG3-style alone-time)

## Decision
There's a "rest zone" carpet at the room center. Standing on it and pressing Space spends a day alone: `exhaustion → 0`, `days_alone++`. The GM gets `days_alone` in world state and is told to color the dialog by it.

## Intent (manifesto tie-in)
Player's idea, manifesto-aligned: alienation is a two-sided pressure.
- Social presence costs (exhaustion / Sekiro Dragonrot — see ADR around silencing).
- Isolation also costs (alters drift, neighbors fade, the world stales).

Without the rest mechanic, the only valve was the passive recovery during idle movement — you could sit still in the comfort circle and wait it out. That's not a CHOICE, it's an absence. Rest makes alone-time an explicit player decision with consequences.

## Note to future-me
If you wonder why we didn't just auto-heal exhaustion:
- Auto-heal is anti-manifesto: convention without thematic payload.
- Rest as a deliberate action makes the player FEEL the trade-off.
- BG3 long rest is the analogy: cheap to think about, the player intuits trade-offs ("if I rest, time passes and the world might shift").
- `days_alone` is the second-order effect — it makes isolation accumulate and become legible to the GM. Without it, rest would be a free reset.

If you wonder why no visual "1 day passes" fade/cinematic:
- Polish round, not Iter 1. The history line is enough for now.

## Considered, rejected
- Auto-heal exhaustion over time only (no rest action) — was the original behavior; passive, no choice.
- Sleep menu like BG3 (camp screen, party events) — overkill for a 1-character game and adds modal UI complexity.
- Per-pod rest zones (rest in the alter you trust most) — interesting but blurs the "alone" axis. Save for a later design pass.

## Result (code-side)
- `scripts/rest_zone.gd`: Area3D with body_entered + Space input → calls `gs.rest()`.
- `scenes/main.tscn`: RestZone node at origin (the spawn carpet).
- `game_state.gd`:
  - `days_alone: int`
  - `rest()` clears exhaustion + recovery accumulator, increments counter, emits `day_passed`.
  - `_recovery_accumulator` reset to avoid float drift after rest.
- `conversation.gd`:
  - Listens to `day_passed`, inserts a narrator-styled "— a day passes alone (total: N) —" line into history (so it's persistent and the GM sees it next turn).
  - `_world_state` exposes `days_alone`.
- `game_master.gd` system prompt: instructs the GM to use `days_alone` to color dialog (alters drift further, neighbors feel further, room stales).
