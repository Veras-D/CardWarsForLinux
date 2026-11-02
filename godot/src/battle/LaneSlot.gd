extends Control
class_name LaneSlot

signal slot_clicked(lane_slot)
signal floop_requested(lane_slot)
signal creature_destroyed(lane_slot, dead_data)

@export var is_player: bool = true
@export var lane_index: int = 0
@export var landscape: String = "Plains"

var creature_data: Dictionary = {}
var current_atk: int = 0
var current_def: int = 0
var is_flooped: bool = false
var has_creature: bool = false

@onready var bg_panel: Panel = $BgPanel
@onready var terrain_texture: TextureRect = $TerrainTexture
@onready var highlight_border: Panel = $HighlightBorder
@onready var landscape_label: Label = $LandscapeLabel
@onready var card_container: CenterContainer = $CardContainer
@onready var floop_btn: Button = $FloopBtn
@onready var empty_label: Label = $EmptyLabel

const LANDSCAPE_METADATA = {
	"Plains": {
		"name": "BLUE PLAINS",
		"icon": "🌿",
		"color": Color(0.18, 0.42, 0.28, 0.85),
		"border": Color(0.35, 0.75, 0.45, 0.7)
	},
	"Corn": {
		"name": "CORNFIELD",
		"icon": "🌽",
		"color": Color(0.55, 0.46, 0.12, 0.85),
		"border": Color(0.9, 0.78, 0.25, 0.7)
	},
	"Cotton": {
		"name": "NICELANDS",
		"icon": "🌸",
		"color": Color(0.52, 0.25, 0.45, 0.85),
		"border": Color(0.85, 0.45, 0.75, 0.7)
	},
	"Sand": {
		"name": "SANDY LANDS",
		"icon": "🏜️",
		"color": Color(0.58, 0.38, 0.14, 0.85),
		"border": Color(0.85, 0.60, 0.25, 0.7)
	},
	"Swamp": {
		"name": "USELESS SWAMP",
		"icon": "🧪",
		"color": Color(0.22, 0.32, 0.22, 0.85),
		"border": Color(0.40, 0.60, 0.40, 0.7)
	},
	"Universal": {
		"name": "UNIVERSAL",
		"icon": "⭐",
		"color": Color(0.35, 0.25, 0.50, 0.85),
		"border": Color(0.80, 0.60, 0.95, 0.7)
	}
}

var _pulse_tween: Tween = null

func _ready() -> void:
	floop_btn.pressed.connect(_on_floop_pressed)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	update_landscape(landscape)
	clear_slot()

func update_landscape(new_landscape: String) -> void:
	landscape = new_landscape
	if not is_inside_tree() or not is_node_ready():
		return

	var meta = LANDSCAPE_METADATA.get(landscape, LANDSCAPE_METADATA["Plains"])

	# Label styling
	landscape_label.text = "%s %s" % [meta["icon"], meta["name"]]

	# Background styling
	var style = bg_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style:
		style.bg_color = meta["color"]
		style.border_color = meta["border"]
		bg_panel.add_theme_stylebox_override("panel", style)

	# Terrain Texture loading
	var tex_path = "res://assets/textures/landscapes/%s.png" % landscape
	if ResourceLoader.exists(tex_path):
		terrain_texture.texture = load(tex_path)
		terrain_texture.visible = true
	else:
		terrain_texture.visible = false

func can_accept_creature(card: Dictionary) -> Dictionary:
	if has_creature:
		return {
			"allowed": false,
			"reason": "Lane %d already has a creature deployed!" % (lane_index + 1)
		}

	var card_faction = card.get("faction", "")
	# Universal matches anything
	if card_faction == "Universal" or landscape == "Universal":
		return { "allowed": true, "reason": "" }

	if card_faction.to_lower() == landscape.to_lower():
		return { "allowed": true, "reason": "" }

	var req_name = card_faction.to_upper()
	var cur_name = LANDSCAPE_METADATA.get(landscape, {}).get("name", landscape.to_upper())
	return {
		"allowed": false,
		"reason": "Requires %s Landscape! (This lane is %s)" % [req_name, cur_name]
	}

func set_highlight(active: bool, is_valid: bool = true) -> void:
	if not is_instance_valid(highlight_border):
		return
	if not active:
		highlight_border.visible = false
		if _pulse_tween and _pulse_tween.is_valid():
			_pulse_tween.kill()
		return

	highlight_border.visible = true
	var border_style = highlight_border.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if border_style:
		border_style.border_color = Color(0.2, 1.0, 0.4, 0.9) if is_valid else Color(1.0, 0.25, 0.25, 0.9)
		highlight_border.add_theme_stylebox_override("panel", border_style)

func flash_invalid() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	set_highlight(true, false)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "modulate", Color(1.6, 0.4, 0.4, 1.0), 0.1)
	_pulse_tween.tween_property(self, "modulate", Color.WHITE, 0.25)
	_pulse_tween.tween_callback(func(): set_highlight(false))

func flash_valid() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "modulate", Color(1.3, 1.3, 0.6, 1.0), 0.15)
	_pulse_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	_pulse_tween.tween_callback(func(): set_highlight(false))

func place_creature(card: Dictionary) -> void:
	creature_data = card.duplicate(true)
	current_atk = creature_data.get("atk", 0)
	current_def = creature_data.get("def", 0)
	is_flooped = false
	has_creature = true
	empty_label.visible = false
	set_highlight(false)

	# Clear previous card if any
	for child in card_container.get_children():
		child.queue_free()

	var card_scene = preload("res://scenes/components/CardView.tscn").instantiate()
	card_container.add_child(card_scene)
	card_scene.render_card(creature_data)

	var floop_cost = creature_data.get("floop_cost", 0)
	floop_btn.visible = (is_player and floop_cost > 0)

	flash_valid()

func apply_damage(damage: int) -> bool:
	if not has_creature:
		return false
	current_def -= damage
	_update_card_display()
	if current_def <= 0:
		var dead_data = creature_data.duplicate(true)
		clear_slot()
		creature_destroyed.emit(self, dead_data)
		return true # Creature was destroyed
	return false

func modify_atk(delta: int) -> void:
	current_atk = max(0, current_atk + delta)
	_update_card_display()

func modify_def(delta: int) -> void:
	current_def = max(0, current_def + delta)
	_update_card_display()

func heal_to_full() -> void:
	if has_creature:
		var max_def = creature_data.get("def", current_def)
		current_def = max_def
		_update_card_display()

func set_flooped(state: bool) -> void:
	is_flooped = state
	var card_node = _get_card_node()
	if card_node:
		card_node.set_flooped(state)
	floop_btn.disabled = state

func reset_turn() -> void:
	if has_creature:
		set_flooped(false)

func clear_slot() -> void:
	has_creature = false
	creature_data.clear()
	current_atk = 0
	current_def = 0
	is_flooped = false
	floop_btn.visible = false
	empty_label.visible = true
	set_highlight(false)
	for child in card_container.get_children():
		child.queue_free()

func _update_card_display() -> void:
	var card_node = _get_card_node()
	if card_node:
		card_node.update_stats(current_atk, current_def)

func _get_card_node() -> CardView:
	if card_container.get_child_count() > 0:
		return card_container.get_child(0) as CardView
	return null

func _on_floop_pressed() -> void:
	floop_requested.emit(self)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(self)

func _on_mouse_entered() -> void:
	if not has_creature and is_player:
		modulate = Color(1.1, 1.1, 1.1, 1.0)

func _on_mouse_exited() -> void:
	if not (_pulse_tween and _pulse_tween.is_valid()):
		modulate = Color.WHITE
