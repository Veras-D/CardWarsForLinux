extends Node

## Automated Test Suite for Task 9.1 (Settings Menu & SYS-12 settings_vault)

const SettingsManager = preload("res://src/systems/settings_vault/SettingsManager.gd")
const SettingsModal = preload("res://src/ui/SettingsModal.gd")
const TEST_CONFIG_PATH = "user://test_cardwars_settings.json"

var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING SETTINGS MENU & VAULT TEST SUITE (Task 9.1)")
	print("==================================================\n")

	_test_gamemanager_settings_init()
	_test_audio_bus_controls()
	_test_display_and_steamdeck_resolutions()
	_test_controls_remapping()
	_test_atomic_json_persistence()
	_test_settings_modal_ui()

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [_tests_passed, _tests_failed])
	print("==================================================")

	if _tests_failed == 0:
		print(">>> ALL SETTINGS MENU & VAULT TESTS COMPLETED SUCCESSFULLY! <<<\n")
		get_tree().quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		get_tree().quit(1)


func _assert_test(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s %s" % [test_name, details])


func _test_gamemanager_settings_init() -> void:
	print("[Test 1] GameManager Settings Vault Initialization")
	_assert_test(GameManager.settings_manager != null, "GameManager.settings_manager initialized on boot")
	_assert_test(GameManager.settings_manager is SettingsManager, "settings_manager is type SettingsManager")


func _test_audio_bus_controls() -> void:
	print("\n[Test 2] Audio Bus Volumes & Independent Mute States")
	var sm = GameManager.settings_manager

	sm.set_bus_volume("Master", 0.65)
	_assert_test(is_equal_approx(sm.get_bus_volume("Master"), 0.65), "Master volume set to 65%")
	_assert_test(sm.is_bus_muted("Master") == false, "Master initially unmuted")

	sm.set_bus_mute("Master", true)
	_assert_test(sm.is_bus_muted("Master") == true, "Master muted")
	sm.set_bus_mute("Master", false)
	_assert_test(sm.is_bus_muted("Master") == false, "Master unmuted")

	sm.set_bus_volume("BGM", 0.70)
	_assert_test(is_equal_approx(sm.get_bus_volume("BGM"), 0.70), "Music (BGM) set to 70%")

	sm.set_bus_volume("SFX", 0.85)
	_assert_test(is_equal_approx(sm.get_bus_volume("SFX"), 0.85), "SFX set to 85%")

	sm.set_bus_volume("VO", 0.90)
	_assert_test(is_equal_approx(sm.get_bus_volume("VO"), 0.90), "VO set to 90%")


func _test_display_and_steamdeck_resolutions() -> void:
	print("\n[Test 3] Display Window Modes, Steam Deck Resolutions, VSync & FPS")
	var sm = GameManager.settings_manager

	# Window mode
	sm.set_window_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_assert_test(sm.display_settings["window_mode"] == DisplayServer.WINDOW_MODE_WINDOWED, "Windowed mode configured")

	# Steam Deck 1280x800 resolution
	var deck_res = Vector2i(1280, 800)
	sm.set_resolution(deck_res)
	_assert_test(sm.display_settings["resolution"] == deck_res, "Steam Deck resolution (1280x800) verified")

	# 1920x1080 Full HD
	var fhd_res = Vector2i(1920, 1080)
	sm.set_resolution(fhd_res)
	_assert_test(sm.display_settings["resolution"] == fhd_res, "Full HD resolution (1920x1080) verified")

	# VSync
	sm.set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_assert_test(sm.display_settings["vsync_mode"] == DisplayServer.VSYNC_ENABLED, "VSync Enabled verified")

	# Target FPS
	sm.set_target_fps(120)
	_assert_test(sm.display_settings["target_fps"] == 120, "120 FPS limit set")
	_assert_test(Engine.max_fps == 120, "Engine.max_fps matches target")


func _test_controls_remapping() -> void:
	print("\n[Test 4] Controls Rebinding & Key Serialization")
	var sm = GameManager.settings_manager

	var key_q = InputEventKey.new()
	key_q.keycode = KEY_Q

	var ok = sm.rebind_action(&"floop", key_q)
	_assert_test(ok == true, "Rebind action 'floop' to KEY_Q succeeded")
	_assert_test(sm.custom_keybindings.has("floop"), "Custom keybindings dictionary contains 'floop'")
	_assert_test(sm.custom_keybindings["floop"]["keycode"] == KEY_Q, "Serialized keycode matches KEY_Q")

	# Reset controls
	sm.reset_controls_to_defaults()
	_assert_test(sm.custom_keybindings.is_empty(), "custom_keybindings emptied after reset")


func _test_atomic_json_persistence() -> void:
	print("\n[Test 5] Settings Atomic JSON Save & Reload")
	var sm = GameManager.settings_manager
	sm.settings_file_path = TEST_CONFIG_PATH

	sm.set_bus_volume("Master", 0.55)
	sm.set_bus_volume("BGM", 0.45)
	sm.set_resolution(Vector2i(1600, 900))
	sm.set_target_fps(60)

	var saved = sm.save_settings()
	_assert_test(saved == true, "Settings saved to disk successfully")
	_assert_test(FileAccess.file_exists(TEST_CONFIG_PATH), "Settings file exists on disk")

	# Reload into fresh instance
	var fresh_sm = SettingsManager.new()
	fresh_sm.settings_file_path = TEST_CONFIG_PATH
	var loaded = fresh_sm.load_settings()
	_assert_test(loaded == true, "Settings loaded from disk successfully")
	_assert_test(is_equal_approx(fresh_sm.get_bus_volume("Master"), 0.55), "Reloaded Master volume matches 55%")
	_assert_test(is_equal_approx(fresh_sm.get_bus_volume("BGM"), 0.45), "Reloaded BGM volume matches 45%")
	_assert_test(fresh_sm.display_settings["resolution"] == Vector2i(1600, 900), "Reloaded resolution matches 1600x900")
	_assert_test(fresh_sm.display_settings["target_fps"] == 60, "Reloaded target FPS matches 60")

	DirAccess.remove_absolute(TEST_CONFIG_PATH)
	fresh_sm.free()


func _test_settings_modal_ui() -> void:
	print("\n[Test 6] SettingsModal UI Lifecycle")
	var modal_scene = load("res://scenes/settings_modal.tscn").instantiate()
	add_child(modal_scene)

	_assert_test(modal_scene.visible == false, "SettingsModal starts hidden")
	modal_scene.open_modal()
	_assert_test(modal_scene.visible == true, "SettingsModal visible after open_modal()")

	# Sliders and controls populated
	_assert_test(modal_scene.master_slider != null, "Master slider connected")
	_assert_test(modal_scene.bgm_slider != null, "BGM slider connected")
	_assert_test(modal_scene.sfx_slider != null, "SFX slider connected")
	_assert_test(modal_scene.vo_slider != null, "VO slider connected")
	_assert_test(modal_scene.res_option.get_item_count() >= 6, "Resolution dropdown populated with >= 6 resolutions")
	_assert_test(modal_scene.mode_option.get_item_count() >= 4, "Window mode dropdown populated with >= 4 modes")
	_assert_test(modal_scene.rebind_list.get_child_count() == 5, "Rebind list populated with 5 game actions")

	modal_scene.close_modal()
	_assert_test(modal_scene.visible == false, "SettingsModal hidden after close_modal()")

	modal_scene.queue_free()
