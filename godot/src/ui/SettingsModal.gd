# SettingsModal.gd
# Universal Settings & Preferences modal for Card Wars PC Remake (Task 9.1 / SYS-12).
class_name SettingsModal
extends Control

const SettingsManagerClass = preload("res://src/systems/settings_vault/SettingsManager.gd")

var manager: SettingsManagerClass

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

# Display UI
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

const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"name": &"confirm", "label": "Select / Confirm Card"},
	{"name": &"cancel", "label": "Cancel / Deselect"},
	{"name": &"end_turn", "label": "End Turn"},
	{"name": &"floop", "label": "Floop Creature"},
	{"name": &"leader_power", "label": "Activate Leader Power"}
]


func _ready() -> void:
	visible = false
	if GameManager and GameManager.settings_manager:
		manager = GameManager.settings_manager
	else:
		manager = SettingsManagerClass.new()
		add_child(manager)
		manager.load_settings()

	_setup_options()
	_populate_controls()
	_connect_events()


func open_modal() -> void:
	_sync_ui_from_manager()
	visible = true


func close_modal() -> void:
	_active_rebind_action = &""
	visible = false


func _setup_options() -> void:
	# Window Mode
	mode_option.clear()
	mode_option.add_item("Windowed", DisplayServer.WINDOW_MODE_WINDOWED)
	mode_option.add_item("Fullscreen", DisplayServer.WINDOW_MODE_FULLSCREEN)
	mode_option.add_item("Exclusive Fullscreen", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	mode_option.add_item("Maximized", DisplayServer.WINDOW_MODE_MAXIMIZED)

	# Resolutions
	res_option.clear()
	for i in range(SettingsManagerClass.RESOLUTIONS.size()):
		var r = SettingsManagerClass.RESOLUTIONS[i]
		var tag = " 🎮 Steam Deck (16:10)" if r == Vector2i(1280, 800) else ""
		res_option.add_item("%dx%d%s" % [r.x, r.y, tag], i)

	# VSync
	vsync_option.clear()
	vsync_option.add_item("Disabled", DisplayServer.VSYNC_DISABLED)
	vsync_option.add_item("Enabled (Default)", DisplayServer.VSYNC_ENABLED)
	vsync_option.add_item("Adaptive", DisplayServer.VSYNC_ADAPTIVE)
	vsync_option.add_item("Mailbox", DisplayServer.VSYNC_MAILBOX)

	# Target FPS
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
		row.add_child(label)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(160, 32)
		btn.text = _get_action_binding_text(act_name)
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
		return OS.get_keycode_string(ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode)
	elif ev is InputEventJoypadButton:
		return "Button %d" % ev.button_index
	return ev.as_text()


func _on_rebind_button_pressed(action_name: StringName, btn: Button) -> void:
	_active_rebind_action = action_name
	btn.text = "Press Any Key / Pad..."


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _active_rebind_action == &"":
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return # Ignore bare modifier keys
		manager.rebind_action(_active_rebind_action, event)
		if _rebind_buttons.has(_active_rebind_action):
			_rebind_buttons[_active_rebind_action].text = _get_action_binding_text(_active_rebind_action)
		_active_rebind_action = &""
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		manager.rebind_action(_active_rebind_action, event)
		if _rebind_buttons.has(_active_rebind_action):
			_rebind_buttons[_active_rebind_action].text = _get_action_binding_text(_active_rebind_action)
		_active_rebind_action = &""
		get_viewport().set_input_as_handled()


func _connect_events() -> void:
	master_slider.value_changed.connect(func(v):
		manager.set_bus_volume("Master", v)
		master_label.text = "%d%%" % int(v * 100)
	)
	master_mute.toggled.connect(func(m):
		manager.set_bus_mute("Master", m)
	)

	bgm_slider.value_changed.connect(func(v):
		manager.set_bus_volume("BGM", v)
		bgm_label.text = "%d%%" % int(v * 100)
	)
	bgm_mute.toggled.connect(func(m):
		manager.set_bus_mute("BGM", m)
	)

	sfx_slider.value_changed.connect(func(v):
		manager.set_bus_volume("SFX", v)
		sfx_label.text = "%d%%" % int(v * 100)
	)
	sfx_mute.toggled.connect(func(m):
		manager.set_bus_mute("SFX", m)
	)

	vo_slider.value_changed.connect(func(v):
		manager.set_bus_volume("VO", v)
		vo_label.text = "%d%%" % int(v * 100)
	)
	vo_mute.toggled.connect(func(m):
		manager.set_bus_mute("VO", m)
	)

	test_sfx_btn.pressed.connect(_on_test_sfx_pressed)

	mode_option.item_selected.connect(func(_idx):
		var val = mode_option.get_selected_id()
		manager.set_window_mode(val)
	)

	res_option.item_selected.connect(func(_idx):
		var id = res_option.get_selected_id()
		if id < SettingsManagerClass.RESOLUTIONS.size():
			manager.set_resolution(SettingsManagerClass.RESOLUTIONS[id])
	)

	vsync_option.item_selected.connect(func(_idx):
		var val = vsync_option.get_selected_id()
		manager.set_vsync_mode(val)
	)

	fps_option.item_selected.connect(func(_idx):
		var val = fps_option.get_selected_id()
		manager.set_target_fps(val)
	)

	scale_slider.value_changed.connect(func(v):
		manager.set_ui_scale(v)
		scale_label.text = "%.2fx" % v
	)

	reset_controls_btn.pressed.connect(_on_reset_controls_pressed)
	reset_all_btn.pressed.connect(_on_reset_all_pressed)
	save_close_btn.pressed.connect(_on_save_close_pressed)
	cancel_btn.pressed.connect(close_modal)


func _on_test_sfx_pressed() -> void:
	if ResourceLoader.exists("res://assets/audio/sfx/Click.wav"):
		Audio.play_sfx_with_variation(load("res://assets/audio/sfx/Click.wav"), -3.0, 0.05)


func _on_reset_controls_pressed() -> void:
	manager.reset_controls_to_defaults()
	_populate_controls()


func _on_reset_all_pressed() -> void:
	manager.reset_to_defaults()
	_sync_ui_from_manager()
	_populate_controls()


func _on_save_close_pressed() -> void:
	manager.save_settings()
	close_modal()


func _sync_ui_from_manager() -> void:
	var m_vol = manager.get_bus_volume("Master")
	master_slider.value = m_vol
	master_label.text = "%d%%" % int(m_vol * 100)
	master_mute.button_pressed = manager.is_bus_muted("Master")

	var b_vol = manager.get_bus_volume("BGM")
	bgm_slider.value = b_vol
	bgm_label.text = "%d%%" % int(b_vol * 100)
	bgm_mute.button_pressed = manager.is_bus_muted("BGM")

	var s_vol = manager.get_bus_volume("SFX")
	sfx_slider.value = s_vol
	sfx_label.text = "%d%%" % int(s_vol * 100)
	sfx_mute.button_pressed = manager.is_bus_muted("SFX")

	var v_vol = manager.get_bus_volume("VO")
	vo_slider.value = v_vol
	vo_label.text = "%d%%" % int(v_vol * 100)
	vo_mute.button_pressed = manager.is_bus_muted("VO")

	# Display options
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
