# ADR-003: Sealed pod allowlist enforcement (system prompt + client-side defense)

## Decision
Two-layer enforcement so locked or silenced alters never speak:
1. The GM system prompt only advertises the active roster (unlocked + not-silenced + narrator) and includes an explicit ACTIVE SPEAKER ALLOWLIST section.
2. `conversation.gd._on_gm_turn` defensively drops any speaker the GM emits whose id isn't allowed (logged to console).

## Intent (manifesto tie-in)
Pod opening is the player's first big choice (open one, two, three, or none). That choice has to actually MATTER — a sealed alter speaking through the wall would dissolve the agency. Manifesto: "no fake freedom that collapses into one route."

## Note to future-me
If you find a sealed alter talking and you're tempted to relax the allowlist:
- Don't. The choice of which pods to open is structural, not flavor.
- The first version listed all PERSONAS in the system prompt. The GM happily impersonated locked alters.
- Adding the "ACTIVE SPEAKER ALLOWLIST" line to the system prompt fixed ~95% of cases.
- Adding the client-side drop catches the remaining 5% (LLMs hallucinate ids occasionally).
- Logged to console so you notice when the GM tries — useful telemetry.

## Considered, rejected
- Trust-on-prompt-only — relied on LLM compliance, leaked occasionally.
- Strip locked alters from the entire prompt and rely on absence — works, but if the GM ever sees them in conversation history (multi-pod runs after closing/reopening) it confuses. Better to be explicit.

## Result (code-side)
- `game_master.gd._build_system_prompt`:
  - Iterates `personas_node.PERSONAS` but skips alters not in `unlocked_alters` (narrator always included).
  - Skips silenced alters too.
  - Appends an ACTIVE SPEAKER ALLOWLIST line listing exactly which ids may appear in `speakers`.
- `conversation.gd._on_gm_turn`:
  - For each speaker, checks `gs.is_unlocked(sid)` and `not gs.is_silenced(sid)`.
  - Drops + logs if violated.
- Narrator bypasses the allowlist (always allowed).
