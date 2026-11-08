extends Node

## Automated Test Suite for Task 9.1 (Multilingual Localization System & SYS-13)

var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING MULTILINGUAL LOCALIZATION TEST SUITE (Task 9.1)")
	print("==================================================\n")

	_test_localization_autoload_init()
	_test_supported_languages_list()
	_test_english_translation_lookup()
	_test_spanish_runtime_switching()
	_test_german_and_french_switching()
	_test_card_descriptions_localization()
	_test_settings_modal_language_dropdown()

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [_tests_passed, _tests_failed])
	print("==================================================")

	if _tests_failed == 0:
		print(">>> ALL MULTILINGUAL LOCALIZATION TESTS COMPLETED SUCCESSFULLY! <<<\n")
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


func _test_localization_autoload_init() -> void:
	print("[Test 1] LocalizationService Autoload Initialization")
	_assert_test(Localization != null, "Localization autoload initialized")
	_assert_test(Localization.get_current_language() == "en", "Default active language is 'en'")


func _test_supported_languages_list() -> void:
	print("\n[Test 2] Supported Languages Catalog (7 Official Languages)")
	var langs = Localization.get_supported_languages()
	_assert_test(langs.size() == 7, "Catalog contains 7 supported languages")

	var codes = []
	for l in langs:
		codes.append(l.code)
	_assert_test(codes.has("en"), "English (en) supported")
	_assert_test(codes.has("es"), "Spanish (es) supported")
	_assert_test(codes.has("es_419"), "Latin American Spanish (es_419) supported")
	_assert_test(codes.has("fr"), "French (fr) supported")
	_assert_test(codes.has("de"), "German (de) supported")
	_assert_test(codes.has("it"), "Italian (it) supported")
	_assert_test(codes.has("pt"), "Portuguese (pt) supported")


func _test_english_translation_lookup() -> void:
	print("\n[Test 3] English Translation Lookup (Names & Menu)")
	Localization.set_language("en")

	var leader_name = tr("!!LEADER_FINNPAJAMA")
	_assert_test(leader_name == "Pajama Finn", "!!LEADER_FINNPAJAMA translates to 'Pajama Finn' (got '%s')" % leader_name)

	var gunter_name = tr("!!LEADER_GUNTER")
	_assert_test(gunter_name == "Gunter", "!!LEADER_GUNTER translates to 'Gunter' (got '%s')" % gunter_name)


func _test_spanish_runtime_switching() -> void:
	print("\n[Test 4] Spanish Dynamic Runtime Switching (es & es_419)")
	var switched_es = Localization.set_language("es")
	_assert_test(switched_es == true, "Switched to Spanish ('es')")
	_assert_test(Localization.get_current_language() == "es", "Active language is 'es'")

	# Verify translated text in Spanish
	var es_quest_condition = tr("!!QUESTCONDITION_MAXFLOOP0")
	_assert_test(es_quest_condition != "" and es_quest_condition != "!!QUESTCONDITION_MAXFLOOP0", "Spanish quest condition translated: '%s'" % es_quest_condition)

	# Latin America Spanish
	var switched_latam = Localization.set_language("es_419")
	_assert_test(switched_latam == true, "Switched to Latin American Spanish ('es_419')")
	_assert_test(Localization.get_current_language() == "es_419", "Active language is 'es_419'")


func _test_german_and_french_switching() -> void:
	print("\n[Test 5] German (de) and French (fr) Runtime Switching")
	Localization.set_language("de")
	_assert_test(Localization.get_current_language() == "de", "Active language is 'de'")
	var de_text = tr("!!QUESTCONDITION_MAXFLOOP0")
	_assert_test(de_text != "" and de_text != "!!QUESTCONDITION_MAXFLOOP0", "German translation resolved: '%s'" % de_text)

	Localization.set_language("fr")
	_assert_test(Localization.get_current_language() == "fr", "Active language is 'fr'")
	var fr_text = tr("!!QUESTCONDITION_MAXFLOOP0")
	_assert_test(fr_text != "" and fr_text != "!!QUESTCONDITION_MAXFLOOP0", "French translation resolved: '%s'" % fr_text)

	# Reset back to English
	Localization.set_language("en")


func _test_card_descriptions_localization() -> void:
	print("\n[Test 6] Card Descriptions Localization & Tag Resolution")
	Localization.set_language("en")
	var en_desc = tr("!!BUILDING_FRUITCAKE")
	_assert_test(en_desc.contains("Defense"), "English description contains 'Defense' (got '%s')" % en_desc)

	Localization.set_language("es")
	var es_desc = tr("!!BUILDING_FRUITCAKE")
	_assert_test(es_desc.contains("Defensa") or es_desc.contains("defensa"), "Spanish description contains 'Defensa' (got '%s')" % es_desc)

	Localization.set_language("en")


func _test_settings_modal_language_dropdown() -> void:
	print("\n[Test 7] SettingsModal Language Dropdown Integration")
	var modal_scene = load("res://scenes/settings_modal.tscn").instantiate()
	add_child(modal_scene)

	modal_scene.open_modal()
	_assert_test(modal_scene.lang_option != null, "Language option dropdown exists in modal")
	_assert_test(modal_scene.lang_option.get_item_count() == 7, "Language option contains 7 items")

	# Select Spanish in dropdown
	modal_scene.lang_option.selected = 1 # Spanish
	modal_scene.lang_option.item_selected.emit(1)
	_assert_test(Localization.get_current_language() == "es", "Language switched to 'es' on dropdown selection")

	# Close and clean up
	modal_scene.close_modal()
	modal_scene.queue_free()
	Localization.set_language("en")
