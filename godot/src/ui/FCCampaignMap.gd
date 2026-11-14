extends Control

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
@onready var detail_modal: ColorRect = $QuestDetailModal
@onready var modal_close_btn: TextureButton = $QuestDetailModal/WindowCenter/CloseBtn
@onready var modal_level_label: Label = $QuestDetailModal/WindowCenter/QuestHeader/LevelLabel
@onready var modal_condition_label: Label = $QuestDetailModal/WindowCenter/QuestInfoBox/ConditionLabel
@onready var modal_star1: TextureRect = $QuestDetailModal/WindowCenter/QuestInfoBox/Star1
@onready var modal_star2: TextureRect = $QuestDetailModal/WindowCenter/QuestInfoBox/Star2
@onready var modal_star3: TextureRect = $QuestDetailModal/WindowCenter/QuestInfoBox/Star3
@onready var modal_play_btn: TextureButton = $QuestDetailModal/WindowCenter/PlayBtn
@onready var modal_stamina_cost_label: Label = $QuestDetailModal/WindowCenter/PlayBtn/StaminaCostLabel
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
const MODELS_DIR := "res://assets/models/fc_map/"
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

# Exact Unity node coordinates inside MapRoot/QuestNodes/FCQuestMap*_Nodes (where parent z = -0.036)
const FC_QUEST_NODE_POSITIONS: Dictionary = {
	"5001": Vector2(71.57, 39.38),
	"5002": Vector2(73.53, 29.34),
	"5003": Vector2(34.27, 36.18),
	"5004": Vector2(51.3, 17.86),
	"5005": Vector2(25.0, 13.45),
	"5006": Vector2(24.7, 25.43),
	"5007": Vector2(9.2, 9.69),
	"5008": Vector2(9.89, -10.11),
	"5009": Vector2(25.5, 3.74),
	"5010": Vector2(8.3, -17.99),
	"5011": Vector2(55.2, -17.51),
	"5012": Vector2(73.13, -22.73),
	"5013": Vector2(72.82, -37.6),
	"5014": Vector2(48.0, 1.34),
	"5015": Vector2(21.67, -24.57),
	"5016": Vector2(34.0, -27.74),
	"5017": Vector2(33.68, -37.55),
	"5018": Vector2(52.28, -39.94),
	"5019": Vector2(10.82, -40.28),
	"5020": Vector2(-15.2, -31.3),
	"5021": Vector2(-34.3, -20.46),
	"5022": Vector2(-50.92, -11.88),
	"5023": Vector2(-62.34, -21.35),
	"5024": Vector2(-76.82, -19.63),
	"5025": Vector2(-38.3, -40.2),
	"5026": Vector2(-59.2, -39.1),
	"5027": Vector2(-76.8, -38.9),
	"5028": Vector2(-77.1, -4.3),
	"5029": Vector2(-75.3, 12.7),
	"5030": Vector2(-60.1, -1.5),
	"5031": Vector2(-60.6, 10.6),
	"5032": Vector2(-46.1, 10.1),
	"5033": Vector2(-26.0, 10.6),
	"5034": Vector2(-43.1, 23.9),
	"5035": Vector2(-64.4, 24.6),
	"5036": Vector2(-36.4, -0.6),
	"5037": Vector2(-12.5, 10.3),
	"5038": Vector2(-19.9, 25.8),
	"5039": Vector2(-38.1, 34.7),
	"5040": Vector2(-54.5, 39.1),
	"5041": Vector2(43.01, 42.74),
	"5042": Vector2(-39.47, -6.59),
	"5043": Vector2(-60.46, 32.6),
	"5044": Vector2(124.0, 38.0),
	"5045": Vector2(138.5, 31.5),
	"5046": Vector2(110.9, 29.5),
	"5047": Vector2(150.3, 21.8),
	"5048": Vector2(101.8, 18.1),
	"5049": Vector2(156.8, 10.8),
	"5050": Vector2(97.0, 6.2),
	"5051": Vector2(157.0, -3.0),
	"5052": Vector2(98.3, -6.3),
	"5053": Vector2(147.0, -11.1),
	"5054": Vector2(108.1, -13.8),
	"5055": Vector2(136.3, -9.3),
	"5056": Vector2(120.6, -10.3),
	"5057": Vector2(127.9, -3.2),
	"5058": Vector2(127.2, 4.8),
	"5059": Vector2(140.5, -0.1),
	"5060": Vector2(110.9, 5.6),
	"5061": Vector2(108.5, 16.0)
}

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


func _ready() -> void:
	if GameManager.campaign_graph == null or GameManager.fc_campaign_graph == null:
		GameManager._init_campaign()

	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if deck_btn:
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

	_play_fc_map_bgm()
	_build_map_art()
	_build_quest_nodes()
	_build_player_icon()
	refresh_map_state()
	_refresh_hud()
	focus_camera_on_active_quest(22.0)

	if GameManager.fc_campaign_graph:
		GameManager.fc_campaign_graph.node_updated.connect(func(_nid): refresh_map_state())
		GameManager.fc_campaign_graph.node_completed.connect(func(_nid, _s, _f): refresh_map_state())


func on_map_opened() -> void:
	if detail_modal:
		detail_modal.visible = false
	_play_fc_map_bgm()
	refresh_map_state()
	_refresh_hud()
	focus_camera_on_active_quest(22.0)


func _process(delta: float) -> void:
	_bob_time += delta
	if _player_icon_node != null and _player_icon_node.visible:
		var active_qid = _get_current_fc_quest_id()
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


func _play_fc_map_bgm() -> void:
	# Keep MainMenu.wav playing seamlessly; only start it if no BGM is currently active
	if Audio and BGM_MAIN_MENU:
		if Audio._active_bgm == null or not Audio._active_bgm.playing:
			Audio.play_bgm(BGM_MAIN_MENU, 0.0)


# ==============================================================================
# 3D MAP ART CONSTRUCTION (Exact QuestMap_FC.prefab hierarchy & transforms)
# ==============================================================================

func _build_map_art() -> void:
	if map_root == null or map_art_root == null:
		return
	# MapRoot has Unity rotation (0, 1, 0, -1.629207e-07) -> 180 deg around Y
	map_root.position = Vector3.ZERO
	map_root.quaternion = Quaternion(0.0, -1.0, 0.0, -1.629207e-07)
	map_root.scale = Vector3.ONE

	for child in map_art_root.get_children():
		child.queue_free()

	_road_meshes.clear()
	_hidden_paths.clear()

	# 0. Green Valentine Background
	_add_map_mesh(
		map_art_root,
		"FcQuestMap_ValentineBackground",
		"FcQuestMap_ValentineBackground.obj",
		MAP_TEX_DIR + "FcQuestMap_ValentineBackground.png",
		Vector3(144.08, 0.0, 1.660047),
		Quaternion(-1.152023e-07, 0.7071068, -0.7071068, -1.152023e-07),
		Vector3(99.99998, 100.0, 1.0),
		0,
		true
	)

	# 1. Main Fionna & Cake Open Notebook
	_add_map_mesh(
		map_art_root,
		"FcQuestMap",
		"FcQuestMap.obj",
		MAP_TEX_DIR + "FcQuestMap.png",
		Vector3(-0.5, 0.0, 2.2),
		Quaternion(0.7071068, 0.0, 0.0, 0.7071067),
		Vector3(1.089374, 1.0, 1.0),
		1,
		true
	)

	# 2. Environment Atlases 01, 02, 03 (Notebook Region Banners, Tree, Ham, Mountains, Ice Fionna & Cake)
	_add_atlas_group(
		map_art_root,
		"FcQuestMap_Atlas01",
		"FcQuestMap_Atlas01.obj",
		MAP_TEX_DIR + "FcQuestMap_Atlas01.png",
		Vector3(0.0, 0.0, 80.98454),
		Vector3(26.46923, 113.8213, 0.2808438),
		2
	)
	_add_atlas_group(
		map_art_root,
		"FcQuestMap_Atlas02",
		"FcQuestMap_Atlas02.obj",
		MAP_TEX_DIR + "FcQuestMap_Atlas02.png",
		Vector3(0.0, 0.0, 80.98454),
		Vector3(-61.25297, 48.88206, 0.2808438),
		2
	)
	_add_atlas_group(
		map_art_root,
		"FcQuestMap_Atlas03",
		"FcQuestMap_Atlas03.obj",
		MAP_TEX_DIR + "FcQuestMap_Atlas03.png",
		Vector3(0.0, 0.0, 80.98454),
		Vector3(-49.4117, 63.02619, 0.2808438),
		2
	)

	# 3. Main Roads (FCQuestMapA..G_Road)
	var rot_neg90x = Quaternion(0.7071068, 0.0, 0.0, 0.7071068)
	var std_road_pos = Vector3(73.27933, 0.9668604, 38.52128)
	_road_meshes["FCQuestMapA_Road"] = _add_map_mesh(map_art_root, "FCQuestMapA_Road", "FCQuestMapA_Road.obj", MAP_TEX_DIR + "FcQuestMap_Road_Wildberry.png", std_road_pos, rot_neg90x, Vector3.ONE, 3, true)
	_road_meshes["FCQuestMapB_Road"] = _add_map_mesh(map_art_root, "FCQuestMapB_Road", "FCQuestMapB_Road.obj", MAP_TEX_DIR + "FcQuestMap_Road_Locked.png", std_road_pos, rot_neg90x, Vector3.ONE, 3, true)
	_road_meshes["FCQuestMapC_Road"] = _add_map_mesh(map_art_root, "FCQuestMapC_Road", "FCQuestMapC_Road.obj", MAP_TEX_DIR + "FcQuestMap_Road_Locked.png", std_road_pos, rot_neg90x, Vector3.ONE, 3, true)
	_road_meshes["FCQuestMapD_Road"] = _add_map_mesh(map_art_root, "FCQuestMapD_Road", "FCQuestMapD_Road.obj", MAP_TEX_DIR + "FcQuestMap_Road_Locked.png", std_road_pos, rot_neg90x, Vector3.ONE, 3, true)
	_road_meshes["FCQuestMapE_Road"] = _add_map_mesh(map_art_root, "FCQuestMapE_Road", "FCQuestMapA_HiddenPath2.obj", MAP_TEX_DIR + "FcQuestMap_Road_Locked.png", Vector3(79.25, 0.98, 38.94), rot_neg90x, Vector3(1.136569, 1.136569, 1.136569), 4, true)
	_road_meshes["FCQuestMapF_Road"] = _add_map_mesh(map_art_root, "FCQuestMapF_Road", "FCQuestMapC_HiddenPath7.obj", MAP_TEX_DIR + "FcQuestMap_Road_Locked.png", Vector3(73.28, 0.9668604, 38.29), rot_neg90x, Vector3.ONE, 4, true)
	_road_meshes["FCQuestMapG_Road"] = _add_map_mesh(map_art_root, "FCQuestMapG_Road", "FCQuestMapD_HiddenPath8.obj", MAP_TEX_DIR + "FcQuestMap_Road_Locked.png", std_road_pos, rot_neg90x, Vector3.ONE, 4, true)

	# 4. Hidden Paths (all start hidden until unlocked by quest stars)
	_hidden_paths["FCQuestMapA_HiddenPath1"] = _add_map_mesh(map_art_root, "FCQuestMapA_HiddenPath1", "FCQuestMapA_HiddenPath1.obj", MAP_TEX_DIR + "FcQuestMap_HiddenRoad_Wildberry.png", std_road_pos, rot_neg90x, Vector3.ONE, 3, false)
	for idx in [1, 2, 3, 4]:
		var pname = "FCQuestMapB_HiddenPath%d" % idx
		_hidden_paths[pname] = _add_map_mesh(map_art_root, pname, pname + ".obj", MAP_TEX_DIR + "FcQuestMap_HiddenRoad_Lumpy.png", std_road_pos, rot_neg90x, Vector3.ONE, 3, false)
	for idx in [2, 3, 5, 6]:
		var pname = "FCQuestMapC_HiddenPath%d" % idx
		_hidden_paths[pname] = _add_map_mesh(map_art_root, pname, pname + ".obj", MAP_TEX_DIR + "FcQuestMap_HiddenRoad_Witch.png", std_road_pos, rot_neg90x, Vector3.ONE, 3, false)
	for idx in [1, 2, 3, 4, 5, 6]:
		var pname = "FCQuestMapD_HiddenPath%d" % idx
		_hidden_paths[pname] = _add_map_mesh(map_art_root, pname, pname + ".obj", MAP_TEX_DIR + "FcQuestMap_HiddenRoad_Ice.png", std_road_pos, rot_neg90x, Vector3.ONE, 3, false)
	_hidden_paths["FCQuestMapD_HiddenPath7"] = _add_map_mesh(map_art_root, "FCQuestMapD_HiddenPath7", "FCQuestMapD_HiddenPath8.obj", MAP_TEX_DIR + "FcQuestMap_HiddenRoad_Ice.png", std_road_pos, rot_neg90x, Vector3.ONE, 3, false)

	# 5. "FIONNA & CAKE ADVENTURE" Doodle (FcQuestMap_Atlas04)
	_add_map_mesh(
		map_art_root,
		"FcQuestMap_Atlas04",
		"FcQuestMap_Atlas04_0.obj",
		MAP_TEX_DIR + "FcQuestMap_Atlas04.png",
		Vector3(63.8, 1.0, 22.54),
		Quaternion(0.7010574, 0.09229597, -0.09229597, 0.7010574),
		Vector3(0.5231068, 0.4395196, 0.4395197),
		5,
		true
	)

	# 6. Valentine's Heart Map Page (taped to the left of the notebook)
	_add_map_mesh(
		map_art_root,
		"FcQuestMap_Valentine",
		"FcQuestMap_Valentine.obj",
		MAP_TEX_DIR + "FcValentineQuestMap.png",
		Vector3(127.472, 2.648012, 11.04135),
		rot_neg90x,
		Vector3(-1.0, 1.0, 1.0),
		6,
		true
	)

	# 7. Wooden Bridge & Valentine Environment (FcQuestMap_Atlas05)
	_add_map_mesh(
		map_art_root,
		"FcQuestMap_Atlas05",
		"FcQuestMap_Atlas04.obj",
		MAP_TEX_DIR + "FcQuestMap_Atlas05.png",
		Vector3(133.1825, 2.764348, 21.22362),
		rot_neg90x,
		Vector3.ONE,
		7,
		true
	)

	# 8. Valentine's Roads (HiddenPaths)
	_hidden_paths["FcQuestMap_HiddenRoad_Valentine_Start"] = _add_map_mesh(
		map_art_root,
		"FcQuestMap_HiddenRoad_Valentine_Start",
		"FCQuestMapI_Road.obj",
		MAP_TEX_DIR + "FcQuestMap_Road_Heart.png",
		Vector3(90.2, 2.0, 34.1),
		Quaternion(-0.7071066, 0.0, 0.0, -0.7071069),
		Vector3.ONE,
		8,
		false
	)
	_hidden_paths["FcQuestMap_MainRoad_Valentine"] = _add_map_mesh(
		map_art_root,
		"FcQuestMap_MainRoad_Valentine",
		"FCQuestMapH_Road.obj",
		MAP_TEX_DIR + "FcQuestMap_Road_Heart.png",
		Vector3(125.5102, 2.813909, 10.65503),
		rot_neg90x,
		Vector3.ONE,
		8,
		false
	)
	_hidden_paths["FcQuestMap_HiddenRoad_Valentine_End"] = _add_map_mesh(
		map_art_root,
		"FcQuestMap_HiddenRoad_Valentine_End",
		"FCQuestMapH_HiddenPath1.obj",
		MAP_TEX_DIR + "FcQuestMap_HiddenRoad_Heart.png",
		Vector3(111.7571, 2.833297, 14.37897),
		rot_neg90x,
		Vector3.ONE,
		8,
		false
	)


func _add_atlas_group(parent: Node3D, node_name: String, mesh_file: String, tex_path: String, parent_unity_pos: Vector3, child_unity_pos: Vector3, priority: int) -> MeshInstance3D:
	var group = Node3D.new()
	group.name = node_name + "_Group"
	group.position = Vector3(parent_unity_pos.x, parent_unity_pos.y, -parent_unity_pos.z)
	group.quaternion = Quaternion(0.7071068, 0.0, 0.0, 0.7071068)
	parent.add_child(group)
	return _add_map_mesh(group, node_name, mesh_file, tex_path, child_unity_pos, Quaternion.IDENTITY, Vector3.ONE, priority, true)


func _add_map_mesh(
	parent: Node3D,
	node_name: String,
	mesh_file: String,
	tex_path: String,
	unity_pos: Vector3,
	godot_quat: Quaternion,
	node_scale: Vector3,
	priority: int,
	visible_default: bool
) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.name = node_name
	mi.position = Vector3(unity_pos.x, unity_pos.y, -unity_pos.z)
	mi.quaternion = godot_quat
	mi.scale = node_scale
	mi.visible = visible_default

	var full_mesh_path = MODELS_DIR + mesh_file
	if ResourceLoader.exists(full_mesh_path):
		mi.mesh = load(full_mesh_path)

	var mat = _make_unlit_material(tex_path, priority)
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _make_unlit_material(tex_path: String, priority: int) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.no_depth_test = true
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
# 61 QUEST NODES & PLAYER PIN CONSTRUCTION
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

	for q in Database.fc_quests_list:
		var qid = str(q.get("id", ""))
		if not FC_QUEST_NODE_POSITIONS.has(qid):
			continue
		var upos: Vector2 = FC_QUEST_NODE_POSITIONS[qid]
		var node_root = Node3D.new()
		node_root.name = "Q" + qid
		# Parent FCQuestMap*_Nodes has z = -0.036 in Unity
		var unity_z = upos.y - 0.036
		node_root.position = Vector3(upos.x, 3.0, -unity_z)
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
	if GameManager.fc_campaign_graph == null:
		return

	var fc_graph = GameManager.fc_campaign_graph
	var regions = Database.fc_map_regions_list

	# 1. Determine which regions (1..10) are PLAYABLE (matching MapControllerBase.ValidateRegions)
	var region_playable: Dictionary = {}
	for i in range(regions.size()):
		var r_id = int(regions[i].get("MapID", str(i + 1)))
		if i == 0:
			region_playable[r_id] = true
		else:
			region_playable[r_id] = false

	for q in Database.fc_quests_list:
		var qid = str(q.get("id", ""))
		var r_id = int(q.get("region_id", 1))
		var nd = fc_graph.get_node(qid)
		var state = int(nd.get("state", NodeMapGraph.NodeState.LOCKED))
		if state != NodeMapGraph.NodeState.LOCKED:
			region_playable[r_id] = true

	# 2. Update Region Road Textures (FcQuestMap_Road_Locked.png vs Region RoadTexture)
	for r in regions:
		var r_id = int(r.get("MapID", "1"))
		var road_mesh_name = str(r.get("RoadMesh", "")).strip_edges()
		if road_mesh_name != "" and _road_meshes.has(road_mesh_name):
			var mi: MeshInstance3D = _road_meshes[road_mesh_name]
			var mat := mi.material_override as StandardMaterial3D
			var is_open = region_playable.get(r_id, false)
			var tex_name = str(r.get("RoadTexture", "FcQuestMap_Road_Locked")).strip_edges() if is_open else "FcQuestMap_Road_Locked"
			var tex_path = MAP_TEX_DIR + tex_name + ".png"
			if mat and ResourceLoader.exists(tex_path):
				mat.albedo_texture = load(tex_path)

	# 3. Update Hidden Paths based on earned stars (matching MapControllerBase.InitializeHiddenPaths)
	for hp_name in _hidden_paths.keys():
		_hidden_paths[hp_name].visible = false

	for q in Database.fc_quests_list:
		var qid = str(q.get("id", ""))
		var nd = fc_graph.get_node(qid)
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
		var nd = fc_graph.get_node(qid)
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
	var active_qid = _get_current_fc_quest_id()
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


func _get_current_fc_quest_id() -> String:
	var qid = GameManager.active_fc_quest_id
	if qid != "" and _quest_node_views.has(qid):
		var nd = GameManager.fc_campaign_graph.get_node(qid)
		if int(nd.get("state", 0)) != NodeMapGraph.NodeState.LOCKED:
			return qid
	return "5001"


# ==============================================================================
# CAMERA FOCUS, PAN, ZOOM & COLLIDER CLAMPING (CWCameraCollider.cs)
# ==============================================================================

func focus_camera_on_active_quest(target_ortho: float = 22.0) -> void:
	var active_qid = _get_current_fc_quest_id()
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


func clamp_camera_pos(pos: Vector3, ortho: float) -> Vector3:
	# Exact formula from CWCameraCollider.SetCameraColliderBounds & FCQuestMap Main CameraCollider
	# Collider center in Unity is (-50, 0, 0); size(18) = (240, 75), size(38) = (170, 37)
	var col_w: float = -3.5 * ortho + 303.0
	var col_h: float = -1.9 * ortho + 109.2
	var clamped_x = clampf(pos.x, -50.0 - col_w * 0.5, -50.0 + col_w * 0.5)
	var clamped_z = clampf(pos.z, -col_h * 0.5, col_h * 0.5)
	return Vector3(clamped_x, 50.0, clamped_z)


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
		var nd = GameManager.fc_campaign_graph.get_node(best_qid)
		var state = int(nd.get("state", NodeMapGraph.NodeState.LOCKED))
		if state != NodeMapGraph.NodeState.LOCKED:
			GameManager.active_fc_quest_id = best_qid
			refresh_map_state()
			_open_quest_modal(best_qid)


# ==============================================================================
# HUD & QUEST MODAL
# ==============================================================================

func _refresh_hud() -> void:
	var hero_name = GameManager.player_hero_name
	if hero_name == "" or hero_name == "Finn":
		hero_name = "Jake"
	var char_info = Database.get_character(hero_name)
	var display_name = str(char_info.get("name", hero_name))
	if display_name == "" or display_name.begins_with("!!"):
		display_name = hero_name

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
	var gems = GameManager.gems if "gems" in GameManager else 5
	var coins = GameManager.coins if "coins" in GameManager else 143

	var total_cards = 14
	if "player_deck" in GameManager and GameManager.player_deck != null:
		total_cards = GameManager.player_deck.size()
	if "player_inventory" in GameManager and GameManager.player_inventory != null:
		total_cards += GameManager.player_inventory.size()

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
		cards_label.text = "%d/50" % total_cards
	if gems_label:
		gems_label.text = "%d" % gems
	if coins_label:
		coins_label.text = "%d" % coins


var _modal_leader_ids: Array[String] = ["Jake", "Finn", "Fionna", "Cake"]
var _modal_deck_index: int = 0
var _modal_decks: Array[Dictionary] = []


func _unhandled_input(event: InputEvent) -> void:
	if detail_modal and detail_modal.visible and event.is_action_pressed("ui_cancel"):
		_close_quest_modal()
		get_viewport().set_input_as_handled()


func _open_quest_modal(quest_id: String) -> void:
	_selected_quest_id = quest_id
	var quest = Database.get_quest(quest_id)
	if quest.is_empty() or detail_modal == null:
		return

	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)

	var nd = GameManager.fc_campaign_graph.get_node(quest_id)
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

	# Stamina cost on PLAY! button
	if modal_stamina_cost_label:
		modal_stamina_cost_label.text = str(int(quest.get("stamina", 1)))

	# Player side (Leader + Deck)
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
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)
	if detail_modal:
		detail_modal.visible = false
	if bottom_hud:
		bottom_hud.visible = true


func _load_available_decks() -> void:
	_modal_decks.clear()
	_modal_decks.append({
		"name": GameManager.active_deck_name if GameManager.active_deck_name != "" else "Deck 1",
		"label": "Deck 1",
		"cards": GameManager.player_deck.duplicate(),
		"landscapes": GameManager.player_landscapes.duplicate()
	})
	var dir = DirAccess.open("user://decks")
	if dir != null:
		dir.list_dir_begin()
		var fname = dir.get_next()
		var idx = 2
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".json"):
				var f = FileAccess.open("user://decks/" + fname, FileAccess.READ)
				if f != null:
					var j = JSON.new()
					if j.parse(f.get_as_text()) == OK and typeof(j.data) == TYPE_DICTIONARY:
						var d: Dictionary = j.data
						if str(d.get("name", "")) != GameManager.active_deck_name:
							_modal_decks.append({
								"name": str(d.get("name", "Deck %d" % idx)),
								"label": "Deck %d" % idx,
								"cards": d.get("cards", []),
								"landscapes": d.get("landscapes", ["Plains", "Plains", "Cotton", "Plains"])
							})
							idx += 1
			fname = dir.get_next()
		dir.list_dir_end()
	_modal_deck_index = clampi(_modal_deck_index, 0, maxi(0, _modal_decks.size() - 1))


func _refresh_modal_player_side() -> void:
	var hero_id = GameManager.player_hero_name
	if hero_id == "":
		hero_id = "Jake"
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
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)
	var cur = GameManager.player_hero_name
	if cur == "":
		cur = "Jake"
	var idx = _modal_leader_ids.find(cur)
	if idx < 0:
		idx = 0
	idx = (idx + delta + _modal_leader_ids.size()) % _modal_leader_ids.size()
	GameManager.player_hero_name = _modal_leader_ids[idx]
	GameManager._update_active_hero_hp()
	_refresh_modal_player_side()
	_refresh_hud()


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


func _populate_reward_cards(drops_arr: Array) -> void:
	if modal_card_slots == null:
		return
	for ch in modal_card_slots.get_children():
		ch.queue_free()

	# Gather card dicts and sort by rarity descending (matching CWMapQuestInfoSet)
	var cards: Array[Dictionary] = []
	for cid in drops_arr:
		var cdata = Database.get_card(str(cid))
		if not cdata.is_empty():
			cards.append(cdata)
	cards.sort_custom(func(a, b): return int(a.get("rarity", 1)) > int(b.get("rarity", 1)))

	var font_res: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	var count = mini(4, cards.size())
	for i in range(count):
		var c = cards[i]
		var card_w := 106.0
		var card_h := 148.0
		var slot := Control.new()
		slot.position = Vector2(7.0, float(i) * 68.0)
		slot.size = Vector2(card_w, card_h)
		slot.z_index = i + 1
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		modal_card_slots.add_child(slot)

		var faction = str(c.get("faction", "Universal"))
		var rarity = int(c.get("rarity", 1))
		var ctype = str(c.get("type", "CREATURE"))
		var faction_col: Color = FACTION_COLORS.get(faction, Color.WHITE)

		# Card Art
		var art_tex = Database.get_card_texture(str(c.get("texture_path", "")))
		var art := TextureRect.new()
		art.position = Vector2(5.0, 14.0)
		art.size = Vector2(card_w - 10.0, 72.0)
		art.texture = art_tex
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(art)

		# Card Frame
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

		# Gold Frame overlay for rarity >= 3
		if rarity >= 3:
			var gold := TextureRect.new()
			gold.position = Vector2.ZERO
			gold.size = Vector2(card_w, card_h)
			gold.texture = load(QUEST_INFO_TEX_DIR + "Frame_Gold.png")
			gold.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			gold.stretch_mode = TextureRect.STRETCH_SCALE
			gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(gold)

		# Type Label
		var type_lbl := Label.new()
		type_lbl.position = Vector2(18.0, 3.0)
		type_lbl.size = Vector2(card_w - 36.0, 12.0)
		type_lbl.text = ctype.capitalize()
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_lbl.add_theme_color_override("font_color", Color.BLACK)
		type_lbl.add_theme_font_size_override("font_size", 8)
		if font_res:
			type_lbl.add_theme_font_override("font", font_res)
		slot.add_child(type_lbl)

		# Cost Badge
		var cost_bg := TextureRect.new()
		cost_bg.position = Vector2(2.0, 2.0)
		cost_bg.size = Vector2(20.0, 20.0)
		cost_bg.texture = load(QUEST_INFO_TEX_DIR + "Frame_Cost.png")
		cost_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cost_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(cost_bg)

		var cost_lbl := Label.new()
		cost_lbl.position = Vector2(2.0, 2.0)
		cost_lbl.size = Vector2(20.0, 20.0)
		cost_lbl.text = str(int(c.get("cost", 1)))
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 1.0, 1.0))
		cost_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		cost_lbl.add_theme_constant_override("outline_size", 2)
		cost_lbl.add_theme_font_size_override("font_size", 11)
		if font_res:
			cost_lbl.add_theme_font_override("font", font_res)
		slot.add_child(cost_lbl)

		# Faction Icon (top-right)
		if LANDSCAPE_ICONS.has(faction):
			var fact_icon := TextureRect.new()
			fact_icon.position = Vector2(card_w - 17.0, 2.0)
			fact_icon.size = Vector2(14.0, 14.0)
			fact_icon.texture = load(QUEST_INFO_TEX_DIR + str(LANDSCAPE_ICONS[faction]))
			fact_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			fact_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slot.add_child(fact_icon)

		# Rarity Stars (up to 5) on right side of card
		var full_star = load(NODE_TEX_DIR + "UI_Star_Full.png")
		for s in range(mini(5, rarity)):
			var st := TextureRect.new()
			var col_idx = s % 3
			var row_idx = s / 3
			st.position = Vector2(card_w - 14.0 - float(col_idx) * 10.0, 74.0 - float(row_idx) * 10.0)
			st.size = Vector2(11.0, 11.0)
			st.texture = full_star
			st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slot.add_child(st)

		# Name Label
		var name_lbl := Label.new()
		name_lbl.position = Vector2(6.0, 88.0)
		name_lbl.size = Vector2(card_w - 12.0, 14.0)
		name_lbl.text = str(c.get("name", ""))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.clip_text = true
		name_lbl.add_theme_color_override("font_color", Color.BLACK)
		name_lbl.add_theme_font_size_override("font_size", 8)
		if font_res:
			name_lbl.add_theme_font_override("font", font_res)
		slot.add_child(name_lbl)

		# ATK / DEF for Creatures
		if ctype == "CREATURE":
			var atk_lbl := Label.new()
			atk_lbl.position = Vector2(6.0, card_h - 18.0)
			atk_lbl.size = Vector2(26.0, 14.0)
			atk_lbl.text = str(int(c.get("atk", 0)))
			atk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			atk_lbl.add_theme_color_override("font_color", Color.BLACK)
			atk_lbl.add_theme_font_size_override("font_size", 9)
			if font_res:
				atk_lbl.add_theme_font_override("font", font_res)
			slot.add_child(atk_lbl)

			var def_lbl := Label.new()
			def_lbl.position = Vector2(card_w - 32.0, card_h - 18.0)
			def_lbl.size = Vector2(26.0, 14.0)
			def_lbl.text = str(int(c.get("def", 0)))
			def_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			def_lbl.add_theme_color_override("font_color", Color.BLACK)
			def_lbl.add_theme_font_size_override("font_size", 9)
			if font_res:
				def_lbl.add_theme_font_override("font", font_res)
			slot.add_child(def_lbl)


func _on_battle_pressed() -> void:
	if _selected_quest_id == "":
		return
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)
	_close_quest_modal()
	GameManager.launch_quest_battle(_selected_quest_id)


func _on_back_pressed() -> void:
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)
	GameManager.return_to_menu()


func _on_deck_pressed() -> void:
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)
	GameManager.open_deck_builder()
