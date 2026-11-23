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

const EXPLICIT_OPENING_CLIPS: Dictionary = {
	"Jake": ["Jake_Opening_1.wav", "Jake_Opening_2.wav", "Jake_Opening_4.wav", "Jake_Opening_5.wav"],
	"Finn": ["Finn_Opening_3.wav"],
	"LordMonochromicorn": ["Finn_Opening_3.wav"],
	"PrinceGumball": ["Finn_Opening_3.wav"],
	"BMO": ["BMO_Opening_1.wav", "BMO_Opening_2.wav", "beemo_mode_bmocartridge_01.wav"],
	"FP": ["FP_Opening_3.wav", "FP_Opening_4.wav"],
	"Lemongrab": ["Lemongrab_Opening_3.wav", "lg_hub_01a_ALT03.wav"],
	"LSP": ["LSP_Opening_3.wav", "lsp_upgrade.wav"],
	"Marceline": ["Marceline_Opening_3.wav"],
	"Ice King": ["Ice King_GAME STARTS_2.wav"],
	"Lady Rainicorn": ["Lady Rainicorn_GAME STARTS_1.wav", "Lady Rainicorn_GAME STARTS_2.wav", "Lady Rainicorn_GAME STARTS_3.wav"],
	"Magic Man": ["Magic Man_GAME STARTS_3.wav", "Magic Man_FIGHT START_9.wav"],
	"Cinnamon Bun": ["Cinnamon Bun_GAME STARTS_1.wav", "Cinnamon Bun_GAME STARTS_3.wav"],
	"PeppermintButler": ["Peppermint Butler_GAME STARTS_2.wav"],
	"BananaGuard": ["Banana Guard_Character Select_13.wav", "Banana Guard_FIGHT START_7_ALT01.wav", "Banana Guard_GAME STARTS_2.wav"],
	"PrincessCookie": ["Banana Guard_Character Select_13.wav", "Banana Guard_FIGHT START_7_ALT01.wav", "Banana Guard_GAME STARTS_2.wav"],
}

# Activation rules from db_CharacterVO.json:
# key = event_string, value = { "chance": float, "player": bool, "opponent": bool }
var _event_rules: Dictionary = {}

# Exact Unity VOController clip lists per character prefab (from Assets/Resources/characters/*.prefab):
# key = prefab_name, value = { EventID: Array[String] }
var _prefab_vo_table: Dictionary = {}

# Catalog of available clips (fallback for custom tests):
# key = "Character_EventID", value = Array[String] (file paths)
var _clip_catalog: Dictionary = {}

# Last played clip per key to avoid repeating the identical sound back-to-back
var _last_played_clip: Dictionary = {}

# Dedicated internal player if Audio autoload is not active
var _internal_player: AudioStreamPlayer = null

# Pending 1-slot follow-up per channel ("player" / "opponent") so rapid actions (e.g. Summon -> Floop)
# play naturally back-to-back without cancelling the active clip or silently dropping the line.
var _pending_vo: Dictionary = {}
const MAX_QUEUE_AGE_MSEC: int = 2200


func _init() -> void:
	_load_event_rules()
	_load_prefab_vo_table()
	_build_clip_catalog()


func _load_prefab_vo_table() -> void:
	_prefab_vo_table.clear()
	var path := "res://data/character_prefab_vo.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		_prefab_vo_table = json.data


func resolve_character_prefab(char_name: String) -> String:
	var clean := char_name.strip_edges()
	var db := get_node_or_null("/root/Database")
	if clean.begins_with("Leader_") and db and db.has_method("get_leader"):
		var linfo: Dictionary = db.get_leader(clean)
		var lchar := str(linfo.get("character_id", "")).strip_edges()
		if lchar != "":
			clean = lchar
		else:
			clean = clean.substr(7)
	if _prefab_vo_table.has(clean):
		return clean
	if db and db.has_method("get_character"):
		var cinfo: Dictionary = db.get_character(clean)
		var pf := str(cinfo.get("prefab", "")).strip_edges()
		if pf != "" and _prefab_vo_table.has(pf):
			return pf
	match clean:
		"JakeGhost":
			return "GhostJake"
		"GunterFC", "Gunter02":
			return "Gunter"
		"Fionna":
			return "Fiona"
		"Princess Bubblegum", "PB", "Bubblegum", "PBG":
			return "PrincessBubblegum"
		"Flame Princess", "FP":
			return "FlamePrincess"
		"Earl of Lemongrab", "Lemongrab":
			return "EarlOfLemongrab"
		"LSP":
			return "LumpySpacePrincess"
		"Ice King":
			return "IceKing"
		"Lady Rainicorn":
			return "LadyRainicorn"
		"Magic Man":
			return "MagicMan"
		"Cinnamon Bun", "CinnamonBun":
			return "CinamonBunn"
		"Banana Guard":
			return "BananaGuard"
		"Peppermint Butler":
			return "PeppermintButler"
	return clean


func _ready() -> void:
	if _internal_player == null:
		_internal_player = AudioStreamPlayer.new()
		_internal_player.name = "VOManager_Player"
		var bus_name = "Voice" if AudioServer.get_bus_index("Voice") != -1 else "Master"
		_internal_player.bus = bus_name
		add_child(_internal_player)
	if not _internal_player.finished.is_connected(_on_channel_voice_finished.bind("default")):
		_internal_player.finished.connect(_on_channel_voice_finished.bind("default"))


func normalize_hero_name(char_name: String) -> String:
	var clean = char_name.strip_edges()
	if clean.begins_with("Leader_"):
		var db := get_node_or_null("/root/Database")
		if db and db.has_method("get_leader"):
			var linfo: Dictionary = db.get_leader(clean)
			var lchar := str(linfo.get("character_id", "")).strip_edges()
			clean = lchar if lchar != "" else clean.substr(7)
		else:
			clean = clean.substr(7)
	match clean:
		"FinnDoctor", "FinnPajama", "FinnSweater":
			return "Finn"
		"GhostJake", "JakeGhost", "JakeSweater":
			return "Jake"
		"BMOSweater":
			return "BMO"
		"PrincessBubblegum", "Princess Bubblegum", "PrincessBubblegumSweater", "PB", "Bubblegum":
			return "PBG"
		"FlamePrincess", "Flame Princess":
			return "FP"
		"EarlOfLemongrab", "Earl of Lemongrab":
			return "Lemongrab"
		"LumpySpacePrincess", "LumpySpacePrincessSweater", "LSP":
			return "LSP"
		"IceKing", "IceKingSweater", "IceKingValentine":
			return "Ice King"
		"LadyRainicorn":
			return "Lady Rainicorn"
		"MagicMan":
			return "Magic Man"
		"CinamonBunn", "CinnamonBun":
			return "Cinnamon Bun"
		"Banana Guard":
			return "BananaGuard"
		"Peppermint Butler":
			return "PeppermintButler"
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
		"DestroyCreature": { "chance": 0.85, "player": true, "opponent": true },
		"PlayCreature": { "chance": 0.85, "player": true, "opponent": true },
		"PlayBuilding": { "chance": 0.85, "player": true, "opponent": true },
		"PlaySpell": { "chance": 0.85, "player": true, "opponent": true },
		"CreatureDestroyed": { "chance": 0.85, "player": true, "opponent": true },
		"BuildingDestroyed": { "chance": 0.85, "player": true, "opponent": true },
		"Floop": { "chance": 1.0, "player": true, "opponent": true },
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
	var clean_hero := hero_name.strip_edges()
	var norm_hero := normalize_hero_name(clean_hero)
	var evt_str := get_event_id_string(event)

	# 1. Exact Unity VOController clip list from Assets/Resources/characters/<Prefab>.prefab
	var pf_name := resolve_character_prefab(clean_hero)
	if _prefab_vo_table.has(pf_name):
		var pf_entry: Dictionary = _prefab_vo_table[pf_name]
		if pf_entry.has(evt_str):
			var raw_list: Array = pf_entry[evt_str]
			var pf_res: Array[String] = []
			for fn in raw_list:
				var fp := "res://assets/audio/vo/" + str(fn)
				if ResourceLoader.exists(fp) or FileAccess.file_exists(fp):
					pf_res.append(fp)
			if not pf_res.is_empty():
				return pf_res
			# In Unity Finn.prefab / LumpySpacePrincess.prefab / PeppermintButler.prefab have empty WinClips;
			# fall back to DestroyCreatureClips only for VOEvent.WIN so end_match(true) still plays a victory line.
			if event == VOEvent.WIN and pf_entry.has("DestroyCreature"):
				for fn in pf_entry["DestroyCreature"]:
					var fp := "res://assets/audio/vo/" + str(fn)
					if ResourceLoader.exists(fp) or FileAccess.file_exists(fp):
						pf_res.append(fp)
			return pf_res

	if event == VOEvent.OPENING:
		var clip_files: Array = []
		if EXPLICIT_OPENING_CLIPS.has(clean_hero):
			clip_files = EXPLICIT_OPENING_CLIPS[clean_hero]
		elif EXPLICIT_OPENING_CLIPS.has(norm_hero):
			clip_files = EXPLICIT_OPENING_CLIPS[norm_hero]
		if not clip_files.is_empty():
			var explicit_res: Array[String] = []
			for fn in clip_files:
				var fp := "res://assets/audio/vo/" + str(fn)
				if ResourceLoader.exists(fp):
					explicit_res.append(fp)
			if not explicit_res.is_empty():
				return explicit_res
		return []

	var key := norm_hero + "_" + evt_str
	if _clip_catalog.has(key) and not _clip_catalog[key].is_empty():
		var res: Array[String] = []
		for p in _clip_catalog[key]:
			res.append(str(p))
		return res

	return []


func play_event(char_name: String, event: VOEvent, is_player: bool = true, force: bool = false) -> bool:
	if not vo_enabled:
		vo_skipped.emit(char_name, event, "vo_disabled")
		return false

	var channel := "player" if is_player else "opponent"
	var evt_str = get_event_id_string(event)
	var rule = _event_rules.get(evt_str, { "chance": 1.0, "player": true, "opponent": true })

	# Check player / opponent permission
	var allowed = rule.get("player", true) if is_player else rule.get("opponent", true)
	if not force and not allowed:
		vo_skipped.emit(char_name, event, "role_not_allowed")
		return false

	var candidates = get_candidate_clips(char_name, event)
	if candidates.is_empty():
		vo_skipped.emit(char_name, event, "no_clips_found")
		return false

	# Check random activation chance
	var chance = float(rule.get("chance", 1.0))
	if not force and randf() > chance:
		vo_skipped.emit(char_name, event, "chance_rolled_false")
		return false

	# Pick clip, avoiding duplicate back-to-back if more than 1 option exists
	var norm_hero = normalize_hero_name(char_name)
	var last = _last_played_clip.get(norm_hero + "_" + evt_str, "")
	var chosen = candidates[0]
	if candidates.size() > 1:
		var pool = candidates.filter(func(p): return p != last)
		chosen = pool[randi() % pool.size()] if not pool.is_empty() else candidates[randi() % candidates.size()]

	# If this character's own channel is still speaking, queue this line as a 1-slot follow-up
	# instead of cancelling the active clip or dropping the new line.
	if not force and is_voice_playing(channel):
		_pending_vo[channel] = {
			"char_name": char_name,
			"norm_key": norm_hero + "_" + evt_str,
			"event": event,
			"chosen": chosen,
			"queued_msec": Time.get_ticks_msec(),
		}
		vo_skipped.emit(char_name, event, "queued_already_playing")
		return false

	_pending_vo.erase(channel)
	return _play_chosen_clip(char_name, norm_hero + "_" + evt_str, event, chosen, channel)


func _play_chosen_clip(char_name: String, norm_key: String, event: VOEvent, chosen: String, channel: String) -> bool:
	var stream = ResourceLoader.load(chosen) as AudioStream
	if stream == null:
		vo_skipped.emit(char_name, event, "failed_to_load_stream")
		return false

	_last_played_clip[norm_key] = chosen

	# Route playback to character's dedicated voice channel ("player" or "opponent")
	var audio_autoload = get_node_or_null("/root/Audio")
	if audio_autoload and audio_autoload.has_method("play_voice"):
		var player = audio_autoload.play_voice(stream, 0.0, 1.0, channel)
		if player is AudioStreamPlayer:
			var cb := _on_channel_voice_finished.bind(channel)
			if not player.finished.is_connected(cb):
				player.finished.connect(cb)
	else:
		if _internal_player == null:
			_internal_player = AudioStreamPlayer.new()
			_internal_player.name = "VOManager_Player"
			var bus_name = "Voice" if AudioServer.get_bus_index("Voice") != -1 else "Master"
			_internal_player.bus = bus_name
			add_child(_internal_player)
		if not _internal_player.finished.is_connected(_on_channel_voice_finished.bind("default")):
			_internal_player.finished.connect(_on_channel_voice_finished.bind("default"))
		_internal_player.stop()
		_internal_player.stream = stream
		_internal_player.play()

	vo_played.emit(char_name, event, chosen)
	return true


func _on_channel_voice_finished(channel: String) -> void:
	if not is_inside_tree() or not vo_enabled:
		return
	var key := channel if _pending_vo.has(channel) else ""
	if key == "":
		return
	var entry: Dictionary = _pending_vo[key]
	_pending_vo.erase(key)
	if Time.get_ticks_msec() - int(entry.get("queued_msec", 0)) > MAX_QUEUE_AGE_MSEC:
		return
	if is_voice_playing(key):
		return
	_play_chosen_clip(
		str(entry.get("char_name", "")),
		str(entry.get("norm_key", "")),
		int(entry.get("event", VOEvent.FLOOP)) as VOEvent,
		str(entry.get("chosen", "")),
		key
	)


func stop_voice(channel: String = "") -> void:
	if channel != "":
		_pending_vo.erase(channel)
	else:
		_pending_vo.clear()
	var audio_autoload = get_node_or_null("/root/Audio")
	if audio_autoload and audio_autoload.has_method("stop_voice"):
		audio_autoload.stop_voice(channel)
	elif _internal_player and _internal_player.playing:
		_internal_player.stop()


func is_voice_playing(channel: String = "") -> bool:
	var audio_autoload = get_node_or_null("/root/Audio")
	if audio_autoload and audio_autoload.has_method("is_voice_playing"):
		return audio_autoload.is_voice_playing(channel)
	return _internal_player != null and _internal_player.playing
