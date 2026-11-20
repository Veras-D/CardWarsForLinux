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
const HexAnimTexPath: String = "res://assets/textures/battle/HexAnim.png"
const HEX_SCAN_FX_POSITIONS: Array[Vector3] = [
	Vector3(-1.226716 * 0.05, -2.699997 * 0.05 + 0.001, -14.7205 * 0.05),   # GameBoard_FX_A1
	Vector3(-8.765346 * 0.05, -2.699997 * 0.05 + 0.001, -14.75634 * 0.05),  # GameBoard_FX_A2
	Vector3(-16.28412 * 0.05, -2.699997 * 0.05 + 0.001, -14.75634 * 0.05),  # GameBoard_FX_A3
	Vector3(-1.226716 * 0.05, -2.700000 * 0.05 + 0.001, 13.65900 * 0.05),   # GameBoard_FX_D1
	Vector3(-8.765346 * 0.05, -2.700000 * 0.05 + 0.001, 13.62316 * 0.05),   # GameBoard_FX_D2
	Vector3(-16.28412 * 0.05, -2.700000 * 0.05 + 0.001, 13.62316 * 0.05),   # GameBoard_FX_D3
]

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
var _p1_table_card: Node3D = null
var _p2_table_card: Node3D = null
var _p1_table_card_ready: bool = false
var _p2_table_card_ready: bool = false
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

# 4 lanes matching BattleScene.unity P1Lane1..4mass / P2Lane1..4mass (* 0.05, Z reflected)
const LANE_Z_CENTERS: Array[float] = [-0.8045, -0.2975, 0.2914, 0.8140]
const P1_LANDSCAPE_Z: Array[float] = [-0.8045, -0.2975, 0.2914, 0.8140]
const P2_LANDSCAPE_Z: Array[float] = [-0.8162, -0.2936, 0.2953, 0.8023]
const PLAYER_LANE_X := -0.5769
const OPPONENT_LANE_X := 0.5769
# Offsets relative to lane center matching BattleScene.unity world X: Creature ±0.305, Floop ±0.550, Building ±0.895
const CREATURE_OFFSET_X := 0.2719
const FLOOP_PAD_OFFSET_X := 0.0269
const BUILDING_OFFSET_X := 0.3181
const BOARD_SURFACE_Y := -0.122
# Matches BattleScene.unity local scale (0.994, 0.78, 1.0) in Maya -90X space * WORLD_SCALE (0.05)
const LANDSCAPE_MESH_SCALE := Vector3(0.0497, 0.05, 0.039)

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
var _hex_scan_root: Node3D = null
var _hex_scan_mat: StandardMaterial3D = null
var _hex_scan_active: bool = false
var _hex_scan_time: float = 0.0

var _mesh_cache: Dictionary = {}
var _scene_cache: Dictionary = {}
var _mat_cache: Dictionary = {}
var _tex_cache: Dictionary = {}
var _creature_heights: Dictionary = {} # key: "p_0" / "o_0" -> float height
var _entity_meta: Dictionary = {} # key: "p_0_c" / "p_0_b" / "o_0_c" / "o_0_b" -> Dictionary

# Unity BattleScene.unity CWiTweenVantageCam vantage points (* 0.05, S_Z reflected)
const CREATURE_VANTAGE_POINTS: Array[Vector3] = [
	Vector3(0.0, 0.05, -0.50),
	Vector3(0.0, 0.05, 0.00),
	Vector3(0.0, 0.05, 0.60),
	Vector3(0.0, 0.05, 1.20),
]
const BUILDING_VANTAGE_POINTS: Array[Vector3] = [
	Vector3(0.0, 0.45, -0.25),
	Vector3(0.0, 0.45, 0.35),
	Vector3(0.0, 0.45, 0.95),
	Vector3(0.0, 0.45, 1.55),
]
const DETAIL_CAMERA_OFFSET := Vector3(-0.75, 0.75, 0.0) # CWCommandCardSet detailCameraOffsetX/Y = 15 * 0.05
const FLOOP_CAMERA_OFFSET := Vector3(-0.65, 1.00, 0.0)  # CWFloopActionManager floopCameraOffsetX=13, Y=20 * 0.05
const SUMMON_UNDERGROUND_Y := -0.50                     # SummonScript -10f * 0.05

const FX_SCAN_HEX_SOLID_TEX: String = "res://assets/textures/battle/FX_Scan_Hex_Solid.png"
const FX_SCAN_HEX_OUTLINE_TEX: String = "res://assets/textures/fx/FX_Scan_Hex_Outline.png"
const FX_SCAN_TEX: String = "res://assets/textures/fx/FX_Scan.png"
const FX_FLARE_TEX: String = "res://assets/textures/fx/FX_Flare3_TGA.png"
const FX_SPARKLES_TEX: String = "res://assets/textures/fx/FX_BurstBubble_NoGlow_PNG.png"
const FX_EXCLAMATION_TEX: String = "res://assets/textures/fx/FX_Battle_ExclamationMark_PNG.png"
const SFX_REZIN_PATH: String = "res://assets/audio/sfx/FX_RezInParticle.wav"
const SFX_DEREZ_PATH: String = "res://assets/audio/sfx/SFX_Derez.wav"

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
	_build_hex_scan_fx()
	_setup_split_duel_overlay()
	set_camera_immediate(CAM_INTRO_WIDE_POS, CAM_INTRO_WIDE_LOOK, 60.0)


func _build_hex_scan_fx() -> void:
	_hex_scan_root = Node3D.new()
	_hex_scan_root.name = "HexScanFX"
	_hex_scan_root.visible = false
	add_child(_hex_scan_root)

	_hex_scan_mat = StandardMaterial3D.new()
	_hex_scan_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hex_scan_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hex_scan_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_hex_scan_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_hex_scan_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
	if ResourceLoader.exists(HexAnimTexPath):
		_hex_scan_mat.albedo_texture = load(HexAnimTexPath)
	_hex_scan_mat.uv1_scale = Vector3(0.25, 0.25, 1.0)
	_hex_scan_mat.uv1_offset = Vector3.ZERO

	for i in range(HEX_SCAN_FX_POSITIONS.size()):
		var mi := MeshInstance3D.new()
		mi.name = "GameBoard_FX_%d" % i
		mi.mesh = HexHighlightMesh
		mi.material_override = _hex_scan_mat
		mi.position = HEX_SCAN_FX_POSITIONS[i]
		# GameBoardGrid_FX.obj has Godot Z reflected; +90 X places it flat in X/Z plane matching Unity -90 X
		mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		mi.scale = Vector3(0.0125, 0.0125, 0.0125)
		_hex_scan_root.add_child(mi)


func set_hex_scan_fx_visible(enabled: bool) -> void:
	_hex_scan_active = enabled
	_hex_scan_time = 0.0
	if _hex_scan_mat:
		_hex_scan_mat.uv1_offset = Vector3.ZERO
	if _hex_scan_root:
		_hex_scan_root.visible = enabled


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
	_scene_cache.clear()
	_mat_cache.clear()
	_tex_cache.clear()
	_entity_meta.clear()


func _process(delta: float) -> void:
	if not _active_highlights.is_empty():
		_highlight_pulse_time += delta * 4.5
		var pulse := 0.38 + 0.22 * (0.5 + 0.5 * sin(_highlight_pulse_time))
		for hi in _active_highlights:
			var mat := hi.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color.a = pulse
	if _hex_scan_active and _hex_scan_mat != null:
		_hex_scan_time += delta
		var frame := int(_hex_scan_time * 15.0) % 16
		var col := frame % 4
		var row := int(floor(float(frame) / 4.0))
		_hex_scan_mat.uv1_offset = Vector3(float(col) * 0.25, float(row) * 0.25, 0.0)
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
	_entity_meta.clear()

	for i in range(4):
		var p_slot := _create_lane_node("PlayerLane_%d" % i, Vector3(PLAYER_LANE_X, BOARD_SURFACE_Y, P1_LANDSCAPE_Z[i]), true)
		slots_root.add_child(p_slot)
		_player_lane_anchors.append(p_slot)
		_player_lane_highlights.append(p_slot.get_node("Highlight") as MeshInstance3D)

		var o_slot := _create_lane_node("OpponentLane_%d" % i, Vector3(OPPONENT_LANE_X, BOARD_SURFACE_Y, P2_LANDSCAPE_Z[i]), false)
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
	creature_anchor.position = Vector3(CREATURE_OFFSET_X if is_player else -CREATURE_OFFSET_X, 0.028, 0.0)
	root.add_child(creature_anchor)

	var building_anchor := Node3D.new()
	building_anchor.name = "BuildingAnchor"
	building_anchor.position = Vector3(-BUILDING_OFFSET_X if is_player else BUILDING_OFFSET_X, 0.025, 0.0)
	root.add_child(building_anchor)

	var drop_anchor := Node3D.new()
	drop_anchor.name = "DropAnchor"
	drop_anchor.position = Vector3(CREATURE_OFFSET_X if is_player else -CREATURE_OFFSET_X, 0.026, 0.0)
	root.add_child(drop_anchor)

	var floop_pad := _create_floop_pad(is_player)
	floop_pad.name = "FloopPad"
	floop_pad.position = Vector3(FLOOP_PAD_OFFSET_X if is_player else -FLOOP_PAD_OFFSET_X, 0.024, 0.0)
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


func _get_cached_detail_mat(tex_path: String) -> StandardMaterial3D:
	var key := "%s|scissor" % tex_path
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.35
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
	_entity_meta.clear()


func set_lane_landscape(is_player: bool, lane_idx: int, faction: String, animate: bool = true) -> void:
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return
	var holder := anchor.get_node_or_null("Terrain")
	if holder == null:
		return

	if faction == "" or faction == "None":
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
		return

	# Preserve already-spawned (or currently animating) landscape when BattleController finalizes non-animated layout.
	if not animate and holder.get_node_or_null("Landscape_%s" % faction) != null:
		return

	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()

	var tile_root := Node3D.new()
	tile_root.name = "Landscape_%s" % faction
	tile_root.rotation_degrees = Vector3(0, 0.0 if is_player else 180.0, 0)
	holder.add_child(tile_root)

	# Opponent row is rotated 180Y, so P2 lane 0..3 (-Z..+Z) uses Land_4..1 so outer edges stay straight and curves interlock.
	var variant_idx := lane_idx if is_player else (3 - lane_idx)
	var mesh_info: Dictionary = {}
	if Database and Database.has_method("get_landscape_mesh_info"):
		mesh_info = Database.get_landscape_mesh_info(faction, variant_idx)
	var mesh_path := str(mesh_info.get("mesh", ""))
	var tex_path := str(mesh_info.get("texture", ""))
	var detail_mesh_path := str(mesh_info.get("detail_mesh", ""))
	var detail_tex_path := str(mesh_info.get("detail_texture", ""))
	var land_mesh := _get_cached_mesh(mesh_path)

	var slab_mi: MeshInstance3D = null
	var detail_mi: MeshInstance3D = null

	if land_mesh != null:
		slab_mi = MeshInstance3D.new()
		slab_mi.name = "TerrainMesh"
		slab_mi.mesh = land_mesh
		slab_mi.material_override = _get_cached_mat(tex_path)
		slab_mi.scale = LANDSCAPE_MESH_SCALE
		slab_mi.position = Vector3(0.0, 0.003, 0.0)
		tile_root.add_child(slab_mi)
	else:
		slab_mi = MeshInstance3D.new()
		slab_mi.name = "TerrainMesh"
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.06, 0.50)
		slab_mi.mesh = plane
		slab_mi.position = Vector3(0, 0.005, 0)
		var base_mat := _get_cached_mat(tex_path)
		if tex_path == "":
			base_mat = StandardMaterial3D.new()
			base_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			base_mat.albedo_color = LANDSCAPE_COLORS.get(faction, LANDSCAPE_COLORS["Plains"])
		slab_mi.material_override = base_mat
		tile_root.add_child(slab_mi)

	var detail_mesh := _get_cached_mesh(detail_mesh_path)
	if detail_mesh != null:
		detail_mi = MeshInstance3D.new()
		detail_mi.name = "DetailMesh"
		detail_mi.mesh = detail_mesh
		detail_mi.material_override = _get_cached_detail_mat(detail_tex_path)
		detail_mi.scale = LANDSCAPE_MESH_SCALE
		detail_mi.position = Vector3(0.0, 0.004, 0.0)
		tile_root.add_child(detail_mi)

	if animate:
		if slab_mi and slab_mi.material_override is StandardMaterial3D:
			var final_mat := slab_mi.material_override as StandardMaterial3D
			var fade_mat := final_mat.duplicate() as StandardMaterial3D
			fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fade_mat.albedo_color.a = 0.0
			slab_mi.material_override = fade_mat
			var fade_tw := create_tween()
			fade_tw.tween_property(fade_mat, "albedo_color:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			fade_tw.tween_callback(func():
				if is_instance_valid(slab_mi):
					slab_mi.material_override = final_mat
			)
		if detail_mi:
			detail_mi.scale = Vector3(LANDSCAPE_MESH_SCALE.x, 0.0005, LANDSCAPE_MESH_SCALE.z)
			var prop_tw := create_tween()
			prop_tw.tween_interval(0.08)
			prop_tw.tween_property(detail_mi, "scale", LANDSCAPE_MESH_SCALE, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _get_cached_scene(scene_path: String) -> PackedScene:
	if scene_path == "":
		return null
	if _scene_cache.has(scene_path):
		return _scene_cache[scene_path] as PackedScene
	if not ResourceLoader.exists(scene_path):
		return null
	var sc := load(scene_path) as PackedScene
	if sc:
		_scene_cache[scene_path] = sc
	return sc


func _compute_hierarchy_aabb(node: Node3D) -> AABB:
	var combined := AABB()
	var has_box := false
	var root_inv := node.global_transform.affine_inverse() if node.is_inside_tree() else Transform3D.IDENTITY
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur := stack.pop_back() as Node
		for ch in cur.get_children():
			stack.append(ch)
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh:
				var a := mi.mesh.get_aabb()
				var xf := (root_inv * mi.global_transform) if node.is_inside_tree() else mi.transform
				var b := xf * a
				if not has_box:
					combined = b
					has_box = true
				else:
					combined = combined.merge(b)
	return combined if has_box else AABB(Vector3(-0.15, 0.0, -0.15), Vector3(0.3, 0.34, 0.3))


func _play_ap_clip(ap: AnimationPlayer, clip_name: String, loop: bool = false, start_time: float = -1.0, speed: float = 1.0) -> bool:
	if ap == null or clip_name == "":
		return false
	var resolved := clip_name
	if not ap.has_animation(resolved):
		for an in ap.get_animation_list():
			if str(an).to_lower() == clip_name.to_lower() or str(an).ends_with("_" + clip_name):
				resolved = str(an)
				break
	if not ap.has_animation(resolved):
		return false
	var anim := ap.get_animation(resolved)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	ap.speed_scale = speed
	ap.play(resolved)
	ap.seek(start_time if start_time >= 0.0 else 0.0, true)
	return true


func _queue_ap_clip(ap: AnimationPlayer, clip_name: String, loop: bool = true) -> void:
	if ap == null or clip_name == "":
		return
	var resolved := clip_name
	if not ap.has_animation(resolved):
		for an in ap.get_animation_list():
			if str(an).to_lower() == clip_name.to_lower():
				resolved = str(an)
				break
	if not ap.has_animation(resolved):
		return
	var anim := ap.get_animation(resolved)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	ap.queue(resolved)


func _get_entity_body(is_player: bool, lane_idx: int, is_building: bool) -> Node3D:
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return null
	var holder := anchor.get_node_or_null("BuildingAnchor" if is_building else "CreatureAnchor") as Node3D
	if holder == null:
		return null
	return holder.get_node_or_null("BuildingBody" if is_building else "EntityBody") as Node3D


func _make_fx_add_mat(tex: Texture2D, tint: Color, billboard_mode: BaseMaterial3D.BillboardMode = BaseMaterial3D.BILLBOARD_DISABLED, uv_scale: Vector2 = Vector2.ONE, uv_offset: Vector2 = Vector2.ZERO) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = billboard_mode
	mat.billboard_keep_scale = true
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	mat.uv1_offset = Vector3(uv_offset.x, uv_offset.y, 0.0)
	return mat


func _spawn_floor_fx_quad(fx_root: Node3D, tex_path: String, size_m: float, local_pos: Vector3, delay: float, life: float, start_scale: float, end_scale: float, peak_alpha: float) -> void:
	if not ResourceLoader.exists(tex_path):
		return
	var tex := load(tex_path) as Texture2D
	if tex == null:
		return
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size_m, size_m)
	mi.mesh = pm
	var mat := _make_fx_add_mat(tex, Color(1.0, 0.98, 0.85, 0.0))
	mi.material_override = mat
	mi.position = local_pos
	mi.scale = Vector3(start_scale, 1.0, start_scale)
	fx_root.add_child(mi)

	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(mat, "albedo_color:a", peak_alpha, life * 0.25).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(mi, "scale", Vector3(end_scale, 1.0, end_scale), life * 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, life * 0.55).set_trans(Tween.TRANS_SINE)


func _spawn_summon_vfx(parent_anchor: Node3D, is_building: bool) -> void:
	if parent_anchor == null:
		return
	var fx_root := Node3D.new()
	fx_root.name = "SummonFX"
	parent_anchor.add_child(fx_root)
	var s := 0.88 if is_building else 1.0

	# Mirrors Assets/Resources/particles/FX_RezIn_Creature.prefab & FX_RezInParticle_Building.prefab:
	# 1. FX_Scan base glow disk (size 6 * 0.05 = 0.30m, delay 0, life 1.5s)
	_spawn_floor_fx_quad(fx_root, FX_SCAN_TEX, 0.34 * s, Vector3(0.0, 0.008, 0.0), 0.0, 1.50, 0.35, 1.15, 0.85)
	# 2. FX_ScanHexOutline ring (size 6 * 0.05 = 0.30m, delay 0.45s, life 0.85s)
	_spawn_floor_fx_quad(fx_root, FX_SCAN_HEX_OUTLINE_TEX, 0.36 * s, Vector3(0.0, 0.011, 0.0), 0.45, 0.85, 0.40, 1.08, 0.95)
	# 3. FX_ScanHexSolid1/2/3 staggered inner hexes (size 2 * 0.05 = 0.10m)
	_spawn_floor_fx_quad(fx_root, FX_SCAN_HEX_SOLID_TEX, 0.12 * s, Vector3(1.297 * 0.05 * s, 0.013, 0.0), 0.58, 0.58, 0.30, 1.05, 0.90)
	_spawn_floor_fx_quad(fx_root, FX_SCAN_HEX_SOLID_TEX, 0.12 * s, Vector3(-0.613 * 0.05 * s, 0.013, 1.171 * 0.05 * s), 0.70, 0.58, 0.30, 1.05, 0.90)
	_spawn_floor_fx_quad(fx_root, FX_SCAN_HEX_SOLID_TEX, 0.12 * s, Vector3(-0.613 * 0.05 * s, 0.013, -1.057 * 0.05 * s), 0.84, 0.58, 0.30, 1.05, 0.90)

	# 4. RayBeam: tall vertical light streaks shooting upward (FX_Flare3_TGA, 5/sec)
	if ResourceLoader.exists(FX_FLARE_TEX):
		var ftex := load(FX_FLARE_TEX) as Texture2D
		var beam_count := 8 if is_building else 10
		for i in range(beam_count):
			var bm := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.026 * s, 0.56 * s)
			bm.mesh = qm
			var bmat := _make_fx_add_mat(ftex, Color(1.0, 0.99, 0.88, 0.0), BaseMaterial3D.BILLBOARD_FIXED_Y)
			bm.material_override = bmat
			var ang := float(i) * 2.39996
			var rad := randf_range(0.03, 0.15 * s)
			var start_y := 0.12
			bm.position = Vector3(cos(ang) * rad, start_y, sin(ang) * rad)
			fx_root.add_child(bm)
			var tw_b := create_tween()
			var d := 0.14 * float(i)
			tw_b.tween_interval(d)
			tw_b.tween_property(bmat, "albedo_color:a", 0.92, 0.16)
			tw_b.parallel().tween_property(bm, "position:y", start_y + 0.42, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_b.tween_property(bmat, "albedo_color:a", 0.0, 0.45)

	# 5. Sparkles2: additive 8-point starbursts & sparkles (FX_BurstBubble_NoGlow_PNG 2x1 sheet)
	if ResourceLoader.exists(FX_SPARKLES_TEX):
		var stex := load(FX_SPARKLES_TEX) as Texture2D
		var star_count := 6 if is_building else 8
		for i in range(star_count):
			var sm := MeshInstance3D.new()
			var sqm := QuadMesh.new()
			var sz := randf_range(0.055, 0.095) * s
			sqm.size = Vector2(sz, sz)
			sm.mesh = sqm
			var frame_idx := 0 if (i % 3 != 2) else 1
			var smat := _make_fx_add_mat(stex, Color(1.0, 0.98, 0.88, 0.0), BaseMaterial3D.BILLBOARD_ENABLED, Vector2(0.5, 1.0), Vector2(0.5 * float(frame_idx), 0.0))
			sm.material_override = smat
			var ang2 := float(i) * 2.1 + 0.4
			var rad2 := randf_range(0.03, 0.15 * s)
			var sy := randf_range(0.08, 0.24)
			sm.position = Vector3(cos(ang2) * rad2, sy, sin(ang2) * rad2)
			fx_root.add_child(sm)
			var tw_s := create_tween()
			tw_s.tween_interval(0.16 * float(i))
			tw_s.tween_property(smat, "albedo_color:a", 0.92, 0.18)
			tw_s.parallel().tween_property(sm, "position:y", sy + 0.34, 0.90).set_trans(Tween.TRANS_SINE)
			tw_s.tween_property(smat, "albedo_color:a", 0.0, 0.45)

	if ResourceLoader.exists(SFX_REZIN_PATH):
		Audio.play_sfx_with_variation(load(SFX_REZIN_PATH), -4.0, 0.04)

	var fx_id := fx_root.get_instance_id()
	var clean_timer := get_tree().create_timer(2.6)
	clean_timer.timeout.connect(func():
		var fx := instance_from_id(fx_id) as Node
		if is_instance_valid(fx):
			fx.queue_free()
	)


func _play_delayed_spawn_audio(wav_path: String, delay_secs: float) -> void:
	if wav_path == "" or not ResourceLoader.exists(wav_path):
		return
	if delay_secs > 0.01:
		var t := get_tree().create_timer(delay_secs)
		t.timeout.connect(func():
			if is_inside_tree() and ResourceLoader.exists(wav_path):
				Audio.play_sfx_with_variation(load(wav_path), -3.0, 0.04)
		)
	else:
		Audio.play_sfx_with_variation(load(wav_path), -3.0, 0.04)


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
	var meta_key := "%s_c" % key
	if card_data.is_empty():
		_creature_heights.erase(key)
		_entity_meta.erase(meta_key)
		set_lane_flooped(is_player, lane_idx, false, false)
		return

	var mesh_info: Dictionary = Database.get_entity_mesh_info(card_data) if Database else {}
	var ent_scene := _get_cached_scene(str(mesh_info.get("scene", "")))
	var intro_clip := str(mesh_info.get("intro", ""))
	var idle_clip := str(mesh_info.get("idle", ""))
	var ambient_clip := str(mesh_info.get("ambient", ""))
	var spawn_audio := str(mesh_info.get("spawn_audio", ""))
	var spawn_delay := float(mesh_info.get("spawn_audio_delay", 0.0))

	var body := Node3D.new()
	body.name = "EntityBody"
	body.rotation_degrees = Vector3(0, -90.0 if is_player else 90.0, 0)
	holder.add_child(body)

	var ap: AnimationPlayer = null
	var h_world := 0.34
	if ent_scene != null:
		var inst := ent_scene.instantiate() as Node3D
		if inst:
			inst.name = "Model"
			body.add_child(inst)
			ap = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
			var aabb := _compute_hierarchy_aabb(inst)
			h_world = clampf(aabb.size.y, 0.20, 0.52)
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
	_entity_meta[meta_key] = {
		"intro": intro_clip,
		"idle": idle_clip if idle_clip != "" else ambient_clip,
		"intro_length": float(mesh_info.get("intro_length", 1.5)),
	}
	set_lane_flooped(is_player, lane_idx, false, true)

	if animate:
		# Matches CreatureManagerScript.Summon + SummonScript.SummonAction:
		# 1. FX_RezIn_Creature spawns immediately on the hex while creature sits at -10f (-0.50m) underground.
		# 2. After 1.0s (WaitForSeconds(1f)), PlaySpawnAudio() triggers, creature pops to board surface (+10f) and plays Intro -> Idle.
		body.position.y = SUMMON_UNDERGROUND_Y
		_spawn_summon_vfx(holder, false)
		var body_id := body.get_instance_id()
		var ap_id := ap.get_instance_id() if ap else 0
		var t_fx := get_tree().create_timer(1.0)
		t_fx.timeout.connect(func():
			var b := instance_from_id(body_id) as Node3D
			if not is_inside_tree() or b == null:
				return
			_play_delayed_spawn_audio(spawn_audio, spawn_delay)
			b.position.y = 0.0
			var ap_node := instance_from_id(ap_id) as AnimationPlayer if ap_id != 0 else null
			if ap_node:
				if not _play_ap_clip(ap_node, intro_clip, false):
					_play_ap_clip(ap_node, idle_clip, true)
				if idle_clip != "":
					_queue_ap_clip(ap_node, idle_clip, true)
			else:
				b.scale = Vector3(0.08, 0.08, 0.08)
				var tw := create_tween()
				tw.tween_property(b, "scale", Vector3(1.12, 1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(b, "scale", Vector3.ONE, 0.10)
		)
	else:
		body.position.y = 0.0
		if ap:
			_play_ap_clip(ap, idle_clip if idle_clip != "" else ambient_clip, true)


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

	var key := "%s_%d" % ["p" if is_player else "o", lane_idx]
	var meta_key := "%s_b" % key
	if card_data.is_empty():
		_entity_meta.erase(meta_key)
		return

	var mesh_info: Dictionary = Database.get_entity_mesh_info(card_data) if Database else {}
	var b_scene := _get_cached_scene(str(mesh_info.get("scene", "")))
	var ambient_clip := str(mesh_info.get("ambient", ""))
	var spawn_audio := str(mesh_info.get("spawn_audio", ""))
	var spawn_delay := float(mesh_info.get("spawn_audio_delay", 0.0))

	var body := Node3D.new()
	body.name = "BuildingBody"
	body.rotation_degrees = Vector3(0, -90.0 if is_player else 90.0, 0)
	holder.add_child(body)

	var ap: AnimationPlayer = null
	if b_scene != null:
		var inst := b_scene.instantiate() as Node3D
		if inst:
			inst.name = "Model"
			body.add_child(inst)
			ap = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer

	_entity_meta[meta_key] = {
		"intro": "",
		"idle": ambient_clip,
		"intro_length": float(mesh_info.get("intro_length", 2.0)),
	}

	if ap and ambient_clip != "":
		_play_ap_clip(ap, ambient_clip, true)

	if animate:
		# Matches SummonScript.SummonAction for buildings: start at -10f -> immediate FX -> iTween.MoveTo 2.0s rise
		body.position.y = SUMMON_UNDERGROUND_Y
		_spawn_summon_vfx(holder, true)
		_play_delayed_spawn_audio(spawn_audio, spawn_delay)
		var body_id := body.get_instance_id()
		var t_fx := get_tree().create_timer(0.75)
		t_fx.timeout.connect(func():
			var b := instance_from_id(body_id) as Node3D
			if not is_inside_tree() or b == null:
				return
			var tw := create_tween()
			tw.tween_property(b, "position:y", 0.0, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)
	else:
		body.position.y = 0.0


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


func play_entity_floop(is_player: bool, lane_idx: int, is_building: bool = false) -> void:
	var body := _get_entity_body(is_player, lane_idx, is_building)
	if body == null:
		return
	var ap := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var meta_key := "%s_%d_%s" % ["p" if is_player else "o", lane_idx, "b" if is_building else "c"]
	var idle_clip := str(_entity_meta.get(meta_key, {}).get("idle", ""))
	if ap:
		if _play_ap_clip(ap, "Floop", false) and idle_clip != "":
			_queue_ap_clip(ap, idle_clip, true)
	if is_building and ResourceLoader.exists(FX_EXCLAMATION_TEX):
		var etex := load(FX_EXCLAMATION_TEX) as Texture2D
		var sp := Sprite3D.new()
		sp.texture = etex
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.pixel_size = 0.20 / maxf(1.0, float(etex.get_height())) if etex else 0.0008
		sp.modulate = Color(1.0, 0.94, 0.35, 1.0)
		sp.position = Vector3(0.0, 0.34, 0.0)
		body.add_child(sp)
		var sp_id := sp.get_instance_id()
		var tw := create_tween()
		tw.tween_property(sp, "position:y", 0.56, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.45).set_delay(0.35)
		tw.tween_callback(func():
			var sp_n := instance_from_id(sp_id) as Node
			if is_instance_valid(sp_n):
				sp_n.queue_free()
		)


func animate_creature_lunge(is_player: bool, lane_idx: int) -> void:
	var body := _get_entity_body(is_player, lane_idx, false)
	if body:
		var ap := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var meta_key := "%s_%d_c" % ["p" if is_player else "o", lane_idx]
		var idle_clip := str(_entity_meta.get(meta_key, {}).get("idle", ""))
		if ap and _play_ap_clip(ap, "Crash", false):
			if idle_clip != "":
				_queue_ap_clip(ap, idle_clip, true)
			return
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return
	var holder := anchor.get_node_or_null("CreatureAnchor") as Node3D
	if holder == null:
		return
	var dir := 0.22 if is_player else -0.22
	var base_x := CREATURE_OFFSET_X if is_player else -CREATURE_OFFSET_X
	var tw := create_tween()
	tw.tween_property(holder, "position:x", base_x + dir, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "position:x", base_x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func animate_creature_hit(is_player: bool, lane_idx: int, is_crit: bool = false) -> void:
	var body := _get_entity_body(is_player, lane_idx, false)
	if body:
		var ap := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var meta_key := "%s_%d_c" % ["p" if is_player else "o", lane_idx]
		var idle_clip := str(_entity_meta.get(meta_key, {}).get("idle", ""))
		if ap:
			if is_crit and _play_ap_clip(ap, "Hammer", false, 0.96, 1.35):
				if idle_clip != "":
					_queue_ap_clip(ap, idle_clip, true)
				return
			elif _play_ap_clip(ap, "Crash", false, 0.0, 1.25):
				if idle_clip != "":
					_queue_ap_clip(ap, idle_clip, true)
				return
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return
	var holder := anchor.get_node_or_null("CreatureAnchor") as Node3D
	if holder == null:
		return
	var base_x := CREATURE_OFFSET_X if is_player else -CREATURE_OFFSET_X
	var tw := create_tween()
	tw.tween_property(holder, "position:x", base_x + (-0.08 if is_player else 0.08), 0.08)
	tw.tween_property(holder, "position:x", base_x, 0.12)


func despawn_lane_entity_animated(is_player: bool, lane_idx: int, is_building: bool = false) -> void:
	var key := "%s_%d" % ["p" if is_player else "o", lane_idx]
	if not is_building:
		_creature_heights.erase(key)
		set_lane_flooped(is_player, lane_idx, false, false)
	_entity_meta.erase("%s_%s" % [key, "b" if is_building else "c"])

	var body := _get_entity_body(is_player, lane_idx, is_building)
	if body == null:
		return
	# Rename immediately so any follow-up summon in the same frame won't collide
	body.name = "DyingEntity"
	if ResourceLoader.exists(SFX_DEREZ_PATH):
		Audio.play_sfx_with_variation(load(SFX_DEREZ_PATH), -3.0, 0.04)
	var ap := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clip_name := "Derez" if is_building else "Death"
	var wait_secs := 0.95 if is_building else 0.30
	if ap and _play_ap_clip(ap, clip_name, false):
		var a := ap.get_animation(clip_name)
		if a:
			wait_secs = maxf(wait_secs, a.length)
	else:
		var tw := create_tween()
		tw.tween_property(body, "position:y", SUMMON_UNDERGROUND_Y, 0.25)
	var body_id := body.get_instance_id()
	var t := get_tree().create_timer(wait_secs)
	t.timeout.connect(func():
		var b := instance_from_id(body_id) as Node
		if is_instance_valid(b):
			b.queue_free()
	)


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
				# Lies flat face-up on the table at the end of IntroP1/P2 (matches PlayingCard.prefab -90 X).
				pc.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
				pc.visible = false
				play_hand_bone.add_child(pc)
				play_card_node = pc
	_reset_table_card(is_player)

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


func _reset_table_card(is_player: bool) -> void:
	var existing := _p1_table_card if is_player else _p2_table_card
	if existing and is_instance_valid(existing):
		if existing.get_parent():
			existing.get_parent().remove_child(existing)
		existing.queue_free()
	var spawned: Node3D = null
	if PlayingCardScene != null:
		spawned = PlayingCardScene.instantiate() as Node3D
		if spawned:
			spawned.name = "P1TableCard" if is_player else "P2TableCard"
			spawned.visible = false
			add_child(spawned)
	if is_player:
		_p1_table_card = spawned
		_p1_table_card_ready = false
	else:
		_p2_table_card = spawned
		_p2_table_card_ready = false


func _find_bone_attachment_ancestor(node: Node, stop_at: Node) -> BoneAttachment3D:
	var cur := node.get_parent() if node else null
	while cur != null and cur != stop_at:
		if cur is BoneAttachment3D:
			return cur as BoneAttachment3D
		cur = cur.get_parent()
	return null


func _capture_table_card_transform(is_player: bool) -> void:
	var hero := player_hero_root if is_player else opponent_hero_root
	var pc := player_playing_card if is_player else opponent_playing_card
	var table_card := _p1_table_card if is_player else _p2_table_card
	var ap := _p1_anim_player if is_player else _p2_anim_player
	var info := _p1_char_info if is_player else _p2_char_info
	if hero == null or pc == null or table_card == null or ap == null or info.is_empty():
		return
	var clip := str(info.get("anim_intro_p1" if is_player else "anim_intro_p2", ""))
	if clip == "" or not ap.has_animation(clip):
		return
	var res := ap.get_animation(clip)
	if res:
		res.loop_mode = Animation.LOOP_NONE
	ap.play(clip)
	ap.seek(res.length if res else 0.0, true)
	ap.advance(0.0)
	ap.pause()
	_start_face_track(is_player, clip)
	var skel := hero.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		skel.force_update_all_bone_transforms()
	var ba := _find_bone_attachment_ancestor(pc, hero)
	if ba:
		ba.on_skeleton_update()
	table_card.global_transform = pc.global_transform
	if is_player:
		_p1_table_card_ready = true
	else:
		_p2_table_card_ready = true


func set_heroes_card_on_table(on_table: bool, retract_hands: bool = true, blend_sec: float = 0.45) -> void:
	## Places separate cards on the table at each hero's end-of-intro spot;
	## set retract_hands = false to keep hands resting beside the cards before smoothly blending back to idle.
	for is_player in [true, false]:
		var pc := player_playing_card if is_player else opponent_playing_card
		if pc:
			pc.visible = false
		var table_card := _p1_table_card if is_player else _p2_table_card
		if on_table:
			var ready := _p1_table_card_ready if is_player else _p2_table_card_ready
			if not ready:
				_capture_table_card_transform(is_player)
			if table_card:
				table_card.visible = true
			if retract_hands:
				play_hero_anim(is_player, "anim_card_idle", "", blend_sec)
		else:
			if table_card:
				table_card.visible = false
			if retract_hands:
				play_hero_anim(is_player, "anim_card_idle", "", blend_sec)


func update_holding_cards_count(is_player: bool, count: int) -> void:
	## Mirrors CWPlayCardsController.SetHoldingCardsVisibility: show Card_1..Card_N matching hand size.
	var hand_node := player_cards_hand if is_player else opponent_cards_hand
	if hand_node == null:
		return
	var clamped := clampi(count, 0, 7)
	for i in range(7):
		var card_mesh := hand_node.find_child("Card_%d" % (i + 1), true, false) as Node3D
		if card_mesh:
			card_mesh.visible = (i < clamped)


func play_hero_anim(is_player: bool, anim_slot: String, next_slot: String = "anim_card_idle", blend_sec: float = -1.0) -> void:
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
	ap.play(clip_name, blend_sec)
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


func set_cards_in_hand_visible(visible_flag: bool, include_play_cards: bool = false) -> void:
	if player_cards_hand:
		player_cards_hand.visible = visible_flag
	if opponent_cards_hand:
		opponent_cards_hand.visible = visible_flag
	if player_playing_card:
		player_playing_card.visible = visible_flag and include_play_cards
	if opponent_playing_card:
		opponent_playing_card.visible = visible_flag and include_play_cards


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


func focus_summon_camera(is_player: bool, lane_idx: int, is_building: bool = false, duration: float = 0.50) -> Tween:
	_disable_split_duel()
	var li := clampi(lane_idx, 0, 3)
	var anchor := get_lane_anchor(is_player, li)
	if anchor == null:
		return focus_setup_board(duration)
	var sub := anchor.get_node_or_null("BuildingAnchor" if is_building else "CreatureAnchor") as Node3D
	var target_pos := sub.global_position if sub else anchor.global_position

	# CWiTweenVantageCam: Lane{1..4}{Creature,Building}VantagePoint + bounds-scaled camera pullback
	var vantage := BUILDING_VANTAGE_POINTS[li] if is_building else CREATURE_VANTAGE_POINTS[li]
	var key := "%s_%d" % ["p" if is_player else "o", li]
	var h := float(_creature_heights.get(key, 0.25))
	var look_pos := target_pos + Vector3(0.0, 0.10 if is_building else (h * 0.38), 0.0)
	if not is_building:
		var vec := vantage - look_pos
		var f := h * 0.5 / tan(deg_to_rad(30.0))
		vantage += vec * (absf(f) + 0.08)
		vantage.y = maxf(vantage.y + 0.20, target_pos.y + 0.34)
	return tween_camera(vantage, look_pos, duration, 58.0)


func focus_lane_zoom(is_player: bool, lane_idx: int, duration: float = 0.30, is_building: bool = false) -> Tween:
	_disable_split_duel()
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return focus_setup_board(duration)
	var sub := anchor.get_node_or_null("BuildingAnchor" if is_building else "CreatureAnchor") as Node3D
	var p := sub.global_position if sub else anchor.global_position
	# CWCommandCardSet OnClick: detailCameraOffsetX/Y = 15 * 0.05 = 0.75
	var cam_pos := p + DETAIL_CAMERA_OFFSET
	var look_pos := p + Vector3(0.0, 0.14, 0.0)
	return tween_camera(cam_pos, look_pos, duration, 56.0)


func focus_floop_action(is_player: bool, lane_idx: int, is_building: bool = false, duration: float = 0.20) -> Tween:
	_disable_split_duel()
	var anchor := get_lane_anchor(is_player, lane_idx)
	if anchor == null:
		return focus_setup_board(duration)
	var sub := anchor.get_node_or_null("BuildingAnchor" if is_building else "CreatureAnchor") as Node3D
	var p := sub.global_position if sub else anchor.global_position
	# CWFloopActionManager FloopCameraTrigger: offsetX = -0.65, offsetY = 1.00, targetOffsetY = 0.415 (0.28 for small units)
	var cam_pos := p + FLOOP_CAMERA_OFFSET
	var look_pos := p + Vector3(0.0, 0.28, 0.0)
	return tween_camera(cam_pos, look_pos, duration, 58.0)


func focus_duel_lane(lane_idx: int, _player_attacking: bool, duration: float = 0.40) -> Tween:
	_active_duel_lane_idx = clampi(lane_idx, 0, 3)
	var z := LANE_Z_CENTERS[_active_duel_lane_idx]
	# Matched to BattleScene.unity P1_Lane*BattleCamera / P2_Lane*BattleCamera relative to center & creatures
	var p1_pos := Vector3(-0.02, 0.14, z + 0.58)
	var p1_look := Vector3(PLAYER_LANE_X + CREATURE_OFFSET_X, 0.05, z)
	var p2_pos := Vector3(0.02, 0.14, z + 0.58)
	var p2_look := Vector3(OPPONENT_LANE_X - CREATURE_OFFSET_X, 0.05, z)

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
	set_heroes_card_on_table(false)
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
	_entity_meta.clear()


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
