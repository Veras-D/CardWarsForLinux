# LocalizationService.gd
# Card Wars Runtime Multilingual Localization Service (Task 9.1 / SYS-13).
# Integrates with Godot TranslationServer, parses original .bytes sheets, and manages dynamic switching.
class_name LocalizationService
extends Node

const LocalizationManagerClass = preload("res://src/systems/localization_engine/LocalizationManager.gd")
const LocalizationParserClass = preload("res://src/systems/localization_engine/LocalizationParser.gd")

signal language_changed(locale_code: String, display_name: String)

var manager: LocalizationManagerClass
var _loaded_locales: Dictionary = {} # code -> bool

const SUPPORTED_LANGUAGES: Array[Dictionary] = [
	{"code": "en", "prefix": "EN", "name": "English", "native": "English"},
	{"code": "es", "prefix": "ES", "name": "Spanish", "native": "Español"},
	{"code": "es_419", "prefix": "LatAm", "name": "Spanish (Latin America)", "native": "Español (Latinoamérica)"},
	{"code": "fr", "prefix": "FR", "name": "French", "native": "Français"},
	{"code": "de", "prefix": "DE", "name": "German", "native": "Deutsch"},
	{"code": "it", "prefix": "IT", "name": "Italian", "native": "Italiano"},
	{"code": "pt", "prefix": "PT", "name": "Portuguese", "native": "Português"}
]

const SHEET_TYPES: Array[String] = [
	"Names",
	"Descriptions",
	"Menu",
	"Scenes",
	"Tutorial",
	"NIS"
]


func _ready() -> void:
	manager = LocalizationManagerClass.new()
	add_child(manager)

	# Register all supported languages
	for lang in SUPPORTED_LANGUAGES:
		manager.register_locale(lang.code, lang.name, lang.native)

	# Always load English as primary fallback
	load_language_pack("en")


## Loads and registers all .bytes translation sheets for the specified locale.
func load_language_pack(locale_code: String) -> bool:
	if _loaded_locales.get(locale_code, false):
		return true

	var lang_info: Dictionary = {}
	for item in SUPPORTED_LANGUAGES:
		if item.code == locale_code:
			lang_info = item
			break

	if lang_info.is_empty():
		push_warning("LocalizationService: Unsupported locale '%s'" % locale_code)
		return false

	var prefix = lang_info.prefix
	var combined_messages: Dictionary = {}

	for sheet in SHEET_TYPES:
		var file_path = "res://data/languages/%s_%s.bytes" % [prefix, sheet]
		if FileAccess.file_exists(file_path):
			var sheet_dict = LocalizationParserClass.parse_xml_file(file_path)
			for k in sheet_dict.keys():
				combined_messages[k] = sheet_dict[k]
				# Also register without '!!' prefix if present for flexible querying
				if k.begins_with("!!"):
					combined_messages[k.substr(2)] = sheet_dict[k]

	manager.add_messages(locale_code, combined_messages)
	_loaded_locales[locale_code] = true
	return true


## Switches the active game language dynamically at runtime.
func set_language(locale_code: String) -> bool:
	if not load_language_pack(locale_code):
		return false

	var success = manager.set_locale(locale_code)
	if success:
		var d_name = manager.get_locale_display_name(locale_code)
		language_changed.emit(locale_code, d_name)
	return success


func get_current_language() -> String:
	if manager:
		return manager.get_current_locale()
	return "en"


func get_supported_languages() -> Array[Dictionary]:
	return SUPPORTED_LANGUAGES.duplicate(true)


func translate_text(key: String, fallback: String = "") -> String:
	if manager:
		return manager.translate_key(key, fallback)
	return tr(key)
