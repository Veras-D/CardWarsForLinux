extends Node

var localized_strings: Dictionary = {}
var texture_map: Dictionary = {}
var cards_db: Dictionary = {}
var creatures_list: Array = []
var spells_list: Array = []
var buildings_list: Array = []

func _ready() -> void:
	load_localizations()
	load_textures()
	load_blueprints()
	print("[Database] Loaded %d total cards (%d creatures, %d spells, %d buildings)" % [
		cards_db.size(), creatures_list.size(), spells_list.size(), buildings_list.size()
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

func get_card_texture(texture_path: String) -> Texture2D:
	if ResourceLoader.exists(texture_path):
		return load(texture_path)
	return load("res://assets/textures/icon.png")
