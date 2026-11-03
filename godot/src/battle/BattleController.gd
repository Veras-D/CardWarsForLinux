extends Control

const BattleWheelModal = preload("res://src/battle/BattleWheelModal.gd")
const LeaderPowerButton = preload("res://src/battle/LeaderPowerButton.gd")
const AbilitySystem = preload("res://src/battle/AbilitySystem.gd")

@onready var opponent_hp_bar: ProgressBar = $Header/OpponentInfo/HpBar
@onready var opponent_hp_label: Label = $Header/OpponentInfo/HpLabel
@onready var opponent_name_label: Label = $Header/OpponentInfo/NameLabel
@onready var opponent_leader_btn: LeaderPowerButton = $Header/OpponentInfo/OpponentLeaderPower

@onready var player_hp_bar: ProgressBar = $Footer/PlayerInfo/HpBar
@onready var player_hp_label: Label = $Footer/PlayerInfo/HpLabel
@onready var player_name_label: Label = $Footer/PlayerInfo/NameLabel
@onready var player_leader_btn: LeaderPowerButton = $Footer/PlayerInfo/PlayerLeaderPower
@onready var player_mp_label: Label = $Footer/MpContainer/MpLabel

@onready var opponent_lanes_box: HBoxContainer = $Field/OpponentLanes
@onready var player_lanes_box: HBoxContainer = $Field/PlayerLanes
@onready var hand_container: HBoxContainer = $Footer/HandScroll/HandContainer

@onready var turn_btn: Button = $TurnBtn
@onready var log_label: Label = $BattleLog/Label
@onready var dialog_panel: Panel = $EndGameDialog
@onready var dialog_label: Label = $EndGameDialog/VBox/ResultLabel
@onready var dialog_btn: Button = $EndGameDialog/VBox/MenuBtn

@onready var match_intro: Control = $MatchIntro
@onready var rps_modal: Control = $RockPaperScissors
@onready var wheel_modal: BattleWheelModal = $BattleWheelModal

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

var player_leader_cooldown: int = 0
var opponent_leader_cooldown: int = 0
var player_leader_id: String = ""
var opponent_leader_id: String = ""
var ability_system: AbilitySystem = null

func _ready() -> void:
	turn_btn.pressed.connect(_on_turn_button_pressed)
	dialog_btn.pressed.connect(_on_menu_button_pressed)
	match_intro.intro_completed.connect(_on_intro_completed)
	rps_modal.rps_completed.connect(_on_rps_completed)

	setup_match()
	match_intro.play_intro(
		GameManager.player_hero_name,
		GameManager.opponent_hero_name,
		player_max_hp,
		opponent_max_hp
	)

func _on_intro_completed() -> void:
	rps_modal.start_rps(GameManager.opponent_hero_name)

func _on_rps_completed(player_goes_first: bool) -> void:
	if player_goes_first:
		log_message("⚡ YOU GO FIRST! (Turn 1)")
		start_player_turn()
	else:
		log_message("🛡️ %s GOES FIRST! (Turn 1)" % GameManager.opponent_hero_name.to_upper())
		turn_btn.disabled = true
		turn_btn.text = "Opponent's Turn..."
		var timer = get_tree().create_timer(1.2)
		timer.timeout.connect(execute_opponent_turn)

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

	# Initialize Leaders & Cooldowns
	var p_leader = Database.get_leader(GameManager.player_hero_name)
	player_leader_id = p_leader.get("character_id", GameManager.player_hero_name)
	player_leader_cooldown = p_leader.get("cooldown", 5)
	player_leader_btn.setup(player_leader_id, true)
	if not player_leader_btn.power_activated.is_connected(_on_player_leader_power_activated):
		player_leader_btn.power_activated.connect(_on_player_leader_power_activated)

	var o_leader = Database.get_leader(GameManager.opponent_hero_name)
	opponent_leader_id = o_leader.get("character_id", GameManager.opponent_hero_name)
	opponent_leader_cooldown = o_leader.get("cooldown", 3)
	opponent_leader_btn.setup(opponent_leader_id, false)

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

	if ability_system == null:
		ability_system = AbilitySystem.new()
		add_child(ability_system)
	ability_system.setup(self)

	_update_ui()

	# Start Battle BGM using Audio Jukebox
	var bgm_path = "res://assets/audio/bgm/%s.wav" % GameManager.player_hero_name
	if ResourceLoader.exists(bgm_path):
		Audio.play_bgm(load(bgm_path), 1.5)
	elif ResourceLoader.exists("res://assets/audio/bgm/MainMenu.wav"):
		Audio.play_bgm(load("res://assets/audio/bgm/MainMenu.wav"), 1.5)

	# Initial 4-card hand
	for _i in range(4):
		draw_player_card()

func start_player_turn() -> void:
	is_player_turn = true
	if ResourceLoader.exists("res://assets/audio/sfx/YourTurn.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/YourTurn.wav"))
	player_max_mp = min(10, player_max_mp + 1)
	player_mp = player_max_mp

	# Decrement Leader Cooldown
	if player_leader_cooldown > 0:
		player_leader_cooldown = max(0, player_leader_cooldown - 1)
	player_leader_btn.update_cooldown(player_leader_cooldown)

	for lane in player_lanes:
		lane.reset_turn()

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_START)

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
	if ResourceLoader.exists("res://assets/audio/sfx/Click.wav"):
		Audio.play_sfx_with_variation(load("res://assets/audio/sfx/Click.wav"), -6.0, 0.08)
	selected_card_view = card_view
	selected_card_view.modulate = Color(1.2, 1.2, 0.8, 1.0)
	var card_name = selected_card_view.card_data.get("name", "Card")
	var cost = selected_card_view.card_data.get("cost", 0)
	var faction = selected_card_view.card_data.get("faction", "")
	log_message("Selected %s (%s, Cost: %d MP). Click an empty lane to summon." % [card_name, faction, cost])

	# Highlight valid/invalid lanes for the selected card
	for lane in player_lanes:
		if not lane.has_creature:
			var check = lane.can_accept_creature(selected_card_view.card_data)
			lane.set_highlight(true, check.allowed)

func _deselect_card() -> void:
	if selected_card_view:
		selected_card_view.modulate = Color.WHITE
		selected_card_view = null
	for lane in player_lanes:
		lane.set_highlight(false)

func _on_player_lane_clicked(lane: LaneSlot) -> void:
	if not is_player_turn or selected_card_view == null:
		return

	var card_data = selected_card_view.card_data
	var cost = card_data.get("cost", 1)

	if player_mp < cost:
		lane.flash_invalid()
		log_message("❌ Not enough Magic Points! (Need %d MP, have %d MP)" % [cost, player_mp])
		return

	var check = lane.can_accept_creature(card_data)
	if not check.allowed:
		lane.flash_invalid()
		log_message("❌ Cannot summon: " + check.reason)
		return

	# Summon creature onto valid lane
	player_mp -= cost
	lane.place_creature(card_data)
	log_message("✨ Summoned %s onto Lane %d (%s)!" % [card_data.get("name", "Creature"), lane.lane_index + 1, lane.landscape])

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_SUMMON, lane)

	# Remove from hand and reset selection
	var to_free = selected_card_view
	_deselect_card()
	to_free.queue_free()
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
	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_FLOOP, source_lane)

func _on_player_leader_power_activated(char_id: String) -> void:
	if not is_player_turn or player_leader_cooldown > 0:
		return
	_execute_leader_power(true, char_id)

func _execute_leader_power(is_player_owner: bool, char_id: String) -> void:
	var leader = Database.get_leader(char_id)
	var script_name = leader.get("script_name", "")
	var hero_name = leader.get("name", char_id)

	# Audio feedback
	if ResourceLoader.exists("res://assets/audio/sfx/LeaderPower.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/LeaderPower.wav"))

	var vo_path = "res://assets/audio/vo/%s_Power.wav" % char_id
	if ResourceLoader.exists(vo_path):
		var timer = get_tree().create_timer(0.12)
		timer.timeout.connect(func(): Audio.play_sfx(load(vo_path), -8.0))

	var lanes = player_lanes if is_player_owner else opponent_lanes
	var owner_tag = "YOU" if is_player_owner else GameManager.opponent_hero_name

	match script_name:
		"GainActionPointsLeader":
			var val = int(leader.get("val1", "2"))
			if val <= 0:
				val = 2
			if is_player_owner:
				player_mp = min(10, player_mp + val)
				log_message("⚡ %s activated %s's Power: Gained +%d Magic Points!" % [owner_tag, hero_name, val])
			else:
				log_message("⚡ %s activated %s's Power: Gained +%d Action Points!" % [owner_tag, hero_name, val])
		"ATKBonusFactionCreaturesLeader":
			var faction = leader.get("for_faction", "Corn")
			var val = int(leader.get("val1", "3"))
			if val <= 0:
				val = 3
			var buffed_count = 0
			for lane in lanes:
				if lane.has_creature:
					var c_fac = lane.creature_data.get("faction", "")
					if c_fac.to_lower() == faction.to_lower() or faction == "":
						lane.modify_atk(val)
						buffed_count += 1
			log_message("⚡ %s activated %s's Power: +%d ATK to %d friendly %s creature(s)!" % [owner_tag, hero_name, val, buffed_count, faction])
		"HealAllCreaturesLeader":
			var healed_count = 0
			for lane in lanes:
				if lane.has_creature:
					lane.heal_to_full()
					healed_count += 1
			log_message("⚡ %s activated %s's Power: %d friendly creature(s) healed to full DEF!" % [owner_tag, hero_name, healed_count])
		"ATKBonusAllCreaturesLeader":
			var val = int(leader.get("val1", "2"))
			if val <= 0:
				val = 2
			var buffed_count = 0
			for lane in lanes:
				if lane.has_creature:
					lane.modify_atk(val)
					buffed_count += 1
			log_message("⚡ %s activated %s's Power: +%d ATK to %d friendly creature(s)!" % [owner_tag, hero_name, val, buffed_count])
		"DrawCardsLeader":
			var count = int(leader.get("val1", "2"))
			if count <= 0:
				count = 2
			if is_player_owner:
				for _i in range(count):
					draw_player_card()
				player_mp = min(10, player_mp + 1)
				log_message("⚡ %s activated %s's Power: Drew %d card(s) and gained 1 MP!" % [owner_tag, hero_name, count])
			else:
				log_message("⚡ %s activated %s's Power: Drew cards!" % [owner_tag, hero_name])
		_:
			for lane in lanes:
				if lane.has_creature:
					lane.modify_atk(1)
			log_message("⚡ %s activated %s's Leader Power!" % [owner_tag, hero_name])

	# Reset Cooldown
	var base_cooldown = leader.get("cooldown", 3)
	if is_player_owner:
		player_leader_cooldown = base_cooldown
		player_leader_btn.update_cooldown(player_leader_cooldown)
	else:
		opponent_leader_cooldown = base_cooldown
		opponent_leader_btn.update_cooldown(opponent_leader_cooldown)
		opponent_leader_btn.trigger_activation_anim()

	_update_ui()

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

		if ability_system:
			ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_ATTACK, p_lane)

		var atk = p_lane.current_atk
		var o_lane = opponent_lanes[i]
		var target_name = o_lane.creature_data.name if o_lane.has_creature else GameManager.opponent_hero_name

		# Trigger Battle Wheel minigame
		wheel_modal.start_attack_clash(
			p_lane.creature_data.name,
			target_name,
			atk,
			true
		)
		var clash_res = await wheel_modal.clash_resolved
		var final_damage: int = clash_res.final_damage

		if clash_res.id == "crit":
			log_message("⚡ CRITICAL HIT! %s dealt 2x damage (%d DMG)!" % [p_lane.creature_data.name, final_damage])
		elif clash_res.id == "miss":
			log_message("❌ MISSED! %s's attack missed completely!" % p_lane.creature_data.name)
		else:
			log_message("⚔️ HIT! %s dealt %d damage to %s!" % [p_lane.creature_data.name, final_damage, target_name])

		if o_lane.has_creature:
			var destroyed = o_lane.apply_damage(final_damage)
			if destroyed:
				log_message("Opponent's %s was destroyed!" % o_lane.creature_data.name)
		else:
			opponent_hp = max(0, opponent_hp - final_damage)

		_update_ui()
		if opponent_hp <= 0:
			end_match(true)
			return

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_END)

	# Opponent AI turn
	var timer = get_tree().create_timer(1.2)
	await timer.timeout
	execute_opponent_turn()

func execute_opponent_turn() -> void:
	if ResourceLoader.exists("res://assets/audio/sfx/OpponentTurn.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/OpponentTurn.wav"))
	log_message("=== Opponent Turn (%s) ===" % GameManager.opponent_hero_name)

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_START)

	# Decrement Opponent Leader Cooldown
	if opponent_leader_cooldown > 0:
		opponent_leader_cooldown = max(0, opponent_leader_cooldown - 1)
	opponent_leader_btn.update_cooldown(opponent_leader_cooldown)

	# If Opponent Leader Ability is ready, trigger it during Action Phase!
	if opponent_leader_cooldown == 0:
		_execute_leader_power(false, opponent_leader_id)

	# AI summons creatures in compatible empty lanes if available
	if not opponent_draw_pile.is_empty():
		var candidate_idx = -1
		var candidate_card = {}
		for i in range(opponent_draw_pile.size() - 1, -1, -1):
			var c_id = opponent_draw_pile[i]
			var c_data = Database.get_card(c_id)
			if not c_data.is_empty() and c_data.type == "CREATURE":
				for o_lane in opponent_lanes:
					if not o_lane.has_creature and o_lane.can_accept_creature(c_data).allowed:
						candidate_idx = i
						candidate_card = c_data
						break
			if candidate_idx != -1:
				break

		if candidate_idx != -1:
			opponent_draw_pile.remove_at(candidate_idx)
			for o_lane in opponent_lanes:
				if not o_lane.has_creature and o_lane.can_accept_creature(candidate_card).allowed:
					o_lane.place_creature(candidate_card)
					log_message("%s summoned %s into Lane %d (%s)!" % [
						GameManager.opponent_hero_name, candidate_card.name, o_lane.lane_index + 1, o_lane.landscape
					])
					if ability_system:
						ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_SUMMON, o_lane)
					break

	# Opponent attacks
	for i in range(4):
		var o_lane = opponent_lanes[i]
		if not o_lane.has_creature:
			continue

		if ability_system:
			ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_ATTACK, o_lane)

		var atk = o_lane.current_atk
		var p_lane = player_lanes[i]
		var target_name = p_lane.creature_data.name if p_lane.has_creature else GameManager.player_hero_name

		# Opponent wheel clash (quick-resolve mode)
		wheel_modal.start_attack_clash(
			o_lane.creature_data.name,
			target_name,
			atk,
			false, # is_player
			0.80,
			0.07,
			true # quick resolve for AI
		)
		var clash_res = await wheel_modal.clash_resolved
		var final_damage: int = clash_res.final_damage

		if clash_res.id == "crit":
			log_message("⚡ CRITICAL HIT! %s dealt 2x damage (%d DMG)!" % [o_lane.creature_data.name, final_damage])
		elif clash_res.id == "miss":
			log_message("❌ MISSED! %s's attack missed!" % o_lane.creature_data.name)
		else:
			log_message("⚔️ HIT! %s dealt %d damage to %s!" % [o_lane.creature_data.name, final_damage, target_name])

		if p_lane.has_creature:
			var destroyed = p_lane.apply_damage(final_damage)
			if destroyed:
				log_message("Your %s was destroyed!" % p_lane.creature_data.name)
		else:
			player_hp = max(0, player_hp - final_damage)

		_update_ui()
		if player_hp <= 0:
			end_match(false)
			return

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_END)

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
