extends Control
class_name BattleWheelModal

## Card Wars Composition Component: Non-blocking Bottom-Center Battle Wheel.
## Embeds the generic standalone WheelSpinner from res://src/systems/timing_wheel/
## and renders authentic Card Wars Attack / Defend rings from db_Leaders.json + db_Quest.json.

const WheelConfig = preload("res://src/systems/timing_wheel/WheelConfig.gd")
const WheelSpinner = preload("res://src/systems/timing_wheel/WheelSpinner.gd")

const TEX_NEEDLE_ATK: Texture2D = preload("res://assets/textures/battle/ring/Ring_Bar_ATK.png")
const TEX_NEEDLE_DEF: Texture2D = preload("res://assets/textures/battle/ring/Ring_Bar_DEF.png")

signal clash_resolved(result: Dictionary)

@onready var ring_anchor: Control = $RingAnchor
@onready var wheel_container: CenterContainer = $RingAnchor/WheelContainer
@onready var star_burst_fx: TextureRect = $RingAnchor/StarBurstFX
@onready var ring_outline: TextureRect = $RingAnchor/RingOutline
@onready var needle_pivot: Control = $RingAnchor/NeedlePivot
@onready var needle_tex: TextureRect = $RingAnchor/NeedlePivot/NeedleTex
@onready var result_callout: Label = $ResultCallout
@onready var prompt_lbl: Label = $Prompt

var spinner: WheelSpinner
var _current_base_damage: int = 0
var _defender_atk: int = 0
var _is_defend_mode: bool = false
var _is_quick_mode: bool = false
var _resolved: bool = false


func _ready() -> void:
	visible = false

	var spinner_scene := preload("res://src/systems/timing_wheel/WheelSpinner.tscn")
	spinner = spinner_scene.instantiate() as WheelSpinner
	spinner.radius = 115.0
	spinner.custom_rim = true
	spinner.show_labels = false
	spinner.custom_minimum_size = Vector2(248, 248)
	spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_container.add_child(spinner)

	spinner.spin_completed.connect(_on_spinner_completed)
	gui_input.connect(_on_gui_input)


func _process(_delta: float) -> void:
	if visible and spinner and needle_pivot:
		needle_pivot.rotation_degrees = spinner.current_angle_deg


static func _parse_leader_rgba(rgba_str: String, fallback: Color) -> Color:
	var parts := rgba_str.split(":")
	if parts.size() >= 3:
		var r := float(parts[0]) / 255.0
		var g := float(parts[1]) / 255.0
		var b := float(parts[2]) / 255.0
		var a := float(parts[3]) / 255.0 if parts.size() >= 4 else 1.0
		return Color(r, g, b, clampf(a, 0.72, 1.0))
	return fallback


func _get_leader_and_quest_params() -> Dictionary:
	var leader: Dictionary = {}
	var quest: Dictionary = {}
	if GameManager and Database:
		leader = Database.get_leader(GameManager.player_hero_name)
		if GameManager.active_quest_id != "":
			quest = Database.get_quest(GameManager.active_quest_id)
	var spin_min := float(leader.get("time_for_1_spin_min", 0.18))
	var spin_max := float(leader.get("time_for_1_spin_max", 0.23))
	var spin_factor := maxf(0.5, float(quest.get("spin_factor", 2.0)))
	var rev_time := clampf(randf_range(spin_min, spin_max) * spin_factor, 0.22, 0.85)
	var speed_deg_sec := 360.0 / rev_time
	return {
		"leader": leader,
		"quest": quest,
		"speed_deg_sec": speed_deg_sec,
		"crit_mod": float(leader.get("crit_damage_mod", 2.0)),
	}


func start_attack_clash(
	attacker_name: String,
	target_name: String,
	base_damage: int,
	is_player: bool = true,
	hit_ratio_override: float = -1.0,
	crit_ratio_override: float = -1.0,
	force_quick: bool = false,
	opposing_has_creature: bool = true
) -> void:
	visible = true
	_resolved = false
	_is_defend_mode = false
	_current_base_damage = base_damage
	_defender_atk = 0
	modulate = Color.WHITE

	needle_tex.texture = TEX_NEEDLE_ATK
	needle_tex.offset_left = -18.0
	needle_tex.offset_top = -122.0
	needle_tex.offset_right = 18.0
	needle_tex.offset_bottom = 12.0
	prompt_lbl.text = "Tap to Attack!" if is_player else "%s vs %s" % [attacker_name, target_name]
	if star_burst_fx:
		star_burst_fx.visible = false
	if result_callout:
		result_callout.visible = false

	if ResourceLoader.exists("res://assets/audio/sfx/Ring_Drop.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/Ring_Drop.wav"), -4.0)

	var p := _get_leader_and_quest_params()
	var leader: Dictionary = p["leader"]
	var quest: Dictionary = p["quest"]

	var crit_ratio: float = crit_ratio_override if crit_ratio_override >= 0.0 else clampf(
		float(leader.get("ring_p1_crit_range", 0.07)) + float(quest.get("p1_crit_mod", 0.0)),
		0.03, 0.45
	)
	var hit_ratio: float
	var miss_ratio: float
	if not opposing_has_creature and is_player:
		# Empty enemy lane -> guaranteed Hit + Crit against Hero (100% green wheel)
		hit_ratio = maxf(0.0, 1.0 - crit_ratio)
		miss_ratio = 0.0
	elif hit_ratio_override >= 0.0:
		hit_ratio = hit_ratio_override
		miss_ratio = maxf(0.0, 1.0 - (hit_ratio + crit_ratio))
	else:
		hit_ratio = clampf(
			float(leader.get("ring_p1_hit_range", 0.80)) + float(quest.get("p1_hit_mod", 0.0)),
			0.08, 1.0 - crit_ratio
		)
		miss_ratio = maxf(0.0, 1.0 - (hit_ratio + crit_ratio))

	var crit_col := Color(0.08, 0.96, 0.22, 1.0)
	var hit_col := Color(0.16, 0.58, 0.24, 1.0)
	var miss_col := Color(0.56, 0.26, 0.24, 1.0)

	# Place Crit at 10..12 o'clock and Hit across main span per Screenshot 8 / e_001
	var sectors: Array = []
	if miss_ratio > 0.001:
		sectors.append({"id": "miss", "name": "MISS!", "ratio": miss_ratio, "color": miss_col, "multiplier": 0.0, "is_success": false})
	sectors.append({"id": "hit", "name": "ATTACK x1", "ratio": hit_ratio, "color": hit_col, "multiplier": 1.0, "is_success": true})
	sectors.append({"id": "crit", "name": "CRIT x2", "ratio": crit_ratio, "color": crit_col, "multiplier": p["crit_mod"], "is_success": true})

	_launch_wheel(sectors, float(p["speed_deg_sec"]), force_quick or not is_player)


func start_defend_clash(
	_attacker_name: String,
	_defender_name: String,
	incoming_damage: int,
	defender_atk: int = 0,
	force_quick: bool = false
) -> void:
	visible = true
	_resolved = false
	_is_defend_mode = true
	_current_base_damage = incoming_damage
	_defender_atk = defender_atk
	modulate = Color.WHITE

	needle_tex.texture = TEX_NEEDLE_DEF
	needle_tex.offset_left = -22.0
	needle_tex.offset_top = -122.0
	needle_tex.offset_right = 22.0
	needle_tex.offset_bottom = 12.0
	prompt_lbl.text = "Tap to Defend!"
	if star_burst_fx:
		star_burst_fx.visible = false
	if result_callout:
		result_callout.visible = false

	if ResourceLoader.exists("res://assets/audio/sfx/Ring_Drop.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/Ring_Drop.wav"), -4.0)

	var p := _get_leader_and_quest_params()
	var leader: Dictionary = p["leader"]
	var quest: Dictionary = p["quest"]

	var block_ratio := clampf(
		float(leader.get("ring_p2_hit_range", 0.15)) + float(quest.get("p2_hit_mod", 0.0)),
		0.05, 0.65
	)
	var counter_ratio := clampf(
		float(leader.get("ring_p2_crit_range", 0.05)) + float(quest.get("p2_crit_mod", 0.0)),
		0.03, 0.35
	)
	var miss_total := maxf(0.05, 1.0 - (block_ratio + counter_ratio))
	var miss_half := miss_total * 0.5

	var counter_col := Color(0.08, 0.96, 0.22, 1.0)
	var block_col := Color(0.14, 0.56, 0.22, 1.0)
	var miss_col := Color(0.56, 0.28, 0.24, 1.0)

	# Center green Block + Counter sectors around 6 o'clock (bottom) per Screenshot 9
	var sectors: Array = [
		{"id": "miss", "name": "HIT", "ratio": miss_half, "color": miss_col, "multiplier": 1.0, "is_success": false},
		{"id": "hit", "name": "BLOCK!", "ratio": block_ratio, "color": block_col, "multiplier": 0.0, "is_success": true},
		{"id": "crit", "name": "COUNTER!", "ratio": counter_ratio, "color": counter_col, "multiplier": 0.0, "is_success": true},
		{"id": "miss", "name": "HIT", "ratio": miss_half, "color": miss_col, "multiplier": 1.0, "is_success": false},
	]
	_launch_wheel(sectors, float(p["speed_deg_sec"]), force_quick)


func _launch_wheel(sectors: Array, speed_deg_sec: float, force_quick: bool) -> void:
	ring_anchor.scale = Vector2(0.45, 0.45)
	ring_anchor.pivot_offset = ring_anchor.size * 0.5
	var pop_tw := create_tween()
	pop_tw.tween_property(ring_anchor, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var cfg := WheelConfig.create_custom(sectors, speed_deg_sec)
	spinner.setup(cfg)
	needle_pivot.rotation_degrees = 0.0

	var is_gm_quick: bool = (GameManager.get("wheel_mode") == "QUICK") if GameManager else false
	_is_quick_mode = force_quick or is_gm_quick

	spinner.start_spin()
	if _is_quick_mode:
		var t := get_tree().create_timer(0.32)
		t.timeout.connect(func():
			if visible and not _resolved and spinner and spinner.state == WheelSpinner.State.SPINNING:
				spinner.stop_spin()
		)


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
		accept_event()


func _stop_wheel() -> void:
	if spinner and spinner.state == WheelSpinner.State.SPINNING:
		spinner.stop_spin()


func _on_spinner_completed(result: Dictionary) -> void:
	if _resolved:
		return
	_resolved = true

	var s_id := str(result.get("id", "hit"))
	var mult := float(result.get("multiplier", 1.0))
	var final_damage: int = 0
	var counter_damage: int = 0
	var is_blocked := false
	var is_counter := false

	if _is_defend_mode:
		if s_id == "crit":
			is_counter = true
			final_damage = 0
			counter_damage = _defender_atk
		elif s_id == "hit":
			is_blocked = true
			final_damage = 0
		else:
			final_damage = _current_base_damage
	else:
		final_damage = int(round(_current_base_damage * mult))

	if _is_defend_mode:
		if is_counter or is_blocked:
			if ResourceLoader.exists("res://assets/audio/sfx/Ring_Crit.wav"):
				Audio.play_sfx(load("res://assets/audio/sfx/Ring_Crit.wav"))
		else:
			if ResourceLoader.exists("res://assets/audio/sfx/Ring_Hit.wav"):
				Audio.play_sfx(load("res://assets/audio/sfx/Ring_Hit.wav"))
	else:
		if s_id == "crit" and ResourceLoader.exists("res://assets/audio/sfx/Ring_Crit.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/Ring_Crit.wav"))
		elif s_id == "miss" and ResourceLoader.exists("res://assets/audio/sfx/Ring_Miss.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/Ring_Miss.wav"))
		elif ResourceLoader.exists("res://assets/audio/sfx/Ring_Hit.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/Ring_Hit.wav"))

	_show_wheel_outcome_fx(s_id, is_counter, is_blocked)

	var clash_res := {
		"id": s_id,
		"name": str(result.get("name", "Hit")),
		"mode": "defend" if _is_defend_mode else "attack",
		"multiplier": mult,
		"base_damage": _current_base_damage,
		"final_damage": final_damage,
		"counter_damage": counter_damage,
		"is_blocked": is_blocked,
		"is_counter": is_counter,
		"angle_deg": float(result.get("angle_deg", 0.0)),
	}

	await get_tree().create_timer(0.42).timeout
	var fade_tw := create_tween()
	fade_tw.tween_property(self, "modulate:a", 0.0, 0.16)
	await fade_tw.finished

	visible = false
	modulate.a = 1.0
	if star_burst_fx:
		star_burst_fx.visible = false
	if result_callout:
		result_callout.visible = false
	clash_resolved.emit(clash_res)


func _show_wheel_outcome_fx(s_id: String, is_counter: bool, is_blocked: bool) -> void:
	if star_burst_fx:
		star_burst_fx.visible = (s_id != "miss") or _is_defend_mode
		if star_burst_fx.visible:
			star_burst_fx.scale = Vector2(0.55, 0.55)
			star_burst_fx.modulate = Color(1, 1, 1, 0.95)
			var tw_fx := create_tween()
			tw_fx.set_parallel(true)
			tw_fx.tween_property(star_burst_fx, "scale", Vector2(1.18, 1.18), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_fx.tween_property(star_burst_fx, "modulate:a", 0.72, 0.35)
	if result_callout:
		var txt := "Good!"
		var col := Color(1.0, 0.90, 0.16, 1.0)
		var out_col := Color(0.78, 0.18, 0.06, 1.0)
		if _is_defend_mode:
			if is_counter:
				txt = "Counter!"
				col = Color(0.32, 1.0, 0.38, 1.0)
				out_col = Color(0.06, 0.38, 0.10, 1.0)
			elif is_blocked:
				txt = "Blocked!"
				col = Color(0.38, 0.92, 1.0, 1.0)
				out_col = Color(0.06, 0.25, 0.45, 1.0)
			else:
				txt = "Miss!"
				col = Color(1.0, 0.36, 0.30, 1.0)
				out_col = Color(0.35, 0.04, 0.04, 1.0)
		else:
			if s_id == "crit":
				txt = "Perfect!"
				col = Color(0.35, 1.0, 0.36, 1.0)
				out_col = Color(0.08, 0.45, 0.06, 1.0)
			elif s_id == "miss":
				txt = "Miss!"
				col = Color(1.0, 0.36, 0.30, 1.0)
				out_col = Color(0.35, 0.04, 0.04, 1.0)
		result_callout.text = txt
		if result_callout.label_settings:
			result_callout.label_settings.font_color = col
			result_callout.label_settings.outline_color = out_col
		result_callout.visible = true
		result_callout.scale = Vector2(0.5, 0.5)
		create_tween().tween_property(result_callout, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
