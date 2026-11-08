class_name FusionEngine
extends RefCounted

## Card Quality & Fusion Engine (Task 6.2 / SYS-7 Composition)
## Composes the generic CraftingEngine (res://src/systems/crafting_fusion/CraftingEngine.gd)
## with Card Wars specific blueprints (db_Fusion.json) and Adventure Time card models.

const SystemCraftingEngine = preload("res://src/systems/crafting_fusion/CraftingEngine.gd")

enum QualityTier {
	STANDARD = 0,
	GOLD = 1,
	OBSIDIAN = 2
}

const GOLD_STAT_MULTIPLIER: float = SystemCraftingEngine.DEFAULT_TIER_1_MULT
const OBSIDIAN_STAT_MULTIPLIER: float = SystemCraftingEngine.DEFAULT_TIER_2_MULT


## Determines the quality tier of a card from its Dictionary or ID string.
static func get_card_quality(card_or_id: Variant) -> QualityTier:
	var cid: String = ""
	if typeof(card_or_id) == TYPE_DICTIONARY:
		if card_or_id.has("quality"):
			var q = card_or_id.get("quality")
			if typeof(q) == TYPE_INT:
				return clampi(q, 0, 2) as QualityTier
			var q_str = str(q).to_upper()
			if q_str == "GOLD":
				return QualityTier.GOLD
			elif q_str == "OBSIDIAN":
				return QualityTier.OBSIDIAN
		cid = str(card_or_id.get("id", ""))
	else:
		cid = str(card_or_id)

	if "_OB_" in cid or cid.ends_with("_OB") or cid.begins_with("OB_"):
		return QualityTier.OBSIDIAN
	if "_GL_" in cid or cid.ends_with("_GL") or cid.begins_with("GL_"):
		return QualityTier.GOLD
	return QualityTier.STANDARD


## Returns the human-readable name for a QualityTier.
static func get_quality_name(tier: QualityTier) -> String:
	match tier:
		QualityTier.GOLD:
			return "Gold"
		QualityTier.OBSIDIAN:
			return "Obsidian"
		_:
			return "Standard"


## Returns the stat multiplier for a given QualityTier:
## Standard = 1.0, Gold = 1.10 (+10%), Obsidian = 1.25 (+25%).
static func get_stat_multiplier(tier: QualityTier) -> float:
	match tier:
		QualityTier.GOLD:
			return GOLD_STAT_MULTIPLIER
		QualityTier.OBSIDIAN:
			return OBSIDIAN_STAT_MULTIPLIER
		_:
			return 1.0


## Computes scaled ATK and DEF for a base card dictionary at a target QualityTier.
## Ensures upgraded tiers grant at least +1 stat when base stat > 0.
static func compute_scaled_stats(base_atk: int, base_def: int, tier: QualityTier) -> Dictionary:
	var engine = SystemCraftingEngine.new()
	var base_dict = { "atk": base_atk, "def": base_def }
	var sys_tier = int(tier)
	var scaled = engine.compute_scaled_stats(base_dict, sys_tier)
	var mult = get_stat_multiplier(tier)

	return {
		"atk": int(scaled.get("atk", base_atk)),
		"def": int(scaled.get("def", base_def)),
		"multiplier": mult
	}


## Returns a copy of card_data upgraded to the specified QualityTier (with scaled ATK/DEF).
static func apply_quality_to_card(card_data: Dictionary, tier: QualityTier) -> Dictionary:
	var copy = card_data.duplicate(true)
	var base_atk = int(copy.get("base_atk", copy.get("atk", 0)))
	var base_def = int(copy.get("base_def", copy.get("def", 0)))
	copy["base_atk"] = base_atk
	copy["base_def"] = base_def
	copy["quality"] = tier
	copy["quality_name"] = get_quality_name(tier)

	var scaled = compute_scaled_stats(base_atk, base_def, tier)
	copy["atk"] = scaled["atk"]
	copy["def"] = scaled["def"]
	return copy


## Parses all fusion recipes from res://data/db_Fusion.json.
## Returns Array[Dictionary] where each recipe has:
## {
##   "card_id": String,
##   "cost": int,
##   "quest_unlock": int,
##   "quality": QualityTier,
##   "ingredients": Array[Dictionary] (each {"card_id": String, "count": int})
## }
static func load_fusion_recipes(json_path: String = "res://data/db_Fusion.json") -> Array[Dictionary]:
	var recipes: Array[Dictionary] = []
	if not FileAccess.file_exists(json_path):
		return recipes

	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return recipes

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_ARRAY:
		return recipes

	for raw in json.data:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var out_id = str(raw.get("Card_ID", "")).strip_edges()
		if out_id == "":
			continue

		var cost_str = str(raw.get("Cost", "0")).strip_edges()
		var cost_val = int(cost_str) if cost_str != "" else 0
		var quest_str = str(raw.get("Quest_Unlock", "0")).strip_edges()
		var quest_val = int(quest_str) if quest_str != "" else 0

		var ingredients: Array[Dictionary] = []
		for idx in range(1, 6):
			var c_name = str(raw.get("C%d_Name" % idx, "")).strip_edges()
			if c_name == "":
				continue
			var c_count_str = str(raw.get("C%d_Count" % idx, "1")).strip_edges()
			var c_count = int(c_count_str) if c_count_str != "" else 1
			if c_count <= 0:
				c_count = 1
			ingredients.append({
				"card_id": c_name,
				"count": c_count
			})

		if ingredients.is_empty():
			continue

		recipes.append({
			"card_id": out_id,
			"cost": cost_val,
			"quest_unlock": quest_val,
			"quality": get_card_quality(out_id),
			"ingredients": ingredients
		})

	return recipes


## Checks if the player can craft the given recipe with their owned_counts and coins.
## Delegates core verification to SystemCraftingEngine.
## Returns { "can_craft": bool, "missing_coins": int, "missing_ingredients": Array[Dictionary], "reason": String }
static func can_craft_recipe(
	recipe: Dictionary,
	owned_counts: Dictionary,
	player_coins: int
) -> Dictionary:
	var check = SystemCraftingEngine.check_can_craft(recipe, owned_counts, player_coins)
	var can_craft = check.get("can_craft", false)
	var missing_coins = int(check.get("missing_currency", 0))
	var missing_ingredients: Array[Dictionary] = []

	for item in check.get("missing_ingredients", []):
		missing_ingredients.append({
			"card_id": item.get("item_id", ""),
			"required": item.get("required", 1),
			"owned": item.get("owned", 0),
			"missing": item.get("missing", 1)
		})

	var reason = ""
	if not missing_ingredients.is_empty():
		var first = missing_ingredients[0]
		var c_info = Database.get_card(str(first["card_id"]))
		var c_title = c_info.get("name", first["card_id"]) if not c_info.is_empty() else first["card_id"]
		reason = "Missing %dx %s (%d/%d owned)." % [first["missing"], c_title, first["owned"], first["required"]]
	elif missing_coins > 0:
		var cost = int(recipe.get("cost", 0))
		reason = "Need %d more coins (Cost: %d, Have: %d)." % [missing_coins, cost, player_coins]

	return {
		"can_craft": can_craft,
		"missing_coins": missing_coins,
		"missing_ingredients": missing_ingredients,
		"reason": reason
	}


## Executes a fusion recipe against a mutable owned_counts Dictionary and coin balance.
## Delegates ledger update to SystemCraftingEngine.
## Returns { "ok": bool, "output_card_id": String, "new_coins": int, "owned_counts": Dictionary, "reason": String }
static func execute_fusion(
	recipe: Dictionary,
	owned_counts: Dictionary,
	player_coins: int
) -> Dictionary:
	var check = can_craft_recipe(recipe, owned_counts, player_coins)
	if not check.get("can_craft", false):
		return {
			"ok": false,
			"output_card_id": "",
			"new_coins": player_coins,
			"owned_counts": owned_counts,
			"reason": str(check.get("reason", "Requirements not met."))
		}

	var res = SystemCraftingEngine.execute_craft(recipe, owned_counts, player_coins)
	var out_id = str(recipe.get("card_id", res.get("output_id", "")))

	return {
		"ok": res.get("ok", false),
		"output_card_id": out_id,
		"new_coins": int(res.get("remaining_currency", player_coins)),
		"owned_counts": owned_counts,
		"reason": "Successfully fused %s!" % out_id
	}
