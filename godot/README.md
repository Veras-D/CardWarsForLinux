# Card Wars (Godot 4 PC Remake)

An open-source remake of *Adventure Time: Card Wars* built in **Godot 4.7+** using the original card blueprints, stats, localizations, and textures.

## Features Built
* **Data Integration**:
  * Loads **416 total cards** (341 creatures, 48 spells, 27 buildings) dynamically from `data/db_Creatures.json`, `data/db_Spells.json`, and `data/db_Buildings.json`.
  * Fully mapped card art illustrations (`assets/textures/cardart/`).
  * 1,100+ localized English card names, descriptions, and ability texts (`data/strings_en.json`).
* **Tactical 4-Lane Combat**:
  * Opponent lanes vs. Player lanes with landscape affinities (Corn, Plains, Cotton, Sand, Swamp).
  * Magic Points (MP) progression each turn (up to 10 MP).
  * Summoning creatures onto lanes matching their cost.
  * **Floop Abilities**: Activate creature abilities (e.g., The Pig lowers opponent ATK, Angel Eye draws cards, etc.).
  * **Battle Phase**: Direct lane combat (attacker ATK vs defender DEF) or direct Hero damage if the opposing lane is unoccupied.
* **Menus & Compendium**:
  * Main Menu with direct battle launch (Finn vs Jake).
  * Card Compendium modal to browse all 340+ original creatures and card stats.

## Running the Game
You can open this project in Godot 4 Editor by selecting the `godot/` folder, or launch it directly from the terminal:
```bash
./scripts/run-godot.sh
```
