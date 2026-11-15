extends CampaignMapBase

const MODELS_DIR := "res://assets/models/fc_map/"

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


func _on_map_enter() -> void:
	GameManager.ensure_fc_leaders_unlocked()


func _get_models_dir() -> String:
	return MODELS_DIR


func _get_graph() -> NodeMapGraph:
	return GameManager.fc_campaign_graph


func _get_quests_list() -> Array[Dictionary]:
	return Database.fc_quests_list


func _get_regions_list() -> Array[Dictionary]:
	return Database.fc_map_regions_list


func _get_locked_road_texture_name() -> String:
	return "FcQuestMap_Road_Locked"


func _get_default_quest_id() -> String:
	return "5001"


func _get_active_quest_id_pref() -> String:
	return GameManager.active_fc_quest_id


func _set_active_quest_id_pref(qid: String) -> void:
	GameManager.active_fc_quest_id = qid


func _has_quest_node_pos(qid: String) -> bool:
	return FC_QUEST_NODE_POSITIONS.has(qid)


func _get_quest_node_godot_xz(qid: String) -> Vector2:
	var upos: Vector2 = FC_QUEST_NODE_POSITIONS[qid]
	return Vector2(upos.x, -(upos.y - 0.036))


func clamp_camera_pos(pos: Vector3, ortho: float) -> Vector3:
	# Exact formula from CWCameraCollider.SetCameraColliderBounds & FCQuestMap Main CameraCollider
	# Collider center in Unity is (-50, 0, 0); size(18) = (240, 75), size(38) = (170, 37)
	var col_w: float = -3.5 * ortho + 303.0
	var col_h: float = -1.9 * ortho + 109.2
	var clamped_x = clampf(pos.x, -50.0 - col_w * 0.5, -50.0 + col_w * 0.5)
	var clamped_z = clampf(pos.z, -col_h * 0.5, col_h * 0.5)
	return Vector3(clamped_x, 50.0, clamped_z)


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
