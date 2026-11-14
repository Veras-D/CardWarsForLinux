# 3D Board Menu Icons — Reverse-Engineering & Implementation Guide

This document is the complete technical reference for how the 3D board menu icons on the Treehouse game board (`godot/scenes/treehouse_menu_3d.tscn` + `godot/scenes/main_menu.tscn`) were reverse-engineered from the original *Card Wars* Unity assets (`Assets/Scene/_hirez/Scenes/AdventureTime.unity`, `Assets/Mesh/*.asset`, `Assets/Material/*.mat`, `Assets/AnimationClip/*.anim`, and `Assets/Scripts/Assembly-CSharp/*.cs`) and implemented in Godot 4.

Use this guide whenever implementing, debugging, or modifying any 3D board prop across the **Battle**, **Deck**, **Shop (Market)**, **Daily Dungeons / Gift**, **Gacha Chests**, or **Options** menus.

---

## 1. High-Level Scene Architecture in Godot

### 1.1. 3D Hub Scene (`godot/scenes/treehouse_menu_3d.tscn` & `godot/src/ui/TreehouseMenu3D.gd`)
In the original Unity game (`AdventureTime.unity`), whenever the camera zooms down onto the Treehouse game board (`6478 Menu UI Panel`), a specific board menu container (`pos = (0, -250, 0), rot = (0.5, 0.5, -0.5, 0.5), scale = (10, 10, 10)`) is activated depending on which Hub room/button was selected:
1. **Battle Menu (`6406 F_0_QuestsMenu`)** — 3 icons (*Note: Leaderboards Trophy `6016` will NOT be implemented*):
   - **Quests** (`6014 QuestMenu_Mapbutton_Solo`)
   - **Deck Wars** (`6017 QuestMenu_Mapbutton_Multi` — **Implemented**)
   - **Fionna & Cake Adventure** (`6013 QuestMenu_Mapbutton_FionnaCake` — **Implemented**)
2. **Deck Menu (`6413 C_0_DeckMenu`)** — 4 icons:
   - **Card Box** (`6047 DeckMenu_Inventorybutton` — top-left blue side)
   - **Sell Cards** (`6046 DeckMenu_Sellbutton` — top-right blue side)
   - **Build Deck** (`6049 DeckMenu_Buildbutton` — bottom-left brown side)
   - **Craft Cards** (`6048 DeckMenu_Fusebutton` — bottom-right brown side)
3. **Shop / Market Menu (`6438 D_0_MarketMenu`)** — 3 icons:
   - **Restore Energy** (`6078 ButtonStamina` — top-center blue side)
   - **Increase Inventory** (`6081 ButtonInventory` — bottom-left brown side)
   - **Gems** (`6080 ButtonGems` — bottom-right brown side)
4. **Daily Dungeons & Gift Menu (`6427 I_0_ExtrasMenu`)** — 2 icons:
   - **Daily Dungeons of Doom** (`6099 ExtrasMenu_Dungeon` — left side)
   - **Daily Gift** (`6100 ExtrasMenu_DailyGift` — right side)
5. **Algebraic Chests / Gacha Menu (`6475 E_0_GatchaMenu`)** — 2 icons:
   - **Normal / Cool Chest** (`6471 NormalChest` — left side)
   - **Premium / Algebraic Chest** (`6810 PremiumChest` — right side)
6. **Options Menu (`6420 A_0_OptionsMenu`)** — 4 icons:
   - **Audio Settings** (`6224 AudioSettings`), **Credits** (`6225 Credits`), **Redeem Code / Tutorials** (`6226 Tutorials`), **Cartoon Network** (`6228 CartoonNetwork`).

- **Important Visual Constraint**: Do **NOT** add the orange rez-in beam/sparkle particle effects (`FxRayBeam`, `FxSparkles`, `low_FX_RezInParticle_MenuObject.prefab`) when showing the 3D board icons.

### 1.2. 3D Click Detection & Press/Activate Behavior (`MainMenu.gd` & Unity Scripts)
There are **three types of click behaviors** in the original C# scripts across all board icons:
1. **Custom One-Shot Activate Animation before Screen Transition**:
   - **Solo Quests (`CWQuestMapButton.cs`)**: Plays `SinglePlayer_Activate(copy).anim` (the dagger plunges down into the map scroll!), waits for `!battleMapAnimation.isPlaying`, then enters the Solo campaign map and resets to `SinglePlayer_Idle(copy).anim`.
   - **Fionna & Cake Book (`FCLaunchController.cs`)**: Plays `FionaCakeIcon_Activate.anim` (the book hops and opens wide), waits for completion (`0.866667s`), then enters the Fionna & Cake map.
2. **Chest Open / Close Sequence (`CWGachaChooseChest.cs`)**:
   - **Normal Chest (`6471`)**: Loops `NChest_Idle01(copy).anim`. When opening a chest, plays `NChest_OpenLvl5_0.anim`, spawns the flying card, and plays `NChest_End.anim` when closing.
   - **Premium Chest (`6810`)**: Loops `PChest_Idle01(copy).anim`. When opening a chest, plays `PChest_OpenLvl5_0.anim`, spawns the flying card, and plays `PChest_End.anim` when closing.
3. **Standard Press Squash & Tint Reaction (`ButtonReactionScript.cs`)**:
   - Attached to almost all board buttons (`QuestMenu_Mapbutton_Solo`, `QuestMenu_Mapbutton_FionnaCake`, all 4 `DeckMenu_*` buttons, all 3 `MarketMenu` buttons, both `GatchaMenu` chests, and `OptionsMenu` buttons).
   - On mouse/touch press down (`OnPress(true)`):
     - Scales the button root to `Vector3(originalSize.x * 0.8, originalSize.y * 0.8, originalSize.z)` over `0.05s`.
     - Multiplies all child mesh material colors by `0.5` (`Color(r * 0.5, g * 0.5, b * 0.5, 1.0)`).
   - On release (`OnPress(false)`):
     - Tweens scale back to `originalSize` over `0.05s` and restores `originalColor`.

---

## 2. Exact Unity-to-Godot Coordinate & Transform Math

### 2.1. Global Scale Factor (`0.0005` per Unity UI Panel Unit)
1. The TreeFort 3D environment in Godot (`godot/scenes/treehouse_menu_3d.tscn`) is scaled by **`0.05`** relative to Unity world units.
2. In `Assets/Scene/_hirez/Scenes/AdventureTime.unity`, all board menu containers sit under:
   - `6478 Menu UI Panel`: `m_LocalScale = (0.01, 0.01, 0.01)`
   - Therefore, **1 unit under `6478`** = `0.01` Unity world units = **`0.01 * 0.05 = 0.0005` Godot world units**.
3. Every board menu container (`6406 F_0_QuestsMenu`, `6413 C_0_DeckMenu`, `6438 D_0_MarketMenu`, `6427 I_0_ExtrasMenu`, `6475 E_0_GatchaMenu`, `6420 A_0_OptionsMenu`) has the **exact same transform** under `6478`:
   - `m_LocalPosition`: `(0, -250, 0)`
   - `m_LocalRotation`: `(0.5, 0.5, -0.5, 0.5)` (Euler `(90°, -90°, 0°)`)
   - `m_LocalScale`: `(10, 10, 10)`
   - Because the menu container has `scale = 10`, **1 unit inside any board menu container** = `10 * 0.0005 = 0.005` Godot world units.
   - And because `rot = (0.5, 0.5, -0.5, 0.5)` rotates `(X, Y, Z)` into board space:
     - Menu local `+X` maps to **Godot `+Z`** (towards the bottom of the screen; `-X` is top/blue side, `+X` is bottom/brown side, or vice-versa depending on camera yaw).
     - Menu local `+Y` maps to **Godot `+X`** (left/right along the long axis of the board).
     - Menu local `-Z` maps to **Godot `+Y`** (height above the board surface).

### 2.2. Left-Handed (Unity) to Right-Handed (Godot) Reflection Rules ($S_Z = \text{diag}(1, 1, -1)$)
To convert any local transform, animation curve, or mesh from Unity (left-handed: $+X$ right, $+Y$ up, $+Z$ forward) to Godot (right-handed: $+X$ right, $+Y$ up, $-Z$ forward), apply a $Z$-axis reflection $S_Z = \text{diag}(1, 1, -1)$:

| Data Type | Unity Value | Godot Value |
| :--- | :--- | :--- |
| **3D Position / Translation** | `(x, y, z)` | `Vector3(x, y, -z)` |
| **Position Tangents (`inSlope`/`outSlope`)** | `(tx, ty, tz)` | `Vector3(tx, ty, -tz)` |
| **Quaternion Rotation** | `(qx, qy, qz, qw)` | `Quaternion(-qx, -qy, qz, qw)` |
| **Quaternion Tangents (`inSlope`/`outSlope`)** | `(tx, ty, tz, tw)` | `Quaternion(-tx, -ty, tz, tw)` |
| **3D Scale** | `(sx, sy, sz)` | `Vector3(sx, sy, sz)` |
| **Scale Tangents (`inSlope`/`outSlope`)** | `(tx, ty, tz)` | `Vector3(tx, ty, tz)` |
| **4×4 Matrix Conjugation** | $M_{\text{Unity}}$ | $M_{\text{Godot}} = S_Z \cdot M_{\text{Unity}} \cdot S_Z$ |
| **Wavefront `.obj` Vertex Position** | `(vx, vy, vz)` | `v {vx} {vy} {-vz}` |
| **Wavefront `.obj` UV (`vt`)** | `(u, v)` | `vt {u} {v}` (**DO NOT FLIP `1 - v`!**) |
| **Wavefront `.obj` Triangle Winding (`f`)** | `(a, b, c)` (0-indexed) | `f {a+1}/{a+1} {c+1}/{c+1} {b+1}/{b+1}` |

> **CRITICAL PITFALL — Wavefront `.obj` UVs (`vt u v`)**:
> Both Unity and the Wavefront `.obj` specification use a **bottom-left UV origin** (`(0, 0)` at bottom-left). Godot's built-in `.obj` importer automatically flips `v -> 1.0 - v` during import.
> Therefore, when writing `.obj` files from Unity binary meshes, **always write `vt {u:.6f} {v:.6f}` directly**. Writing `1.0 - v` in the `.obj` file will double-flip the UVs and render textures upside-down!

> **CRITICAL PITFALL — Triangle Winding & Inverted-Normal Cartoon Outline Shells**:
> Reflecting $Z \to -Z$ flips surface handedness. You **must** reverse triangle index order from `(a, b, c)` to `(a, c, b)` when writing `.obj` faces (`f`).
> Many Card Wars 3D props have **either**:
> 1. An outline shell baked into the same mesh (`MultiPlayer.asset`, `BookCover.asset`, `CardInventory.asset`, `BuildDeck.asset`, `Sell.asset`), **or**
> 2. A second `*_Outline.asset` `SkinnedMeshRenderer` sibling (`Crafting_Outline.asset`, `CardSlots_Outline.asset`, `GemBag_Outline.asset`, `RestoreStamina_Outline.asset`, `Portal_Outline.asset`, `DailyGift_Christmas_Outline.asset`).
> In both cases, those outline triangles have **inverted normals** (pointing inward) mapped to black texels on the texture. With reversed `(a, c, b)` winding in `.obj` and Godot's default backface culling (`cull_mode = CULL_BACK`, i.e., omitting `cull_mode` in `StandardMaterial3D`), the front-most outline faces are culled so the inner colored model is visible, while the back-most outline faces form the black cartoon silhouette! Never set `cull_mode = 2` (`CULL_DISABLED`) on meshes that contain outline shells.

---

## 3. Binary Mesh Extraction from Unity `.asset` Files

Unity `.asset` mesh files in `Assets/Mesh/` store vertex data as a hex string in `_typelessdata:` and 16-bit triangle indices in `m_IndexBuffer:`.

### 3.1. Two Vertex Buffer Layouts in `Assets/Mesh/*.asset`
Always inspect `m_Channels:` in the `.asset` YAML before unpacking `_typelessdata`:

#### Layout A — Separate Streams with 16-Byte Stream Alignment
Used by **`SkinnedMeshRenderer` meshes** (e.g., `MultiPlayer.asset`, `Stadium_Lights.asset`, `Cards.asset`, `BuildDeck.asset`, `Crafting.asset`, `CardInventory.asset`, `Sell.asset`, `CardSlots.asset`, `GemBag.asset`, `RestoreStamina.asset`, `Portal.asset`, `DailyGift_Christmas.asset`, `NChest.asset`, `PChest.asset`) and static meshes like `SinglePlayer.asset`:
- `m_Channels[0]` (Position): `stream: 0, offset: 0, format: 0, dimension: 3` (`12` bytes per vertex: `<3f`).
- `m_Channels[3]` (UV0): `stream: 1, offset: 0, format: 0, dimension: 2` (`8` bytes per vertex: `<2f`).
- **CRITICAL 16-BYTE STREAM ALIGNMENT RULE**:
  Unity pads the end of each vertex stream to a **16-byte boundary**!
  Stream 0 occupies `vc * 12` bytes, followed by `0, 4, 8, or 12` padding bytes so Stream 1 starts at:
  ```python
  uv_offset = ((vc * 12) + 15) // 16 * 16
  ```
  **Never** use `uv_offset = vc * 12`! When `vc` is not a multiple of 4, omitting the 16-byte alignment shifts every UV by 4 bytes and scrambles the texture mapping!

#### Layout B — Single Interleaved Stream (`20` bytes per vertex)
Used by **static `MeshRenderer` sub-meshes** (e.g., `BookCover.asset`, `BookEnd.asset`, `BookPage1..3.asset`, `BookSpine.asset`):
- `m_Channels[0]` (Position): `stream: 0, offset: 0, format: 0, dimension: 3`
- `m_Channels[3]` (UV0): `stream: 0, offset: 12, format: 0, dimension: 2`
- Position and UV are interleaved in Stream 0 with a stride of `20` bytes per vertex:
  ```python
  x, y, z, u, v = struct.unpack_from('<5f', typelessdata, i * 20)
  ```

### 3.2. Unbaking `SkinnedMeshRenderer` Bindposes: Rigid vs. Soft-Skinned Meshes
We verified the vertex skin weights (`weight[0..3]`) across **every single board icon mesh** in `Assets/Mesh/*.asset`:

| Mesh Asset | Menu / Icon | Verts | Tris | Bones | Soft Verts (`w[1] > 0`) | Skinning Type |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| `MultiPlayer.asset` | Battle — Deck Wars | 2269 | 2124 | 9 | `0` | **Rigid** (`w[0] = 1.0`) |
| `Stadium_Lights.asset` | Battle — Deck Wars | 66 | 60 | 2 | `0` | **Rigid** (`w[0] = 1.0`) |
| `Cards.asset` | Battle — Solo Quests | 1302 | 1356 | 8 | `0` | **Rigid** (`w[0] = 1.0`) |
| `CardInventory.asset` | Deck — Card Box | 257 | 170 | 6 | `0` | **Rigid** (`w[0] = 1.0`) |
| `Sell.asset` | Deck — Sell Cards | 974 | 806 | 9 | `0` | **Rigid** (`w[0] = 1.0`) |
| `BuildDeck.asset` | Deck — Build Deck | 335 | 218 | 8 | `0` | **Rigid** (`w[0] = 1.0`) |
| `Crafting.asset` + `_Outline` | Deck — Craft Cards | 961 / 823 | 944 / 864 | 11 / 7 | `0` | **Rigid** (`w[0] = 1.0`) |
| `CardSlots.asset` + `_Outline` | Shop — Increase Inventory | 1661 / 1279 | 2069 / 1959 | 5 / 3 | `0` | **Rigid** (`w[0] = 1.0`) |
| `GemBag.asset` + `_Outline` | Shop — Gems | 824 / 743 | 1120 / 1092 | 6 / 4 | `0` | **Rigid** (`w[0] = 1.0`) |
| `RestoreStamina.asset` + `_Outline` | Shop — Restore Energy | 592 / 525 | 790 / 774 | 12 / 8 | `275 / 256` | **Soft-Skinned** (hose & balloon) |
| `Portal.asset` + `_Outline` | Extras — Daily Dungeons | 1662 / 1582 | 1802 / 1806 | 3 / 1 | `0` | **Rigid** (`w[0] = 1.0`) |
| `DailyGift_Christmas.asset` + `_Outline` | Extras — Daily Gift | 943 / 957 | 974 / 998 | 6 / 6 | `323 / 232` | **Soft-Skinned** (gift box squash) |
| `NChest.asset` | Gacha — Normal Chest | 1830 | 2380 | 9 | `0` | **Rigid** (`w[0] = 1.0`) |
| `PChest.asset` | Gacha — Premium Chest | 708 | 666 | 3 | `0` | **Rigid** (`w[0] = 1.0`) |
| `MainMenu_Audio.asset` | Options — Audio | 517 | 578 | 6 | `139` | **Soft-Skinned** |
| `MainMenu_Credits.asset` | Options — Credits | 467 | 586 | 5 | `16` | **Soft-Skinned** (feather pen) |
| `Code.asset` | Options — Tutorials/Code | 302 | 378 | 8 | `120` | **Soft-Skinned** (mouse wire) |

#### Case 1 — Rigid Piece-Per-Bone Meshes (`soft_verts == 0`)
Multiply each vertex by its bone's `m_BindPose[b]` 4×4 matrix to transform it into bone `b`'s local coordinate space:
```python
lx = bp[0][0]*vx + bp[0][1]*vy + bp[0][2]*vz + bp[0][3]
ly = bp[1][0]*vx + bp[1][1]*vy + bp[1][2]*vz + bp[1][3]
lz = bp[2][0]*vx + bp[2][1]*vy + bp[2][2]*vz + bp[2][3]
# Write to bone b's .obj file with Z negated:
# v {lx:.6f} {ly:.6f} {-lz:.6f}
```
Then attach each exported `.obj` as a `MeshInstance3D` child of bone `b`'s `Node3D` in Godot.

#### Case 2 — Soft-Skinned Meshes (`soft_verts > 0`, e.g., `RestoreStamina`, `DailyGift`)
For meshes where vertices blend across 2+ bones (`w[1] > 0`, such as the flexible rubber hose on `RestoreStamina` or the squashing box on `DailyGift`), every vertex $v$ in bind space is deformed by the Linear Blend Skinning (LBS) formula:
$$v_{\text{posed}} = \sum_{k=0}^{3} w_k \cdot \left( W_{b_k} \cdot B_{b_k} \cdot v_{\text{raw}} \right)$$
where $B_{b_k}$ is `m_BindPose[b_k]` (converted to Godot via $S_Z \cdot B_{b_k} \cdot S_Z$) and $W_{b_k}$ is bone $b_k$'s current `Transform3D` relative to the mesh root. In Godot 4, this can be driven either via a `Skeleton3D` + `ArrayMesh` (`ARRAY_BONES` / `ARRAY_WEIGHTS` with bone rest poses set from $S_Z \cdot B_b^{-1} \cdot S_Z$) or by updating an `ArrayMesh` / `ImmediateMesh` directly.

---

## 4. Unity `.anim` Hermite Spline Animation System

### 4.1. How Unity Evaluates `.anim` Curves
Unity `AnimationClip` (`.anim`) files contain:
- `m_RotationCurves`: Quaternion curves (`x, y, z, w`) per relative node `path`.
- `m_PositionCurves`: Vector3 translation curves (`x, y, z`) per relative node `path`.
- `m_ScaleCurves`: Vector3 scale curves (`x, y, z`) per relative node `path`.

Each keyframe has `time`, `value`, `inSlope`, and `outSlope`. Between keyframe $k_0 = (t_0, v_0, \text{in}_0, \text{out}_0)$ and $k_1 = (t_1, v_1, \text{in}_1, \text{out}_1)$, with $\Delta t = t_1 - t_0$ and $u = \text{clamp}((t - t_0) / \Delta t, 0, 1)$, Unity uses cubic Hermite interpolation:
$$h_{00}(u) = 2u^3 - 3u^2 + 1, \quad h_{10}(u) = u^3 - 2u^2 + u, \quad h_{01}(u) = -2u^3 + 3u^2, \quad h_{11}(u) = u^3 - u^2$$
$$v(t) = h_{00}(u) v_0 + h_{10}(u) (\Delta t \cdot \text{out}_0) + h_{01}(u) v_1 + h_{11}(u) (\Delta t \cdot \text{in}_1)$$
For quaternions, normalize $v(t)$ after evaluating the 4D Hermite polynomial.

> **CRITICAL CHECK — Root Path Curves (`path: ""`)**:
> Always check if an `.anim` file contains curves with `path: ""` (empty string)!
> A curve with `path: ""` animates or overrides the **root node itself** (the GameObject that holds the `Animation` component, e.g., `FionnaCakeIcon`). Ignoring `path: ""` will leave the root node in its unposed scene transform!

---

## 5. Completed Icons Reference (Battle Menu)

### 5.1. Deck Wars Stadium (`6017 QuestMenu_Mapbutton_Multi`) — DONE
- **Godot Files**: [`godot/scenes/deck_wars_stadium.tscn`](file:///home/verivi/Veras/Projects/CardWarsForLinux/godot/scenes/deck_wars_stadium.tscn), [`godot/src/ui/DeckWarsStadium.gd`](file:///home/verivi/Veras/Projects/CardWarsForLinux/godot/src/ui/DeckWarsStadium.gd), `godot/assets/models/stadium/*.obj`.
- **Textures**: `godot/assets/textures/hub/MultiPlayer.png` + `godot/assets/textures/hub/Floodlight.png` (additive unshaded light cones).
- **Animation**: `Assets/AnimationClip/MultiPlayer_Idle.anim` (`6.666667s` loop). No separate click animation.

### 5.2. Fionna & Cake Book (`6013 QuestMenu_Mapbutton_FionnaCake`) — DONE
- **Godot Files**: [`godot/scenes/fionna_cake_book.tscn`](file:///home/verivi/Veras/Projects/CardWarsForLinux/godot/scenes/fionna_cake_book.tscn), [`godot/src/ui/FionnaCakeBook.gd`](file:///home/verivi/Veras/Projects/CardWarsForLinux/godot/src/ui/FionnaCakeBook.gd), `godot/assets/models/book/*.obj`.
- **Texture**: `godot/assets/textures/hub/FionnaCakeIcon.png` (`Assets/Material/low_FionnaCakeIcon.mat`).
- **Animations (`FCLaunchController.cs`)**:
  - **Idle**: `Assets/AnimationClip/Idle_2.anim` (`3.366667s` loop — starts closed showing the cover, hops, leaps and fans pages open in mid-air, snaps shut and lands back on the board).
  - **Click / Activate**: `Assets/AnimationClip/FionaCakeIcon_Activate.anim` (`0.866667s` one-shot — book hops and opens wide before transitioning to the Fionna & Cake campaign map).

---

## 6. Complete Catalog of All Remaining 3D Board Icons

### 6.1. Battle Menu (`6406 F_0_QuestsMenu`) — 1 Remaining Icon
*(Note: `6016 QuestMenu_LeaderBoards` is intentionally excluded and will NOT be implemented.)*

#### 1. Solo Quests (`6014 QuestMenu_Mapbutton_Solo` — Label: `"Quests"`)
- **Board Placement under `6406 F_0_QuestsMenu`**:
  - `6014 QuestMenu_Mapbutton_Solo`: `pos = (96, -126, -12), rot = (0, 0, 0.08715574, 0.9961947), scale = (0.5, 0.5, 1.0)`
  - `5929 MapQuests`: `pos = (6.1898, 35.1039, 0), rot = (0, 0.7071068, -0.7071068, 0), scale = (1, 1, 1)`
  - `5088 SinglePlayer`: `pos = (0, 0, 0), rot = (0, 0, 0, 1), scale = (10, 10, 10)`
- **Meshes & Materials under `5088 SinglePlayer`**:
  1. `4275 SinglePlayer` (Static `MeshRenderer` + `MeshFilter`):
     - `pos = (-0.0059, -1.8811, 0.6808), rot = (-0.7071068, 0, 0, 0.7071068), scale = (1, 1, 1)`
     - Mesh: `Assets/Mesh/SinglePlayer.asset` (Unrolled Quest Map Scroll + Magnifying Glass + Compasses).
     - Material: `Assets/Material/low_MultiPlayer.mat` (`MultiPlayer.png`).
  2. `4278 Cards` (`SkinnedMeshRenderer &7310`):
     - `pos = (0, 0, 0), rot = (-0.7071068, 0, 0, 0.7071068), scale = (1, 1, 1)`
     - Mesh: `Assets/Mesh/Cards.asset` (2 card decks, 5 floating cards, and the Dagger/Knife).
     - Material: `Assets/Material/low_BattleMap.mat` (`BattleMap.png`).
     - `m_Bones` order (`0..7`):
       - `0`: `3689 Puppet_Deck01`
       - `1`: `3688 Puppet_Deck02`
       - `2`: `3694 Puppet_Card01`
       - `3`: `3860 Puppet_Knife` (Dagger)
       - `4`: `3693 Puppet_Card02`
       - `5`: `3692 Puppet_Card03`
       - `6`: `3691 Puppet_Card04`
       - `7`: `3690 Puppet_Card05`
  3. `4277 Puppet_Global` (Bone Hierarchy):
     - `pos = (0, -0.0191, 0), rot = (0.5, -0.5, -0.5, 0.5), scale = (1, 1, 1)`
     - Children:
       - `3861 Puppet_GlobalAllCards` (`pos = (-1.0037, 6.0452, 17.7439)`) $\to$ `Puppet_Card01..05`, `Puppet_Deck01..02`
       - `3860 Puppet_Knife` (`pos = (0, 12.3919, -9.9708)`)
       - `3859 Puppet_Map00` (`pos = (0, 0, 0.3324)`)
- **Animations & Click Behavior (`CWQuestMapButton.cs` + `ButtonReactionScript.cs`)**:
  - **Idle Clip**: `Assets/AnimationClip/SinglePlayer_Idle(copy).anim` (cards shuffle/float out of the deck).
  - **Click / Activate Clip**: `Assets/AnimationClip/SinglePlayer_Activate(copy).anim` (triggered on click via `battleMapAnimation.CrossFade(daggerAnimation)`—the dagger plunges down and stabs into the map scroll; when finished, opens the Solo campaign map).
  - **Audio Clips (`CWPlayAudioScript.cs`)**: `low_SFX_Map_Dagger.wav`, `low_SFX_Map_Rollout.wav`, `low_Map_Cards_Shuffle.wav`.

---

### 6.2. Deck Menu (`6413 C_0_DeckMenu`) — 4 Icons
All 4 buttons use `DeckNavigationScript.cs` + `ButtonReactionScript.cs` (press squash/tint on click, then navigate to the respective Deck screen).

#### 1. Card Box (`6047 DeckMenu_Inventorybutton` — Label: `"Card Box"`, Top-Left Blue Side)
- **Transform Chain under `6413 C_0_DeckMenu`**:
  - `6047 DeckMenu_Inventorybutton`: `pos = (-105, 115, 0), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
  - `5903 CardInventory`: `pos = (0, 0, 0), rot = (0, 0, 1, 0), scale = (1, 1, 1)`
  - `4841 CardInventory`: `pos = (0, 0, 0), rot = (0.7071068, 0, 0, -0.7071068), scale = (12, 12, 12)`
- **Mesh & Material**:
  - `4284 CardInventory` (`SkinnedMeshRenderer &7336`):
    - Mesh: `Assets/Mesh/CardInventory.asset`
    - Material: `Assets/Material/low_CardInventory.mat`
    - `m_Bones` (`0..5` under `4283 Puppet_Global`):
      - `0`: `4202 Puppet_BoxLid`
      - `1`: `4203 Puppet_Box`
      - `2`: `4200 Puppet_Card02`
      - `3`: `4201 Puppet_Card01`
      - `4`: `4199 Puppet_Card03`
      - `5`: `4198 Puppet_Card04`
- **Animation**:
  - **Idle Clip**: `Assets/AnimationClip/Idle.anim` (GUID `c0778df3c646e264cace88f033e7008a` — the box opens its lid and the 4 cards fan out above the box).

#### 2. Sell Cards (`6046 DeckMenu_Sellbutton` — Label: `"Sell Cards"`, Top-Right Blue Side)
- **Transform Chain under `6413 C_0_DeckMenu`**:
  - `6046 DeckMenu_Sellbutton`: `pos = (105, 115, 0), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
  - `5222 CardSell`: `pos = (0, 0, 0), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
  - `4702 Sell`: `pos = (0, 0, 0), rot = (0.2706, 0.6533, -0.6533, -0.2706), scale = (7, 7, 7)`
- **Mesh & Material**:
  - `4281 Puppet_Base` (`SkinnedMeshRenderer &7318`):
    - Mesh: `Assets/Mesh/Sell.asset` (Cash Register with buttons, pop-up top display, drawer tray, and 3 coins).
    - Material: `Assets/Material/low_Sell.mat`
    - `m_Bones` (`0..8`):
      - `0`: `4281 Puppet_Base`
      - `1`: `4104 Puppet_Tray` (drawer)
      - `2`: `4105 Puppet_Top`
      - `3`: `4108 Puppet_Button01`
      - `4`: `4107 Puppet_Button02`
      - `5`: `4106 Puppet_Button03`
      - `6`: `3749 Puppet_Coin01` (child of `4104 Puppet_Tray`)
      - `7`: `3748 Puppet_Coin02` (child of `4104 Puppet_Tray`)
      - `8`: `3747 Puppet_Coin03` (child of `4104 Puppet_Tray`)
- **Animation**:
  - **Idle Clip**: `Assets/AnimationClip/Take 001_6.anim` (GUID `17b943be3afe6f64db0e71a08f81daf4` — buttons press down, the cash register drawer pops open, and coins bounce inside).

#### 3. Build Deck (`6049 DeckMenu_Buildbutton` — Label: `"Build Deck"`, Bottom-Left Brown Side)
- **Transform Chain under `6413 C_0_DeckMenu`**:
  - `6049 DeckMenu_Buildbutton`: `pos = (-105, -115, 0), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
  - `5773 CardBuild`: `pos = (0, 0, 0), rot = (0.2067, -0.6762, 0.6762, -0.2067), scale = (1, 1, 1)`
  - `4631 BuildDeck`: `pos = (0, 0, 0), rot = (0, 0.3827, 0, 0.9239), scale = (11, 11, 11)`
- **Mesh & Material**:
  - `4334 BuildDeck` (`SkinnedMeshRenderer &7334`):
    - Mesh: `Assets/Mesh/BuildDeck.asset`
    - Material: `Assets/Material/low_BuildDeck.mat`
    - `m_Bones` (`0..7` under `4333 Puppet_Global`):
      - `0`: `3772 Puppet_Box`
      - `1`: `3771 Puppet_BoxLid`
      - `2`: `4333 Puppet_Global`
      - `3`: `3770 Puppet_Card01`
      - `4`: `3769 Puppet_Card02`
      - `5`: `3766 Puppet_Deck`
      - `6`: `3768 Puppet_Card03`
      - `7`: `3767 Puppet_Card04`
- **Animation**:
  - **Idle Clip**: `Assets/AnimationClip/BuildDeck_Idle(copy).anim` (GUID `0db2162d2f1d90f4f8849ac320397ad6` — cards fly between the deck stack and the open card box).

#### 4. Craft Cards (`6048 DeckMenu_Fusebutton` — Label: `"Craft Cards"`, Bottom-Right Brown Side)
- **Transform Chain under `6413 C_0_DeckMenu`**:
  - `6048 DeckMenu_Fusebutton`: `pos = (105, -115, 0), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
  - `5458 CardCraft`: `pos = (0, 0, 0), rot = (0.0308, 0.7578, -0.651, -0.0308), scale = (6, 6, 6)`
  - `4999 Crafting`: `pos = (0, 0, 0), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
  - *(Note: `5457 CardFuse` is `active=0` in `AdventureTime.unity`; `5458 CardCraft` is the active anvil icon!)*
- **Meshes & Material**:
  - Material: `Assets/Material/low_Crafting.mat`
  - `4463 Crafting` (`SkinnedMeshRenderer &7316`, `Assets/Mesh/Crafting.asset`), `m_Bones` (`0..10`):
    - `0`: `4460 Puppet_Global`
    - `1`: `3890 Puppet_Top` (Anvil top)
    - `2`: `4461 Puppet_Base` (Anvil base)
    - `3`: `3680 Puppet_Sledge` (Hammer head, child of `3892 Puppet_Sledge_Handle`)
    - `4`: `3892 Puppet_Sledge_Handle`
    - `5`: `3894 Puppet_PlugL`
    - `6`: `3893 Puppet_PlugR`
    - `7`: `3888 Puppet_WrenchR` (Tongs right jaw)
    - `8`: `3889 Puppet_WrenchL` (Tongs left jaw)
    - `9`: `3895 Puppet_Card2`
    - `10`: `3896 Puppet_Card1`
  - `4462 Crafting_Outline` (`SkinnedMeshRenderer &7312`, `Assets/Mesh/Crafting_Outline.asset`), `m_Bones` (`0..6`):
    - `0`: `3888 Puppet_WrenchR`, `1`: `3889 Puppet_WrenchL`, `2`: `4460 Puppet_Global`, `3`: `3890 Puppet_Top`, `4`: `4461 Puppet_Base`, `5`: `3680 Puppet_Sledge`, `6`: `3892 Puppet_Sledge_Handle`.
- **Animation**:
  - **Idle Clip**: `Assets/AnimationClip/Crafting_Take 001(copy).anim` (GUID `b766a0a1a2dfc8a4394ccd45fb644d56` — tongs hold cards on the anvil while the sledgehammer slams down to forge them; audio `low_Manager_Shuffle_Anvil.wav`).

---

### 6.3. Shop / Market Menu (`6438 D_0_MarketMenu`) — 3 Icons
All 3 buttons use `ButtonReactionScript.cs` + `UIButtonMessage.cs` to open the corresponding shop popup/screen.

#### 1. Restore Energy (`6078 ButtonStamina` — Label: `"Restore Energy"`, Top-Center Blue Side)
- **Transform Chain under `6438 D_0_MarketMenu`**:
  - `6078 ButtonStamina`: `pos = (0, 115, -2), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
  - `5865 MarketStamina`: `pos = (-17, 6, -1), rot = (0.1167, 0.6974, -0.6974, -0.1167), scale = (8.5, 8.5, 8.5)`
  - `4809 RestoreStamina`: `pos = (0, 0, 0), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
- **Meshes & Material**:
  - Material: `Assets/Material/low_RestoreStamina.mat`
  - `4379 RestoreStamina` (`SkinnedMeshRenderer &7315`, `Assets/Mesh/RestoreStamina.asset`), `m_Bones` (`0..11`):
    - `0`: `3629 Puppet_Hose1` (child of `3677 Puppet_PumpBase`)
    - `1`: `3677 Puppet_PumpBase` (child of `4235 Puppet_PumpGlobal`)
    - `2`: `4239 Puppet_Hose2`
    - `3`: `4238 Puppet_Hose3`
    - `4`: `4237 Puppet_Hose4`
    - `5`: `3744 Puppet_Balloon` (child of `4237 Puppet_Hose4`)
    - `6`: `3628 Puppet_Balloon Expand` (child of `3744 Puppet_Balloon`)
    - `7`: `4235 Puppet_PumpGlobal`
    - `8`: `4380 Puppet_Global`
    - `9`: `3676 Puppet_Pumptop` (child of `4235 Puppet_PumpGlobal`)
    - `10`: `4240 Puppet_Explode`
    - `11`: `4236 Puppet_Pop`
  - `4378 RestoreStamina_Outline` (`SkinnedMeshRenderer &7328`, `Assets/Mesh/RestoreStamina_Outline.asset`), `m_Bones` (`0..7`):
    - `0`: `3629`, `1`: `3677`, `2`: `4239`, `3`: `4238`, `4`: `4237`, `5`: `3744`, `6`: `3628`, `7`: `3676`.
- **Animation**:
  - **Idle Clip**: `Assets/AnimationClip/RestoreStamina_Take 001(clone).anim` (GUID `ad772a3e633ee6d43b69b41af88f168b` — the pump handle pumps up and down inflating the heart balloon until it pops/explodes and repeats; audio `low_Restore_Stamina_Pump.wav`).

#### 2. Increase Inventory (`6081 ButtonInventory` — Label: `"Increase Inventory"`, Bottom-Left Brown Side)
- **Transform Chain under `6438 D_0_MarketMenu`**:
  - `6081 ButtonInventory`: `pos = (-105, -115, -2), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
  - `5840 MarketInventory`: `pos = (0, 0, 0), rot = (0, 0.7071068, -0.7071068, 0), scale = (1, 1, 1)`
  - `4908 CardSlots`: `pos = (0, 0, 0), rot = (0, 0, 0, 1), scale = (15, 15, 15)`
- **Meshes & Material**:
  - Material: `Assets/Material/low_CardSlots.mat`
  - `4407 CardSlots` (`SkinnedMeshRenderer &7320`, `Assets/Mesh/CardSlots.asset`, `pos = (0.0024, 0.0729, -6.0034), scale = (1.28, 1.28, 1.28)`), `m_Bones` (`0..4` under `4405 Puppet_Global`):
    - `0`: `4030 Puppet_Box`
    - `1`: `4029 Puppet_BoxLid`
    - `2`: `4027 Puppet_CornBall`
    - `3`: `4028 Puppet_CoolDog`
    - `4`: `4026 Puppet_Pieclops` (the purple creature standing beside/popping out of the box!)
  - `4406 CardSlots_Outline` (`SkinnedMeshRenderer &7329`, `Assets/Mesh/CardSlots_Outline.asset`), `m_Bones` (`0..2`):
    - `0`: `4027 Puppet_CornBall`, `1`: `4028 Puppet_CoolDog`, `2`: `4026 Puppet_Pieclops`.
- **Animation**:
  - **Idle Clip**: `Assets/AnimationClip/Take 001_9.anim` (GUID `bda39fd0de5ed2f498cc5ba099877eff` — `2.666667s` loop where the cardboard box shakes/opens and hologram creatures `Pieclops`, `CoolDog`, and `CornBall` pop out above it!).

#### 3. Gems (`6080 ButtonGems` — Label: `"Gems"`, Bottom-Right Brown Side)
- **Transform Chain under `6438 D_0_MarketMenu`**:
  - `6080 ButtonGems`: `pos = (105, -115, -2), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
  - `5653 MarketGems`: `pos = (7.3, 41, 0), rot = (0, -0.7071068, 0.7071068, 0), scale = (1, 1, 1)`
  - `5000 Gems`: `pos = (0, 0, 0), rot = (0, 0, 0, 1), scale = (12, 12, 12)`
- **Meshes & Material**:
  - Material: `Assets/Material/low_Gems.mat`
  - `4388 GemBag` (`SkinnedMeshRenderer &7311`, `Assets/Mesh/GemBag.asset`), `m_Bones` (`0..5` under `4386 Puppet_Base`):
    - `0`: `4386 Puppet_Base` (the purple gem sack)
    - `1`: `3818 Puppet_Gem02`
    - `2`: `3819 Puppet_Gem01`
    - `3`: `3817 Puppet_Gem03`
    - `4`: `3815 Puppet_Twinkle02` (sparkle star)
    - `5`: `3816 Puppet_Twinkle01` (sparkle star)
  - `4387 GemBag_Outline` (`SkinnedMeshRenderer &7324`, `Assets/Mesh/GemBag_Outline.asset`), `m_Bones` (`0..3`):
    - `0`: `4386 Puppet_Base`, `1`: `3818 Puppet_Gem02`, `2`: `3819 Puppet_Gem01`, `3`: `3817 Puppet_Gem03`.
- **Animation**:
  - **Idle Clip**: `Assets/AnimationClip/Idle_3.anim` (GUID `91153219aa2bf0e45b8f6bc1fb000897` — gems shift and twinkle stars scale up and down; also has `Intro.anim` `f4652d0c3c43a3c4f838ae6ccc1dda32`).

---

### 6.4. Daily Dungeons & Daily Gift Menu (`6427 I_0_ExtrasMenu`) — 2 Icons
Both buttons use `UIButtonScale.cs` + `UIButtonMessage.cs` + `UIButtonSound.cs`.

#### 1. Daily Dungeons of Doom (`6099 ExtrasMenu_Dungeon` — Label: `"Daily Dungeons of Doom"`, Left Side)
- **Transform Chain under `6427 I_0_ExtrasMenu`**:
  - `6099 ExtrasMenu_Dungeon`: `pos = (-90, -120, -25), rot = (0, 0.7071068, -0.7071068, 0), scale = (1, 1, 1)`
  - `5178 DungeonPortal`: `pos = (0, 0, 0), rot = (0, 0, 0, 1), scale = (6, 6, 6)`
- **Meshes & Material**:
  - Material: `Assets/Material/low_DungeonPortal.mat`
  - `4691 Portal` (`SkinnedMeshRenderer &7351`, `Assets/Mesh/Portal.asset`), `m_Bones` (`0..2`):
    - `0`: `4689 Puppet_Global` (Stone arch + skull on stick + rocks/weeds)
    - `1`: `4418 Puppet_PortalParent` (`pos = (0.1556, 5.0611, -0.0084), rot = (1, 0, 0, 0), scale = (0.6009, 1, 1)`)
    - `2`: `3937 Puppet_Portal` (Swirling blue vortex inside the arch, child of `4418`)
  - `4690 Portal_Outline` (`SkinnedMeshRenderer &7344`, `Assets/Mesh/Portal_Outline.asset`), `m_Bones` (`0`):
    - `0`: `4689 Puppet_Global`.
- **Animation**:
  - **Idle Clip**: `Assets/AnimationClip/Take 001_14.anim` (GUID `6a4eeb95a1fd4e64b89fd571f68665a2` — rotates `Puppet_Portal` continuously to spin the blue vortex inside the stone archway).

#### 2. Daily Gift (`6100 ExtrasMenu_DailyGift` — Label: `"Daily Gift"`, Right Side)
- **Transform Chain under `6427 I_0_ExtrasMenu`**:
  - `6100 ExtrasMenu_DailyGift`: `pos = (90, -120, -25), rot = (0, 0.7071068, -0.7071068, 0), scale = (1, 1, 1)`
  - `5308 DailyGift_Normal`: `pos = (0, -25, -25), rot = (0, 0, 0, 1), scale = (8, 8, 8)`
  - *(Note: Also has inactive seasonal siblings `5311 DailyGift_Christmas` and `5310 DailyGift_Halloween`)*
- **Meshes & Material**:
  - Material: `Assets/Material/low_DailyGift_Normal.mat` (orange gift box with yellow ribbon)
  - `4897 DailyGift_Normal` (`SkinnedMeshRenderer &7342`, `Assets/Mesh/DailyGift_Christmas.asset`), `m_Bones` (`0..5` under `4895 Puppet_Global`):
    - `0`: `4295 Puppet_Pumpkin_Top` (Gift box top/lid)
    - `1`: `4301 Puppet_BowL` (Left bow loop)
    - `2`: `4300 Puppet_BowR` (Right bow loop)
    - `3`: `4296 Puppet_Pumpkin_Base` (Gift box base)
    - `4`: `4298 Puppet_BowTailR` (Right ribbon tail)
    - `5`: `4299 Puppet_BowTailL` (Left ribbon tail)
  - `4896 DailyGift_Normal_Outline` (`SkinnedMeshRenderer &7348`, `Assets/Mesh/DailyGift_Christmas_Outline.asset`), same 6 bones (`0..5`).
- **Animation**:
  - **Idle Clip**: `Assets/AnimationClip/Take 001_5.anim` (GUID `b883ed41e36eefa42a4f5245aafdeb9e` — the gift box bounces/squashes playfully while the bow loops and tails flap).

---

### 6.5. Algebraic Chests / Gacha Menu (`6475 E_0_GatchaMenu`) — 2 Chests

#### 1. Normal / Cool Chest (`6471 NormalChest`, Left Side)
- **Transform Chain under `6475 E_0_GatchaMenu`**:
  - `6471 NormalChest`: `pos = (-105, -115, 0), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
  - `6465 NormalParent`: `pos = (105, 115, -25), rot = (-0.5, -0.5, 0.5, 0.5), scale = (10, 10, 10)`
  - `6200 NChest`: `pos = (0, 0, 0), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
- **Meshes & Materials**:
  - `5380 NChest` (`SkinnedMeshRenderer &7358`, `Assets/Mesh/NChest.asset`, Material: `Assets/Material/low_NChest.mat`), `m_Bones` (`0..8` under `5379 Puppet_Global`):
    - `0`: `5147 Puppet_Base`, `1`: `4341 Puppet_Lid`, `2`: `4171 Puppet_LooseBoard`, `3`: `5145 Puppet_Moth01_Body`, `4`: `4255 Puppet_Moth01_WingR`, `5`: `4256 Puppet_Moth01_WingL`, `6`: `5144 Puppet_Moth02_Body`, `7`: `4513 Puppet_Moth02_WingR`, `8`: `4514 Puppet_Moth02_WingL`.
  - `5381 Chest_Card` (`SkinnedMeshRenderer &7357`, `Assets/Mesh/Chest_Card_0.asset`, Material: `Assets/Material/low_Chest_Card.mat`), Bone `0`: `5146 Puppet_Card`.
- **Animations (`CWGachaChooseChest.cs`)**:
  - **Idle**: `Assets/AnimationClip/NChest_Idle01(copy).anim` (chest rattles while moths flutter around it; audio `low_Cool_Chest_Rattle.wav`).
  - **Open**: `Assets/AnimationClip/NChest_OpenLvl5_0.anim`
  - **Close**: `Assets/AnimationClip/NChest_End.anim`

#### 2. Premium / Algebraic Chest (`6810 PremiumChest`, Right Side)
- **Transform Chain under `6475 E_0_GatchaMenu`**:
  - `6810 PremiumChest`: `pos = (105, -115, 0), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
  - `6477 PremiumParent`: `pos = (-105, 115, -25), rot = (-0.5, -0.5, 0.5, 0.5), scale = (10, 10, 10)`
  - `6466 PChest`: `pos = (0, 0, 0), rot = (0, 0, 0, 1), scale = (1, 1, 1)`
- **Meshes & Materials**:
  - `6461 PChestDefault` (`SkinnedMeshRenderer &7360`, `Assets/Mesh/PChest.asset`, Material: `Assets/Material/low_PChest.mat`), `m_Bones` (`0..2` under `6460 Puppet_Global`):
    - `0`: `6261 Puppet_Base`, `1`: `5668 Puppet_Lid`, `2`: `6259 Puppet_Sparkle`.
  - `6463 Chest_Card` (`SkinnedMeshRenderer &7359`, `Assets/Mesh/Chest_Card.asset`, Material: `Assets/Material/low_Chest_Card.mat`), Bone `0`: `6260 Puppet_Card`.
- **Animations (`CWGachaChooseChest.cs`)**:
  - **Idle**: `Assets/AnimationClip/PChest_Idle01(copy).anim` (audio `low_Algebraic_Chest_Rattle.wav`).
  - **Open**: `Assets/AnimationClip/PChest_OpenLvl5_0.anim`
  - **Close**: `Assets/AnimationClip/PChest_End.anim`

---

### 6.6. Options Menu (`6420 A_0_OptionsMenu`) — 4 Icons
1. **Audio Settings (`6224 AudioSettings`)**:
   - `pos = (-105, -145, 0)` $\to$ `5694 Audio` (`pos = (-3.0172, 50, 0), rot = (0, 0.7071, -0.7071, 0), scale = (8, 8, 8)`)
   - Meshes: `Assets/Mesh/MainMenu_Audio.asset` + `Assets/Mesh/MainMenu_Audio_Outline.asset` (`Assets/Material/low_MainMenu_Objects01.mat`).
   - Bones (`0..5`): `4312 Puppet_Sub01`, `3844 Puppet_Sub02`, `3765 Puppet_Speaker02`, `3845 Puppet_Speaker01`, `4313 Puppet_JoystickBase`, `3957 Puppet_JoystickStick`.
   - Animation: `Assets/AnimationClip/Audio_Anim.anim`.
2. **Credits (`6225 Credits`)**:
   - `pos = (-105, 70, -1)` $\to$ `5530 Credits` (`pos = (0, 50, 0), rot = (0, 0.7071, -0.7071, 0), scale = (8, 8, 8)`)
   - Meshes: `Assets/Mesh/MainMenu_Credits.asset` + `Assets/Mesh/MainMenu_Credits_Outline.asset` (`Assets/Material/low_MainMenu_Objects01_0.mat`).
   - Bones (`0..4`): `4471 Puppet_InkBottle`, `4472 Puppet_FeatherPen`, `3869 Puppet_FeatherPen01`, `3750 Puppet_FeatherPen02`, `4470 Puppet_Paper`.
   - Animation: `Assets/AnimationClip/Credits_Anim.anim`.
3. **Tutorials / Code Redeem (`6226 Tutorials`)**:
   - `pos = (105, -145, -1.5)` $\to$ `5441 CodeRedeem` (`pos = (2.5, 55, -7), rot = (0.2706, 0.6533, -0.6533, -0.2706), scale = (0.8, 0.8, 0.8)`) $\to$ `4789 Code` (`scale = (8, 8, 8)`).
   - Mesh: `Assets/Mesh/Code.asset` (`Assets/Material/low_Code.mat`).
   - Bones (`0..7`): `4190 Puppet_Mouse`, `4189 Puppet_Wire01`, `4188 Puppet_Wire02`, `4187 Puppet_Wire03`, `4191 Puppet_CompBase`, `3705 Puppet_CompMid`, `3646 Puppet_CompTop`, `4305 Puppet_Diskette`.
   - Animation: `Assets/AnimationClip/Idle_0.anim`.
4. **Cartoon Network (`6228 CartoonNetwork`)**:
   - `pos = (105, 70, 0)` $\to$ `5791 Cube` (`pos = (0, 50, -40), rot = (-0.5, -0.5, 0.5, 0.5), scale = (75, 75, 75)`), Material: `Assets/Material/low_CNLogo.mat`.

---

## 7. Reusable Python Extraction CLI Toolkit (`scripts/unity_extractor/`)

Three standalone, reusable CLI tools have been created in [`scripts/unity_extractor/`](file:///home/verivi/Veras/Projects/CardWarsForLinux/scripts/unity_extractor) to automate scene hierarchy inspection, mesh extraction, and GDScript Hermite animation generation:

1. **[`scripts/unity_extractor/unity_scene.py`](file:///home/verivi/Veras/Projects/CardWarsForLinux/scripts/unity_extractor/unity_scene.py)** — Parses `AdventureTime.unity`, resolves all `.meta` GUIDs in `Assets/`, prints the full hierarchy under any Transform ID (including its Godot `Transform3D`), and computes combined parent-to-child Godot `Transform3D` chains:
   ```bash
   # Walk a Transform ID hierarchy and print resolved meshes, materials, clips, and Godot local Transform3Ds:
   python3 scripts/unity_extractor/unity_scene.py --walk 6014

   # Compute combined Godot Transform3D from board menu container (6406) to icon root (5088):
   python3 scripts/unity_extractor/unity_scene.py --chain 6406 5088 --scale 0.005
   ```

2. **[`scripts/unity_extractor/unity_mesh.py`](file:///home/verivi/Veras/Projects/CardWarsForLinux/scripts/unity_extractor/unity_mesh.py)** — Inspects and exports both static and `SkinnedMeshRenderer` `.asset` meshes (automatically handling Layout A 16-byte stream alignment vs. Layout B 20-byte interleaved streams, unbaking `m_BindPose[b]`, reflecting `Z -> -Z`, preserving `vt u v`, and reversing triangle winding `f a c b`):
   ```bash
   # Inspect mesh layout, bone counts, and rigid vs soft skinning:
   python3 scripts/unity_extractor/unity_mesh.py --info Assets/Mesh/Cards.asset

   # Export a static mesh to .obj:
   python3 scripts/unity_extractor/unity_mesh.py --export-static Assets/Mesh/SinglePlayer.asset \
       --out godot/assets/models/quests/SinglePlayer.obj

   # Export a rigid SkinnedMeshRenderer mesh into bone-local .obj submeshes:
   python3 scripts/unity_extractor/unity_mesh.py --export-skinned Assets/Mesh/Cards.asset \
       --out-dir godot/assets/models/quests \
       --bone-names Deck01 Deck02 Card01 Knife Card02 Card03 Card04 Card05
   ```

3. **[`scripts/unity_extractor/unity_anim.py`](file:///home/verivi/Veras/Projects/CardWarsForLinux/scripts/unity_extractor/unity_anim.py)** — Inspects Unity `.anim` files (highlighting animated vs. constant curves and root `path: ""` curves) and emits ready-to-paste Godot GDScript `const` keyframe arrays with `S_Z` reflection and `_eval_quat` / `_eval_vec3` Hermite evaluators:
   ```bash
   # Inspect all curves in an .anim file:
   python3 scripts/unity_extractor/unity_anim.py --info "Assets/AnimationClip/SinglePlayer_Idle(copy).anim"

   # Emit Godot GDScript const keyframe tables & Hermite evaluators:
   python3 scripts/unity_extractor/unity_anim.py --emit-gd "Assets/AnimationClip/SinglePlayer_Idle(copy).anim" --prefix IDLE
   ```
