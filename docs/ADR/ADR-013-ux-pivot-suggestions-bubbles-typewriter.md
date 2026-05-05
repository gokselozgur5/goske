# ADR-013: UX pivot — speech bubbles, GM suggestions, typewriter reveal

## Decision
The conversation surface stops being a text-heavy modal and becomes spatial + cinematic. Three changes together:
1. **Floating speech bubbles** — alter lines render as `Label3D` billboards on the alter in the world, fade in/hold/fade out.
2. **GM suggestions strip** — every turn the GM emits exactly **13** short replies in kanka's voice, tagged by tone. They render as a tone-colored button list. Tapping one sends the line. The conversation panel's `LineEdit` is hidden by default; **F** toggles free-text mode.
3. **Typewriter reveal** — alter lines reveal char-by-char in the conversation panel (~30 ms/char), with inline markup the GM may use sparingly: `(*)` pause, `**X**` bold, `*slow*X*!*` slowed segment, `[shake]X[/shake]`, `[whisper]X[/whisper]`. Speakers in a multi-speaker turn reveal sequentially, not in parallel.

Movement is no longer locked while the conversation is open — only when `LineEdit` has focus. Goske can roam under speech bubbles between turns.

## Intent (manifesto tie-in)
"Speech is action. A line can calm, provoke, mislead, reveal, close off a path, change trust" — and the WAY a line arrives is part of that action.

The original modal text panel was killing the manifesto's "presence" pillar — Goske froze, the world dimmed, the player stared at scrolling text. That made it feel like a chat client, not a 2.5D inhabited space. Bubbles + movement put the conversation back in the world.

The 13-suggestions question hit "no canned dialogue trees pretending to be agency". The escape: each suggestion is a DIFFERENT consequence (tone matters — sharp pushes, soft opens), and free text via F is always there. Manifesto's enemy is FAKE choice, not visible choice — BG3 options are real because they branch, and these branch through the GM's reactions.

13 matches the canonical pod count (ADR-007). Multiplicity texture: as many voices as there are versions of self.

## Note to future-me
If the surface ever drifts back to "text adventure":
- The bubbles AND the movement-during-dialog have to stay together. Either alone is half the win.
- Suggestions are NOT a tree. They're predictions of what kanka would naturally type. If they start sounding like RPG options ("[Persuasion] Convince him..."), the GM prompt is wrong — the predictions should be in kanka's voice, not a UI's voice.
- Typewriter pacing should be deliberate but not frustrating. 30ms/char is the read-along sweet spot. Lowering to 15ms feels cheaper. Raising to 50ms feels slow.
- The 13 number can flex — it's load-bearing CANONICALLY (pod count) but if it overwhelms, drop to ~9. UX > symbolism in the end.

If suggestions stop appearing:
- Check console — `[GM] world_events: [...]` should list "suggestions" each turn.
- If the GM stops emitting, the prompt's "MANDATORY" line probably needs to be made even louder, or the model under-tokens.

If the typewriter feels broken (cut off, scroll behind, etc.):
- HistoryScroll auto-scroll is manual (`_scroll_history_to_bottom()`). It's called per-char inside the typewriter loop. If you switch to a different scroll container, port it.

## Considered, rejected
- **Pure preset dialog wheel** (no free text) — manifesto-violating, kanka explicitly rejected this lineage in earlier conversation.
- **Pure free text** (no suggestions) — kanka described it as "yorucu" (exhausting), and the agency feedback was missing.
- **Auto-detect tone from typed input** — interesting but wraps complexity around the wrong axis. Tone is the GM's prediction, not a parser job.
- **No movement-during-dialog** — earlier behavior. Killed the spatial feel for no thematic gain.

## Result (code-side)
- `scripts/alter.gd`: `_create_bubble()` + `show_bubble(text)` (Label3D, billboard, no_depth_test, color from alter id).
- `scripts/conversation.gd`:
  - `_typewriter_reveal()` + `_typewriter_parse()` inline (no separate file — earlier global-class-cache lag).
  - `_rebuild_suggestions(items)` builds a tone-colored Button list under HistoryScroll.
  - `_on_suggestion_pressed(label)` sends the suggestion as if typed.
  - F key toggles `input_line.visible`.
  - `_scroll_history_to_bottom()` called per char during typewriter.
  - `_strip_markup()` for stored history (re-opens render clean).
- `scripts/player.gd`: `typing` check — only freezes when `input_line.has_focus()`.
- `scripts/game_master.gd` system prompt:
  - "MANDATORY 13 suggestions" with tone vocabulary.
  - Typewriter markup table with sparing-use guidance.
- `scenes/main.tscn`:
  - Panel anchor 0.5 → 0.32 (more vertical room for the suggestion strip).
  - HistoryScroll min height 260 → 200 (room for 13 suggestions).
  - SuggestionScroll wraps SuggestionStrip; max ~280 px height with scroll.
  - HintLabel: "F  type freely    ·    ESC  close".
  - LineEdit `visible = false` by default.
