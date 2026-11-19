extends Control
class_name LeaderPowerButton

signal power_activated(character_id: String)

const TEX_TURNS: Texture2D = preload("res://assets/textures/battle/hud/uiTurns.png")
const TEX_READY: Texture2D = preload("res://assets/textures/battle/hud/uiTurnsReady.png")

@onready var main_button: Button = $Button
@onready var portrait_rect: TextureRect = $Button/HBox/Portrait
@onready var count_label: Label = $Button/HBox/CountLabel
@onready var title_label: Label = $Button/HBox/VBox/TitleLabel
@onready var status_label: Label = $Button/HBox/VBox/StatusLabel
@onready var glow_rect: Control = $GlowPanel

var character_id: String = ""
var leader_data: Dictionary = {}
var current_cooldown: int = 0
var max_cooldown: int = 0
var is_player: bool = true
var is_interactive: bool = true
var is_ready_pulse_active: bool = false
var _pulse_tween: Tween = null

func _ready() -> void:
	if main_button:
		main_button.pressed.connect(_on_button_pressed)

func setup(char_or_leader_id: String, player_owner: bool = true) -> void:
	character_id = char_or_leader_id
	is_player = player_owner
	is_interactive = player_owner
	leader_data = Database.get_leader(char_or_leader_id)

	if leader_data.is_empty():
		# Fallback defaults if not found in db
		leader_data = {
			"character_id": char_or_leader_id,
			"name": char_or_leader_id,
			"desc": "Leader ability.",
			"cooldown": 3,
			"script_name": "GainActionPointsLeader",
			"val1": "2"
		}

	max_cooldown = leader_data.get("cooldown", 3)
	current_cooldown = max_cooldown

	# Portrait lookup
	var char_name = leader_data.get("character_id", char_or_leader_id)
	var round_path = "res://assets/textures/leaders/%s_Round.png" % char_name
	var full_path = "res://assets/textures/leaders/%s.png" % char_name

	if ResourceLoader.exists(round_path):
		portrait_rect.texture = load(round_path)
	elif ResourceLoader.exists(full_path):
		portrait_rect.texture = load(full_path)
	else:
		portrait_rect.texture = load("res://assets/textures/icon.png")

	var hero_name = leader_data.get("name", char_name)
	var hero_desc = leader_data.get("desc", "")
	title_label.text = hero_name
	tooltip_text = "%s: %s" % [hero_name, hero_desc]

	update_cooldown(current_cooldown)

func update_cooldown(cooldown: int) -> void:
	current_cooldown = max(0, cooldown)
	var hero_name = leader_data.get("name", character_id)
	var hero_desc = leader_data.get("desc", "")

	var sb := StyleBoxTexture.new()
	if current_cooldown <= 0:
		sb.texture = TEX_READY
		if count_label:
			count_label.visible = false
		status_label.text = ""
		status_label.visible = false
		main_button.disabled = !is_interactive
		_start_ready_pulse()
		tooltip_text = "READY! Click to activate:\n%s" % hero_desc
	else:
		sb.texture = TEX_TURNS
		if count_label:
			count_label.visible = true
			count_label.text = str(current_cooldown)
		status_label.visible = true
		status_label.text = "TURNS" if current_cooldown != 1 else "TURN"
		status_label.modulate = Color.WHITE
		main_button.disabled = true
		_stop_ready_pulse()
		tooltip_text = "%s (%d turn%s cooldown):\n%s" % [
			hero_name, current_cooldown, "s" if current_cooldown > 1 else "", hero_desc
		]
	if main_button:
		for st in ["normal", "hover", "pressed", "disabled"]:
			main_button.add_theme_stylebox_override(st, sb)

func _start_ready_pulse() -> void:
	if is_ready_pulse_active or not is_player:
		return
	is_ready_pulse_active = true
	if glow_rect:
		glow_rect.visible = true
	_animate_pulse()

func _animate_pulse() -> void:
	if not is_ready_pulse_active:
		return
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(glow_rect, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(glow_rect, "modulate:a", 0.2, 0.6).set_trans(Tween.TRANS_SINE)

func _stop_ready_pulse() -> void:
	is_ready_pulse_active = false
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	if glow_rect:
		glow_rect.visible = false
		glow_rect.modulate.a = 0.0

func _on_button_pressed() -> void:
	if not is_interactive or current_cooldown > 0:
		return
	trigger_activation_anim()
	power_activated.emit(character_id)

func trigger_activation_anim() -> void:
	# Punch scale & golden flash
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
