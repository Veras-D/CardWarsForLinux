extends Control
class_name BattleWheelModal

# Card Wars Composition Component: Battle Wheel Clash Modal
# Embeds the generic standalone WheelSpinner from res://src/systems/timing_wheel/

const WheelConfig = preload("res://src/systems/timing_wheel/WheelConfig.gd")
const WheelSpinner = preload("res://src/systems/timing_wheel/WheelSpinner.gd")

signal clash_resolved(result: Dictionary)

@onready var backdrop: ColorRect = $Backdrop
@onready var modal_panel: PanelContainer = $ModalPanel
@onready var title_lbl: Label = $ModalPanel/Margin/VBox/Title
@onready var clash_info_lbl: Label = $ModalPanel/Margin/VBox/ClashInfo
@onready var prompt_lbl: Label = $ModalPanel/Margin/VBox/Prompt
@onready var wheel_container: Control = $ModalPanel/Margin/VBox/WheelCenter/WheelContainer
@onready var result_banner: PanelContainer = $ModalPanel/Margin/VBox/ResultBanner
@onready var result_lbl: Label = $ModalPanel/Margin/VBox/ResultBanner/ResultText

var spinner: WheelSpinner
var _current_base_damage: int = 0
var _is_quick_mode: bool = false
var _resolved: bool = false

func _ready() -> void:
	visible = false
	result_banner.visible = false

	# Instantiate the decoupled WheelSpinner
	var spinner_scene = preload("res://src/systems/timing_wheel/WheelSpinner.tscn")
	spinner = spinner_scene.instantiate() as WheelSpinner
	wheel_container.add_child(spinner)

	spinner.spin_completed.connect(_on_spinner_completed)
	gui_input.connect(_on_gui_input)

func start_attack_clash(
	attacker_name: String,
	target_name: String,
	base_damage: int,
	is_player: bool = true,
	hit_ratio: float = 0.80,
	crit_ratio: float = 0.07,
	force_quick: bool = false
) -> void:
	visible = true
	_resolved = false
	_current_base_damage = base_damage
	result_banner.visible = false
	modulate = Color(1, 1, 1, 0)

	title_lbl.text = "⚔️ CREATURE ATTACK CLASH!" if is_player else "🛡️ OPPONENT ATTACK CLASH!"
	clash_info_lbl.text = "%s (%d ATK) ➔ %s" % [attacker_name, base_damage, target_name]
	prompt_lbl.text = "Tap anywhere or press SPACE to stop the wheel!" if is_player else "Opponent is spinning..."

	# Play Wheel Drop SFX
	if ResourceLoader.exists("res://assets/audio/sfx/Ring_Drop.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/Ring_Drop.wav"))

	# Fade in modal
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.25)

	# Configure Attacker Wheel
	var miss_ratio = max(0.0, 1.0 - (hit_ratio + crit_ratio))
	var sectors = [
		{
			"id": "crit",
			"name": "CRITICAL HIT!",
			"ratio": crit_ratio,
			"color": Color(0.1, 1.0, 0.3, 1.0), # Neon Green
			"multiplier": 2.0,
			"is_success": true
		},
		{
			"id": "hit",
			"name": "HIT",
			"ratio": hit_ratio,
			"color": Color(0.95, 0.85, 0.2, 1.0), # Gold/Yellow
			"multiplier": 1.0,
			"is_success": true
		},
		{
			"id": "miss",
			"name": "MISS",
			"ratio": miss_ratio,
			"color": Color(0.85, 0.2, 0.2, 1.0), # Crimson Red
			"multiplier": 0.0,
			"is_success": false
		}
	]
	var cfg = WheelConfig.create_custom(sectors, 1600.0)
	spinner.setup(cfg)

	var is_gm_quick: bool = (GameManager.get("wheel_mode") == "QUICK") if GameManager else false
	_is_quick_mode = force_quick or is_gm_quick or not is_player

	if _is_quick_mode:
		# Quick resolve: show brief spin then resolve
		spinner.start_spin()
		var timer = get_tree().create_timer(0.4)
		timer.timeout.connect(func():
			if not _resolved:
				spinner.stop_spin()
		)
	else:
		spinner.start_spin()

func _input(event: InputEvent) -> void:
	if not visible or _resolved or _is_quick_mode:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_stop_wheel()

func _on_gui_input(event: InputEvent) -> void:
	if not visible or _resolved or _is_quick_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_stop_wheel()

func _stop_wheel() -> void:
	if spinner and spinner.state == WheelSpinner.State.SPINNING:
		spinner.stop_spin()

func _on_spinner_completed(result: Dictionary) -> void:
	if _resolved:
		return
	_resolved = true

	var mult: float = result.get("multiplier", 1.0)
	var final_damage = int(round(_current_base_damage * mult))
	var s_id = result.get("id", "hit")

	result_banner.visible = true
	result_banner.scale = Vector2(0.7, 0.7)
	var banner_tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tw.tween_property(result_banner, "scale", Vector2.ONE, 0.25)

	# Sound and banner color by result type
	if s_id == "crit":
		result_lbl.text = "⚡ CRITICAL HIT! (2x Damage: %d DMG)" % final_damage
		result_lbl.modulate = Color(0.2, 1.0, 0.4)
		if ResourceLoader.exists("res://assets/audio/sfx/Ring_Crit.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/Ring_Crit.wav"))
	elif s_id == "miss":
		result_lbl.text = "❌ MISSED! (0 DMG)"
		result_lbl.modulate = Color(1.0, 0.3, 0.3)
		if ResourceLoader.exists("res://assets/audio/sfx/Ring_Miss.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/Ring_Miss.wav"))
	else:
		result_lbl.text = "⚔️ HIT! (1x Damage: %d DMG)" % final_damage
		result_lbl.modulate = Color(1.0, 0.9, 0.3)
		if ResourceLoader.exists("res://assets/audio/sfx/Ring_Hit.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/Ring_Hit.wav"))

	# Package detailed result
	var clash_res = {
		"id": s_id,
		"name": result.get("name", "Hit"),
		"multiplier": mult,
		"base_damage": _current_base_damage,
		"final_damage": final_damage,
		"angle_deg": result.get("angle_deg", 0.0)
	}

	# Wait a moment for player to see the result, then fade out
	var close_timer = get_tree().create_timer(0.9)
	await close_timer.timeout

	var fade_tw = create_tween()
	fade_tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)
	await fade_tw.finished

	visible = false
	clash_resolved.emit(clash_res)
