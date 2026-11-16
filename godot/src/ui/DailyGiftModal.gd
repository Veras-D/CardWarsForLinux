extends Control
class_name DailyGiftModal

signal closed
signal reward_granted
signal open_store_gems_requested

const FONT_MAIN: FontFile = preload("res://assets/fonts/KBPlanetEarth.ttf")
const CardViewScene: PackedScene = preload("res://scenes/components/CardView.tscn")

const TEX_COIN: Texture2D = preload("res://assets/textures/ui/store/UI_Coin_Icon.png")
const TEX_GEM: Texture2D = preload("res://assets/textures/ui/store/GsGems.png")
const TEX_CARD_SHEET: Texture2D = preload("res://assets/textures/chests/low_Chest_Card.png")

const SFX_SELECT: AudioStream = preload("res://assets/audio/sfx/UI_Select.wav")
const SFX_BACK: AudioStream = preload("res://assets/audio/sfx/UI_Back.wav")
const SFX_SPINNER_NOTE: AudioStream = preload("res://assets/audio/sfx/SFX_Gift_Spinner_Note.wav")
const SFX_REWARD: AudioStream = preload("res://assets/audio/sfx/TrickOrTreat.wav")

# Wheel timing constants modeled on DailyGiftController.cs (startSpeed -> endSpeed)
const START_SPEED: float = 0.05
const END_SPEED: float = 0.42
const SPEED_DURATION: float = 4.2
const NUM_CELLS: int = 12
const PITCH_RANGE: float = 0.1

# Perimeter coordinates (x, y offsets inside 728x432 WheelArea for 4x4 outer ring)
const CELL_SLOTS: Array[Vector2] = [
	Vector2(18, 12), Vector2(194, 12), Vector2(370, 12), Vector2(546, 12),
	Vector2(546, 114), Vector2(546, 216),
	Vector2(546, 318), Vector2(370, 318), Vector2(194, 318), Vector2(18, 318),
	Vector2(18, 216), Vector2(18, 114),
]

@onready var dimmer: ColorRect = $Dimmer
@onready var frame: Control = $Center/Frame
@onready var close_btn: BaseButton = $Center/Frame/TitleBar/CloseBtn
@onready var cells_layer: Control = $Center/Frame/Body/WheelArea/CellsLayer
@onready var status_label: Label = $Center/Frame/Body/WheelArea/CenterBox/StatusLabel
@onready var timer_label: Label = $Center/Frame/Body/WheelArea/CenterBox/TimerLabel
@onready var spin_btn: BaseButton = $Center/Frame/Body/WheelArea/CenterBox/SpinBtn
@onready var spin_btn_label: Label = $Center/Frame/Body/WheelArea/CenterBox/SpinBtn/HBox/Label
@onready var spin_btn_gem: TextureRect = $Center/Frame/Body/WheelArea/CenterBox/SpinBtn/HBox/GemIcon

@onready var confirm_popup: Control = $Center/Frame/ConfirmPopup
@onready var confirm_msg: Label = $Center/Frame/ConfirmPopup/Card/VBox/Msg
@onready var confirm_yes: BaseButton = $Center/Frame/ConfirmPopup/Card/VBox/Btns/YesBtn
@onready var confirm_no: BaseButton = $Center/Frame/ConfirmPopup/Card/VBox/Btns/NoBtn

@onready var reward_popup: Control = $Center/Frame/RewardPopup
@onready var reward_icon: TextureRect = $Center/Frame/RewardPopup/Card/VBox/RewardIcon
@onready var card_anchor: Control = $Center/Frame/RewardPopup/Card/VBox/CardAnchor
@onready var card_pivot: Control = $Center/Frame/RewardPopup/Card/VBox/CardAnchor/CardPivot
@onready var reward_label: Label = $Center/Frame/RewardPopup/Card/VBox/RewardLabel
@onready var collect_btn: BaseButton = $Center/Frame/RewardPopup/Card/VBox/CollectBtn

@onready var note_player: AudioStreamPlayer = $WheelNotePlayer

var _cell_panels: Array[Panel] = []
var _cell_highlights: Array[Panel] = []
var _is_spinning: bool = false
var _finishing_spin: bool = false
var _current_cell: int = -1
var _target_cell: int = 0
var _step_timer: float = 0.0
var _current_speed: float = START_SPEED
var _spin_elapsed: float = 0.0
var _pending_spin: Dictionary = {}
var _confirm_needs_gems: bool = false
var _anim_tween: Tween = null
var _is_closing: bool = false


func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		StoreModalAnimator.attach_button_reaction(close_btn)
	if spin_btn:
		spin_btn.pressed.connect(_on_spin_pressed)
		StoreModalAnimator.attach_button_reaction(spin_btn)
	if confirm_yes:
		confirm_yes.pressed.connect(_on_confirm_yes)
		StoreModalAnimator.attach_button_reaction(confirm_yes)
	if confirm_no:
		confirm_no.pressed.connect(_on_confirm_no)
		StoreModalAnimator.attach_button_reaction(confirm_no)
	if collect_btn:
		collect_btn.pressed.connect(_on_collect_pressed)
		StoreModalAnimator.attach_button_reaction(collect_btn)
	if note_player and SFX_SPINNER_NOTE:
		note_player.stream = SFX_SPINNER_NOTE

	_build_wheel_cells()


func open_modal(preview_highlight_cell: int = -1) -> void:
	_is_closing = false
	_is_spinning = false
	_finishing_spin = false
	if confirm_popup:
		confirm_popup.visible = false
	if reward_popup:
		reward_popup.visible = false
	_set_highlight_cell(preview_highlight_cell)
	_refresh_center_state()
	visible = true
	_anim_tween = StoreModalAnimator.play_open(self, dimmer, frame, _anim_tween)


func close_modal() -> void:
	if _is_spinning or _finishing_spin or _is_closing or not visible:
		return
	_is_closing = true
	_anim_tween = StoreModalAnimator.play_close(self, dimmer, frame, _anim_tween, func():
		_is_closing = false
		closed.emit()
	)


func _build_wheel_cells() -> void:
	if not cells_layer:
		return
	for c in cells_layer.get_children():
		c.queue_free()
	_cell_panels.clear()
	_cell_highlights.clear()

	var entries := Database.get_daily_gift_entries()
	for i in range(NUM_CELLS):
		var entry: Dictionary = entries[i] if i < entries.size() else {}
		var pos := CELL_SLOTS[i]

		var cell := Panel.new()
		cell.position = pos
		cell.size = Vector2(164, 92)
		var gtype := str(entry.get("type", ""))
		var bg_sb := StyleBoxFlat.new()
		if gtype == "Card obsidian":
			bg_sb.bg_color = Color(0.18, 0.10, 0.25, 0.95)
			bg_sb.border_color = Color(0.82, 0.50, 1.0, 0.95)
		elif gtype == "Card gold":
			bg_sb.bg_color = Color(0.28, 0.22, 0.08, 0.95)
			bg_sb.border_color = Color(1.0, 0.85, 0.25, 0.95)
		elif gtype == "Gems" and int(entry.get("quantity", 1)) >= 50:
			bg_sb.bg_color = Color(0.25, 0.12, 0.18, 0.95)
			bg_sb.border_color = Color(1.0, 0.45, 0.55, 0.95)
		else:
			bg_sb.bg_color = Color(0.14, 0.25, 0.32, 0.95)
			bg_sb.border_color = Color(0.60, 0.76, 0.84, 0.85)
		bg_sb.set_border_width_all(2)
		bg_sb.set_corner_radius_all(8)
		cell.add_theme_stylebox_override("panel", bg_sb)

		var hbox := HBoxContainer.new()
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 10
		hbox.offset_right = -10
		hbox.add_theme_constant_override("separation", 8)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(hbox)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(44, 44)
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = _icon_for_gift_type(gtype)
		if gtype == "Card gold":
			icon_rect.modulate = Color(1.0, 0.88, 0.25)
		elif gtype == "Card obsidian":
			icon_rect.modulate = Color(0.75, 0.45, 1.0)
		hbox.add_child(icon_rect)

		var vbox := VBoxContainer.new()
		vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vbox.add_theme_constant_override("separation", 0)

		var qty := int(entry.get("quantity", 1))
		var val_lbl := Label.new()
		val_lbl.add_theme_font_override("font", FONT_MAIN)
		val_lbl.add_theme_font_size_override("font_size", 18 if qty >= 100000 else 22)
		val_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		val_lbl.add_theme_constant_override("outline_size", 4)
		val_lbl.text = _format_short_qty(gtype, qty)
		vbox.add_child(val_lbl)

		var type_lbl := Label.new()
		type_lbl.add_theme_font_override("font", FONT_MAIN)
		type_lbl.add_theme_font_size_override("font_size", 13)
		type_lbl.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
		type_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		type_lbl.add_theme_constant_override("outline_size", 3)
		type_lbl.text = _short_type_name(gtype)
		vbox.add_child(type_lbl)

		hbox.add_child(vbox)

		var hi := Panel.new()
		hi.visible = false
		hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hi.set_anchors_preset(Control.PRESET_FULL_RECT)
		var hi_sb := StyleBoxFlat.new()
		hi_sb.bg_color = Color(1.0, 0.9, 0.2, 0.26)
		hi_sb.set_border_width_all(4)
		hi_sb.border_color = Color(1.0, 0.92, 0.15, 1.0)
		hi_sb.set_corner_radius_all(8)
		hi.add_theme_stylebox_override("panel", hi_sb)
		cell.add_child(hi)

		cells_layer.add_child(cell)
		_cell_panels.append(cell)
		_cell_highlights.append(hi)


func _get_card_icon_tex() -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = TEX_CARD_SHEET
	at.region = Rect2(0, 0, 92, 128)
	return at


func _icon_for_gift_type(gtype: String) -> Texture2D:
	match gtype:
		"Coins": return TEX_COIN
		"Gems": return TEX_GEM
		_: return _get_card_icon_tex()


func _short_type_name(gtype: String) -> String:
	match gtype:
		"Coins": return "Coins"
		"Gems": return "Gems"
		"Card normal": return "Card"
		"Card gold": return "Gold Card"
		"Card obsidian": return "Obsidian"
		_: return gtype


func _format_short_qty(gtype: String, qty: int) -> String:
	if gtype.begins_with("Card"):
		return "x%d" % qty
	if qty >= 1000000:
		return "%dM" % int(qty / 1000000)
	if qty >= 1000:
		return "%dK" % int(qty / 1000)
	return str(qty)


func _format_commas(value: int) -> String:
	var s := str(abs(value))
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		if cnt > 0 and cnt % 3 == 0:
			out = "," + out
		out = s[i] + out
		cnt += 1
	return out


func _set_highlight_cell(cell_idx: int) -> void:
	for i in range(_cell_highlights.size()):
		_cell_highlights[i].visible = (i == cell_idx)


func _refresh_center_state() -> void:
	var free_ready := GameManager.is_daily_gift_free_ready()
	var secs_left := GameManager.get_daily_gift_seconds_left()
	var retry_cost := Database.get_daily_gift_retry_cost()

	if spin_btn:
		spin_btn.disabled = _is_spinning or _finishing_spin

	if free_ready:
		if status_label:
			status_label.text = "1 Free Spin Ready!"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		if timer_label:
			timer_label.visible = false
		if spin_btn_label:
			spin_btn_label.text = "SPIN FREE!"
		if spin_btn_gem:
			spin_btn_gem.visible = false
	else:
		if status_label:
			status_label.text = "Next Free Gift In:"
			status_label.add_theme_color_override("font_color", Color(0.85, 0.94, 1.0))
		if timer_label:
			timer_label.visible = true
			@warning_ignore("integer_division")
			var hh := secs_left / 3600
			@warning_ignore("integer_division")
			var mm := (secs_left % 3600) / 60
			var ss := secs_left % 60
			timer_label.text = "%02d:%02d:%02d" % [hh, mm, ss]
		if spin_btn_label:
			spin_btn_label.text = "SPIN (%d)" % retry_cost
		if spin_btn_gem:
			spin_btn_gem.visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	if not _is_spinning and not _finishing_spin:
		_refresh_center_state()
		return
	if not _is_spinning:
		return

	_spin_elapsed += delta
	_step_timer -= delta
	var frac := clampf(_spin_elapsed / SPEED_DURATION, 0.0, 1.0)
	_current_speed = lerpf(START_SPEED, END_SPEED, frac * frac)

	if _step_timer <= 0.0:
		_current_cell = (_current_cell + 1) % NUM_CELLS
		_set_highlight_cell(_current_cell)
		if note_player and SFX_SPINNER_NOTE:
			note_player.pitch_scale = 1.0 + randf_range(-PITCH_RANGE, PITCH_RANGE)
			note_player.play()
		_step_timer = _current_speed

		if _spin_elapsed >= SPEED_DURATION and _current_cell == _target_cell:
			_is_spinning = false
			_finishing_spin = true
			var tw := create_tween()
			tw.tween_interval(0.5)
			tw.tween_callback(_finish_wheel)


func _on_spin_pressed() -> void:
	if _is_spinning or _finishing_spin:
		return
	_play_sfx(SFX_SELECT)
	if GameManager.is_daily_gift_free_ready():
		_begin_spin(false)
	else:
		var cost := Database.get_daily_gift_retry_cost()
		if GameManager.get_gems() < cost:
			_confirm_needs_gems = true
			if confirm_msg:
				confirm_msg.text = "Not enough Gems for another spin! Visit the Store?"
			if confirm_popup:
				confirm_popup.visible = true
		else:
			_confirm_needs_gems = false
			if confirm_msg:
				confirm_msg.text = "Are you sure you want to spend %d Gem to spin again?" % cost
			if confirm_popup:
				confirm_popup.visible = true


func _on_confirm_yes() -> void:
	_play_sfx(SFX_SELECT)
	if confirm_popup:
		confirm_popup.visible = false
	if _confirm_needs_gems:
		close_modal()
		open_store_gems_requested.emit()
		return
	_begin_spin(true)


func _on_confirm_no() -> void:
	_play_sfx(SFX_BACK)
	if confirm_popup:
		confirm_popup.visible = false


func _begin_spin(use_gem_retry: bool) -> void:
	var res := GameManager.start_daily_gift_spin(use_gem_retry)
	if not bool(res.get("ok", false)):
		_refresh_center_state()
		return
	reward_granted.emit()
	_pending_spin = res
	_target_cell = int(res.get("cell_index", 0))
	_current_cell = -1
	_spin_elapsed = 0.0
	_current_speed = START_SPEED
	_step_timer = 0.0
	_is_spinning = true
	_finishing_spin = false
	_refresh_center_state()


func _finish_wheel() -> void:
	_finishing_spin = false
	if Audio and SFX_REWARD:
		Audio.play_sfx(SFX_REWARD)
	var granted := GameManager.grant_daily_gift_reward(_pending_spin)
	reward_granted.emit()
	show_reward_preview(granted)


func show_reward_preview(granted: Dictionary) -> void:
	var gtype := str(granted.get("type", "Gems"))
	var qty := int(granted.get("quantity", 1))
	var card_id := str(granted.get("card_id", ""))

	for child in card_pivot.get_children():
		child.queue_free()

	if gtype.begins_with("Card") and card_id != "":
		if reward_icon:
			reward_icon.visible = false
		if card_anchor:
			card_anchor.visible = true
		var card_info: Dictionary = Database.get_card(card_id)
		if not card_info.is_empty() and CardViewScene:
			card_info = card_info.duplicate()
			if gtype == "Card gold":
				card_info["quality"] = "Gold"
			elif gtype == "Card obsidian":
				card_info["quality"] = "Obsidian"
			var cv = CardViewScene.instantiate()
			card_pivot.add_child(cv)
			if cv.has_method("render_card"):
				cv.render_card(card_info)
		if reward_label:
			reward_label.text = "%s!" % str(card_info.get("name", card_id))
	else:
		if card_anchor:
			card_anchor.visible = false
		if reward_icon:
			reward_icon.visible = true
			reward_icon.texture = _icon_for_gift_type(gtype)
		if reward_label:
			reward_label.text = "+%s %s!" % [_format_commas(qty), _short_type_name(gtype)]

	if reward_popup:
		reward_popup.visible = true
	_refresh_center_state()


func _on_collect_pressed() -> void:
	_play_sfx(SFX_SELECT)
	if reward_popup:
		reward_popup.visible = false
	_set_highlight_cell(-1)
	_refresh_center_state()


func _on_close_pressed() -> void:
	if _is_spinning or _finishing_spin:
		return
	_play_sfx(SFX_BACK)
	close_modal()


func _play_sfx(stream: AudioStream) -> void:
	if Audio and stream:
		Audio.play_sfx(stream)
