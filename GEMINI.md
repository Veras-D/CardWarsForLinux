# Project Directives: Card Wars & Modular Game Systems Library

This document outlines the strict behavioral and architectural rules for this codebase. Any agent or contributor working on this repository must adhere to these directives.

---

## 1. Core Architectural Directive: Systems-First & Independent Modules

> **"Build systems, not monolithic games."**
> Instead of building an entire monolithic game that cannot be repurposed, build individual, reusable, and polished game systems — deck engine, lane board, timing wheel, ability interpreter, save vault, audio jukebox — as standalone, decoupled modules.

### Rules of Separation:
1. **Zero Game-Specific Coupling in Systems**:
   - All generic system packages live in `godot/src/systems/<system_name>/`.
   - Generic systems **must never** import or reference *Card Wars* specifics (no hardcoded references to "The Pig", "Cornfield", "Finn", or "db_Creatures").
   - Systems deal purely in generic data types and contracts (e.g. `CardData`, `CardCost`, `FactionAffinity`, `SlotIndex`, `HitAreaPercentage`).
2. **Extraction-Ready for Other Projects**:
   - Every system directory under `godot/src/systems/` must be structured so the user can copy-paste it directly into an entirely different, independent Godot project and have it work immediately out-of-the-box.
3. **Isolated Testbed Scenes (`testbed_*.tscn`)**:
   - Every single module **must** contain a standalone runnable test scene (e.g. `testbed_deck.tscn`, `testbed_wheel.tscn`).
   - A developer or agent must be able to run that testbed alone (`godot scenes/.../testbed.tscn`) to test the system in isolation without clicking through menus or running the full battle game.
4. **Card Wars as a Composition Layer**:
   - *Card Wars* itself is purely a **Composition Consumer Layer** (`godot/src/card_wars/` or `godot/src/battle/`).
   - The battle scene simply instantiates these generic systems and wires them together with Card Wars art, blueprints, and Adventure Time characters.

---

## 2. Directory Architecture

```text
godot/
├── assets/                  # Raw Card Wars assets (textures, audio, data)
├── data/                    # Parsed JSON database (cards, quests, blueprints)
├── scenes/
│   ├── main_menu.tscn       # Main navigation
│   └── battle.tscn          # Game composition scene
└── src/
    ├── card_wars/           # Card Wars specific logic & glue code
    │   ├── Database.gd      # Blueprint loaders
    │   └── GameManager.gd   # Campaign state & flow
    └── systems/             # STANDALONE, REUSABLE SYSTEMS (Independent projects)
        ├── deck_engine/     # Universal Card/Hand/Deck Manager
        │   ├── Deck.gd
        │   ├── HandManager.gd
        │   └── testbed_deck.tscn
        ├── board_system/    # Universal Lane/Grid Board System
        │   ├── LaneSlot.gd
        │   ├── BoardGrid.gd
        │   └── testbed_board.tscn
        ├── timing_wheel/    # Universal Roulette / Timing Spinner Minigame
        │   ├── WheelSpinner.gd
        │   └── testbed_wheel.tscn
        ├── ability_engine/  # Universal Trigger/Action Effect Resolver
        │   ├── AbilityRunner.gd
        │   └── testbed_abilities.tscn
        ├── save_vault/      # Universal JSON Save & Backup System
        │   ├── SaveManager.gd
        │   └── testbed_save.tscn
        └── audio_jukebox/   # Universal BGM Crossfader & SFX Bus Pool
            ├── AudioManager.gd
            └── testbed_audio.tscn
```

---

## 3. Tooling & MCP Integration

- **Godot MCP Server**:
  - Configured in `~/.gemini/config/mcp_config.json` and `~/.gemini/antigravity/mcp_config.json` using `@coding-solo/godot-mcp`.
  - Executable node path: `/home/verivi/.nvm/versions/node/v24.15.0/bin/node`.
  - Package: `/home/verivi/.nvm/versions/node/v24.15.0/lib/node_modules/@coding-solo/godot-mcp/build/index.js`.
  - Godot Binary: `/home/verivi/.local/bin/godot`.

---

## 4. Diagnostics & Debugging Policy

- **Never Silence Output**:
  - Never silence, suppress, or hide any warnings, errors, or engine diagnostics. All logs must remain visible in terminal output for real debugging.
- **Debug First**:
  - When facing an error, investigate logs and debug first. Never assume root causes.
- **Never Guess APIs**:
  - Verify library capabilities and parameters directly via code, official docs, or web search.

---

## 5. Interaction & Modification Protocol

- **Consult Before Execution**: If the user asks a conceptual, design, or architectural question, discuss it with them first before writing code.
- **Preserve Documentation**: Maintain documentation integrity across [`BACKLOG.md`](./BACKLOG.md), preserving progress notes and task tracking.
