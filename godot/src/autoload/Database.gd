extends Node

var localized_strings: Dictionary = {}
var texture_map: Dictionary = {}
var cards_db: Dictionary = {}
var leaders_db: Dictionary = {}
var drop_profiles_db: Dictionary = {}
var creatures_list: Array = []
var spells_list: Array = []
var buildings_list: Array = []

func _ready() -> void:
	load_localizations()
	load_textures()
	load_blueprints()
	print("[Database] Loaded %d total cards (%d creatures, %d spells, %d buildings, %d leaders, %d drop profiles)" % [
		cards_db.size(), creatures_list.size(), spells_list.size(), buildings_list.size(), leaders_db.size(), drop_profiles_db.size()
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

func load_blueprints() -> void:
	_load_creatures()
	_load_spells()
	_load_buildings()
	_load_leaders()
	_load_drop_profiles()

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

	return {
		"id": id,
		"type": card_type,
		"name": localize(name_key),
		"raw_name": name_key,
		"desc": localize(desc_key, val1, val2),
		"faction": data.get("Faction", "Universal"),
		"cost": int(data.get("Cost", "1")),
		"atk": int(data.get("ATK", "0")),
		"def": int(data.get("DEF", "0")),
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

