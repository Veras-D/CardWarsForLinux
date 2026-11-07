class_name VOManager
extends Node

## Comprehensive Voice-Over Manager for Card Wars
## Handles character-specific battle voice lines (Finn, Jake, Marceline, Lemongrab, BMO, etc.)
## routed directly to the Voice bus with activation rules parsed from db_CharacterVO.json.

enum VOEvent {
	OPENING,
	WIN,
	LOSE,
	DESTROY_CREATURE,
	PLAY_CREATURE,
	PLAY_BUILDING,
	PLAY_SPELL,
	CREATURE_DESTROYED,
	BUILDING_DESTROYED,
	FLOOP,
	HERO_DAMAGED,
	LEADER_ABILITY
}

signal vo_played(character: String, event: VOEvent, clip_path: String)
signal vo_skipped(character: String, event: VOEvent, reason: String)

@export var vo_enabled: bool = true

# Activation rules from db_CharacterVO.json:
# key = event_string, value = { "chance": float, "player": bool, "opponent": bool }
var _event_rules: Dictionary = {}

# Catalog of available clips:
# key = "Character_EventID", value = Array[String] (file paths)
var _clip_catalog: Dictionary = {}

# Last played clip per key to avoid repeating the identical sound back-to-back
var _last_played_clip: Dictionary = {}

# Dedicated internal player if Audio autoload is not active
var _internal_player: AudioStreamPlayer = null


func _init() -> void:
	_load_event_rules()
	_build_clip_catalog()


func _ready() -> void:
	if _internal_player == null:
		_internal_player = AudioStreamPlayer.new()
		_internal_player.name = "VOManager_Player"
		var bus_name = "Voice" if AudioServer.get_bus_index("Voice") != -1 else "Master"
		_internal_player.bus = bus_name
		add_child(_internal_player)


func normalize_hero_name(char_name: String) -> String:
	var clean = char_name.strip_edges()
	match clean:
		"PrincessBubblegum", "Princess Bubblegum", "PB", "Bubblegum":
			return "PBG"
		"FlamePrincess", "Flame Princess":
			return "FP"
		"EarlOfLemongrab", "Earl of Lemongrab":
			return "Lemongrab"
		"LumpySpacePrincess", "LSP":
			return "LSP"
		"IceKing":
			return "Ice King"
		"LadyRainicorn":
			return "Lady Rainicorn"
		"MagicMan":
			return "Magic Man"
		"CinnamonBun":
			return "Cinnamon Bun"
		_:
			return clean


func get_event_id_string(event: VOEvent) -> String:
	match event:
		VOEvent.OPENING: return "Opening"
		VOEvent.WIN: return "Win"
		VOEvent.LOSE: return "Lose"
		VOEvent.DESTROY_CREATURE: return "DestroyCreature"
		VOEvent.PLAY_CREATURE: return "PlayCreature"
		VOEvent.PLAY_BUILDING: return "PlayBuilding"
		VOEvent.PLAY_SPELL: return "PlaySpell"
		VOEvent.CREATURE_DESTROYED: return "CreatureDestroyed"
		VOEvent.BUILDING_DESTROYED: return "BuildingDestroyed"
		VOEvent.FLOOP: return "Floop"
		VOEvent.HERO_DAMAGED: return "HeroDamaged"
		VOEvent.LEADER_ABILITY: return "LeaderAbility"
		_: return "Opening"


func _load_event_rules() -> void:
	# Set baseline hardcoded defaults in case file is absent
	_event_rules = {
		"Opening": { "chance": 1.0, "player": true, "opponent": false },
		"Win": { "chance": 1.0, "player": true, "opponent": false },
		"Lose": { "chance": 1.0, "player": true, "opponent": false },
		"DestroyCreature": { "chance": 0.5, "player": true, "opponent": true },
		"PlayCreature": { "chance": 0.5, "player": true, "opponent": true },
		"PlayBuilding": { "chance": 0.5, "player": true, "opponent": true },
		"PlaySpell": { "chance": 0.5, "player": true, "opponent": true },
		"CreatureDestroyed": { "chance": 0.5, "player": true, "opponent": true },
		"BuildingDestroyed": { "chance": 0.5, "player": true, "opponent": true },
		"Floop": { "chance": 0.5, "player": true, "opponent": true },
		"HeroDamaged": { "chance": 1.0, "player": true, "opponent": true },
		"LeaderAbility": { "chance": 1.0, "player": true, "opponent": true }
	}

	var json_path = "res://data/db_CharacterVO.json"
	if FileAccess.file_exists(json_path):
		var file = FileAccess.open(json_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_ARRAY:
				for item in json.data:
					if typeof(item) == TYPE_DICTIONARY:
						var eid = str(item.get("EventID", ""))
						var chance = float(item.get("ActivateChance", 0.5))
						var p = str(item.get("Player", "true")).to_lower() == "true"
						var o = str(item.get("Opponent", "false")).to_lower() == "true"
						_event_rules[eid] = {
							"chance": chance,
							"player": p,
							"opponent": o
						}


func _build_clip_catalog() -> void:
	_clip_catalog.clear()
	var dir = DirAccess.open("res://assets/audio/vo")
	if not dir:
		return

	dir.list_dir_begin()
	var f_name = dir.get_next()
	var all_files: Array[String] = []
	while f_name != "":
		if not dir.current_is_dir() and f_name.ends_with(".wav"):
			all_files.append(f_name)
		f_name = dir.get_next()

	# Map events to file matchers
	var matcher: Dictionary = {
		"Opening": ["Opening"],
		"Win": ["Win", "Winner"],
		"Lose": ["Lose", "Defeat"],
		"DestroyCreature": ["Destroy_Creature", "DestroyCreature"],
		"PlayCreature": ["Play_Creature", "PlayCreature"],
		"PlayBuilding": ["Play_Building", "PlayBuilding"],
		"PlaySpell": ["Play_Spell", "PlaySpell"],
		"CreatureDestroyed": ["Creature_Destroyed", "CreatureDestroyed"],
		"BuildingDestroyed": ["Building_Destroyed", "BuildingDestroyed"],
		"Floop": ["Floop_Ability", "Floop"],
		"HeroDamaged": ["Hero_Damage", "HeroDamage"],
		"LeaderAbility": ["Power", "Leader"]
	}

	for f in all_files:
		var path = "res://assets/audio/vo/" + f
		for evt_id in matcher:
			var patterns: Array = matcher[evt_id]
			for pat in patterns:
				if ("_" + pat) in f:
					var prefix = f.split("_" + pat)[0]
					var cat_key = prefix + "_" + evt_id
					if not _clip_catalog.has(cat_key):
						_clip_catalog[cat_key] = []
					_clip_catalog[cat_key].append(path)
					break


func get_candidate_clips(hero_name: String, event: VOEvent) -> Array[String]:
	var norm_hero = normalize_hero_name(hero_name)
	var evt_str = get_event_id_string(event)
	var key = norm_hero + "_" + evt_str

	if _clip_catalog.has(key) and not _clip_catalog[key].is_empty():
		var res: Array[String] = []
		for p in _clip_catalog[key]:
			res.append(str(p))
		return res

	# Hero-specific aliases / fallbacks
	if event == VOEvent.WIN:
		# Fallback to DestroyCreature or Power
		var fallback_key = norm_hero + "_DestroyCreature"
		if _clip_catalog.has(fallback_key) and not _clip_catalog[fallback_key].is_empty():
			var res: Array[String] = []
			for p in _clip_catalog[fallback_key]:
				res.append(str(p))
			return res
	elif event == VOEvent.LEADER_ABILITY:
		var p_path = "res://assets/audio/vo/%s_Power.wav" % norm_hero
		if FileAccess.file_exists(p_path):
			return [p_path]
		var f_key = norm_hero + "_Floop"
		if _clip_catalog.has(f_key) and not _clip_catalog[f_key].is_empty():
			var res: Array[String] = []
			for p in _clip_catalog[f_key]:
				res.append(str(p))
			return res

	# Check global Finn fallback
	var finn_key = "Finn_" + evt_str
	if _clip_catalog.has(finn_key) and not _clip_catalog[finn_key].is_empty():
		var res: Array[String] = []
		for p in _clip_catalog[finn_key]:
			res.append(str(p))
		return res

	return []


func play_event(char_name: String, event: VOEvent, is_player: bool = true, force: bool = false) -> bool:
	if not vo_enabled:
		vo_skipped.emit(char_name, event, "vo_disabled")
		return false

	var evt_str = get_event_id_string(event)
	var rule = _event_rules.get(evt_str, { "chance": 1.0, "player": true, "opponent": true })

	# Check player / opponent permission
	var allowed = rule.get("player", true) if is_player else rule.get("opponent", true)
	if not force and not allowed:
		vo_skipped.emit(char_name, event, "role_not_allowed")
		return false

	# Check random activation chance
	var chance = float(rule.get("chance", 1.0))
	if not force and randf() > chance:
		vo_skipped.emit(char_name, event, "chance_rolled_false")
		return false

	var candidates = get_candidate_clips(char_name, event)
	if candidates.is_empty():
		vo_skipped.emit(char_name, event, "no_clips_found")
		return false

	# Pick clip, avoiding duplicate back-to-back if more than 1 option exists
	var norm_hero = normalize_hero_name(char_name)
	var last = _last_played_clip.get(norm_hero + "_" + evt_str, "")
	var chosen = candidates[0]
	if candidates.size() > 1:
		var pool = candidates.filter(func(p): return p != last)
		chosen = pool[randi() % pool.size()] if not pool.is_empty() else candidates[randi() % candidates.size()]

	_last_played_clip[norm_hero + "_" + evt_str] = chosen

	# Load AudioStream
	var stream = ResourceLoader.load(chosen) as AudioStream
	if stream == null:
		vo_skipped.emit(char_name, event, "failed_to_load_stream")
		return false

	# Route playback
	var audio_autoload = get_node_or_null("/root/Audio")
	if audio_autoload and audio_autoload.has_method("play_voice"):
		audio_autoload.play_voice(stream)
	else:
		if _internal_player == null:
			_internal_player = AudioStreamPlayer.new()
			_internal_player.name = "VOManager_Player"
			var bus_name = "Voice" if AudioServer.get_bus_index("Voice") != -1 else "Master"
			_internal_player.bus = bus_name
			add_child(_internal_player)
		_internal_player.stop()
		_internal_player.stream = stream
		_internal_player.play()

	vo_played.emit(char_name, event, chosen)
	return true


func stop_voice() -> void:
	var audio_autoload = get_node_or_null("/root/Audio")
	if audio_autoload and audio_autoload.has_method("stop_voice"):
		audio_autoload.stop_voice()
	elif _internal_player and _internal_player.playing:
		_internal_player.stop()


func is_voice_playing() -> bool:
	var audio_autoload = get_node_or_null("/root/Audio")
	if audio_autoload and audio_autoload.has_method("is_voice_playing"):
		return audio_autoload.is_voice_playing()
	return _internal_player != null and _internal_player.playing
