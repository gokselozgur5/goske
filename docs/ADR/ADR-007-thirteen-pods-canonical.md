# ADR-007: Thirteen pods, canonical (3 functional + 10 sealed)

## Decision
The room has exactly 13 pods. Three are functional (red, blue, green) — they open, the alters inside speak. The other ten are sealed decoratives — Node3D + meshes only, no script, no collision area, no interaction. The number 13 is canon and is told to the GM in the system prompt.

## Intent (manifesto tie-in)
Player chose the count (13). The visual mass matters: a single capsule looks like an episode setpiece; a forest of capsules makes the player FEEL the scope of the question (which versions of me exist? how many got me here?). Density over volume — but the visual density is part of the density.

Three functional alters keep the dialogue scope bounded (no 13-way conversations to manage). Ten sealed pods are mystery surface — the GM riffs on them ("the twelve don't move", "the fourth pod's occupant doesn't breathe").

## Note to future-me
If you're tempted to make sealed pods openable later:
- They're load-bearing as MYSTERY props. Once you can open them, they become inventory.
- Adding personas for 10 more alters is real writing work — that's where the cost is, not the code.
- One scripted "anomaly pod" (e.g., the dark fourth) could open as a one-time story moment without making all 10 mechanically interactive. Save for an Iter 3+ event.

If you increase the count beyond 13:
- Update the GM system prompt's canon line — the count is hard-coded there.
- Update neighbor count if you add NPCs too — same canon-discipline applies.

If the GM ever invents a different count ("fifteen pods", "five sealed"):
- That's a prompt failure. Sharpen the canon block. We've seen the GM hold this number cleanly so far ("the twelve don't move" was emergent and correct).

## Considered, rejected
- 3 pods only — too sparse, mystery felt thin.
- 5–7 pods — felt arbitrary, no thematic weight.
- 13+ all openable — explosion of writing scope, persona drift across 13 voices unmanageable.

## Result (code-side)
- `scenes/main.tscn`:
  - PodRed/PodBlue/PodGreen — full Pod (Area3D + script + alter linkage).
  - DecorPod1..DecorPod10 — Node3D root, Base+Lid MeshInstance3D, no Area3D, no script.
- `game_master.gd` system prompt: explicit "exactly THIRTEEN pods", names the three functional, calls the rest sealed/silent. "Don't invent a different count."
- `pod.gd` is unchanged for the sealed ones; they don't reference it.
