class_name ChestIconBase
extends Node3D

signal open_burst
signal card_pop
signal open_finished
signal close_finished

enum State { IDLE, OPENING, OPEN_HOLD, CLOSING }

const SFX_OPEN_SHAKE: AudioStream = preload("res://assets/audio/sfx/FX_LootDrop_Chest.wav")
const SFX_OPEN_BURST: AudioStream = preload("res://assets/audio/sfx/FX_LootDrop_ChestOpen.wav")
const SFX_CLOSE: AudioStream = preload("res://assets/audio/sfx/Gatcha_Chest_Close.wav")
const SFX_CARD_POP: AudioStream = preload("res://assets/audio/sfx/Map_HeartEarn.wav")

var _state: int = State.IDLE
var _anim_time: float = 0.0
var _was_visible: bool = false
var _burst_fired: bool = false
var _card_pop_fired: bool = false
var _idle_audio_enabled: bool = false
var _rattle_stream: AudioStream = null
var _rattle_time: float = 0.2
var _open_burst_time: float = 2.07
var _card_pop_time: float = 4.33
var _sfx_player: AudioStreamPlayer = null


func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("SFX") >= 0:
		_sfx_player.bus = "SFX"
	add_child(_sfx_player)
	_apply_idle_frame(0.0)


func set_idle_audio_enabled(enabled: bool) -> void:
	_idle_audio_enabled = enabled
	if not enabled:
		stop_audio()


func stop_audio() -> void:
	if _sfx_player and _sfx_player.playing:
		_sfx_player.stop()


func reset_anim() -> void:
	_state = State.IDLE
	_anim_time = 0.0
	_burst_fired = false
	_card_pop_fired = false
	_apply_idle_frame(0.0)


func play_open(speed_scale: float = 1.0) -> void:
	set_meta("open_speed", speed_scale)
	_state = State.OPENING
	_anim_time = 0.0
	_burst_fired = false
	_card_pop_fired = false
	_apply_open_frame(0.0)
	_play_stream(SFX_OPEN_SHAKE)


func play_close() -> void:
	_state = State.CLOSING
	_anim_time = 0.0
	_apply_close_frame(0.0)
	_play_stream(SFX_CLOSE)


func set_open_preview_time(t: float) -> void:
	_state = State.OPEN_HOLD
	_anim_time = clampf(t, 0.0, _get_open_duration())
	_apply_open_frame(_anim_time)


func is_opening_or_open() -> bool:
	return _state == State.OPENING or _state == State.OPEN_HOLD or _state == State.CLOSING


func _process(delta: float) -> void:
	var vis := is_visible_in_tree()
	if not _was_visible and vis:
		reset_anim()
	_was_visible = vis
	if not vis:
		stop_audio()
		return

	match _state:
		State.IDLE:
			var dur := _get_idle_duration()
			var prev_t := _anim_time
			_anim_time = fmod(_anim_time + delta, dur)
			if _idle_audio_enabled and _rattle_stream != null:
				var crossed := (prev_t < _rattle_time and _anim_time >= _rattle_time) or (_anim_time < prev_t and (_rattle_time >= prev_t or _rattle_time <= _anim_time))
				if crossed:
					_play_stream(_rattle_stream)
			_apply_idle_frame(_anim_time)
		State.OPENING:
			var speed := float(get_meta("open_speed", 1.0))
			_anim_time += delta * speed
			if not _burst_fired and _anim_time >= _open_burst_time:
				_burst_fired = true
				_play_stream(SFX_OPEN_BURST)
				open_burst.emit()
			if not _card_pop_fired and _anim_time >= _card_pop_time:
				_card_pop_fired = true
				_play_stream(SFX_CARD_POP)
				card_pop.emit()
			var dur_open := _get_open_duration()
			if _anim_time >= dur_open:
				_anim_time = dur_open
				_apply_open_frame(dur_open)
				_state = State.OPEN_HOLD
				open_finished.emit()
			else:
				_apply_open_frame(_anim_time)
		State.OPEN_HOLD:
			pass
		State.CLOSING:
			_anim_time += delta
			var dur_close := _get_close_duration()
			if _anim_time >= dur_close:
				_apply_close_frame(dur_close)
				_state = State.IDLE
				_anim_time = 0.0
				_apply_idle_frame(0.0)
				close_finished.emit()
			else:
				_apply_close_frame(_anim_time)


func _play_stream(stream: AudioStream) -> void:
	if _sfx_player and stream:
		_sfx_player.stream = stream
		_sfx_player.play()


func _get_idle_duration() -> float:
	return 4.0


func _get_open_duration() -> float:
	return 6.0


func _get_close_duration() -> float:
	return 1.666667


func _apply_idle_frame(_t: float) -> void:
	pass


func _apply_open_frame(_t: float) -> void:
	pass


func _apply_close_frame(_t: float) -> void:
	pass


func _apply_bone(node: Node3D, pos_keys: Array, rot_keys: Array, scale_keys: Array, t: float) -> void:
	if not node:
		return
	if not pos_keys.is_empty():
		node.position = _eval_vec3(pos_keys, t)
	if not rot_keys.is_empty():
		node.quaternion = _eval_quat(rot_keys, t)
	if not scale_keys.is_empty():
		node.scale = _eval_vec3(scale_keys, t)


func _eval_quat(keys: Array, t: float) -> Quaternion:
	if keys.is_empty():
		return Quaternion.IDENTITY
	if t <= keys[0][0]:
		var q0: Vector4 = keys[0][1]
		return Quaternion(q0.x, q0.y, q0.z, q0.w).normalized()
	var last_idx := keys.size() - 1
	if t >= keys[last_idx][0]:
		var ql: Vector4 = keys[last_idx][1]
		return Quaternion(ql.x, ql.y, ql.z, ql.w).normalized()
	for i in range(last_idx):
		var t0: float = keys[i][0]
		var t1: float = keys[i + 1][0]
		if t >= t0 and t <= t1:
			var dt := t1 - t0
			if dt <= 0.000001:
				var qs: Vector4 = keys[i][1]
				return Quaternion(qs.x, qs.y, qs.z, qs.w).normalized()
			var u := (t - t0) / dt
			var u2 := u * u
			var u3 := u2 * u
			var h00 := 2.0 * u3 - 3.0 * u2 + 1.0
			var h10 := u3 - 2.0 * u2 + u
			var h01 := -2.0 * u3 + 3.0 * u2
			var h11 := u3 - u2
			var p0: Vector4 = keys[i][1]
			var m0: Vector4 = keys[i][3] * dt
			var p1: Vector4 = keys[i + 1][1]
			var m1: Vector4 = keys[i + 1][2] * dt
			if p0.dot(p1) < 0.0:
				p1 = -p1
				m1 = -m1
			var q := p0 * h00 + m0 * h10 + p1 * h01 + m1 * h11
			return Quaternion(q.x, q.y, q.z, q.w).normalized()
	var qr: Vector4 = keys[0][1]
	return Quaternion(qr.x, qr.y, qr.z, qr.w).normalized()


func _eval_vec3(keys: Array, t: float) -> Vector3:
	if keys.is_empty():
		return Vector3.ZERO
	if t <= keys[0][0]:
		return keys[0][1]
	var last_idx := keys.size() - 1
	if t >= keys[last_idx][0]:
		return keys[last_idx][1]
	for i in range(last_idx):
		var t0: float = keys[i][0]
		var t1: float = keys[i + 1][0]
		if t >= t0 and t <= t1:
			var dt := t1 - t0
			if dt <= 0.000001:
				return keys[i][1]
			var u := (t - t0) / dt
			var u2 := u * u
			var u3 := u2 * u
			var h00 := 2.0 * u3 - 3.0 * u2 + 1.0
			var h10 := u3 - 2.0 * u2 + u
			var h01 := -2.0 * u3 + 3.0 * u2
			var h11 := u3 - u2
			var p0: Vector3 = keys[i][1]
			var m0: Vector3 = keys[i][3] * dt
			var p1: Vector3 = keys[i + 1][1]
			var m1: Vector3 = keys[i + 1][2] * dt
			return p0 * h00 + m0 * h10 + p1 * h01 + m1 * h11
	return keys[0][1]
