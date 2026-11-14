extends Node

func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING FIONNA & CAKE EXPANSION TEST SUITE (Task 7.3)")
	print("==================================================\n")

	var passed = 0
	var failed = 0

	# -------------------------------------------------------------
	# Test 1: Database FC Quests & Map Regions
	# -------------------------------------------------------------
	print("[Test 1] Database FC Quests & Regions Loading")
	var fc_quests = Database.get_fc_quests()
	var fc_regions = Database.get_fc_map_regions()
	if fc_quests.size() == 61:
		print("  [PASS] Loaded exactly 61 FC quests")
		passed += 1
	else:
		printerr("  [FAIL] Expected 61 FC quests, got %d" % fc_quests.size())
		failed += 1

	if fc_regions.size() == 10:
		print("  [PASS] Loaded exactly 10 FC map regions")
		passed += 1
	else:
		printerr("  [FAIL] Expected 10 FC map regions, got %d" % fc_regions.size())
		failed += 1

	# Verify sample regions
	var r1_name = fc_regions[0].get("RegionName", "")
	if r1_name == "WILDBERRY KINGDOM":
		print("  [PASS] Region 1 is 'WILDBERRY KINGDOM'")
		passed += 1
	else:
		printerr("  [FAIL] Expected Region 1 'WILDBERRY KINGDOM', got '%s'" % r1_name)
		failed += 1

	var r2_name = fc_regions[1].get("RegionName", "")
	if r2_name == "LUMPY SPACE":
		print("  [PASS] Region 2 is 'LUMPY SPACE'")
		passed += 1
	else:
		printerr("  [FAIL] Expected Region 2 'LUMPY SPACE', got '%s'" % r2_name)
		failed += 1

	# -------------------------------------------------------------
	# Test 2: FC Campaign Graph Initialization
	# -------------------------------------------------------------
	print("\n[Test 2] FC Campaign Graph Initialization & Initial Unlock")
	GameManager.fc_campaign_graph = null
	GameManager._init_campaign()
	var fc_graph = GameManager.fc_campaign_graph
	if fc_graph != null:
		print("  [PASS] fc_campaign_graph instance created")
		passed += 1
	else:
		printerr("  [FAIL] fc_campaign_graph is null")
		failed += 1

	if fc_graph.get_all_nodes().size() == 61:
		print("  [PASS] fc_campaign_graph contains 61 nodes")
		passed += 1
	else:
		printerr("  [FAIL] Expected 61 nodes, got %d" % fc_graph.get_all_nodes().size())
		failed += 1

	var node_5001 = fc_graph.get_node("5001")
	if not node_5001.is_empty() and node_5001.get("state") == 1: # UNLOCKED = 1
		print("  [PASS] Quest 5001 starts UNLOCKED")
		passed += 1
	else:
		printerr("  [FAIL] Quest 5001 state is not UNLOCKED (got %s)" % str(node_5001.get("state")))
		failed += 1

	var node_5002 = fc_graph.get_node("5002")
	if not node_5002.is_empty() and node_5002.get("state") == 0: # LOCKED = 0
		print("  [PASS] Quest 5002 starts LOCKED")
		passed += 1
	else:
		printerr("  [FAIL] Quest 5002 should start LOCKED")
		failed += 1

	# -------------------------------------------------------------
	# Test 3: Quest Completion & Branching Unlocks
	# -------------------------------------------------------------
	print("\n[Test 3] Quest Completion & Multi-Node Unlocking")
	var dummy_stats = {
		"won": true,
		"turns_taken": 4,
		"player_hp_pct_remaining": 0.85,
		"cards_played": 3,
		"spells_played": 0,
		"creatures_lost": 0,
		"enemy_creatures_defeated": 10,
		"floops_used": 0
	}
	var res = GameManager.complete_campaign_quest("5001", dummy_stats)
	if res.get("ok") == true and res.get("stars") == 3:
		print("  [PASS] Quest 5001 completed with 3 stars")
		passed += 1
	else:
		printerr("  [FAIL] Quest 5001 completion failed: %s" % str(res))
		failed += 1

	# Verify 5002 is now UNLOCKED
	var node_5002_after = fc_graph.get_node("5002")
	if node_5002_after.get("state") == 1:
		print("  [PASS] Quest 5002 unlocked after 5001 victory")
		passed += 1
	else:
		printerr("  [FAIL] Quest 5002 failed to unlock: %s" % str(node_5002_after.get("state")))
		failed += 1

	# Quest 5044 converges from 5001 and 5004. Verify prerequisites contain both
	var node_5044 = fc_graph.get_node("5044")
	var prereqs_5044 = node_5044.get("prerequisites", [])
	if prereqs_5044.has("5001") and prereqs_5044.has("5004"):
		print("  [PASS] Quest 5044 has multi-route convergence (prerequisites: %s)" % str(prereqs_5044))
		passed += 1
	else:
		printerr("  [FAIL] Quest 5044 prerequisites mismatch: %s" % str(prereqs_5044))
		failed += 1

	# -------------------------------------------------------------
	# Test 4: Combined Star Totals Across Worlds
	# -------------------------------------------------------------
	print("\n[Test 4] Combined Campaign Stars Across Land of Ooo & FC")
	var ooo_stars = GameManager.campaign_graph.get_total_stars()
	var fc_stars = GameManager.fc_campaign_graph.get_total_stars()
	var total_stars = GameManager.get_total_campaign_stars()
	if fc_stars >= 3 and total_stars == (ooo_stars + fc_stars):
		print("  [PASS] Total campaign stars combines Ooo (%d) + FC (%d) = %d" % [ooo_stars, fc_stars, total_stars])
		passed += 1
	else:
		printerr("  [FAIL] Total stars mismatch: Ooo=%d, FC=%d, Total=%d" % [ooo_stars, fc_stars, total_stars])
		failed += 1

	# -------------------------------------------------------------
	# Test 5: Profile Persistence for FC Campaign
	# -------------------------------------------------------------
	print("\n[Test 5] Profile Persistence & FC Restoration")
	var test_profile_path = "user://test_fc_profile.json"
	GameManager.save_profile(test_profile_path)
	if FileAccess.file_exists(test_profile_path):
		print("  [PASS] Profile saved with FC data")
		passed += 1
	else:
		printerr("  [FAIL] Failed to write profile")
		failed += 1

	# Verify serialization content contains fc_campaign with 5001 completed
	var file = FileAccess.open(test_profile_path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	DirAccess.remove_absolute(test_profile_path)

	var pdata = json.data
	if pdata.has("fc_campaign"):
		var fc_save = pdata["fc_campaign"]
		var prog = fc_save.get("progress", {})
		if prog.has("5001") and int(prog["5001"].get("stars", 0)) == 3:
			print("  [PASS] Quest 5001 serialized with 3 stars in fc_campaign")
			passed += 1
		else:
			printerr("  [FAIL] Quest 5001 progress missing from fc_campaign: %s" % str(prog))
			failed += 1
	else:
		printerr("  [FAIL] Profile missing 'fc_campaign' key")
		failed += 1

	# -------------------------------------------------------------
	# Test 6: CampaignMap World Toggle UI
	# -------------------------------------------------------------
	print("\n[Test 6] CampaignMap UI World Switcher")
	var map_scene = load("res://scenes/campaign_map.tscn").instantiate()
	add_child(map_scene)

	if map_scene.current_world == 0: # LAND_OF_OOO
		print("  [PASS] CampaignMap initially on LAND_OF_OOO")
		passed += 1
	else:
		printerr("  [FAIL] Expected initial world LAND_OF_OOO")
		failed += 1

	# Toggle to Fionna & Cake
	map_scene.set_campaign_world(1) # FIONNA_AND_CAKE
	if map_scene.current_world == 1:
		print("  [PASS] Switched to FIONNA_AND_CAKE world")
		passed += 1
	else:
		printerr("  [FAIL] Failed to switch world")
		failed += 1

	if map_scene.title_label.text.contains("FIONNA & CAKE"):
		print("  [PASS] Title updated to 'FIONNA & CAKE EXPANSION'")
		passed += 1
	else:
		printerr("  [FAIL] Title mismatch: %s" % map_scene.title_label.text)
		failed += 1

	if map_scene.regions_bar.get_child_count() == 10:
		print("  [PASS] Regions bar populated with 10 FC regions")
		passed += 1
	else:
		printerr("  [FAIL] Expected 10 region buttons, got %d" % map_scene.regions_bar.get_child_count())
		failed += 1

	# Toggle back to Land of Ooo
	map_scene.set_campaign_world(0)
	if map_scene.regions_bar.get_child_count() == 8:
		print("  [PASS] Regions bar restored to 8 Land of Ooo regions")
		passed += 1
	else:
		printerr("  [FAIL] Expected 8 Ooo regions, got %d" % map_scene.regions_bar.get_child_count())
		failed += 1

	map_scene.queue_free()

	# -------------------------------------------------------------
	# Test 7: 3D Fionna & Cake Adventure Map (FCCampaignMap.gd)
	# -------------------------------------------------------------
	print("\n[Test 7] 3D Fionna & Cake Adventure Map Scene (QuestMap_FC.prefab)")
	var fc_3d_map = load("res://scenes/fc_campaign_map.tscn").instantiate()
	add_child(fc_3d_map)

	if fc_3d_map._quest_node_views.size() == 61:
		print("  [PASS] FCCampaignMap built all 61 3D quest nodes at original Unity coordinates")
		passed += 1
	else:
		printerr("  [FAIL] Expected 61 3D quest nodes, got %d" % fc_3d_map._quest_node_views.size())
		failed += 1

	if fc_3d_map._road_meshes.size() == 7:
		print("  [PASS] FCCampaignMap loaded all 7 region road meshes")
		passed += 1
	else:
		printerr("  [FAIL] Expected 7 region road meshes, got %d" % fc_3d_map._road_meshes.size())
		failed += 1

	if fc_3d_map._hidden_paths.size() == 19:
		print("  [PASS] FCCampaignMap loaded all 19 hidden path meshes")
		passed += 1
	else:
		printerr("  [FAIL] Expected 19 hidden path meshes, got %d" % fc_3d_map._hidden_paths.size())
		failed += 1

	# Since 5001 was completed with 3 stars in Test 3, verify FcQuestMap_HiddenRoad_Valentine_Start (3-star Valentine bridge path) is visible
	if fc_3d_map._hidden_paths.has("FcQuestMap_HiddenRoad_Valentine_Start") and fc_3d_map._hidden_paths["FcQuestMap_HiddenRoad_Valentine_Start"].visible:
		print("  [PASS] 3-star hidden path 'FcQuestMap_HiddenRoad_Valentine_Start' unlocked and visible after 5001 3-star clear")
		passed += 1
	else:
		printerr("  [FAIL] Expected 'FcQuestMap_HiddenRoad_Valentine_Start' to be visible after 5001 3-star clear")
		failed += 1

	fc_3d_map.queue_free()

	# Clean up default profile written by complete_campaign_quest during test run
	if FileAccess.file_exists(GameManager.DEFAULT_PROFILE_PATH):
		DirAccess.remove_absolute(GameManager.DEFAULT_PROFILE_PATH)

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [passed, failed])
	print("==================================================")

	if failed == 0:
		print(">>> ALL FIONNA & CAKE TESTS COMPLETED SUCCESSFULLY! <<<\n")
		get_tree().quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		get_tree().quit(1)
