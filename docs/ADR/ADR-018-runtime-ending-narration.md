# ADR-018: Runtime ending narration (GM writes the closing beat)

## Decision
The ending overlay no longer renders a static `theme` blurb. When `show_ending()` fires, the resolved Voronoi result still picks the **label** ("Justified Rage", "Empty Jar", etc.) and the **color** of the bg wash — those stay deterministic. But the 2-3 sentence narration under the label is now written by the Game Master at the moment of resolution, briefed with the actual run's state.

The static `theme` strings in `endings.gd` are kept and used as a fallback when the GM call errors or times out (12s default).

Flow:
1. `show_ending()` resolves the Voronoi ending → sets label + color + coords + ellipsis placeholder.
2. Builds a run summary string (trust triple, days_alone, comfort_exits, monotony, tension, mystery_phase, unlocked, silenced, npc_intensity).
3. Calls `GameMaster.request_turn` with a single user message that includes the resolved label, the centroid, and the run summary, asking for 2-3 short literary sentences in second person.
4. On response: pull `speakers[0].line` (or `narration` fallback) into `theme_label`.
5. On error / 12s timeout: write `endings.gd`'s static `theme` instead.

## Intent (manifesto tie-in)
"AI must be structural, not cosmetic. No canonical run."

The 17 Voronoi labels are already structural — they classify what kind of run this was. But the static blurbs were cosmetic: the same prose every time you landed on "Justified Rage", regardless of whether you got there in 3 days screaming or 22 days slow-cooking. Manifesto says: don't decorate; let the AI carry meaning.

Now: the label is the diagnosis (deterministic), the narration is the bedside manner (run-aware). Two players who land on the same Voronoi cell get the same name for what happened to them and different prose describing it. The GM gets to acknowledge that one player burned out fast, the other ground down. That is "no canonical run" written into the closing frame instead of just the journey.

It also closes the loop on the engine→LLM contract from ADR-016. Engine resolves the ending math; LLM colors the resolution. Same pattern, same direction, applied to the moment that matters most.

## Note to future-me
**If the GM blurb feels generic** (you're seeing the same kind of sentences across very different runs):
- Sharpen the prompt. The current prompt asks the GM to "reference what kanka actually did" — it might need explicit cues like "name the day count if it was extreme, name the silenced alter if there was one, name the dominant trust channel". Right now we hand it the numbers and trust it to pick the load-bearing ones.
- Consider passing an explicit "highlight" field built engine-side (e.g., "your dominant axis was blue, your unusual stat was 22 days alone") so the GM doesn't have to mine it from raw state.
- Increase max_tokens for ending calls if the prose is getting cut off.

**If the GM call fails too often:**
- Static fallback already kicks in. Confirm the player still gets a coherent ending (label + static theme + coords). They do — but the wash of "GM-driven ending" is broken for that run.
- Consider a retry-once-then-fallback pattern. Right now it's one shot.
- Network failures during the climax of a run feel especially bad; the 12s timeout is generous, but you may want a "soft retry" while the fade-in is still playing.

**If you want the ending to be more cinematic:**
- The narration is currently dropped in plain. Consider running it through the same typewriter system as `conversation.gd` — would reinforce the idea that this is a beat, not a screen.
- Music swell + slow color drain on the bg would make the ellipsis-to-text transition feel intentional rather than like "loading".

**If you want multiple narration lines:**
- The prompt currently asks for 2-3 sentences in a single speaker entry. You could ask for 3 narrator beats and reveal them one by one. That changes the rhythm a lot — try first as one block, then split if it feels rushed.

**If the ending should be replayable** ("show me that ending again"):
- The narration is regenerated every time `show_ending()` runs. There is no caching. Replays of the same run state will get a different blurb each time. If you want stable replays, store the narration in `GameState` keyed by run id and reuse.

## Considered, rejected
- **Fully GM-written ending including the label** — would make the 17-cell Voronoi cosmetic. The whole point of the partition is that the engine knows which kind of run this was; cede the label and you cede the diagnosis.
- **Pre-write all 17 blurbs in 5-6 variants each, pick by run state** — manual content treadmill, doesn't scale to side-axes (days_alone, comfort_exits, npc_intensity) without combinatorial explosion. GM does the same job by reading the state.
- **Stream the narration token-by-token** — worth doing eventually (matches the typewriter feel) but the current `request_turn` is non-streaming. Adding streaming for one surface is more refactor than this ADR's scope.
- **No fallback, just spinner forever on error** — a network blip at the climax of a run is the worst time to hang the player. Static fallback after 12s keeps the run finish-able.
- **Build a "narrator-only mode" in `game_master.gd`** — would bypass the active-roster filter and the LAST ACTION FLAVOR block. Tempting, but the current prompt already asks for `id: "narrator"` and the system prompt always exposes narrator. Adding a mode flag for one caller is over-engineering before we've seen it fail.

## Result (code-side)
- `scripts/ending_overlay.gd`:
  - `show_ending()` no longer fills `theme_label` from the static dict. Sets it to `…` and kicks off a GM request.
  - `_request_narration()` builds the prompt (label + centroid + run summary), calls `GameMaster.request_turn` with a 1-message history.
  - `_on_narration(turn, error)` writes the GM line into `theme_label`; falls back to the static theme on error.
  - `_on_narration_timeout()` (12s) writes the static fallback if the GM hasn't replied yet.
  - `_waiting` flag prevents a late GM response from overwriting a fallback that already landed (or vice-versa).
- `scripts/endings.gd`: untouched. Static `theme` strings stay as fallback content.
- `scripts/game_state.gd`: untouched. `compute_ending()` still returns the same dict.
- `scripts/game_master.gd`: untouched. Reuses the existing `request_turn` API.
