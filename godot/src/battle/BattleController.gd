extends Control

@onready var opponent_hp_bar: ProgressBar = $Header/OpponentInfo/HpBar
@onready var opponent_hp_label: Label = $Header/OpponentInfo/HpLabel
@onready var opponent_name_label: Label = $Header/OpponentInfo/NameLabel

@onready var player_hp_bar: ProgressBar = $Footer/PlayerInfo/HpBar
@onready var player_hp_label: Label = $Footer/PlayerInfo/HpLabel
@onready var player_name_label: Label = $Footer/PlayerInfo/NameLabel
@onready var player_mp_label: Label = $Footer/MpContainer/MpLabel

@onready var opponent_lanes_box: HBoxContainer = $Field/OpponentLanes
@onready var player_lanes_box: HBoxContainer = $Field/PlayerLanes
@onready var hand_container: HBoxContainer = $Footer/HandScroll/HandContainer

@onready var turn_btn: Button = $TurnBtn
@onready var log_label: Label = $BattleLog/Label
@onready var dialog_panel: Panel = $EndGameDialog
@onready var dialog_label: Label = $EndGameDialog/VBox/ResultLabel
@onready var dialog_btn: Button = $EndGameDialog/VBox/MenuBtn

var player_hp: int = 25
var player_max_hp: int = 25
var player_mp: int = 2
var player_max_mp: int = 2

var opponent_hp: int = 25
var opponent_max_hp: int = 25

var player_draw_pile: Array[String] = []
var opponent_draw_pile: Array[String] = []
var selected_card_view: CardView = null

var player_lanes: Array[LaneSlot] = []
var opponent_lanes: Array[LaneSlot] = []
var is_player_turn: bool = true

func _ready() -> void:
	turn_btn.pressed.connect(_on_turn_button_pressed)
	dialog_btn.pressed.connect(_on_menu_button_pressed)
	setup_match()
	start_player_turn()

func setup_match() -> void:
	player_name_label.text = GameManager.player_hero_name
	player_max_hp = GameManager.player_hero_max_hp
	player_hp = player_max_hp

	opponent_name_label.text = GameManager.opponent_hero_name
	opponent_max_hp = GameManager.opponent_hero_max_hp
	opponent_hp = opponent_max_hp

	player_draw_pile = GameManager.player_deck.duplicate()
	player_draw_pile.shuffle()

	opponent_draw_pile = GameManager.opponent_deck.duplicate()
	opponent_draw_pile.shuffle()

	player_lanes.clear()
	opponent_lanes.clear()

	for i in range(4):
		var p_lane = player_lanes_box.get_child(i) as LaneSlot
		p_lane.is_player = true
		p_lane.lane_index = i
		p_lane.update_landscape(GameManager.player_landscapes[i])
		p_lane.slot_clicked.connect(_on_player_lane_clicked)
		p_lane.floop_requested.connect(_on_floop_requested)
		player_lanes.append(p_lane)

		var o_lane = opponent_lanes_box.get_child(i) as LaneSlot
		o_lane.is_player = false
		o_lane.lane_index = i
		o_lane.update_landscape(GameManager.opponent_landscapes[i])
		opponent_lanes.append(o_lane)

	_update_ui()

	# Initial 4-card hand
	for _i in range(4):
		draw_player_card()

func start_player_turn() -> void:
	is_player_turn = true
	player_max_mp = min(10, player_max_mp + 1)
	player_mp = player_max_mp

	for lane in player_lanes:
		lane.reset_turn()

	draw_player_card()
	_update_ui()
	log_message("Your turn! (Action Phase) - Play cards or Floop abilities.")
	turn_btn.text = "⚔️ ATTACK! (End Turn)"
	turn_btn.disabled = false

func draw_player_card() -> void:
	if player_draw_pile.is_empty():
		return
	var card_id = player_draw_pile.pop_back()
	var card_data = Database.get_card(card_id)
	if card_data.is_empty():
		return

	var card_scene = preload("res://scenes/components/CardView.tscn").instantiate()
	hand_container.add_child(card_scene)
	card_scene.render_card(card_data)
	card_scene.card_clicked.connect(_on_hand_card_clicked)

func _on_hand_card_clicked(card_view: CardView) -> void:
	if not is_player_turn:
		return
	if selected_card_view == card_view:
		_deselect_card()
	else:
		_select_card(card_view)

func _select_card(card_view: CardView) -> void:
	_deselect_card()
	selected_card_view = card_view
	selected_card_view.modulate = Color(1.2, 1.2, 0.8, 1.0)
	var card_name = selected_card_view.card_data.get("name", "Card")
	var cost = selected_card_view.card_data.get("cost", 0)
	log_message("Selected %s (Cost: %d MP). Click an empty lane to summon." % [card_name, cost])

func _deselect_card() -> void:
	if selected_card_view:
		selected_card_view.modulate = Color.WHITE
		selected_card_view = null

func _on_player_lane_clicked(lane: LaneSlot) -> void:
	if not is_player_turn or selected_card_view == null:
		return

	var card_data = selected_card_view.card_data
	var cost = card_data.get("cost", 1)

	if player_mp < cost:
		log_message("Not enough Magic Points! (Need %d MP)" % cost)
		return

	if lane.has_creature:
		log_message("Lane %d already has a creature!" % (lane.lane_index + 1))
		return

	# Summon creature
	player_mp -= cost
	lane.place_creature(card_data)
	log_message("Summoned %s into Lane %d!" % [card_data.get("name", "Creature"), lane.lane_index + 1])

	# Remove from hand
	selected_card_view.queue_free()
	selected_card_view = null
	_update_ui()

func _on_floop_requested(lane: LaneSlot) -> void:
	if not is_player_turn or not lane.has_creature or lane.is_flooped:
		return

	var data = lane.creature_data
	var floop_cost = data.get("floop_cost", 0)

	if player_mp < floop_cost:
		log_message("Not enough MP to Floop! (Need %d MP)" % floop_cost)
		return

	player_mp -= floop_cost
	lane.set_flooped(true)
	log_message("Flooped %s!" % data.get("name", "Creature"))

	_execute_floop_ability(lane)
	_update_ui()

func _execute_floop_ability(source_lane: LaneSlot) -> void:
	var script_name = source_lane.creature_data.get("script_name", "")
	var val1 = int(source_lane.creature_data.get("val1", "0"))
	var val2 = int(source_lane.creature_data.get("val2", "0"))

	match script_name:
		"ATKPenaltyFaction":
			# Decrease ATK of opposite creatures (like The Pig)
			for opp_lane in opponent_lanes:
				if opp_lane.has_creature:
					opp_lane.modify_atk(-val2 if val2 > 0 else -1)
			log_message("Floop: Enemy creatures had their Attack reduced!")
		"DrawCards":
			var count = val1 if val1 > 0 else 1
			for _i in range(count):
				draw_player_card()
			log_message("Floop: Drew %d card(s)!" % count)
		"HealHero":
			var heal = val1 if val1 > 0 else 2
			player_hp = min(player_max_hp, player_hp + heal)
			log_message("Floop: Restored %d HP to your hero!" % heal)
		"DamageAll":
			var dmg = val1 if val1 > 0 else 2
			for opp_lane in opponent_lanes:
				if opp_lane.has_creature:
					opp_lane.apply_damage(dmg)
			log_message("Floop: Dealt %d damage to all opponent creatures!" % dmg)
		_:
			# Default Floop bonus: +2 ATK this turn
			source_lane.modify_atk(2)
			log_message("Floop: %s gained +2 Attack!" % source_lane.creature_data.get("name", "Creature"))

func _on_turn_button_pressed() -> void:
	if not is_player_turn:
		return
	_deselect_card()
	execute_battle_phase()

func execute_battle_phase() -> void:
	is_player_turn = false
	turn_btn.disabled = true
	log_message("=== BATTLE PHASE! ===")

	# Player attacks
	for i in range(4):
		var p_lane = player_lanes[i]
		if not p_lane.has_creature:
			continue

		var atk = p_lane.current_atk
		var o_lane = opponent_lanes[i]

		if o_lane.has_creature:
			log_message("%s attacks opponent's %s for %d damage!" % [
				p_lane.creature_data.name, o_lane.creature_data.name, atk
			])
			var destroyed = o_lane.apply_damage(atk)
			if destroyed:
				log_message("Opponent's creature was destroyed!")
		else:
			log_message("%s attacks %s directly for %d damage!" % [
				p_lane.creature_data.name, GameManager.opponent_hero_name, atk
			])
			opponent_hp = max(0, opponent_hp - atk)

		_update_ui()
		if opponent_hp <= 0:
			end_match(true)
			return

	# Opponent AI turn
	var timer = get_tree().create_timer(1.2)
	await timer.timeout
	execute_opponent_turn()

func execute_opponent_turn() -> void:
	log_message("=== Opponent Turn (%s) ===" % GameManager.opponent_hero_name)

	# AI summons creatures in empty lanes if available
	for o_lane in opponent_lanes:
		if not o_lane.has_creature and not opponent_draw_pile.is_empty():
			var card_id = opponent_draw_pile.pop_back()
			var card_data = Database.get_card(card_id)
			if not card_data.is_empty() and card_data.type == "CREATURE":
				o_lane.place_creature(card_data)
				log_message("%s summoned %s into Lane %d!" % [
					GameManager.opponent_hero_name, card_data.name, o_lane.lane_index + 1
				])
				break

	# Opponent attacks
	for i in range(4):
		var o_lane = opponent_lanes[i]
		if not o_lane.has_creature:
			continue

		var atk = o_lane.current_atk
		var p_lane = player_lanes[i]

		if p_lane.has_creature:
			log_message("%s attacks your %s for %d damage!" % [
				o_lane.creature_data.name, p_lane.creature_data.name, atk
			])
			var destroyed = p_lane.apply_damage(atk)
			if destroyed:
				log_message("Your creature was destroyed!")
		else:
			log_message("%s attacks you directly for %d damage!" % [
				o_lane.creature_data.name, atk
			])
			player_hp = max(0, player_hp - atk)

		_update_ui()
		if player_hp <= 0:
			end_match(false)
			return

	var timer = get_tree().create_timer(1.0)
	await timer.timeout
	start_player_turn()

func end_match(victory: bool) -> void:
	dialog_panel.visible = true
	if victory:
		dialog_label.text = "🏆 VICTORY! 🏆\nYou are crowned a Cool Guy!"
	else:
		dialog_label.text = "💀 DEFEAT! 💀\nYou drank from the Dweeb Cup!"

func log_message(text: String) -> void:
	log_label.text = text

func _update_ui() -> void:
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp
	player_hp_label.text = "%s: %d / %d HP" % [GameManager.player_hero_name, player_hp, player_max_hp]

	opponent_hp_bar.max_value = opponent_max_hp
	opponent_hp_bar.value = opponent_hp
	opponent_hp_label.text = "%s: %d / %d HP" % [GameManager.opponent_hero_name, opponent_hp, opponent_max_hp]

	player_mp_label.text = "⚡ Magic Points: %d / %d" % [player_mp, player_max_mp]

func _on_menu_button_pressed() -> void:
	GameManager.return_to_menu()
