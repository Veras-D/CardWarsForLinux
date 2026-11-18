extends Control
class_name KetchupBottleSpinner

## First-Turn Spinner (CWKetchupBottleScript + BattleScene.unity parity).
## Randomly selects from normalSpinners (FishBone, HotDog, KetchupBottle, PizzaSlice)
## or fcSpinners (FcSword, FcShard) matching BattleScene.unity, spins clockwise or
## counter-clockwise in any swipe direction using angular gesture delta around the
## spinner center, decelerates via PhysX angularDrag = 3.0 down to natural rest,
## displays "[Hero] goes first!" + "Tap anywhere on the screen", and continues.

const Arena3DScript = preload("res://src/battle/BattleArena3D.gd")

signal spin_completed(player_goes_first: bool)

const UNIT_PX: float = 16.0
const SHADOW_SCREEN_OFFSET := Vector2(-10.0, 10.0)
const SPIN_SFX_PATH: String = "res://assets/audio/sfx/Ketchup_Final.wav"

# Physics constants directly matching CWKetchupBottleScript.cs & BattleScene.unity Rigidbody
const DRAG_DISTANCE_PX: float = 5.0
const SPIN_ANGLE_SCALE: float = 0.75
const MIN_ANGULAR_VELOCITY_RAD: float = 0.7
const ANGULAR_VELOCITY_SCALE: float = 10.0
const ANGULAR_RANDOMNESS: float = 1.0
const FORCE_ANGULAR_VELOCITY_RAD: float = 2.0
const STOP_ANGULAR_VELOCITY_RAD: float = 0.1
const RIGIDBODY_ANGULAR_DRAG: float = 3.0
const MIN_LAUNCH_ANGULAR_VEL_RAD: float = 18.0
const MAX_LAUNCH_ANGULAR_VEL_RAD: float = 95.0

# Exact Unity normalSpinners array (Assets/Scene/_hirez/Scenes/BattleScene.unity &8004)
const NORMAL_SPINNERS: Array[Dictionary] = [
	{
		"sprite": "res://assets/textures/battle/banners/Spinner_Fish.png",
		"shadow": "res://assets/textures/battle/banners/Spinner_Fish_Shadow.png",
		"scale": Vector2(6.6, 20.0),
	},
	{
		"sprite": "res://assets/textures/battle/banners/Spinner_Hotdog.png",
		"shadow": "res://assets/textures/battle/banners/Spinner_Hotdog_Shadow.png",
		"scale": Vector2(6.6, 20.0),
	},
	{
		"sprite": "res://assets/textures/battle/banners/Spinner_Ketchup.png",
		"shadow": "res://assets/textures/battle/banners/Spinner_Ketchup_Shadow.png",
		"scale": Vector2(6.6, 20.0),
	},
	{
		"sprite": "res://assets/textures/battle/banners/Spinner_Pizza.png",
		"shadow": "res://assets/textures/battle/banners/Spinner_Pizza_Shadow.png",
		"scale": Vector2(11.5, 20.0),
	},
]

# Exact Unity fcSpinners array (Assets/Scene/_hirez/Scenes/BattleScene.unity &8004)
const FC_SPINNERS: Array[Dictionary] = [
	{
		"sprite": "res://assets/textures/battle/banners/Spinner_Sword.png",
		"shadow": "res://assets/textures/battle/banners/Spinner_Sword_Shadow.png",
		"scale": Vector2(8.0, 20.0),
	},
	{
		"sprite": "res://assets/textures/battle/banners/Spinner_Shard.png",
		"shadow": "res://assets/textures/battle/banners/Spinner_Shard_Shadow.png",
		"scale": Vector2(4.7, 16.6),
	},
]

@onready var dim_rect: ColorRect = $DimRect
@onready var bottle_center: Control = $BottleCenter
@onready var bottle_pivot: Control = $BottleCenter/BottlePivot
@onready var bottle_shadow: TextureRect = $BottleCenter/BottleShadow
@onready var bottle_sprite: TextureRect = $BottleCenter/BottlePivot/BottleSprite
@onready var finger_hint: TextureRect = $FingerHint
@onready var swipe_pill: PanelContainer = $SwipePill
@onready var swipe_label: Label = $SwipePill/Label
@onready var tap_prompt: PanelContainer = $TapPrompt
@onready var tap_label: Label = $TapPrompt/Label
@onready var winner_pill: PanelContainer = $WinnerPill
@onready var winner_label: Label = $WinnerPill/Label

enum SpinState { HIDDEN, WAIT_SWIPE, SPINNING, SHOW_RESULT }

var _arena: Arena3DScript = null
var _state: SpinState = SpinState.HIDDEN
var _player_name: String = "Jake"
var _opponent_name: String = "Finn"
var _angular_vel_rad: float = 0.0
var _pending_ang_vel_rad: float = 0.0
var _player_goes_first: bool = true
var _forced_winner: int = -1 # -1 = random, 0 = opponent, 1 = player (for deterministic LAN)
var _pointer_down: bool = false
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _prev_drag_pos: Vector2 = Vector2.ZERO
var _finger_tween: Tween = null
var _prompt_pulse_tween: Tween = null


func _ready() -> void:
	visible = false


func bind_arena(arena: Arena3DScript) -> void:
	_arena = arena


func start_spin(p_name: String, opp_name: String, is_fc: bool = false, forced_player_first: int = -1) -> void:
	visible = true
	modulate.a = 1.0
	_state = SpinState.WAIT_SWIPE
	_player_name = p_name
	_opponent_name = opp_name
	_forced_winner = forced_player_first
	_pointer_down = false
	_dragging = false
	_angular_vel_rad = 0.0
	_pending_ang_vel_rad = 0.0

	dim_rect.color = Color(0, 0, 0, 0.0)
	swipe_pill.visible = true
	swipe_pill.modulate = Color.WHITE
	finger_hint.visible = true
	tap_prompt.visible = false
	winner_pill.visible = false
	_start_prompt_pulse(swipe_label)

	# Choose from normalSpinners (4) or fcSpinners (2) matching CWKetchupBottleScript.Start()
	var pool: Array[Dictionary] = FC_SPINNERS if is_fc else NORMAL_SPINNERS
	var spinner_def: Dictionary = pool[randi() % pool.size()]
	_apply_spinner_definition(spinner_def)

	# Horizontal resting pose pointing LEFT across the center board seam (270 deg in Godot)
	bottle_pivot.rotation_degrees = 270.0
	bottle_shadow.rotation_degrees = 270.0
	bottle_shadow.position = bottle_pivot.position + SHADOW_SCREEN_OFFSET

	if _arena:
		_arena.focus_ketchup_spin(0.5)

	_start_finger_hint()

	# If deterministic forced result (LAN), show quick spin right away
	if _forced_winner != -1:
		get_tree().create_timer(0.4).timeout.connect(func():
			if visible and _state == SpinState.WAIT_SWIPE:
				_trigger_spin_random_dir()
		)


func _apply_spinner_definition(spinner_def: Dictionary) -> void:
	var sprite_path := str(spinner_def.get("sprite", ""))
	var shadow_path := str(spinner_def.get("shadow", ""))
	var u_scale: Vector2 = spinner_def.get("scale", Vector2(6.6, 20.0))

	if ResourceLoader.exists(sprite_path):
		bottle_sprite.texture = load(sprite_path)
	if ResourceLoader.exists(shadow_path):
		bottle_shadow.texture = load(shadow_path)

	var display_size := u_scale * UNIT_PX
	var center_local := bottle_center.size * 0.5

	bottle_pivot.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bottle_pivot.size = display_size
	bottle_pivot.pivot_offset = display_size * 0.5
	bottle_pivot.position = center_local - display_size * 0.5

	bottle_shadow.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bottle_shadow.size = display_size
	bottle_shadow.pivot_offset = display_size * 0.5
	bottle_shadow.position = bottle_pivot.position + SHADOW_SCREEN_OFFSET


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


## Unity TweenAlpha parity (BattleScene.unity &7460 BottleSpin_Label & &6877 TapTheScreen):
## PingPong EaseOut between alpha 0.0 and 1.0 over 1.0s on label text only (pill BG stays solid).
func _start_prompt_pulse(lbl: Label) -> void:
	_stop_prompt_pulse()
	if not lbl:
		return
	lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_prompt_pulse_tween = create_tween().set_loops()
	_prompt_pulse_tween.tween_property(lbl, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_prompt_pulse_tween.tween_property(lbl, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _stop_prompt_pulse() -> void:
	if _prompt_pulse_tween and _prompt_pulse_tween.is_valid():
		_prompt_pulse_tween.kill()
	_prompt_pulse_tween = null
	if swipe_label:
		swipe_label.modulate.a = 1.0
	if tap_label:
		tap_label.modulate.a = 1.0


func _get_spinner_screen_center() -> Vector2:
	return bottle_center.global_position + bottle_center.size * 0.5


func _process(delta: float) -> void:
	if _state != SpinState.SPINNING:
		return

	var step_deg := rad_to_deg(_angular_vel_rad) * delta
	bottle_pivot.rotation_degrees = fposmod(bottle_pivot.rotation_degrees + step_deg, 360.0)
	bottle_shadow.rotation_degrees = bottle_pivot.rotation_degrees
	bottle_shadow.position = bottle_pivot.position + SHADOW_SCREEN_OFFSET

	# Unity PhysX angularDrag (m_AngularDrag = 3.0) decay
	_angular_vel_rad /= (1.0 + RIGIDBODY_ANGULAR_DRAG * delta)

	var deg := bottle_pivot.rotation_degrees
	var cos_a := cos(deg_to_rad(deg)) # < 0 when pointing down toward Player; > 0 toward Opponent
	var p_first := cos_a < 0.0
	var on_horizontal_boundary := absf(cos_a) < 0.08

	if absf(_angular_vel_rad) <= FORCE_ANGULAR_VELOCITY_RAD:
		var needs_flip := (_forced_winner == 1 and not p_first) or (_forced_winner == 0 and p_first)
		if needs_flip or on_horizontal_boundary:
			var dir_sign := -1.0 if _angular_vel_rad < 0.0 else 1.0
			_angular_vel_rad = FORCE_ANGULAR_VELOCITY_RAD * dir_sign

	if absf(_angular_vel_rad) <= STOP_ANGULAR_VELOCITY_RAD:
		var final_needs_flip := (_forced_winner == 1 and not p_first) or (_forced_winner == 0 and p_first)
		if final_needs_flip or on_horizontal_boundary:
			var dir_sign := -1.0 if _angular_vel_rad < 0.0 else 1.0
			_angular_vel_rad = STOP_ANGULAR_VELOCITY_RAD * dir_sign
			return

		_angular_vel_rad = 0.0
		_player_goes_first = p_first
		_state = SpinState.SHOW_RESULT
		_show_result()


func _launch_spin_rad(vel_rad: float) -> void:
	if _state != SpinState.WAIT_SWIPE:
		return
	_state = SpinState.SPINNING
	_pointer_down = false
	_dragging = false
	_stop_finger_hint()
	_stop_prompt_pulse()
	swipe_pill.visible = false

	var dir_sign := 1.0 if vel_rad >= 0.0 else -1.0
	var mag := clampf(absf(vel_rad), MIN_LAUNCH_ANGULAR_VEL_RAD, MAX_LAUNCH_ANGULAR_VEL_RAD)
	_angular_vel_rad = mag * dir_sign

	if Audio and ResourceLoader.exists(SPIN_SFX_PATH):
		Audio.play_sfx(load(SPIN_SFX_PATH), -2.0)


func _trigger_spin_random_dir() -> void:
	var dir_sign := 1.0 if randf() > 0.5 else -1.0
	var base_rad := randf_range(26.0, 46.0)
	_launch_spin_rad(base_rad * dir_sign)


func _show_result() -> void:
	_stop_finger_hint()
	swipe_pill.visible = false
	var winner_name := _player_name if _player_goes_first else _opponent_name
	winner_label.text = "%s goes first!" % winner_name
	winner_label.modulate = Color.WHITE
	winner_pill.visible = true
	tap_prompt.visible = true
	winner_pill.modulate.a = 0.0
	tap_prompt.modulate.a = 0.0
	if tap_label:
		tap_label.modulate.a = 1.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(winner_pill, "modulate:a", 1.0, 0.25)
	tw.tween_property(tap_prompt, "modulate:a", 1.0, 0.25)
	tw.chain().tween_callback(func():
		if _state == SpinState.SHOW_RESULT and visible:
			_start_prompt_pulse(tap_label)
	)


func _handle_drag_motion(pos: Vector2) -> void:
	if not _dragging:
		if _drag_start.distance_squared_to(pos) > DRAG_DISTANCE_PX * DRAG_DISTANCE_PX:
			_dragging = true
	else:
		var center := _get_spinner_screen_center()
		var cur_v := pos - center
		var prev_v := _prev_drag_pos - center
		if cur_v.length() > 10.0 and prev_v.length() > 10.0:
			var angle_delta_deg := rad_to_deg(prev_v.angle_to(cur_v))
			_pending_ang_vel_rad += angle_delta_deg * SPIN_ANGLE_SCALE
			if absf(_pending_ang_vel_rad) > MIN_ANGULAR_VELOCITY_RAD:
				var sign_dir := 1.0 if _pending_ang_vel_rad > 0.0 else -1.0
				var launch_rad := (_pending_ang_vel_rad + randf() * ANGULAR_RANDOMNESS * sign_dir) * ANGULAR_VELOCITY_SCALE
				_launch_spin_rad(launch_rad)
				return
	_prev_drag_pos = pos


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if _state == SpinState.WAIT_SWIPE:
			if st.pressed:
				_pointer_down = true
				_dragging = false
				_drag_start = st.position
				_prev_drag_pos = st.position
				_pending_ang_vel_rad = 0.0
			elif _pointer_down:
				_pointer_down = false
				_dragging = false
				if _drag_start.distance_to(st.position) > 20.0 or _drag_start.distance_to(st.position) < 12.0:
					_trigger_spin_random_dir()
			accept_event()
		elif _state == SpinState.SHOW_RESULT and st.pressed and winner_pill.visible:
			_confirm_and_close()
			accept_event()
		return

	if event is InputEventScreenDrag and _state == SpinState.WAIT_SWIPE and _pointer_down:
		var sd := event as InputEventScreenDrag
		_handle_drag_motion(sd.position)
		accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if _state == SpinState.WAIT_SWIPE:
			if mb.pressed:
				_pointer_down = true
				_dragging = false
				_drag_start = mb.position
				_prev_drag_pos = mb.position
				_pending_ang_vel_rad = 0.0
			elif _pointer_down:
				_pointer_down = false
				_dragging = false
				var drag_len := _drag_start.distance_to(mb.position)
				if absf(_pending_ang_vel_rad) > 0.05:
					var dir_sign := 1.0 if _pending_ang_vel_rad > 0.0 else -1.0
					_launch_spin_rad(maxf(absf(_pending_ang_vel_rad) * ANGULAR_VELOCITY_SCALE, randf_range(26.0, 42.0)) * dir_sign)
				elif drag_len > 20.0 or drag_len < 12.0:
					_trigger_spin_random_dir()
			accept_event()
		elif _state == SpinState.SHOW_RESULT and mb.pressed and winner_pill.visible:
			_confirm_and_close()
			accept_event()
	elif event is InputEventMouseMotion and _state == SpinState.WAIT_SWIPE and _pointer_down:
		var mm := event as InputEventMouseMotion
		_handle_drag_motion(mm.position)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		if _state == SpinState.WAIT_SWIPE:
			_trigger_spin_random_dir()
			get_viewport().set_input_as_handled()
		elif _state == SpinState.SHOW_RESULT and winner_pill.visible:
			_confirm_and_close()
			get_viewport().set_input_as_handled()


func _confirm_and_close() -> void:
	_state = SpinState.HIDDEN
	_stop_prompt_pulse()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		visible = false
		modulate.a = 1.0
		spin_completed.emit(_player_goes_first)
	)
