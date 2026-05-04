# ADR-001: Single Game Master (over per-alter parallel calls)

## Decision
One LLM call per turn handles every alter. We do NOT fire parallel API calls per alter.

## Intent (manifesto tie-in)
"AI must be structural, not cosmetic." A single coherent mind makes inter-alter inconsistency impossible. The GM is the dramatic director — who speaks, what happens in the world, decided in one place. Per-alter parallel was cosmetic: each alter spoke without knowing the others, and tone consistency had to be policed externally.

## Note to future-me
If you find yourself thinking "wouldn't parallel be faster, simpler?":
- Persona drift was uncontrollable in parallel — only GM-single keeps tone over long conversations.
- NPCs would explode the call count (one HTTP request per NPC per turn).
- Cross-talk wasn't natural — alters spoke without referencing what other alters said in the same turn.
- The system prompt grew: GM needs the full character roster + world state + mystery thread context. That's expensive to multiply N times.
- Manifesto literally says "structural, not cosmetic". Parallel = cosmetic.

## Considered, rejected
- Per-alter parallel calls — ~30% faster but drift + scale broke it.
- Hybrid (alters parallel + GM-only for NPCs) — two systems running in parallel, complexity not worth the throughput gain.

## Result (code-side)
- `llm_client.gd` → `game_master.gd` (rename)
- Response shape: `{ speakers: [{id, line, trust_delta}], world_events: [...], narration }`
- `max_tokens` 1000 → 2500 (multi-speaker JSON needs the headroom)
- `conversation.gd`: `_on_gm_turn` parses the multi-speaker response, applies trust + world events, writes each speaker into history.
- Defense in depth: speakers outside the active allowlist are dropped client-side (see ADR-003).
