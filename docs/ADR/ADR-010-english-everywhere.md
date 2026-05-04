# ADR-010: English across all surfaces (LLM, UI, code)

## Decision
Every player-facing string, system prompt, persona content, code comment, and identifier is in English. Internal team chat (between us) stays bilingual TR/EN as it always has — that's a different surface.

## Intent (manifesto tie-in)
Not thematic. Pragmatic, with one tone-impact note.

We started with Turkish persona prompts and Turkish UI. Two problems:
1. Haiku 4.5 drifts noticeably in Turkish — persona discipline fails faster, JSON output gets lazier, model occasionally answers in English mid-Turkish.
2. The persona examples (sample lines) are tone-anchors. In Turkish they were fine, but the same model in English produced more cinematic output for the same archetype.

For a story-heavy AI-driven game, the LLM's output quality is the product. Going English bought us tighter persona discipline and richer prose.

## Note to future-me
If you want to localize back to Turkish (or any other language) later:
- Externalize strings now (current code has English literals embedded). A small `i18n.gd` or Godot's TranslationServer wraps it.
- Persona content is the hard part — translating "voice" is non-trivial. You'd write fresh personas in TR, not translate.
- LLM model choice matters more than translation. If a future TR-strong model emerges (Claude 5? Gemini 3? Local fine-tune?), try the persona test first with that model BEFORE re-introducing TR personas.

If a player insists on TR/EN switch:
- Persona has to be authored separately per language (not auto-translated). Cost: meaningful writing time.
- The CHARACTERS section of the system prompt is the largest text block; switching it is the bulk of the work.

## Considered, rejected
- Bilingual personas (model picks based on player input language) — unstable, model picked TR even when English was strong, drifted between.
- Pure Turkish — drift was visible within a session, lost the persona discipline that the charter system bought us.

## Result (code-side)
- `game_master.gd` SYSTEM_BASE — English.
- `alter_personas.gd` PERSONAS dict — English (red/blue/green/narrator core, traits, forbidden, voice, examples).
- `conversation.gd` user-facing strings: "you:", "exhaustion N/100", "Type, press Enter to send...", "history reset", "alter went silent...", "a day passes alone".
- `main.tscn` UI labels: "exhaustion 0/100", placeholder.
- All code comments — English.
- README — English.
- ADRs — English (this file is one).
