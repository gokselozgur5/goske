# Goske — design docs

Living docs for the project. Read them when you stop trusting your own memory.

## Map

- **[GDD.md](GDD.md)** — game design overview. Premise, pillars, mechanics summary, scope.
- **[journey.md](journey.md)** — single-run player flow + pressure axes + state-event diagram.
- **[ADR/](ADR/)** — architecture decision records, one per major call. Read these when you're tempted to undo a past decision; future-you wrote them for present-you.

## ADR index

- [ADR-001](ADR/ADR-001-single-game-master.md) — Single Game Master (over per-alter parallel calls)
- [ADR-002](ADR/ADR-002-persona-charter-structure.md) — Persona charter structure (anti-drift)
- [ADR-003](ADR/ADR-003-sealed-pod-allowlist.md) — Sealed pod allowlist enforcement
- [ADR-004](ADR/ADR-004-npc-no-direct-dialogue.md) — NPCs have no direct dialogue
- [ADR-005](ADR/ADR-005-rest-mechanic-and-days-alone.md) — Rest mechanic + days_alone counter
- [ADR-006](ADR/ADR-006-mystery-thread-layered.md) — Mystery thread is two-layered
- [ADR-007](ADR/ADR-007-thirteen-pods-canonical.md) — Thirteen pods, canonical
- [ADR-008](ADR/ADR-008-awakening-fresh-start.md) — Awakening sends no prior history
- [ADR-009](ADR/ADR-009-project-structure.md) — Project structure (scripts/, scenes/)
- [ADR-010](ADR/ADR-010-english-everywhere.md) — English across all surfaces
- [ADR-011](ADR/ADR-011-ending-production-triggers.md) — Ending production triggers
- [ADR-012](ADR/ADR-012-fourth-wall-meta-breach.md) — 4th-wall meta breach (rare)

## When to write a new ADR

A new ADR goes in when ALL of these are true:
- The decision changes how a system fundamentally works (not a tweak, not a fix).
- An obvious-looking alternative was rejected (and someone in 6 months might wonder why).
- The reasoning ties to either the manifesto, an external dependency, or accumulated experience that isn't visible in the code.

A bug fix doesn't need an ADR. A refactor that changes the data model does.

## When to update an existing ADR

Don't edit the body — append a "## Update — YYYY-MM-DD" section. Past-you's reasoning stays visible; you only add what changed.

## Format

Each ADR has five sections:
1. **Decision** — the call, in one or two sentences.
2. **Intent (manifesto tie-in)** — what the call serves at the theme level.
3. **Note to future-me** — what'll tempt you to undo this and why you'd be wrong (or right).
4. **Considered, rejected** — the alternatives that lost, with one-line reasons.
5. **Result (code-side)** — what files / systems changed.

The format isn't sacred. The five questions are.
