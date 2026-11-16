extends Control
class_name CampaignMapBase

const NodeMapGraph = preload("res://src/systems/node_map_system/NodeMapGraph.gd")
const BGM_MAIN_MENU = preload("res://assets/audio/bgm/MainMenu.wav")
const SFX_CLICK = preload("res://assets/audio/sfx/Click.wav")

@onready var sub_viewport: SubViewport = $ViewportContainer/SubViewport
@onready var world_3d: Node3D = $ViewportContainer/SubViewport/World3D
@onready var map_root: Node3D = $ViewportContainer/SubViewport/World3D/MapRoot
@onready var map_art_root: Node3D = $ViewportContainer/SubViewport/World3D/MapRoot/MapArt
@onready var quest_nodes_root: Node3D = $ViewportContainer/SubViewport/World3D/MapRoot/QuestNodes
@onready var camera_3d: Camera3D = $ViewportContainer/SubViewport/World3D/Camera3D

# Top Bar HUD
@onready var player_portrait: TextureRect = $TopBar/PlayerBadge/Portrait
@onready var player_name_label: Label = $TopBar/PlayerBadge/NameLabel
@onready var player_level_label: Label = $TopBar/PlayerBadge/LevelLabel
@onready var xp_bar: ProgressBar = $TopBar/PlayerBadge/XPBar
@onready var xp_label: Label = $TopBar/PlayerBadge/XPLabel
@onready var stamina_value: Label = $TopBar/PlayerBadge/StaminaValue
@onready var stamina_status: Label = $TopBar/PlayerBadge/StaminaStatus
@onready var trophy_label: Label = $TopBar/TrophyBadge/TrophyLabel
@onready var cards_label: Label = $TopBar/Currencies/InventoryBadge/CardsLabel
@onready var gems_label: Label = $TopBar/Currencies/GemsBadge/GemsLabel
@onready var coins_label: Label = $TopBar/Currencies/CoinsBadge/CoinsLabel

# Bottom Buttons
@onready var bottom_hud: Control = $BottomHud
@onready var back_btn: TextureButton = $BottomHud/BackBtn
@onready var deck_btn: TextureButton = $BottomHud/DeckBtn

# Quest Detail Modal (F_QuestInfo)
@onready var detail_modal: Control = $QuestDetailModal
@onready var modal_close_btn: TextureButton = $QuestDetailModal/WindowCenter/CloseBtn
@onready var modal_level_label: Label = $QuestDetailModal/Panel/QuestHeader/LevelLabel if has_node("QuestDetailModal/Panel/QuestHeader/LevelLabel") else $QuestDetailModal/WindowCenter/QuestHeader/LevelLabel
@onready var modal_condition_label: Label = $QuestDetailModal/WindowCenter/QuestInfoBox/ConditionLabel
@onready var modal_star1: TextureRect = $QuestDetailModal/WindowCenter/QuestInfoBox/Star1
@onready var modal_star2: TextureRect = $QuestDetailModal/WindowCenter/QuestInfoBox/Star2
@onready var modal_star3: TextureRect = $QuestDetailModal/WindowCenter/QuestInfoBox/Star3
@onready var modal_play_btn: TextureButton = $QuestDetailModal/WindowCenter/PlayBtn
@onready var modal_card_slots: Control = $QuestDetailModal/WindowCenter/RewardDrawer/CardSlots

# Modal Player Side
@onready var modal_player_name: Label = $QuestDetailModal/WindowCenter/MainFrame/PlayerSide/PlayerNameBG/PlayerNameLabel
@onready var modal_player_portrait: TextureRect = $QuestDetailModal/WindowCenter/MainFrame/PlayerSide/PlayerPortrait
@onready var modal_player_hp: Label = $QuestDetailModal/WindowCenter/MainFrame/PlayerSide/HeroShield/PlayerHPLabel
@onready var modal_player_lvl: Label = $QuestDetailModal/WindowCenter/MainFrame/PlayerSide/PlayerLvlBG/PlayerLvlLabel
@onready var modal_player_ability: Label = $QuestDetailModal/WindowCenter/MainFrame/PlayerSide/PlayerAbilityBG/PlayerAbilityLabel
@onready var modal_leader_left_btn: TextureButton = $QuestDetailModal/WindowCenter/MainFrame/PlayerSide/LeaderLeftBtn
@onready var modal_leader_right_btn: TextureButton = $QuestDetailModal/WindowCenter/MainFrame/PlayerSide/LeaderRightBtn
@onready var modal_deck_left_btn: TextureButton = $QuestDetailModal/WindowCenter/MainFrame/PlayerSide/DeckLeftBtn
@onready var modal_deck_right_btn: TextureButton = $QuestDetailModal/WindowCenter/MainFrame/PlayerSide/DeckRightBtn
@onready var modal_deck_number_label: Label = $QuestDetailModal/WindowCenter/MainFrame/PlayerSide/DeckNumberLabel
@onready var modal_player_landscapes_row: HBoxContainer = $QuestDetailModal/WindowCenter/MainFrame/PlayerSide/LandscapesRow

# Modal Opponent Side
@onready var modal_opponent_name: Label = $QuestDetailModal/WindowCenter/MainFrame/OpponentSide/OpponentNameBG/OpponentNameLabel
@onready var modal_opponent_portrait: TextureRect = $QuestDetailModal/WindowCenter/MainFrame/OpponentSide/OpponentPortrait
@onready var modal_opponent_hp: Label = $QuestDetailModal/WindowCenter/MainFrame/OpponentSide/HeroShield/OpponentHPLabel
@onready var modal_opponent_lvl: Label = $QuestDetailModal/WindowCenter/MainFrame/OpponentSide/OpponentLvlBG/OpponentLvlLabel
@onready var modal_opponent_ability: Label = $QuestDetailModal/WindowCenter/MainFrame/OpponentSide/OpponentAbilityBG/OpponentAbilityLabel
@onready var modal_opponent_landscapes_row: HBoxContainer = $QuestDetailModal/WindowCenter/MainFrame/OpponentSide/LandscapesRow

const FONT_PATH := "res://assets/fonts/KBPlanetEarth.ttf"
const MAP_TEX_DIR := "res://assets/textures/questmap/"
const NODE_TEX_DIR := "res://assets/textures/questmap/nodes/"
const PORTRAIT_TEX_DIR := "res://assets/textures/questmap/portraits/"
const QUEST_INFO_TEX_DIR := "res://assets/textures/questmap/quest_info/"

const LANDSCAPE_ICONS: Dictionary = {
	"Corn": "UI_CornIcon.png",
	"Cotton": "UI_CottonIcon.png",
	"Plains": "UI_PlainsIcon.png",
	"Swamp": "UI_SwampIcon.png",
	"Sand": "UI_SandIcon.png"
}

const FACTION_COLORS: Dictionary = {
	"Corn": Color(1.0, 0.937, 0.424, 1.0),
	"Plains": Color(0.424, 0.804, 0.941, 1.0),
	"Cotton": Color(0.953, 0.478, 0.690, 1.0),
	"Sand": Color(0.851, 0.667, 0.522, 1.0),
	"Swamp": Color(0.404, 0.561, 0.184, 1.0),
	"Universal": Color(1.0, 1.0, 1.0, 1.0)
}

# Unity orthoSize (half-height): default 22.0, min 18.0, max 38.0
var ortho_size: float = 22.0
const MIN_ORTHO_SIZE: float = 18.0
const MAX_ORTHO_SIZE: float = 38.0

var _road_meshes: Dictionary = {}
var _hidden_paths: Dictionary = {}
var _quest_node_views: Dictionary = {}
var _player_icon_node: Node3D = null
var _player_icon_leader_mat: StandardMaterial3D = null
var _active_glow_node: MeshInstance3D = null
var _active_glow_mat: StandardMaterial3D = null
var _selected_quest_id: String = ""

var _is_dragging: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_last_mouse: Vector2 = Vector2.ZERO
var _bob_time: float = 0.0

var _modal_leader_ids: Array[String] = []
var _modal_deck_index: int = 0
var _modal_decks: Array[Dictionary] = []
var _zoom_overlay: ColorRect = null
var _zoom_card_holder: Control = null
var _zoom_tween: Tween = null


# ==============================================================================
# VIRTUAL HOOKS OVERRIDDEN BY SPECIFIC MAP SUBCLASSES
# ==============================================================================

func _get_models_dir() -> String:
	return ""


func _get_graph() -> NodeMapGraph:
	return GameManager.campaign_graph


func _get_quests_list() -> Array[Dictionary]:
	return Database.main_quests_list


func _get_regions_list() -> Array[Dictionary]:
	return Database.map_regions_list


func _get_locked_road_texture_name() -> String:
	return "QuestMap_Road_Locked"


func _get_default_quest_id() -> String:
	return "1"


func _get_active_quest_id_pref() -> String:
	return GameManager.active_quest_id


func _set_active_quest_id_pref(qid: String) -> void:
	GameManager.active_quest_id = qid


func _has_quest_node_pos(qid: String) -> bool:
	return false


func _get_quest_node_godot_xz(qid: String) -> Vector2:
	return Vector2.ZERO


func clamp_camera_pos(pos: Vector3, _ortho: float) -> Vector3:
	return Vector3(pos.x, 50.0, pos.z)


func _build_map_art() -> void:
	pass


func _on_map_enter() -> void:
	pass


# ==============================================================================
# LIFECYCLE & ANIMATIONS
# ==============================================================================

func _ready() -> void:
	if GameManager.campaign_graph == null or GameManager.fc_campaign_graph == null:
		GameManager._init_campaign()
	_on_map_enter()

	if back_btn:
		_wire_hud_button_reaction(back_btn)
		back_btn.pressed.connect(_on_back_pressed)
	if deck_btn:
		_wire_hud_button_reaction(deck_btn)
		deck_btn.pressed.connect(_on_deck_pressed)
	if modal_close_btn:
		modal_close_btn.pressed.connect(_close_quest_modal)
	if modal_play_btn:
		modal_play_btn.pressed.connect(_on_battle_pressed)
	if modal_leader_left_btn:
		modal_leader_left_btn.pressed.connect(func(): _cycle_leader(-1))
	if modal_leader_right_btn:
		modal_leader_right_btn.pressed.connect(func(): _cycle_leader(1))
	if modal_deck_left_btn:
		modal_deck_left_btn.pressed.connect(func(): _cycle_deck(-1))
	if modal_deck_right_btn:
		modal_deck_right_btn.pressed.connect(func(): _cycle_deck(1))

	if detail_modal:
		detail_modal.visible = false

	_play_map_bgm()
	_build_map_art()
	_build_quest_nodes()
	_build_player_icon()
	refresh_map_state()
	_refresh_hud()
	focus_camera_on_active_quest(22.0)

	var g = _get_graph()
	if g:
		g.node_updated.connect(func(_nid): refresh_map_state())
		g.node_completed.connect(func(_nid, _s, _f): refresh_map_state())


func on_map_opened() -> void:
	_on_map_enter()
	if detail_modal:
		detail_modal.visible = false
	if bottom_hud:
		bottom_hud.visible = true
	_play_map_bgm()
	refresh_map_state()
	_refresh_hud()
	focus_camera_on_active_quest(22.0)


func _process(delta: float) -> void:
	_bob_time += delta
	if _player_icon_node != null and _player_icon_node.visible:
		var active_qid = _get_current_quest_id()
		if _quest_node_views.has(active_qid):
			var q_node: Node3D = _quest_node_views[active_qid]["root"]
			var bob_offset = 6.35 + 0.45 * (0.5 + 0.5 * sin(_bob_time * PI * 2.5))
			# Screen-up is -Z in Godot world space
			_player_icon_node.global_position = Vector3(
				q_node.global_position.x,
				5.0,
				q_node.global_position.z - bob_offset
			)

	# Animate FX_Map_Active.prefab (FX_HexagonGlow) 1.0s expanding & fading pulse
	if _active_glow_node != null and _active_glow_node.visible:
		var t: float = fmod(_bob_time, 1.0)
		var t2: float = t * t
		var t3: float = t2 * t
		# Exact Unity cubic Hermite spline from SizeModule: key0(0, 0.2545454, slope=2) -> key1(1, 1.0, slope=0)
		var s_curve: float = (2.0 * t3 - 3.0 * t2 + 1.0) * 0.2545454 + (t3 - 2.0 * t2 + t) * 2.0 + (-2.0 * t3 + 3.0 * t2) * 1.0
		_active_glow_node.scale = Vector3(s_curve, s_curve, 1.0)
		if _active_glow_mat != null:
			# Exact Unity ColorModule alpha gradient: 0 -> 1 at t=0.19118 (12529/65535), 1 -> 0 at t=1.0
			var alpha: float = (t / 0.19118) if (t < 0.19118) else (1.0 - (t - 0.19118) / (1.0 - 0.19118))
			_active_glow_mat.albedo_color = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))


func _play_map_bgm() -> void:
	# Keep MainMenu.wav playing seamlessly; only start it if no BGM is currently active
	if Audio and BGM_MAIN_MENU:
		if Audio._active_bgm == null or not Audio._active_bgm.playing:
			Audio.play_bgm(BGM_MAIN_MENU, 0.0)


# ==============================================================================
# 3D MESH & MATERIAL HELPERS
# ==============================================================================

func _add_map_mesh(
	parent: Node3D,
	node_name: String,
	mesh_file: String,
	tex_path: String,
	unity_pos: Vector3,
	godot_quat: Quaternion,
	node_scale: Vector3,
	priority: int,
	visible_default: bool,
	transparency: BaseMaterial3D.Transparency = BaseMaterial3D.TRANSPARENCY_ALPHA,
	no_depth_test: bool = true,
	depth_draw: BaseMaterial3D.DepthDrawMode = BaseMaterial3D.DEPTH_DRAW_DISABLED
) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.name = node_name
	mi.position = Vector3(unity_pos.x, unity_pos.y, -unity_pos.z)
	mi.quaternion = godot_quat
	mi.scale = node_scale
	mi.visible = visible_default

	var full_mesh_path = _get_models_dir() + mesh_file
	if ResourceLoader.exists(full_mesh_path):
		mi.mesh = load(full_mesh_path)

	mi.material_override = _make_unlit_material(tex_path, priority, transparency, no_depth_test, depth_draw)
	parent.add_child(mi)
	return mi


func _make_unlit_material(
	tex_path: String,
	priority: int,
	transparency: BaseMaterial3D.Transparency = BaseMaterial3D.TRANSPARENCY_ALPHA,
	no_depth_test: bool = true,
	depth_draw: BaseMaterial3D.DepthDrawMode = BaseMaterial3D.DEPTH_DRAW_DISABLED
) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = transparency
	mat.depth_draw_mode = depth_draw
	mat.no_depth_test = no_depth_test
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_repeat = false
	mat.render_priority = priority
	if tex_path != "" and ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
	return mat


func _make_quad_node(node_name: String, size: Vector2, local_pos: Vector3, tex_path: String, priority: int) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.name = node_name
	var qm = QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.position = local_pos
	mi.material_override = _make_unlit_material(tex_path, priority)
	return mi


# ==============================================================================
# QUEST NODES & PLAYER PIN CONSTRUCTION
# ==============================================================================

func _build_quest_nodes() -> void:
	if quest_nodes_root == null:
		return
	for child in quest_nodes_root.get_children():
		child.queue_free()
	_quest_node_views.clear()

	# Active quest node glow (FX_Map_Active.prefab)
	_active_glow_node = _make_quad_node("ActiveGlow", Vector2(11.5, 11.5), Vector3.ZERO, MAP_TEX_DIR + "FX_Glow_ball3.png", 10)
	_active_glow_mat = _active_glow_node.material_override as StandardMaterial3D
	_active_glow_node.rotation_degrees = Vector3(-90.0, 180.0, 0.0)
	_active_glow_node.visible = false
	quest_nodes_root.add_child(_active_glow_node)

	var font_res: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null

	for q in _get_quests_list():
		var qid = str(q.get("id", ""))
		if not _has_quest_node_pos(qid):
			continue
		var xz: Vector2 = _get_quest_node_godot_xz(qid)
		var node_root = Node3D.new()
		node_root.name = "Q" + qid
		node_root.position = Vector3(xz.x, 3.0, xz.y)
		# Because MapRoot is rotated 180 around Y, rotation (-90, 180, 0) makes local +X = world +X (right) and local +Y = world -Z (screen up)
		node_root.rotation_degrees = Vector3(-90.0, 180.0, 0.0)
		quest_nodes_root.add_child(node_root)

		var prefab_type = str(q.get("node_prefab_path", ""))
		var frame_size = Vector2(4.38, 4.32)
		var unlocked_frame_tex = NODE_TEX_DIR + "QuestIconFrame_NormalQuest.png"
		var locked_frame_tex = NODE_TEX_DIR + "QuestIconFrame_UnlockedQuest.png"

		if prefab_type.ends_with("Node_Stamina"):
			frame_size = Vector2(5.88, 5.88)
			unlocked_frame_tex = NODE_TEX_DIR + "QuestIconFrame_HeartQuest.png"
			locked_frame_tex = NODE_TEX_DIR + "QuestIconFrame_HeartQuest_Unlocked.png"
		elif prefab_type.ends_with("Node_Hero"):
			frame_size = Vector2(6.66, 6.30)
			unlocked_frame_tex = NODE_TEX_DIR + "QuestIcon_HeroBattle_Unlocked.png"
			locked_frame_tex = NODE_TEX_DIR + "QuestIcon_HeroBattle.png"

		# Opponent round portrait
		var opp_id = str(q.get("opponent", ""))
		var char_info = Database.get_character(opp_id)
		var round_sprite = str(char_info.get("portrait_round", "Portrait_Jake_Round"))
		var portrait_path = PORTRAIT_TEX_DIR + round_sprite + ".png"
		if not ResourceLoader.exists(portrait_path):
			portrait_path = PORTRAIT_TEX_DIR + "Portrait_Jake_Round.png"

		var char_icon = _make_quad_node("CharIcon", Vector2(3.84, 3.84), Vector3(0.0, 0.45, 0.02), portrait_path, 11)
		node_root.add_child(char_icon)

		var frame_icon = _make_quad_node("FrameIcon", frame_size, Vector3(0.0, 0.45, 0.04), locked_frame_tex, 12)
		node_root.add_child(frame_icon)

		# Quest Label ("1", "2", "BOSS", etc.) above node
		var label_3d = Label3D.new()
		label_3d.name = "QuestLabel"
		label_3d.position = Vector3(0.0, 3.25, 0.06)
		label_3d.text = str(q.get("label", qid))
		if font_res:
			label_3d.font = font_res
		label_3d.font_size = 64
		label_3d.outline_size = 18
		label_3d.pixel_size = 0.024
		label_3d.modulate = Color(1.0, 1.0, 1.0, 1.0)
		label_3d.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
		label_3d.no_depth_test = true
		label_3d.render_priority = 15
		label_3d.outline_render_priority = 14
		node_root.add_child(label_3d)

		# 3 Stars below node
		var stars_arr: Array[MeshInstance3D] = []
		var star_offsets = [-1.392, 0.0, 1.392]
		for s_idx in range(3):
			var star_quad = _make_quad_node(
				"Star%d" % (s_idx + 1),
				Vector2(1.392, 1.392),
				Vector3(star_offsets[s_idx], -2.45, 0.05),
				NODE_TEX_DIR + "UI_Star_Empty.png",
				14
			)
			star_quad.visible = false
			node_root.add_child(star_quad)
			stars_arr.append(star_quad)

		_quest_node_views[qid] = {
			"root": node_root,
			"char_icon": char_icon,
			"frame_icon": frame_icon,
			"label": label_3d,
			"stars": stars_arr,
			"unlocked_frame_tex": unlocked_frame_tex,
			"locked_frame_tex": locked_frame_tex,
			"quest": q
		}


func _build_player_icon() -> void:
	if world_3d == null:
		return
	if _player_icon_node != null:
		_player_icon_node.queue_free()

	_player_icon_node = Node3D.new()
	_player_icon_node.name = "PlayerIcon"
	_player_icon_node.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	world_3d.add_child(_player_icon_node)

	var leader_portrait_quad = _make_quad_node(
		"LeaderSprite",
		Vector2(3.18, 3.18),
		Vector3(0.02, 1.51, 0.02),
		PORTRAIT_TEX_DIR + "Portrait_Jake_Frame.png",
		16
	)
	_player_icon_leader_mat = leader_portrait_quad.material_override as StandardMaterial3D
	_player_icon_node.add_child(leader_portrait_quad)

	var pin_frame_quad = _make_quad_node(
		"PinFrame",
		Vector2(4.053, 5.067),
		Vector3(-0.20, 0.83, 0.04),
		NODE_TEX_DIR + "uiMessageWindow.png",
		17
	)
	_player_icon_node.add_child(pin_frame_quad)


# ==============================================================================
# DYNAMIC REGION, ROAD, HIDDEN PATH & NODE STATE REFRESH
# ==============================================================================

func refresh_map_state() -> void:
	var g = _get_graph()
	if g == null:
		return

	var regions = _get_regions_list()
	var quests = _get_quests_list()
	var locked_road_tex = _get_locked_road_texture_name()

	# 1. Determine which regions are PLAYABLE (matching MapControllerBase.ValidateRegions)
	var region_playable: Dictionary = {}
	for i in range(regions.size()):
		var r_id = int(regions[i].get("MapID", str(i + 1)))
		region_playable[r_id] = (i == 0)

	for q in quests:
		var qid = str(q.get("id", ""))
		if not _has_quest_node_pos(qid):
			continue
		var r_id = int(q.get("region_id", 1))
		var nd = g.get_node(qid)
		var state = int(nd.get("state", NodeMapGraph.NodeState.LOCKED))
		if state != NodeMapGraph.NodeState.LOCKED:
			region_playable[r_id] = true

	# 2. Update Region Road Textures (Locked vs Region RoadTexture)
	for r in regions:
		var r_id = int(r.get("MapID", "1"))
		var road_mesh_name = str(r.get("RoadMesh", "")).strip_edges()
		if road_mesh_name != "" and _road_meshes.has(road_mesh_name):
			var mi: MeshInstance3D = _road_meshes[road_mesh_name]
			var mat := mi.material_override as StandardMaterial3D
			var is_open = region_playable.get(r_id, false)
			var tex_name = str(r.get("RoadTexture", locked_road_tex)).strip_edges() if is_open else locked_road_tex
			var tex_path = MAP_TEX_DIR + tex_name + ".png"
			if mat and ResourceLoader.exists(tex_path):
				mat.albedo_texture = load(tex_path)

	# 3. Update Hidden Paths based on earned stars (matching MapControllerBase.InitializeHiddenPaths)
	for hp_name in _hidden_paths.keys():
		_hidden_paths[hp_name].visible = false

	for q in quests:
		var qid = str(q.get("id", ""))
		var nd = g.get_node(qid)
		var stars = int(nd.get("stars", 0))
		if stars > 0:
			var paths_by_star: Array = q.get("unlock_paths_by_star", [])
			for s_idx in range(mini(stars, paths_by_star.size())):
				for path_name in paths_by_star[s_idx]:
					if _hidden_paths.has(path_name):
						_hidden_paths[path_name].visible = true

	# 4. Update Quest Nodes visibility, frame, portrait, label, and stars (matching MapControllerBase.UpdateQuestNode)
	var region_always_visible: Dictionary = {}
	for r in regions:
		var r_id = int(r.get("MapID", "1"))
		region_always_visible[r_id] = str(r.get("NodesAlwaysVisible", "False")).to_lower() == "true"

	var full_star_tex = load(NODE_TEX_DIR + "UI_Star_Full.png")
	var empty_star_tex = load(NODE_TEX_DIR + "UI_Star_Empty.png")

	for qid in _quest_node_views.keys():
		var view: Dictionary = _quest_node_views[qid]
		var q: Dictionary = view["quest"]
		var r_id = int(q.get("region_id", 1))
		var nd = g.get_node(qid)
		var state = int(nd.get("state", NodeMapGraph.NodeState.LOCKED))
		var stars = int(nd.get("stars", 0))

		var is_region_open = region_playable.get(r_id, false)
		var show_node = is_region_open or region_always_visible.get(r_id, false)
		var effective_playable = is_region_open and (state != NodeMapGraph.NodeState.LOCKED)

		var root_node: Node3D = view["root"]
		root_node.visible = show_node
		if not show_node:
			continue

		var char_icon: MeshInstance3D = view["char_icon"]
		var frame_icon: MeshInstance3D = view["frame_icon"]
		var label_3d: Label3D = view["label"]
		var stars_arr: Array = view["stars"]

		char_icon.visible = effective_playable
		label_3d.visible = effective_playable

		var frame_mat := frame_icon.material_override as StandardMaterial3D
		var target_frame_path = view["unlocked_frame_tex"] if effective_playable else view["locked_frame_tex"]
		if frame_mat and ResourceLoader.exists(target_frame_path):
			frame_mat.albedo_texture = load(target_frame_path)
			frame_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0) if effective_playable else Color(0.8156863, 0.5490196, 0.227451, 1.0)

		var show_stars = effective_playable and (stars > 0)
		for s_idx in range(stars_arr.size()):
			var star_quad: MeshInstance3D = stars_arr[s_idx]
			star_quad.visible = show_stars
			if show_stars:
				var smat := star_quad.material_override as StandardMaterial3D
				if smat:
					smat.albedo_texture = full_star_tex if (stars > s_idx) else empty_star_tex

	# 5. Update Active Glow & PlayerIcon position
	var active_qid = _get_current_quest_id()
	if _quest_node_views.has(active_qid):
		var active_view = _quest_node_views[active_qid]
		var active_root: Node3D = active_view["root"]
		if _active_glow_node:
			_active_glow_node.visible = true
			_active_glow_node.position = Vector3(active_root.position.x, 2.9, active_root.position.z)
		if _player_icon_node:
			_player_icon_node.visible = true
			_player_icon_node.global_position = Vector3(
				active_root.global_position.x,
				5.0,
				active_root.global_position.z - 6.5
			)


func _get_current_quest_id() -> String:
	var qid = _get_active_quest_id_pref()
	var g = _get_graph()
	if qid != "" and _quest_node_views.has(qid) and g != null:
		var nd = g.get_node(qid)
		if int(nd.get("state", 0)) != NodeMapGraph.NodeState.LOCKED:
			return qid
	return _get_default_quest_id()


# ==============================================================================
# CAMERA FOCUS, PAN & ZOOM
# ==============================================================================

func focus_camera_on_active_quest(target_ortho: float = 22.0) -> void:
	var active_qid = _get_current_quest_id()
	focus_camera_on_quest(active_qid, target_ortho)


func focus_camera_on_quest(qid: String, target_ortho: float = -1.0) -> void:
	if target_ortho > 0.0:
		ortho_size = clampf(target_ortho, MIN_ORTHO_SIZE, MAX_ORTHO_SIZE)
	if camera_3d == null:
		return
	camera_3d.size = ortho_size * 2.0
	if _quest_node_views.has(qid):
		var q_root: Node3D = _quest_node_views[qid]["root"]
		var desired = Vector3(q_root.global_position.x, 50.0, q_root.global_position.z)
		camera_3d.global_position = clamp_camera_pos(desired, ortho_size)


func set_camera_ortho_size(new_ortho: float) -> void:
	ortho_size = clampf(new_ortho, MIN_ORTHO_SIZE, MAX_ORTHO_SIZE)
	if camera_3d:
		camera_3d.size = ortho_size * 2.0
		camera_3d.global_position = clamp_camera_pos(camera_3d.global_position, ortho_size)


func _gui_input(event: InputEvent) -> void:
	if detail_modal and detail_modal.visible:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			set_camera_ortho_size(ortho_size - 2.0)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			set_camera_ortho_size(ortho_size + 2.0)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_dragging = true
				_drag_start_mouse = mb.position
				_drag_last_mouse = mb.position
			else:
				if _is_dragging:
					_is_dragging = false
					if mb.position.distance_to(_drag_start_mouse) < 8.0:
						_handle_map_tap(mb.position)
	elif event is InputEventMouseMotion and _is_dragging:
		var mm := event as InputEventMouseMotion
		var delta_px = mm.position - _drag_last_mouse
		_drag_last_mouse = mm.position
		if camera_3d != null and size.y > 0.0:
			var units_per_px = camera_3d.size / size.y
			var next_pos = camera_3d.global_position + Vector3(-delta_px.x * units_per_px, 0.0, -delta_px.y * units_per_px)
			camera_3d.global_position = clamp_camera_pos(next_pos, ortho_size)


func _handle_map_tap(screen_pos: Vector2) -> void:
	if camera_3d == null or size.y <= 0.0:
		return
	var units_per_px = camera_3d.size / size.y
	var offset_px = screen_pos - (size * 0.5)
	var tap_world_x = camera_3d.global_position.x + offset_px.x * units_per_px
	var tap_world_z = camera_3d.global_position.z + offset_px.y * units_per_px
	var tap_xz = Vector2(tap_world_x, tap_world_z)

	var best_qid: String = ""
	var best_dist: float = 3.2
	for qid in _quest_node_views.keys():
		var view: Dictionary = _quest_node_views[qid]
		var root_node: Node3D = view["root"]
		if not root_node.visible:
			continue
		# Node visual center is shifted 0.45 screen-up (-Z in world)
		var node_xz = Vector2(root_node.global_position.x, root_node.global_position.z - 0.45)
		var d = tap_xz.distance_to(node_xz)
		if d < best_dist:
			best_dist = d
			best_qid = qid

	if best_qid != "":
		var g = _get_graph()
		var nd = g.get_node(best_qid) if g != null else {}
		var state = int(nd.get("state", NodeMapGraph.NodeState.LOCKED))
		if state != NodeMapGraph.NodeState.LOCKED:
			_set_active_quest_id_pref(best_qid)
			refresh_map_state()
			_open_quest_modal(best_qid)


# ==============================================================================
# HUD & QUEST MODAL
# ==============================================================================

func _refresh_hud() -> void:
	# Keep the top-left profile badge fixed (matching MainMenu TopBar and Unity CWUpdatePlayerStats);
	# cycling battle leaders in Quest Info must never mutate the player profile name/portrait HUD.
	var profile_char_id = "Jake"
	var char_info = Database.get_character(profile_char_id)
	var display_name = str(char_info.get("name", profile_char_id))
	if display_name == "" or display_name.begins_with("!!"):
		display_name = profile_char_id

	var portrait_sprite = str(char_info.get("portrait", "Portrait_Jake_Frame"))
	var portrait_path = PORTRAIT_TEX_DIR + portrait_sprite + ".png"
	if player_portrait and ResourceLoader.exists(portrait_path):
		player_portrait.texture = load(portrait_path)
	if _player_icon_leader_mat and ResourceLoader.exists(portrait_path):
		_player_icon_leader_mat.albedo_texture = load(portrait_path)

	# Use identical TopBar stat resolution as MainMenu._update_player_stats() so HUD never changes between scenes
	var level = GameManager.player_level if "player_level" in GameManager else 1
	var xp = GameManager.player_xp if "player_xp" in GameManager else 56
	var max_xp = GameManager.xp_to_next_level if "xp_to_next_level" in GameManager else 106
	var stamina = GameManager.stamina if "stamina" in GameManager else 5
	var max_stamina = GameManager.max_stamina if "max_stamina" in GameManager else 5
	var gems = GameManager.get_gems() if GameManager.has_method("get_gems") else 50
	var coins = GameManager.get_coins() if GameManager.has_method("get_coins") else 5000

	var total_cards = GameManager.get_total_card_count() if GameManager.has_method("get_total_card_count") else 10
	var max_inventory = GameManager.get_max_inventory() if GameManager.has_method("get_max_inventory") else 50

	if player_name_label:
		player_name_label.text = display_name
	if player_level_label:
		player_level_label.text = "Lvl. %d" % level
	if xp_bar:
		xp_bar.max_value = float(max_xp)
		xp_bar.value = float(xp)
	if xp_label:
		xp_label.text = "%d/%d" % [xp, max_xp]
	if stamina_value:
		stamina_value.text = "%d/%d" % [stamina, max_stamina]
	if stamina_status:
		stamina_status.text = "Full" if stamina >= max_stamina else "04:30"
	if trophy_label:
		trophy_label.text = "0"
	if cards_label:
		cards_label.text = "%d/%d" % [total_cards, max_inventory]
	if gems_label:
		gems_label.text = "%d" % gems
	if coins_label:
		coins_label.text = "%d" % coins


func _unhandled_input(event: InputEvent) -> void:
	if detail_modal and detail_modal.visible and event.is_action_pressed("ui_cancel"):
		if _zoom_overlay != null and _zoom_overlay.visible:
			_close_zoom_card()
		else:
			_close_quest_modal()
		get_viewport().set_input_as_handled()


func _open_quest_modal(quest_id: String) -> void:
	_close_zoom_card(true)
	_selected_quest_id = quest_id
	var quest = Database.get_quest(quest_id)
	if quest.is_empty() or detail_modal == null:
		return

	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)

	var g = _get_graph()
	var nd = g.get_node(quest_id) if g != null else {}
	var stars = int(nd.get("stars", 0))

	# Top banner: "Level 1" (or "BOSS")
	var qlabel = str(quest.get("label", quest_id))
	if modal_level_label:
		modal_level_label.text = qlabel if qlabel.to_upper() == "BOSS" else ("Level " + qlabel)

	# Condition box + 3 stars
	var cond_ids: Array = quest.get("condition_ids", [])
	if modal_condition_label:
		if stars >= 3:
			modal_condition_label.text = "All three stars earned!"
		elif stars < cond_ids.size():
			modal_condition_label.text = Database.get_condition_description(str(cond_ids[stars]))
		elif not cond_ids.is_empty():
			modal_condition_label.text = Database.get_condition_description(str(cond_ids[0]))
		else:
			modal_condition_label.text = "Beat your opponent to win a star!"

	var full_star_tex = load(NODE_TEX_DIR + "UI_Star_Full.png")
	var empty_star_tex = load(NODE_TEX_DIR + "UI_Star_Empty.png")
	if modal_star1:
		modal_star1.texture = full_star_tex if stars >= 1 else empty_star_tex
	if modal_star2:
		modal_star2.texture = full_star_tex if stars >= 2 else empty_star_tex
	if modal_star3:
		modal_star3.texture = full_star_tex if stars >= 3 else empty_star_tex

	# Player side (Leader + Deck)
	_modal_leader_ids = GameManager.get_valid_leaders_for_quest(quest_id)
	var cur_char = GameManager.get_leader_character_id(GameManager.player_hero_name)
	if not _modal_leader_ids.is_empty():
		if not _modal_leader_ids.has(cur_char):
			GameManager.player_hero_name = _modal_leader_ids[0]
			GameManager._update_active_hero_hp()
		else:
			GameManager.player_hero_name = cur_char
	var show_leader_arrows: bool = _modal_leader_ids.size() > 1
	if modal_leader_left_btn:
		modal_leader_left_btn.visible = show_leader_arrows
	if modal_leader_right_btn:
		modal_leader_right_btn.visible = show_leader_arrows

	_load_available_decks()
	_refresh_modal_player_side()

	# Opponent side
	var opp_id = str(quest.get("opponent", "BerryBones"))
	var opp_leader_id = str(quest.get("leader_id", "Leader_" + opp_id))
	var opp_leader = Database.get_leader(opp_leader_id)
	if opp_leader.is_empty():
		opp_leader = Database.get_leader(opp_id)
	var char_info = Database.get_character(opp_id)

	var opp_name = str(opp_leader.get("name", char_info.get("name", opp_id)))
	if opp_name == "" or opp_name.begins_with("!!"):
		opp_name = opp_id

	var opp_lvl = int(quest.get("leader_level", 1))
	var opp_base_hp = int(opp_leader.get("base_hp", 10))
	var opp_hp = opp_base_hp + (opp_lvl * 5)
	var opp_ability = str(opp_leader.get("desc", ""))

	var hero_sprite = str(opp_leader.get("sprite_name_hero", char_info.get("portrait_hero", "Portrait_BerryBones_Hero")))
	var hero_path = PORTRAIT_TEX_DIR + hero_sprite + ".png"
	if not ResourceLoader.exists(hero_path):
		hero_path = PORTRAIT_TEX_DIR + str(char_info.get("portrait_round", "Portrait_BerryBones_Round")) + ".png"
	if modal_opponent_portrait and ResourceLoader.exists(hero_path):
		modal_opponent_portrait.texture = load(hero_path)

	if modal_opponent_name:
		modal_opponent_name.text = opp_name
	if modal_opponent_hp:
		modal_opponent_hp.text = str(opp_hp)
	if modal_opponent_lvl:
		modal_opponent_lvl.text = "Lvl %d" % opp_lvl
	if modal_opponent_ability:
		modal_opponent_ability.text = opp_ability

	var opp_deck_id = str(quest.get("deck_id", ""))
	var opp_lands = Database.get_preset_deck_landscapes(opp_deck_id)
	_set_landscape_icons(modal_opponent_landscapes_row, opp_lands)

	# Reward drawer cards (sorted by rarity descending, max 4)
	_populate_reward_cards(quest.get("card_drops", []))

	# Hide bottom map buttons while modal is open (matching CWMapQuestInfo.OnTweenEnableForward)
	if bottom_hud:
		bottom_hud.visible = false
	detail_modal.visible = true


func _close_quest_modal() -> void:
	_close_zoom_card(true)
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)
	if detail_modal:
		detail_modal.visible = false
	if bottom_hud:
		bottom_hud.visible = true


func _load_available_decks() -> void:
	_modal_decks.clear()
	var saved_decks: Array[Dictionary] = []
	var dir = DirAccess.open("user://decks")
	if dir != null:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".json"):
				var f = FileAccess.open("user://decks/" + fname, FileAccess.READ)
				if f != null:
					var j = JSON.new()
					if j.parse(f.get_as_text()) == OK and typeof(j.data) == TYPE_DICTIONARY:
						saved_decks.append(j.data)
			fname = dir.get_next()
		dir.list_dir_end()

	if not saved_decks.is_empty():
		var idx = 1
		for d in saved_decks:
			_modal_decks.append({
				"name": str(d.get("name", "Deck %d" % idx)),
				"label": "Deck %d" % idx,
				"cards": d.get("cards", []),
				"landscapes": d.get("landscapes", ["Plains", "Plains", "Cotton", "Plains"])
			})
			idx += 1
	else:
		_modal_decks.append({
			"name": "Jake Starter Deck",
			"label": "Deck 1",
			"cards": GameManager.player_deck.duplicate(),
			"landscapes": ["Corn", "Corn", "Corn", "Swamp"]
		})

	_modal_deck_index = 0
	for i in range(_modal_decks.size()):
		if str(_modal_decks[i].get("name", "")) == GameManager.active_deck_name:
			_modal_deck_index = i
			break


func _refresh_modal_player_side() -> void:
	var hero_id = GameManager.player_hero_name
	if hero_id == "":
		hero_id = "Jake"
	elif hero_id == "Fionna":
		hero_id = "Fiona"
		GameManager.player_hero_name = hero_id
	var leader_info = Database.get_leader(hero_id)
	var char_info = Database.get_character(hero_id)

	var display_name = str(leader_info.get("name", char_info.get("name", hero_id)))
	if display_name == "" or display_name.begins_with("!!"):
		display_name = hero_id

	var lvl = GameManager.get_hero_level(hero_id)
	var hp = GameManager.get_hero_max_hp(hero_id)
	var ability = str(leader_info.get("desc", ""))

	var hero_sprite = str(leader_info.get("sprite_name_hero", char_info.get("portrait_hero", "Portrait_Jake_Hero")))
	var hero_path = PORTRAIT_TEX_DIR + hero_sprite + ".png"
	if not ResourceLoader.exists(hero_path):
		hero_path = PORTRAIT_TEX_DIR + "Portrait_Jake_Hero.png"

	if modal_player_name:
		modal_player_name.text = display_name
	if modal_player_portrait and ResourceLoader.exists(hero_path):
		modal_player_portrait.texture = load(hero_path)
	if modal_player_hp:
		modal_player_hp.text = str(hp)
	if modal_player_lvl:
		modal_player_lvl.text = "Lvl %d" % lvl
	if modal_player_ability:
		modal_player_ability.text = ability

	_set_landscape_icons(modal_player_landscapes_row, GameManager.player_landscapes)
	if modal_deck_number_label:
		if _modal_deck_index >= 0 and _modal_deck_index < _modal_decks.size():
			modal_deck_number_label.text = str(_modal_decks[_modal_deck_index].get("label", "Deck 1"))
		else:
			modal_deck_number_label.text = "Deck 1"


func _cycle_leader(delta: int) -> void:
	if _modal_leader_ids.size() <= 1:
		return
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)
	var cur = GameManager.get_leader_character_id(GameManager.player_hero_name)
	var idx = _modal_leader_ids.find(cur)
	if idx < 0:
		idx = 0
	idx = (idx + delta + _modal_leader_ids.size()) % _modal_leader_ids.size()
	GameManager.player_hero_name = _modal_leader_ids[idx]
	GameManager._update_active_hero_hp()
	_refresh_modal_player_side()


func _cycle_deck(delta: int) -> void:
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)
	if _modal_decks.is_empty():
		return
	_modal_deck_index = (_modal_deck_index + delta + _modal_decks.size()) % _modal_decks.size()
	var d = _modal_decks[_modal_deck_index]
	var cards_arr: Array[String] = []
	for c in d.get("cards", []):
		cards_arr.append(str(c))
	if not cards_arr.is_empty():
		GameManager.player_deck = cards_arr
	var lands_arr: Array[String] = []
	for l in d.get("landscapes", []):
		lands_arr.append(str(l))
	if not lands_arr.is_empty():
		GameManager.player_landscapes = lands_arr
	GameManager.active_deck_name = str(d.get("name", "Deck 1"))
	_refresh_modal_player_side()


func _set_landscape_icons(row: HBoxContainer, landscapes: Array) -> void:
	if row == null:
		return
	var children = row.get_children()
	for i in range(children.size()):
		var icon_rect := children[i] as TextureRect
		if icon_rect == null:
			continue
		if i < landscapes.size():
			var land_name = str(landscapes[i]).strip_edges()
			var icon_file = str(LANDSCAPE_ICONS.get(land_name, "UI_CornIcon.png"))
			var icon_path = QUEST_INFO_TEX_DIR + icon_file
			if ResourceLoader.exists(icon_path):
				icon_rect.texture = load(icon_path)
			icon_rect.visible = true
		else:
			icon_rect.visible = false


func _make_card_label(font_res: Font, font_sz: int, pos: Vector2, sz: Vector2, txt: String, col: Color = Color.BLACK, center_v: bool = true) -> Label:
	var lbl := Label.new()
	if font_res:
		lbl.add_theme_font_override("font", font_res)
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	var adj_y := pos.y
	if center_v and font_res:
		adj_y = pos.y + (sz.y - font_res.get_height(font_sz)) * 0.5
	lbl.position = Vector2(pos.x, adj_y)
	lbl.size = sz
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _unity_qsort_cards_by_rarity(arr: Array[Dictionary], low: int, high: int) -> void:
	if low >= high:
		return
	var pivot := int(arr[(low + high) / 2].get("rarity", 1))
	var i := low
	var j := high
	while i <= j:
		while int(arr[i].get("rarity", 1)) > pivot:
			i += 1
		while int(arr[j].get("rarity", 1)) < pivot:
			j -= 1
		if i <= j:
			var tmp := arr[i]
			arr[i] = arr[j]
			arr[j] = tmp
			i += 1
			j -= 1
	if low < j:
		_unity_qsort_cards_by_rarity(arr, low, j)
	if i < high:
		_unity_qsort_cards_by_rarity(arr, i, high)


func _populate_reward_cards(drops_arr: Array) -> void:
	if modal_card_slots == null:
		return
	for ch in modal_card_slots.get_children():
		ch.queue_free()

	# Gather card dicts and sort by rarity descending using Unity Mono List.Sort order (CWMapQuestInfo.cs)
	var cards: Array[Dictionary] = []
	for cid in drops_arr:
		var cdata = Database.get_card(str(cid))
		if not cdata.is_empty():
			cards.append(cdata)
	if cards.size() > 1:
		_unity_qsort_cards_by_rarity(cards, 0, cards.size() - 1)

	var card_w := 90.0
	var card_h := 127.0
	var step_y := 77.0
	var count = mini(4, cards.size())
	for i in range(count):
		var c = cards[i]
		var slot := Control.new()
		slot.position = Vector2(0.0, float(i) * step_y)
		slot.size = Vector2(card_w, card_h)
		slot.z_index = i + 1
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_open_zoom_card(c, slot)
		)
		modal_card_slots.add_child(slot)
		_build_card_visual(slot, c, card_w, card_h, false)


func _build_card_visual(slot: Control, c: Dictionary, card_w: float, card_h: float, is_zoomed: bool) -> void:
	var font_res: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	var sx := card_w / 297.0
	var sy := card_h / 420.0
	var ui_scale := card_w / 90.0

	var faction = str(c.get("faction", "Universal"))
	var rarity = int(c.get("rarity", 1))
	var ctype = str(c.get("type", "CREATURE"))
	var quality_name = str(c.get("quality_name", "Standard"))
	var faction_col: Color = FACTION_COLORS.get(faction, Color.WHITE)
	# Unity PanelManagerBattle.FillCardInfo: BG_Name / BG_Type / Frame_ATK / Frame_DEF use Lerp(factionColor, white, 0.5f)
	var bg_tint: Color = faction_col.lerp(Color.WHITE, 0.5)

	# Card Art (d=-8 in 297x420; zoomed uses slightly wider 285x285 bounds per B_2_ZoomCard)
	var art_tex = Database.get_card_texture(str(c.get("texture_path", "")))
	var art := TextureRect.new()
	if is_zoomed:
		art.position = Vector2(6.0 * sx, 3.2 * sy)
		art.size = Vector2(285.0 * sx, 285.0 * sy)
	else:
		art.position = Vector2(11.0 * sx, 7.5 * sy)
		art.size = Vector2(275.0 * sx, 275.0 * sy)
	art.texture = art_tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(art)

	# Opaque backing for card Type header (d=-5 BG_Type: center=(0,179), size=(280,24))
	var bg_type := ColorRect.new()
	bg_type.position = Vector2(8.5 * sx, 19.0 * sy)
	bg_type.size = Vector2(280.0 * sx, 24.0 * sy)
	bg_type.color = bg_tint
	bg_type.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg_type)

	# Opaque backing for card Name strip (d=-5 BG_Name: center=(0,-59), size=(280,30))
	var bg_name := ColorRect.new()
	bg_name.position = Vector2(8.5 * sx, 254.0 * sy)
	bg_name.size = Vector2(280.0 * sx, 30.0 * sy)
	bg_name.color = bg_tint
	bg_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg_name)

	# Cost Orb (d=-2 behind Card_Frame: center=(-100,165), size=(60,60))
	var cost_bg := TextureRect.new()
	cost_bg.position = Vector2(18.5 * sx, 15.0 * sy)
	cost_bg.size = Vector2(60.0 * sx, 60.0 * sy)
	cost_bg.texture = load(QUEST_INFO_TEX_DIR + "Frame_Cost.png")
	cost_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cost_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cost_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cost_bg)

	# Card Frame (d=0)
	var frame_file = "Frame_Colorless.png" if faction == "Universal" else "Frame_White.png"
	var frame := TextureRect.new()
	frame.position = Vector2.ZERO
	frame.size = Vector2(card_w, card_h)
	frame.texture = load(QUEST_INFO_TEX_DIR + frame_file)
	frame.modulate = faction_col
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(frame)

	# Gold Frame overlay ONLY when card Quality is Gold (CardForm.GetCardQualityFrameSprite)
	if quality_name == "Gold":
		var gold := TextureRect.new()
		gold.position = Vector2.ZERO
		gold.size = Vector2(card_w, card_h)
		gold.texture = load(QUEST_INFO_TEX_DIR + "Frame_Gold.png")
		gold.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gold.stretch_mode = TextureRect.STRETCH_SCALE
		gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(gold)

	# Faction Icon (d=10 top-right circle: center=(118,179), size=(30,30))
	if LANDSCAPE_ICONS.has(faction):
		var fact_icon := TextureRect.new()
		fact_icon.position = Vector2(251.5 * sx, 16.0 * sy)
		fact_icon.size = Vector2(30.0 * sx, 30.0 * sy)
		fact_icon.texture = load(QUEST_INFO_TEX_DIR + str(LANDSCAPE_ICONS[faction]))
		fact_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fact_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fact_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(fact_icon)

	# Rarity Stars: bottom-right of Card_Art on mini cards (DeckCard), bottom-center on zoomed card (B_2_ZoomCard)
	var full_star = load(NODE_TEX_DIR + "UI_Star_Full.png")
	var clamped_rarity := mini(5, rarity)
	if is_zoomed:
		var zstar_ngui := 14.0
		var zstar_px := zstar_ngui * sx
		for s in range(clamped_rarity):
			var st := TextureRect.new()
			var nx := (float(s) - float(clamped_rarity - 1) * 0.5) * zstar_ngui
			st.position = Vector2((nx - zstar_ngui * 0.5 + 148.5) * sx, (210.0 - (-185.0) - zstar_ngui * 0.5) * sy)
			st.size = Vector2(zstar_px, zstar_px)
			st.texture = full_star
			st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			st.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(st)
	else:
		var star_offsets: Array[Vector2] = [
			Vector2(0.0, 0.0),
			Vector2(-1.0, 0.0),
			Vector2(-2.0, 0.0),
			Vector2(-0.35, 0.97),
			Vector2(-1.41, 0.97)
		]
		var star_px := 36.1 * sx
		for s in range(clamped_rarity):
			var st := TextureRect.new()
			var npos := Vector2(111.0, -20.0) + star_offsets[s] * 36.1
			st.position = Vector2((npos.x - 18.05 + 148.5) * sx, (210.0 - npos.y - 18.05) * sy)
			st.size = Vector2(star_px, star_px)
			st.texture = full_star
			st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			st.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(st)

	# Cost Label (centered in Cost Orb: center=(-102,162))
	var cost_lbl := _make_card_label(font_res, roundi(10.0 * ui_scale), Vector2(18.5 * sx, 16.0 * sy), Vector2(56.0 * sx, 58.0 * sy), str(int(c.get("cost", 1))), Color(0.976, 0.831, 1.0, 1.0))
	cost_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	cost_lbl.add_theme_constant_override("outline_size", roundi(2.0 * ui_scale))
	slot.add_child(cost_lbl)

	# Type Label (centered inside BG_Type band: y=19..43 in 297x420)
	var type_lbl := _make_card_label(font_res, roundi(6.0 * ui_scale), Vector2(72.0 * sx, 19.0 * sy), Vector2(174.0 * sx, 24.0 * sy), ctype.capitalize())
	slot.add_child(type_lbl)

	# Name Label (inside BG_Name strip: y=254..284)
	var name_lbl := _make_card_label(font_res, roundi(7.0 * ui_scale), Vector2(12.0 * sx, 254.0 * sy), Vector2(273.0 * sx, 30.0 * sy), str(c.get("name", "")))
	name_lbl.clip_text = true
	slot.add_child(name_lbl)

	# Ability Text Block (FLOOP cost header + Description combined cleanly so lines never overlap)
	var ability_type = str(c.get("ability_type", ""))
	var floop_cost = int(c.get("floop_cost", 0))
	var full_desc := str(c.get("desc", ""))
	if ability_type == "FLOOP":
		full_desc = "FLOOP (%d Magic)\n%s" % [floop_cost, full_desc]

	var desc_top := 294.0 if is_zoomed else 285.0
	var desc_lbl := _make_card_label(font_res, roundi(5.0 * ui_scale), Vector2(16.0 * sx, desc_top * sy), Vector2(265.0 * sx, (92.0 if ctype == "CREATURE" else 106.0) * sy), full_desc, Color.BLACK, false)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.clip_text = true
	desc_lbl.add_theme_constant_override("line_spacing", 2 if is_zoomed else 0)
	slot.add_child(desc_lbl)

	# ATK / DEF badges & values for Creatures (Frame_Combat + Combat_Icon_ATK/DEF)
	if ctype == "CREATURE":
		var combat_tex = load(QUEST_INFO_TEX_DIR + "Frame_Combat.png")
		var atk_bg := TextureRect.new()
		atk_bg.position = Vector2(11.0 * sx, 359.0 * sy)
		atk_bg.size = Vector2(75.0 * sx, 50.0 * sy)
		atk_bg.texture = combat_tex
		atk_bg.modulate = bg_tint
		atk_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		atk_bg.stretch_mode = TextureRect.STRETCH_SCALE
		atk_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(atk_bg)

		var def_bg := TextureRect.new()
		def_bg.position = Vector2(210.5 * sx, 359.0 * sy)
		def_bg.size = Vector2(76.0 * sx, 50.0 * sy)
		def_bg.texture = combat_tex
		def_bg.modulate = bg_tint
		def_bg.flip_h = true
		def_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		def_bg.stretch_mode = TextureRect.STRETCH_SCALE
		def_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(def_bg)

		var atk_lbl := _make_card_label(font_res, roundi(7.0 * ui_scale), Vector2(16.0 * sx, 362.0 * sy), Vector2(32.0 * sx, 46.0 * sy), str(int(c.get("atk", 0))))
		slot.add_child(atk_lbl)

		var atk_icon := TextureRect.new()
		atk_icon.position = Vector2(49.0 * sx, 370.0 * sy)
		atk_icon.size = Vector2(16.6 * sx, 29.7 * sy)
		atk_icon.texture = load(QUEST_INFO_TEX_DIR + "Combat_Icon_ATK.png")
		atk_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		atk_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		atk_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(atk_icon)

		var def_icon := TextureRect.new()
		def_icon.position = Vector2(226.0 * sx, 373.5 * sy)
		def_icon.size = Vector2(19.6 * sx, 22.6 * sy)
		def_icon.texture = load(QUEST_INFO_TEX_DIR + "Combat_Icon_DEF.png")
		def_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		def_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		def_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(def_icon)

		var def_lbl := _make_card_label(font_res, roundi(7.0 * ui_scale), Vector2(246.0 * sx, 362.0 * sy), Vector2(32.0 * sx, 46.0 * sy), str(int(c.get("def", 0))))
		slot.add_child(def_lbl)


func _ensure_zoom_nodes() -> void:
	if detail_modal == null:
		return
	var window_center: Control = detail_modal.get_node_or_null("WindowCenter")
	if _zoom_overlay == null:
		_zoom_overlay = ColorRect.new()
		_zoom_overlay.name = "ZoomBlackPanel"
		_zoom_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_zoom_overlay.color = Color(0.0, 0.0, 0.0, 0.503)
		_zoom_overlay.z_index = 8
		_zoom_overlay.visible = false
		_zoom_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		_zoom_overlay.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_close_zoom_card()
		)
		detail_modal.add_child(_zoom_overlay)

	if _zoom_card_holder == null and window_center != null:
		_zoom_card_holder = Control.new()
		_zoom_card_holder.name = "ZoomCard"
		# Unity B_2_ZoomCard (pos=(875,-50), scl=1.5) mapped to WindowCenter 0.488 scale: center=(834, 259), size=218x308
		_zoom_card_holder.size = Vector2(218.0, 308.0)
		_zoom_card_holder.pivot_offset = Vector2(109.0, 154.0)
		_zoom_card_holder.position = Vector2(725.0, 105.0)
		_zoom_card_holder.z_index = 9
		_zoom_card_holder.visible = false
		_zoom_card_holder.mouse_filter = Control.MOUSE_FILTER_STOP
		_zoom_card_holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_zoom_card_holder.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_close_zoom_card()
		)
		window_center.add_child(_zoom_card_holder)


func _open_zoom_card(card_data: Dictionary, source_slot: Control = null) -> void:
	_ensure_zoom_nodes()
	if _zoom_overlay == null or _zoom_card_holder == null:
		return
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	for ch in _zoom_card_holder.get_children():
		ch.queue_free()

	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)

	var zoom_w := 218.0
	var zoom_h := 308.0
	_build_card_visual(_zoom_card_holder, card_data, zoom_w, zoom_h, true)

	var target_pos := Vector2(725.0, 105.0)
	_zoom_overlay.visible = true
	_zoom_overlay.modulate.a = 0.0
	_zoom_card_holder.visible = true

	if source_slot != null and is_instance_valid(source_slot):
		var window_center: Control = detail_modal.get_node_or_null("WindowCenter")
		var src_center := source_slot.global_position + source_slot.size * 0.5
		var wc_origin := window_center.global_position if window_center else Vector2.ZERO
		_zoom_card_holder.position = (src_center - wc_origin) - _zoom_card_holder.pivot_offset
		_zoom_card_holder.scale = Vector2(source_slot.size.x / zoom_w, source_slot.size.y / zoom_h)
	else:
		_zoom_card_holder.position = target_pos
		_zoom_card_holder.scale = Vector2(0.8, 0.8)

	_zoom_tween = create_tween().set_parallel(true)
	_zoom_tween.tween_property(_zoom_overlay, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(_zoom_card_holder, "position", target_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(_zoom_card_holder, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _close_zoom_card(immediate: bool = false) -> void:
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	if _zoom_overlay == null and _zoom_card_holder == null:
		return
	if immediate:
		if _zoom_overlay:
			_zoom_overlay.visible = false
		if _zoom_card_holder:
			_zoom_card_holder.visible = false
			for ch in _zoom_card_holder.get_children():
				ch.queue_free()
		return
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)
	_zoom_tween = create_tween().set_parallel(true)
	if _zoom_overlay:
		_zoom_tween.tween_property(_zoom_overlay, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _zoom_card_holder:
		_zoom_tween.tween_property(_zoom_card_holder, "scale", Vector2(0.85, 0.85), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_zoom_tween.chain().tween_callback(func():
		if _zoom_overlay:
			_zoom_overlay.visible = false
		if _zoom_card_holder:
			_zoom_card_holder.visible = false
			for ch in _zoom_card_holder.get_children():
				ch.queue_free()
	)


func _on_battle_pressed() -> void:
	if _selected_quest_id == "":
		return
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)
	_close_quest_modal()
	GameManager.launch_quest_battle(_selected_quest_id)


func _wire_hud_button_reaction(btn: TextureButton) -> void:
	if not btn:
		return
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(0.8, 0.8), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "modulate", Color(0.5, 0.5, 0.5, 1.0), 0.05)
	)
	btn.button_up.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "modulate", Color.WHITE, 0.05)
	)


func _on_back_pressed() -> void:
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)
	GameManager.return_to_menu()


func _on_deck_pressed() -> void:
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)
	if deck_btn:
		deck_btn.disabled = true
		await get_tree().create_timer(0.06).timeout
		deck_btn.scale = Vector2.ONE
		deck_btn.modulate = Color.WHITE
		deck_btn.disabled = false
	GameManager.open_deck_menu()
