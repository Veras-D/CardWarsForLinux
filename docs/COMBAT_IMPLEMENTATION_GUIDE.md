# Card Wars Combat Overhaul — Specification, Code Audit & Implementation Guide

> **Purpose**: This document synthesizes (1) all **31 original-game reference screenshots**, (2) a direct audit of the **original Unity source code, blueprints, and scene wiring** in `Assets/`, and (3) a direct debug & code audit of the **current Godot implementation** in `godot/`, producing an exact specification and milestone plan to implement Combat properly in Godot 4.

---

## 1. Executive Gap Summary (Current Godot vs Original Unity)

When launching [`godot/scenes/battle.tscn`](../godot/scenes/battle.tscn) today (`Godot v4.7.2.stable`), the scene loads without parse errors (noting **6 ObjectDB leaks / 3 resources in use at exit** during `--headless --quit-after 3`), but **the visual presentation, 3D staging, audio switching, intro sequence, and core turn/combat fidelity diverge significantly from the original game**:

| Area | Current Godot Implementation (`godot/`) | Original Unity Implementation (`Assets/`) & Screenshots |
| :--- | :--- | :--- |
| **Battle Stage** | Flat 2D dark-blue `Panel` (`Control` root) with flat 2D `LaneSlot` cards | **Full 3D Treehouse (or Quest Arena) Table**, hex game board, 3D seated opponent across the table (`CharacterAnimController`), 3D player character in wide shots, dynamic 3D cameras |
| **Pre-Battle Intro** | [`MatchIntro.gd`](../godot/src/battle/MatchIntro.gd): 2D VS portrait popup with static strings (`"I'm gonna kick your butt..."`) & `Start` button | [`CWBattleIntroController.cs`](../Assets/Scripts/Assembly-CSharp/CWBattleIntroController.cs): 3D wide-angle camera sweep (`introCameraClips`), Jake & Finn holding cards & playing `IntroP1`/`IntroP2` → `CardIdle`, crossed sword+shield **`BATTLE!`** banner, then **`Tree House`** arena banner (Screenshots 1–2) |
| **Battle Music (BGM)** | [`BattleController.gd`](../godot/src/battle/BattleController.gd#L246-L251) tries `res://assets/audio/bgm/<player_hero_name>.wav` and falls back to `MainMenu.wav`! Only `Finn.wav`, `Jake.wav`, `MainMenu.wav` exist in `godot/assets/audio/bgm/`. | [`BattleJukeboxScript.cs`](../Assets/Scripts/Assembly-CSharp/BattleJukeboxScript.cs) + [`BattleScene.unity`](../Assets/Scene/_hirez/Scenes/BattleScene.unity): Plays `BattleIntroTheme` (`SFX_Intro_Battle.wav`) during intro, then switches cleanly via `jukebox.Refresh()` to **Opponent's `BattleMusic`** (`Finn`, `Jake`, `BMO`, `Bubblegum`, `IceKing`, `Lemongrab`, `Marceline` from `db_Characters.json` — all present in `Assets/AudioClip/`), and switches to `BattleEndTheme` (`LSP.wav`) on match end! |
| **Landscape Placement** | Auto-assigned statically in `setup_match()` with no player choice or animation | **Interactive `"Place Your Landscapes"` Phase** (`LandscapeManagerScript`, `CWLandscapeFillCards`, `CWLandscapeCardDragOld`): Top-down view over empty blue hex grid, 4 landscape cards below, yellow finger swipe tutorial, drag-to-lane yellow hex glow & 3D terrain sprouting (Screenshots 0 & 3) |
| **Turn-Order Resolution** | [`RockPaperScissors.gd`](../godot/src/battle/RockPaperScissors.gd): Generic 2D Rock-Paper-Scissors modal (`✊ ROCK / ✋ PAPER / ✌️ SCISSORS`) | **3D Ketchup Bottle Spinner** ([`CWKetchupBottleScript.cs`](../Assets/Scripts/Assembly-CSharp/CWKetchupBottleScript.cs)): Overhead board view with Ketchup bottle on seam, upward yellow swipe finger (`"Swipe Finger to Spin"`), physics spin deceleration pointing toward winner, `"[Player] goes first!"` + `"Tap anywhere on the screen"` (Screenshots 4–5) |
| **Turn 1 & Magic Rules** | Allows attacking on Turn 1; increments `player_max_mp` on every player turn; AI draws/plays straight from `opponent_draw_pile` with no MP tracking or opponent hand | [`BattleManagerScript.cs`](../Assets/Scripts/Assembly-CSharp/BattleManagerScript.cs#L77), [`CWP1SetupBranch.cs`](../Assets/Scripts/Assembly-CSharp/CWP1SetupBranch.cs#L41), [`CWOpponentActionSequencer.cs`](../Assets/Scripts/Assembly-CSharp/CWOpponentActionSequencer.cs#L93): **No Attack on Turn 1** (`Turn <= 1` skips Battle Phase); `Starting_Magic_Points = 2` up to `Max_Magic_Points = 10` incrementing when `FirstPlayer` ends turn ([`GameState.cs`](../Assets/Scripts/Assembly-CSharp/GameState.cs#L1989)) |
| **Battle HUD & Modals** | Top HP bars + flat hand scroll + `⚔️ ATTACK!` button | Corner Player/Opponent HUDs (Portrait, HP bar/text, Magic count, `X TURNS` / `READY!` hero cooldown), Left Skull/Chest & Coin counters + Draw/Discard stacks, Overlapping curved hand cards, Right Magic Orb & green **`BATTLE!`** shield button, Star Quest (`★`) & Pause (`||`) buttons, Horizontal Card/Building Info bars, `Floop` & `Hero Ability` `Yes`/`No` prompts, `Player's Discard Pile`, `Current Quest` (`Achievable`), `Leave this Battle?` pause dialog (Screenshots 6–7, 12–15, 20–23) |
| **3D Board Entities & Cameras** | 2D `CardView` inside 2D `Panel` slots; no camera movement | 3D terrain tiles per lane (`Corn`, `Cotton`, `Plains`, `Sand`, `Swamp`), **203 Creature** & **35 Building** 3D models (`Assets/Resources/summons/`, `Assets/Resources/building/`), floating billboard HP/ATK/buff displays, 3D green **`FLOOP`** buttons, angled summon zoom camera & split/angled battle camera (`CWiTweenBattleCam`, `CWBattleSequenceCam`) (Screenshots 6–9, 18, 22) |
| **Battle Wheel & Combat** | [`BattleWheelModal.gd`](../godot/src/battle/BattleWheelModal.gd): Centered 2D popup; always Attack wheel only; AI auto-quick-resolves without a Defend Wheel! | [`CWBattleSequenceController.cs`](../Assets/Scripts/Assembly-CSharp/CWBattleSequenceController.cs) + [`db_Leaders.json`](../godot/data/db_Leaders.json): 3D split/angled lane camera + ring widget at bottom-center; **P1 Attack Wheel** (`Tap to Attack!`, huge Hit+Crit green sectors) AND **P2 Defend Wheel** (`Tap to Defend!`, narrow Crit/Block green sectors + miss brown/red sectors); Direct Hero Attack red flash & banner; `ATTACK x1` / `MISS!` comic popups & creature hit/lunge animations (Screenshots 8–11, 16–17) |
| **Post-Match Rewards & Chests** | [`BattleResultModal.gd`](../godot/src/ui/BattleResultModal.gd): Single generic 2D dark dialog listing stars/coins/cards | **Staged 5-step sequence**: **`K.O.`** banner & defeated pose → **`You leveled up [Hero]`** modal → **`Quest Rewards`** modal (Coins, XP bar, 3-star plaque, `x N Loot`) → **3D Chest Loot Floor (`TAP chests to unlock!`)** with chest opening, card spinning out (`CardFlap`/`CardReveal`) & reveal → **`JAKE'S PRO TIP`** modal → return to Map (Screenshots 24–30) |

---

## 2. Screenshot-by-Screenshot Master Checklist (31 Reference Screens)

1. **Screenshot 0 (Baseline comparison)**: Empty 3D board table on green Treehouse cloth with blue hex grid, brown wooden border w/ gold corners, `"Place Your Landscapes"` translucent pill, 4 landscape cards across the bottom (`Corn Fields`, `Nice Lands`).
2. **Screenshot 1 (Intro Beat 1 — Clash)**: Wide 3D Treehouse table shot; Player Hero (Jake) seated left on stool, Opponent Hero (Finn) seated right on stool, 3D arena props (soda bottle, mugs, chips, couch, stove, wall tree geometry), giant crossed sword+shield **`BATTLE!`** crest center-screen.
3. **Screenshot 2 (Intro Beat 2 — Venue)**: Wide 3D Treehouse view with both characters picking up/holding red CW card fans (`HoldCards`), top-center dark rounded translucent **`Tree House`** location banner.
4. **Screenshot 3 (Landscape Drag Placement)**: Dragging landscape card upward highlights target lane column in pulsing yellow over the hex grid with sprouting corn/grass previews and upward-pointing yellow swipe hand guide.
5. **Screenshot 4 (Ketchup Bottle Turn Spin)**: Full 8-lane tabletop view (blue enemy lanes top row, placed player Corn/NiceLands bottom row), 3D Ketchup Bottle horizontal on center table crease, upward swipe finger + `"Swipe Finger to Spin"` banner.
6. **Screenshot 5 (Spin Result)**: Ketchup bottle rotated pointing at winner (`Finn` or `Jake`), dim screen with `"Tap anywhere on the screen"` middle prompt and `"Finn goes first!"` bottom banner.
7. **Screenshot 6 (Main Setup HUD & 3D Board)**:
   - Top-left Player HUD: Blue HP bar + `HP 15`, Jake portrait, Purple Magic counter `2`, Cooldown pill `2 TURNS`.
   - Top-right Opponent HUD: Orange/Red HP bar + `15`, Purple Magic `1`, Finn portrait, Cooldown pill `4 TURNS`.
   - Bottom Tray: Left Skull/Chest counter (`0`), Coin counter (`0`), Red CW Draw Deck (`7`), Discard Pile (`0`); Curved/overlapping hand cards centered; Right Magic Orb (`2`) + Green **`BATTLE!`** crossed-swords button.
   - 3D Board: Opponent creatures spawned in lanes with billboard `7/7` bars + floating red/orange ATK gem badges (`1`), player 3D **`FLOOP`** circular pads (`+` / glow).
8. **Screenshot 7 (Summon Camera & Card Info Banner)**: Camera zooms low over the placed lane behind/beside newly summoned creature (`Mouthball`), glowing hex borders on lane, horizontal bottom Card Info Bar showing Name (`Mouthball`), Rainbow faction icon, Ability text, `3 ATK`, `Creature`, `3 DEF`.
9. **Screenshot 8 (Attack Spin Wheel — P1 Battle)**: Angled 3D behind-the-shoulder duel view of player creature (`Mouthball` `3` `3/3`) vs enemy (`1` `7/7`), large circular **Attack Wheel** (`Crit` neon green, `Hit` dark green, reddish-brown remainder, sword needle), **`Tap to Attack!`** text above.
10. **Screenshot 9 (Defend Spin Wheel — P2 Battle)**: Angled 3D defense view with enemy creature glowing/charging (`+4`), 4-sector **Defend Wheel** (narrow neon-green Counter/Crit + dark-green Block segments, wide miss segments, CW shield pointer), **`Tap to Defend!`** text.
11. **Screenshot 10 (Direct Hero Attack)**: Empty opposing lane bursts red/orange when hit directly; top-center Jake banner: `"Whoah, man! You didn't have any creatures defending your lane so your Hero took some damage."`; Hero HP bar animates down (`15 -> 14`).
12. **Screenshot 11 (Creature Combat Impact)**: Giant yellow comic **`ATTACK x1`** text over target creature + floating red `-1` damage number + HP bar drop (`3/3 -> 2/3`).
13. **Screenshot 12 (In-Turn Action Overlay & Quick Buttons)**: Mid-left circular blue Star **Quest Info** button (`★`), mid-right circular **Pause** button (`||`), yellow glowing valid lane strips on valid Corn/NiceLands lanes while playing card from hand, green `FLOOP` floor buttons visible under eligible creatures.
14. **Screenshot 13 (`Your Turn` Draw Banner)**: Golden sunburst + red ribbon **`Your Turn`** banner mid-screen with oversized red `CW` card flipping out for turn draw.
15. **Screenshot 14 (Floop Confirmation & `READY!` Hero Badge)**:
    - Top horizontal Floop Info Card: Card Name (`Cornball`), Art, Effect (`"+1 Attack."`), Footer (`"Floop Ability"`).
    - Bottom prompt: Red **`No`** button | `"Floop the Cornball?"` | Green **`Yes`** button w/ purple cost gem (`2`).
    - Top-left Hero HUD shows glowing blue **`READY!`** flame badge when cooldown hits `0`.
16. **Screenshot 15 (Hero Ability Confirmation)**:
    - Top horizontal Hero Info Bar (`Jake`, `"(3 Turns) All your Corn creatures gain +3 Attack."`, `0` cooldown badge, `"Hero Ability"`).
    - Bottom prompt: Red **`No`** button | `"Activate?"` | Green **`Yes`** button.
17. **Screenshot 16 (Buffed Combat State)**: Pink buff callouts (`+5`, `+3`) & raised stats (`5/5`, `4/5`, `3/7`) rendered cleanly on lane creatures during combat wheels.
18. **Screenshot 17 (`MISS!` Outcome)**: Yellow-bordered comic **`MISS!`** burst on missed attack/defense spin + attack lunge animation.
19. **Screenshot 18 (3D Buildings Alongside Creatures)**: 3D Building meshes (`Sand Pyramid` / `Comfy Cave` / towers behind creature slot in same lane) visible on the table during setup & battle cameras.
20. **Screenshot 19 (`Opponent's Turn` Banner)**: Blue ribbon + skull-and-crossbones **`Opponent's Turn`** banner over board when AI turn starts.
21. **Screenshot 20 (`Current Quest` Modal)**: Gold plaque title (`Current Quest`), framed blue panel displaying quest objective (`"Beat the opponent without using Spell cards. / Spell Cards Used: 0"`), `"Achievable"` green status pill + 3 star slots + close `X`.
22. **Screenshot 21 (`Leave this Battle?` Pause Modal)**: Blue Card Wars framed modal with `"Leave this Battle?"`, warning copy (`"All coins, chests and XP collected will be lost if you return to the main menu."`), green **`QUIT`**, red **`DON'T QUIT`**.
23. **Screenshot 22 (Building Tap Inspection)**: Angled 3D close-up on lane holding building (`Comfy Cave`) + horizontal rainbow-framed Building Info Bar (`Comfy Cave`, `"Creature in this lane heals 2 Damage for each creature you control at start of turn."`, `"Building"`).
24. **Screenshot 23 (`Player's Discard Pile` Modal)**: Blue framed scroll/grid modal titled `"Player's Discard Pile"` showing full card tiles for discarded cards + close `X`.
25. **Screenshot 24 (`K.O.` Match Finish)**: Giant comic **`K.O.`** burst on lethal blow (`0 HP`) with defeated hero slumping back in chair + end battle camera switch.
26. **Screenshot 25 (`You leveled up [Hero]` Modal)**: Framed popup with Hero card on left (`Level 2`, `Max HP is now 20`, `Max Deck Size is now 16`), top banner (`"You leveled up Jake. Increasing Jake's Level increases your Max HP and Max Deck Size!"`).
27. **Screenshot 26 (`Quest Rewards` Modal)**: Framed panel showing `Quest 1`, `Coins Earned`, `XP Earned` + progress bar + `XP to next level`, `Quest Star Awarded!` (3 large stars), green **`x 1 Loot`** (chest count) button.
28. **Screenshot 27 (3D Post-Match Chest Floor)**: Green Treehouse table with hex board showing **3D Chest(s)** sitting on glowing hex pedestals, `"TAP chests to unlock!"` top banner, Hero sitting in background.
29. **Screenshot 28 (3D Chest Opening & Card Spin)**: 3D chest lid pops open with burst light/particles; 3D red `CW` card spirals forward out of chest toward camera.
30. **Screenshot 29 (Revealed Loot Card)**: Card flips upright front-and-center (`Heavenly Gazer`), crisp readable card face + `"Tap anywhere on the Screen"`.
31. **Screenshot 30 (`JAKE'S PRO TIP` Closing Screen)**: Framed tip panel (`"JAKE'S PRO TIP"`, tip text e.g. `"Homies help homies, so tell your homies about Card Wars."`) + big green **`OK`** button before returning to map.

---

## 3. Architecture & Systems Separation (`GEMINI.md` Compliance)

Per [`GEMINI.md`](../GEMINI.md), generic systems in [`godot/src/systems/`](../godot/src/systems/) **must remain 100% Card-Wars-agnostic** (relative `preload(...)`, dedicated `README.md`, standalone `testbed_*.tscn`), while [`godot/src/battle/`](../godot/src/battle/) and [`godot/scenes/`](../godot/scenes/) compose them with Card Wars 3D meshes, HUD styling, blueprints, and audio:

- **Generic Modules to Reuse / Extend cleanly (NO Card Wars names inside `systems/`)**:
  - `timing_wheel/` ([`WheelSpinner.gd`](../godot/src/systems/timing_wheel/WheelSpinner.gd), [`WheelConfig.gd`](../godot/src/systems/timing_wheel/WheelConfig.gd)): Already supports arbitrary custom `sectors` (`ratio`, `color`, `multiplier`, `is_success`), `clockwise`, `spin_speed_deg_sec`, and `quick_resolve`. We can add optional sector offset randomization (`start_angle_deg`) and textured rim support cleanly in `WheelSpinner.gd` while keeping `testbed_wheel.tscn` working and generic.
  - `board_system/`, `deck_engine/`, `ability_engine/`, `audio_jukebox/`, `progression_engine/`, `local_multiplayer/`, `network_multiplayer/`, `node_map_system/` (`StarConditionEvaluator`): Remain intact as clean contracts; Multiplayer (`is_network_match` / `TurnActionProtocol` & `is_local_versus` / `HotseatCurtain`) must keep working alongside the new 3D stage and HUD.
- **Card Wars Composition Layer (`godot/src/battle/`, `godot/scenes/`)**:
  - New/Upgraded 3D Battle Arena controller (`BattleArena3D.gd` + `BattleCameraRig.gd`) hosting the 3D Treehouse environment, seated Hero/Opponent 3D models, hex game board, 4x2 3D lane terrains, 3D creature/building meshes, 3D tombstones/chests, and 3D Ketchup Bottle turn spinner.
  - Upgraded `BattleController.gd` + `BattleHUD.gd` + `BattleWheelOverlay` matching Unity's exact phases (`BattlePhase`), Turn 1 No-Attack rule, MP ramp rule, AI Hand + MP budget, Floop/Leader confirmation banners, Card Info bars, Discard Viewer, Quest Objective Modal, Pause Modal, and the 5-step Post-Match sequence (`K.O.` → Level Up → Quest Rewards → 3D Chest Loot Floor → Jake's Pro Tip).

---

## 4. Assets & Audio Inventory (What Exists vs What Needs Extraction)

1. **BGM & Battle Music Tracks (`BattleJukeboxScript.cs` + `BattleScene.unity` verified)**:
   - Already in `godot/assets/audio/bgm/`: `Finn.wav`, `Jake.wav`, `MainMenu.wav`.
   - Copy from `Assets/AudioClip/` into `godot/assets/audio/bgm/`:
     - `BMO.wav`, `Bubblegum.wav`, `IceKing.wav`, `Lemongrab.wav`, `LSP.wav` (**BattleEndTheme**!), `Marceline.wav`, `FC_MapMenu.wav`.
   - **Mapping Rule (`BattleJukeboxScript.Refresh()`)**: Read opponent's `BattleMusic` field from [`db_Characters.json`](../godot/data/db_Characters.json) (`Finn`, `Jake`, `BMO`, `Bubblegum`, `IceKing`, `Lemongrab`, `Marceline`, `"Fire"` -> fallback `Finn.wav` since `Fire.wav` does not exist in `Assets/AudioClip/`). Play `SFX_Intro_Battle.wav` (already in `godot/assets/audio/sfx/`) when battle intro begins, switch to Opponent `BattleMusic` when intro completes, and switch to `LSP.wav` (`BattleEndTheme`) on match victory/defeat.
2. **SFX Already Present in `godot/assets/audio/sfx/`**:
   - `SFX_Intro_Battle.wav`, `SFX_Banner_Battle.wav`, `FX_BattleRing_Drop.wav`, `FX_BattleRing_Timer.wav`, `FX_BattleRing_Hit.wav`, `FX_BattleRing_Crit.wav`, `FX_BattleRing_Miss.wav`, `FX_BattleRing_Damage_Hit.wav`, `FX_BattleRing_Damage_Crit.wav`, `FX_BattleRing_Damage_Block.wav`, `FX_Battle_FloopAnimation.wav`, `FX_Battle_AttackUp.wav`, `FX_Battle_AttackDown.wav`, `FX_Battle_DefenseUp.wav`, `FX_Battle_DefenseDown.wav`, `FX_Battle_HealthUp.wav`, `FX_Battle_Helpless.wav`, `FX_Battle_Protection.wav`, `FX_Battle_BlockSummon.wav`, `FX_BattleEnd_P1Win.wav`, `FX_BattleEnd_P1Lose.wav`, `FX_BattleEnd_Defeat.wav`, `FX_BattleEnd_DefeatHit.wav`, `FX_BattleEnd_LevelUp.wav`, `FX_BattleEnd_XPGain.wav`, `FX_BattleEnd_CardFlap.wav`, `FX_BattleEnd_CardReveal.wav`, `FX_BattleEnd_PanelTween.wav`, `FX_LootDrop_ChestOpen_LootAfterBattle.wav`.
   - Copy missing card/combat SFX from `Assets/AudioClip/`: `CardMove.wav`, `Card_Pick.wav`, `Cancel.wav`, `CreatureDeath.wav`, `FX_TriggerLeaderAbility.wav`, `GUI_Battle_ReshuffleCard.wav`.
3. **3D Models & Arena Props (`godot/assets/models/` vs `Assets/`)**:
   - **Already in Godot** (`treehouse_menu_3d.tscn` uses them!): `TreeFort_FloorCeiling.obj`, `TreeFort_Furniture.obj`, `TreeFort_Alphas.obj`, `TreeFort_Table.obj`, `TreeFort_Table_Objects.obj`, `TreeFort_Chair.obj`, `GameBoard_Boarder.obj`, `GameBoardGrid_Red.obj`, `GameBoardGrid_Blue.obj`, `Finn_Sitting.obj`, `Jake_Sitting.obj`, `Finn_Face.obj`, `Jake_Face.obj`, `Finn_CardsHand.obj`, `Jake_CardsHand.obj`, `chests/algebraic/*`, `chests/cool/*`.
   - **Need Conversion / Extraction via `scripts/unity_extractor/unity_mesh.py` & `unity_atlas.py`**:
     - **3D Landscapes**: `Assets/Mesh/Corn1..4.asset` + `_Corn` crops, plus `Cotton`, `Plains`, `Sand`, `Swamp` lane terrains & textures.
     - **203 Creature Models** (`Assets/Resources/summons/` + `Assets/Mesh/` + `Assets/Texture2D/`) and **35 Building Models** (`Assets/Resources/building/` + `Assets/Mesh/` + `Assets/Texture2D/`), plus additional opponent Hero seated/idle meshes (BMO, Bubblegum, Ice King, Marceline, LSP, Lemongrab, Flame Princess, etc.) cleanly batch-exported to `godot/assets/models/summons/`, `godot/assets/models/buildings/`, `godot/assets/models/characters/` with safe billboard/sprite fallback if any creature mesh lacks texture/geometry.
     - **3D Props & Atlases**: Ketchup Bottle / FC Spinners (`Spinner_Ketchup`, `Spinner_Sword`, `Spinner_Pizza`, `Spinner_Hotdog`, `Spinner_Fish`, `Spinner_Shard`), Battle Banners (`YourTurn_Banner`, `OpponentsTurn_Banner`, `YouWin_Banner`, `YouLose_Banner`), `Battle_Banners_Atlas.png`, `BattleRingAtlas.png`, `BannersAtlas.png`, `GUIAtlas*.png`.
   - Also investigate & resolve the **6 ObjectDB / 3 resource leaks** in `battle.tscn` / autoloads on exit.

---

## 5. Unity-Parity Rebuild Plan (3 Stages)

> **Strict Original-Asset Rule**: Zero homemade placeholder meshes, `StyleBoxFlat` panels, or approximated UI. Every 3D environment/character/prop/FX/card model, animation curve, NGUI atlas frame, and audio track must come directly from original Unity assets (`Assets/`) via [`scripts/unity_extractor/`](../scripts/unity_extractor/). Reference gameplay recording: `~/Videos/Video_2026-11-17_05-31-33.mp4`.

### Stage 1: 3D Battle Arena, Rigged Characters, Intro Sequence & Audio (Implemented + Audited vs Video `0:03–0:21`)
- **Pure-Python Unity Exporter (`scripts/unity_extractor/`)**:
  - [`unity_glb.py`](../scripts/unity_extractor/unity_glb.py) + [`unity_mesh.py`](../scripts/unity_extractor/unity_mesh.py) + [`export_battle_stage1.py`](../scripts/unity_extractor/export_battle_stage1.py) export skinned `Skeleton3D` `.glb` rigs + `.anim` clips + unlit multi-submesh materials and Hermite camera splines (`BattleIntroAnims.gd`) cleanly at `0.05` scale (`S_Z` reflected).
- **Extracted Stage 1 Assets**:
  - `51/51` rigged & animated hero `.glb`s (`godot/assets/models/battle/characters/`).
  - `43/44` environments, tables & chairs `.glb`s (`godot/assets/models/battle/environments/`; note `LumpySpace_Chair.prefab` is absent from `Assets/Resources/environment/`).
  - `Battle_Battle.glb` (`BattleScene.unity` GO `787` + `Take 001_15.anim` crossed Sword/Shield/Lightning/`BATTLE!` banner).
  - `HoldCards.glb` (7-card fanned hand on `hand` bone) & `PlayingCard.glb` (single played card on `"Puppet_CardPlay"` per `CWCharacterAnimController.cs:72-98`).
  - `BattleIntroAnims.gd` (`BattleIntro_CUT1..4.anim`: `1.333s`, `1.567s`, `2.033s`, `1.167s`).
  - `GameBoardGrid_FX.obj` + `FX_Scan_Hex_Solid.png` / `HexAnim.png` for hex lane highlights; `FloopPanel_BG.png` 9-slice banners; BGM & intro SFX (`SFX_Intro_Battle.wav`, Opponent `BattleMusic`).
- **Audit vs Original Video (`Video_2026-11-17_05-31-33.mp4` `0:03–0:21`)**:
  - **Verified matching**: Treehouse stage, `GameBoard` 180° Y orientation (Blue left P1, Brown right P2), `BattleIntro_CUT1..4` (`FOV 60`) camera choreography, Jake/Finn card pickup + `PlayingCard` in raised hand (`Puppet_CardPlay`), `M_MOUTH` / `M_EYES` 4×4 face UV stepping, localized `"Tree House"` / `"Candy Kingdom"` / `"Hunson Abadeer"` banners, and `Battle_Battle.glb` (`Take 001_15`).
  - **Remaining Stage 1 Polish (carry into Stage 2 entry)**:
    - Tighten `Phase1` (`ArenaName`), `BG_RootP1`, `BG_RootP2` `NinePatchRect` dimensions/padding to match `BattleScene.unity` NGUI widgets (smaller pill padding, centered-scale pop-in).
    - Smoothly tween/glide the camera from Cut 4 end pose directly into top-down Landscape Placement (`Video 0:20–0:21` / `CWP1LandscapeBranch`), instead of an abrupt camera snap; reveal `"Place Your Landscapes"` upon camera arrival.
    - Original intro has no `"Click to Skip >>"` HUD caption (hide caption while keeping click/key skip working if desired).

### Stage 2: Original Landscapes, Ketchup/FC Spinner, Main Battle HUD & In-Match Panels (Next)
- **Landscape Placement (`CWLandscapeFillCards`, `CWLandscapeCardDragOld`, `BattleScene.unity`)**:
  - Replace custom Godot landscape card widgets/buttons with exact Unity NGUI atlas frames (`GUIAtlas` / `GUIAtlas_2`), original `Swipe` finger animation + pulsing yellow hex lane highlight, and 3D terrain lane meshes/sprouting animation (`Corn`, `Cotton`, `Plains`, `Sand`, `Swamp`).
- **3D Ketchup & FC Spinners (`CWKetchupBottleScript`)**:
  - Export and wire original 3D `Spinner_Ketchup` (plus FC variants: Sword, Pizza, Hotdog, Fish, Shard) on the board seam, `"Swipe Finger to Spin"` + swipe guide, deceleration physics, and `"[Name] goes first!"` / `"Tap anywhere on the screen"` banners.
- **Battle HUD & In-Match Modals (`PanelManagerBattle`, `CWUpdatePlayerData`, `GUIAtlas*`)**:
  - Replace custom `StyleBoxFlat` HUD/modals in [`battle.tscn`](../godot/scenes/battle.tscn), `LaneSlot`, `BattleModals`, and `CardView` with authentic Unity NGUI frames/atlases: Corner Player/Opponent HUDs (HP bar/value, `CharacterFaceRig`, Magic badge, `X TURNS`/`READY!` flame), Left Chest/Coin/Draw/Discard tray, Overlapping hand cards, Right Magic Orb + **`BATTLE!`** shield, Star Quest (`★`) & Pause (`||`) quick buttons, **`Your Turn`** / **`Opponent's Turn`** draw banners, horizontal **Card/Building Info** bars, **`Floop`** & **`Hero Ability`** `Yes`/`No` confirmations, **`Current Quest`**, **`Player's Discard Pile`**, **`Leave this Battle?`**, plus `DweebCup.glb` defeat prop (`CWCharacterAnimController.cs:306`).
  - Fix [`test_face_rig.tscn`](../godot/test_face_rig.tscn) Test 6 node path failures (`PlayerFaceRig` / `OpponentFaceRig` in `battle.tscn`).

### Stage 3: Duel Cameras, Attack/Defend Battle Wheels, Combat FX & Post-Match (Final)
- **Duel Cameras & Battle Wheels (`CWBattleSequenceController`, `CWBattleSequenceCam`, `BattleRingAtlas`)**:
  - Rebuild Attack (`Tap to Attack!`) and Defend (`Tap to Defend!`) wheels strictly from Unity `BattleRingAtlas` textures, needles (`Ring_Bar_ATK`/`DEF`), hit/crit/block leader ranges (`db_Leaders.json`), and split/angled 3D duel cameras — keeping generic [`WheelSpinner.gd`](../godot/src/systems/timing_wheel/WheelSpinner.gd) Card-Wars-agnostic.
- **3D Combat Props & FX (`Assets/Resources/props/`, `BattleScene.unity`)**:
  - Original 3D Creatures (`Assets/Resources/summons/`), Buildings (`Assets/Resources/building/`), `CreatureHPBarWithATK`, red/orange buff badges, 3D green **`FLOOP`** pads, `ATTACK x1` / `CRIT x2` / `BLOCK!` / `MISS!` comic callouts, direct Hero attack red burst + warning banner, Tombstones (`P1Tombstone`/`P2Tombstone`), and spell/loot FX prefabs.
- **Post-Match Sequence (`CWBattleEndChestController`, `BattleEndTheme`)**:
  - Comic **`K.O.`** burst & defeated slump pose + `LSP.wav` transition → **`You leveled up [Hero]`** → **`Quest Rewards`** → **3D Chest Loot Floor** (`TAP chests to unlock!`, `LootChest_*` opening + spinning card reveal) → **`JAKE'S PRO TIP`** → return to map cleanly.
- **Verification & Leak Audit**:
  - Resolve remaining exit `ObjectDB` / resource leaks, verify `player_profile.json` test isolation, and capture visual comparisons against `Video_2026-11-17_05-31-33.mp4` across all 3 stages.

---

## 6. Ordered Stage Checklist & Live Progress Tracker

### Stage 1 — 3D Arena, Heroes, Pre-Battle Intro & Audio
- [x] **S1.1 — Unity Scene/Prefab/Clip Exporter (`unity_glb.py`, `unity_mesh.py`, `export_battle_stage1.py`)**: Export `51/51` rigged hero `.glb`s, `43/44` arena/table/chair `.glb`s, `HoldCards.glb`, `PlayingCard.glb`, `Battle_Battle.glb` (`Take 001_15`), `GameBoardGrid_FX.obj`, and Hermite splines `BattleIntroAnims.gd`.
- [x] **S1.2 — `BattleArena3D` Stage & Dual-Hand Cards**: Dynamic quest arena/table/chair spawning, `FOV = 60.0`, `GameBoard` 180° Y orientation (Blue left / Brown right), `IntroP1`/`IntroP2` → `CardIdle`, `M_MOUTH` + `M_EYES` UV tracking, `HoldCards` (`hand` bone) + `PlayingCard` (`"Puppet_CardPlay"`).
- [x] **S1.3 — `MatchIntro` Banners & BGM**: `FloopPanel_BG.png` `NinePatchRect` banners with localized `Database.localize()` arena (`!!LEVEL_*`) & character names, 3D `Battle_Battle.glb` SubViewport overlay, and `BattleJukebox.play_intro_sequence()` → `play_battle_theme()`.
- [x] **S1.4 — Stage 1 Verification vs Original Video (`0:03–0:21`)**: Verified Quest 1 (`TreeFort`, `Jake` vs `Finn`) and Quest 31 (`Candy`, `BMO` vs `HunsonAbadeer`) visually and fixed `GameManager._open_cached_map` freed-reference crash on map roundtrip.
- [x] **S1.5 — Stage 1 Polish (from Video Audit)**: Match `Phase1` / `BG_RootP1` / `BG_RootP2` exact Unity NGUI pill dimensions/tween-in, hide non-authentic `"Click to Skip >>"` label, and add smooth Cut 4 → top-down Landscape Placement camera glide before showing Landscape cards.

### Stage 2 — Original Landscapes, Ketchup Spinner, Setup HUD & In-Match Panels
- [x] **S2.1 — Landscape Placement Assets & Logic**: Extracted `LandscapeAtlas.prefab` sprites (`Frame_Base_Landscape.png`, `Landscape_*1.png`), replaced pill `StyleBoxFlat` with `FloopPanel_BG.png`, and synced card reveal with Cut 4 → top-down camera glide.
- [x] **S2.2 — Ketchup / FC Spinners & Board Props**: Replaced `StyleBox_DarkPill` with `FloopPanel_BG.png` beneath `Spinner_Ketchup.png` / FC spinner sprites, and imported `FloopPad.glb` & `DweebCup.glb`.
- [x] **S2.3 — Battle HUD & In-Match Panels (`GUIAtlas*`)**: Extracted 57 NGUI HUD sprites, replaced all `StyleBoxFlat` HUD/modals across [`battle.tscn`](../godot/scenes/battle.tscn), [`LeaderPowerButton.tscn`](../godot/scenes/components/LeaderPowerButton.tscn), [`BattleModals.gd`](../godot/src/battle/BattleModals.gd), and [`BattleController.gd`](../godot/src/battle/BattleController.gd) (`Header` portraits/HP/MP/Turns, `StarButton`, `Pause`, `Tray_Player` + chest/coins/deck/discard/orb/`BATTLE!`, Card Info, Floop Confirm, Quest/Discard modals, creature HP bars), and fixed [`test_face_rig.tscn`](../godot/test_face_rig.tscn) (`30 PASSED, 0 FAILED`).

### Stage 3 — Duel Cameras, Attack/Defend Wheels, Combat FX & Post-Match
- [x] **S3.1 — Battle Wheel & Duel Camera Rig**: Rebuild Attack (`Tap to Attack!`) & Defend (`Tap to Defend!`) wheels using `BattleRingAtlas` assets + split/angled `CWBattleSequenceCam` framing while keeping generic `WheelSpinner.gd` decoupled.
- [x] **S3.2 — 3D Summons, Buildings, `FLOOP` Pads & Combat FX**: Wire original creature/building prefabs, `CreatureHPBarWithATK`, comic callouts (`ATTACK x1`, `CRIT x2`, `BLOCK!`, `MISS!`), Tombstones, and spell/hit FX.
- [x] **S3.3 — Post-Match Flow & Final Regression Audit**: Implement original Unity `K.O.`, Level Up, Quest Rewards, 3D Chest Loot Floor (`LootChest_*`), and `JAKE'S PRO TIP` screens; pass full headless + visual verification against `Video_2026-11-17_05-31-33.mp4` (`player_profile.json` unchanged, `0` `StyleBoxFlat` instances).
