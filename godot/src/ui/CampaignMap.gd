extends CampaignMapBase

const MODELS_DIR := "res://assets/models/main_map/"

# Exact Godot MapRoot-local (x, z) coordinates for QuestMap_Main Q0001..Q0120
const MAIN_QUEST_NODE_POSITIONS: Dictionary = {
	"1": Vector2(52.8045, -39.8524), "2": Vector2(43.5001, -43.6041), "3": Vector2(33.2586, -42.9744), "4": Vector2(29.8604, -35.712),
	"5": Vector2(37.0192, -32.2561), "6": Vector2(35.0341, -25.067), "7": Vector2(26.2403, -25.6463), "8": Vector2(15.8876, -24.4053),
	"9": Vector2(7.0532, -20.6103), "10": Vector2(4.8121, -29.7947), "11": Vector2(10.1832, -36.6475), "12": Vector2(18.9993, -41.8622),
	"13": Vector2(16.5914, -49.3898), "14": Vector2(5.9948, -50.8557), "15": Vector2(-2.3566, -45.1866), "16": Vector2(-13.3948, -38.4709),
	"17": Vector2(-23.6877, -41.1303), "18": Vector2(-35.4349, -44.8786), "19": Vector2(-48.4728, -42.8731), "20": Vector2(-53.3687, -34.0483),
	"21": Vector2(-54.5857, -24.2373), "22": Vector2(-56.1213, -13.3297), "23": Vector2(-48.7839, -5.576), "24": Vector2(-37.4242, -4.9268),
	"25": Vector2(-27.5219, -12.1596), "26": Vector2(-20.4176, -18.886), "27": Vector2(-14.5605, -14.6632), "28": Vector2(-17.0804, -5.5502),
	"29": Vector2(-28.5841, -1.0081), "30": Vector2(-36.5463, 3.6161), "31": Vector2(-36.9057, 13.6571), "32": Vector2(-44.9524, 17.922),
	"33": Vector2(-52.4, 23.4083), "34": Vector2(-46.0701, 28.4462), "35": Vector2(-36.4136, 28.6976), "36": Vector2(-27.2845, 26.9624),
	"37": Vector2(-22.7346, 19.6993), "38": Vector2(-17.7394, 10.8775), "39": Vector2(-7.4873, 11.5254), "40": Vector2(3.1916, 8.6267),
	"41": Vector2(4.6508, 17.2045), "42": Vector2(-7.0339, 21.0138), "43": Vector2(-13.2827, 27.3575), "44": Vector2(-5.1706, 28.0644),
	"45": Vector2(4.3305, 25.0825), "46": Vector2(13.8179, 13.9998), "47": Vector2(14.6282, 3.9224), "48": Vector2(19.6112, -3.6934),
	"49": Vector2(30.1407, -7.8475), "50": Vector2(42.6555, -7.8758), "51": Vector2(52.3587, -3.7122), "52": Vector2(50.4326, 6.3831),
	"53": Vector2(39.2994, 7.9576), "54": Vector2(29.4852, 11.1155), "55": Vector2(32.7584, 20.0872), "56": Vector2(42.5968, 25.8309),
	"57": Vector2(41.0481, 34.0559), "58": Vector2(32.1149, 37.9145), "59": Vector2(27.778, 46.4556), "60": Vector2(29.1809, 55.6743),
	"61": Vector2(44.3941, 61.3993), "62": Vector2(53.002, 69.3914), "63": Vector2(54.1922, 81.4008), "64": Vector2(52.2941, 94.0167),
	"65": Vector2(43.0478, 94.1374), "66": Vector2(43.7201, 80.1572), "67": Vector2(35.9711, 70.91), "68": Vector2(24.0427, 67.8857),
	"69": Vector2(13.9871, 73.664), "70": Vector2(15.2208, 86.4709), "71": Vector2(19.5547, 98.0908), "72": Vector2(30.7043, 106.1525),
	"73": Vector2(19.8325, 113.2824), "74": Vector2(8.6702, 109.9878), "75": Vector2(3.9411, 97.3403), "76": Vector2(0.891, 75.6517),
	"77": Vector2(7.6349, 66.0765), "78": Vector2(11.8305, 56.8628), "79": Vector2(3.0804, 53.0767), "80": Vector2(-6.1267, 56.5751),
	"81": Vector2(-16.1991, 62.402), "82": Vector2(-27.4692, 62.2713), "83": Vector2(-39.7253, 63.0036), "84": Vector2(-50.1021, 67.6063),
	"85": Vector2(-54.5522, 76.2351), "86": Vector2(-55.8325, 88.1095), "87": Vector2(-53.904, 98.3088), "88": Vector2(-50.223, 107.9547),
	"89": Vector2(-41.5053, 114.5181), "90": Vector2(-28.4143, 114.7604), "91": Vector2(-19.6032, 116.4406), "92": Vector2(-8.6321, 120.9771),
	"93": Vector2(-0.6192, 128.7007), "94": Vector2(-3.3165, 137.5573), "95": Vector2(-14.7275, 142.5545), "96": Vector2(-30.5972, 147.7587),
	"97": Vector2(-44.3375, 153.0475), "98": Vector2(-54.57, 159.2124), "99": Vector2(-58.1264, 170.782), "100": Vector2(-52.3686, 178.737),
	"101": Vector2(-40.5192, 178.298), "102": Vector2(-30.958, 171.4588), "103": Vector2(-23.0407, 164.0519), "104": Vector2(-15.214, 157.6627),
	"105": Vector2(-5.3836, 150.547), "106": Vector2(2.2636, 146.1127), "107": Vector2(10.0238, 140.5468), "108": Vector2(19.5272, 135.5981),
	"109": Vector2(29.7265, 132.7261), "110": Vector2(41.7294, 132.2356), "111": Vector2(50.9095, 135.2873), "112": Vector2(59.706, 141.6306),
	"113": Vector2(62.8759, 149.1753), "114": Vector2(61.9305, 159.3218), "115": Vector2(57.4766, 170.3571), "116": Vector2(49.9892, 178.5652),
	"117": Vector2(39.2132, 183.3542), "118": Vector2(28.3295, 182.9942), "119": Vector2(18.3949, 180.187), "120": Vector2(7.8308, 182.7992)
}


func _get_models_dir() -> String:
	return MODELS_DIR


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
	return MAIN_QUEST_NODE_POSITIONS.has(qid)


func _get_quest_node_godot_xz(qid: String) -> Vector2:
	return MAIN_QUEST_NODE_POSITIONS[qid]


func clamp_camera_pos(pos: Vector3, ortho: float) -> Vector3:
	# Exact formula from CWCameraCollider.SetCameraColliderBounds & QuestMap Main CameraCollider
	# Collider center in Unity is (0, 0, 70) -> Godot (0, 0, -70); size(18) = (100, 240), size(38) = (35, 180)
	var col_w: float = -3.25 * ortho + 158.5
	var col_h: float = -3.0 * ortho + 294.0
	var clamped_x = clampf(pos.x, -col_w * 0.5, col_w * 0.5)
	var clamped_z = clampf(pos.z, -70.0 - col_h * 0.5, -70.0 + col_h * 0.5)
	return Vector3(clamped_x, 50.0, clamped_z)


# ==============================================================================
# 3D MAP ART CONSTRUCTION (Exact QuestMap_Main.prefab hierarchy & depth-sorted materials)
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

	# 0. Ground Sand / Ocean Shore / Forest Edge (opaque at Y=0, writes Z)
	_add_map_mesh(
		map_art_root,
		"QuestMap_Ground",
		"QuestMap_Ground.obj",
		MAP_TEX_DIR + "QuestMap_Ground.png",
		Vector3(0.0, 0.0, -30.0),
		Quaternion(0.7071068, 0.0, 0.0, 0.7071067),
		Vector3.ONE,
		0,
		true,
		BaseMaterial3D.TRANSPARENCY_DISABLED,
		false,
		BaseMaterial3D.DEPTH_DRAW_ALWAYS
	)

	# 1. Region Roads (A..H at Y=0.5, alpha cutout/pre-pass writing Z so hills at Y<=0.4 sit behind & trees at Y>=1.0 sit above)
	var road_quat = Quaternion(0.7071068, -8.42937e-08, 8.42937e-08, 0.7071068)
	var road_specs: Array = [
		["QuestMapA_Road", MAP_TEX_DIR + "QuestMap_Road_TreeHouse.png", Vector3(30.0, 0.0, 30.0)],
		["QuestMapB_Road", MAP_TEX_DIR + "QuestMap_Road_Locked.png", Vector3(-30.0, 0.0, 30.0)],
		["QuestMapC_Road", MAP_TEX_DIR + "QuestMap_Road_Locked.png", Vector3(-30.0, 0.0, -30.0)],
		["QuestMapD_Road", MAP_TEX_DIR + "QuestMap_Road_Locked.png", Vector3(30.0, 0.0, -30.0)],
		["QuestMapE_Road", MAP_TEX_DIR + "QuestMap_Road_Locked.png", Vector3(29.99998, 0.0, -90.0)],
		["QuestMapF_Road", MAP_TEX_DIR + "QuestMap_Road_Locked.png", Vector3(-30.00002, 0.0, -90.0)],
		["QuestMapG_Road", MAP_TEX_DIR + "QuestMap_Road_Locked.png", Vector3(-122.9448, 0.0, -120.8434)],
		["QuestMapH_Road", MAP_TEX_DIR + "QuestMap_Road_Locked.png", Vector3(-64.34193, 0.0, -124.5471)]
	]
	for spec in road_specs:
		var rname: String = spec[0]
		_road_meshes[rname] = _add_map_mesh(
			map_art_root,
			rname,
			rname + ".obj",
			spec[1],
			spec[2],
			road_quat,
			Vector3.ONE,
			1,
			true,
			BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS,
			false,
			BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
		)

	# 2. Environment Atlases 01..04 (depth-tested against Y=0.5 roads: hills Y<=0.4 appear behind roads, trees/banners Y>=0.6 appear over roads)
	var std_quat = Quaternion(0.7071068, 0.0, 0.0, 0.7071068)
	var atlas_specs: Array = [
		["QuestMap_Atlas04_DarkForest", MAP_TEX_DIR + "QuestMap_Atlas04.png", Vector3(35.68325, 0.464589, -157.9511), std_quat],
		["QuestMap_Atlas04_Desert", MAP_TEX_DIR + "QuestMap_Atlas04.png", Vector3(-43.06643, 0.0, -139.5415), std_quat],
		["QuestMap_Atlas01_00", MAP_TEX_DIR + "QuestMap_Atlas01.png", Vector3(50.95524, 1.0, 29.47369), Quaternion(0.7071068, -2.702117e-15, 6.181724e-08, 0.7071068)],
		["QuestMap_Atlas01_01", MAP_TEX_DIR + "QuestMap_Atlas01.png", Vector3(50.95524, 1.0, 29.47369), std_quat],
		["QuestMap_Atlas02_00", MAP_TEX_DIR + "QuestMap_Atlas02.png", Vector3(1.243649, 0.5865758, -27.10174), std_quat],
		["QuestMap_Atlas02_01", MAP_TEX_DIR + "QuestMap_Atlas02.png", Vector3(-55.06229, 0.4, -45.38657), std_quat],
		["QuestMap_Atlas03_00", MAP_TEX_DIR + "QuestMap_Atlas03.png", Vector3(9.299915, 0.0, -83.6952), std_quat],
		["QuestMap_Atlas03_01", MAP_TEX_DIR + "QuestMap_Atlas03.png", Vector3(9.299915, 0.0, -83.6952), std_quat]
	]
	for spec in atlas_specs:
		var aname: String = spec[0]
		_add_map_mesh(
			map_art_root,
			aname,
			aname + ".obj",
			spec[1],
			spec[2],
			spec[3],
			Vector3.ONE,
			2,
			true,
			BaseMaterial3D.TRANSPARENCY_ALPHA,
			false,
			BaseMaterial3D.DEPTH_DRAW_DISABLED
		)
