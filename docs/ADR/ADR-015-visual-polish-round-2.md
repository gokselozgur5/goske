# ADR-015: Visual polish round 2 — grass shader, pod metals, particles, ambient light, head silhouettes

## Decision
Round-2 atmosphere/material pass after the mechanic skeleton stabilized:

- **Procedural grass shader** (`scripts/grass.gdshader`) — FBM noise on world-space XZ for color variation, overlaid with larger-scale dirt patches (smoothstep threshold). Replaces the flat green StandardMaterial3D on the floor.
- **Pod material upgrade** — base `metallic = 0.78, roughness = 0.42`, lid separated to `PodLidMesh` with `metallic = 0.65, rim_enabled = 0.4` for a "kapsül glass-edge" feel.
- **Pod opening particles** — `GPUParticles3D` one-shot under each functional pod, steam puff at lid crack (30 particles, 1.4s lifetime, explosiveness 0.7). Triggered in `pod._open()`.
- **Goske ambient halo** — `OmniLight3D` child on the player (warm `Color(0.95, 0.85, 0.7)`, range 4.5). Player carries a soft pool of light wherever they go.
- **Composite character silhouette** — capsule body + sphere head (`radius = 0.32`, `Y = 1.05`) for Goske + 3 alters. Material set on both meshes (player.gd `_apply_material` updates head_mesh too).
- **Pod-open easing** tightened — `TRANS_CUBIC + EASE_OUT` for lid (0.85s), `TRANS_BACK + EASE_OUT` for alter rise (0.9s, slight overshoot).
- **WorldEnvironment polish** — SSAO, glow, fog, exposure 1.05.

## Intent (manifesto tie-in)
"Each thing we do should be a piece of craftsmanship. Not cheap, not gaudy — quality." Round 1 was "skeleton" — flat green, plain capsules, default lighting. Round 2 puts the systems we already built into a world the eye believes.

Manifesto: "atmosphere, framing, material presence". Specifically:
- Grass variation makes the floor feel alive — not just "ground colored green".
- Pod metals + rim catch the directional light and convey "sealed kapsüller", not "boxes".
- Steam particles mark lid-opening as a moment, not just a mesh translate.
- Ambient halo on Goske says "you're here, you displace light" — presence pillar.
- Sphere head turns "abstract pill" into "person you can almost name".

## Note to future-me
If perf drops on web export (ADR pending) or mobile:
- Particles: lower amount per pod (30 → 15) or disable per platform.
- Grass shader: drop FBM octaves from 4 to 2.
- SSAO: `ssao_intensity` is the cheap knob (1.5 → 0.8).
- Glow + fog: cheap, keep.

If the head sphere looks wrong:
- Position is `Y = 1.05` from capsule center. Capsule height 1.8 means top is at Y = 0.9, head at 1.05 sits clean above. Don't drop it under 0.9 or it intersects the body.

If procedural grass goes wrong on a different renderer (web Compatibility / Mobile):
- The shader uses `VERTEX.xz` for world-aligned noise. Should still work in Compatibility but custom shader behavior can differ. Plan: test on Compatibility renderer when we web-export, fall back to a baked tiled texture if the shader misbehaves.

If the player loses the warm halo / it bleeds too far:
- `omni_range` is 4.5. `omni_attenuation` 1.5 controls falloff curve. Tighten range first, only then drop attenuation.

## Considered, rejected
- **Hand-authored capsule textures (decals)** — would look better but writing/sourcing a Goske texture set is a big pass. Procedural is enough for round 2.
- **Full humanoid mesh** (arms, legs) — composite primitive heads + capsule body lands the silhouette without a rig. Full rig is a different effort entirely (see Iter Stack memory).
- **Bake static lightmap** — overkill for a 20×20 floor + 13 pods. SSAO + Forward+ realtime is fine.
- **Custom RichTextEffect for `[shake]`** — Godot 4 ships built-in shake, used directly.

## Result (code-side)
- `scripts/grass.gdshader` — new shader, FBM noise + dirt patches.
- `scenes/main.tscn`:
  - GrassMat_1 → ShaderMaterial referencing grass.gdshader.
  - PodBaseMat / PodLidMat sub-resources, PodLidMesh shares lid material.
  - SteamProcessMat / SteamQuadMat / SteamQuadMesh sub-resources for particles.
  - OpenParticles GPUParticles3D under PodRed/PodBlue/PodGreen.
  - HeadMesh (SphereMesh) added to Player + AlterRed/Blue/Green.
  - GoskeLight OmniLight3D on Player.
  - Env_1 polished (ssao, glow, fog, tonemap_exposure 1.05).
- `scripts/pod.gd`:
  - Easing on lid + alter rise tween (TRANS_CUBIC ease_out / TRANS_BACK ease_out).
  - `OpenParticles.restart()` called inside `_open()`.
- `scripts/player.gd`:
  - `head_mesh` reference; `_apply_material` updates both body and head.
