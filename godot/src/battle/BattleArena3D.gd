extends Node3D
class_name BattleArena3D

## 3D Treehouse Battle Stage & Dynamic Camera Rig.
## Hosts the tabletop environment, seated heroes, 8 hex board lanes,
## lane highlights, ketchup bottle pivot, and combat/inspection camera presets.

signal camera_transition_finished

const HoldCardsScene: PackedScene = preload("res://assets/models/battle/props/HoldCards.glb")
const PlayingCardScene: PackedScene = preload("res://assets/models/battle/props/PlayingCard.glb")
const FloopPadScene: PackedScene = preload("res://assets/models/battle/props/FloopPad.glb")
const GoldBagScene: PackedScene = preload("res://assets/models/battle/props/GoldBag.glb")
const P1TombstoneScene: PackedScene = preload("res://assets/models/battle/props/P1Tombstone.glb")
const P2TombstoneScene: PackedScene = preload("res://assets/models/battle/props/P2Tombstone.glb")
const ResultChest01Scene: PackedScene = preload("res://assets/models/battle/props/ResultLootChest_01.glb")
const ResultChest04Scene: PackedScene = preload("res://assets/models/battle/props/ResultLootChest_04.glb")
const PrizeSpotlightTex: Texture2D = preload("res://assets/textures/battle/hud/Prize_Spotlight.png")
const HexHighlightMesh: ArrayMesh = preload("res://assets/models/battle/GameBoardGrid_FX.obj")
const HexHighlightTexPath: String = "res://assets/textures/battle/FX_Scan_Hex_Solid.png"

# Unity BattleScene P1/P2CharacterPosition scaled by 0.05 (S_Z reflected)
const P1_CHAR_POS := Vector3(-3.35, -2.55, 0.0)
const P2_CHAR_POS := Vector3(3.35, -2.55, 0.0)

@onready var camera: Camera3D = $Camera3D
@onready var env_root: Node3D = $EnvironmentRoot
@onready var player_seat: Node3D = $PlayerSeat
@onready var opponent_seat: Node3D = $OpponentSeat
@onready var bottle_anchor: Node3D = $BottleAnchor

var player_hero_root: Node3D = null
var opponent_hero_root: Node3D = null
var player_cards_hand: Node3D = null
var opponent_cards_hand: Node3D = null
var player_playing_card: Node3D = null
var opponent_playing_card: Node3D = null
var _p1_anim_player: AnimationPlayer = null
var _p2_anim_player: AnimationPlayer = null
var _p1_char_info: Dictionary = {}
var _p2_char_info: Dictionary = {}
var _p1_face_tracks: Array[Dictionary] = []
var _p2_face_tracks: Array[Dictionary] = []
var _p1_mouth_mat: StandardMaterial3D = null
var _p2_mouth_mat: StandardMaterial3D = null
var _p1_eyes_mat: StandardMaterial3D = null
var _p2_eyes_mat: StandardMaterial3D = null
var _p1_face_elapsed: float = 0.0
var _p2_face_elapsed: float = 0.0
var _p1_face_playing: bool = false
var _p2_face_playing: bool = false

# Camera presets matched to Card Wars BattleScene angles (FOV 60 = Battle GameCamera)
const CAM_INTRO_WIDE_POS := Vector3(0.0, 2.50, 6.25)
const CAM_INTRO_WIDE_END_POS := Vector3(0.074, 2.39, 7.767)
const CAM_INTRO_WIDE_LOOK := Vector3(0.0, -0.125, 0.0)

const CAM_INTRO_P1_POS := Vector3(-0.83, 0.576, 1.139)
const CAM_INTRO_P1_LOOK := Vector3(-2.85, 0.30, 0.0)

const CAM_INTRO_P2_POS := Vector3(0.762, 0.355, 0.920)
const CAM_INTRO_P2_LOOK := Vector3(2.85, 0.30, 0.0)

const CAM_INTRO_ARENA_POS := Vector3(0.193, 1.606, 5.511)
const CAM_INTRO_ARENA_LOOK := Vector3(0.0, 0.0, 0.0)

const CAM_LANDSCAPE_POS := Vector3(-1.50, 1.25, 0.0)
const CAM_LANDSCAPE_LOOK := Vector3(-1.10, 0.0, 0.0)

const CAM_KETCHUP_POS := Vector3(-0.0575, 2.0235, 0.0)
const CAM_KETCHUP_LOOK := Vector3(-0.00135, -1.104, 0.0)

const CAM_SETUP_POS := Vector3(-1.876, 1.34, 0.0)
const CAM_SETUP_LOOK := Vector3(-0.85, -0.019, 0.0)

const CAM_LOOT_POS := Vector3(-1.05, 0.58, 0.0)
const CAM_LOOT_LOOK := Vector3(0.25, -0.02, 0.0)

# 4 lanes centered across the board width (Z in [-0.80 .. +0.86])
const LANE_Z_CENTERS: Array[float] = [-0.74, -0.21, 0.33, 0.86]
const PLAYER_LANE_X := -0.58
const OPPONENT_LANE_X := 0.56
const BOARD_SURFACE_Y := -0.122

var _cam_tween: Tween = null
var _cam_pos: Vector3 = CAM_INTRO_WIDE_POS
var _cam_look: Vector3 = CAM_INTRO_WIDE_LOOK

const LANDSCAPE_COLORS: Dictionary = {
	"Corn": Color(0.84, 0.72, 0.16, 1.0),
	"Cotton": Color(0.88, 0.62, 0.78, 1.0),
	"Plains": Color(0.28, 0.56, 0.72, 1.0),
	"Sand": Color(0.84, 0.66, 0.34, 1.0),
	"Swamp": Color(0.32, 0.42, 0.32, 1.0),
}

const LANDSCAPE_ACCENT_COLORS: Dictionary = {
	"Corn": Color(0.98, 0.90, 0.24, 1.0),
	"Cotton": Color(0.98, 0.96, 0.98, 1.0),
	"Plains": Color(0.45, 0.82, 0.95, 1.0),
	"Sand": Color(0.95, 0.82, 0.50, 1.0),
	"Swamp": Color(0.55, 0.78, 0.35, 1.0),
}

var _player_lane_anchors: Array[Node3D] = []
var _opponent_lane_anchors: Array[Node3D] = []
var _player_lane_highlights: Array[MeshInstance3D] = []
var _opponent_lane_highlights: Array[MeshInstance3D] = []
var _highlight_pulse_time: float = 0.0
var _active_highlights: Array[MeshInstance3D] = []

var _mesh_cache: Dictionary = {}
var _mat_cache: Dictionary = {}
var _tex_cache: Dictionary = {}
var _creature_heights: Dictionary = {} # key: "p_0" / "o_0" -> float height

var _split_overlay: Control = null
var _split_svp_p1: SubViewport = null
var _split_svp_p2: SubViewport = null
var _battle_cam_p1: Camera3D = null
var _battle_cam_p2: Camera3D = null
var _duel_split_active: bool = false
var _active_duel_lane_idx: int = -1
var _orig_grid_red_mat: Material = null
var _orig_grid_blue_mat: Material = null


func _ready() -> void:
	_build_lane_anchors()
	_setup_split_duel_overlay()
	set_camera_immediate(CAM_INTRO_WIDE_POS, CAM_INTRO_WIDE_LOOK, 60.0)


func _setup_split_duel_overlay() -> void:
	if _split_overlay != null:
		return
	_split_overlay = Control.new()
	_split_overlay.name = "SplitDuelOverlay"
	_split_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_split_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split_overlay.visible = false
	add_child(_split_overlay)

	var left_wrap := SubViewportContainer.new()
	left_wrap.name = "LeftSplitWrap"
	left_wrap.anchor_left = 0.0
	left_wrap.anchor_top = 0.0
	left_wrap.anchor_right = 0.5
	left_wrap.anchor_bottom = 1.0
	left_wrap.stretch = true
	left_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split_overlay.add_child(left_wrap)

	_split_svp_p1 = SubViewport.new()
	_split_svp_p1.name = "BattleSvpP1"
	_split_svp_p1.render_target_update_mode = SubViewport.UPDATE_DISABLED
	left_wrap.add_child(_split_svp_p1)

	_battle_cam_p1 = Camera3D.new()
	_battle_cam_p1.name = "BattleCamP1"
	_battle_cam_p1.fov = 60.0
	_battle_cam_p1.current = true
	_split_svp_p1.add_child(_battle_cam_p1)

	var right_wrap := SubViewportContainer.new()
	right_wrap.name = "RightSplitWrap"
	right_wrap.anchor_left = 0.5
	right_wrap.anchor_top = 0.0
	right_wrap.anchor_right = 1.0
	right_wrap.anchor_bottom = 1.0
	right_wrap.stretch = true
	right_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split_overlay.add_child(right_wrap)

	_split_svp_p2 = SubViewport.new()
	_split_svp_p2.name = "BattleSvpP2"
	_split_svp_p2.render_target_update_mode = SubViewport.UPDATE_DISABLED
	right_wrap.add_child(_split_svp_p2)

	_battle_cam_p2 = Camera3D.new()
	_battle_cam_p2.name = "BattleCamP2"
	_battle_cam_p2.fov = 60.0
	_battle_cam_p2.current = true
	_split_svp_p2.add_child(_battle_cam_p2)


func _disable_split_duel() -> void:
	_duel_split_active = false
	_active_duel_lane_idx = -1
	if _split_overlay:
		_split_overlay.visible = false
	if _split_svp_p1:
		_split_svp_p1.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _split_svp_p2:
		_split_svp_p2.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _exit_tree() -> void:
	clear_loot_chests()
	_active_highlights.clear()
	_mesh_cache.clear()
	_mat_cache.clear()
	_tex_cache.clear()


func _process(delta: float) -> void:
	if not _active_highlights.is_empty():
		_highlight_pulse_time += delta * 4.5
		var pulse := 0.38 + 0.22 * (0.5 + 0.5 * sin(_highlight_pulse_time))
		for hi in _active_highlights:
			var mat := hi.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color.a = pulse
	_step_face_tracks(delta, true)
	_step_face_tracks(delta, false)


func _build_lane_anchors() -> void:
	var slots_root := get_node_or_null("BoardSlots")
	if slots_root == null:
		slots_root = Node3D.new()
		slots_root.name = "BoardSlots"
		add_child(slots_root)

	for child in slots_root.get_children():
		slots_root.remove_child(child)
		child.queue_free()
	_player_lane_anchors.clear()
	_opponent_lane_anchors.clear()
	_player_lane_highlights.clear()
	_opponent_lane_highlights.clear()
	_creature_heights.clear()

	for i in range(4):
		var z_pos := LANE_Z_CENTERS[i]
		var p_slot := _create_lane_node("PlayerLane_%d" % i, Vector3(PLAYER_LANE_X, BOARD_SURFACE_Y, z_pos), true)
		slots_root.add_child(p_slot)
		_player_lane_anchors.append(p_slot)
		_player_lane_highlights.append(p_slot.get_node("Highlight") as MeshInstance3D)

		var o_slot := _create_lane_node("OpponentLane_%d" % i, Vector3(OPPONENT_LANE_X, BOARD_SURFACE_Y, z_pos), false)
		slots_root.add_child(o_slot)
		_opponent_lane_anchors.append(o_slot)
		_opponent_lane_highlights.append(o_slot.get_node("Highlight") as MeshInstance3D)


func _create_lane_node(node_name: String, pos: Vector3, is_player: bool) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos

	var terrain_holder := Node3D.new()
	terrain_holder.name = "Terrain"
	root.add_child(terrain_holder)

	var creature_anchor := Node3D.new()
	creature_anchor.name = "CreatureAnchor"
	creature_anchor.position = Vector3(0.14 if is_player else -0.14, 0.028, 0.0)
	root.add_child(creature_anchor)

	var building_anchor := Node3D.new()
	building_anchor.name = "BuildingAnchor"
	building_anchor.position = Vector3(-0.37 if is_player else 0.37, 0.025, 0.0)
	root.add_child(building_anchor)

	var drop_anchor := Node3D.new()
	drop_anchor.name = "DropAnchor"
	drop_anchor.position = Vector3(0.14 if is_player else -0.14, 0.026, 0.0)
	root.add_child(drop_anchor)

	var floop_pad := _create_floop_pad(is_player)
	floop_pad.name = "FloopPad"
	floop_pad.position = Vector3(-0.16 if is_player else 0.16, 0.024, 0.0)
	floop_pad.visible = false
	root.add_child(floop_pad)

	var hi := MeshInstance3D.new()
	hi.name = "Highlight"
	hi.mesh = HexHighlightMesh
	# GameBoardGrid_FX bounds are [-22.74..23.18] x [-20.69..21.96]; rotate -90 X to lie on board
	hi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	hi.scale = Vector3(1.08 / 45.92, 0.50 / 42.65, 1.0)
	hi.position = Vector3(0.0, 0.022, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ResourceLoader.exists(HexHighlightTexPath):
		mat.albedo_texture = load(HexHighlightTexPath)
	mat.albedo_color = Color(0.98, 0.88, 0.15, 0.55)
	hi.material_override = mat
	hi.visible = false
	root.add_child(hi)
	return root


func _create_floop_pad(is_player: bool) -> Node3D:
	var pad := Node3D.new()
	if FloopPadScene != null:
		var inst := FloopPadScene.instantiate() as Node3D
		if inst:
			var src_mesh: Mesh = null
			var stack: Array[Node] = [inst]
			while not stack.is_empty():
				var n: Node = stack.pop_back()
				if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
					src_mesh = (n as MeshInstance3D).mesh
					break
				for c in n.get_children():
					stack.append(c)
			inst.queue_free()
			if src_mesh != null:
				var face := MeshInstance3D.new()
				face.name = "Face"
				face.mesh = src_mesh
				# FloopPad mesh bounds are [-3.55..3.55] x [-1.43..1.43] x [-1.14..0.0]; center at origin on board
				face.scale = Vector3(0.052, -0.052, 0.018)
				face.rotation_degrees = Vector3(-90.0, 90.0 if is_player else -90.0, 0.0)
				face.position = Vector3(0.0, 0.022, 0.0)
				pad.add_child(face)
	return pad


func _get_cached_mesh(res_path: String) -> Mesh:
	if res_path == "" or not ResourceLoader.exists(res_path):
		return null
	if _mesh_cache.has(res_path):
		return _mesh_cache[res_path]
	var m := load(res_path) as Mesh
	if m:
		_mesh_cache[res_path] = m
	return m


func _get_cached_mat(tex_path: String, alpha: bool = false) -> StandardMaterial3D:
	var key := "%s|%s" % [tex_path, str(alpha)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if tex_path != "" and ResourceLoader.exists(tex_path):
		if not _tex_cache.has(tex_path):
			_tex_cache[tex_path] = load(tex_path)
		mat.albedo_texture = _tex_cache[tex_path]
	_mat_cache[key] = mat
	return mat


func clear_lane_landscapes() -> void:
	for anchor in _player_lane_anchors + _opponent_lane_anchors:
		for holder_name in ["Terrain", "CreatureAnchor", "BuildingAnchor"]:
			var holder := anchor.get_node_or_null(holder_name)
			if holder:
				for c in holder.get_children():
					holder.remove_child(c)
					c.queue_free()
		var pad := anchor.get_node_or_null("FloopPad")
		if pad:
			pad.visible = false
	_creature_heights.clear()


func set_lane_landscape(is_player: bool, lane_idx: int, faction: String, animate: bool = true) -> void:
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return
	var holder := anchor.get_node_or_null("Terrain")
	if holder == null:
		return
	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()

	if faction == "" or faction == "None":
		return

	var tile_root := Node3D.new()
	tile_root.name = "Landscape_%s" % faction
	tile_root.rotation_degrees = Vector3(0, 0.0 if is_player else 180.0, 0)
	holder.add_child(tile_root)

	var mesh_info: Dictionary = {}
	if Database and Database.has_method("get_landscape_mesh_info"):
		mesh_info = Database.get_landscape_mesh_info(faction, lane_idx)
	var mesh_path := str(mesh_info.get("mesh", ""))
	var tex_path := str(mesh_info.get("texture", ""))
	var land_mesh := _get_cached_mesh(mesh_path)

	if land_mesh != null:
		var mi := MeshInstance3D.new()
		mi.name = "TerrainMesh"
		mi.mesh = land_mesh
		mi.material_override = _get_cached_mat(tex_path)
		var aabb := land_mesh.get_aabb()
		var sx := 1.08 / maxf(0.001, aabb.size.x)
		var sz := 0.51 / maxf(0.001, aabb.size.z)
		var sy := 0.5 * (sx + sz)
		var cx := aabb.position.x + aabb.size.x * 0.5
		var cz := aabb.position.z + aabb.size.z * 0.5
		mi.scale = Vector3(sx, sy, sz)
		mi.position = Vector3(-cx * sx, -aabb.position.y * sy + 0.002, -cz * sz)
		tile_root.add_child(mi)
	else:
		var base_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.06, 0.50)
		base_mesh.mesh = plane
		base_mesh.position = Vector3(0, 0.005, 0)
		var base_mat := _get_cached_mat(tex_path)
		if tex_path == "":
			base_mat = StandardMaterial3D.new()
			base_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			base_mat.albedo_color = LANDSCAPE_COLORS.get(faction, LANDSCAPE_COLORS["Plains"])
		base_mesh.material_override = base_mat
		tile_root.add_child(base_mesh)

	if animate:
		tile_root.scale = Vector3(1.0, 0.05, 1.0)
		var tw := create_tween()
		tw.tween_property(tile_root, "scale:y", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func spawn_lane_creature(is_player: bool, lane_idx: int, card_data: Dictionary, animate: bool = true) -> void:
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return
	var holder := anchor.get_node_or_null("CreatureAnchor") as Node3D
	if holder == null:
		return
	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()
	var drop_holder := anchor.get_node_or_null("DropAnchor") as Node3D
	if drop_holder:
		_clear_node_children(drop_holder)

	var key := "%s_%d" % ["p" if is_player else "o", lane_idx]
	if card_data.is_empty():
		_creature_heights.erase(key)
		set_lane_flooped(is_player, lane_idx, false, false)
		return

	var mesh_info: Dictionary = Database.get_entity_mesh_info(card_data) if Database else {}
	var ent_mesh := _get_cached_mesh(str(mesh_info.get("mesh", "")))
	var ent_tex := str(mesh_info.get("texture", ""))
	var body := Node3D.new()
	body.name = "EntityBody"
	body.rotation_degrees = Vector3(0, -90.0 if is_player else 90.0, 0)
	holder.add_child(body)

	var h_world := 0.36
	if ent_mesh != null:
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = ent_mesh
		mi.material_override = _get_cached_mat(ent_tex)
		var aabb := ent_mesh.get_aabb()
		var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		var s := 0.40 / maxf(0.001, max_dim)
		var cx := aabb.position.x + aabb.size.x * 0.5
		var cz := aabb.position.z + aabb.size.z * 0.5
		mi.scale = Vector3(s, s, s)
		mi.position = Vector3(-cx * s, -aabb.position.y * s, -cz * s)
		body.add_child(mi)
		h_world = clampf(aabb.size.y * s, 0.22, 0.46)
	else:
		var fallback := Sprite3D.new()
		fallback.pixel_size = 0.0018
		fallback.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		var ftex := str(card_data.get("texture_path", ""))
		if ftex != "" and ResourceLoader.exists(ftex):
			fallback.texture = load(ftex)
		fallback.position = Vector3(0, 0.20, 0)
		body.add_child(fallback)

	_creature_heights[key] = h_world
	set_lane_flooped(is_player, lane_idx, false, true)

	if animate:
		body.scale = Vector3(0.08, 0.08, 0.08)
		var tw := create_tween()
		tw.tween_property(body, "scale", Vector3(1.12, 1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(body, "scale", Vector3.ONE, 0.10)


func spawn_lane_building(is_player: bool, lane_idx: int, card_data: Dictionary, animate: bool = true) -> void:
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return
	var holder := anchor.get_node_or_null("BuildingAnchor") as Node3D
	if holder == null:
		return
	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()

	if card_data.is_empty():
		return

	var mesh_info: Dictionary = Database.get_entity_mesh_info(card_data) if Database else {}
	var b_mesh := _get_cached_mesh(str(mesh_info.get("mesh", "")))
	var b_tex := str(mesh_info.get("texture", ""))
	var body := Node3D.new()
	body.name = "BuildingBody"
	body.rotation_degrees = Vector3(0, -90.0 if is_player else 90.0, 0)
	holder.add_child(body)

	if b_mesh != null:
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = b_mesh
		mi.material_override = _get_cached_mat(b_tex)
		var aabb := b_mesh.get_aabb()
		var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		var s := 0.34 / maxf(0.001, max_dim)
		var cx := aabb.position.x + aabb.size.x * 0.5
		var cz := aabb.position.z + aabb.size.z * 0.5
		mi.scale = Vector3(s, s, s)
		mi.position = Vector3(-cx * s, -aabb.position.y * s, -cz * s)
		body.add_child(mi)

	if animate:
		body.scale = Vector3(1.0, 0.05, 1.0)
		var tw := create_tween()
		tw.tween_property(body, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_lane_flooped(is_player: bool, lane_idx: int, is_flooped: bool, has_creature: bool = true) -> void:
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return
	var pad := anchor.get_node_or_null("FloopPad") as Node3D
	if pad:
		pad.visible = has_creature
		if has_creature:
			var face := pad.get_node_or_null("Face") as MeshInstance3D
			if face:
				face.material_override = _get_cached_mat("res://assets/textures/battle/Floop_Red.png", true) if is_flooped else null
	var holder := anchor.get_node_or_null("CreatureAnchor") as Node3D
	if holder:
		var body := holder.get_node_or_null("EntityBody") as Node3D
		if body:
			var target_rot_y := (-90.0 if is_player else 90.0) + (90.0 if is_flooped else 0.0)
			body.rotation_degrees = Vector3(0, target_rot_y, 0)


func animate_creature_lunge(is_player: bool, lane_idx: int) -> void:
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return
	var holder := anchor.get_node_or_null("CreatureAnchor") as Node3D
	if holder == null:
		return
	var dir := 0.22 if is_player else -0.22
	var base_x := 0.14 if is_player else -0.14
	var tw := create_tween()
	tw.tween_property(holder, "position:x", base_x + dir, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "position:x", base_x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func animate_creature_hit(is_player: bool, lane_idx: int) -> void:
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return
	var holder := anchor.get_node_or_null("CreatureAnchor") as Node3D
	if holder == null:
		return
	var base_x := 0.14 if is_player else -0.14
	var tw := create_tween()
	tw.tween_property(holder, "position:x", base_x + (-0.08 if is_player else 0.08), 0.08)
	tw.tween_property(holder, "position:x", base_x, 0.12)


func spawn_lane_drop_prop(is_player: bool, lane_idx: int, drop_type: String) -> void:
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return
	var drop_holder := anchor.get_node_or_null("DropAnchor") as Node3D
	if drop_holder == null:
		return
	_clear_node_children(drop_holder)

	var scene_res: PackedScene = null
	var anim_hint := ""
	if drop_type == "GOLD":
		scene_res = GoldBagScene
		anim_hint = "GoldBag_Anim"
	elif drop_type == "CARD":
		scene_res = ResultChest01Scene
		anim_hint = "LootChest_In"
	else:
		scene_res = P1TombstoneScene if is_player else P2TombstoneScene
		anim_hint = "Tombstone_Left" if is_player else "Tombstone_Right"

	if scene_res == null:
		return
	var prop := scene_res.instantiate() as Node3D
	if prop == null:
		return
	prop.name = "DropProp"
	prop.rotation_degrees = Vector3(0.0, -90.0 if is_player else 90.0, 0.0)
	if drop_type == "CARD":
		prop.scale = Vector3(0.75, 0.75, 0.75)
	drop_holder.add_child(prop)

	var ap := prop.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		if anim_hint != "" and ap.has_animation(anim_hint):
			ap.play(anim_hint)
		elif ap.get_animation_list().size() > 0:
			ap.play(ap.get_animation_list()[0])
		if drop_type == "CARD" and ap.has_animation("LootChest_Idle"):
			ap.queue("LootChest_Idle")


func get_creature_head_screen_pos(is_player: bool, lane_idx: int, container_size: Vector2) -> Vector2:
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return Vector2(-9999.0, -9999.0)
	var holder := anchor.get_node_or_null("CreatureAnchor") as Node3D
	if holder == null or holder.get_child_count() == 0:
		return Vector2(-9999.0, -9999.0)
	var key := "%s_%d" % ["p" if is_player else "o", lane_idx]
	var h := float(_creature_heights.get(key, 0.36))
	var world_pos := holder.global_position + Vector3(0.0, h + 0.06, 0.0)
	return _project_world_to_screen(world_pos, is_player, lane_idx, container_size, true)


func _project_world_to_screen(world_pos: Vector3, is_player: bool, lane_idx: int, container_size: Vector2, hide_non_duel: bool = false) -> Vector2:
	if _duel_split_active:
		if hide_non_duel and lane_idx != _active_duel_lane_idx:
			return Vector2(-9999.0, -9999.0)
		var cam := _battle_cam_p1 if is_player else _battle_cam_p2
		var svp := _split_svp_p1 if is_player else _split_svp_p2
		if cam == null or svp == null or cam.is_position_behind(world_pos):
			return Vector2(-9999.0, -9999.0)
		var sv_size := Vector2(svp.size)
		if sv_size.x <= 1.0 or sv_size.y <= 1.0:
			sv_size = Vector2(container_size.x * 0.5, container_size.y)
		var p := cam.unproject_position(world_pos)
		var half_w := container_size.x * 0.5
		var x_off := 0.0 if is_player else half_w
		return Vector2(x_off + p.x * (half_w / sv_size.x), p.y * (container_size.y / sv_size.y))

	if camera == null or camera.is_position_behind(world_pos):
		return Vector2(-9999.0, -9999.0)
	var sv := get_viewport()
	var sv_size := Vector2(sv.get_visible_rect().size) if sv else container_size
	if sv_size.x <= 1.0 or sv_size.y <= 1.0:
		sv_size = container_size
	var p := camera.unproject_position(world_pos)
	return Vector2(p.x * (container_size.x / sv_size.x), p.y * (container_size.y / sv_size.y))


func pick_board_at_screen_pos(screen_pos: Vector2, container_size: Vector2) -> Dictionary:
	if camera == null or container_size.x <= 1.0 or container_size.y <= 1.0:
		return {"valid": false}
	var sv := get_viewport()
	var sv_size := Vector2(sv.get_visible_rect().size) if sv else container_size
	var sv_pos := Vector2(screen_pos.x * (sv_size.x / container_size.x), screen_pos.y * (sv_size.y / container_size.y))
	var ro := camera.project_ray_origin(sv_pos)
	var rd := camera.project_ray_normal(sv_pos)
	if absf(rd.y) < 0.001:
		return {"valid": false}

	var hit := Vector3.ZERO
	var found := false
	var y_planes: Array[float] = [BOARD_SURFACE_Y + 0.06, BOARD_SURFACE_Y]
	for y_plane in y_planes:
		var t: float = (y_plane - ro.y) / rd.y
		if t > 0.05:
			var p: Vector3 = ro + rd * t
			if p.x >= -1.16 and p.x <= 1.16 and p.z >= -1.04 and p.z <= 1.14:
				hit = p
				found = true
				break
	if not found:
		return {"valid": false}

	var is_player := hit.x < 0.0
	var best_lane := 0
	var best_dz := 999.0
	for i in range(4):
		var dz := absf(hit.z - LANE_Z_CENTERS[i])
		if dz < best_dz:
			best_dz = dz
			best_lane = i

	var local_x := hit.x - (PLAYER_LANE_X if is_player else OPPONENT_LANE_X)
	var zone := "lane"
	if is_player:
		if local_x >= -0.28 and local_x <= -0.04 and absf(hit.z - LANE_Z_CENTERS[best_lane]) < 0.20:
			zone = "floop"
		elif local_x < -0.28:
			zone = "building"
		elif local_x > -0.04:
			zone = "creature"
	else:
		if local_x <= 0.28 and local_x >= 0.04 and absf(hit.z - LANE_Z_CENTERS[best_lane]) < 0.20:
			zone = "floop"
		elif local_x > 0.28:
			zone = "building"
		elif local_x < 0.04:
			zone = "creature"

	return {
		"valid": true,
		"is_player": is_player,
		"lane_idx": best_lane,
		"zone": zone,
		"world_pos": hit,
	}


func setup_heroes(player_id: String, opponent_id: String) -> void:
	var qid := GameManager.active_quest_id if GameManager else ""
	setup_arena(qid, player_id, opponent_id)


func setup_arena(quest_id: String, player_id: String, opponent_id: String) -> void:
	_disable_split_duel()
	set_board_postmatch_green(false)
	var q_data: Dictionary = Database.get_quest(quest_id) if (Database and quest_id != "") else {}
	var level_prefab := str(q_data.get("level_prefab", "")).strip_edges()
	if level_prefab == "":
		level_prefab = "TreeFort"
	var table_prefab := str(q_data.get("table_prefab", "")).strip_edges()
	if table_prefab == "":
		table_prefab = "TreeFort_Table"
	var chair_prefab := str(q_data.get("chair_prefab", "")).strip_edges()
	if chair_prefab == "":
		chair_prefab = "TreeFort_Chair"

	_load_environment(level_prefab, table_prefab)
	_spawn_hero_seat(true, player_id, chair_prefab)
	_spawn_hero_seat(false, opponent_id, chair_prefab)
	if opponent_seat:
		opponent_seat.visible = true


func _clear_node_children(parent: Node) -> void:
	if parent == null:
		return
	for c in parent.get_children():
		parent.remove_child(c)
		c.queue_free()


func _load_environment(level_prefab: String, table_prefab: String) -> void:
	if env_root == null:
		return
	_clear_node_children(env_root)

	for prefab_name in [level_prefab, table_prefab]:
		if prefab_name == "":
			continue
		var path := "res://assets/models/battle/environments/%s.glb" % prefab_name
		if not ResourceLoader.exists(path):
			continue
		var ps := load(path) as PackedScene
		if ps == null:
			continue
		var inst := ps.instantiate() as Node3D
		if inst:
			env_root.add_child(inst)


func _resolve_character_info(hero_id: String) -> Dictionary:
	if Database == null:
		return {}
	var norm := hero_id.strip_edges()
	if norm == "Fionna":
		norm = "Fiona"
	var info := Database.get_character(norm)
	if not info.is_empty():
		return info
	for cid in Database.characters_db.keys():
		var entry: Dictionary = Database.characters_db[cid]
		if str(entry.get("id", "")).to_lower() == norm.to_lower() or str(entry.get("prefab", "")).to_lower() == norm.to_lower():
			return entry
	return Database.get_character("Jake")


func _spawn_hero_seat(is_player: bool, hero_id: String, chair_prefab: String) -> void:
	var seat := player_seat if is_player else opponent_seat
	if seat == null:
		return
	_clear_node_children(seat)

	var base_pos := P1_CHAR_POS if is_player else P2_CHAR_POS
	# Unity P1CharacterPosition rot (0, +90, 0) & P2 (0, -90, 0) reflected via S_Z -> -90 Y / +90 Y
	var base_rot_y := -90.0 if is_player else 90.0
	seat.position = base_pos
	seat.rotation_degrees = Vector3(0.0, base_rot_y, 0.0)

	var info := _resolve_character_info(hero_id)
	if is_player:
		_p1_char_info = info
		player_hero_root = null
		player_cards_hand = null
		player_playing_card = null
		_p1_anim_player = null
		_p1_mouth_mat = null
		_p1_eyes_mat = null
	else:
		_p2_char_info = info
		opponent_hero_root = null
		opponent_cards_hand = null
		opponent_playing_card = null
		_p2_anim_player = null
		_p2_mouth_mat = null
		_p2_eyes_mat = null

	var use_chair := bool(info.get("use_chair", true))
	var cx := float(info.get("chair_offset_x", 0.0))
	var cy := float(info.get("chair_offset_y", 0.0))
	if not is_player:
		cx = -cx
	if use_chair and chair_prefab != "":
		var cpath := "res://assets/models/battle/environments/%s.glb" % chair_prefab
		if ResourceLoader.exists(cpath):
			var cps := load(cpath) as PackedScene
			if cps:
				var chair_inst := cps.instantiate() as Node3D
				if chair_inst:
					# Reset prefab root transform (below 0.05 scale wrapper) to match Unity Instantiate(prefab, pos, rot)
					if chair_inst.get_child_count() > 0:
						var wrap := chair_inst.get_child(0)
						if wrap.get_child_count() > 0 and wrap.get_child(0) is Node3D:
							var inner := wrap.get_child(0) as Node3D
							inner.position = Vector3.ZERO
							inner.rotation = Vector3.ZERO
					chair_inst.position = Vector3(cx * 0.05, cy * 0.05, 0.0)
					seat.add_child(chair_inst)

	var prefab_name := str(info.get("prefab", "Jake"))
	var hpath := "res://assets/models/battle/characters/%s.glb" % prefab_name
	if not ResourceLoader.exists(hpath):
		hpath = "res://assets/models/battle/characters/Jake.glb"
	var hps := load(hpath) as PackedScene
	if hps == null:
		return
	var hero_inst := hps.instantiate() as Node3D
	if hero_inst == null:
		return

	var hx := float(info.get("char_offset_x", 0.0))
	var hy := float(info.get("char_offset_y", 0.0))
	if not is_player:
		hx = -hx
	hero_inst.name = "HeroModel"
	hero_inst.position = Vector3(hx * 0.05, hy * 0.05, 0.0)
	seat.add_child(hero_inst)

	var ap := hero_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var hand_bone_name := str(info.get("hand", ""))
	var cards_node: Node3D = null
	if hand_bone_name != "" and HoldCardsScene != null:
		var hand_node := hero_inst.find_child(hand_bone_name, true, false) as Node3D
		if hand_node:
			var hc := HoldCardsScene.instantiate() as Node3D
			if hc:
				hc.name = "HoldCardsInstance"
				# HoldCards.glb already preserves Unity's (-90, 0, 0) X orientation reflected via S_Z
				hc.rotation_degrees = Vector3.ZERO
				hand_node.add_child(hc)
				cards_node = hc

	var play_card_node: Node3D = null
	if PlayingCardScene != null:
		var play_hand_bone := hero_inst.find_child("Puppet_CardPlay", true, false) as Node3D
		if play_hand_bone:
			var pc := PlayingCardScene.instantiate() as Node3D
			if pc:
				pc.name = "PlayingCardInstance"
				pc.rotation_degrees = Vector3.ZERO
				play_hand_bone.add_child(pc)
				play_card_node = pc

	# Configure M_MOUTH & M_EYES 4x4 UV atlas tiling
	var mouth_mat := _setup_face_uv_mat(hero_inst.find_child("M_MOUTH", true, false) as MeshInstance3D)
	var eyes_mat := _setup_face_uv_mat(hero_inst.find_child("M_EYES", true, false) as MeshInstance3D)

	if is_player:
		player_hero_root = hero_inst
		player_cards_hand = cards_node
		player_playing_card = play_card_node
		_p1_anim_player = ap
		_p1_mouth_mat = mouth_mat
		_p1_eyes_mat = eyes_mat
	else:
		opponent_hero_root = hero_inst
		opponent_cards_hand = cards_node
		opponent_playing_card = play_card_node
		_p2_anim_player = ap
		_p2_mouth_mat = mouth_mat
		_p2_eyes_mat = eyes_mat

	play_hero_anim(is_player, "anim_card_idle", "")


func _setup_face_uv_mat(face_mesh: MeshInstance3D) -> StandardMaterial3D:
	if face_mesh == null or face_mesh.mesh == null or face_mesh.mesh.get_surface_count() <= 0:
		return null
	var orig := face_mesh.get_active_material(0)
	if orig is StandardMaterial3D:
		var dup := orig.duplicate() as StandardMaterial3D
		dup.uv1_scale = Vector3(0.25, 0.25, 1.0)
		dup.uv1_offset = Vector3(0.0, 0.0, 0.0)
		dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		face_mesh.set_surface_override_material(0, dup)
		return dup
	return null


func play_hero_anim(is_player: bool, anim_slot: String, next_slot: String = "anim_card_idle") -> void:
	var ap := _p1_anim_player if is_player else _p2_anim_player
	var info := _p1_char_info if is_player else _p2_char_info
	if ap == null or info.is_empty():
		return
	var clip_name := str(info.get(anim_slot, ""))
	if clip_name == "" or not ap.has_animation(clip_name):
		clip_name = str(info.get("anim_card_idle", ""))
	if clip_name == "" or not ap.has_animation(clip_name):
		return

	var anim_res := ap.get_animation(clip_name)
	var is_idle_loop := (anim_slot == "anim_card_idle" or anim_slot == "anim_idle")
	if anim_res:
		anim_res.loop_mode = Animation.LOOP_LINEAR if is_idle_loop else Animation.LOOP_NONE
	ap.play(clip_name)
	_start_face_track(is_player, clip_name)

	if not is_idle_loop and next_slot != "":
		var next_name := str(info.get(next_slot, ""))
		if next_name != "" and ap.has_animation(next_name):
			var next_res := ap.get_animation(next_name)
			if next_res:
				next_res.loop_mode = Animation.LOOP_LINEAR
			ap.queue(next_name)


func _start_face_track(is_player: bool, anim_name: String) -> void:
	var path := "res://data/character_face_anim/%s.json" % anim_name
	var tracks: Array[Dictionary] = []
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var json := JSON.new()
			if json.parse(f.get_as_text()) == OK and typeof(json.data) == TYPE_ARRAY:
				for item in json.data:
					if typeof(item) == TYPE_DICTIONARY:
						var cnt := str(item.get("CNT", ""))
						if cnt == "CNT_MOUTH" or cnt == "CNT_EYES":
							tracks.append(item)
	if is_player:
		_p1_face_tracks = tracks
		_p1_face_elapsed = 0.0
		_p1_face_playing = not tracks.is_empty()
		_apply_initial_face_uv(true, tracks)
	else:
		_p2_face_tracks = tracks
		_p2_face_elapsed = 0.0
		_p2_face_playing = not tracks.is_empty()
		_apply_initial_face_uv(false, tracks)


func _apply_initial_face_uv(is_player: bool, tracks: Array[Dictionary]) -> void:
	var set_mouth := false
	var set_eyes := false
	for kf in tracks:
		var cnt := str(kf.get("CNT", ""))
		if cnt == "CNT_MOUTH" and not set_mouth:
			_apply_face_uv(is_player, "CNT_MOUTH", float(kf.get("x", 0.0)), float(kf.get("y", 0.75)))
			set_mouth = true
		elif cnt == "CNT_EYES" and not set_eyes:
			_apply_face_uv(is_player, "CNT_EYES", float(kf.get("x", 0.0)), float(kf.get("y", 0.75)))
			set_eyes = true
		if set_mouth and set_eyes:
			break


func _step_face_tracks(delta: float, is_player: bool) -> void:
	var playing := _p1_face_playing if is_player else _p2_face_playing
	if not playing:
		return
	var tracks := _p1_face_tracks if is_player else _p2_face_tracks
	if tracks.is_empty():
		return
	if is_player:
		_p1_face_elapsed += delta
	else:
		_p2_face_elapsed += delta
	var elapsed := _p1_face_elapsed if is_player else _p2_face_elapsed
	var chosen_mouth := {}
	var chosen_eyes := {}
	for kf in tracks:
		if elapsed >= float(kf.get("time", 0.0)):
			var cnt := str(kf.get("CNT", ""))
			if cnt == "CNT_MOUTH":
				chosen_mouth = kf
			elif cnt == "CNT_EYES":
				chosen_eyes = kf
	if not chosen_mouth.is_empty():
		_apply_face_uv(is_player, "CNT_MOUTH", float(chosen_mouth.get("x", 0.0)), float(chosen_mouth.get("y", 0.75)))
	if not chosen_eyes.is_empty():
		_apply_face_uv(is_player, "CNT_EYES", float(chosen_eyes.get("x", 0.0)), float(chosen_eyes.get("y", 0.75)))
	if elapsed > float(tracks[tracks.size() - 1].get("time", 0.0)) + 0.1:
		if is_player:
			_p1_face_playing = false
		else:
			_p2_face_playing = false


func _apply_face_uv(is_player: bool, cnt: String, ux: float, uy: float) -> void:
	var mat: StandardMaterial3D = null
	if cnt == "CNT_EYES":
		mat = _p1_eyes_mat if is_player else _p2_eyes_mat
	else:
		mat = _p1_mouth_mat if is_player else _p2_mouth_mat
	if mat:
		mat.uv1_offset = Vector3(ux, 0.75 - uy, 0.0)


func set_camera_transform(xform: Transform3D, fov_deg: float = 60.0) -> void:
	if _cam_tween and _cam_tween.is_running():
		_cam_tween.kill()
	if camera:
		camera.fov = fov_deg
		camera.global_transform = xform
		_cam_pos = camera.global_position
		_cam_look = _cam_pos - camera.global_transform.basis.z * 4.0


func set_cards_in_hand_visible(visible_flag: bool) -> void:
	if player_cards_hand:
		player_cards_hand.visible = visible_flag
	if opponent_cards_hand:
		opponent_cards_hand.visible = visible_flag
	if player_playing_card:
		player_playing_card.visible = visible_flag
	if opponent_playing_card:
		opponent_playing_card.visible = visible_flag


func set_lane_highlight(is_player: bool, lane_idx: int, enabled: bool, color: Color = Color(0.98, 0.88, 0.15, 0.45)) -> void:
	var list := _player_lane_highlights if is_player else _opponent_lane_highlights
	if lane_idx < 0 or lane_idx >= list.size():
		return
	var hi := list[lane_idx]
	hi.visible = enabled
	var mat := hi.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = color
	if enabled and not _active_highlights.has(hi):
		_active_highlights.append(hi)
	elif not enabled and _active_highlights.has(hi):
		_active_highlights.erase(hi)


func clear_all_highlights() -> void:
	_active_highlights.clear()
	for hi in _player_lane_highlights:
		hi.visible = false
	for hi in _opponent_lane_highlights:
		hi.visible = false


func get_lane_anchor(is_player: bool, lane_idx: int) -> Node3D:
	var list := _player_lane_anchors if is_player else _opponent_lane_anchors
	if lane_idx >= 0 and lane_idx < list.size():
		return list[lane_idx]
	return null


func set_camera_immediate(pos: Vector3, look_target: Vector3, fov_deg: float = 60.0) -> void:
	if _cam_tween and _cam_tween.is_running():
		_cam_tween.kill()
	_cam_pos = pos
	_cam_look = look_target
	if camera:
		camera.fov = fov_deg
		camera.global_position = pos
		camera.look_at(look_target, Vector3.UP)


func tween_camera(pos: Vector3, look_target: Vector3, duration: float = 0.65, fov_deg: float = 60.0) -> Tween:
	if _cam_tween and _cam_tween.is_running():
		_cam_tween.kill()
	var start_pos := _cam_pos
	var start_look := _cam_look
	var start_fov := camera.fov if camera else 60.0
	_cam_tween = create_tween()
	_cam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_method(func(t: float) -> void:
		_cam_pos = start_pos.lerp(pos, t)
		_cam_look = start_look.lerp(look_target, t)
		if camera:
			camera.fov = lerpf(start_fov, fov_deg, t)
			camera.global_position = _cam_pos
			camera.look_at(_cam_look, Vector3.UP)
	, 0.0, 1.0, maxf(0.01, duration))
	_cam_tween.tween_callback(func(): camera_transition_finished.emit())
	return _cam_tween


func focus_landscape_placement(duration: float = 0.7) -> Tween:
	_disable_split_duel()
	return tween_camera(CAM_LANDSCAPE_POS, CAM_LANDSCAPE_LOOK, duration, 60.0)


func focus_ketchup_spin(duration: float = 0.55) -> Tween:
	_disable_split_duel()
	return tween_camera(CAM_KETCHUP_POS, CAM_KETCHUP_LOOK, duration, 60.0)


func focus_setup_board(duration: float = 0.65) -> Tween:
	_disable_split_duel()
	if player_seat:
		player_seat.visible = true
	if opponent_seat:
		opponent_seat.visible = true
	return tween_camera(CAM_SETUP_POS, CAM_SETUP_LOOK, duration, 60.0)


func focus_lane_zoom(is_player: bool, lane_idx: int, duration: float = 0.45) -> Tween:
	_disable_split_duel()
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return focus_setup_board(duration)
	var p := anchor.global_position
	var cam_pos := Vector3(p.x - 0.85, 0.72, p.z + (0.28 if p.z < 0.0 else -0.28))
	var look_pos := Vector3(p.x + 0.15, p.y + 0.22, p.z)
	return tween_camera(cam_pos, look_pos, duration, 40.0)


func focus_duel_lane(lane_idx: int, _player_attacking: bool, duration: float = 0.40) -> Tween:
	_active_duel_lane_idx = clampi(lane_idx, 0, 3)
	var z := LANE_Z_CENTERS[_active_duel_lane_idx]
	var p1_pos := Vector3(-0.04, 0.42, z + 1.08)
	var p1_look := Vector3(-0.62, 0.10, z - 0.10)
	var p2_pos := Vector3(0.04, 0.42, z + 1.08)
	var p2_look := Vector3(0.60, 0.10, z - 0.10)

	var was_active := _duel_split_active
	_duel_split_active = true
	if opponent_seat:
		opponent_seat.visible = true
	set_cards_in_hand_visible(true)

	var main_vp := get_viewport()
	if main_vp and main_vp.world_3d:
		if _split_svp_p1 and _split_svp_p1.world_3d != main_vp.world_3d:
			_split_svp_p1.world_3d = main_vp.world_3d
		if _split_svp_p2 and _split_svp_p2.world_3d != main_vp.world_3d:
			_split_svp_p2.world_3d = main_vp.world_3d

	if _split_overlay:
		_split_overlay.visible = true
	if _split_svp_p1:
		_split_svp_p1.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _split_svp_p2:
		_split_svp_p2.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	if _battle_cam_p1 and _battle_cam_p2:
		_battle_cam_p1.fov = 52.0
		_battle_cam_p2.fov = 52.0
		if not was_active or duration <= 0.05:
			_battle_cam_p1.global_position = p1_pos
			_battle_cam_p1.look_at(p1_look, Vector3.UP)
			_battle_cam_p2.global_position = p2_pos
			_battle_cam_p2.look_at(p2_look, Vector3.UP)
		else:
			var s1_pos := _battle_cam_p1.global_position
			var s2_pos := _battle_cam_p2.global_position
			var s1_quat := _battle_cam_p1.global_transform.basis.get_rotation_quaternion()
			var s2_quat := _battle_cam_p2.global_transform.basis.get_rotation_quaternion()
			var t1 := Transform3D().looking_at(p1_look - p1_pos, Vector3.UP).basis.get_rotation_quaternion()
			var t2 := Transform3D().looking_at(p2_look - p2_pos, Vector3.UP).basis.get_rotation_quaternion()
			if _cam_tween and _cam_tween.is_running():
				_cam_tween.kill()
			_cam_tween = create_tween()
			_cam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_cam_tween.tween_method(func(t: float) -> void:
				if _battle_cam_p1:
					_battle_cam_p1.global_position = s1_pos.lerp(p1_pos, t)
					_battle_cam_p1.global_transform.basis = Basis(s1_quat.slerp(t1, t))
				if _battle_cam_p2:
					_battle_cam_p2.global_position = s2_pos.lerp(p2_pos, t)
					_battle_cam_p2.global_transform.basis = Basis(s2_quat.slerp(t2, t))
			, 0.0, 1.0, maxf(0.05, duration))
			return _cam_tween
	return null


func focus_ko_camera(player_lost: bool, duration: float = 0.25) -> Tween:
	_disable_split_duel()
	set_cards_in_hand_visible(true)
	if opponent_seat:
		opponent_seat.visible = true
	if player_lost:
		return tween_camera(Vector3(0.85, 0.60, 0.0), Vector3(-0.25, 0.22, 0.0), duration, 60.0)
	return tween_camera(Vector3(-0.85, 0.60, 0.0), Vector3(0.25, 0.22, 0.0), duration, 60.0)


func play_lane_direct_hit_vfx(target_is_player: bool, lane_idx: int) -> void:
	set_lane_highlight(target_is_player, lane_idx, true, Color(0.96, 0.06, 0.06, 0.72))
	var t := get_tree().create_timer(0.65)
	t.timeout.connect(func():
		if is_inside_tree():
			set_lane_highlight(target_is_player, lane_idx, false)
	)


func get_lane_screen_pos(is_player: bool, lane_idx: int, container_size: Vector2) -> Vector2:
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return container_size * 0.5
	var world_pos := anchor.global_position + Vector3(0.0, 0.24, 0.0)
	var spos := _project_world_to_screen(world_pos, is_player, lane_idx, container_size, false)
	return container_size * 0.5 if spos.x < -1000.0 else spos


func set_board_postmatch_green(enabled: bool) -> void:
	var grid_red := get_node_or_null("GameBoard/BoardGridRed") as MeshInstance3D
	var grid_blue := get_node_or_null("GameBoard/BoardGridBlue") as MeshInstance3D
	if grid_red == null or grid_blue == null:
		return
	if _orig_grid_red_mat == null:
		_orig_grid_red_mat = grid_red.get_surface_override_material(0)
	if _orig_grid_blue_mat == null:
		_orig_grid_blue_mat = grid_blue.get_surface_override_material(0)
	if enabled:
		var loot_tex_path := "res://assets/textures/environment/GameBoardGrid_Loot.png"
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if ResourceLoader.exists(loot_tex_path):
			mat.albedo_texture = load(loot_tex_path)
		else:
			mat.albedo_color = Color(0.28, 0.72, 0.16, 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		grid_red.set_surface_override_material(0, mat)
		grid_blue.set_surface_override_material(0, mat)
	else:
		grid_red.set_surface_override_material(0, _orig_grid_red_mat)
		grid_blue.set_surface_override_material(0, _orig_grid_blue_mat)


func focus_loot_floor(duration: float = 0.65) -> Tween:
	_disable_split_duel()
	set_board_postmatch_green(true)
	if player_seat:
		player_seat.visible = false
	if opponent_seat:
		opponent_seat.visible = true
	set_cards_in_hand_visible(true)
	play_hero_anim(false, "anim_card_idle", "anim_card_idle")
	return tween_camera(CAM_LOOT_POS, CAM_LOOT_LOOK, duration, 60.0)


func play_ko_slump(player_lost: bool) -> void:
	play_hero_anim(player_lost, "anim_defeated", "")
	play_hero_anim(not player_lost, "anim_happy", "")


func clear_all_entities() -> void:
	_disable_split_duel()
	clear_all_highlights()
	clear_lane_landscapes()
	if player_seat:
		player_seat.visible = true
	if opponent_seat:
		opponent_seat.visible = true
	set_cards_in_hand_visible(true)
	set_board_postmatch_green(false)
	for anchor in _player_lane_anchors + _opponent_lane_anchors:
		if anchor == null:
			continue
		for sub_name in ["CreatureAnchor", "BuildingAnchor", "DropAnchor"]:
			var holder := anchor.get_node_or_null(sub_name) as Node3D
			if holder:
				_clear_node_children(holder)
		var pad := anchor.get_node_or_null("FloopPad") as Node3D
		if pad:
			pad.visible = false
	_creature_heights.clear()


var _loot_chests: Array[Dictionary] = []


func clear_loot_chests() -> void:
	var holder := get_node_or_null("LootChests")
	if holder:
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
	_loot_chests.clear()


func spawn_loot_chests(card_ids: Array) -> int:
	clear_all_entities()
	set_board_postmatch_green(true)
	if player_seat:
		player_seat.visible = false
	if opponent_seat:
		opponent_seat.visible = true
	clear_loot_chests()
	if card_ids.is_empty():
		return 0

	var holder := get_node_or_null("LootChests") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "LootChests"
		add_child(holder)

	var count := mini(4, card_ids.size())
	var spawn_pts: Array[Vector3] = [
		Vector3(-0.18, BOARD_SURFACE_Y + 0.02, -0.42),
		Vector3(-0.18, BOARD_SURFACE_Y + 0.02, 0.0),
		Vector3(-0.18, BOARD_SURFACE_Y + 0.02, 0.42),
		Vector3(0.16, BOARD_SURFACE_Y + 0.02, -0.22),
	]
	if count == 1:
		spawn_pts = [Vector3(-0.18, BOARD_SURFACE_Y + 0.02, -0.40)]

	for i in range(count):
		var cid := str(card_ids[i])
		var c_data: Dictionary = Database.get_card(cid) if Database else {}
		var rarity := int(c_data.get("rarity", 1))
		var chest_scene: PackedScene = ResultChest04Scene if (rarity >= 4 and ResultChest04Scene != null) else ResultChest01Scene
		if chest_scene == null:
			continue

		var slot := Node3D.new()
		slot.name = "LootChest_%d" % i
		var target_pos := spawn_pts[i]
		slot.position = target_pos
		holder.add_child(slot)

		# Original Prize_Spotlight glow pad flat under chest
		var pad := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2(0.46, 0.46)
		pad.mesh = quad
		var p_mat := StandardMaterial3D.new()
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		p_mat.albedo_texture = PrizeSpotlightTex
		p_mat.albedo_color = Color(0.65, 1.0, 0.42, 0.55)
		pad.material_override = p_mat
		pad.position = Vector3(0.0, 0.004, 0.0)
		slot.add_child(pad)

		var chest := chest_scene.instantiate() as Node3D
		if chest:
			var inner := chest.find_child("ResultLootChest_01", true, false) as Node3D
			if inner == null:
				inner = chest.find_child("ResultLootChest_04", true, false) as Node3D
			if inner:
				inner.position = Vector3.ZERO
			chest.rotation_degrees = Vector3(0, -90.0, 0)
			slot.add_child(chest)
			var ap := chest.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if ap:
				if ap.has_animation("LootChest_In"):
					ap.play("LootChest_In")
				if ap.has_animation("LootChest_Idle"):
					ap.queue("LootChest_Idle")
			slot.position.y = target_pos.y + 0.65
			var tw := create_tween()
			tw.tween_property(slot, "position:y", target_pos.y, 0.35 + i * 0.08).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		_loot_chests.append({
			"idx": i,
			"card_id": cid,
			"slot": slot,
			"chest": chest,
			"pad": pad,
			"opened": false,
		})

	return _loot_chests.size()


func pick_chest_at_screen_pos(screen_pos: Vector2, container_size: Vector2) -> int:
	if camera == null or _loot_chests.is_empty() or container_size.x <= 1.0:
		return -1
	var sv := get_viewport()
	var sv_size := Vector2(sv.get_visible_rect().size) if sv else container_size
	var sv_pos := Vector2(screen_pos.x * (sv_size.x / container_size.x), screen_pos.y * (sv_size.y / container_size.y))
	var ro := camera.project_ray_origin(sv_pos)
	var rd := camera.project_ray_normal(sv_pos)
	if absf(rd.y) < 0.001:
		return -1
	var t := ((BOARD_SURFACE_Y + 0.14) - ro.y) / rd.y
	if t <= 0.05:
		return -1
	var hit := ro + rd * t
	var best_idx := -1
	var best_d := 0.42
	for item in _loot_chests:
		if bool(item.get("opened", false)):
			continue
		var slot := item["slot"] as Node3D
		if slot:
			var d := Vector2(hit.x - slot.position.x, hit.z - slot.position.z).length()
			if d < best_d:
				best_d = d
				best_idx = int(item["idx"])
	return best_idx


func get_chest_screen_pos(idx: int, container_size: Vector2) -> Vector2:
	if idx < 0 or idx >= _loot_chests.size() or camera == null:
		return container_size * 0.5
	var slot := _loot_chests[idx]["slot"] as Node3D
	if slot == null:
		return container_size * 0.5
	var world_pos := slot.global_position + Vector3(0.0, 0.24, 0.0)
	if camera.is_position_behind(world_pos):
		return container_size * 0.5
	var sv := get_viewport()
	var sv_size := Vector2(sv.get_visible_rect().size) if sv else container_size
	if sv_size.x <= 1.0 or sv_size.y <= 1.0:
		sv_size = container_size
	var p := camera.unproject_position(world_pos)
	return Vector2(p.x * (container_size.x / sv_size.x), p.y * (container_size.y / sv_size.y))


func open_loot_chest(idx: int) -> Node3D:
	if idx < 0 or idx >= _loot_chests.size():
		return null
	var item: Dictionary = _loot_chests[idx]
	item["opened"] = true
	var pad := item.get("pad") as MeshInstance3D
	if pad and pad.material_override is StandardMaterial3D:
		(pad.material_override as StandardMaterial3D).albedo_color = Color(0.4, 0.4, 0.4, 0.18)
	var chest := item.get("chest") as Node3D
	if chest:
		var ap := chest.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			if ap.has_animation("LootChest_NewCard_In"):
				ap.play("LootChest_NewCard_In")
			elif ap.has_animation("LootChest_Out"):
				ap.play("LootChest_Out")
	return chest


func focus_chest_zoom(idx: int, duration: float = 0.40) -> Tween:
	return focus_loot_floor(duration)
