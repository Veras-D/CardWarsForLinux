extends Control
class_name LaneSlot

signal slot_clicked(lane_slot)
signal floop_requested(lane_slot)

@export var is_player: bool = true
@export var lane_index: int = 0
@export var landscape: String = "Plains"

var creature_data: Dictionary = {}
var current_atk: int = 0
var current_def: int = 0
var is_flooped: bool = false
var has_creature: bool = false

@onready var bg_panel: Panel = $BgPanel
@onready var landscape_label: Label = $LandscapeLabel
@onready var card_container: CenterContainer = $CardContainer
@onready var floop_btn: Button = $FloopBtn
@onready var empty_label: Label = $EmptyLabel

const LANDSCAPE_COLORS = {
	"Plains": Color(0.2, 0.48, 0.31, 0.8),
	"Corn": Color(0.56, 0.49, 0.11, 0.8),
	"Cotton": Color(0.54, 0.29, 0.48, 0.8),
	"Sand": Color(0.62, 0.43, 0.14, 0.8),
	"Swamp": Color(0.24, 0.36, 0.24, 0.8)
}

func _ready() -> void:
	update_landscape(landscape)
	floop_btn.pressed.connect(_on_floop_pressed)
	gui_input.connect(_on_gui_input)
	clear_slot()

func update_landscape(new_landscape: String) -> void:
	landscape = new_landscape
	landscape_label.text = landscape.to_upper()
	var color = LANDSCAPE_COLORS.get(landscape, Color(0.2, 0.2, 0.2, 0.8))
	var style = bg_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style:
		style.bg_color = color
		bg_panel.add_theme_stylebox_override("panel", style)

func place_creature(card: Dictionary) -> void:
	creature_data = card.duplicate(true)
	current_atk = creature_data.get("atk", 0)
	current_def = creature_data.get("def", 0)
	is_flooped = false
	has_creature = true
	empty_label.visible = false

	# Clear previous card if any
	for child in card_container.get_children():
		child.queue_free()

	var card_scene = preload("res://scenes/components/CardView.tscn").instantiate()
	card_container.add_child(card_scene)
	card_scene.render_card(creature_data)

	var floop_cost = creature_data.get("floop_cost", 0)
	floop_btn.visible = (is_player and floop_cost > 0)

func apply_damage(damage: int) -> bool:
	if not has_creature:
		return false
	current_def -= damage
	_update_card_display()
	if current_def <= 0:
		clear_slot()
		return true # Creature was destroyed
	return false

func modify_atk(delta: int) -> void:
	current_atk = max(0, current_atk + delta)
	_update_card_display()

func modify_def(delta: int) -> void:
	current_def = max(0, current_def + delta)
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
