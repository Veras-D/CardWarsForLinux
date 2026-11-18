extends Control
class_name LandscapePlacementOverlay

## Interactive "Place Your Landscapes" Phase (CWLandscapeFillCards / CWLandscapeCardDragOld parity).
## Displays 4 fixed deck landscape card slots flush at the bottom of the screen,
## lets the player drag (with tabletop perspective foreshortening) or click cards onto Lanes 0..3,
## highlights hovered columns in yellow on BattleArena3D, plays original SFX, and spawns 3D tiles + props.

const Arena3DScript = preload("res://src/battle/BattleArena3D.gd")
const CARD_FRAME_TEX: Texture2D = preload("res://assets/textures/landscapes/Frame_Base_Landscape.png")
const FINGER_TEX: Texture2D = preload("res://assets/textures/battle/hud/Finger_SwipeUp.png")
const FONT_CARDS: FontFile = preload("res://assets/fonts/KBPlanetEarth.ttf")

const SFX_CARD_MOVE := "res://assets/audio/sfx/CardMove.wav"
const SFX_PLACE_LANDSCAPE := "res://assets/audio/sfx/PlaceLandscape.wav"
const SFX_PLACE_CARD_POOL: Array[String] = [
	"res://assets/audio/sfx/Place_Card_1.wav",
	"res://assets/audio/sfx/Place_Card_3.wav",
	"res://assets/audio/sfx/Place_Card_4.wav",
	"res://assets/audio/sfx/Place_Card_5.wav",
]

const CARD_SIZE := Vector2(174.0, 244.0)
const DRAG_TABLE_SCALE := Vector2(0.58, 0.48)
const DRAG_FADE_END_SCALE := Vector2(0.32, 0.27)
const CARDS_REST_TOP := -246.0
const CARDS_REST_BOTTOM := -2.0
const CARDS_START_TOP := 60.0
const CARDS_START_BOTTOM := 304.0

signal landscapes_placed(placed_order: Array[String])

# Exact FactionColor values from db_Faction.json
const FACTION_META: Dictionary = {
	"Corn": {
		"label": "Corn Fields",
		"color": Color(255.0 / 255.0, 239.0 / 255.0, 108.0 / 255.0, 1.0),
		"tex": "res://assets/textures/landscapes/Landscape_Corn1.png",
	},
	"Cotton": {
		"label": "Nice Lands",
		"color": Color(243.0 / 255.0, 122.0 / 255.0, 176.0 / 255.0, 1.0),
		"tex": "res://assets/textures/landscapes/Landscape_Cotton1.png",
	},
	"Plains": {
		"label": "Blue Plains",
		"color": Color(108.0 / 255.0, 205.0 / 255.0, 240.0 / 255.0, 1.0),
		"tex": "res://assets/textures/landscapes/Landscape_Plains1.png",
	},
	"Sand": {
		"label": "Sandy Lands",
		"color": Color(217.0 / 255.0, 170.0 / 255.0, 133.0 / 255.0, 1.0),
		"tex": "res://assets/textures/landscapes/Landscape_Sand1.png",
	},
	"Swamp": {
		"label": "Useless Swamp",
		"color": Color(103.0 / 255.0, 143.0 / 255.0, 47.0 / 255.0, 1.0),
		"tex": "res://assets/textures/landscapes/Landscape_Swamp1.png",
	},
}

@onready var prompt_pill: PanelContainer = $PromptPill
@onready var prompt_label: Label = $PromptPill/Label
@onready var cards_row: HBoxContainer = $CardsRow
@onready var finger_hint: TextureRect = $FingerHint

var _arena: Arena3DScript = null
var _cards_factions: Array[String] = []
var _opponent_factions: Array[String] = []
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
var _prompt_pulse_tween: Tween = null


func _ready() -> void:
	visible = false
	if finger_hint:
		finger_hint.texture = FINGER_TEX


func bind_arena(arena: Arena3DScript) -> void:
	_arena = arena


func start_placement(player_landscapes: Array[String], opponent_landscapes: Array[String]) -> void:
	visible = true
	modulate = Color(1, 1, 1, 0)
	if prompt_pill:
		prompt_pill.visible = true
	_cards_factions.clear()
	_opponent_factions.clear()
	for i in range(4):
		var fac := str(player_landscapes[i]) if i < player_landscapes.size() else "Corn"
		if not FACTION_META.has(fac):
			fac = "Corn"
		_cards_factions.append(fac)
		var o_fac := str(opponent_landscapes[i]) if i < opponent_landscapes.size() else "Plains"
		_opponent_factions.append(o_fac)

	_placed_lanes = ["", "", "", ""]
	_placed_count = 0
	_selected_card_idx = -1
	_dragging_card_idx = -1
	_is_dragging_motion = false
	_hovered_lane = -1
	_free_drag_ghost()

	_rebuild_cards()
	cards_row.offset_top = CARDS_START_TOP
	cards_row.offset_bottom = CARDS_START_BOTTOM

	if _arena:
		_arena.clear_lane_landscapes()
		_arena.clear_all_highlights()
		_arena.set_hex_scan_fx_visible(true)
		_arena.set_cards_in_hand_visible(true)
		var cam_tw := _arena.focus_landscape_placement(0.85)
		if cam_tw and cam_tw.is_running():
			await cam_tw.finished

	if not visible:
		return

	_start_prompt_pulse()
	_start_finger_hint()

	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.25)
	tw.parallel().tween_property(cards_row, "offset_top", CARDS_REST_TOP, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cards_row, "offset_bottom", CARDS_REST_BOTTOM, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _rebuild_cards() -> void:
	for c in cards_row.get_children():
		cards_row.remove_child(c)
		c.queue_free()
	_card_nodes.clear()

	# Use fixed slot wrappers so placed cards leave an empty gap instead of shifting remaining cards.
	for i in range(4):
		var slot_wrap := Control.new()
		slot_wrap.name = "Slot_%d" % i
		slot_wrap.custom_minimum_size = CARD_SIZE
		slot_wrap.size = CARD_SIZE
		slot_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card := _build_landscape_card(_cards_factions[i], i)
		card.position = Vector2.ZERO
		slot_wrap.add_child(card)
		cards_row.add_child(slot_wrap)
		_card_nodes.append(card)


func _build_landscape_card(faction: String, idx: int) -> Control:
	var meta: Dictionary = FACTION_META.get(faction, FACTION_META["Corn"])
	var card := Control.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.pivot_offset = CARD_SIZE * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta("card_idx", idx)
	card.set_meta("faction", faction)
	card.set_meta("placed", false)

	var art := TextureRect.new()
	art.z_index = 0
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 7
	art.offset_top = 7
	art.offset_right = -7
	art.offset_bottom = -42
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(meta["tex"]):
		art.texture = load(meta["tex"])
	card.add_child(art)

	var frame := TextureRect.new()
	frame.z_index = 1
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture = CARD_FRAME_TEX
	frame.self_modulate = meta["color"]
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)

	var lbl := Label.new()
	lbl.z_index = 2
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_left = 8
	lbl.offset_right = -8
	lbl.offset_top = -38
	lbl.offset_bottom = -6
	lbl.text = meta["label"]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FONT_CARDS)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)

	card.gui_input.connect(func(ev: InputEvent) -> void:
		_on_card_gui_input(ev, idx)
	)
	return card


func _play_sfx(res_path: String, volume_db: float = -2.0) -> void:
	if Audio and ResourceLoader.exists(res_path):
		Audio.play_sfx(load(res_path), volume_db)


func _start_prompt_pulse() -> void:
	if _prompt_pulse_tween and _prompt_pulse_tween.is_running():
		_prompt_pulse_tween.kill()
	if not prompt_label:
		return
	prompt_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_prompt_pulse_tween = create_tween().set_loops()
	_prompt_pulse_tween.tween_property(prompt_label, "modulate:a", 0.08, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_prompt_pulse_tween.tween_property(prompt_label, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_prompt_pulse() -> void:
	if _prompt_pulse_tween and _prompt_pulse_tween.is_running():
		_prompt_pulse_tween.kill()
	_prompt_pulse_tween = null


func _first_empty_lane() -> int:
	for i in range(4):
		if _placed_lanes[i] == "":
			return i
	return 0


func _get_lane_screen_pos(lane_idx: int) -> Vector2:
	var sz := get_viewport_rect().size
	if _arena and _arena.camera:
		var anchor := _arena.get_lane_anchor(true, lane_idx)
		if anchor:
			return _arena.camera.unproject_position(anchor.global_position)
	var board_left := sz.x * 0.24
	var board_right := sz.x * 0.76
	var x := lerpf(board_left, board_right, (float(lane_idx) + 0.5) / 4.0)
	return Vector2(x, sz.y * 0.38)


func _start_finger_hint() -> void:
	if not finger_hint or _placed_count >= 4 or not visible:
		return
	if _finger_tween and _finger_tween.is_running():
		_finger_tween.kill()

	var sz := get_viewport_rect().size
	var target_lane := _first_empty_lane()
	var lane_screen := _get_lane_screen_pos(target_lane)
	var half_w := finger_hint.size.x * 0.5
	var start_x := clampf(lane_screen.x - half_w, 80.0, sz.x - 160.0)
	var start_y := sz.y * 0.59
	var end_y := sz.y * 0.41

	finger_hint.visible = true
	finger_hint.position = Vector2(start_x, start_y)
	finger_hint.modulate = Color(1.0, 1.0, 1.0, 0.0)

	_finger_tween = create_tween().set_loops()
	_finger_tween.tween_callback(func():
		if is_instance_valid(finger_hint):
			var next_lane := _first_empty_lane()
			var next_x := clampf(_get_lane_screen_pos(next_lane).x - finger_hint.size.x * 0.5, 80.0, get_viewport_rect().size.x - 160.0)
			finger_hint.position = Vector2(next_x, get_viewport_rect().size.y * 0.59)
			finger_hint.modulate.a = 0.0
	)
	_finger_tween.tween_property(finger_hint, "modulate:a", 0.95, 0.25).set_trans(Tween.TRANS_SINE)
	_finger_tween.parallel().tween_property(finger_hint, "position:y", end_y, 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_finger_tween.tween_property(finger_hint, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	_finger_tween.tween_interval(0.15)


func _stop_finger_hint() -> void:
	if _finger_tween and _finger_tween.is_running():
		_finger_tween.kill()
	_finger_tween = null
	if finger_hint:
		finger_hint.visible = false


func _on_card_gui_input(event: InputEvent, card_idx: int) -> void:
	if not visible or card_idx < 0 or card_idx >= _card_nodes.size():
		return
	var card := _card_nodes[card_idx]
	if card.get_meta("placed", false) == true:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_stop_finger_hint()
			_dragging_card_idx = card_idx
			_drag_start_pos = get_global_mouse_position()
			_is_dragging_motion = false
			_play_sfx(SFX_CARD_MOVE, -3.0)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion and _dragging_card_idx != -1:
		var mpos := get_global_mouse_position()
		if not _is_dragging_motion and mpos.distance_to(_drag_start_pos) > 8.0:
			_is_dragging_motion = true
			_spawn_drag_ghost(_dragging_card_idx)
		if _is_dragging_motion and _drag_ghost:
			_update_drag_visual(mpos)
			_update_hover_lane(mpos)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos := get_global_mouse_position()
		if not event.pressed and _dragging_card_idx != -1:
			var idx := _dragging_card_idx
			_dragging_card_idx = -1
			if _is_dragging_motion:
				_is_dragging_motion = false
				var drop_lane := _screen_pos_to_lane(mpos)
				if drop_lane != -1 and _placed_lanes[drop_lane] == "":
					_place_card_on_lane(idx, drop_lane, mpos)
				else:
					_return_dragged_card()
			else:
				_free_drag_ghost()
				_select_card(idx)
			get_viewport().set_input_as_handled()
		elif event.pressed and _dragging_card_idx == -1 and _selected_card_idx != -1:
			var target_lane := _screen_pos_to_lane(mpos)
			if target_lane != -1 and _placed_lanes[target_lane] == "":
				_place_card_on_lane(_selected_card_idx, target_lane, mpos)
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
		if c.get_meta("placed", false) == true:
			continue
		c.scale = Vector2(1.06, 1.06) if i == card_idx else Vector2.ONE
		c.position.y = -12.0 if i == card_idx else 0.0
	if _arena:
		for l in range(4):
			_arena.set_lane_highlight(true, l, _placed_lanes[l] == "")


func _spawn_drag_ghost(card_idx: int) -> void:
	_free_drag_ghost()
	_card_nodes[card_idx].modulate = Color(1, 1, 1, 0.0)
	_drag_ghost = _build_landscape_card(_cards_factions[card_idx], card_idx)
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.pivot_offset = CARD_SIZE * 0.5
	_drag_ghost.scale = Vector2.ONE
	_drag_ghost.z_index = 20
	add_child(_drag_ghost)
	_update_drag_visual(get_global_mouse_position())


func _update_drag_visual(mpos: Vector2) -> void:
	if _drag_ghost == null:
		return
	var sz := get_viewport_rect().size
	var over_board := mpos.y < sz.y * 0.65
	var target_scale := DRAG_TABLE_SCALE if over_board else Vector2.ONE
	_drag_ghost.scale = _drag_ghost.scale.lerp(target_scale, 0.45)
	_drag_ghost.position = mpos - CARD_SIZE * 0.5


func _return_dragged_card() -> void:
	_clear_lane_highlights()
	_free_drag_ghost()
	_play_sfx(SFX_CARD_MOVE, -3.0)
	if _placed_count < 4:
		_start_finger_hint()


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
	if _arena and _arena.camera:
		var ro := _arena.camera.project_ray_origin(mpos)
		var rd := _arena.camera.project_ray_normal(mpos)
		if absf(rd.y) > 0.001:
			var t := (_arena.BOARD_SURFACE_Y - ro.y) / rd.y
			if t > 0.0:
				var hit := ro + rd * t
				if hit.z >= -1.18 and hit.z <= 1.18:
					var best_lane := 0
					var best_dist := INF
					for i in range(4):
						var d := absf(hit.z - _arena.P1_LANDSCAPE_Z[i])
						if d < best_dist:
							best_dist = d
							best_lane = i
					return best_lane
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


func _spawn_fading_placed_card(card_idx: int, drop_pos: Vector2) -> void:
	var fading: Control = null
	if _drag_ghost != null:
		fading = _drag_ghost
		_drag_ghost = null
	else:
		fading = _build_landscape_card(_cards_factions[card_idx], card_idx)
		fading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fading.pivot_offset = CARD_SIZE * 0.5
		fading.z_index = 20
		add_child(fading)
		fading.position = drop_pos - CARD_SIZE * 0.5
		fading.scale = DRAG_TABLE_SCALE

	var tw := create_tween()
	tw.tween_property(fading, "scale", DRAG_FADE_END_SCALE, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fading, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(fading.queue_free)


func _place_card_on_lane(card_idx: int, lane_idx: int, drop_pos: Vector2 = Vector2.ZERO) -> void:
	var faction := _cards_factions[card_idx]
	_placed_lanes[lane_idx] = faction
	_placed_count += 1
	_selected_card_idx = -1

	var card := _card_nodes[card_idx]
	card.set_meta("placed", true)
	card.modulate = Color(1, 1, 1, 0.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var effect_pos := drop_pos if drop_pos != Vector2.ZERO else _get_lane_screen_pos(lane_idx)
	_spawn_fading_placed_card(card_idx, effect_pos)

	_clear_lane_highlights()
	if _arena:
		_arena.set_lane_landscape(true, lane_idx, faction, true)

	_play_sfx(SFX_PLACE_LANDSCAPE, -1.0)
	_play_sfx(SFX_PLACE_CARD_POOL[randi() % SFX_PLACE_CARD_POOL.size()], -1.5)

	if _placed_count >= 4:
		_finish_placement()
	else:
		_start_finger_hint()


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
	_stop_prompt_pulse()
	if prompt_pill:
		prompt_pill.visible = false

	if _arena:
		_arena.set_hex_scan_fx_visible(false)
		for i in range(4):
			var o_fac := str(_opponent_factions[i]) if i < _opponent_factions.size() else "Plains"
			_arena.set_lane_landscape(false, i, o_fac, true)

	var final_order: Array[String] = []
	for l in _placed_lanes:
		final_order.append(l if l != "" else "Corn")

	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		visible = false
		landscapes_placed.emit(final_order)
	)
