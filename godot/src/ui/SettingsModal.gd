# SettingsModal.gd
# Card Wars styled Options & Preferences modal (Audio, Display, Controls).
class_name SettingsModal
extends Control

const SettingsManagerClass = preload("res://src/systems/settings_vault/SettingsManager.gd")
const FONT_KB := preload("res://assets/fonts/KBPlanetEarth.ttf")
const TEX_GEAR := preload("res://assets/textures/ui/UI_Gear.png")
const TEX_BTN_BLUE := preload("res://assets/textures/ui/forge/uiButtonBlue.png")
const SFX_SELECT := preload("res://assets/audio/sfx/UI_Select.wav")
const SFX_BACK := preload("res://assets/audio/sfx/UI_Back.wav")
const SFX_CLICK := preload("res://assets/audio/sfx/ButtonClick5.wav")

var manager: SettingsManagerClass

@onready var dark_overlay: ColorRect = get_node_or_null("DarkOverlay")
@onready var panel_root: Control = get_node_or_null("OptionsCanvas/PanelRoot")
@onready var close_btn: TextureButton = get_node_or_null("OptionsCanvas/PanelRoot/CloseBtn")

@onready var audio_tab_btn: TextureButton = get_node_or_null("OptionsCanvas/PanelRoot/TabsBar/AudioTabBtn")
@onready var audio_tab_scale: Control = get_node_or_null("OptionsCanvas/PanelRoot/TabsBar/AudioTabBtn/ScaleRoot")
@onready var display_tab_btn: TextureButton = get_node_or_null("OptionsCanvas/PanelRoot/TabsBar/DisplayTabBtn")
@onready var display_tab_scale: Control = get_node_or_null("OptionsCanvas/PanelRoot/TabsBar/DisplayTabBtn/ScaleRoot")
@onready var controls_tab_btn: TextureButton = get_node_or_null("OptionsCanvas/PanelRoot/TabsBar/ControlsTabBtn")
@onready var controls_tab_scale: Control = get_node_or_null("OptionsCanvas/PanelRoot/TabsBar/ControlsTabBtn/ScaleRoot")

@onready var audio_page: Control = get_node_or_null("OptionsCanvas/PanelRoot/ContentFrame/AudioPage")
@onready var display_page: Control = get_node_or_null("OptionsCanvas/PanelRoot/ContentFrame/DisplayPage")
@onready var controls_page: Control = get_node_or_null("OptionsCanvas/PanelRoot/ContentFrame/ControlsPage")

# Audio UI
@onready var master_slider: HSlider = %MasterSlider
@onready var master_label: Label = %MasterLabel
@onready var master_mute: CheckBox = %MasterMute

@onready var bgm_slider: HSlider = %BgmSlider
@onready var bgm_label: Label = %BgmLabel
@onready var bgm_mute: CheckBox = %BgmMute

@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_label: Label = %SfxLabel
@onready var sfx_mute: CheckBox = %SfxMute

@onready var vo_slider: HSlider = %VoSlider
@onready var vo_label: Label = %VoLabel
@onready var vo_mute: CheckBox = %VoMute

@onready var test_sfx_btn: Button = %TestSfxBtn
@onready var test_vo_btn: Button = %TestVoBtn

# Display UI
@onready var lang_option: OptionButton = %LangOption
@onready var mode_option: OptionButton = %ModeOption
@onready var res_option: OptionButton = %ResOption
@onready var vsync_option: OptionButton = %VsyncOption
@onready var fps_option: OptionButton = %FpsOption
@onready var scale_slider: HSlider = %ScaleSlider
@onready var scale_label: Label = %ScaleLabel

# Controls UI
@onready var rebind_list: VBoxContainer = %RebindList
@onready var reset_controls_btn: Button = %ResetControlsBtn

# Bottom Action Buttons
@onready var reset_all_btn: Button = %ResetAllBtn
@onready var save_close_btn: Button = %SaveCloseBtn
@onready var cancel_btn: Button = %CancelBtn

var _active_rebind_action: StringName = &""
var _rebind_buttons: Dictionary = {} # action_name -> Button
var _updating_ui: bool = false
var _active_tab: int = 0
var _snapshot: Dictionary = {}
var _gear_thumb_tex: Texture2D = null

const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"name": &"confirm", "label": "Select / Confirm Card", "key": KEY_ENTER},
	{"name": &"cancel", "label": "Cancel / Deselect", "key": KEY_ESCAPE},
	{"name": &"end_turn", "label": "End Turn", "key": KEY_E},
	{"name": &"floop", "label": "Floop Creature", "key": KEY_F},
	{"name": &"leader_power", "label": "Activate Leader Power", "key": KEY_Q}
]


func _ready() -> void:
	visible = false
	if GameManager and GameManager.settings_manager:
		manager = GameManager.settings_manager
	else:
		manager = SettingsManagerClass.new()
		add_child(manager)
		if not manager.load_settings():
			manager.apply_audio_settings()

	_ensure_default_actions()
	_apply_card_wars_styling()
	_setup_options()
	_populate_controls()
	_connect_events()


func open_modal() -> void:
	_ensure_default_actions()
	_capture_snapshot()
	_sync_ui_from_manager()
	_select_tab(0, false)
	visible = true

	if dark_overlay:
		dark_overlay.color.a = 0.0
		create_tween().tween_property(dark_overlay, "color:a", 0.58, 0.22)
	if panel_root:
		panel_root.scale = Vector2(0.05, 0.05)
		panel_root.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(panel_root, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel_root, "modulate:a", 1.0, 0.2)


func close_modal() -> void:
	_active_rebind_action = &""
	visible = false


# ==============================================================================
# CARD WARS VISUAL STYLING
# ==============================================================================

func _apply_card_wars_styling() -> void:
	_gear_thumb_tex = _build_scaled_gear_texture(Vector2i(54, 58))
	for s in [master_slider, bgm_slider, sfx_slider, vo_slider, scale_slider]:
		if s:
			_style_cw_slider(s)

	for cb in [master_mute, bgm_mute, sfx_mute, vo_mute]:
		if cb:
			_style_cw_mute_checkbox(cb)

	for ob in [lang_option, mode_option, res_option, vsync_option, fps_option]:
		if ob:
			_style_cw_option_button(ob)


func _build_scaled_gear_texture(target_sz: Vector2i) -> Texture2D:
	if TEX_GEAR == null:
		return null
	var img := TEX_GEAR.get_image()
	if img == null:
		return TEX_GEAR
	var resized := img.duplicate() as Image
	resized.resize(target_sz.x, target_sz.y, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(resized)


func _style_cw_slider(slider: HSlider) -> void:
	if _gear_thumb_tex:
		slider.add_theme_icon_override("grabber", _gear_thumb_tex)
		slider.add_theme_icon_override("grabber_highlight", _gear_thumb_tex)
		slider.add_theme_icon_override("grabber_disabled", _gear_thumb_tex)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.18, 0.14, 0.10, 0.95)
	track.border_width_left = 3
	track.border_width_top = 3
	track.border_width_right = 3
	track.border_width_bottom = 3
	track.border_color = Color(0.06, 0.04, 0.03, 1.0)
	track.set_corner_radius_all(12)
	track.content_margin_top = 12
	track.content_margin_bottom = 12
	slider.add_theme_stylebox_override("slider", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.0, 0.576, 0.925, 1.0)
	fill.border_width_left = 3
	fill.border_width_top = 3
	fill.border_width_right = 3
	fill.border_width_bottom = 3
	fill.border_color = Color(0.04, 0.25, 0.42, 1.0)
	fill.set_corner_radius_all(10)
	fill.content_margin_top = 10
	fill.content_margin_bottom = 10
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)


func _style_cw_mute_checkbox(cb: CheckBox) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.24, 0.19, 0.14, 0.95)
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.border_color = Color(0.06, 0.04, 0.03, 1.0)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.34, 0.27, 0.20, 0.98)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.76, 0.19, 0.15, 0.98)
	pressed.border_color = Color(0.28, 0.04, 0.04, 1.0)

	var hover_pressed := pressed.duplicate() as StyleBoxFlat
	hover_pressed.bg_color = Color(0.86, 0.24, 0.18, 1.0)

	var empty_icon := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for icon_name in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		cb.add_theme_icon_override(icon_name, empty_icon)

	cb.alignment = HORIZONTAL_ALIGNMENT_CENTER
	cb.add_theme_stylebox_override("normal", normal)
	cb.add_theme_stylebox_override("hover", hover)
	cb.add_theme_stylebox_override("pressed", pressed)
	cb.add_theme_stylebox_override("hover_pressed", hover_pressed)
	cb.add_theme_stylebox_override("focus", hover)


func _refresh_mute_button_text(cb: CheckBox) -> void:
	if cb:
		cb.text = "Muted" if cb.button_pressed else "Mute"


func _style_cw_option_button(ob: OptionButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.34, 0.50, 0.98)
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.border_color = Color(0.05, 0.12, 0.18, 1.0)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.44, 0.64, 1.0)

	ob.add_theme_stylebox_override("normal", normal)
	ob.add_theme_stylebox_override("hover", hover)
	ob.add_theme_stylebox_override("pressed", hover)
	ob.add_theme_stylebox_override("focus", hover)

	var popup := ob.get_popup()
	if popup:
		var panel_sb := StyleBoxFlat.new()
		panel_sb.bg_color = Color(0.10, 0.20, 0.28, 0.98)
		panel_sb.border_width_left = 3
		panel_sb.border_width_top = 3
		panel_sb.border_width_right = 3
		panel_sb.border_width_bottom = 3
		panel_sb.border_color = Color(0.04, 0.08, 0.12, 1.0)
		panel_sb.set_corner_radius_all(10)
		popup.add_theme_stylebox_override("panel", panel_sb)
		popup.add_theme_font_override("font", FONT_KB)
		popup.add_theme_font_size_override("font_size", 24)
		popup.add_theme_color_override("font_color", Color.WHITE)
		popup.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.45))


# ==============================================================================
# TABS & INPUT DEFAULTS
# ==============================================================================

func _select_tab(tab_idx: int, play_sfx: bool = true) -> void:
	if _active_tab == tab_idx and play_sfx:
		return
	if play_sfx:
		_play_sfx(SFX_SELECT)
	_active_tab = tab_idx
	if audio_page:
		audio_page.visible = (tab_idx == 0)
	if display_page:
		display_page.visible = (tab_idx == 1)
	if controls_page:
		controls_page.visible = (tab_idx == 2)

	var tabs: Array = [audio_tab_scale, display_tab_scale, controls_tab_scale]
	for i in range(tabs.size()):
		var sr := tabs[i] as Control
		if sr == null:
			continue
		var selected := (i == tab_idx)
		sr.scale = Vector2(1.06, 1.06) if selected else Vector2(0.95, 0.95)
		sr.modulate = Color.WHITE if selected else Color(0.76, 0.76, 0.76, 1.0)


func _ensure_default_actions() -> void:
	for spec in REBINDABLE_ACTIONS:
		var act := spec["name"] as StringName
		if not InputMap.has_action(act):
			InputMap.add_action(act)
		if InputMap.action_get_events(act).is_empty():
			var ev := InputEventKey.new()
			ev.keycode = int(spec["key"]) as Key
			ev.physical_keycode = int(spec["key"]) as Key
			InputMap.action_add_event(act, ev)
			if manager and not manager._default_keybindings.has(str(act)):
				var ser := SettingsManagerClass.serialize_input_event(ev)
				if not ser.is_empty():
					manager._default_keybindings[str(act)] = [ser]


func _setup_options() -> void:
	if lang_option and Localization:
		lang_option.clear()
		var langs = Localization.get_supported_languages()
		for i in range(langs.size()):
			var item = langs[i]
			lang_option.add_item("%s (%s)" % [item.name, item.native], i)
			lang_option.set_item_metadata(i, item.code)

	mode_option.clear()
	mode_option.add_item("Windowed", DisplayServer.WINDOW_MODE_WINDOWED)
	mode_option.add_item("Fullscreen", DisplayServer.WINDOW_MODE_FULLSCREEN)
	mode_option.add_item("Exclusive Fullscreen", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	mode_option.add_item("Maximized", DisplayServer.WINDOW_MODE_MAXIMIZED)

	res_option.clear()
	for i in range(SettingsManagerClass.RESOLUTIONS.size()):
		var r = SettingsManagerClass.RESOLUTIONS[i]
		var tag = " (Steam Deck)" if r == Vector2i(1280, 800) else ""
		res_option.add_item("%dx%d%s" % [r.x, r.y, tag], i)

	vsync_option.clear()
	vsync_option.add_item("Disabled", DisplayServer.VSYNC_DISABLED)
	vsync_option.add_item("Enabled (Default)", DisplayServer.VSYNC_ENABLED)
	vsync_option.add_item("Adaptive", DisplayServer.VSYNC_ADAPTIVE)
	vsync_option.add_item("Mailbox", DisplayServer.VSYNC_MAILBOX)

	fps_option.clear()
	fps_option.add_item("30 FPS", 30)
	fps_option.add_item("60 FPS", 60)
	fps_option.add_item("120 FPS", 120)
	fps_option.add_item("144 FPS", 144)
	fps_option.add_item("Unlimited", 0)


func _populate_controls() -> void:
	for child in rebind_list.get_children():
		child.queue_free()
	_rebind_buttons.clear()

	for item in REBINDABLE_ACTIONS:
		var act_name = item.name as StringName
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label = Label.new()
		label.text = item.label
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_override("font", FONT_KB)
		label.add_theme_font_size_override("font_size", 30)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 7)
		row.add_child(label)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(280, 54)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.text = _get_action_binding_text(act_name)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.42, 0.64, 0.98)
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 4
		sb.border_color = Color(0.03, 0.11, 0.18, 1.0)
		sb.set_corner_radius_all(12)
		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = Color(0.12, 0.52, 0.78, 1.0)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb_hover)
		btn.add_theme_stylebox_override("focus", sb_hover)
		btn.add_theme_font_override("font", FONT_KB)
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_outline_color", Color.BLACK)
		btn.add_theme_constant_override("outline_size", 6)
		btn.pressed.connect(_on_rebind_button_pressed.bind(act_name, btn))
		row.add_child(btn)

		_rebind_buttons[act_name] = btn
		rebind_list.add_child(row)


func _get_action_binding_text(action_name: StringName) -> String:
	if not InputMap.has_action(action_name):
		return "Unbound"
	var events = InputMap.action_get_events(action_name)
	if events.is_empty():
		return "Unbound"
	var ev = events[0]
	if ev is InputEventKey:
		var k: Key = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		var k_str := OS.get_keycode_string(k)
		return k_str if k_str != "" else "Key %d" % k
	elif ev is InputEventJoypadButton:
		return "Pad Button %d" % ev.button_index
	return ev.as_text()


func _on_rebind_button_pressed(action_name: StringName, btn: Button) -> void:
	_play_sfx(SFX_CLICK)
	_active_rebind_action = action_name
	btn.text = "Press Any Key..."


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _active_rebind_action == &"":
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_on_cancel_pressed()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return
		_play_sfx(SFX_SELECT)
		manager.rebind_action(_active_rebind_action, event)
		if _rebind_buttons.has(_active_rebind_action):
			_rebind_buttons[_active_rebind_action].text = _get_action_binding_text(_active_rebind_action)
		_active_rebind_action = &""
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		_play_sfx(SFX_SELECT)
		manager.rebind_action(_active_rebind_action, event)
		if _rebind_buttons.has(_active_rebind_action):
			_rebind_buttons[_active_rebind_action].text = _get_action_binding_text(_active_rebind_action)
		_active_rebind_action = &""
		get_viewport().set_input_as_handled()


# ==============================================================================
# SNAPSHOT / REVERT ON CANCEL
# ==============================================================================

func _capture_snapshot() -> void:
	_snapshot = {
		"audio": manager.audio_settings.duplicate(true),
		"display": manager.display_settings.duplicate(true),
		"controls": manager.custom_keybindings.duplicate(true),
		"lang": Localization.get_current_language() if Localization else str(manager.display_settings.get("language", "en")),
	}


func _restore_snapshot() -> void:
	if _snapshot.is_empty():
		return
	var a_data: Dictionary = _snapshot.get("audio", {})
	for bus_name in a_data.keys():
		var b: Dictionary = a_data[bus_name]
		manager.set_bus_volume(str(bus_name), float(b.get("volume", 0.8)))
		manager.set_bus_mute(str(bus_name), bool(b.get("muted", false)))

	var d_data: Dictionary = _snapshot.get("display", {})
	if d_data.has("window_mode"):
		manager.set_window_mode(int(d_data["window_mode"]))
	if d_data.has("resolution"):
		manager.set_resolution(d_data["resolution"])
	if d_data.has("vsync_mode"):
		manager.set_vsync_mode(int(d_data["vsync_mode"]))
	if d_data.has("target_fps"):
		manager.set_target_fps(int(d_data["target_fps"]))
	if d_data.has("ui_scale"):
		manager.set_ui_scale(float(d_data["ui_scale"]))

	var prev_lang := str(_snapshot.get("lang", "en"))
	manager.display_settings["language"] = prev_lang
	if Localization and Localization.get_current_language() != prev_lang:
		Localization.set_language(prev_lang)

	manager.reset_controls_to_defaults()
	var prev_controls: Dictionary = _snapshot.get("controls", {})
	for act_str in prev_controls.keys():
		var ev := SettingsManagerClass.deserialize_input_event(prev_controls[act_str])
		if ev:
			manager.rebind_action(StringName(act_str), ev)
	_populate_controls()


# ==============================================================================
# EVENTS & UI SYNC
# ==============================================================================

func _connect_events() -> void:
	if audio_tab_btn:
		audio_tab_btn.pressed.connect(func(): _select_tab(0))
	if display_tab_btn:
		display_tab_btn.pressed.connect(func(): _select_tab(1))
	if controls_tab_btn:
		controls_tab_btn.pressed.connect(func(): _select_tab(2))
	if close_btn:
		close_btn.pressed.connect(_on_cancel_pressed)

	master_slider.value_changed.connect(func(v):
		if _updating_ui: return
		manager.set_bus_volume("Master", v)
		master_label.text = "%d%%" % roundi(v * 100.0)
	)
	master_mute.toggled.connect(func(m):
		_refresh_mute_button_text(master_mute)
		if _updating_ui: return
		manager.set_bus_mute("Master", m)
	)

	bgm_slider.value_changed.connect(func(v):
		if _updating_ui: return
		manager.set_bus_volume("BGM", v)
		bgm_label.text = "%d%%" % roundi(v * 100.0)
	)
	bgm_mute.toggled.connect(func(m):
		_refresh_mute_button_text(bgm_mute)
		if _updating_ui: return
		manager.set_bus_mute("BGM", m)
	)

	sfx_slider.value_changed.connect(func(v):
		if _updating_ui: return
		manager.set_bus_volume("SFX", v)
		sfx_label.text = "%d%%" % roundi(v * 100.0)
	)
	sfx_mute.toggled.connect(func(m):
		_refresh_mute_button_text(sfx_mute)
		if _updating_ui: return
		manager.set_bus_mute("SFX", m)
	)

	vo_slider.value_changed.connect(func(v):
		if _updating_ui: return
		manager.set_bus_volume("VO", v)
		vo_label.text = "%d%%" % roundi(v * 100.0)
	)
	vo_mute.toggled.connect(func(m):
		_refresh_mute_button_text(vo_mute)
		if _updating_ui: return
		manager.set_bus_mute("VO", m)
	)

	test_sfx_btn.pressed.connect(_on_test_sfx_pressed)
	if test_vo_btn:
		test_vo_btn.pressed.connect(_on_test_vo_pressed)

	if lang_option:
		lang_option.item_selected.connect(func(idx):
			if _updating_ui: return
			var code = str(lang_option.get_item_metadata(idx))
			if Localization:
				Localization.set_language(code)
			manager.display_settings["language"] = code
		)

	mode_option.item_selected.connect(func(_idx):
		if _updating_ui: return
		manager.set_window_mode(mode_option.get_selected_id())
	)

	res_option.item_selected.connect(func(_idx):
		if _updating_ui: return
		var id = res_option.get_selected_id()
		if id < SettingsManagerClass.RESOLUTIONS.size():
			manager.set_resolution(SettingsManagerClass.RESOLUTIONS[id])
	)

	vsync_option.item_selected.connect(func(_idx):
		if _updating_ui: return
		manager.set_vsync_mode(vsync_option.get_selected_id())
	)

	fps_option.item_selected.connect(func(_idx):
		if _updating_ui: return
		manager.set_target_fps(fps_option.get_selected_id())
	)

	scale_slider.value_changed.connect(func(v):
		if _updating_ui: return
		manager.set_ui_scale(v)
		scale_label.text = "%.2fx" % v
	)

	reset_controls_btn.pressed.connect(_on_reset_controls_pressed)
	reset_all_btn.pressed.connect(_on_reset_all_pressed)
	save_close_btn.pressed.connect(_on_save_close_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)


func _on_test_sfx_pressed() -> void:
	if Audio:
		if ResourceLoader.exists("res://assets/audio/sfx/ButtonClick5.wav"):
			Audio.play_sfx(SFX_CLICK)
		elif ResourceLoader.exists("res://assets/audio/sfx/Click.wav"):
			Audio.play_sfx_with_variation(load("res://assets/audio/sfx/Click.wav"), -3.0, 0.05)


func _on_test_vo_pressed() -> void:
	if Audio:
		var sample_path := "res://assets/audio/vo/Finn_Floop_Ability_1.wav"
		if ResourceLoader.exists(sample_path):
			Audio.play_voice(load(sample_path))


func _on_reset_controls_pressed() -> void:
	_play_sfx(SFX_CLICK)
	manager.reset_controls_to_defaults()
	_populate_controls()


func _on_reset_all_pressed() -> void:
	_play_sfx(SFX_CLICK)
	manager.reset_to_defaults()
	if Localization:
		Localization.set_language("en")
	_sync_ui_from_manager()
	_populate_controls()


func _on_cancel_pressed() -> void:
	_play_sfx(SFX_BACK)
	_restore_snapshot()
	close_modal()


func _on_save_close_pressed() -> void:
	_play_sfx(SFX_SELECT)
	manager.save_settings()
	close_modal()


func _sync_ui_from_manager() -> void:
	_updating_ui = true
	var m_vol = manager.get_bus_volume("Master")
	master_slider.value = m_vol
	master_label.text = "%d%%" % roundi(m_vol * 100.0)
	master_mute.button_pressed = manager.is_bus_muted("Master")
	_refresh_mute_button_text(master_mute)

	var b_vol = manager.get_bus_volume("BGM")
	bgm_slider.value = b_vol
	bgm_label.text = "%d%%" % roundi(b_vol * 100.0)
	bgm_mute.button_pressed = manager.is_bus_muted("BGM")
	_refresh_mute_button_text(bgm_mute)

	var s_vol = manager.get_bus_volume("SFX")
	sfx_slider.value = s_vol
	sfx_label.text = "%d%%" % roundi(s_vol * 100.0)
	sfx_mute.button_pressed = manager.is_bus_muted("SFX")
	_refresh_mute_button_text(sfx_mute)

	var v_vol = manager.get_bus_volume("VO")
	vo_slider.value = v_vol
	vo_label.text = "%d%%" % roundi(v_vol * 100.0)
	vo_mute.button_pressed = manager.is_bus_muted("VO")
	_refresh_mute_button_text(vo_mute)

	if lang_option and Localization:
		var cur_lang = Localization.get_current_language()
		for i in range(lang_option.item_count):
			if str(lang_option.get_item_metadata(i)) == cur_lang:
				lang_option.selected = i
				break

	var cur_mode = int(manager.display_settings.get("window_mode", DisplayServer.WINDOW_MODE_WINDOWED))
	for i in range(mode_option.item_count):
		if mode_option.get_item_id(i) == cur_mode:
			mode_option.selected = i
			break

	var cur_res = manager.display_settings.get("resolution", Vector2i(1280, 720))
	for i in range(SettingsManagerClass.RESOLUTIONS.size()):
		if SettingsManagerClass.RESOLUTIONS[i] == cur_res:
			res_option.selected = i
			break

	var cur_vsync = int(manager.display_settings.get("vsync_mode", DisplayServer.VSYNC_ENABLED))
	for i in range(vsync_option.item_count):
		if vsync_option.get_item_id(i) == cur_vsync:
			vsync_option.selected = i
			break

	var cur_fps = int(manager.display_settings.get("target_fps", 60))
	for i in range(fps_option.item_count):
		if fps_option.get_item_id(i) == cur_fps:
			fps_option.selected = i
			break

	var cur_scale = float(manager.display_settings.get("ui_scale", 1.0))
	scale_slider.value = cur_scale
	scale_label.text = "%.2fx" % cur_scale
	_updating_ui = false


func show_panel_preview(mode: String) -> void:
	if mode == "settings_display":
		_select_tab(1, false)
	elif mode == "settings_controls":
		_select_tab(2, false)
	else:
		_select_tab(0, false)


func _play_sfx(stream: AudioStream) -> void:
	if Audio and stream:
		Audio.play_sfx(stream)
