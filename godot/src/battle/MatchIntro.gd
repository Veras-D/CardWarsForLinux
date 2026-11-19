extends Control
class_name MatchIntro

const Arena3DScript = preload("res://src/battle/BattleArena3D.gd")
const IntroAnims = preload("res://src/battle/BattleIntroAnims.gd")

## Authentic 3D Pre-Battle Intro Overlay (CWBattleIntroController + BattleScene.unity parity).
## Evaluates the exact BattleIntro_CUT1..4.anim camera curves on BattleArena3D:
##   Cut 1 (1.333s): Wide arena pullback + Phase1 ArenaName banner ("Tree House")
##   Cut 2 (1.567s): Pan onto Player 1 + P1 IntroP1 anim + BG_RootP1 name banner
##   Cut 3 (2.033s): Pan onto Player 2 + P2 IntroP2 anim + BG_RootP2 name banner
##   Cut 4 (1.167s + Take 001_15 1.6s): Zoom back + 3D Battle_Battle.glb ("BATTLE!" sword/shield)

signal intro_completed

@onready var banner_viewport_container: SubViewportContainer = $BattleBannerViewportContainer
@onready var battle_banner_node: Node3D = $BattleBannerViewportContainer/SubViewport/Battle_Battle
@onready var phase1_banner: Control = $Phase1
@onready var arena_label: Label = $Phase1/ArenaName
@onready var p1_banner: Control = $BG_RootP1
@onready var p1_name_label: Label = $BG_RootP1/P1_Name
@onready var p2_banner: Control = $BG_RootP2
@onready var p2_name_label: Label = $BG_RootP2/P2_Name
@onready var skip_hint: Label = $SkipHint

@onready var audio_sfx: AudioStreamPlayer = $AudioSFX
@onready var audio_vo: AudioStreamPlayer = $AudioVO

var _arena: Arena3DScript = null
var _banner_anim_player: AnimationPlayer = null
var _banner_tween: Tween = null
var _can_skip: bool = false
var _finished: bool = false
var _playing_cuts: bool = false
var _cut_idx: int = 0
var _cut_elapsed: float = 0.0
var _cut_duration: float = 0.0
var _tween_out_triggered: bool = false
var _player_name: String = "Jake"
var _opponent_name: String = "Finn"


func _ready() -> void:
	visible = false
	if audio_vo and AudioServer.get_bus_index("Voice") != -1:
		audio_vo.bus = "Voice"
	if audio_sfx and AudioServer.get_bus_index("SFX") != -1:
		audio_sfx.bus = "SFX"
	if battle_banner_node:
		_banner_anim_player = battle_banner_node.find_child("AnimationPlayer", true, false) as AnimationPlayer


func bind_arena(arena: Arena3DScript) -> void:
	_arena = arena


func play_intro(player_name: String, opponent_name: String, _p1_max_hp: int, _p2_max_hp: int, arena_name: String = "Tree House") -> void:
	visible = true
	_finished = false
	_can_skip = false
	_playing_cuts = false
	_player_name = player_name
	_opponent_name = opponent_name
	modulate = Color.WHITE

	p1_name_label.text = player_name.to_upper()
	p2_name_label.text = opponent_name.to_upper()
	arena_label.text = arena_name if arena_name != "" else "Tree House"

	_resize_banner_to_label(p1_banner, p1_name_label, 72.0, 220.0)
	_resize_banner_to_label(p2_banner, p2_name_label, 72.0, 220.0)
	_resize_banner_to_label(phase1_banner, arena_label, 96.0, 340.0)

	phase1_banner.visible = false
	p1_banner.visible = false
	p2_banner.visible = false
	banner_viewport_container.visible = false
	skip_hint.visible = false

	if _arena:
		_arena.set_heroes_card_on_table(false)
		_arena.set_cards_in_hand_visible(true, true)
		_arena.play_hero_anim(true, "anim_intro_p1", "")
		_arena.play_hero_anim(false, "anim_intro_p2", "")

	# Allow silent click/key skip after 0.65s (original shows no skip caption)
	get_tree().create_timer(0.65).timeout.connect(func():
		if visible and not _finished:
			_can_skip = true
	)

	_begin_cut(1)


func _resize_banner_to_label(banner: Control, lbl: Label, padding_w: float, min_w: float = 280.0) -> void:
	var font := lbl.get_theme_font("font")
	var fsize := lbl.get_theme_font_size("font_size")
	var text_w := 240.0
	if font:
		text_w = font.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize).x
	var w := maxf(min_w, text_w + padding_w)
	var h := banner.size.y if banner.size.y > 0.0 else 110.0
	banner.offset_left = -w * 0.5
	banner.offset_right = w * 0.5
	banner.pivot_offset = Vector2(w * 0.5, h * 0.5)


func _begin_cut(cut_idx: int) -> void:
	if _finished:
		return
	_cut_idx = cut_idx
	_cut_elapsed = 0.0
	_tween_out_triggered = false
	_playing_cuts = true

	var clip_dur := IntroAnims.get_cut_duration(cut_idx)
	_cut_duration = maxf(clip_dur, 1.55) if cut_idx == 4 else clip_dur

	if _arena:
		_arena.set_camera_transform(IntroAnims.eval_cut_transform(cut_idx, 0.0), 60.0)

	match cut_idx:
		1:
			_tween_banner_in(phase1_banner, Vector2.ONE, 0.20)
		2:
			phase1_banner.visible = false
			_tween_banner_in(p1_banner, Vector2.ONE, 0.10)
		3:
			p1_banner.visible = false
			_tween_banner_in(p2_banner, Vector2.ONE, 0.10)
		4:
			p2_banner.visible = false
			banner_viewport_container.visible = true
			if _banner_anim_player and _banner_anim_player.has_animation("Take 001_15"):
				var anim_res := _banner_anim_player.get_animation("Take 001_15")
				if anim_res:
					anim_res.loop_mode = Animation.LOOP_NONE
				_banner_anim_player.stop()
				_banner_anim_player.play("Take 001_15")


func _tween_banner_in(banner: Control, target_scale: Vector2, dur: float) -> void:
	if _banner_tween and _banner_tween.is_running():
		_banner_tween.kill()
	banner.visible = true
	banner.scale = Vector2(0.01, 0.01)
	banner.modulate = Color.WHITE
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "scale", target_scale, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _tween_banner_out(banner: Control, dur: float = 0.20) -> void:
	if not banner.visible:
		return
	if _banner_tween and _banner_tween.is_running():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "scale", Vector2(0.01, 0.01), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_banner_tween.tween_callback(func(): banner.visible = false)


func _process(delta: float) -> void:
	if not _playing_cuts or _finished:
		return

	_cut_elapsed += delta
	var clip_dur := IntroAnims.get_cut_duration(_cut_idx)
	if _arena:
		_arena.set_camera_transform(IntroAnims.eval_cut_transform(_cut_idx, minf(_cut_elapsed, clip_dur)), 60.0)

	# Trigger banner tween-out 0.3s before clip ends (matching CWBattleIntroController.TriggerBannerTween)
	if not _tween_out_triggered and _cut_idx < 4 and _cut_elapsed >= maxf(0.1, _cut_duration - 0.3):
		_tween_out_triggered = true
		match _cut_idx:
			1: _tween_banner_out(phase1_banner, 0.22)
			2: _tween_banner_out(p1_banner, 0.20)
			3: _tween_banner_out(p2_banner, 0.20)

	if _cut_elapsed >= _cut_duration:
		if _cut_idx < 4:
			_begin_cut(_cut_idx + 1)
		else:
			_finish_intro()


func _gui_input(event: InputEvent) -> void:
	if _can_skip and not _finished:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_finish_intro()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _can_skip and not _finished:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
			_finish_intro()
			get_viewport().set_input_as_handled()


func _finish_intro() -> void:
	if _finished:
		return
	_finished = true
	_playing_cuts = false
	if _banner_tween and _banner_tween.is_running():
		_banner_tween.kill()
	if _banner_anim_player:
		_banner_anim_player.stop()
	banner_viewport_container.visible = false
	phase1_banner.visible = false
	p1_banner.visible = false
	p2_banner.visible = false
	visible = false
	if _arena and _arena.has_method("set_heroes_card_on_table"):
		_arena.set_heroes_card_on_table(true, false)
	intro_completed.emit()
