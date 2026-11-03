extends Control
class_name MatchIntro

signal intro_completed

@onready var p1_portrait: TextureRect = $Content/HBox/P1Card/VBox/Portrait
@onready var p1_name: Label = $Content/HBox/P1Card/VBox/NameLabel
@onready var p1_quote: Label = $Content/HBox/P1Card/VBox/QuoteLabel
@onready var p1_hp: Label = $Content/HBox/P1Card/VBox/HpLabel

@onready var p2_portrait: TextureRect = $Content/HBox/P2Card/VBox/Portrait
@onready var p2_name: Label = $Content/HBox/P2Card/VBox/NameLabel
@onready var p2_quote: Label = $Content/HBox/P2Card/VBox/QuoteLabel
@onready var p2_hp: Label = $Content/HBox/P2Card/VBox/HpLabel

@onready var start_btn: Button = $Content/StartBtn
@onready var audio_sfx: AudioStreamPlayer = $AudioSFX
@onready var audio_vo: AudioStreamPlayer = $AudioVO

@export var vo_volume_db: float = -12.0
@export var sfx_volume_db: float = -10.0

var _auto_timer: SceneTreeTimer = null

func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	audio_vo.volume_db = vo_volume_db
	audio_sfx.volume_db = sfx_volume_db
	if AudioServer.get_bus_index("SFX") != -1:
		audio_vo.bus = "SFX"
		audio_sfx.bus = "SFX"

func play_intro(player_name: String, opponent_name: String, p1_max_hp: int, p2_max_hp: int) -> void:
	visible = true
	modulate = Color(1, 1, 1, 0)

	p1_name.text = player_name.to_upper()
	p1_hp.text = "❤️ %d HP" % p1_max_hp
	p1_quote.text = "\"I'm gonna kick your butt, %s!\"" % opponent_name

	p2_name.text = opponent_name.to_upper()
	p2_hp.text = "❤️ %d HP" % p2_max_hp
	p2_quote.text = "\"I do not play such games with cowards!\""

	# Load portraits
	var p1_tex_path = "res://assets/textures/leaders/%s.png" % player_name
	if ResourceLoader.exists(p1_tex_path):
		p1_portrait.texture = load(p1_tex_path)

	var p2_tex_path = "res://assets/textures/leaders/%s.png" % opponent_name
	if ResourceLoader.exists(p2_tex_path):
		p2_portrait.texture = load(p2_tex_path)

	# Play Intro SFX
	var intro_sfx_path = "res://assets/audio/sfx/Intro_Battle.wav"
	if ResourceLoader.exists(intro_sfx_path):
		audio_sfx.stream = load(intro_sfx_path)
		audio_sfx.play()

	# Play Opening VO
	var vo_path = "res://assets/audio/vo/%s_Opening.wav" % player_name
	if ResourceLoader.exists(vo_path):
		audio_vo.stream = load(vo_path)
		audio_vo.play()

	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.4)

	# Auto-proceed after 3.5 seconds if user doesn't click
	_auto_timer = get_tree().create_timer(3.5)
	_auto_timer.timeout.connect(func():
		if visible:
			_dismiss_intro()
	)

func _on_start_pressed() -> void:
	_dismiss_intro()

func _dismiss_intro() -> void:
	if not visible:
		return
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(func():
		visible = false
		intro_completed.emit()
	)
