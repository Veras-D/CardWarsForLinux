extends Node

var localized_strings: Dictionary = {}
var texture_map: Dictionary = {}
var cards_db: Dictionary = {}
var leaders_db: Dictionary = {}
var drop_profiles_db: Dictionary = {}
var creatures_list: Array = []
var spells_list: Array = []
var buildings_list: Array = []
var all_cards_list: Array = []
var preset_decks_db: Dictionary = {}
var fusion_recipes_list: Array[Dictionary] = []
var fusion_recipes_db: Dictionary = {}
var rank_up_db: Dictionary = {}
var lvup_schemes_db: Dictionary = {}
var gacha_pools_db: Dictionary = {}
var gacha_schedules_list: Array[Dictionary] = []
var chest_defs_db: Dictionary = {}
var quests_db: Dictionary = {}
var main_quests_list: Array[Dictionary] = []
var fc_quests_list: Array[Dictionary] = []
var quest_conditions_db: Dictionary = {}
var map_regions_list: Array[Dictionary] = []
var fc_map_regions_list: Array[Dictionary] = []

func _ready() -> void:
	load_localizations()
	load_textures()
	load_blueprints()
	print("[Database] Loaded %d total cards (%d creatures, %d spells, %d buildings, %d leaders, %d drop profiles, %d rank levels, %d gacha pools, %d quests, %d conditions, %d regions)" % [
		cards_db.size(), creatures_list.size(), spells_list.size(), buildings_list.size(), leaders_db.size(), drop_profiles_db.size(), rank_up_db.size(), gacha_pools_db.size(), quests_db.size(), quest_conditions_db.size(), map_regions_list.size()
	])

func load_localizations() -> void:
	var path = "res://data/strings_en.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			localized_strings = json.data

func load_textures() -> void:
	var path = "res://data/texture_map.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			texture_map = json.data

const FusionEngine = preload("res://src/cards/FusionEngine.gd")

func load_blueprints() -> void:
	_load_creatures()
	_load_spells()
	_load_buildings()
	_load_leaders()
	_load_drop_profiles()
	_load_preset_decks()
	_load_fusion_recipes()
	_load_rank_ups()
	_load_lvup_schemes()
	_load_gacha_weights()
	_load_gacha_schedule()
	_load_quest_conditions()
	_load_quests()
	_load_map_regions()
	_load_fc_map()
	all_cards_list.clear()
	all_cards_list.append_array(creatures_list)
	all_cards_list.append_array(spells_list)
	all_cards_list.append_array(buildings_list)

func _load_leaders() -> void:
	var path = "res://data/db_Leaders.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	for item in json.data:
		var val1 = str(item.get("Val1", ""))
		var val2 = str(item.get("Val2", ""))
		var char_id = item.get("CharacterID", "")
		var id = item.get("ID", "")
		var leader = {
			"id": id,
			"character_id": char_id,
			"name": localize(item.get("Name", "")),
			"desc": localize(item.get("Desc", ""), val1, val2),
			"cooldown": int(item.get("Cooldown", "0")),
			"base_hp": int(item.get("BaseHP", "25")),
			"script_name": item.get("ScriptName", ""),
			"val1": val1,
			"val2": val2,
			"for_faction": item.get("forFaction", ""),
			"sprite_name": item.get("SpriteName", "")
		}
		leaders_db[id] = leader
		if char_id != "" and not leaders_db.has(char_id):
			leaders_db[char_id] = leader

func _load_creatures() -> void:
	var path = "res://data/db_Creatures.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	for item in json.data:
		var card = _parse_card(item, "CREATURE")
		cards_db[card.id] = card
		creatures_list.append(card)

func _load_spells() -> void:
	var path = "res://data/db_Spells.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	for item in json.data:
		var card = _parse_card(item, "SPELL")
		cards_db[card.id] = card
		spells_list.append(card)

func _load_buildings() -> void:
	var path = "res://data/db_Buildings.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	for item in json.data:
		var card = _parse_card(item, "BUILDING")
		cards_db[card.id] = card
		buildings_list.append(card)

func _parse_card(data: Dictionary, card_type: String) -> Dictionary:
	var id = data.get("ID", "")
	var name_key = data.get("Name", "")
	var desc_key = data.get("Desc", "")
	var sprite_name = data.get("SpriteName", id)
	var val1 = str(data.get("val1", ""))
	var val2 = str(data.get("val2", ""))

	var tex_path = texture_map.get(sprite_name, "")
	if tex_path == "":
		tex_path = texture_map.get(id, "res://assets/textures/icon.png")

	var raw_atk = int(data.get("ATK", "0"))
	var raw_def = int(data.get("DEF", "0"))
	var quality_tier = FusionEngine.get_card_quality(id)

	return {
		"id": id,
		"type": card_type,
		"name": localize(name_key),
		"raw_name": name_key,
		"desc": localize(desc_key, val1, val2),
		"faction": data.get("Faction", "Universal"),
		"cost": int(data.get("Cost", "1")),
		"atk": raw_atk,
		"def": raw_def,
		"base_atk": raw_atk,
		"base_def": raw_def,
		"quality": quality_tier,
		"quality_name": FusionEngine.get_quality_name(quality_tier),
		"floop_cost": int(data.get("FloopCost", "0")),
		"ability_type": data.get("AbilityType", "NONE"),
		"script_name": data.get("ScriptName", ""),
		"val1": val1,
		"val2": val2,
		"texture_path": tex_path
	}

func localize(key: String, val1: String = "", val2: String = "") -> String:
	if not key.begins_with("!!"):
		return key
	var text = localized_strings.get(key, key)
	if val1 != "":
		text = text.replace("<val1>", val1)
	if val2 != "":
		text = text.replace("<val2>", val2)
	return text

func get_card(id: String) -> Dictionary:
	return cards_db.get(id, {})

func get_leader(character_or_leader_id: String) -> Dictionary:
	return leaders_db.get(character_or_leader_id, {})

func get_card_texture(texture_path: String) -> Texture2D:
	if ResourceLoader.exists(texture_path):
		return load(texture_path)
	return load("res://assets/textures/icon.png")

func _load_drop_profiles() -> void:
	var path = "res://data/db_DropProfile.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	for item in json.data:
		var profile_id = str(item.get("DropProfileID", "")).strip_edges()
		if profile_id == "":
			continue
		var chest_drop_percentages: Array[float] = []
		var card_weights: Array[int] = []
		var coin_drop_percentages: Array[float] = []
		var coin_amounts: Array[int] = []
		var coin_weights: Array[int] = []
		var item_drop_percentages: Array[float] = []

		for n in range(1, 16):
			var chest_key = "ChestDropPercentage" + str(n)
			if item.has(chest_key):
				var val = float(item[chest_key])
				if val > 1.0:
					val /= 100.0
				chest_drop_percentages.append(val)
			var card_w_key = "CardWeight" + str(n)
			if item.has(card_w_key):
				card_weights.append(int(item[card_w_key]))
			var coin_pct_key = "CoinDropPercentage" + str(n)
			if item.has(coin_pct_key):
				var val = float(item[coin_pct_key])
				if val > 1.0:
					val /= 100.0
				coin_drop_percentages.append(val)
			var coin_amt_key = "CoinAmount" + str(n)
			if item.has(coin_amt_key):
				coin_amounts.append(int(item[coin_amt_key]))
			var coin_w_key = "CoinWeight" + str(n)
			if item.has(coin_w_key):
				coin_weights.append(int(item[coin_w_key]))
			var item_pct_key = "ItemDropPercentage" + str(n)
			if item.has(item_pct_key):
				var val = float(item[item_pct_key])
				if val > 1.0:
					val /= 100.0
				item_drop_percentages.append(val)

		drop_profiles_db[profile_id] = {
			"id": profile_id,
			"chest_drop_percentages": chest_drop_percentages,
			"card_weights": card_weights,
			"coin_drop_percentages": coin_drop_percentages,
			"coin_amounts": coin_amounts,
			"coin_weights": coin_weights,
			"item_drop_percentages": item_drop_percentages
		}

func get_drop_profile(profile_id: String) -> Dictionary:
	return drop_profiles_db.get(profile_id, {})

func _load_preset_decks() -> void:
	var path = "res://data/db_Decks.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_ARRAY:
		return
	var current_did: String = ""
	for item in json.data:
		var raw_did = str(item.get("DeckID", "")).strip_edges()
		if raw_did != "":
			current_did = raw_did
			if not preset_decks_db.has(current_did):
				preset_decks_db[current_did] = []
		if current_did == "":
			continue
		var cid = str(item.get("Cards", item.get("Card", ""))).strip_edges()
		if cid == "":
			continue
		var qty = int(item.get("Quantity", "1"))
		for _i in range(max(1, qty)):
			preset_decks_db[current_did].append(cid)

func get_preset_deck(deck_id: String) -> Array:
	return preset_decks_db.get(deck_id, []).duplicate()

func _load_fusion_recipes() -> void:
	fusion_recipes_list = FusionEngine.load_fusion_recipes("res://data/db_Fusion.json")
	fusion_recipes_db.clear()
	for rec in fusion_recipes_list:
		var cid = str(rec.get("card_id", ""))
		if cid != "":
			fusion_recipes_db[cid] = rec

func get_fusion_recipe(card_id: String) -> Dictionary:
	return fusion_recipes_db.get(card_id, {})

func _load_rank_ups() -> void:
	var path = "res://data/db_RankUp.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_ARRAY:
		return
	for item in json.data:
		var rank_val = int(item.get("LeaderRank", "1"))
		rank_up_db[rank_val] = {
			"rank": rank_val,
			"deck_max_size": int(item.get("DeckMaxSize", "15")),
			"pvp_coins": int(item.get("PvP_Search_Coins", "15")),
			"pvp_gems": int(item.get("PvP_Search_Gems", "1")),
			"pvp_entry": int(item.get("PvP_Entry", "1"))
		}

func get_rank_info(rank: int) -> Dictionary:
	return rank_up_db.get(rank, {
		"rank": rank,
		"deck_max_size": 15 if rank <= 1 else 40,
		"pvp_coins": 15,
		"pvp_gems": 1,
		"pvp_entry": 1
	})

func _load_lvup_schemes() -> void:
	var path = "res://data/db_LvUpScheme.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_ARRAY:
		return
	for item in json.data:
		var sid = str(item.get("LvUpSchemeID", "")).strip_edges()
		if sid != "":
			lvup_schemes_db[sid] = float(item.get("LvIndex", "100.0"))

func get_lvup_scheme_index(scheme_id: String) -> float:
	return lvup_schemes_db.get(scheme_id, 100.0)

func _load_gacha_weights() -> void:
	var path = "res://data/db_GachaWeights.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_ARRAY:
		return
	var cool_items: Array[Dictionary] = []
	var algebraic_items: Array[Dictionary] = []
	for item in json.data:
		var card_id = str(item.get("CardID", "")).strip_edges()
		if card_id == "":
			continue
		var rarity = str(item.get("Quality", "Standard")).strip_edges()
		if rarity == "":
			rarity = "Standard"
		var normal_w = int(item.get("NormalChestWeight", "0"))
		var premium_w = int(item.get("PremiumChestWeight", "0"))
		if normal_w > 0:
			cool_items.append({
				"id": card_id,
				"weight": normal_w,
				"rarity": rarity,
				"metadata": {"card_id": card_id, "quality": rarity}
			})
		if premium_w > 0:
			algebraic_items.append({
				"id": card_id,
				"weight": premium_w,
				"rarity": rarity,
				"metadata": {"card_id": card_id, "quality": rarity}
			})
	gacha_pools_db["cool_chest"] = cool_items
	gacha_pools_db["algebraic_chest"] = algebraic_items

func _load_gacha_schedule() -> void:
	chest_defs_db = {
		"cool_chest": {
			"id": "cool_chest",
			"name": "Cool Chest",
			"currency": "coins",
			"cost": 10000,
			"pool": "cool_chest"
		},
		"algebraic_chest": {
			"id": "algebraic_chest",
			"name": "Algebraic Chest",
			"currency": "gems",
			"cost": 3,
			"pool": "algebraic_chest"
		}
	}
	var path = "res://data/db_GachaSchedule.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_ARRAY:
		return
	gacha_schedules_list.clear()
	for item in json.data:
		gacha_schedules_list.append(item)
		var ctype = str(item.get("ChestType", "")).to_lower()
		var start_d = str(item.get("StartDate", "")).to_lower()
		if start_d == "default":
			if ctype == "normal":
				var coins_val = int(item.get("Coins", "10000"))
				if coins_val > 0:
					chest_defs_db["cool_chest"]["cost"] = coins_val
			elif ctype == "premium":
				var gems_val = int(item.get("Gems", "3"))
				if gems_val > 0:
					chest_defs_db["algebraic_chest"]["cost"] = gems_val

func get_gacha_pool(pool_name: String) -> Array[Dictionary]:
	var p = gacha_pools_db.get(pool_name, [])
	var res: Array[Dictionary] = []
	for it in p:
		res.append(it)
	return res

func get_chest_def(chest_type: String) -> Dictionary:
	var key = chest_type.to_lower()
	if key == "normal" or key == "cool":
		key = "cool_chest"
	elif key == "premium" or key == "algebraic":
		key = "algebraic_chest"
	return chest_defs_db.get(key, {})

const QUEST_CONDITION_STRINGS: Dictionary = {
	"!!QUESTCONDITION_JUSTWIN": "Beat your opponent to win a star!",
	"!!QUESTCONDITION_FASTWIN3": "Beat the opponent in 3 turns or less.",
	"!!QUESTCONDITION_FASTWIN5": "Beat the opponent in 5 turns or less.",
	"!!QUESTCONDITION_FASTWIN7": "Beat the opponent in 7 turns or less.",
	"!!QUESTCONDITION_FASTWIN10": "Beat the opponent in 10 turns or less.",
	"!!QUESTCONDITION_ONLY5HP": "Don't lose more than 5 HP on your Hero.",
	"!!QUESTCONDITION_ONLY10HP": "Don't lose more than 10 HP on your Hero.",
	"!!QUESTCONDITION_ONLY25HP": "Don't lose more than 25 HP on your Hero.",
	"!!QUESTCONDITION_ONLY50HP": "Don't lose more than 50 HP on your Hero.",
	"!!QUESTCONDITION_ONLY100HP": "Don't lose more than 100 HP on your Hero.",
	"!!QUESTCONDITION_ONLYLOSE2CREATURES": "Don't lose more than 2 creatures.",
	"!!QUESTCONDITION_ONLYLOSE3CREATURES": "Don't lose more than 3 creatures.",
	"!!QUESTCONDITION_ONLYLOSE5CREATURES": "Don't lose more than 5 creatures.",
	"!!QUESTCONDITION_ONLYLOSE10CREATURES": "Don't lose more than 10 creatures.",
	"!!QUESTCONDITION_DEFEAT2": "Defeat at least 2 Creatures.",
	"!!QUESTCONDITION_DEFEAT5": "Defeat at least 5 Creatures.",
	"!!QUESTCONDITION_DEAFEAT10": "Defeat at least 10 Creatures.",
	"!!QUESTCONDITION_DEFEAT15": "Defeat at least 15 Creatures.",
	"!!QUESTCONDITION_DEFEAT20": "Defeat at least 20 Creatures.",
	"!!QUESTCONDITION_DEFEAT25": "Defeat at least 25 Creatures.",
	"!!QUESTCONDITION_LANDSCAPES_TWO": "Use two different landscapes.",
	"!!QUESTCONDITION_LANDSCAPES_THREE": "Use three different landscapes.",
	"!!QUESTCONDITION_LANDSCAPES_FOUR": "Use four different landscapes.",
	"!!QUESTCONDITION_FORBID_SPELLS": "Beat the opponent without using Spell cards.",
	"!!QUESTCONDITION_FORBID_CREATURES": "Beat the opponent without using Creature cards.",
	"!!QUESTCONDITION_FORBID_BUILDINGS": "Beat the opponent without using Building cards.",
	"!!QUESTCONDITION_ONLY_CREATURES": "Beat the opponent using only Creature cards.",
	"!!QUESTCONDITION_ONLY_SPELLS": "Beat the opponent using only Spell cards.",
	"!!QUESTCONDITION_FORBID_CORN": "Beat the opponent without using Corn cards.",
	"!!QUESTCONDITION_FORBID_PLAINS": "Beat the opponent without using Blue Plains cards.",
	"!!QUESTCONDITION_FORBID_SWAMP": "Beat the opponent without using Useless Swamp cards.",
	"!!QUESTCONDITION_FORBID_COTTON": "Beat the opponent without using Nice Lands cards.",
	"!!QUESTCONDITION_FORBID_SAND": "Beat the opponent without using Sandy Lands cards.",
	"!!QUESTCONDITION_FORBID_UNIVERSAL": "Beat the opponent without using Rainbow cards.",
	"!!QUESTCONDITION_ONLY_CORN": "Beat the opponent using only Corn cards.",
	"!!QUESTCONDITION_ONLY_PLAINS": "Beat the opponent using only Blue Plains cards.",
	"!!QUESTCONDITION_ONLY_SWAMP": "Beat the opponent using only Useless Swamp cards.",
	"!!QUESTCONDITION_ONLY_COTTON": "Beat the opponent using only Nice Lands cards.",
	"!!QUESTCONDITION_ONLY_SAND": "Beat the opponent using only Sandy Lands cards.",
	"!!QUESTCONDITION_ONLY_UNIVERSAL": "Beat the opponent using only Rainbow cards.",
	"!!QUESTCONDITION_MAXCOST30": "Don't use a deck that costs more than 30.",
	"!!QUESTCONDITION_MAXFLOOP0": "Don't use any floops.",
	"!!QUESTCONDITION_MAXFLOOP1": "Don't use more than one floop.",
	"!!QUESTCONDITION_MAXFLOOP3": "Don't use more than three floops.",
	"!!QUESTCONDITION_ONLY0POINTCARDS": "Don't use cards with more than 0 Magic Points.",
	"!!QUESTCONDITION_ONLY1POINTCARDS": "Don't use cards with more than 1 Magic Points.",
	"!!QUESTCONDITION_ONLY2POINTCARDS": "Don't use cards with more than 2 Magic Points.",
	"!!QUESTCONDITION_ONLY3POINTCARDS": "Don't use cards with more than 3 Magic Points.",
	"!!QUESTCONDITION_ONLY10POINTS": "Don't use more than 10 Magic Points total.",
	"!!QUESTCONDITION_ONLY15POINTS": "Don't use more than 15 Magic Points total.",
	"!!QUESTCONDITION_ONLY20POINTS": "Don't use more than 20 Magic Points total.",
	"!!QUESTCONDITION_ONLY25POINTS": "Don't use more than 25 Magic Points total.",
	"!!QUESTCONDITION_TREASURECAT": "Defeat the cat, claim the loot."
}

func get_condition_description(cond_id: String) -> String:
	var cond = get_quest_condition(cond_id)
	if cond.is_empty():
		return cond_id
	var raw_desc = str(cond.get("Description", ""))
	if QUEST_CONDITION_STRINGS.has(raw_desc):
		return QUEST_CONDITION_STRINGS[raw_desc]
	if raw_desc != "" and not raw_desc.begins_with("!!"):
		return raw_desc
	return cond_id

func _load_quest_conditions() -> void:
	var path = "res://data/db_QuestConditions.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_ARRAY:
		return
	quest_conditions_db.clear()
	for item in json.data:
		var cid = str(item.get("ID", "")).strip_edges()
		if cid != "":
			var raw_desc = str(item.get("Description", ""))
			if QUEST_CONDITION_STRINGS.has(raw_desc):
				item["Description"] = QUEST_CONDITION_STRINGS[raw_desc]
			item["description"] = item["Description"]
			quest_conditions_db[cid] = item

func _load_map_regions() -> void:
	var path = "res://data/db_Map.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_ARRAY:
		return
	map_regions_list.clear()
	for item in json.data:
		map_regions_list.append(item)

func _load_fc_map() -> void:
	var path = "res://data/db_FCMap.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_ARRAY:
		return
	fc_map_regions_list.clear()
	for item in json.data:
		fc_map_regions_list.append(item)

func _load_quests() -> void:
	var path = "res://data/db_Quest.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_ARRAY:
		return

	quests_db.clear()
	main_quests_list.clear()
	fc_quests_list.clear()

	for item in json.data:
		var qid = str(item.get("QuestID", "")).strip_edges()
		if qid == "":
			continue

		var qtype = str(item.get("QuestType", "main")).strip_edges()
		var qlabel = str(item.get("QuestLabel", qid)).strip_edges()

		# Build conditions list
		var cond_ids: Array[String] = []
		var conditions: Array[Dictionary] = []
		for c_idx in [1, 2, 3]:
			var c_key = "Condition" + str(c_idx)
			var c_id = str(item.get(c_key, "")).strip_edges()
			if c_id != "":
				cond_ids.append(c_id)
				var cond_data = quest_conditions_db.get(c_id, {"id": c_id, "ID": c_id}).duplicate(true)
				cond_data["id"] = c_id
				cond_data["ID"] = c_id
				conditions.append(cond_data)

		# Build unlock targets (supporting comma-separated lists e.g. "5002, 5044")
		var unlock_ids: Array[String] = []
		for u_idx in [1, 2, 3]:
			var u_key = "UnlockQuestIDs" + str(u_idx)
			var raw_u = str(item.get(u_key, "")).strip_edges()
			if raw_u != "":
				for part in raw_u.split(","):
					var clean_id = part.strip_edges()
					if clean_id != "" and not unlock_ids.has(clean_id):
						unlock_ids.append(clean_id)

		# Card drops
		var card_drops: Array[String] = []
		for cd_idx in range(1, 9):
			var cd_key = "CardDrop" + str(cd_idx)
			var cd_id = str(item.get(cd_key, "")).strip_edges()
			if cd_id != "":
				card_drops.append(cd_id)

		# Calculate map position
		var pos = Vector2.ZERO
		if qid.is_valid_int():
			var num = int(qid)
			if num >= 5001 and num <= 5061:
				var fc_idx = num - 5001
				var region_idx = fc_idx / 8
				var local_idx = fc_idx % 8
				var pos_x = (120.0 + (local_idx * 150.0)) if (region_idx % 2 == 0) else (120.0 + (7 - local_idx) * 150.0)
				var pos_y = 120.0 + (region_idx * 180.0) + (sin(float(local_idx) * 0.9) * 35.0)
				pos = Vector2(pos_x, pos_y)
			else:
				var region_idx = (num - 1) / 15
				var local_idx = (num - 1) % 15
				var pos_x = (100.0 + (local_idx * 95.0)) if (region_idx % 2 == 0) else (100.0 + (14 - local_idx) * 95.0)
				var pos_y = 120.0 + (region_idx * 200.0) + (sin(float(local_idx) * 0.7) * 40.0)
				pos = Vector2(pos_x, pos_y)

		var quest_entry = {
			"id": qid,
			"label": qlabel,
			"type": qtype,
			"opponent": str(item.get("Opponent", "")).strip_edges(),
			"deck_id": str(item.get("Deck", "")).strip_edges(),
			"leader_id": str(item.get("LeaderID", "")).strip_edges(),
			"leader_level": int(item.get("LeaderLevel", "1")),
			"stamina": int(item.get("Stamina", "1")),
			"min_xp": float(item.get("MinXP", "0")),
			"max_xp": float(item.get("MaxXP", "0")),
			"min_coins": int(item.get("MinCoins", "0")),
			"max_coins": int(item.get("MaxCoins", "0")),
			"spin_factor": float(item.get("SpinFactor", "1.6")),
			"condition_ids": cond_ids,
			"conditions": conditions,
			"unlock_ids": unlock_ids,
			"level_prefab": str(item.get("LevelPrefab", "")).strip_edges(),
			"level_name": str(item.get("LevelName", "")).strip_edges(),
			"drop_profile_id": str(item.get("DropProfileID", "")).strip_edges(),
			"card_drops": card_drops,
			"position": pos,
			"prerequisites": []
		}

		quests_db[qid] = quest_entry
		if qtype == "main":
			main_quests_list.append(quest_entry)
		elif qtype == "fc":
			fc_quests_list.append(quest_entry)

	# Precompute prerequisites from unlock_ids
	for qid in quests_db.keys():
		var q = quests_db[qid]
		for u_id in q.get("unlock_ids", []):
			if quests_db.has(u_id):
				var target_prereqs: Array = quests_db[u_id].get("prerequisites", [])
				if not target_prereqs.has(qid):
					target_prereqs.append(qid)
				quests_db[u_id]["prerequisites"] = target_prereqs

func get_quest(quest_id: String) -> Dictionary:
	return quests_db.get(quest_id, {}).duplicate(true)

func get_quest_condition(cond_id: String) -> Dictionary:
	return quest_conditions_db.get(cond_id, {}).duplicate(true)

func get_map_regions() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for r in map_regions_list:
		res.append(r.duplicate(true))
	return res

func get_fc_map_regions() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for r in fc_map_regions_list:
		res.append(r.duplicate(true))
	return res

func get_fc_quests() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for q in fc_quests_list:
		res.append(q.duplicate(true))
	return res




