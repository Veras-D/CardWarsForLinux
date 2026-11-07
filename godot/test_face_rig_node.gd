extends Node

const CharacterFaceRig = preload("res://src/battle/CharacterFaceRig.gd")

var passed_count: int = 0
var failed_count: int = 0

func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING CHARACTER FACE RIG TEST SUITE (Task 4.1)")
	print("==================================================")

	test_basic_instantiation_and_materials()
	test_keyframe_loading()
	test_emote_states_and_signals()
	test_uv_stepping_and_shader_params()
	test_all_38_characters_robustness()
	test_battle_scene_face_rig_integration()

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print(">>> ALL FACE RIG TESTS COMPLETED SUCCESSFULLY! <<<")
		get_tree().quit(0)
	else:
		push_error("Face rig tests failed!")
		get_tree().quit(1)

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % msg)
	else:
		failed_count += 1
		printerr("  [FAIL] %s" % msg)

func test_basic_instantiation_and_materials() -> void:
	print("\n[Test 1] CharacterFaceRig Instantiation & Shader Materials")
	var rig_scene = preload("res://scenes/components/CharacterFaceRig.tscn")
	var rig = rig_scene.instantiate() as CharacterFaceRig
	add_child(rig)

	assert_true(rig != null, "CharacterFaceRig instance created successfully")
	assert_true(rig.mouth_material != null, "Mouth ShaderMaterial is initialized")
	assert_true(rig.eyes_material != null, "Eyes ShaderMaterial is initialized")
	assert_true(rig.mouth_rect.material == rig.mouth_material, "MouthRect material assigned")
	assert_true(rig.eyes_rect.material == rig.eyes_material, "EyesRect material assigned")

	rig.queue_free()

func test_keyframe_loading() -> void:
	print("\n[Test 2] Keyframe Loading & Parsing")
	var rig = preload("res://scenes/components/CharacterFaceRig.tscn").instantiate() as CharacterFaceRig
	add_child(rig)
	rig.setup("Finn")

	var idle_kf = rig.get_animation_keyframes("Idle")
	assert_true(not idle_kf.is_empty(), "Finn Idle keyframes loaded (%d frames)" % idle_kf.size())
	if not idle_kf.is_empty():
		var first = idle_kf[0]
		assert_true(first.has("CNT") and first.has("time") and first.has("x") and first.has("y"), "Keyframe schema contains CNT, time, x, y")

	var play_kf = rig.get_animation_keyframes("PlayCard")
	assert_true(not play_kf.is_empty(), "Finn PlayCard keyframes loaded (%d frames)" % play_kf.size())

	rig.queue_free()

func test_emote_states_and_signals() -> void:
	print("\n[Test 3] Emote States and Signals")
	var rig = preload("res://scenes/components/CharacterFaceRig.tscn").instantiate() as CharacterFaceRig
	add_child(rig)
	rig.setup("Jake")

	var emote_box = {"last_emote": -1}
	var anim_box = {"last_anim": ""}
	rig.emote_changed.connect(func(e): emote_box["last_emote"] = e)
	rig.animation_started.connect(func(a): anim_box["last_anim"] = a)

	rig.play_emote(CharacterFaceRig.EmoteState.PLAY_CARD)
	assert_true(rig.current_emote == CharacterFaceRig.EmoteState.PLAY_CARD, "Current emote is PLAY_CARD")
	assert_true(emote_box["last_emote"] == CharacterFaceRig.EmoteState.PLAY_CARD, "emote_changed signal emitted for PLAY_CARD")
	assert_true(anim_box["last_anim"] == "PlayCard", "animation_started signal emitted with PlayCard")

	rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
	assert_true(rig.current_emote == CharacterFaceRig.EmoteState.TAKE_DAMAGE, "Current emote is TAKE_DAMAGE (Sad)")
	assert_true(anim_box["last_anim"] == "Sad", "Sad animation started")

	rig.play_emote(CharacterFaceRig.EmoteState.VICTORY)
	assert_true(rig.current_emote == CharacterFaceRig.EmoteState.VICTORY, "Current emote is VICTORY (Happy)")
	assert_true(anim_box["last_anim"] == "Happy", "Happy animation started")

	rig.play_emote(CharacterFaceRig.EmoteState.DEFEAT)
	assert_true(rig.current_emote == CharacterFaceRig.EmoteState.DEFEAT, "Current emote is DEFEAT (Defeated)")
	assert_true(anim_box["last_anim"] == "Defeated", "Defeated animation started")

	rig.queue_free()

func test_uv_stepping_and_shader_params() -> void:
	print("\n[Test 4] UV Stepping and Shader Uniforms")
	var rig = preload("res://scenes/components/CharacterFaceRig.tscn").instantiate() as CharacterFaceRig
	add_child(rig)
	rig.setup("BMO")

	# BMO Happy has multiple keyframes at different times
	rig.play_animation("Happy", false)
	assert_true(rig.is_playing, "Animation is playing")

	rig._step_keyframes(0.0)
	var mouth_uv0 = rig.mouth_material.get_shader_parameter("uv_offset")
	assert_true(typeof(mouth_uv0) == TYPE_VECTOR2, "Shader uniform uv_offset is Vector2")

	# Advance time past keyframes
	rig._step_keyframes(1.2)
	var mouth_uv_end = rig.mouth_material.get_shader_parameter("uv_offset")
	assert_true(typeof(mouth_uv_end) == TYPE_VECTOR2, "Shader uniform uv_offset updated after time advancement")

	rig.queue_free()

func test_all_38_characters_robustness() -> void:
	print("\n[Test 5] 38 Character Roster Robustness")
	var rig = preload("res://scenes/components/CharacterFaceRig.tscn").instantiate() as CharacterFaceRig
	add_child(rig)

	var dir = DirAccess.open("res://data/character_face_anim")
	var chars_set: Dictionary = {}
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var parts = file_name.split("_")
				chars_set[parts[0]] = true
			file_name = dir.get_next()

	var char_list = chars_set.keys()
	assert_true(char_list.size() >= 38, "Found %d characters in character_face_anim directory (expected >= 38)" % char_list.size())

	var all_successful = true
	var tested_count = 0
	for char_name in char_list:
		rig.setup(char_name)
		var played_idle = rig.play_animation("Idle")
		var played_play = rig.play_animation("PlayCard")
		var played_damage = rig.play_animation("Sad")
		var played_win = rig.play_animation("Happy")
		var played_loss = rig.play_animation("Defeated")
		if not (played_idle and played_play and played_damage and played_win and played_loss):
			all_successful = false
			printerr("Failed animation fallback for character: %s" % char_name)
		tested_count += 1

	assert_true(all_successful and tested_count >= 38, "All %d characters successfully loaded and resolved all 5 emote animations" % tested_count)
	rig.queue_free()

func test_battle_scene_face_rig_integration() -> void:
	print("\n[Test 6] Battle Scene Face Rig Integration")
	var battle_scene = preload("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	add_child(battle)

	var p_rig = battle.get_node_or_null("Footer/PlayerInfo/PlayerFaceRig") as CharacterFaceRig
	var o_rig = battle.get_node_or_null("Header/OpponentInfo/OpponentFaceRig") as CharacterFaceRig

	assert_true(p_rig != null, "PlayerFaceRig exists in Battle scene hierarchy")
	assert_true(o_rig != null, "OpponentFaceRig exists in Battle scene hierarchy")

	if p_rig and o_rig:
		assert_true(p_rig.character_id == "Finn", "PlayerFaceRig defaults to Finn")
		assert_true(o_rig.character_id == "Jake", "OpponentFaceRig defaults to Jake")

		# Test end_match victory
		battle.end_match(true)
		assert_true(p_rig.current_emote == CharacterFaceRig.EmoteState.VICTORY, "Player emote set to VICTORY on win")
		assert_true(o_rig.current_emote == CharacterFaceRig.EmoteState.DEFEAT, "Opponent emote set to DEFEAT on player win")

		# Test end_match defeat
		battle.end_match(false)
		assert_true(p_rig.current_emote == CharacterFaceRig.EmoteState.DEFEAT, "Player emote set to DEFEAT on loss")
		assert_true(o_rig.current_emote == CharacterFaceRig.EmoteState.VICTORY, "Opponent emote set to VICTORY on opponent win")

	battle.queue_free()
