# Goske — TODO

Living list of pending work, captured as we go. Roughly sorted by priority.

## Now / next

- [ ] **Credits screen** — in-game About / credits menu listing Sketchfab CC-BY attributions (cryopod, subnautica_pod) + Quaternius UAL1/UAL2 + Kenney + ElevenLabs voice notice. Required by CC-BY licenses; pull from `assets/sketchfab/CREDITS.md`.
- [ ] **Pod silhouette mesh discovery** — `pod.gd` has a debug print (`_debug_meshes`) to find the cryopod's human mesh name. After confirming the name, remove the debug and tighten `_find_human_mesh` if needed.
- [ ] **ElevenLabs quota** — currently hitting 429 (rate limit). Either upgrade plan or switch the heavy lifter (e.g. only narrator + alters use ElevenLabs, neighbors/system use a cheaper TTS).
- [ ] **room_2 content** — `scenes/room_2.tscn` is an empty placeholder; design the next-level layout once GM emits `unlock_room`. Ties into the "environment shapes around the player" idea (different aesthetic per ending tendency).

## Soon

- [ ] **13 endings RGB partition** — endings keyed off the dominant trust trajectory channel; this was discussed but not implemented yet.
- [ ] **Save / persistence** — currently each run starts cold. At minimum, save the trust history + days_alone so a closed tab doesn't wipe progress.
- [ ] **Sound effects** — pod-open hiss, footstep on metal, ambient room hum (low). Currently the only audio is TTS + opening narration.
- [ ] **Per-character voice tuning** — GM emits stability/style per line; verify the values actually feel right for each alter (red/blue/green) once the quota is back.
- [ ] **Mystery phase pacing** — verify `early → mid → late` advancement actually triggers in normal play, not just on `/ending` debug. Tune the GM's threshold for when to emit `mystery_phase`.
- [ ] **Meta breach** — eligibility flag exists (`meta_eligible`) but the conditions for it to flip true need to be tightened. Currently it might fire too early or never.

## Later

- [ ] **NPC neighbors** — `neighbor_1/2/3` exist as IDs and `npc_affected` is wired, but the visual response (gray drain) and the dialogue references are thin. Make alters allude to them more often as `monotony` climbs.
- [ ] **Day-alone mechanic** — `days_alone` counter advances but its texture in the dialogue is subtle. Consider a visible side-effect (room saturation drop, distant NPC silhouettes blurring) per N days.
- [ ] **Localization** — currently English-only TTS + UI. Turkish would double the work for ElevenLabs (need TR voices) but the GM is fine multilingual.
- [ ] **Subtitle for in-game alter lines** — opening narration has a polished subtitle; the in-game alter lines use the conversation panel instead. Decide if a subtitle pass for alters too is worth it.
- [ ] **N-skip during in-game lines** — N skips opening narration audio, but should it skip current alter audio too? Today it does (NarratorVoice listens for N globally), but check it doesn't desync the typewriter.

## Ops / build

- [ ] **itch.io upload automation** — currently I rebuild the zip and the user uploads manually. Could be a one-liner via butler if we add an `ITCH_API_KEY` to a non-committed config.
- [ ] **CI** — at least a `godot --headless --check-only` lint on PRs to catch parse errors before push.
- [ ] **Asset cleanup** — `assets/sketchfab/scifi_lab*` and `stasis_pod/` are old pod assets, no longer referenced. Once the cryopod swap is fully validated in-game, remove them.

## Done — recent (sanity checkpoint)

- [x] GM sovereignty (4 laws + JSON discipline + prosody rules)
- [x] Awakening queue (3 simultaneous pod opens no longer race)
- [x] Per-character TTS voices (red/blue/green/narrator)
- [x] Audio-text sync (typewriter paces to remaining audio)
- [x] N-skip for narrator audio
- [x] Dash on Space + freeze during conversation/opening
- [x] Pod silhouette inside / materialize outside
- [x] Cryopod model swap
- [x] Opening cinematic subtitle (BG3-style, skippable)
- [x] LICENSE: All Rights Reserved (source-visible, no use granted)
