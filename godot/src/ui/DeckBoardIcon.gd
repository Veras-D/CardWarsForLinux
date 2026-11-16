class_name DeckBoardIcon
extends Node3D

@export var icon_texture: Texture2D
@export var strike_times: PackedFloat32Array = PackedFloat32Array()
@export var strike_sfx: AudioStream = null
@export var strike_volume_db: float = -4.0

var _anim_player: AnimationPlayer = null
var _sfx_player: AudioStreamPlayer = null
var _idle_audio_enabled: bool = false
var _last_anim_pos: float = -1.0
var _anim_length: float = 0.0


func _ready() -> void:
	_setup_model()
	_setup_audio()
	reset_anim()


func _setup_model() -> void:
	var mat: StandardMaterial3D = null
	if icon_texture:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = icon_texture
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		mat.cull_mode = BaseMaterial3D.CULL_BACK

	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D and mat != null:
			var mi := n as MeshInstance3D
			var surf_cnt := mi.get_surface_override_material_count()
			for idx in range(surf_cnt):
				mi.set_surface_override_material(idx, mat)
		elif n is AnimationPlayer and _anim_player == null:
			_anim_player = n as AnimationPlayer

	if _anim_player:
		var anim_names := _anim_player.get_animation_list()
		if not anim_names.is_empty():
			var first_anim := anim_names[0]
			var anim_res := _anim_player.get_animation(first_anim)
			if anim_res:
				anim_res.loop_mode = Animation.LOOP_LINEAR
				_anim_length = anim_res.length
			_anim_player.play(first_anim)


func _setup_audio() -> void:
	if strike_sfx == null or strike_times.is_empty():
		return
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.stream = strike_sfx
	_sfx_player.volume_db = strike_volume_db
	_sfx_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(_sfx_player)


func set_idle_audio_enabled(enabled: bool) -> void:
	_idle_audio_enabled = enabled
	if not enabled and _sfx_player and _sfx_player.playing:
		_sfx_player.stop()


func stop_audio() -> void:
	_idle_audio_enabled = false
	if _sfx_player and _sfx_player.playing:
		_sfx_player.stop()


func reset_anim() -> void:
	_last_anim_pos = 0.0
	if _anim_player:
		var anim_names := _anim_player.get_animation_list()
		if not anim_names.is_empty():
			_anim_player.play(anim_names[0])
			_anim_player.seek(0.0, true)


func _process(_delta: float) -> void:
	if _anim_player == null or _sfx_player == null or strike_times.is_empty():
		return
	if not _idle_audio_enabled or not is_visible_in_tree():
		_last_anim_pos = _anim_player.current_animation_position if _anim_player.is_playing() else -1.0
		return

	var pos := _anim_player.current_animation_position
	if _last_anim_pos < 0.0:
		_last_anim_pos = pos
		return

	var crossed := false
	if pos >= _last_anim_pos:
		for st in strike_times:
			if st > _last_anim_pos and st <= pos:
				crossed = true
				break
	else:
		# Wrapped cleanly across animation loop boundary
		for st in strike_times:
			if st > _last_anim_pos or st <= pos:
				crossed = true
				break

	_last_anim_pos = pos
	if crossed:
		_sfx_player.play()
