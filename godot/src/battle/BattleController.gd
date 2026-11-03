extends Control

const BattleWheelModal = preload("res://src/battle/BattleWheelModal.gd")
const LeaderPowerButton = preload("res://src/battle/LeaderPowerButton.gd")
const AbilitySystem = preload("res://src/battle/AbilitySystem.gd")
const BattlePhaseManager = preload("res://src/battle/BattlePhaseManager.gd")
const SpellResolver = preload("res://src/battle/SpellResolver.gd")
const LootRoller = preload("res://src/battle/LootRoller.gd")
const Tombstone = preload("res://src/battle/Tombstone.gd")

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
var player_discard_pile: Array[String] = []
var opponent_discard_pile: Array[String] = []
var selected_card_view: CardView = null

var player_lanes: Array[LaneSlot] = []
var opponent_lanes: Array[LaneSlot] = []
var is_player_turn: bool = true

# Session loot & drop tracking
var session_gold: int = 0
var session_loot_cards: Array[String] = []
var loot_drops_count: int = 0
var drop_profile_id: String = "Quest01"

var player_leader_cooldown: int = 0
var opponent_leader_cooldown: int = 0
var player_leader_id: String = ""
var opponent_leader_id: String = ""
var ability_system: AbilitySystem = null
var phase_manager: BattlePhaseManager = null
var spell_resolver: SpellResolver = null

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
		if phase_manager:
			phase_manager.start_battle(0)
		start_player_turn()
	else:
		log_message("🛡️ %s GOES FIRST! (Turn 1)" % GameManager.opponent_hero_name.to_upper())
		turn_btn.disabled = true
		turn_btn.text = "Opponent's Turn..."
		if phase_manager:
			phase_manager.start_battle(1)
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
	player_discard_pile.clear()
	opponent_discard_pile.clear()
	session_gold = 0
	session_loot_cards.clear()
	loot_drops_count = 0

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
		if not p_lane.slot_clicked.is_connected(_on_lane_clicked):
			p_lane.slot_clicked.connect(_on_lane_clicked)
		if not p_lane.floop_requested.is_connected(_on_floop_requested):
			p_lane.floop_requested.connect(_on_floop_requested)
		if not p_lane.creature_destroyed.is_connected(_on_creature_destroyed):
			p_lane.creature_destroyed.connect(_on_creature_destroyed)
		if not p_lane.loot_collected.is_connected(_on_loot_collected):
			p_lane.loot_collected.connect(_on_loot_collected)
		player_lanes.append(p_lane)

		var o_lane = opponent_lanes_box.get_child(i) as LaneSlot
		o_lane.is_player = false
		o_lane.lane_index = i
		o_lane.update_landscape(GameManager.opponent_landscapes[i])
		if not o_lane.slot_clicked.is_connected(_on_lane_clicked):
			o_lane.slot_clicked.connect(_on_lane_clicked)
		if not o_lane.creature_destroyed.is_connected(_on_creature_destroyed):
			o_lane.creature_destroyed.connect(_on_creature_destroyed)
		if not o_lane.loot_collected.is_connected(_on_loot_collected):
			o_lane.loot_collected.connect(_on_loot_collected)
		opponent_lanes.append(o_lane)

	if ability_system == null:
		ability_system = AbilitySystem.new()
		add_child(ability_system)
	ability_system.setup(self)

	if phase_manager == null:
		phase_manager = BattlePhaseManager.new()
		add_child(phase_manager)

	if spell_resolver == null:
		spell_resolver = SpellResolver.new()
		add_child(spell_resolver)
	spell_resolver.setup(self)

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

func is_action_allowed() -> bool:
	if phase_manager != null and phase_manager.get_current_phase() != BattlePhaseManager.Phase.NONE:
		return phase_manager.is_action_allowed(0)
	return is_player_turn

func start_player_turn() -> void:
	is_player_turn = true
	if phase_manager != null:
		if phase_manager.get_current_phase() == BattlePhaseManager.Phase.NONE:
			phase_manager.start_battle(0)
		elif phase_manager.get_current_phase() != BattlePhaseManager.Phase.START_TURN:
			phase_manager.transition_to(BattlePhaseManager.Phase.START_TURN)

	if ResourceLoader.exists("res://assets/audio/sfx/YourTurn.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/YourTurn.wav"))
	player_max_mp = min(10, player_max_mp + 1)
	player_mp = player_max_mp

	# Decrement Leader Cooldown
	if player_leader_cooldown > 0:
		player_leader_cooldown = max(0, player_leader_cooldown - 1)
	player_leader_btn.update_cooldown(player_leader_cooldown)

	for lane in player_lanes:
		lane.clear_tombstone()
		lane.reset_turn()
	for lane in opponent_lanes:
		lane.clear_tombstone()

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_START)

	draw_player_card()
	_update_ui()

	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.ACTION_PHASE)

	log_message("Your turn! (Action Phase) - Play cards or Floop abilities.")
	turn_btn.text = "⚔️ ATTACK! (End Turn)"
	turn_btn.disabled = false

func add_card_to_hand(card_data: Dictionary) -> void:
	if card_data.is_empty():
		return
	var card_scene = preload("res://scenes/components/CardView.tscn").instantiate()
	hand_container.add_child(card_scene)
	card_scene.render_card(card_data)
	card_scene.card_clicked.connect(_on_hand_card_clicked)

func draw_player_card() -> void:
	if player_draw_pile.is_empty():
		return
	var card_id = player_draw_pile.pop_back()
	var card_data = Database.get_card(card_id)
	add_card_to_hand(card_data)

func _on_hand_card_clicked(card_view: CardView) -> void:
	if not is_action_allowed():
		return
	if selected_card_view == card_view:
		# If clicking an already selected non-targeted spell, cast it!
		if card_view.card_data.get("type") == "SPELL" and spell_resolver and not spell_resolver.is_targeted(card_view.card_data):
			_cast_selected_spell_on_lane(null)
		else:
			_deselect_card()
	else:
		_select_card(card_view)

func _select_card(card_view: CardView) -> void:
	_deselect_card()
	if ResourceLoader.exists("res://assets/audio/sfx/Click.wav"):
		Audio.play_sfx_with_variation(load("res://assets/audio/sfx/Click.wav"), -6.0, 0.08)
	selected_card_view = card_view
	selected_card_view.modulate = Color(1.2, 1.2, 0.8, 1.0)
	var card_data = selected_card_view.card_data
	var card_name = card_data.get("name", "Card")
	var cost = card_data.get("cost", 0)
	var faction = card_data.get("faction", "")
	var card_type = card_data.get("type", "CREATURE")

	if card_type == "SPELL":
		if spell_resolver and spell_resolver.is_targeted(card_data):
			log_message("Selected %s (Spell, Cost: %d MP). Click a valid target lane to cast." % [card_name, cost])
			var valid_targets = spell_resolver.get_valid_lane_targets(card_data, true)
			for lane in player_lanes:
				lane.set_highlight(lane in valid_targets, lane in valid_targets)
			for lane in opponent_lanes:
				lane.set_highlight(lane in valid_targets, lane in valid_targets)
		else:
			log_message("Selected %s (Spell, Cost: %d MP). Click again or click any lane to cast." % [card_name, cost])
			for lane in player_lanes:
				lane.set_highlight(true, true)
	elif card_type == "BUILDING":
		log_message("Selected %s (Building, Cost: %d MP). Click an empty building slot to construct." % [card_name, cost])
		for lane in player_lanes:
			var check = lane.can_accept_building(card_data)
			lane.set_highlight(check.allowed, check.allowed)
	else:
		log_message("Selected %s (%s, Cost: %d MP). Click an empty lane to summon." % [card_name, faction, cost])
		for lane in player_lanes:
			if not lane.has_creature:
				var check = lane.can_accept_creature(card_data)
				lane.set_highlight(true, check.allowed)

func _deselect_card() -> void:
	if selected_card_view:
		selected_card_view.modulate = Color.WHITE
		selected_card_view = null
	for lane in player_lanes:
		lane.set_highlight(false)
	for lane in opponent_lanes:
		lane.set_highlight(false)

func _on_lane_clicked(lane: LaneSlot) -> void:
	if not is_action_allowed() or selected_card_view == null:
		return

	var card_data = selected_card_view.card_data
	var card_type = card_data.get("type", "CREATURE")

	if card_type == "SPELL":
		_cast_selected_spell_on_lane(lane)
		return

	if card_type == "BUILDING":
		if not lane.is_player:
			return
		var cost = card_data.get("cost", 1)
		if player_mp < cost:
			lane.flash_invalid()
			log_message("❌ Not enough Magic Points! (Need %d MP, have %d MP)" % [cost, player_mp])
			return
		var check = lane.can_accept_building(card_data)
		if not check.allowed:
			lane.flash_invalid()
			log_message("❌ Cannot build: " + check.reason)
			return

		# Construct building
		player_mp -= cost
		lane.place_building(card_data)
		log_message("🏰 Constructed %s on Lane %d (%s)!" % [card_data.get("name", "Building"), lane.lane_index + 1, lane.landscape])

		if ResourceLoader.exists("res://assets/audio/sfx/Click.wav"):
			Audio.play_sfx_with_variation(load("res://assets/audio/sfx/Click.wav"), -4.0, 0.05)

		var to_free = selected_card_view
		_deselect_card()
		to_free.queue_free()
		_update_ui()
		return

	if not lane.is_player:
		return

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

func _cast_selected_spell_on_lane(target_lane: LaneSlot = null) -> bool:
	if selected_card_view == null or not is_action_allowed():
		return false

	var card_data = selected_card_view.card_data
	var cost = card_data.get("cost", 1)

	if player_mp < cost:
		if target_lane:
			target_lane.flash_invalid()
		log_message("❌ Not enough Magic Points! (Need %d MP, have %d MP)" % [cost, player_mp])
		return false

	if spell_resolver:
		if spell_resolver.is_targeted(card_data):
			var valid_targets = spell_resolver.get_valid_lane_targets(card_data, true)
			if target_lane == null or not (target_lane in valid_targets):
				if target_lane:
					target_lane.flash_invalid()
				log_message("❌ Invalid target for %s!" % card_data.get("name", "Spell"))
				return false

		# Deduct MP
		player_mp -= cost

		if ResourceLoader.exists("res://assets/audio/sfx/LeaderPower.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/LeaderPower.wav"), -6.0)

		var res = spell_resolver.cast_spell(card_data, target_lane, true)
		log_message("✨ Cast %s! %s" % [card_data.get("name", "Spell"), res.get("message", "")])
	else:
		player_mp -= cost

	# Move to discard pile
	player_discard_pile.append(card_data.get("id", ""))

	# Remove from hand and reset selection
	var to_free = selected_card_view
	_deselect_card()
	to_free.queue_free()
	_update_ui()
	return true

func _on_floop_requested(lane: LaneSlot) -> void:
	if not is_action_allowed() or not lane.has_creature or lane.is_flooped:
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
	if not is_action_allowed() or player_leader_cooldown > 0:
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
	if not is_action_allowed():
		return
	_deselect_card()
	execute_battle_phase()

func execute_battle_phase() -> void:
	is_player_turn = false
	turn_btn.disabled = true
	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.BATTLE_WHEEL_PHASE)
	log_message("=== BATTLE PHASE! ===")

	# Player attacks
	for i in range(4):
		var p_lane = player_lanes[i]
		if not p_lane.has_creature:
			continue

		if phase_manager != null:
			phase_manager.start_combat_lane(i)

		if ability_system:
			ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_ATTACK, p_lane)

		var attacker_name = p_lane.creature_data.get("name", "Creature")
		var atk = p_lane.current_atk
		var o_lane = opponent_lanes[i]
		var target_name = o_lane.creature_data.get("name", "Creature") if o_lane.has_creature else GameManager.opponent_hero_name

		# Trigger Battle Wheel minigame
		wheel_modal.start_attack_clash(
			attacker_name,
			target_name,
			atk,
			true
		)
		var clash_res = await wheel_modal.clash_resolved
		var final_damage: int = clash_res.final_damage

		if phase_manager != null:
			phase_manager.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
			phase_manager.resolve_combat_lane(i, clash_res)

		if clash_res.id == "crit":
			log_message("⚡ CRITICAL HIT! %s dealt 2x damage (%d DMG)!" % [attacker_name, final_damage])
		elif clash_res.id == "miss":
			log_message("❌ MISSED! %s's attack missed completely!" % attacker_name)
		else:
			log_message("⚔️ HIT! %s dealt %d damage to %s!" % [attacker_name, final_damage, target_name])

		if o_lane.has_creature:
			var target_creature_name = o_lane.creature_data.get("name", "Creature")
			var destroyed = o_lane.apply_damage(final_damage)
			if destroyed:
				log_message("Opponent's %s was destroyed!" % target_creature_name)
		else:
			opponent_hp = max(0, opponent_hp - final_damage)

		_update_ui()
		if opponent_hp <= 0:
			end_match(true)
			return

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_END)

	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.END_TURN)

	# Opponent AI turn
	var timer = get_tree().create_timer(1.2)
	await timer.timeout
	execute_opponent_turn()

func execute_opponent_turn() -> void:
	if phase_manager != null:
		if phase_manager.get_current_phase() != BattlePhaseManager.Phase.START_TURN:
			phase_manager.transition_to(BattlePhaseManager.Phase.START_TURN)

	if ResourceLoader.exists("res://assets/audio/sfx/OpponentTurn.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/OpponentTurn.wav"))
	log_message("=== Opponent Turn (%s) ===" % GameManager.opponent_hero_name)

	for lane in player_lanes:
		lane.clear_tombstone()
	for lane in opponent_lanes:
		lane.clear_tombstone()

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_START)

	# Decrement Opponent Leader Cooldown
	if opponent_leader_cooldown > 0:
		opponent_leader_cooldown = max(0, opponent_leader_cooldown - 1)
	opponent_leader_btn.update_cooldown(opponent_leader_cooldown)

	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.ACTION_PHASE)

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
						GameManager.opponent_hero_name, candidate_card.get("name", "Creature"), o_lane.lane_index + 1, o_lane.landscape
					])
					if ability_system:
						ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_SUMMON, o_lane)
					break

	# AI constructs buildings if available in draw pile
	if not opponent_draw_pile.is_empty():
		for i in range(opponent_draw_pile.size() - 1, -1, -1):
			var c_id = opponent_draw_pile[i]
			var c_data = Database.get_card(c_id)
			if not c_data.is_empty() and c_data.get("type") == "BUILDING":
				for o_lane in opponent_lanes:
					if not o_lane.has_building and o_lane.can_accept_building(c_data).allowed:
						opponent_draw_pile.remove_at(i)
						o_lane.place_building(c_data)
						log_message("%s constructed %s on Lane %d (%s)!" % [
							GameManager.opponent_hero_name, c_data.get("name", "Building"), o_lane.lane_index + 1, o_lane.landscape
						])
						break
				break

	# AI casts spells if available in draw pile
	if not opponent_draw_pile.is_empty() and spell_resolver != null:
		for i in range(opponent_draw_pile.size() - 1, -1, -1):
			var c_id = opponent_draw_pile[i]
			var c_data = Database.get_card(c_id)
			if not c_data.is_empty() and c_data.get("type") == "SPELL":
				var check = spell_resolver.can_cast(c_data, 10, false)
				if check.allowed:
					opponent_draw_pile.remove_at(i)
					var target: LaneSlot = null
					if spell_resolver.is_targeted(c_data):
						var targets = spell_resolver.get_valid_lane_targets(c_data, false)
						if not targets.is_empty():
							target = targets[0]
					var res = spell_resolver.cast_spell(c_data, target, false)
					opponent_discard_pile.append(c_id)
					log_message("%s cast %s! %s" % [
						GameManager.opponent_hero_name, c_data.get("name", "Spell"), res.get("message", "")
					])
					break

	# Opponent attacks
	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.BATTLE_WHEEL_PHASE)

	for i in range(4):
		var o_lane = opponent_lanes[i]
		if not o_lane.has_creature:
			continue

		if phase_manager != null:
			phase_manager.start_combat_lane(i)

		if ability_system:
			ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_ATTACK, o_lane)

		var attacker_name = o_lane.creature_data.get("name", "Creature")
		var atk = o_lane.current_atk
		var p_lane = player_lanes[i]
		var target_name = p_lane.creature_data.get("name", "Creature") if p_lane.has_creature else GameManager.player_hero_name

		# Opponent wheel clash (quick-resolve mode)
		wheel_modal.start_attack_clash(
			attacker_name,
			target_name,
			atk,
			false, # is_player
			0.80,
			0.07,
			true # quick resolve for AI
		)
		var clash_res = await wheel_modal.clash_resolved
		var final_damage: int = clash_res.final_damage

		if phase_manager != null:
			phase_manager.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
			phase_manager.resolve_combat_lane(i, clash_res)

		if clash_res.id == "crit":
			log_message("⚡ CRITICAL HIT! %s dealt 2x damage (%d DMG)!" % [attacker_name, final_damage])
		elif clash_res.id == "miss":
			log_message("❌ MISSED! %s's attack missed!" % attacker_name)
		else:
			log_message("⚔️ HIT! %s dealt %d damage to %s!" % [attacker_name, final_damage, target_name])

		if p_lane.has_creature:
			var target_creature_name = p_lane.creature_data.get("name", "Creature")
			var destroyed = p_lane.apply_damage(final_damage)
			if destroyed:
				log_message("Your %s was destroyed!" % target_creature_name)
		else:
			player_hp = max(0, player_hp - final_damage)

		_update_ui()
		if player_hp <= 0:
			end_match(false)
			return

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_END)

	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.END_TURN)

	var timer = get_tree().create_timer(1.0)
	await timer.timeout
	start_player_turn()

func end_match(victory: bool) -> void:
	if phase_manager != null:
		phase_manager.end_match(victory)
	if GameManager:
		GameManager.add_rewards(session_gold, session_loot_cards)
	dialog_panel.visible = true
	var reward_text = ""
	if session_gold > 0 or not session_loot_cards.is_empty():
		reward_text = "\n\nRewards:\n💰 Gold: +%d" % session_gold
		if not session_loot_cards.is_empty():
			reward_text += "\n🎁 Cards Won: %d" % session_loot_cards.size()
	if victory:
		dialog_label.text = "🏆 VICTORY! 🏆\nYou are crowned a Cool Guy!" + reward_text
	else:
		dialog_label.text = "💀 DEFEAT! 💀\nYou drank from the Dweeb Cup!" + reward_text

func _on_creature_destroyed(lane: LaneSlot, dead_data: Dictionary) -> void:
	var creature_name = dead_data.get("name", "Creature")
	if not lane.is_player:
		# Opponent creature died -> roll drop table
		var candidate_cards = GameManager.opponent_deck
		var drop = LootRoller.roll_drop(drop_profile_id, loot_drops_count, candidate_cards)
		loot_drops_count += 1
		lane.spawn_tombstone(drop)
		if drop.type == "CARD":
			log_message("🎁 Opponent's %s dropped a Card Chest!" % creature_name)
		elif drop.type == "GOLD":
			log_message("💰 Opponent's %s dropped a Gold Bag!" % creature_name)
		else:
			log_message("🪦 Opponent's %s was destroyed!" % creature_name)
	else:
		lane.spawn_tombstone({
			"type": "TOMBSTONE",
			"card_id": "",
			"card_name": "",
			"amount": 0,
			"texture_path": "res://assets/textures/props/Tombstone.png",
			"icon": "🪦",
			"label": "R.I.P."
		})
		log_message("Your %s was destroyed!" % creature_name)

func _on_loot_collected(lane: LaneSlot, loot_type: String, drop_data: Dictionary) -> void:
	if loot_type == "GOLD":
		var amt = int(drop_data.get("amount", 0))
		session_gold += amt
		log_message("💰 Collected %d Gold Coins!" % amt)
	elif loot_type == "CARD":
		var c_id = str(drop_data.get("card_id", ""))
		var c_name = str(drop_data.get("card_name", "Mystery Card"))
		session_loot_cards.append(c_id)
		log_message("🎁 Collected Card: %s!" % c_name)
	_update_ui()

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
