# Technical Preferences

<!-- project.yaml at the repo root is the machine-readable source of truth for
     engine, specialists, naming, performance, platform, and testing.framework.
     This file is the human-readable LEGACY FALLBACK: agents and skills resolve
     each key from project.yaml first and fall back here only when the
     project.yaml key is absent. /setup-engine dual-writes both.
     Forbidden patterns and allowed libraries are NOT migrated — they live only
     in this file. Populated by /setup-engine; updated as decisions are made. -->

## Engine & Language

- **Engine**: Godot 4.7
- **Language**: GDScript
- **Rendering**: Compatibility (OpenGL 3.3 / WebGL 2)
- **Physics**: Jolt

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC (Steam; Windows primero). Web solo para probar de a uno.
- **Input Methods**: Teclado y mouse, más el micrófono (el volumen de la voz es una mecánica)
- **Primary Input**: Teclado y mouse
- **Gamepad Support**: None (por ahora)
- **Touch Support**: None
- **Platform Notes**: multijugador sin servidores (un jugador es anfitrión), por IP o lobbies de Steam

## Naming Conventions

- **Classes**: PascalCase (`class_name HouseOwner`)
- **Variables**: snake_case
- **Signals/Events**: snake_case en pasado (`woke_up`, `caught`)
- **Files**: snake_case (`house_owner.gd`)
- **Scenes/Prefabs**: snake_case (casi todo se arma por código; hay una sola escena)
- **Constants**: SCREAMING_SNAKE

## Performance Budgets

- **Target Framerate**: 60
- **Frame Budget**: 16,67 ms
- **Draw Calls**: [TO BE CONFIGURED]
- **Memory Ceiling**: [TO BE CONFIGURED]

## Testing

- **Framework**: propio — `scripts/dev/autotest.gd` (anfitrión + cliente reales por red); no hay gdUnit4
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist
- **Shader Specialist**: godot-shader-specialist
- **UI Specialist**: godot-specialist
- **Additional Specialists**: godot-gdextension-specialist
- **Routing Notes**: el código está en `scripts/` (no en `src/`)

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (primary language) | godot-gdscript-specialist |
| Shader / material files | godot-shader-specialist |
| UI / screen files | godot-specialist |
| Scene / prefab / level files | godot-specialist |
| Native extension / plugin files | godot-gdextension-specialist |
| General architecture review | Primary |
