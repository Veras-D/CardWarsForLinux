class_name CharacterFaceRig
extends Control

## Character Facial Animation Rig for Adventure Time Leaders.
## Animates mouth and eyes UV coordinates from original CharacterFaceAnim JSONs.

enum EmoteState {
	IDLE,
	PLAY_CARD,
	TAKE_DAMAGE,
	VICTORY,
	DEFEAT
}

signal animation_started(anim_name: String)
signal animation_finished(anim_name: String)
signal emote_changed(new_emote: EmoteState)

@export var character_id: String = "Finn"
@export var auto_start_idle: bool = true
@export var enable_breathing: bool = true

var current_emote: EmoteState = EmoteState.IDLE
var current_anim_name: String = ""
var is_playing: bool = false
var anim_elapsed: float = 0.0
var anim_duration: float = 0.0
var loop_idle_when_done: bool = true

# Keyframe queues
var mouth_keyframes: Array[Dictionary] = []
var eyes_keyframes: Array[Dictionary] = []
var current_mouth_idx: int = 0
var current_eyes_idx: int = 0

# Shader material references
var mouth_material: ShaderMaterial = null
var eyes_material: ShaderMaterial = null

# Cached animations: key = anim_name, value = Array[Dictionary]
var _anim_cache: Dictionary = {}
var _breathing_tween: Tween = null

@onready var base_portrait: TextureRect = $BasePortrait
@onready var mouth_rect: TextureRect = $MouthRect
@onready var eyes_rect: TextureRect = $EyesRect


func _ready() -> void:
	_init_shader_materials()
	setup(character_id)
	if enable_breathing:
		_start_breathing_wobble()
	if auto_start_idle:
		play_emote(EmoteState.IDLE)


func _get_mouth_rect() -> TextureRect:
	if mouth_rect:
		return mouth_rect
	mouth_rect = get_node_or_null("MouthRect")
	return mouth_rect


func _get_eyes_rect() -> TextureRect:
	if eyes_rect:
		return eyes_rect
	eyes_rect = get_node_or_null("EyesRect")
	return eyes_rect


func _get_base_portrait() -> TextureRect:
	if base_portrait:
		return base_portrait
	base_portrait = get_node_or_null("BasePortrait")
	return base_portrait


func _init_shader_materials() -> void:
	var shader = preload("res://src/shaders/face_uv_anim.gdshader")
	var m_rect = _get_mouth_rect()
	if m_rect and mouth_material == null:
		mouth_material = ShaderMaterial.new()
		mouth_material.shader = shader
		m_rect.material = mouth_material

	var e_rect = _get_eyes_rect()
	if e_rect and eyes_material == null:
		eyes_material = ShaderMaterial.new()
		eyes_material.shader = shader
		e_rect.material = eyes_material


func setup(char_id: String) -> void:
	character_id = char_id
	_anim_cache.clear()
	_init_shader_materials()

	# 1. Load Face Texture Atlas
	var face_candidates: Array[String] = [
		"res://assets/textures/characters/face/%s_Face.png" % char_id,
		"res://assets/textures/characters/face/low_%s_Face.png" % char_id,
		"res://assets/textures/characters/face/%s_FaceAtlas.png" % char_id,
		"res://assets/textures/characters/face/Finn_Face.png"
	]

	var face_tex: Texture2D = null
	for path in face_candidates:
		if ResourceLoader.exists(path):
			face_tex = load(path)
			break

	var m_rect = _get_mouth_rect()
	if m_rect and face_tex:
		m_rect.texture = face_tex
		m_rect.visible = true

	var e_rect = _get_eyes_rect()
	if e_rect and face_tex:
		e_rect.texture = face_tex
		e_rect.visible = true

	# 2. Base Portrait (Leader round avatar / body texture)
	var round_portrait_path = "res://assets/textures/leaders/%s_Round.png" % char_id
	var leader_portrait_path = "res://assets/textures/leaders/%s.png" % char_id
	var b_portrait = _get_base_portrait()
	if b_portrait:
		if ResourceLoader.exists(round_portrait_path):
			b_portrait.texture = load(round_portrait_path)
		elif ResourceLoader.exists(leader_portrait_path):
			b_portrait.texture = load(leader_portrait_path)
		elif ResourceLoader.exists("res://assets/textures/leaders/Finn_Round.png"):
			b_portrait.texture = load("res://assets/textures/leaders/Finn_Round.png")


func play_emote(state: EmoteState, return_to_idle: bool = true) -> void:
	current_emote = state
	emote_changed.emit(state)

	var anim_name = "Idle"
	match state:
		EmoteState.IDLE:
			anim_name = "Idle"
			return_to_idle = false
		EmoteState.PLAY_CARD:
			anim_name = "PlayCard"
		EmoteState.TAKE_DAMAGE:
			anim_name = "Sad"
		EmoteState.VICTORY:
			anim_name = "Happy"
		EmoteState.DEFEAT:
			anim_name = "Defeated"

	play_animation(anim_name, return_to_idle)


func play_animation(anim_name: String, return_to_idle: bool = true) -> bool:
	var keyframes = get_animation_keyframes(anim_name)
	if keyframes.is_empty():
		if anim_name != "Idle":
			keyframes = get_animation_keyframes("Idle")
		if keyframes.is_empty():
			return false

	current_anim_name = anim_name
	loop_idle_when_done = return_to_idle
	is_playing = true
	anim_elapsed = 0.0
	current_mouth_idx = 0
	current_eyes_idx = 0

	mouth_keyframes.clear()
	eyes_keyframes.clear()

	var max_time: float = 0.0
	for kf in keyframes:
		var cnt = str(kf.get("CNT", "CNT_MOUTH"))
		var t = float(kf.get("time", 0.0))
		if t > max_time:
			max_time = t
		if cnt == "CNT_EYES":
			eyes_keyframes.append(kf)
		else:
			mouth_keyframes.append(kf)

	anim_duration = max(0.4, max_time)

	# Apply initial frame if keyframes are defined
	if not mouth_keyframes.is_empty():
		var first_m = mouth_keyframes[0]
		set_mouth_uv(Vector2(float(first_m.get("x", 0.0)), float(first_m.get("y", 0.75))))
	if not eyes_keyframes.is_empty():
		var first_e = eyes_keyframes[0]
		set_eyes_uv(Vector2(float(first_e.get("x", 0.0)), float(first_e.get("y", 0.75))))

	animation_started.emit(anim_name)
	_step_keyframes(0.0)
	return true


func _process(delta: float) -> void:
	if not is_playing:
		return

	anim_elapsed += delta
	_step_keyframes(anim_elapsed)

	if anim_elapsed >= anim_duration:
		is_playing = false
		animation_finished.emit(current_anim_name)
		if loop_idle_when_done:
			play_emote(EmoteState.IDLE)


func _step_keyframes(target_time: float) -> void:
	# Advance mouth keyframes
	while current_mouth_idx < mouth_keyframes.size():
		var kf = mouth_keyframes[current_mouth_idx]
		var kf_time = float(kf.get("time", 0.0))
		if target_time >= kf_time:
			var x = float(kf.get("x", 0.0))
			var y = float(kf.get("y", 0.75))
			set_mouth_uv(Vector2(x, y))
			current_mouth_idx += 1
		else:
			break

	# Advance eyes keyframes
	while current_eyes_idx < eyes_keyframes.size():
		var kf = eyes_keyframes[current_eyes_idx]
		var kf_time = float(kf.get("time", 0.0))
		if target_time >= kf_time:
			var x = float(kf.get("x", 0.0))
			var y = float(kf.get("y", 0.75))
			set_eyes_uv(Vector2(x, y))
			current_eyes_idx += 1
		else:
			break


func set_mouth_uv(offset: Vector2) -> void:
	if mouth_material:
		mouth_material.set_shader_parameter("uv_offset", offset)


func set_eyes_uv(offset: Vector2) -> void:
	if eyes_material:
		eyes_material.set_shader_parameter("uv_offset", offset)


func get_animation_keyframes(anim_name: String) -> Array[Dictionary]:
	if _anim_cache.has(anim_name):
		return _anim_cache[anim_name]

	var file_candidates: Array[String] = []
	file_candidates.append("res://data/character_face_anim/%s_%s.json" % [character_id, anim_name])

	# State-specific aliases and fallbacks
	if anim_name == "Idle":
		file_candidates.append("res://data/character_face_anim/%s_CardIdle.json" % character_id)
	elif anim_name == "CardIdle":
		file_candidates.append("res://data/character_face_anim/%s_Idle.json" % character_id)
	elif anim_name == "Sad":
		file_candidates.append("res://data/character_face_anim/%s_Defeated.json" % character_id)
		file_candidates.append("res://data/character_face_anim/%s_CardIdle.json" % character_id)
	elif anim_name == "Happy":
		file_candidates.append("res://data/character_face_anim/%s_PlayRare.json" % character_id)
		file_candidates.append("res://data/character_face_anim/%s_CardIdle.json" % character_id)
	elif anim_name == "Defeated":
		file_candidates.append("res://data/character_face_anim/%s_DweebDrink.json" % character_id)
		file_candidates.append("res://data/character_face_anim/%s_Sad.json" % character_id)

	# Global Finn fallback candidates
	file_candidates.append("res://data/character_face_anim/Finn_%s.json" % anim_name)
	if anim_name == "Idle":
		file_candidates.append("res://data/character_face_anim/Finn_CardIdle.json")

	var chosen_path = ""
	for path in file_candidates:
		if FileAccess.file_exists(path):
			chosen_path = path
			break

	var keyframes: Array[Dictionary] = []
	if chosen_path != "":
		var file = FileAccess.open(chosen_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_ARRAY:
				for item in json.data:
					if typeof(item) == TYPE_DICTIONARY:
						keyframes.append(item)

	_anim_cache[anim_name] = keyframes
	return keyframes


func _start_breathing_wobble() -> void:
	if _breathing_tween and _breathing_tween.is_valid():
		_breathing_tween.kill()
	pivot_offset = size / 2.0
	_breathing_tween = create_tween().set_loops()
	_breathing_tween.tween_property(self, "scale:y", 1.04, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathing_tween.tween_property(self, "scale:y", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
