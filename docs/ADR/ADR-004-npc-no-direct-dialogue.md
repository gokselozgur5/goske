# ADR-004: NPCs (neighbors) have no direct spoken dialogue

## Decision
The three neighbor capsules (neighbor_1/2/3) are visible in the scene but cannot be conversed with. They never appear in the GM's `speakers` array. The only way they enter mechanics is the `npc_affected` world_event, which drains their visual color toward gray (Dragonrot infection).

## Intent (manifesto tie-in)
Goske's alienation is the jar metaphor — people on the other side of the glass are unreachable. The moment a neighbor opens their mouth and speaks back, the jar is gone. The thematic core dies. Manifesto: alienation is structural, not a stat.

The alter system gives the player rich dialogue. The NPC system gives them a visual reminder of who they CANNOT speak to. Both are needed for the theme to land.

## Note to future-me
If you're tempted to add NPC dialogue ("just one line each, it'd feel more alive"):
- Read the manifesto's "Working Premise" and "Outside there are people" passage.
- The whole point is that Goske CAN'T reach them. Letting him reach them is the equivalent of giving Meursault a happy ending — it solves the wrong problem.
- A future "endgame moment" could break this as a one-time dramatic event (jar cracking) — that's fine, it'd be RARE and EARNED. But it shouldn't be a normal mechanic.
- If you want richer NPC presence, add: visual states (asleep, gone, stilled), narrator references ("the woman in 5B hasn't waved this week"), npc_affected drains. Not dialogue.

## Considered, rejected
- Standard dialog (Pod/Alter pattern) — kills the theme. Vetoed early.
- Hybrid "memory scene": NPC speaks one line as a flashback. Saved for an Iter 2/3 design pass — not built yet, but it's the right loophole if we want any NPC voice.
- One-time endgame "jar crack" dialogue — kept on the design backlog, not implemented.

## Result (code-side)
- `scripts/npc.gd`: Node3D with `set_intensity(0..1)` that lerps the mesh color toward gray.
- `scenes/main.tscn`: Neighbor1/2/3 nodes at scene edges (outside comfort radius).
- `game_state.gd`: `npc_intensity` dict + `update_npc_intensity` (max-wins; Dragonrot accumulates).
- `conversation.gd._apply_world_event "npc_affected"`: pushes intensity to the matching npc node + records in state.
- `game_master.gd` system prompt: explicit "NO spoken dialogue, don't put them in speakers, only npc_affected mechanic."
