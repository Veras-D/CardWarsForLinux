extends Control
class_name LandscapePlacementOverlay

## Interactive "Place Your Landscapes" Phase (CWLandscapeFillCards / CWLandscapeCardDragOld parity).
## Displays the 4 deck landscapes at the bottom of the screen over the 3D hex board,
## lets the player drag (or click) each card onto any empty Player Lane 0..3,
## highlights the hovered target column in yellow on BattleArena3D, and spawns 3D tiles.

const Arena3DScript = preload("res://src/battle/BattleArena3D.gd")
const CARD_FRAME_TEX: Texture2D = preload("res://assets/textures/landscapes/Frame_Base_Landscape.png")
const FINGER_TEX: Texture2D = preload("res://assets/textures/battle/hud/Finger_SwipeUp.png")
const FONT_CARDS: FontFile = preload("res://assets/fonts/KBPlanetEarth.ttf")

signal landscapes_placed(placed_order: Array[String])

const FACTION_META: Dictionary = {
	"Corn": {"label": "Corn Fields", "color": Color(0.95, 0.85, 0.18, 1.0), "tex": "res://assets/textures/landscapes/Landscape_Corn1.png"},
	"Cotton": {"label": "Nice Lands", "color": Color(0.95, 0.52, 0.78, 1.0), "tex": "res://assets/textures/landscapes/Landscape_Cotton1.png"},
	"Plains": {"label": "Blue Plains", "color": Color(0.28, 0.68, 0.96, 1.0), "tex": "res://assets/textures/landscapes/Landscape_Plains1.png"},
	"Sand": {"label": "Sandy Lands", "color": Color(0.92, 0.62, 0.22, 1.0), "tex": "res://assets/textures/landscapes/Landscape_Sand1.png"},
	"Swamp": {"label": "Useless Swamp", "color": Color(0.38, 0.66, 0.34, 1.0), "tex": "res://assets/textures/landscapes/Landscape_Swamp1.png"},
}

@onready var prompt_pill: PanelContainer = $PromptPill
@onready var cards_row: HBoxContainer = $CardsRow
@onready var finger_hint: TextureRect = $FingerHint

var _arena: Arena3DScript = null
var _cards_factions: Array[String] = []
var _placed_lanes: Array[String] = ["", "", "", ""]
var _placed_count: int = 0
var _card_nodes: Array[Control] = []
var _selected_card_idx: int = -1
var _dragging_card_idx: int = -1
var _drag_ghost: Control = null
var _drag_start_pos: Vector2 = Vector2.ZERO
var _is_dragging_motion: bool = false
var _hovered_lane: int = -1
var _finger_tween: Tween = null


func _ready() -> void:
	visible = false
	if finger_hint:
		finger_hint.texture = FINGER_TEX


func bind_arena(arena: Arena3DScript) -> void:
	_arena = arena


func start_placement(player_landscapes: Array[String], opponent_landscapes: Array[String]) -> void:
	visible = true
	modulate = Color(1, 1, 1, 0)
	_cards_factions.clear()
	for i in range(4):
		var fac := str(player_landscapes[i]) if i < player_landscapes.size() else "Corn"
		if not FACTION_META.has(fac):
			fac = "Corn"
		_cards_factions.append(fac)

	_placed_lanes = ["", "", "", ""]
	_placed_count = 0
	_selected_card_idx = -1
	_dragging_card_idx = -1
	_is_dragging_motion = false
	_hovered_lane = -1
	_free_drag_ghost()

	_rebuild_cards()
	_start_finger_hint()

	if _arena:
		_arena.clear_lane_landscapes()
		_arena.clear_all_highlights()
		_arena.set_cards_in_hand_visible(true)
		for i in range(4):
			var o_fac := str(opponent_landscapes[i]) if i < opponent_landscapes.size() else "Plains"
			_arena.set_lane_landscape(false, i, o_fac, false)
		var cam_tw := _arena.focus_landscape_placement(0.85)
		if cam_tw and cam_tw.is_running():
			await cam_tw.finished

	if not visible:
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.25)


func _rebuild_cards() -> void:
	for c in cards_row.get_children():
		c.queue_free()
	_card_nodes.clear()

	for i in range(4):
		var card := _build_landscape_card(_cards_factions[i], i)
		cards_row.add_child(card)
		_card_nodes.append(card)


func _build_landscape_card(faction: String, idx: int) -> Control:
	var meta: Dictionary = FACTION_META.get(faction, FACTION_META["Corn"])
	var card := Control.new()
	card.custom_minimum_size = Vector2(142, 200)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta("card_idx", idx)
	card.set_meta("faction", faction)

	var art := TextureRect.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 7
	art.offset_top = 8
	art.offset_right = -7
	art.offset_bottom = -38
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(meta["tex"]):
		art.texture = load(meta["tex"])
	card.add_child(art)

	var frame := TextureRect.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.texture = CARD_FRAME_TEX
	frame.self_modulate = meta["color"]
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_left = 8
	lbl.offset_right = -8
	lbl.offset_top = -34
	lbl.offset_bottom = -6
	lbl.text = meta["label"]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FONT_CARDS)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)

	card.gui_input.connect(func(ev: InputEvent) -> void:
		_on_card_gui_input(ev, idx)
	)
	return card


func _start_finger_hint() -> void:
	if not finger_hint:
		return
	finger_hint.visible = true
	if _finger_tween and _finger_tween.is_running():
		_finger_tween.kill()
	# Position left/over first landscape card area and bob upward
	var base_y := 520.0
	finger_hint.position = Vector2(360.0, base_y)
	finger_hint.modulate = Color(1, 1, 1, 0.95)
	_finger_tween = create_tween().set_loops()
	_finger_tween.tween_property(finger_hint, "position:y", base_y - 105.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_finger_tween.parallel().tween_property(finger_hint, "modulate:a", 0.25, 0.85)
	_finger_tween.tween_callback(func():
		finger_hint.position.y = base_y
		finger_hint.modulate.a = 0.95
	)


func _stop_finger_hint() -> void:
	if _finger_tween and _finger_tween.is_running():
		_finger_tween.kill()
	if finger_hint:
		finger_hint.visible = false


func _on_card_gui_input(event: InputEvent, card_idx: int) -> void:
	if not visible or card_idx < 0 or card_idx >= _card_nodes.size():
		return
	var card := _card_nodes[card_idx]
	if card.modulate.a < 0.1:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_stop_finger_hint()
			_dragging_card_idx = card_idx
			_drag_start_pos = get_global_mouse_position()
			_is_dragging_motion = false
			if Audio and ResourceLoader.exists("res://assets/audio/sfx/Card_Pick.wav"):
				Audio.play_sfx(load("res://assets/audio/sfx/Card_Pick.wav"), -4.0)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion and _dragging_card_idx != -1:
		var mpos := get_global_mouse_position()
		if not _is_dragging_motion and mpos.distance_to(_drag_start_pos) > 10.0:
			_is_dragging_motion = true
			_spawn_drag_ghost(_dragging_card_idx)
		if _is_dragging_motion and _drag_ghost:
			_drag_ghost.global_position = mpos - _drag_ghost.size * 0.5
			_update_hover_lane(mpos)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos := get_global_mouse_position()
		if not event.pressed and _dragging_card_idx != -1:
			var idx := _dragging_card_idx
			_dragging_card_idx = -1
			_free_drag_ghost()
			if _is_dragging_motion:
				_is_dragging_motion = false
				var drop_lane := _screen_pos_to_lane(mpos)
				if drop_lane != -1 and _placed_lanes[drop_lane] == "":
					_place_card_on_lane(idx, drop_lane)
				else:
					_clear_lane_highlights()
			else:
				# Simple click selected this card
				_select_card(idx)
			get_viewport().set_input_as_handled()
		elif event.pressed and _dragging_card_idx == -1 and _selected_card_idx != -1:
			# Clicking upper board area places the selected card into that lane column
			var target_lane := _screen_pos_to_lane(mpos)
			if target_lane != -1 and _placed_lanes[target_lane] == "":
				_place_card_on_lane(_selected_card_idx, target_lane)
				get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_auto_place_remaining()
		get_viewport().set_input_as_handled()


func _select_card(card_idx: int) -> void:
	_selected_card_idx = card_idx
	for i in range(_card_nodes.size()):
		var c := _card_nodes[i]
		if c.modulate.a < 0.1:
			continue
		c.scale = Vector2(1.08, 1.08) if i == card_idx else Vector2.ONE
		c.position.y = -14.0 if i == card_idx else 0.0
	if _arena:
		for l in range(4):
			_arena.set_lane_highlight(true, l, _placed_lanes[l] == "")


func _spawn_drag_ghost(card_idx: int) -> void:
	_free_drag_ghost()
	_card_nodes[card_idx].modulate = Color(1, 1, 1, 0.35)
	_drag_ghost = _build_landscape_card(_cards_factions[card_idx], card_idx)
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.scale = Vector2(0.95, 0.95)
	_drag_ghost.z_index = 20
	add_child(_drag_ghost)
	_drag_ghost.global_position = get_global_mouse_position() - _drag_ghost.custom_minimum_size * 0.5


func _free_drag_ghost() -> void:
	if _drag_ghost:
		_drag_ghost.queue_free()
		_drag_ghost = null
	for c in _card_nodes:
		if c.get_meta("placed", false) == false:
			c.modulate = Color.WHITE


func _screen_pos_to_lane(mpos: Vector2) -> int:
	var sz := get_viewport_rect().size
	if mpos.y > sz.y * 0.65:
		return -1
	# Screen left -> right maps cleanly to Lane 0..3 inside the central board span
	var board_left := sz.x * 0.18
	var board_right := sz.x * 0.82
	var nx := clampf((mpos.x - board_left) / maxf(1.0, board_right - board_left), 0.0, 0.999)
	return clampi(int(nx * 4.0), 0, 3)


func _update_hover_lane(mpos: Vector2) -> void:
	var lane := _screen_pos_to_lane(mpos)
	if lane == _hovered_lane:
		return
	_hovered_lane = lane
	if _arena:
		for l in range(4):
			var ok := (l == lane and _placed_lanes[l] == "")
			_arena.set_lane_highlight(true, l, ok)


func _clear_lane_highlights() -> void:
	_hovered_lane = -1
	if _arena:
		_arena.clear_all_highlights()


func _place_card_on_lane(card_idx: int, lane_idx: int) -> void:
	var faction := _cards_factions[card_idx]
	_placed_lanes[lane_idx] = faction
	_placed_count += 1
	_selected_card_idx = -1

	var card := _card_nodes[card_idx]
	card.set_meta("placed", true)
	card.modulate = Color(1, 1, 1, 0.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_clear_lane_highlights()
	if _arena:
		_arena.set_lane_landscape(true, lane_idx, faction, true)
	if Audio and ResourceLoader.exists("res://assets/audio/sfx/CardMove.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/CardMove.wav"), -3.0)

	if _placed_count >= 4:
		_finish_placement()


func _auto_place_remaining() -> void:
	_stop_finger_hint()
	for i in range(mini(4, _card_nodes.size())):
		var c := _card_nodes[i]
		if c.get_meta("placed", false):
			continue
		for l in range(4):
			if _placed_lanes[l] == "":
				_place_card_on_lane(i, l)
				break


func _finish_placement() -> void:
	_clear_lane_highlights()
	_stop_finger_hint()
	var final_order: Array[String] = []
	for l in _placed_lanes:
		final_order.append(l if l != "" else "Corn")

	var tw := create_tween()
	tw.tween_interval(0.32)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func():
		visible = false
		landscapes_placed.emit(final_order)
	)
