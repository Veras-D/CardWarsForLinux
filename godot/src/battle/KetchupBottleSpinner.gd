extends Control
class_name KetchupBottleSpinner

## First-Turn Ketchup Bottle Spinner (CWKetchupBottleScript parity).
## Renders Ketchup (or Fionna & Cake spinner) centered horizontally across
## the board seam, accepts an upward swipe / click / Spacebar to spin,
## decelerates realistically to point at Player (down) or Opponent (up),
## displays "[Hero] goes first!" + "Tap anywhere on the screen", and continues.

const Arena3DScript = preload("res://src/battle/BattleArena3D.gd")

signal spin_completed(player_goes_first: bool)

const NORMAL_SPINNER_TEX: String = "res://assets/textures/battle/banners/Spinner_Ketchup.png"
const NORMAL_SHADOW_TEX: String = "res://assets/textures/battle/banners/Spinner_Ketchup_Shadow.png"
const FC_SPINNERS: Array[Array] = [
	["res://assets/textures/battle/banners/Spinner_Sword.png", "res://assets/textures/battle/banners/Spinner_Sword_Shadow.png"],
	["res://assets/textures/battle/banners/Spinner_Pizza.png", "res://assets/textures/battle/banners/Spinner_Pizza_Shadow.png"],
	["res://assets/textures/battle/banners/Spinner_Hotdog.png", "res://assets/textures/battle/banners/Spinner_Hotdog_Shadow.png"],
	["res://assets/textures/battle/banners/Spinner_Fish.png", "res://assets/textures/battle/banners/Spinner_Fish_Shadow.png"],
	["res://assets/textures/battle/banners/Spinner_Shard.png", "res://assets/textures/battle/banners/Spinner_Shard_Shadow.png"],
]

@onready var dim_rect: ColorRect = $DimRect
@onready var bottle_pivot: Control = $BottleCenter/BottlePivot
@onready var bottle_shadow: TextureRect = $BottleCenter/BottleShadow
@onready var bottle_sprite: TextureRect = $BottleCenter/BottlePivot/BottleSprite
@onready var finger_hint: TextureRect = $FingerHint
@onready var swipe_pill: PanelContainer = $SwipePill
@onready var tap_prompt: Label = $TapPrompt
@onready var winner_pill: PanelContainer = $WinnerPill
@onready var winner_label: Label = $WinnerPill/Label

enum SpinState { HIDDEN, WAIT_SWIPE, SPINNING, SHOW_RESULT }

var _arena: Arena3DScript = null
var _state: SpinState = SpinState.HIDDEN
var _player_name: String = "Jake"
var _opponent_name: String = "Finn"
var _angular_vel_deg: float = 0.0
var _player_goes_first: bool = true
var _forced_winner: int = -1 # -1 = random, 0 = opponent, 1 = player (for deterministic LAN)
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _finger_tween: Tween = null


func _ready() -> void:
	visible = false


func bind_arena(arena: Arena3DScript) -> void:
	_arena = arena


func start_spin(p_name: String, opp_name: String, is_fc: bool = false, forced_player_first: int = -1) -> void:
	visible = true
	_state = SpinState.WAIT_SWIPE
	_player_name = p_name
	_opponent_name = opp_name
	_forced_winner = forced_player_first
	_dragging = false

	dim_rect.color = Color(0, 0, 0, 0.0)
	swipe_pill.visible = true
	finger_hint.visible = true
	tap_prompt.visible = false
	winner_pill.visible = false

	# Choose bottle or FC spinner asset
	var tex_pair := [NORMAL_SPINNER_TEX, NORMAL_SHADOW_TEX]
	if is_fc:
		tex_pair = FC_SPINNERS[randi() % FC_SPINNERS.size()]
	if ResourceLoader.exists(tex_pair[0]):
		bottle_sprite.texture = load(tex_pair[0])
	if ResourceLoader.exists(tex_pair[1]):
		bottle_shadow.texture = load(tex_pair[1])

	# Horizontal resting pose across the center board seam (matching Screenshot 4)
	bottle_pivot.rotation_degrees = 90.0
	bottle_shadow.rotation_degrees = 90.0

	if _arena:
		_arena.focus_ketchup_spin(0.5)

	_start_finger_hint()

	# If deterministic forced result (LAN), show quick spin right away
	if _forced_winner != -1:
		get_tree().create_timer(0.4).timeout.connect(func():
			if visible and _state == SpinState.WAIT_SWIPE:
				_trigger_spin(1.0)
		)


func _start_finger_hint() -> void:
	if _finger_tween and _finger_tween.is_running():
		_finger_tween.kill()
	finger_hint.visible = true
	var start_pos := Vector2(735.0, 290.0)
	finger_hint.position = start_pos
	finger_hint.modulate = Color(1, 1, 1, 0.95)
	_finger_tween = create_tween().set_loops()
	_finger_tween.tween_property(finger_hint, "position:y", start_pos.y - 120.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_finger_tween.parallel().tween_property(finger_hint, "modulate:a", 0.25, 0.85)
	_finger_tween.tween_callback(func():
		finger_hint.position = start_pos
		finger_hint.modulate.a = 0.95
	)


func _stop_finger_hint() -> void:
	if _finger_tween and _finger_tween.is_running():
		_finger_tween.kill()
	finger_hint.visible = false


func _process(delta: float) -> void:
	if _state != SpinState.SPINNING:
		return

	bottle_pivot.rotation_degrees = fposmod(bottle_pivot.rotation_degrees + _angular_vel_deg * delta, 360.0)
	bottle_shadow.rotation_degrees = bottle_pivot.rotation_degrees

	# Exponential friction matching CWKetchupBottleScript rigidbody drag
	_angular_vel_deg = maxf(0.0, _angular_vel_deg - maxf(180.0, _angular_vel_deg * 1.45) * delta)

	# Keep nudging near stop if forced winner or landing right on horizontal 90/270 boundary
	var a := bottle_pivot.rotation_degrees
	var on_boundary := (absf(a - 90.0) < 16.0 or absf(a - 270.0) < 16.0)
	if _angular_vel_deg <= 45.0 and on_boundary:
		_angular_vel_deg = 95.0

	if _angular_vel_deg <= 12.0:
		# Snap clearly toward the side it is pointing
		var p_first := (a > 90.0 and a < 270.0) # 180 deg = nozzle points DOWN toward Player
		if _forced_winner == 1:
			p_first = true
		elif _forced_winner == 0:
			p_first = false

		_player_goes_first = p_first
		var target_deg := 180.0 if _player_goes_first else 0.0
		var settle := create_tween().set_parallel(true)
		var shortest := wrapf(target_deg - a, -180.0, 180.0)
		settle.tween_property(bottle_pivot, "rotation_degrees", a + shortest, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		settle.tween_property(bottle_shadow, "rotation_degrees", a + shortest, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		settle.chain().tween_callback(_show_result)
		_state = SpinState.SHOW_RESULT
		_angular_vel_deg = 0.0


func _trigger_spin(strength: float = 1.0) -> void:
	if _state != SpinState.WAIT_SWIPE:
		return
	_state = SpinState.SPINNING
	_stop_finger_hint()
	swipe_pill.visible = false
	_angular_vel_deg = randf_range(950.0, 1550.0) * clampf(strength, 0.8, 1.5)
	if Audio and ResourceLoader.exists("res://assets/audio/sfx/CardMove.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/CardMove.wav"), -3.0)


func _show_result() -> void:
	var winner_name := _player_name if _player_goes_first else _opponent_name
	winner_label.text = "%s goes first!" % winner_name
	winner_pill.visible = true
	tap_prompt.visible = true
	winner_pill.modulate.a = 0.0
	tap_prompt.modulate.a = 0.0

	if Audio and ResourceLoader.exists("res://assets/audio/sfx/Bell.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/Bell.wav"), -4.0)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim_rect, "color:a", 0.32, 0.25)
	tw.tween_property(winner_pill, "modulate:a", 1.0, 0.25)
	tw.tween_property(tap_prompt, "modulate:a", 1.0, 0.25)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if _state == SpinState.WAIT_SWIPE:
			if mb.pressed:
				_dragging = true
				_drag_start = mb.position
			else:
				if _dragging:
					_dragging = false
					var dy: float = _drag_start.y - mb.position.y
					if dy > 22.0 or _drag_start.distance_to(mb.position) < 12.0:
						_trigger_spin(clampf(dy / 160.0, 0.9, 1.4))
			accept_event()
		elif _state == SpinState.SHOW_RESULT and mb.pressed and winner_pill.visible:
			_confirm_and_close()
			accept_event()
	elif event is InputEventMouseMotion and _state == SpinState.WAIT_SWIPE and _dragging:
		var mm := event as InputEventMouseMotion
		var dy: float = _drag_start.y - mm.position.y
		if dy > 45.0:
			_dragging = false
			_trigger_spin(clampf(dy / 140.0, 0.95, 1.45))
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		if _state == SpinState.WAIT_SWIPE:
			_trigger_spin(1.0)
			get_viewport().set_input_as_handled()
		elif _state == SpinState.SHOW_RESULT and winner_pill.visible:
			_confirm_and_close()
			get_viewport().set_input_as_handled()


func _confirm_and_close() -> void:
	_state = SpinState.HIDDEN
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		visible = false
		modulate.a = 1.0
		spin_completed.emit(_player_goes_first)
	)
