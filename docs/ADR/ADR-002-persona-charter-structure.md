# ADR-002: Persona charter structure (over one-line persona prompts)

## Decision
Each alter has a structured charter: `core` + `traits` + `forbidden` + `voice` + `examples` + anti-mimicry clause. The system prompt is built from this charter every API call.

## Intent (manifesto tie-in)
Manifesto: "AI must be structural, not cosmetic." A single sentence ("you are angry") IS cosmetic — LLMs drift away from it within a few turns. Structured constraints (what you ARE, what you NEVER are, sample lines, drift recovery instruction) hold tone over long conversations.

## Note to future-me
If you're wondering "why all this scaffolding for a one-liner persona":
- Early version was "you are an angry alter, 1-2 short sentences". Within 5 turns red was talking like a sad therapist.
- Adding `forbidden` was the single biggest win — telling the model what NOT to be is more reliable than telling it what to be.
- `examples` is few-shot in disguise. 3 sample lines anchor tone better than paragraphs of description.
- Anti-mimicry clause matters specifically because alters see each other's lines in history (cross-talk). Without "don't agree with them, don't mimic them", green starts sounding like blue when blue speaks first in a turn.
- Drift-recovery line ("if you notice you're drifting, return to your core") is cheap and works.

## Considered, rejected
- One-line persona ("you are X alter") — drifted within turns.
- Long literary character description — verbose, model still drifted because no negative constraints.
- Embedding-based persona retrieval — overkill for 4 characters.

## Result (code-side)
- `scripts/alter_personas.gd` holds `PERSONAS` dict keyed by alter_id.
- Each entry: `name`, `core`, `traits[]`, `forbidden[]`, `voice`, `examples[]`.
- `build_persona_prompt(id)` assembles the full prompt block per request.
- `game_master.gd._build_system_prompt` lists active charters in a CHARACTERS section.
- Narrator is also a charter (treated as a non-character "voice of the game"; see ADR-006).
