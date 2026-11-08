extends Node

var total_tests = 0
var passed_tests = 0

func assert_test(condition: bool, description: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("[PASS] %s" % description)
	else:
		push_error("[FAIL] %s" % description)

func _ready() -> void:
	print("==========================================")
	print("RUNNING MAIN MENU & TREEHOUSE VISUAL TESTS")
	print("==========================================")

	# 1. Instantiate Main Menu
	var main_menu_scene = load("res://scenes/main_menu.tscn")
	assert_test(main_menu_scene != null, "MainMenu scene loads successfully")

	var menu = main_menu_scene.instantiate()
	add_child(menu)
	await get_tree().process_frame

	# 2. Check 3D Treehouse Environment
	var vp = menu.get_node_or_null("ViewportContainer/SubViewport")
	assert_test(vp != null, "SubViewport for 3D treehouse exists")

	var treehouse = menu.get_node_or_null("ViewportContainer/SubViewport/TreehouseMenu3D")
	assert_test(treehouse != null, "TreehouseMenu3D instance exists inside SubViewport")

	if treehouse:
		assert_test(treehouse.has_node("FloorCeiling"), "3D FloorCeiling mesh instance exists")
		assert_test(treehouse.has_node("Furniture"), "3D Furniture mesh instance exists")
		assert_test(treehouse.has_node("Table"), "3D Table mesh instance exists")
		assert_test(treehouse.has_node("TableObjects"), "3D TableObjects snack props exist")
		assert_test(treehouse.has_node("Finn"), "3D Finn character mesh exists")
		assert_test(treehouse.has_node("Jake"), "3D Jake character mesh exists")
		assert_test(treehouse.has_node("Logo"), "3D floating Logo exists")

	# 3. Check Top Status Bar & Data Binding
	var top_bar = menu.get_node_or_null("TopBar")
	assert_test(top_bar != null, "TopBar control exists")
	if top_bar:
		var lvl = menu.level_label
		assert_test(lvl != null and lvl.text.begins_with("Lvl."), "Level label is bound ('%s')" % (lvl.text if lvl else ""))
		var xp = menu.xp_label
		assert_test(xp != null and "/" in xp.text, "XP label displays current/max ratio ('%s')" % (xp.text if xp else ""))
		var st = menu.stamina_label
		assert_test(st != null and st.text.contains("Full"), "Stamina label displays authentic full status ('%s')" % (st.text if st else ""))
		var cd = menu.cards_label
		assert_test(cd != null and "/50" in cd.text, "Card inventory label displays count ('%s')" % (cd.text if cd else ""))
		var gm = menu.gems_label
		assert_test(gm != null and gm.text.is_valid_int(), "Gems count is valid number ('%s')" % (gm.text if gm else ""))
		var cn = menu.coins_label
		assert_test(cn != null and cn.text.is_valid_int(), "Coins count is valid number ('%s')" % (cn.text if cn else ""))
		var tr = menu.trophy_label
		assert_test(tr != null and tr.text.is_valid_int(), "Trophy count is valid number ('%s')" % (tr.text if tr else ""))

	# 4. Check Bottom Dock Buttons
	assert_test(menu.settings_btn != null, "Settings dock button exists")
	assert_test(menu.dungeons_btn != null, "Daily Dungeons dock button exists")
	assert_test(menu.deck_btn != null, "Deck box dock button exists")
	assert_test(menu.store_btn != null, "Store gems dock button exists")
	assert_test(menu.chests_btn != null, "Chests dock button exists")
	assert_test(menu.battle_btn != null, "BATTLE! large red button exists")

	# 5. Check Start Overlay & Dismissal
	var start_overlay = menu.start_overlay
	assert_test(start_overlay != null and start_overlay.visible, "StartOverlay is initially visible ('Tap anywhere to Start')")
	if start_overlay:
		menu._on_start_tapped()
		await get_tree().create_timer(0.4).timeout
		assert_test(not start_overlay.visible or start_overlay.modulate.a == 0.0, "Tapping StartOverlay dismissed the prompt")

	# 6. Check Deck Choice Submenu
	assert_test(menu.deck_choice_modal != null, "DeckChoiceModal exists")
	menu._on_deck_pressed()
	assert_test(menu.deck_choice_modal.visible, "DeckChoiceModal opened on deck button press")
	menu.choice_cancel_btn.emit_signal("pressed")
	assert_test(not menu.deck_choice_modal.visible, "DeckChoiceModal closed on cancel")

	# 7. Check Authentic Quit Confirmation Modal
	var quit_modal = menu.quit_modal
	assert_test(quit_modal != null and not quit_modal.visible, "Quit modal exists and is initially hidden")
	menu._show_quit_modal()
	assert_test(quit_modal.visible, "Quit modal is visible after Esc / Quit trigger")
	assert_test(menu.quit_confirm_btn != null, "QUIT green button exists in quit modal")
	assert_test(menu.quit_cancel_btn != null, "DON'T QUIT red button exists in quit modal")
	menu._on_quit_cancel_pressed()
	assert_test(not quit_modal.visible, "Quit modal closed on DON'T QUIT press")

	# 8. Check Audio Soundtrack
	assert_test(menu.BGM_TREEHOUSE != null, "Treehouse theme BGM loaded successfully")

	print("==========================================")
	print("RESULTS: %d / %d TESTS PASSED (%.1f%%)" % [passed_tests, total_tests, float(passed_tests) / float(total_tests) * 100.0])
	print("==========================================")
	
	if passed_tests == total_tests:
		get_tree().quit(0)
	else:
		get_tree().quit(1)
