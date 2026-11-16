class_name DailyGiftIcon
extends Node3D

const TEX_GIFT: Texture2D = preload("res://assets/textures/dungeons/low_DailyGif.png")

@onready var model: Node3D = $GiftRoot/DailyGift_Normal

var _anim_player: AnimationPlayer = null


func _ready() -> void:
	_setup_model()
	reset_anim()


func _setup_model() -> void:
	if not model:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = TEX_GIFT
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_BACK

	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var surf_cnt := mi.get_surface_override_material_count()
			for idx in range(surf_cnt):
				mi.set_surface_override_material(idx, mat)
		elif n is AnimationPlayer:
			_anim_player = n as AnimationPlayer

	if _anim_player:
		var anim_names := _anim_player.get_animation_list()
		if not anim_names.is_empty():
			var first_anim := anim_names[0]
			var anim_res := _anim_player.get_animation(first_anim)
			if anim_res:
				anim_res.loop_mode = Animation.LOOP_LINEAR
			_anim_player.play(first_anim)


func reset_anim() -> void:
	if _anim_player:
		var anim_names := _anim_player.get_animation_list()
		if not anim_names.is_empty():
			_anim_player.play(anim_names[0])
			_anim_player.seek(0.0, true)
