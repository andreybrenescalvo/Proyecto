# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.7 (renderer Compatibility, física Jolt)
- **Language**: GDScript
- **Version Control**: Git; el trabajo se sube a ramas `claude/...` y se integra por pull request
- **Build System**: export presets de Godot (`export_presets.cfg`; hoy solo "Web")
- **Asset Pipeline**: todo se arma por código (cajas texturizadas); las texturas las genera
  `tools/generate_textures.py` en `assets/textures/` (sin assets externos)

## This Project: Mudanceros Truchos

Cooperativo de 1 a 4 jugadores: robar de noche la casa de Don Ramón sin despertarlo (el juego
escucha el micrófono). `README.md` explica el juego y `docs/plan-juego-steam.md` es el plan
(sección 8 = la idea actual). Read both before designing or changing gameplay.

- **Code root is `scripts/`, not `src/`.** Wherever a skill or agent says `src/`, read
  `scripts/`. Do not move the code: every `res://scripts/...` path depends on it.
- **Language:** everything the player sees, code comments and docs are in Spanish (neutral
  Latin American). Identifiers stay in English, matching the existing code.
- **Balance numbers** live in `scripts/core/config.gd`; house styles in
  `scripts/world/house_builder.gd`.
- **Tests:** there is no gdUnit4. The automated test is `scripts/dev/autotest.gd`:
  `godot --headless --path . -- --solo --autotest` (one player), or a host and a client over
  the network (see README). It prints `AUTOTEST OK`. Run `godot --headless --path . --import`
  first on a fresh clone.
- **Looking at the game:** `godot --path . -- --host --tour=<folder>` saves screenshots
  (`--tour-quick` for two). In a container without a screen, wrap it in `xvfb-run`.
- **The owner of this project is not a programmer.** Explain choices in plain Spanish,
  keep questions few and concrete, and recommend one option instead of listing many.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

<!-- ENGINE-REFERENCE-IMPORT: the line below is engine-specific. /setup-engine
     rewrites it to @docs/engine-reference/<engine>/VERSION.md for the chosen
     engine, so a Unity or Unreal project stops loading the Godot reference every
     session. It defaults to Godot (the template's example engine); skills that
     need the pinned version read docs/engine-reference/<engine>/VERSION.md on
     demand regardless of this import. -->
@docs/engine-reference/godot/VERSION.md


## Technical Preferences

`project.yaml` at the repo root is the primary config store — engine, specialists,
naming, platform, performance, modes. Skills resolve it via `resolve_config`
(see `.claude/docs/config-resolution.md`).

`.claude/docs/technical-preferences.md` is the **legacy fallback**, read on demand
when a key is absent from `project.yaml`. It is not imported here: before
`/setup-engine` runs it is almost entirely `[TO BE CONFIGURED]` placeholders, and
after it runs `project.yaml` holds the real values.

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
  (exempt: `active.md` appends, agent memory, a subagent's new file at the path
  its orchestrating skill named; see `.claude/rules/agent-memory.md`)
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction
- A skipped or dismissed question is not an answer: act on nothing, re-ask in
  plain text and wait
- Started outside this file's folder? Warn first: hooks, deny rules and the
  ask-first mode load only when Claude Code starts here

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

Read `.claude/docs/context-management.md` on demand — it is a reference, not
session context. Two of its conventions are load-bearing and cited by name
elsewhere in the repo, so they are restated here rather than lost:

- **`production/session-state/active.md` is the session checkpoint.** The file is
  the memory, not the conversation. Read it first after any compaction, crash, or
  `/clear`.
- **Helpers in `.claude/scripts/` emit observations, never verdicts.** A script
  that scores or judges will eventually contradict a mode or override it cannot
  see. (Cited by `artifact-check.sh` and `adr-dep-graph.sh`.)
