extends Control
class_name RockPaperScissors

signal rps_completed(player_goes_first: bool)

enum Move { NONE, ROCK, PAPER, SCISSORS }

const MOVE_ICONS = {
	Move.ROCK: "✊ ROCK",
	Move.PAPER: "✋ PAPER",
	Move.SCISSORS: "✌️ SCISSORS"
}

@onready var status_label: Label = $Modal/Content/StatusLabel
@onready var choices_container: HBoxContainer = $Modal/Content/ChoicesContainer
@onready var rock_btn: Button = $Modal/Content/ChoicesContainer/RockBtn
@onready var paper_btn: Button = $Modal/Content/ChoicesContainer/PaperBtn
@onready var scissors_btn: Button = $Modal/Content/ChoicesContainer/ScissorsBtn

@onready var clash_container: HBoxContainer = $Modal/Content/ClashContainer
@onready var p1_move_label: Label = $Modal/Content/ClashContainer/P1Choice/VBox/MoveLabel
@onready var p2_move_label: Label = $Modal/Content/ClashContainer/P2Choice/VBox/MoveLabel

@onready var order_container: VBoxContainer = $Modal/Content/OrderContainer
@onready var go_first_btn: Button = $Modal/Content/OrderContainer/HBox/GoFirstBtn
@onready var go_second_btn: Button = $Modal/Content/OrderContainer/HBox/GoSecondBtn

@onready var audio_sfx: AudioStreamPlayer = $AudioSFX

var opponent_name: String = "Jake"
var _player_choice: Move = Move.NONE
var _opponent_choice: Move = Move.NONE

func _ready() -> void:
	rock_btn.pressed.connect(func(): _on_player_picked(Move.ROCK))
	paper_btn.pressed.connect(func(): _on_player_picked(Move.PAPER))
	scissors_btn.pressed.connect(func(): _on_player_picked(Move.SCISSORS))

	go_first_btn.pressed.connect(func(): _resolve_turn_order(true))
	go_second_btn.pressed.connect(func(): _resolve_turn_order(false))

func start_rps(opp_name: String) -> void:
	opponent_name = opp_name
	visible = true
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

	_reset_round()

func _reset_round() -> void:
	_player_choice = Move.NONE
	_opponent_choice = Move.NONE

	status_label.text = "Rock, Paper, Scissors! Shoot!"
	choices_container.visible = true
	clash_container.visible = false
	order_container.visible = false

	rock_btn.disabled = false
	paper_btn.disabled = false
	scissors_btn.disabled = false

func _play_sfx(sfx_name: String) -> void:
	var path = "res://assets/audio/sfx/%s.wav" % sfx_name
	if ResourceLoader.exists(path):
		audio_sfx.stream = load(path)
		audio_sfx.play()

func _on_player_picked(choice: Move) -> void:
	_player_choice = choice
	choices_container.visible = false
	_play_sfx("Click")

	# Opponent random choice
	var moves = [Move.ROCK, Move.PAPER, Move.SCISSORS]
	_opponent_choice = moves[randi() % moves.size()]

	# Show clash view
	clash_container.visible = true
	p1_move_label.text = MOVE_ICONS[_player_choice]
	p2_move_label.text = "❓ ..."
	status_label.text = "SHOOT!"

	# Suspense reveal
	var timer = get_tree().create_timer(0.6)
	timer.timeout.connect(_reveal_opponent_move)

func _reveal_opponent_move() -> void:
	p2_move_label.text = MOVE_ICONS[_opponent_choice]
	_play_sfx("Bell")

	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(_evaluate_result)

func _evaluate_result() -> void:
	if _player_choice == _opponent_choice:
		status_label.text = "IT'S A TIE! Shoot again!"
		var tie_timer = get_tree().create_timer(1.2)
		tie_timer.timeout.connect(_reset_round)
		return

	var player_won = false
	if (_player_choice == Move.ROCK and _opponent_choice == Move.SCISSORS) or \
	   (_player_choice == Move.PAPER and _opponent_choice == Move.ROCK) or \
	   (_player_choice == Move.SCISSORS and _opponent_choice == Move.PAPER):
		player_won = true

	if player_won:
		status_label.text = "🏆 YOU WIN THE TOSS!\nChoose your turn order:"
		order_container.visible = true
	else:
		# Opponent AI decides
		var ai_goes_first = (randf() < 0.7) # AI prefers going first 70%
		var order_str = "FIRST (Turn 1)" if ai_goes_first else "SECOND (Turn 2)"
		status_label.text = "💀 %s WINS THE TOSS!\n%s chooses to GO %s!" % [
			opponent_name.to_upper(), opponent_name, order_str
		]

		var end_timer = get_tree().create_timer(1.8)
		end_timer.timeout.connect(func(): _resolve_turn_order(not ai_goes_first))

func _resolve_turn_order(player_goes_first: bool) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(func():
		visible = false
		rps_completed.emit(player_goes_first)
	)
