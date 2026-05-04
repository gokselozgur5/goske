# ADR-006: Mystery thread is two-layered (pod surface / jar deep)

## Decision
The system prompt carries one mystery thread with two stacked questions:
- SURFACE: "Who put me in this pod? What is this place? Are these clones real?"
- DEEPER (slow reveal): "Why is there glass between me and other people? Did I put it there?"

The GM is told these layers connect (the pod is the literal of the jar) and is given pacing guidance (early/mid/late turns). The thread is never resolved in dialogue — resolution belongs to the ending.

## Intent (manifesto tie-in)
Manifesto: "controlled ambiguity is a tool, not a flaw" + "no canonical run, no repeatable truth."
- Surface gives the player something concrete to grip on turn 1 (the pod is right there).
- Deeper gives the run weight — over time, conversations stop being about the pod and start being about who Goske is.
- Two layers means there's always something to surface; the player doesn't sit waiting for a single answer.

## Note to future-me
If the mystery feels stuck or one-note:
- Check the GM prompt's pacing block. It tells the GM to circle the deeper question only mid-late.
- The two layers are CONNECTED; if the GM names "the jar" in turn 1, that's a tone failure, not a content failure. Tweak pacing wording in the system prompt.
- Resolution doesn't happen in dialogue. The endings (Iter 4, RGB partition) embody the resolution. If you ever feel pressure to "answer" the mystery in-conversation, push back.

If you want to add a third layer:
- Don't crowd. Two is the right number for density-over-volume. Layer 3 could become a New-Game+ thing.

## Considered, rejected
- Single concrete mystery (just "who put me in this pod") — felt thin, exhausted in a few turns.
- Single abstract mystery (just "what is the jar") — abstract, no early grip.
- Three layers — too crowded for a vertical slice.

## Result (code-side)
- `scripts/game_master.gd` SYSTEM_BASE has a `--- MYSTERY THREAD ---` block with both layers, the connection, and pacing.
- No state machine for mystery progression yet — relies on GM judgment from `play_seconds`, `comfort_exits`, alter trust, days_alone. If we ever need explicit progress (Iter 3+), that's where it goes (`mystery_phase` in GameState).
