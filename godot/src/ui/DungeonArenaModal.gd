extends Control

signal closed

const FONT_MAIN: FontFile = preload("res://assets/fonts/KBPlanetEarth.ttf")
const TEX_BTN_GREEN: Texture2D = preload("res://assets/textures/ui/store/uiButtonGreen.png")
const TEX_BTN_BLUE: Texture2D = preload("res://assets/textures/ui/store/uiButtonBlue.png")
const TEX_HEART: Texture2D = preload("res://assets/textures/ui/heart.png")
const SFX_SELECT: AudioStream = preload("res://assets/audio/sfx/UI_Select.wav")
const SFX_BACK: AudioStream = preload("res://assets/audio/sfx/UI_Back.wav")

const DUNGEON_INFO_TEXT: Dictionary = {
	"!!Monday_Dungeon_Info": "Get your Plains Cards here!",
	"!!Tuesday_Dungeon_Info": "Get your Corn Cards here!",
	"!!Wednesday_Dungeon_Info": "Get your Swamp Cards here!",
	"!!Thursday_Dungeon_Info": "Get your Cotton Cards here!",
	"!!Friday_Dungeon_Info": "Get your Sand Cards here!",
	"!!Saturday_Dungeon_Info": "Today is 2x Coins Day!",
	"!!Sunday_Dungeon_Info": "Today is 2x XP Day!",
}

@onready var dimmer: ColorRect = $Dimmer
@onready var frame: Control = $Center/Frame
@onready var close_btn: BaseButton = $Center/Frame/TitleBar/CloseBtn
@onready var dungeon_name_lbl: Label = $Center/Frame/Body/DungeonBanner/HBox/TextVBox/DungeonName
@onready var dungeon_desc_lbl: Label = $Center/Frame/Body/DungeonBanner/HBox/TextVBox/DungeonDesc
@onready var stamina_lbl: Label = $Center/Frame/Body/DungeonBanner/HBox/HeartBadge/StaminaLabel

@onready var locked_gate_panel: Control = $Center/Frame/Body/LockedGatePanel
@onready var gate_msg_lbl: Label = $Center/Frame/Body/LockedGatePanel/VBox/GateMsg
@onready var gate_sub_lbl: Label = $Center/Frame/Body/LockedGatePanel/VBox/SubMsg
@onready var gate_deck_btn: BaseButton = $Center/Frame/Body/LockedGatePanel/VBox/GateBtns/DeckBtn
@onready var gate_ok_btn: BaseButton = $Center/Frame/Body/LockedGatePanel/VBox/GateBtns/OkBtn

@onready var stages_panel: Control = $Center/Frame/Body/StagesPanel
@onready var stages_list: VBoxContainer = $Center/Frame/Body/StagesPanel/StagesList
@onready var status_label: Label = $Center/Frame/Body/StagesPanel/StatusRow/StatusLabel
@onready var refill_btn: Button = $Center/Frame/Body/StagesPanel/StatusRow/RefillBtn

var _anim_tween: Tween = null
var _is_closing: bool = false
var _force_unlocked_preview: bool = false


func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		StoreModalAnimator.attach_button_reaction(close_btn)
	if gate_ok_btn:
		gate_ok_btn.pressed.connect(_on_close_pressed)
		StoreModalAnimator.attach_button_reaction(gate_ok_btn)
	if gate_deck_btn:
		gate_deck_btn.pressed.connect(_on_deck_builder_pressed)
		StoreModalAnimator.attach_button_reaction(gate_deck_btn)
	if refill_btn:
		refill_btn.pressed.connect(_on_refill_stamina_pressed)


func open_modal(force_unlocked_preview: bool = false) -> void:
	_is_closing = false
	_force_unlocked_preview = force_unlocked_preview
	if status_label:
		status_label.text = ""
	if refill_btn:
		refill_btn.visible = false
	refresh_views()
	visible = true
	_anim_tween = StoreModalAnimator.play_open(self, dimmer, frame, _anim_tween)


func close_modal() -> void:
	if _is_closing or not visible:
		return
	_is_closing = true
	_anim_tween = StoreModalAnimator.play_close(self, dimmer, frame, _anim_tween, func():
		_is_closing = false
		closed.emit()
	)


func _play_sfx(stream: AudioStream) -> void:
	if Audio and stream:
		Audio.play_sfx(stream)


func _on_close_pressed() -> void:
	_play_sfx(SFX_BACK)
	close_modal()


func _on_deck_builder_pressed() -> void:
	_play_sfx(SFX_SELECT)
	visible = false
	GameManager.open_deck_builder()


func _on_refill_stamina_pressed() -> void:
	_play_sfx(SFX_SELECT)
	var res := GameManager.refill_stamina_with_gems()
	if bool(res.get("ok", false)):
		if status_label:
			status_label.text = "Hearts refilled to %d!" % int(res.get("stamina", 100))
			status_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
		if refill_btn:
			refill_btn.visible = false
		refresh_views()
	else:
		if status_label:
			status_label.text = str(res.get("reason", "Not enough Gems!"))
			status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))


func refresh_views() -> void:
	var dt := Time.get_date_dict_from_system()
	var today_weekday := int(dt.get("weekday", 1))
	var d_data := Database.get_dungeon_for_weekday(today_weekday)
	var d_name := str(d_data.get("dungeon", "Monday Dungeon"))
	var raw_info := str(d_data.get("info", ""))

	if dungeon_name_lbl:
		dungeon_name_lbl.text = d_name.to_upper()
	if dungeon_desc_lbl:
		dungeon_desc_lbl.text = DUNGEON_INFO_TEXT.get(raw_info, "Complete today's stages to earn special cards & rewards!")
	if stamina_lbl:
		stamina_lbl.text = "%d / %d" % [GameManager.get_stamina(), GameManager.get_max_stamina()]

	var gate := GameManager.validate_dungeon_entry()
	var entry_ok := bool(gate.get("ok", false)) or _force_unlocked_preview

	if locked_gate_panel:
		locked_gate_panel.visible = not entry_ok
	if stages_panel:
		stages_panel.visible = entry_ok

	if not entry_ok:
		if gate_msg_lbl:
			gate_msg_lbl.text = str(gate.get("reason", ""))
		if gate_sub_lbl:
			var cur_hero := GameManager.player_hero_name
			var cur_lvl := int(gate.get("level", 1))
			gate_sub_lbl.text = "Current Hero: %s (Lvl. %d / Required: Lvl. %d)" % [cur_hero, cur_lvl, GameManager.MIN_DUNGEON_LEVEL]
		return

	_populate_stages(d_name)


func _populate_stages(d_name: String) -> void:
	if not stages_list:
		return
	for c in stages_list.get_children():
		stages_list.remove_child(c)
		c.queue_free()

	var stages := Database.get_dungeon_stages(d_name)
	var max_cleared := GameManager.get_dungeon_max_cleared_stage(d_name)

	for i in range(stages.size()):
		var s: Dictionary = stages[i]
		var qid := str(s.get("quest_id", ""))
		var h_cost := int(s.get("heart_cost", 5))
		var quest := Database.get_quest(qid)
		var is_unlocked := GameManager.is_dungeon_stage_unlocked(d_name, i)
		var is_cleared := i < max_cleared

		var row := Panel.new()
		row.custom_minimum_size = Vector2(0, 56)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.11, 0.20, 0.26, 0.92) if is_unlocked else Color(0.08, 0.13, 0.17, 0.72)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.45, 0.85, 0.55, 0.85) if is_cleared else (Color(0.75, 0.86, 0.92, 0.85) if is_unlocked else Color(0.35, 0.42, 0.46, 0.6))
		sb.set_corner_radius_all(8)
		row.add_theme_stylebox_override("panel", sb)

		var hbox := HBoxContainer.new()
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 14
		hbox.offset_right = -12
		hbox.add_theme_constant_override("separation", 12)
		row.add_child(hbox)

		var opp_name := str(quest.get("opponent", "Opponent"))
		var lv := int(quest.get("leader_level", 1))
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_override("font", FONT_MAIN)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_color_override("font_color", Color.WHITE if is_unlocked else Color(0.65, 0.7, 0.74))
		var prefix := "✓ " if is_cleared else ""
		lbl.text = "%sStage %d — vs %s (Lv. %d)" % [prefix, i + 1, opp_name, lv]
		hbox.add_child(lbl)

		var cost_box := HBoxContainer.new()
		cost_box.add_theme_constant_override("separation", 4)
		var h_icon := TextureRect.new()
		h_icon.custom_minimum_size = Vector2(24, 24)
		h_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h_icon.texture = TEX_HEART
		h_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cost_box.add_child(h_icon)

		var cost_lbl := Label.new()
		cost_lbl.add_theme_font_override("font", FONT_MAIN)
		cost_lbl.add_theme_font_size_override("font_size", 20)
		cost_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		cost_lbl.add_theme_constant_override("outline_size", 4)
		cost_lbl.text = str(h_cost)
		cost_box.add_child(cost_lbl)
		hbox.add_child(cost_box)

		var play_btn := _make_stage_btn(is_unlocked, is_cleared)
		if is_unlocked:
			play_btn.pressed.connect(func(): _on_launch_stage(d_name, i, qid, h_cost))
			StoreModalAnimator.attach_button_reaction(play_btn)
		hbox.add_child(play_btn)

		stages_list.add_child(row)


func _make_stage_btn(is_unlocked: bool, is_cleared: bool) -> TextureButton:
	var btn := TextureButton.new()
	btn.custom_minimum_size = Vector2(138, 48)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not is_unlocked

	var np := NinePatchRect.new()
	np.offset_right = 276.0
	np.offset_bottom = 96.0
	np.scale = Vector2(0.5, 0.5)
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.texture = TEX_BTN_GREEN if is_unlocked else TEX_BTN_BLUE
	np.patch_margin_left = 36
	np.patch_margin_top = 28
	np.patch_margin_right = 36
	np.patch_margin_bottom = 36
	if not is_unlocked:
		np.modulate = Color(0.55, 0.6, 0.65, 0.9)
	btn.add_child(np)

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_bottom = -3
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FONT_MAIN)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.text = ("REPLAY" if is_cleared else "PLAY") if is_unlocked else "LOCKED"
	btn.add_child(lbl)
	return btn


func _on_launch_stage(dungeon_name: String, stage_index: int, quest_id: String, heart_cost: int) -> void:
	_play_sfx(SFX_SELECT)
	var res := GameManager.launch_dungeon_stage(dungeon_name, stage_index, quest_id, heart_cost)
	if not bool(res.get("ok", false)):
		var ftype := str(res.get("fail_type", ""))
		if status_label:
			status_label.text = str(res.get("reason", "Cannot start stage."))
			status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		if refill_btn:
			refill_btn.visible = (ftype == "stamina")
		return
	visible = false
