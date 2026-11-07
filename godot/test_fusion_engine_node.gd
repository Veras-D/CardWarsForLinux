extends Node

## Automated Test Suite for Task 6.2: Card Quality & Fusion Engine

const FusionEngine = preload("res://src/cards/FusionEngine.gd")
const DeckBuilder = preload("res://src/ui/DeckBuilder.gd")
const CardViewScene = preload("res://scenes/components/CardView.tscn")

var passed_count: int = 0
var failed_count: int = 0


func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING CARD QUALITY & FUSION ENGINE TEST SUITE (Task 6.2)")
	print("==================================================")

	test_quality_tiers_and_stat_scaling()
	test_card_view_quality_shaders()
	test_fusion_recipes_loading_204()
	test_can_craft_and_execute_fusion()
	test_gold_card_fusion_recipes()
	test_deck_builder_fusion_lab_integration()

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print(">>> ALL FUSION ENGINE TESTS COMPLETED SUCCESSFULLY! <<<")
		get_tree().quit(0)
	else:
		push_error("Fusion Engine tests failed!")
		get_tree().quit(1)


func assert_true(condition: bool, msg: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % msg)
	else:
		failed_count += 1
		printerr("  [FAIL] %s" % msg)


func test_quality_tiers_and_stat_scaling() -> void:
	print("\n[Test 1] Card Quality Tiers (Standard / Gold [+10%] / Obsidian [+25%])")
	assert_true(FusionEngine.get_card_quality("Creature_Pig") == FusionEngine.QualityTier.STANDARD, "Creature_Pig is STANDARD quality")
	assert_true(FusionEngine.get_card_quality("Creature_GL_Pig") == FusionEngine.QualityTier.GOLD, "Creature_GL_Pig is GOLD quality")
	assert_true(FusionEngine.get_card_quality("Creature_OB_Pig") == FusionEngine.QualityTier.OBSIDIAN, "Creature_OB_Pig is OBSIDIAN quality")

	assert_true(is_equal_approx(FusionEngine.get_stat_multiplier(FusionEngine.QualityTier.STANDARD), 1.0), "Standard stat multiplier is 1.0")
	assert_true(is_equal_approx(FusionEngine.get_stat_multiplier(FusionEngine.QualityTier.GOLD), 1.10), "Gold stat multiplier is 1.10 (+10%)")
	assert_true(is_equal_approx(FusionEngine.get_stat_multiplier(FusionEngine.QualityTier.OBSIDIAN), 1.25), "Obsidian stat multiplier is 1.25 (+25%)")

	# Base 20 ATK / 20 DEF -> Gold (+10% = 22/22), Obsidian (+25% = 25/25)
	var std_stats = FusionEngine.compute_scaled_stats(20, 20, FusionEngine.QualityTier.STANDARD)
	var gold_stats = FusionEngine.compute_scaled_stats(20, 20, FusionEngine.QualityTier.GOLD)
	var obs_stats = FusionEngine.compute_scaled_stats(20, 20, FusionEngine.QualityTier.OBSIDIAN)

	assert_true(std_stats["atk"] == 20 and std_stats["def"] == 20, "Standard 20/20 stays 20/20")
	assert_true(gold_stats["atk"] == 22 and gold_stats["def"] == 22, "Gold (+10%) scales 20/20 -> 22/22")
	assert_true(obs_stats["atk"] == 25 and obs_stats["def"] == 25, "Obsidian (+25%) scales 20/20 -> 25/25")

	# Apply quality to card dictionary
	var pig_base = Database.get_card("Creature_Pig")
	var pig_gold = FusionEngine.apply_quality_to_card(pig_base, FusionEngine.QualityTier.GOLD)
	var pig_obs = FusionEngine.apply_quality_to_card(pig_base, FusionEngine.QualityTier.OBSIDIAN)
	assert_true(pig_gold["quality"] == FusionEngine.QualityTier.GOLD, "Upgraded card dictionary has quality = GOLD")
	assert_true(pig_gold["atk"] > pig_base["atk"] and pig_gold["def"] > pig_base["def"], "Gold card has higher ATK/DEF than Standard")
	assert_true(pig_obs["atk"] >= pig_gold["atk"] and pig_obs["def"] >= pig_gold["def"], "Obsidian card has >= stats than Gold")


func test_card_view_quality_shaders() -> void:
	print("\n[Test 2] CardView Gold Foil & Obsidian Dark Shaders")
	var cv = CardViewScene.instantiate() as CardView
	add_child(cv)

	var std_card = Database.get_card("Creature_Pig")
	cv.render_card(std_card)
	assert_true(cv.current_quality == FusionEngine.QualityTier.STANDARD, "CardView detects Standard quality")
	assert_true(cv.panel.material == null, "Standard card has no custom shader material")

	var gl_card = Database.get_card("Creature_GL_Pig")
	cv.render_card(gl_card)
	assert_true(cv.current_quality == FusionEngine.QualityTier.GOLD, "CardView detects Gold quality for Creature_GL_Pig")
	assert_true(cv.panel.material is ShaderMaterial, "Gold card applies GoldFoilShader ShaderMaterial to panel")
	assert_true(cv.title_label.text.begins_with("✨ "), "Gold card prefixes title with ✨")

	var obs_card = FusionEngine.apply_quality_to_card(std_card, FusionEngine.QualityTier.OBSIDIAN)
	cv.render_card(obs_card)
	assert_true(cv.current_quality == FusionEngine.QualityTier.OBSIDIAN, "CardView detects Obsidian quality")
	assert_true(cv.panel.material is ShaderMaterial, "Obsidian card applies ObsidianDarkShader ShaderMaterial to panel")
	assert_true(cv.title_label.text.begins_with("🔮 "), "Obsidian card prefixes title with 🔮")

	cv.queue_free()


func test_fusion_recipes_loading_204() -> void:
	print("\n[Test 3] Loading All 204 Fusion Recipes from db_Fusion.json")
	assert_true(Database.fusion_recipes_list.size() == 204, "Loaded all 204 fusion recipes from db_Fusion.json (got %d)" % Database.fusion_recipes_list.size())

	var blue_castle_rec = Database.get_fusion_recipe("Building_BlueCastle")
	assert_true(not blue_castle_rec.is_empty(), "Recipe for Building_BlueCastle exists")
	assert_true(int(blue_castle_rec.get("cost", 0)) == 95, "Building_BlueCastle fusion cost is 95 coins")
	assert_true(blue_castle_rec.get("ingredients", []).size() == 2, "Building_BlueCastle requires 2 ingredients")


func test_can_craft_and_execute_fusion() -> void:
	print("\n[Test 4] Fusion Material Validation & Crafting Execution")
	var recipe = Database.get_fusion_recipe("Building_BlueCastle")
	# Building_BlueCastle requires 1x Building_RedDome + 1x Spell_CerebralBloodstorm + 95 coins

	# 1. Missing ingredient
	var inv_missing_card = {"Building_RedDome": 1, "Spell_CerebralBloodstorm": 0}
	var check1 = FusionEngine.can_craft_recipe(recipe, inv_missing_card, 500)
	assert_true(check1["can_craft"] == false, "can_craft_recipe blocks fusion when ingredient is missing")
	assert_true(check1["missing_ingredients"].size() == 1, "Reports 1 missing ingredient")

	# 2. Missing coins
	var inv_full = {"Building_RedDome": 2, "Spell_CerebralBloodstorm": 2}
	var check2 = FusionEngine.can_craft_recipe(recipe, inv_full, 50)
	assert_true(check2["can_craft"] == false, "can_craft_recipe blocks fusion when coins are insufficient (50 < 95)")
	assert_true(check2["missing_coins"] == 45, "Reports 45 missing coins")

	# 3. Valid craft execution
	var exec_res = FusionEngine.execute_fusion(recipe, inv_full, 200)
	assert_true(exec_res["ok"] == true, "execute_fusion succeeds when materials and coins are sufficient")
	assert_true(exec_res["output_card_id"] == "Building_BlueCastle", "Output card is Building_BlueCastle")
	assert_true(exec_res["new_coins"] == 105, "Deducted 95 coins from 200 -> 105 coins remaining")
	assert_true(inv_full.get("Building_RedDome", 0) == 1, "Consumed 1 Building_RedDome (2 -> 1)")
	assert_true(inv_full.get("Spell_CerebralBloodstorm", 0) == 1, "Consumed 1 Spell_CerebralBloodstorm (2 -> 1)")
	assert_true(inv_full.get("Building_BlueCastle", 0) == 1, "Added 1 Building_BlueCastle to inventory (0 -> 1)")


func test_gold_card_fusion_recipes() -> void:
	print("\n[Test 5] Gold Card Fusion Recipes (10x Base Copies -> Gold Card)")
	var gl_pig_rec = Database.get_fusion_recipe("Creature_GL_Pig")
	assert_true(not gl_pig_rec.is_empty(), "Recipe for Creature_GL_Pig exists")
	assert_true(gl_pig_rec.get("quality") == FusionEngine.QualityTier.GOLD, "Creature_GL_Pig recipe quality is GOLD")

	var inv = {"Creature_Pig": 10}
	var res = FusionEngine.execute_fusion(gl_pig_rec, inv, 150000)
	assert_true(res["ok"] == true, "Fusing 10x Creature_Pig + 110,000 coins produces Creature_GL_Pig")
	assert_true(inv.get("Creature_Pig", 0) == 0, "All 10 duplicate Creature_Pig copies consumed")
	assert_true(inv.get("Creature_GL_Pig", 0) == 1, "Creature_GL_Pig added to owned inventory")


func test_deck_builder_fusion_lab_integration() -> void:
	print("\n[Test 6] DeckBuilder Fusion Lab Modal & GameManager Integration")
	var builder_scene = preload("res://scenes/deck_builder.tscn")
	var builder = builder_scene.instantiate() as DeckBuilder
	add_child(builder)

	builder.open_fusion_modal()
	assert_true(builder.fusion_modal.visible == true, "Fusion Lab modal opens inside DeckBuilder")
	assert_true(builder.recipe_list_vbox.get_child_count() > 0, "Fusion Lab populated recipe rows")

	# Craft Care Crow (Cost 50: 1x Creature_Cornball + 1x Creature_WanderingBaldMan)
	GameManager.player_coins = 1000
	var counts = GameManager.get_owned_card_counts()
	var before_care_crow = int(counts.get("Creature_CareCrow", 0))
	var before_cornball = int(counts.get("Creature_Cornball", 0))

	var care_crow_rec = Database.get_fusion_recipe("Creature_CareCrow")
	var craft_res = builder.craft_recipe(care_crow_rec)
	assert_true(craft_res.get("ok", false) == true, "Crafted Creature_CareCrow via DeckBuilder.craft_recipe()")
	assert_true(GameManager.player_coins == 950, "GameManager.player_coins deducted by 50 (1000 -> 950)")
	assert_true(int(counts.get("Creature_CareCrow", 0)) == before_care_crow + 1, "Owned count of Creature_CareCrow incremented by 1")
	assert_true(int(counts.get("Creature_Cornball", 0)) == before_cornball - 1, "Owned count of Creature_Cornball decremented by 1")

	builder.close_fusion_modal()
	assert_true(builder.fusion_modal.visible == false, "Fusion Lab modal closes cleanly")
	builder.queue_free()
