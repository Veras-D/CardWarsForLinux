# Card Wars (Godot 4 PC Remake) - Master Engineering Backlog & Implementation Manual

> **Purpose**: This document serves as the exhaustive, self-sufficient technical reference and backlog for engineering the Godot 4 PC remake of *Adventure Time: Card Wars*. It contains exact file mappings from the original 1,380+ Unity C# codebase, data schemas from the blueprint database, mathematical formulas, state machine designs, and unambiguous Acceptance Criteria (Definition of Done) for every single feature.

---

## 📑 Table of Contents
1. [Core Engine & Architectural Foundations](#1-core-engine--architectural-foundations)
2. [Global Game Parameters & Balance Constants](#2-global-game-parameters--balance-constants)
3. [Epic 1: Match Flow & Pre-Battle Setup (RPS & Landscapes)](#epic-1-match-flow--pre-battle-setup)
4. [Epic 2: Battlefield Mechanics & Combat Resolver Engine](#epic-2-battlefield-mechanics--combat-resolver-engine)
5. [Epic 3: The 317 Ability Scripts & Trigger System](#epic-3-the-317-ability-scripts--trigger-system)
6. [Epic 4: 38 Animated Character Face Rigs & Audio Engine](#epic-4-38-animated-character-face-rigs--audio-engine)
7. [Epic 5: Gamepad Controls & Local 2-Player Multiplayer](#epic-5-gamepad-controls--local-2-player-multiplayer)
8. [Epic 6: Deck Building, Fusion, Quality & Inventory](#epic-6-deck-building-fusion-quality--inventory)
9. [Epic 7: Campaign, Quests & Game Modes (346 Quests, FC, Dungeons, El Fisto)](#epic-7-campaign-quests--game-modes)
10. [Epic 8: Economy, Gacha Chests & Progression](#epic-8-economy-gacha-chests--progression)
11. [Epic 9: UI, Localization, Settings & Multiplatform CI/CD](#epic-9-ui-localization-settings--multiplatform-cicd)
12. [Milestone Roadmap & Implementation Order](#12-milestone-roadmap--implementation-order)

---

## 1. Core Engine & Architectural Foundations

### Architecture Pattern: Data-Driven ECS / Autoload Node Model
- **`Database.gd`** (`res://src/autoload/Database.gd`):
  - Ingests `db_Creatures.json`, `db_Spells.json`, `db_Buildings.json`, `db_Leaders.json`, and `strings_en.json`.
  - Caches unified card dictionaries.
- **`GameManager.gd`** (`res://src/autoload/GameManager.gd`):
  - Holds active match configuration (Player 1 deck, Player 2 / AI deck, landscapes, hero selections, match state).
- **`AudioManager.gd`** (`res://src/autoload/AudioManager.gd`):
  - Global audio dispatcher routing SFX, VO, and BGM to 4 distinct Godot audio buses.
- **`SaveManager.gd`** (`res://src/autoload/SaveManager.gd`):
  - Persists player inventory, unlocked cards, quest star ratings, coins/gems to `user://save_data.json`.

---

## 2. Global Game Parameters & Balance Constants

*Source of Truth: `Assets/StreamingAssets/Blueprints/db_Parameters.json`*

| Constant Identifier | Value | Gameplay Effect |
| :--- | :--- | :--- |
| `Starting_Magic_Points` | `2` | Base MP given to players on Turn 1 |
| `Max_Magic_Points` | `10` | Hard cap on turn Magic Points |
| `Min_Cards_In_Deck` | `10` | Minimum legal deck size |
| `Max_Cards_In_Deck` | `25` | Maximum legal deck size |
| `Max_Duplicates_In_Deck` | `4` | Maximum copies of a single card allowed |
| `New_Player_Max_Inventory` | `50` | Base Card Box inventory slots |
| `New_Player_Max_Stamina` | `5` | Maximum Heart stamina |
| `Stamina_Restoration_Rate` | `15` | Minutes elapsed to restore 1 Heart |
| `New_Player_Coins` | `0` | Starting Gold coins |
| `New_Player_Gems` | `5` | Starting Algebraic Gems |
| `Max_Leader_Level` | `50` | Hero Leader level cap |
| `Dungeon_Min_Level` | `5` | Hero level required to enter Daily Dungeons |

---

## Epic 1: Match Flow & Pre-Battle Setup

### Task 1.1: Rock-Paper-Scissors (RPS) Turn Decider
- **Unity Reference**: `RPSMatrix.cs`, `RPSManager.cs`, `db_RPS.json`.
- **Godot Implementation**:
  - Create `res://scenes/components/RPSMinigame.tscn` and `RPSMinigame.gd`.
  - State Machine: `CHOOSING -> REVEALING -> RESOLVED`.
  - Display 3 choice buttons: 🪨 Rock, 📄 Paper, ✂️ Scissors.
  - Opponent AI randomly selects choice based on weighting matrix (`RPSMatrix.cs`).
  - **Resolution**:
    - Winner gets modal dialog: *"You Won! Choose Turn Order:"* with options `[Go First]` and `[Go Second]`.
    - Tie triggers re-roll animation.
  - Setting toggle: `Options -> Skip RPS (Randomize First Turn)`.
- **Acceptance Criteria**:
  - [ ] Opening match starts with RPS phase unless skipped in Settings.
  - [ ] Winner can choose turn order; chosen player receives Turn 1.
  - [ ] Full controller and mouse support.

### Task 1.2: 4-Landscape Placement Phase
- **Unity Reference**: `LandscapePreviewController.cs`, `ManualLandscapeScript.cs`, `LandscapeType.cs`.
- **Godot Implementation**:
  - The 4 landscape tiles represent the 4 lanes on each player's side:
    - `0: Corn` (Golden Cornfield)
    - `1: Plains` (Blue Plains)
    - `2: Swamp` (Useless Swamp)
    - `3: Cotton` (Cotton Land)
    - `4: Sand` (Sandy Lands)
    - `5: Candy` (Fionna & Cake expansion)
  - At match start, display an animation placing the 4 chosen landscape tiles into lane slots 0..3 before card draw.
- **Acceptance Criteria**:
  - [ ] Lanes render their assigned landscape theme, texture, and label.
  - [ ] Both Player and Opponent lane affinities match their deck configuration.

### Task 1.3: Matchup Intro Screen
- **Unity Reference**: `CWBattleIntroController.cs`, `CWBattleSequenceController.cs`.
- **Godot Implementation**:
  - Split-screen banner showing Player Leader portrait vs. Opponent Leader portrait.
  - Reads opening voice line from `Assets/AudioClip/` (e.g. Finn: *"Let's play Card Wars!"*).
- **Acceptance Criteria**:
  - [ ] Displays Leader names, starting HP (25), and plays VO. Transitions into RPS smoothly.

---

## Epic 2: Battlefield Mechanics & Combat Resolver Engine

### Task 2.1: Phase State Machine (`BattlePhaseManager.gd`)
- **Phases**:
  ```
  START_TURN -> ACTION_PHASE -> BATTLE_WHEEL_PHASE -> COMBAT_RESOLUTION -> END_TURN
  ```
- **Execution Rules**:
  - `START_TURN`: Draw 1 card; MP = `min(10, current_max_mp + 1)`; unfloop all creatures; tick down Leader power cooldown (-1).
  - `ACTION_PHASE`: Player can summon creatures, place buildings, cast spells, and tap Floop abilities.
  - `COMBAT_RESOLUTION`: Iterates Lane 0 to Lane 3 sequentially.
- **Acceptance Criteria**:
  - [ ] Turn transitions cannot be skipped or bypassed out of sequence.
  - [ ] Actions correctly spend Magic Points; players cannot act with insufficient MP.

### Task 2.2: Spell Cards System
- **Unity Reference**: `db_Spells.json`, `CardType.cs`, `SpellResolver.cs`.
- **Godot Implementation**:
  - Spell types:
    - **Board/Hero Spells**: Played by releasing onto the battlefield (e.g. `Spell_GrainStorm`, `Spell_HotDogRain`).
    - **Targeted Spells**: Spawns a draggable targeting arrow from hand to target creature or lane (e.g. `Spell_ScrollOfBadBreath`, `Spell_Teleport`).
  - Expended spells trigger a dissolve particle animation and move to `player_discard_pile`.
- **Acceptance Criteria**:
  - [ ] All 48 spells in `db_Spells.json` can be cast with valid targeting.
  - [ ] Magic Points deducted; spells move to discard pile upon completion.

### Task 2.3: Building Cards System
- **Unity Reference**: `db_Buildings.json`, `BuildingScript.cs`, `DestroyBuildingLane.cs`.
- **Godot Implementation**:
  - Each `LaneSlot.tscn` gains a `BuildingSlot` sub-node behind the creature slot.
  - Placing a building occupies the slot; applies continuous aura to the creature in that lane.
  - Buildings possess their own DEF or stay active until destroyed by opposing spells/abilities.
- **Acceptance Criteria**:
  - [ ] Building cards can be placed in empty building slots of any lane.
  - [ ] Passive lane bonuses (ATK/DEF) update dynamically when creatures enter/leave the lane.

### Task 2.4: Landscape Affinity Enforcer
- **Unity Reference**: `db_Creatures.json` (`Faction` field), `LandscapeType.cs`.
- **Godot Implementation**:
  - When dragging or selecting a creature card:
    - If `card.faction == "Universal"`: valid on all 4 lanes.
    - If `card.faction != "Universal"`: valid **only** on lanes where `lane.landscape == card.faction`.
  - Visual feedback: Incompatible lanes display dimmed red border; compatible lanes display pulsating green glow.
- **Acceptance Criteria**:
  - [ ] Summons rejected on mismatched landscape with user notification ("Requires Corn Landscape!").

### Task 2.5: The Battle Wheel (Roulette Minigame)
- **Unity Reference**: `BattleWheelController.cs`, `db_Leaders.json`.
- **Godot Implementation**:
  - Create `res://scenes/components/BattleWheel.tscn`.
  - Spinning needle rotates at `TimeFor1SpinMin` to `TimeFor1SpinMax` seconds per 360°.
  - Slices configured per leader from `db_Leaders.json`:
    - `Ring_P1_CritAreaRange` (default ~7% of wheel $\rightarrow$ **Critical Hit: 2x ATK Damage**).
    - `Ring_P1_HitAreaRange` (default ~80% of wheel $\rightarrow$ **Normal Hit: 1.0x ATK Damage**).
    - Remainder (~13% $\rightarrow$ **Miss / Blocked: 0 Damage**).
  - Needle stopped on Button press (`Spacebar` / `Gamepad A` / Left Click).
  - Settings toggle: `Options -> Wheel Mode [Manual / Auto / Off]`.
- **Acceptance Criteria**:
  - [ ] Wheel appears during creature clash when enabled.
  - [ ] Accurate hit detection based on needle angle; correct damage multipliers applied.

### Task 2.6: Leader Powers & Cooldown System
- **Unity Reference**: `db_Leaders.json`, `LeaderPowerScript.cs`.
- **Godot Implementation**:
  - Active Leader power button positioned next to Hero portrait.
  - Charge counter ticks down by 1 each turn start until reaching 0 ("READY!").
  - Leader Powers:
    - **Finn**: *Gain 2 Magic Points immediately*.
    - **Jake**: *All friendly Corn creatures gain +3 Attack this turn*.
    - **Princess Bubblegum**: *Heal all friendly creatures to full DEF*.
    - **Marceline**: *All friendly creatures gain +2 Attack*.
    - **BMO**: *Draw 2 additional cards and gain 1 MP*.
    - **Ice King**: *Freeze 1 opponent lane (cannot attack next turn)*.
- **Acceptance Criteria**:
  - [ ] Button activates only when cooldown == 0 and clicked during Action Phase.
  - [ ] Applies effect, plays leader voice line, resets cooldown to base value.

### Task 2.7: Tombstone & Loot Drop System
- **Unity Reference**: `CWTombstoneScript.cs`, `CreatureBattleScript.cs`.
- **Godot Implementation**:
  - When creature DEF reaches 0:
    - Play destruction VFX and spawn a Tombstone (`Tombstone.tscn`) in the lane.
    - If enemy creature: roll drop chance from `db_DropProfile.json` (spawns Gold Bag or Floating Loot Card).
    - Tombstone clears at the end of the turn.
- **Acceptance Criteria**:
  - [ ] Creature death spawns Tombstone; loot cards collected into player session inventory.

---

## Epic 3: The 317 Ability Scripts & Trigger System

*Reference: All 317 scripts in `Assets/Scripts/Assembly-CSharp/` matching ability patterns*

### Task 3.1: Trigger Event Architecture
Implement a unified ability trigger pipeline in `AbilitySystem.gd`:

```gdscript
enum Trigger {
    ON_FLOOP,         # Manual activation during Action Phase
    ON_SUMMON,        # Triggered when card enters a lane
    ON_DEATH,         # Triggered when creature DEF <= 0
    ON_TURN_START,    # Triggered at the beginning of owner's turn
    ON_TURN_END,      # Triggered at the end of owner's turn
    ON_ATTACK,        # Triggered before dealing combat damage
    STATIC_AURA       # Continuous passive effect (recalculated on board state changes)
}
```

### Task 3.2: Complete Ability Script Matrix
Implement the core behavior classes:

1. **Stat Modifiers**:
   - `ATKBonusAdjacentEmpty.cs`: +ATK if neighboring lane is empty.
   - `AdjacentDEFBonus.cs`: +DEF to creatures in left and right lanes.
   - `ATKPenaltyFaction.cs`: (e.g. *The Pig*) decreases ATK of all opposing creatures of a designated faction.
   - `SwapATKDEF.cs`: Inverts current Attack and Defense values.
2. **Board Control & Movement**:
   - `ReturnOppnentToHand.cs`: Bounces opposing creature back to enemy hand.
   - `Teleport.cs`: Shifts friendly creature to an unoccupied lane.
   - `SacrificeForMP.cs`: Destroys target friendly creature; adds `Val1` Magic Points.
3. **Card Economy**:
   - `DrawCards.cs`: Draws `Val1` cards from draw pile.
   - `ReturnDiscardCard.cs`: Opens discard pile browser; player selects card to retrieve.
   - `DamageOpponentDiscardPile.cs`: Deals direct Hero damage proportional to discard count.
4. **Hero Health Manipulators**:
   - `DamageHeroOnDeath.cs`: Deals direct damage to enemy Hero when creature dies.
   - `HealHeroATK.cs`: Restores Hero HP equal to creature's ATK value.

- **Acceptance Criteria**:
  - [ ] Ability system cleanly resolves any card's `ScriptName`, `Val1`, and `Val2` from `db_Creatures.json` without hardcoded card IDs.

---

## Epic 4: 38 Animated Character Face Rigs & Audio Engine

### Task 4.1: Character Facial Animation Rig (`CharacterFaceRig.gd`)
- **Unity Reference**: `Assets/StreamingAssets/CharacterFaceAnim/` (38 characters), `CharacterFaceAnim.cs`.
- **Format**: UV coordinate keyframes:
  ```json
  [ {"CNT":"CNT_MOUTH", "time":"0.0", "x":"0.0", "y":"0.75"}, ... ]
  ```
- **Godot Implementation**:
  - Create `CharacterFaceRig.tscn` using a `SubViewport` or `TextureRect` with custom shader mapping UV offsets.
  - Animation State Machine:
    - `IDLE`: Subtle blinking and breathing loops (`_Idle.json`, `_CardIdle.json`).
    - `PLAY_CARD`: Confident expression when summoning (`_PlayCard.json`).
    - `TAKE_DAMAGE`: Grimace and screen shake when attacked.
    - `VICTORY`: Big celebration smile (`_Happy.json`).
    - `DEFEAT`: Drinks from the Dweeb Cup (`_DweebDrink.json`, `_Defeated.json`).
  - Cover all 38 characters: *Finn, Jake, Marceline, BMO, PB, Ice King, Flame Princess, Lemongrab, Fionna, Cake, Ash, Magic Man, etc.*
- **Acceptance Criteria**:
  - [ ] Facial features animate smoothly according to original JSON timing.
  - [ ] Emote states trigger dynamically during match events.

### Task 4.2: Comprehensive Audio Engine (`AudioManager.gd`)
- **Unity Reference**: `Assets/AudioClip/` (500+ .wav files), `VOManager.cs`.
- **Godot Implementation**:
  - Route audio to 4 buses: `Master`, `Music`, `SFX`, `Voice`.
  - Implement randomized sound pools (e.g., 5 distinct card play whooshes, 3 distinct attack clangs).
  - Character Voice Lines:
    - Finn: *"Floop the pig!"*, *"Algebraic!"*, *"Mathematical!"*, perfect block audio.
    - Jake: *"Oh man!"*, *"I floop the pig!"*, defeat cries.
    - Lemongrab: *"Unacceptable!"*.
- **Acceptance Criteria**:
  - [ ] Full audio coverage across all game events with zero audio clipping or overlapping distortion.

---

## Epic 5: Gamepad Controls & Local 2-Player Multiplayer

### Task 5.1: Gamepad & Steam Deck Support
- **Godot Implementation**:
  - Define Godot `InputMap` actions: `ui_up`, `ui_down`, `ui_left`, `ui_right`, `game_select`, `game_floop`, `game_inspect`, `game_attack`, `game_leader`.
  - Focus Graph:
    - D-Pad Left/Right moves cursor across cards in hand.
    - D-Pad Up shifts focus to Player Lanes 0..3.
    - D-Pad Up again shifts focus to Opponent Lanes 0..3.
  - Action Bindings:
    - `Button South (A / Cross)`: Select / Summon / Confirm.
    - `Button West (X / Square)`: Trigger Floop on selected creature.
    - `Button North (Y / Triangle)`: Zoom inspect card.
    - `R1 / RB`: Trigger Attack / End Turn.
    - `L1 / LB`: Activate Leader Power.
  - Auto-detects input hardware: displays Xbox buttons, PlayStation shapes, or Keyboard keys dynamically.
- **Acceptance Criteria**:
  - [ ] 100% of menus and gameplay accessible via controller alone without touching a mouse.
  - [ ] Verified on Steam Deck (1280x800 native resolution).

### Task 5.2: Local 2-Player Multiplayer
- **Modes**:
  1. **Shared Screen (Dual Controllers)**:
     - Player 1 commands bottom lanes with Gamepad 1.
     - Player 2 commands top lanes with Gamepad 2.
     - Split camera view / symmetric UI.
  2. **Pass & Play (Hotseat / Single Device)**:
     - Alternating turns with intermediate privacy screen: *"Pass device to Player 2 - Press A when ready"* to protect hand secrets.
  - Custom match setup screen: Select decks, leaders, and landscapes for both players.
- **Acceptance Criteria**:
  - [ ] Two players can complete a full 1v1 match on a single PC or Steam Deck.

---

## Epic 6: Deck Building, Fusion, Quality & Inventory

### Task 6.1: Deck Builder Interface (`DeckBuilder.tscn`)
- **Unity Reference**: `CWDeckBuildDeckController.cs`, `db_Decks.json`.
- **Godot Implementation**:
  - Grid view of owned cards with pagination/scrolling.
  - Filters: Faction (Corn, Plains, Cotton, Sand, Swamp, Universal), Card Type (Creature, Spell, Building), MP Cost (1 to 5+).
  - Live deck stats: Mana curve bar chart, Creature/Spell/Building ratio, total card count (10 to 25 cards).
  - Validation: Prevents saving illegal decks (< 10 cards, > 25 cards, or > 4 copies of any single card).
- **Acceptance Criteria**:
  - [ ] Players can construct, rename, and save custom decks to `user://decks/*.json`.

### Task 6.2: Card Quality & Fusion Engine
- **Unity Reference**: `Quality.cs`, `db_Fusion.json` (204 recipes).
- **Godot Implementation**:
  - Quality tiers: **Standard $\rightarrow$ Gold $\rightarrow$ Obsidian**.
  - Gold cards receive +10% base ATK/DEF and gold foil card frame shader.
  - Obsidian cards receive +25% base ATK/DEF and dark animated obsidian shader.
  - Fusion Screen: Player selects recipe from `db_Fusion.json`, consumes duplicate base cards + gold coins, outputs upgraded card.
- **Acceptance Criteria**:
  - [ ] Card fusion correctly consumes materials and adds upgraded card to inventory.

---

## Epic 7: Campaign, Quests & Game Modes

### Task 7.1: Main Campaign Quest Map (`QuestMap.tscn`)
- **Unity Reference**: `CWMapController.cs`, `db_Quest.json` (346 Quests).
- **Godot Implementation**:
  - Interactive Land of Ooo map with 346 quest nodes.
  - Roads draw and unlock upon victory.
  - Reads opponent deck, leader, and hero dialogue from `db_Quest.json`.
- **Acceptance Criteria**:
  - [ ] Progression unlocks nodes sequentially; victory records stars and drops loot.

### Task 7.2: 3-Star Quest Objectives (`db_QuestConditions.json`)
- **Godot Implementation**:
  - Evaluates match stats against `db_QuestConditions.json` conditions:
    - *Star 1*: Win the battle.
    - *Star 2*: Win without using Floops / Win in $\le 5$ turns / Win with only Corn cards.
    - *Star 3*: Finish with $\ge 15$ Hero HP.
  - Star totals unlock bonus reward chests on the world map.
- **Acceptance Criteria**:
  - [ ] Post-battle screen audits objectives and awards 1-3 stars accurately.

### Task 7.3: Fionna & Cake Expansion (`db_FCMap.json`)
- **Godot Implementation**:
  - Toggle map button switching between "Land of Ooo" and "Fionna & Cake World".
  - Features Candy landscapes and unique Fionna & Cake leaders and cards.
- **Acceptance Criteria**:
  - [ ] 10-node campaign map with authentic Fionna & Cake opponents and rewards.

### Task 7.4: Daily Dungeons & El Fisto Arena
- **Unity Reference**: `db_Dungeon.json`, `db_ElFisto.json`.
- **Godot Implementation**:
  - **7 Daily Dungeons**: Rotate based on day of the week (Monday Plains through Sunday Double Coins).
  - **El Fisto Arena**: 8-round survival ladder where damage carries over between consecutive battles.
- **Acceptance Criteria**:
  - [ ] Daily dungeons unlock on corresponding system days; El Fisto gauntlet tracks consecutive wins.

---

## Epic 8: Economy, Gacha Chests & Progression

### Task 8.1: In-Game Economy & Progression
- **100% Free / Zero Real-Money Transactions**:
  - **Gold Coins**: Earned from completing battles and selling duplicate cards.
  - **Algebraic Gems**: Earned from earning 3-star quest ratings and completing dungeon milestones.
  - **Hero XP & Levels** (`db_RankUp.json`): Leaders level up from 1 to 50, unlocking higher base HP and upgraded abilities.
- **Acceptance Criteria**:
  - [ ] Coins and gems balance updates in header; hero levels persist across sessions.

### Task 8.2: Chest Opening Gacha System (`db_GachaWeights.json`)
- **Godot Implementation**:
  - **Cool Chest** (Costs Gold Coins): Common, Rare, and Very Rare cards.
  - **Algebraic Chest** (Costs Gems): Guaranteed Rare or Algebraic cards.
  - Animated 3D/2D chest opening sequence: Chest shakes, bursts open with light rays, cards flip over with rarity color bursts.
- **Acceptance Criteria**:
  - [ ] Correctly rolls drop rates from `db_GachaWeights.json`; adds acquired cards to inventory.

---

## Epic 9: UI, Localization, Settings & Multiplatform CI/CD

### Task 9.1: Multilingual Localization System
- **Original Language Files**: `Assets/Resources/languages/`
  - English (`EN`), German (`DE`), Spanish (`ES`), French (`FR`), Italian (`IT`), Portuguese (`PT`), Latin American Spanish (`LatAm`).
- **Godot Implementation**:
  - Parse language byte files into JSON dictionaries under `godot/data/languages/`.
  - Setting dropdown switches active language dynamically across all cards, dialogs, and menus.
- **Acceptance Criteria**:
  - [ ] 100% of in-game text translates immediately upon language selection.

### Task 9.2: Settings & Accessibility Menu
- **Godot Implementation**:
  - Graphics: Fullscreen, Windowed, Borderless, VSync, Resolution (including 1280x800 for Steam Deck).
  - Audio: Master, Music, SFX, Voice volume sliders.
  - Gameplay: Fast Combat Animation Toggle (1x, 1.5x, 2x), Auto Battle Wheel toggle.
- **Acceptance Criteria**:
  - [ ] Settings persist to `user://settings.cfg`.

### Task 9.3: Automated Multiplatform CI/CD (Zero Licenses Required)
- **Godot Implementation**:
  - Configure Godot export presets (`export_presets.cfg`):
    - Linux/X11 (`CardWars.x86_64`)
    - Windows Desktop (`CardWars.exe`)
    - macOS (`CardWars.app`)
  - Create `.github/workflows/godot-build-and-release.yml`:
    - Uses official headless Godot 4 builder (requires **zero licenses, zero activation files, zero serials**).
    - Automatically packages Linux build into single-file portable `CardWars-x86_64.AppImage`.
    - Creates GitHub Releases on tag push (`v*`).
- **Acceptance Criteria**:
  - [ ] Pushing a tag automatically produces downloadable Linux AppImage, Windows zip, and macOS zip releases on GitHub.

---

## 12. Milestone Roadmap & Implementation Order

```mermaid
flowchart TD
    M1["Milestone 1: Combat Depth<br>(Spells, Buildings, Landscape Rules, Battle Wheel)"] --> M2["Milestone 2: Controls & Audio<br>(Gamepad, Local 2P Multiplayer, SFX, 38 Face Rigs)"]
    M2 --> M3["Milestone 3: Deck Builder & Progression<br>(Deck Editor, Quality Fusion, Inventory)"]
    M3 --> M4["Milestone 4: Full Campaign & Modes<br>(346 Quests, Fionna & Cake, Daily Dungeons, El Fisto)"]
    M4 --> M5["Milestone 5: Economy, Polish & Releases<br>(Chests, Localization, Settings, Multiplatform AppImage)"]
```
