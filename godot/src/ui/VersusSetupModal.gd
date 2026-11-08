class_name VersusSetupModal
extends Control

## VersusSetupModal: Local 2-Player Match Setup (Task 5.2)
## Configures Hotseat Pass & Play vs Dual Gamepad, hero loadouts, decks, and device routing.

const MatchRulesConfig = preload("res://src/systems/local_multiplayer/MatchRulesConfig.gd")

signal match_started(rules: MatchRulesConfig)
signal modal_closed()

@onready var mode_option: OptionButton = $CenterContainer/Panel/VBox/Header/ModeOption

# P1 Controls
@onready var p1_name_edit: LineEdit = $CenterContainer/Panel/VBox/PlayersGrid/P1Box/NameEdit
@onready var p1_hero_option: OptionButton = $CenterContainer/Panel/VBox/PlayersGrid/P1Box/HeroOption
@onready var p1_deck_option: OptionButton = $CenterContainer/Panel/VBox/PlayersGrid/P1Box/DeckOption
@onready var p1_device_label: Label = $CenterContainer/Panel/VBox/PlayersGrid/P1Box/DeviceLabel

# P2 Controls
@onready var p2_name_edit: LineEdit = $CenterContainer/Panel/VBox/PlayersGrid/P2Box/NameEdit
@onready var p2_hero_option: OptionButton = $CenterContainer/Panel/VBox/PlayersGrid/P2Box/HeroOption
@onready var p2_deck_option: OptionButton = $CenterContainer/Panel/VBox/PlayersGrid/P2Box/DeckOption
@onready var p2_device_label: Label = $CenterContainer/Panel/VBox/PlayersGrid/P2Box/DeviceLabel

# Buttons
@onready var start_btn: Button = $CenterContainer/Panel/VBox/ButtonContainer/StartBtn
@onready var cancel_btn: Button = $CenterContainer/Panel/VBox/ButtonContainer/CancelBtn

var available_heroes: Array[String] = ["Finn", "Jake", "Marceline", "PrincessBubblegum", "IceKing", "EarlOfLemongrab", "BMO", "FlamePrincess"]
var available_decks: Array[Dictionary] = []


func _ready() -> void:
	visible = false

	if start_btn and not start_btn.pressed.is_connected(_on_start_pressed):
		start_btn.pressed.connect(_on_start_pressed)
	if cancel_btn and not cancel_btn.pressed.is_connected(_on_cancel_pressed):
		cancel_btn.pressed.connect(_on_cancel_pressed)
	if mode_option and not mode_option.item_selected.is_connected(_on_mode_changed):
		mode_option.item_selected.connect(_on_mode_changed)


func open_modal() -> void:
	_populate_heroes()
	_populate_decks()
	_populate_modes()
	_update_device_labels()
	visible = true


func _populate_modes() -> void:
	mode_option.clear()
	mode_option.add_item("🔄 Hotseat Pass & Play (1 Device)", MatchRulesConfig.MatchMode.HOTSEAT_PASS_AND_PLAY)
	mode_option.add_item("🎮 Shared Screen (Dual Gamepads)", MatchRulesConfig.MatchMode.SHARED_SCREEN_DUAL_PAD)
	mode_option.selected = 0


func _populate_heroes() -> void:
	p1_hero_option.clear()
	p2_hero_option.clear()

	for h in available_heroes:
		p1_hero_option.add_item(h)
		p2_hero_option.add_item(h)

	p1_hero_option.selected = 0 # Finn
	p2_hero_option.selected = 1 # Jake


func _populate_decks() -> void:
	available_decks.clear()
	p1_deck_option.clear()
	p2_deck_option.clear()

	# Add Starter Decks
	available_decks.append({
		"name": "Finn Starter Deck",
		"cards": GameManager.player_deck.duplicate(),
		"landscapes": ["Plains", "Plains", "Cotton", "Plains"]
	})
	available_decks.append({
		"name": "Jake Corn Deck",
		"cards": GameManager.opponent_deck.duplicate(),
		"landscapes": ["Corn", "Corn", "Sand", "Corn"]
	})

	for d in available_decks:
		p1_deck_option.add_item(d.name)
		p2_deck_option.add_item(d.name)

	p1_deck_option.selected = 0
	p2_deck_option.selected = mini(1, available_decks.size() - 1)


func _on_mode_changed(_index: int) -> void:
	_update_device_labels()


func _update_device_labels() -> void:
	var mode = mode_option.selected as MatchRulesConfig.MatchMode
	if mode == MatchRulesConfig.MatchMode.HOTSEAT_PASS_AND_PLAY:
		p1_device_label.text = "Device: Shared Keyboard / Gamepad (Pass on turn)"
		p2_device_label.text = "Device: Shared Keyboard / Gamepad (Pass on turn)"
	else:
		p1_device_label.text = "Device: Gamepad 0 / Keyboard (WASD/Space)"
		p2_device_label.text = "Device: Gamepad 1 (Controller Slot 2)"


func _on_start_pressed() -> void:
	var mode = mode_option.selected as MatchRulesConfig.MatchMode
	var rules = MatchRulesConfig.new(mode)

	var p1_name = p1_name_edit.text.strip_edges()
	if p1_name == "": p1_name = "Player 1"
	var p2_name = p2_name_edit.text.strip_edges()
	if p2_name == "": p2_name = "Player 2"

	var p1_hero = available_heroes[p1_hero_option.selected]
	var p2_hero = available_heroes[p2_hero_option.selected]

	var d1 = available_decks[p1_deck_option.selected]
	var d2 = available_decks[p2_deck_option.selected]

	var p1_dev = -1
	var p2_dev = 0 if mode == MatchRulesConfig.MatchMode.HOTSEAT_PASS_AND_PLAY else 1

	var d1_cards: Array[String] = []
	for c in d1.cards: d1_cards.append(str(c))
	var d1_lands: Array[String] = []
	for l in d1.landscapes: d1_lands.append(str(l))

	var d2_cards: Array[String] = []
	for c in d2.cards: d2_cards.append(str(c))
	var d2_lands: Array[String] = []
	for l in d2.landscapes: d2_lands.append(str(l))

	rules.set_player_loadout(0, p1_name, p1_hero, d1_cards, d1_lands, p1_dev)
	rules.set_player_loadout(1, p2_name, p2_hero, d2_cards, d2_lands, p2_dev)

	visible = false
	match_started.emit(rules)

	if GameManager:
		GameManager.setup_local_versus_match(rules)
		GameManager.start_battle()


func _on_cancel_pressed() -> void:
	visible = false
	modal_closed.emit()
