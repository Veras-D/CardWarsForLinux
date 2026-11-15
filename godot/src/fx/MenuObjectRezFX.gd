class_name MenuObjectRezFX
extends Node3D

const TEX_SCAN: Texture2D = preload("res://assets/textures/fx/FX_Scan.png")
const TEX_HEX_OUTLINE: Texture2D = preload("res://assets/textures/fx/FX_Scan_Hex_Outline.png")
const TEX_PLATFORM: Texture2D = preload("res://assets/textures/fx/FX_RezInParticle2_PNG.png")
const TEX_FLARE: Texture2D = preload("res://assets/textures/fx/FX_Flare3.png")
const TEX_SPARKLE: Texture2D = preload("res://assets/textures/fx/FX_BurstBubble_NoGlow.png")

const TOTAL_LIFETIME := 1.05

var fx_scale: float = 1.0

var _elapsed: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _scan_mesh: MeshInstance3D
var _scan_mat: StandardMaterial3D
var _hex_mesh: MeshInstance3D
var _hex_mat: StandardMaterial3D
var _platform_mesh: MeshInstance3D
var _platform_mat: StandardMaterial3D

# Each entry: { "node": MeshInstance3D, "mat": StandardMaterial3D, "delay": float, "life": float, ... }
var _beams: Array[Dictionary] = []
var _sparkles: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()
	_build_board_discs()
	_build_ray_beams()
	_build_sparkles()
	_update_effects(0.0)


func _make_plane_mat(tex: Texture2D, additive: bool, priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.render_priority = priority
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat


func _build_board_discs() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)

	# 1. Ground glow pad (Platform — Unity Particles/Alpha Blended applies 2x tint multiplier)
	_platform_mat = _make_plane_mat(TEX_PLATFORM, false, 1)
	_platform_mesh = MeshInstance3D.new()
	_platform_mesh.mesh = plane
	_platform_mesh.material_override = _platform_mat
	_platform_mesh.position = Vector3(0.0, 0.002 * fx_scale, 0.0)
	_platform_mesh.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	var p_size: float = 1.05 * fx_scale
	_platform_mesh.scale = Vector3(p_size, 1.0, p_size)
	add_child(_platform_mesh)

	# 2. Radial golden glow (FX_Scan)
	_scan_mat = _make_plane_mat(TEX_SCAN, false, 2)
	_scan_mesh = MeshInstance3D.new()
	_scan_mesh.mesh = plane
	_scan_mesh.material_override = _scan_mat
	_scan_mesh.position = Vector3(0.0, 0.004 * fx_scale, 0.0)
	_scan_mesh.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	add_child(_scan_mesh)

	# 3. Expanding Hexagon Outline (FX_ScanHexOutline)
	_hex_mat = _make_plane_mat(TEX_HEX_OUTLINE, false, 3)
	_hex_mesh = MeshInstance3D.new()
	_hex_mesh.mesh = plane
	_hex_mesh.material_override = _hex_mat
	_hex_mesh.position = Vector3(0.0, 0.006 * fx_scale, 0.0)
	_hex_mesh.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	add_child(_hex_mesh)


func _build_ray_beams() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var count: int = 9
	for i in range(count):
		var mat := _make_plane_mat(TEX_FLARE, true, 4)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.billboard_keep_scale = true

		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		var ang: float = (float(i) / float(count)) * TAU + _rng.randf_range(-0.35, 0.35)
		var rad: float = _rng.randf_range(0.22, 0.48) * fx_scale
		var start_y: float = _rng.randf_range(0.14, 0.32) * fx_scale
		var w: float = _rng.randf_range(0.045, 0.08) * fx_scale
		var h: float = _rng.randf_range(0.45, 0.78) * fx_scale
		mi.position = Vector3(cos(ang) * rad, start_y, sin(ang) * rad)
		mi.scale = Vector3(w, h, 1.0)
		mi.visible = false
		add_child(mi)

		_beams.append({
			"node": mi,
			"mat": mat,
			"delay": float(i) * 0.04,
			"life": 0.44,
			"start_y": start_y,
			"vel_y": _rng.randf_range(1.05, 1.55) * fx_scale,
		})


func _build_sparkles() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var count: int = 8
	for i in range(count):
		var mat := _make_plane_mat(TEX_SPARKLE, true, 5)
		mat.uv1_scale = Vector3(0.5, 1.0, 1.0)

		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		var ang: float = (float(i) / float(count)) * TAU + _rng.randf_range(-0.4, 0.4)
		var rad: float = _rng.randf_range(0.14, 0.46) * fx_scale
		var pos_y: float = _rng.randf_range(0.06, 0.36) * fx_scale
		var sz: float = _rng.randf_range(0.075, 0.14) * fx_scale
		mi.position = Vector3(cos(ang) * rad, pos_y, sin(ang) * rad)
		mi.scale = Vector3(sz, sz, sz)
		mi.visible = false
		add_child(mi)

		_sparkles.append({
			"node": mi,
			"mat": mat,
			"delay": float(i) * 0.045,
			"life": 0.42,
			"base_rot": _rng.randf_range(-1.5, 1.5),
			"spin": _rng.randf_range(-5.0, 5.0),
			"start_tile": i % 2,
		})


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TOTAL_LIFETIME:
		queue_free()
		return
	_update_effects(_elapsed)


func _sample_alpha_plateau(t: float, rise_end: float, fall_start: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	if t < rise_end:
		return clampf(t / rise_end, 0.0, 1.0)
	if t > fall_start:
		return clampf(1.0 - (t - fall_start) / (1.0 - fall_start), 0.0, 1.0)
	return 1.0


func _update_effects(t: float) -> void:
	# Platform (0.35s, soft warm pad letting board hex grid stay visible underneath)
	if t < 0.35:
		var pt: float = t / 0.35
		var pa: float = _sample_alpha_plateau(pt, 0.276, 0.621) * 0.26
		_platform_mesh.visible = pa > 0.005
		_platform_mat.albedo_color = Color(1.45, 1.40, 1.28, pa)
	else:
		_platform_mesh.visible = false

	# FX_Scan (0.75s, size 0.46 -> 1.18)
	if t < 0.75:
		var st: float = t / 0.75
		var sa: float = _sample_alpha_plateau(st, 0.276, 0.621) * 0.62
		var s_size: float = lerpf(0.46, 1.18, st) * fx_scale
		_scan_mesh.visible = sa > 0.005
		_scan_mesh.scale = Vector3(s_size, 1.0, s_size)
		_scan_mat.albedo_color = Color(1.30, 1.24, 1.02, sa)
	else:
		_scan_mesh.visible = false

	# FX_ScanHexOutline (delay 0.10s, life 0.75s, size 0.50 -> 1.22)
	var ht_raw: float = t - 0.10
	if ht_raw >= 0.0 and ht_raw < 0.75:
		var ht: float = ht_raw / 0.75
		var ha: float = (1.0 - ht) * 0.95
		var h_size: float = lerpf(0.50, 1.22, ht) * fx_scale
		_hex_mesh.visible = ha > 0.005
		_hex_mesh.scale = Vector3(h_size, 1.0, h_size)
		_hex_mat.albedo_color = Color(1.50, 1.48, 1.25, ha)
	else:
		_hex_mesh.visible = false

	# RayBeams
	for b in _beams:
		var node: MeshInstance3D = b["node"]
		var mat: StandardMaterial3D = b["mat"]
		var bt_raw: float = t - float(b["delay"])
		var blife: float = float(b["life"])
		if bt_raw < 0.0 or bt_raw >= blife:
			node.visible = false
			continue
		var bt: float = bt_raw / blife
		node.visible = true
		node.position.y = float(b["start_y"]) + float(b["vel_y"]) * bt_raw
		var ba: float = _sample_alpha_plateau(bt, 0.28, 0.36) * 0.95
		mat.albedo_color = Color(1.0, 0.96, 0.78, ba)

	# Sparkles
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	for sp in _sparkles:
		var node: MeshInstance3D = sp["node"]
		var mat: StandardMaterial3D = sp["mat"]
		var st_raw: float = t - float(sp["delay"])
		var slife: float = float(sp["life"])
		if st_raw < 0.0 or st_raw >= slife:
			node.visible = false
			continue
		var spt: float = st_raw / slife
		node.visible = true
		var spa: float = _sample_alpha_plateau(spt, 0.28, 0.32)
		mat.albedo_color = Color(1.0, 0.96, 0.78, spa)
		var tile_idx: int = (int(sp["start_tile"]) + int(floor(spt * 4.0))) % 2
		mat.uv1_offset = Vector3(0.5 if tile_idx == 1 else 0.0, 0.0, 0.0)
		if cam:
			node.look_at(cam.global_position, Vector3.UP)
			node.rotate_object_local(Vector3.BACK, float(sp["base_rot"]) + float(sp["spin"]) * st_raw)
