# ADR-017: Typewriter session token + punctuation auto-pacing

## Decision
Two small fixes to the typewriter system that make it survive real player behavior:

**Session token.**
- `conversation.gd` keeps `_session_id: int`. Bumped on every `_open_ui()` and `close()`.
- Each invocation of `_typewriter_reveal()` captures `my_session = _session_id` at start and rechecks before each `await`. If the panel was closed and reopened mid-reveal, the in-flight coroutine returns instead of writing into the new conversation.

**Punctuation auto-pacing.**
- Beyond the per-segment delay, the typewriter loop adds a small extra wait after natural pause characters:
  - `.` `!` `?` → +0.18s
  - `,` `;` `:` → +0.07s
  - `—` `…` → +0.12s
- This gives the reveal a heartbeat even on lines without explicit markup.

## Intent (manifesto tie-in)
Not a thematic call — both are robustness/quality. But:

- The session token directly serves "speech is action" — when the player closes a conversation mid-line, the abandoned line really IS abandoned. No ghost text bleeding into the next session.
- Punctuation pacing makes prose breathe at the rhythm a reader expects. The base 30 ms/char felt mechanical; punctuation adds the "hmm" between sentences. Density beat without writing more text.

## Note to future-me
If you ever switch to a streaming LLM (token-by-token reveal as the model emits):
- Session token still applies — the streamer should subscribe to `_session_id` the same way.
- Auto-pacing might need to be skipped (the model's stream cadence already is the pace).

If lines still feel uniform:
- The constants in punctuation are first-pass. If `.` feels too short, raise to 0.30; if `,` feels insistent, drop to 0.04.
- Consider a per-channel speed: red lines fast, blue lines steady, green lines slow. Hooks into `last_action.color`.

If you remove the typewriter entirely (instant reveal):
- Session token can stay; it becomes a no-op for synchronous append paths.
- Auto-pacing dies with the typewriter — punctuation has no character-level reveal to pause through.

## Considered, rejected
- **Cancel any in-flight Tweens on close** — would also work, but Tweens here are only used for fades (bubbles, ending overlay). Typewriter is plain `await create_timer`. Session token is the right granularity.
- **Per-segment markup-only pacing (no auto-pacing)** — relies on the GM remembering to mark. Auto-pacing makes baseline lines feel right even when GM forgets.
- **Sentence-level rhythm parser** (split on `.!?`, fade per sentence) — overkill; per-character extra delay does the job.

## Result (code-side)
- `conversation.gd`:
  - `_session_id: int = 0` bumped in `_open_ui()` and `close()`
  - `_typewriter_reveal()` captures `my_session` at start, checks `my_session != _session_id` before each `await` and after each step
  - Char loop adds `0.18 / 0.07 / 0.12` extra delay on punctuation classes
- `game_master.gd`: prompt lines updated to encourage markup ("USE markup OFTEN, at least one marker per non-trivial line") so explicit drama beats stack on top of auto-pacing
