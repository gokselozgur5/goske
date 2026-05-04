# ADR-009: Project structure — scripts/ + scenes/

## Decision
Source layout:
- `scripts/` — all `.gd` and matching `.uid` files
- `scenes/` — all `.tscn` files (currently `main.tscn`)
- `addons/godotiq/` — third-party plugin (Godot expects this path)
- `icon.svg`, `project.godot`, `secrets.cfg` (gitignored), `README.md` at root
- `docs/` — design docs, ADRs

We do NOT keep `.gd` files at the project root.

## Intent (manifesto tie-in)
Not directly thematic — pure scalability. The player's plan is to grow this; flat root would become unreadable past ~10 scripts. Cost to refactor later (path updates in tscn ext_resources, fixing `res://` references) is way higher than the cost to put them in folders now.

## Note to future-me
If the editor reports "script not found at res://X.gd" after a restructure:
- Check the `path=` in scene files' `[ext_resource]` lines (not just the file system).
- Godot caches uids in `.godot/`. If something feels stuck, delete `.godot/` while the editor is closed; it regenerates on next open.
- If you see TWO copies of the same scene at root and in scenes/ — Godot recreated one because uid_cache pointed to the wrong location. Delete the wrong copy, delete `.godot/`, restart Godot.

If you add a new asset directory (textures, audio):
- Mirror the pattern: `materials/`, `audio/`, `images/` — flat at root, not under `scripts/`.

## Considered, rejected
- All flat at root (Godot's default for new projects) — fine for prototypes, fails past a handful of files.
- One folder per system (`combat/`, `dialog/`) — premature; we don't have systems-level scope yet, every script touches the same flow.

## Result (code-side)
- `scripts/`: alter, alter_personas, conversation, game_master, game_state, npc, player, pod, rest_zone (each + `.uid`).
- `scenes/main.tscn`: ext_resource paths use `res://scripts/X.gd`.
- `project.godot`: `run/main_scene = "res://scenes/main.tscn"`.
- One-time cleanup also removed godotiq's auto-installed agent-rule files (`AGENTS.md`, `CLAUDE.md`, `GODOTIQ_RULES.md`, `.cursorrules`, `.windsurfrules`, `.github/copilot-instructions.md`) — they duplicated guidance already in the addon and conflicted with the user's own Claude Code context.
