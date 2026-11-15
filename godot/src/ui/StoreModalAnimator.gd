class_name StoreModalAnimator
extends RefCounted
## Reproduces Card Wars Unity D_2_MarketGems_New / D_3_MarketInventory popup scale + dimmer transitions.

const OPEN_DURATION := 0.8
const CLOSE_DURATION := 0.24
const DIMMER_OPEN_DURATION := 0.45
const DIMMER_ALPHA := 0.55

# Exact 5-point Unity TweenScale bounce keyframes: [normalized_t, value]
const SCALE_KEYS := [
	[0.0, 0.0],
	[0.4059757, 1.078034],
	[0.6047682, 0.8352123],
	[0.7755909, 0.9902204],
	[1.0, 1.0],
]


static func evaluate_bounce(u: float) -> float:
	var t := clampf(u, 0.0, 1.0)
	for i in range(SCALE_KEYS.size() - 1):
		var t0: float = SCALE_KEYS[i][0]
		var t1: float = SCALE_KEYS[i + 1][0]
		if t <= t1:
			var seg_t := clampf((t - t0) / maxf(t1 - t0, 0.0001), 0.0, 1.0)
			# Smooth hermite-like ease between extrema
			var s := seg_t * seg_t * (3.0 - 2.0 * seg_t)
			return lerpf(SCALE_KEYS[i][1], SCALE_KEYS[i + 1][1], s)
	return 1.0


static func _center_pivot(frame: Control) -> void:
	if not frame:
		return
	var sz := frame.size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = frame.custom_minimum_size
	frame.pivot_offset = sz * 0.5


static func play_open(host: Control, dimmer: ColorRect, frame: Control, prev_tween: Tween = null) -> Tween:
	if prev_tween and prev_tween.is_valid():
		prev_tween.kill()
	host.visible = true
	if dimmer:
		dimmer.color.a = 0.0
	if frame:
		_center_pivot(frame)
		frame.scale = Vector2.ZERO
	var tw := host.create_tween()
	if dimmer:
		tw.tween_property(dimmer, "color:a", DIMMER_ALPHA, DIMMER_OPEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if frame:
		tw.parallel().tween_method(func(u: float):
			_center_pivot(frame)
			var s := evaluate_bounce(u)
			frame.scale = Vector2(s, s)
		, 0.0, 1.0, OPEN_DURATION)
	return tw


static func play_close(host: Control, dimmer: ColorRect, frame: Control, prev_tween: Tween = null, on_finished: Callable = Callable()) -> Tween:
	if prev_tween and prev_tween.is_valid():
		prev_tween.kill()
	if frame:
		_center_pivot(frame)
	var tw := host.create_tween()
	if dimmer:
		tw.tween_property(dimmer, "color:a", 0.0, CLOSE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if frame:
		tw.parallel().tween_property(frame, "scale", Vector2.ZERO, CLOSE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		host.visible = false
		if frame:
			frame.scale = Vector2.ONE
		if dimmer:
			dimmer.color.a = DIMMER_ALPHA
		if on_finished.is_valid():
			on_finished.call()
	)
	return tw


static func attach_button_reaction(btn: BaseButton) -> void:
	if not btn or btn.has_meta("_reaction_attached"):
		return
	btn.set_meta("_reaction_attached", true)
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.86, 0.86), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
