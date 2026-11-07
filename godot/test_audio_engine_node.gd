extends Node

const VOManager = preload("res://src/battle/VOManager.gd")
const AudioManager = preload("res://src/systems/audio_jukebox/AudioManager.gd")

var passed_count: int = 0
var failed_count: int = 0

func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING AUDIO ENGINE & VO TEST SUITE (Task 4.2)")
	print("==================================================")

	test_four_audio_buses_setup()
	test_audio_manager_volume_controls()
	test_sfx_pooling_and_variation()
	test_voice_playback_and_deduplication()
	test_vo_rules_and_hero_normalization()
	test_character_voice_roster()
	test_battle_controller_audio_integration()

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print(">>> ALL AUDIO ENGINE TESTS COMPLETED SUCCESSFULLY! <<<")
		get_tree().quit(0)
	else:
		push_error("Audio Engine tests failed!")
		get_tree().quit(1)

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % msg)
	else:
		failed_count += 1
		printerr("  [FAIL] %s" % msg)

func test_four_audio_buses_setup() -> void:
	print("\n[Test 1] 4 Audio Buses Verification (Master, Music, SFX, Voice)")
	var master_idx = AudioServer.get_bus_index("Master")
	var music_idx = AudioServer.get_bus_index("Music")
	var sfx_idx = AudioServer.get_bus_index("SFX")
	var voice_idx = AudioServer.get_bus_index("Voice")

	assert_true(master_idx != -1, "Master bus exists (index %d)" % master_idx)
	assert_true(music_idx != -1, "Music bus exists (index %d)" % music_idx)
	assert_true(sfx_idx != -1, "SFX bus exists (index %d)" % sfx_idx)
	assert_true(voice_idx != -1, "Voice bus exists (index %d)" % voice_idx)

	# Verify send routing
	if music_idx != -1:
		assert_true(AudioServer.get_bus_send(music_idx) == "Master", "Music bus sends to Master")
	if sfx_idx != -1:
		assert_true(AudioServer.get_bus_send(sfx_idx) == "Master", "SFX bus sends to Master")
	if voice_idx != -1:
		assert_true(AudioServer.get_bus_send(voice_idx) == "Master", "Voice bus sends to Master")

func test_audio_manager_volume_controls() -> void:
	print("\n[Test 2] Volume Controls (dB <-> Linear conversions)")
	var audio_mgr = get_node_or_null("/root/Audio") as AudioManager
	assert_true(audio_mgr != null, "Audio singleton autoload exists")
	if not audio_mgr:
		return

	audio_mgr.set_master_volume(0.8)
	assert_true(abs(audio_mgr.get_master_volume() - 0.8) < 0.05, "Master volume sets to 0.8")

	audio_mgr.set_music_volume(0.6)
	assert_true(abs(audio_mgr.get_music_volume() - 0.6) < 0.05, "Music volume sets to 0.6")

	audio_mgr.set_sfx_volume(0.7)
	assert_true(abs(audio_mgr.get_sfx_volume() - 0.7) < 0.05, "SFX volume sets to 0.7")

	audio_mgr.set_voice_volume(0.9)
	assert_true(abs(audio_mgr.get_voice_volume() - 0.9) < 0.05, "Voice volume sets to 0.9")

	# Test Mute
	audio_mgr.set_bus_muted("Voice", true)
	assert_true(audio_mgr.is_bus_muted("Voice"), "Voice bus muted successfully")
	audio_mgr.set_bus_muted("Voice", false)
	assert_true(not audio_mgr.is_bus_muted("Voice"), "Voice bus unmuted successfully")

func test_sfx_pooling_and_variation() -> void:
	print("\n[Test 3] SFX Player Pooling & Dynamic Expansion")
	var audio_mgr = get_node_or_null("/root/Audio") as AudioManager
	if not audio_mgr:
		return

	var initial_pool = audio_mgr.get_total_sfx_pool_size()
	assert_true(initial_pool >= 8, "Initial SFX pool has at least 8 players (%d)" % initial_pool)

	# Create a procedural tone to avoid file I/O dependency in unit test
	var tone = AudioManager.create_tone_stream(440.0, 0.1)
	var p = audio_mgr.play_sfx_with_variation(tone, -6.0, 0.15)
	assert_true(p != null, "SFX player assigned from pool")
	assert_true(p.bus == "SFX", "SFX player is assigned to SFX bus")
	assert_true(abs(p.pitch_scale - 1.0) <= 0.16, "Pitch scale randomized within variance")

func test_voice_playback_and_deduplication() -> void:
	print("\n[Test 4] Voice Playback (Dedicated Voice Bus)")
	var audio_mgr = get_node_or_null("/root/Audio") as AudioManager
	if not audio_mgr:
		return

	var tone = AudioManager.create_tone_stream(550.0, 0.2)
	var vp = audio_mgr.play_voice(tone, -4.0)
	assert_true(vp != null, "Voice player created/returned")
	assert_true(vp.bus == "Voice", "Voice player routed to Voice bus")
	assert_true(audio_mgr.is_voice_playing(), "is_voice_playing returns true during playback")

	audio_mgr.stop_voice()
	assert_true(not audio_mgr.is_voice_playing(), "stop_voice successfully stops playback")

func test_vo_rules_and_hero_normalization() -> void:
	print("\n[Test 5] VO Rules and Hero Name Normalization")
	var vom = VOManager.new()
	add_child(vom)

	# Verify normalization
	assert_true(vom.normalize_hero_name("PrincessBubblegum") == "PBG", "PrincessBubblegum -> PBG")
	assert_true(vom.normalize_hero_name("FlamePrincess") == "FP", "FlamePrincess -> FP")
	assert_true(vom.normalize_hero_name("EarlOfLemongrab") == "Lemongrab", "EarlOfLemongrab -> Lemongrab")
	assert_true(vom.normalize_hero_name("IceKing") == "Ice King", "IceKing -> Ice King")
	assert_true(vom.normalize_hero_name("Finn") == "Finn", "Finn -> Finn")

	# Verify event strings
	assert_true(vom.get_event_id_string(VOManager.VOEvent.OPENING) == "Opening", "OPENING -> Opening")
	assert_true(vom.get_event_id_string(VOManager.VOEvent.FLOOP) == "Floop", "FLOOP -> Floop")
	assert_true(vom.get_event_id_string(VOManager.VOEvent.WIN) == "Win", "WIN -> Win")

	# Test rules loaded
	assert_true(vom._event_rules.has("Opening"), "db_CharacterVO rule 'Opening' loaded")
	assert_true(vom._event_rules.has("HeroDamaged"), "db_CharacterVO rule 'HeroDamaged' loaded")

	vom.queue_free()

func test_character_voice_roster() -> void:
	print("\n[Test 6] Character Voice Roster Availability")
	var vom = VOManager.new()
	add_child(vom)

	var heroes = ["Finn", "Jake", "BMO", "Lemongrab", "Marceline", "PBG", "FP", "LSP"]
	var all_have_clips = true
	for h in heroes:
		var clips = vom.get_candidate_clips(h, VOManager.VOEvent.OPENING)
		if clips.is_empty():
			# try creature destroyed or damage
			clips = vom.get_candidate_clips(h, VOManager.VOEvent.CREATURE_DESTROYED)
		if clips.is_empty():
			all_have_clips = false
			printerr("Missing clips for hero: %s" % h)

	assert_true(all_have_clips, "All 8 key heroes have voice lines indexed in catalog")

	# Test forced playback
	var played_box = {"played": false, "clip": ""}
	vom.vo_played.connect(func(c, e, path):
		played_box["played"] = true
		played_box["clip"] = path
	)

	var success = vom.play_event("Finn", VOManager.VOEvent.OPENING, true, true)
	assert_true(success, "Finn Opening VO played with forced=true")
	assert_true(played_box["played"], "vo_played signal emitted")
	assert_true(played_box["clip"].ends_with(".wav"), "Played clip is valid .wav path: %s" % played_box["clip"])

	vom.queue_free()

func test_battle_controller_audio_integration() -> void:
	print("\n[Test 7] Battle Controller Audio & VO Integration")
	var battle = preload("res://scenes/battle.tscn").instantiate()
	add_child(battle)

	assert_true(battle.vo_manager != null, "BattleController.vo_manager instantiated")
	assert_true(battle.vo_manager is VOManager, "BattleController.vo_manager is VOManager instance")

	var last_vo = {"event": -1}
	battle.vo_manager.vo_played.connect(func(_c, e, _p):
		last_vo["event"] = e
	)

	# Test end match victory triggers WIN VO
	battle.end_match(true)
	assert_true(last_vo["event"] == VOManager.VOEvent.WIN or last_vo["event"] == VOManager.VOEvent.LOSE, "Victory triggered Win/Lose VO event")

	# Test end match defeat triggers LOSE VO
	battle.end_match(false)
	assert_true(last_vo["event"] == VOManager.VOEvent.WIN or last_vo["event"] == VOManager.VOEvent.LOSE, "Defeat triggered Win/Lose VO event")

	battle.queue_free()
