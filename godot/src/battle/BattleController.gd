extends Control

const BattleWheelModal = preload("res://src/battle/BattleWheelModal.gd")
const LeaderPowerButton = preload("res://src/battle/LeaderPowerButton.gd")
const AbilitySystem = preload("res://src/battle/AbilitySystem.gd")
const BattlePhaseManager = preload("res://src/battle/BattlePhaseManager.gd")
const SpellResolver = preload("res://src/battle/SpellResolver.gd")
const LootRoller = preload("res://src/battle/LootRoller.gd")
const Tombstone = preload("res://src/battle/Tombstone.gd")
const CharacterFaceRig = preload("res://src/battle/CharacterFaceRig.gd")
const VOManager = preload("res://src/battle/VOManager.gd")
const BattleResultModal = preload("res://src/ui/BattleResultModal.gd")
const StarConditionEvaluator = preload("res://src/systems/node_map_system/StarConditionEvaluator.gd")
const MatchRulesConfig = preload("res://src/systems/local_multiplayer/MatchRulesConfig.gd")
const PlayerInputRouter = preload("res://src/systems/local_multiplayer/PlayerInputRouter.gd")
const HotseatCurtain = preload("res://src/systems/local_multiplayer/HotseatCurtain.gd")
const GamepadNavigator = preload("res://src/systems/local_multiplayer/GamepadNavigator.gd")
const TurnActionProtocol = preload("res://src/systems/network_multiplayer/TurnActionProtocol.gd")

@onready var opponent_hp_bar: ProgressBar = $Header/OpponentInfo/HpBar
@onready var opponent_hp_label: Label = $Header/OpponentInfo/HpLabel
@onready var opponent_name_label: Label = $Header/OpponentInfo/NameLabel
@onready var opponent_leader_btn: LeaderPowerButton = $Header/OpponentInfo/OpponentLeaderPower
@onready var opponent_face_rig: CharacterFaceRig = $Header/OpponentInfo/OpponentFaceRig

@onready var player_hp_bar: ProgressBar = $Footer/PlayerInfo/HpBar
@onready var player_hp_label: Label = $Footer/PlayerInfo/HpLabel
@onready var player_name_label: Label = $Footer/PlayerInfo/NameLabel
@onready var player_leader_btn: LeaderPowerButton = $Footer/PlayerInfo/PlayerLeaderPower
@onready var player_face_rig: CharacterFaceRig = $Footer/PlayerInfo/PlayerFaceRig
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
@onready var result_modal: BattleResultModal = $BattleResultModal

# Live Match Telemetry for 3-Star Objectives (Task 7.2)
var match_turn_count: int = 0
var match_player_hp_lost: int = 0
var match_player_creatures_lost: int = 0
var match_enemy_creatures_defeated: int = 0
var match_card_types_played: Array[String] = []
var match_factions_played: Array[String] = []
var match_floops_used: int = 0
var match_total_mp_spent: int = 0

# SYS-10 Local Multiplayer & Gamepad Support (Epic 5)
var input_router: PlayerInputRouter
var gamepad_navigator: GamepadNavigator
var hotseat_curtain: HotseatCurtain
var active_versus_player: int = 0 # 0 for P1, 1 for P2

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
var vo_manager: VOManager = null

func _ready() -> void:
	vo_manager = VOManager.new()
	add_child(vo_manager)

	hotseat_curtain = HotseatCurtain.new()
	add_child(hotseat_curtain)
	hotseat_curtain.unveil_confirmed.connect(_on_curtain_unveiled)

	var match_cfg = GameManager.match_rules if (GameManager and GameManager.is_local_versus) else MatchRulesConfig.new(MatchRulesConfig.MatchMode.SOLO_VS_AI)
	input_router = PlayerInputRouter.new(match_cfg)
	gamepad_navigator = GamepadNavigator.new()

	turn_btn.pressed.connect(_on_turn_button_pressed)
	dialog_btn.pressed.connect(_on_menu_button_pressed)
	match_intro.intro_completed.connect(_on_intro_completed)
	rps_modal.rps_completed.connect(_on_rps_completed)

	if GameManager and GameManager.is_network_match and GameManager.network_protocol:
		GameManager.network_protocol.action_executed.connect(_on_network_action_executed)

	setup_match()
	_update_controller_glyphs()
	match_intro.play_intro(
		GameManager.player_hero_name,
		GameManager.opponent_hero_name,
		player_max_hp,
		opponent_max_hp
	)

func _on_intro_completed() -> void:
	if GameManager and GameManager.is_network_match:
		_on_rps_completed(GameManager.is_network_host)
		return
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

	# Reset Match Telemetry
	match_turn_count = 0
	match_player_hp_lost = 0
	match_player_creatures_lost = 0
	match_enemy_creatures_defeated = 0
	match_card_types_played.clear()
	match_factions_played.clear()
	if GameManager:
		for l in GameManager.player_landscapes:
			match_factions_played.append(str(l))
	match_floops_used = 0
	match_total_mp_spent = 0

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

	if player_face_rig:
		player_face_rig.setup(GameManager.player_hero_name)
		player_face_rig.play_emote(CharacterFaceRig.EmoteState.IDLE)
	if opponent_face_rig:
		opponent_face_rig.setup(GameManager.opponent_hero_name)
		opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.IDLE)

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
	match_turn_count += 1
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
		match_card_types_played.append("BUILDING")
		match_total_mp_spent += cost
		var b_fac = str(card_data.get("faction", "")).strip_edges()
		if b_fac != "":
			match_factions_played.append(b_fac)
		lane.place_building(card_data)
		if GameManager and GameManager.is_network_match and GameManager.network_protocol:
			GameManager.network_protocol.send_play_card(str(card_data.get("id", "")), lane.lane_index, false)
		log_message("🏰 Constructed %s on Lane %d (%s)!" % [card_data.get("name", "Building"), lane.lane_index + 1, lane.landscape])

		if player_face_rig:
			player_face_rig.play_emote(CharacterFaceRig.EmoteState.PLAY_CARD)
		if vo_manager:
			vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.PLAY_BUILDING, true)

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
	match_card_types_played.append("CREATURE")
	match_total_mp_spent += cost
	var c_fac = str(card_data.get("faction", "")).strip_edges()
	if c_fac != "":
		match_factions_played.append(c_fac)
	lane.place_creature(card_data)
	if GameManager and GameManager.is_network_match and GameManager.network_protocol:
		GameManager.network_protocol.send_play_card(str(card_data.get("id", "")), lane.lane_index, false)
	log_message("✨ Summoned %s onto Lane %d (%s)!" % [card_data.get("name", "Creature"), lane.lane_index + 1, lane.landscape])

	if player_face_rig:
		player_face_rig.play_emote(CharacterFaceRig.EmoteState.PLAY_CARD)
	if vo_manager:
		vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.PLAY_CREATURE, true)

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
		match_card_types_played.append("SPELL")
		match_total_mp_spent += cost
		var s_fac = str(card_data.get("faction", "")).strip_edges()
		if s_fac != "":
			match_factions_played.append(s_fac)

		if ResourceLoader.exists("res://assets/audio/sfx/LeaderPower.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/LeaderPower.wav"), -6.0)

		var res = spell_resolver.cast_spell(card_data, target_lane, true)
		if GameManager and GameManager.is_network_match and GameManager.network_protocol:
			GameManager.network_protocol.send_play_card(str(card_data.get("id", "")), target_lane.lane_index if target_lane else 0, true)
		log_message("✨ Cast %s! %s" % [card_data.get("name", "Spell"), res.get("message", "")])
	else:
		player_mp -= cost
		match_card_types_played.append("SPELL")
		match_total_mp_spent += cost

	if player_face_rig:
		player_face_rig.play_emote(CharacterFaceRig.EmoteState.PLAY_CARD)
	if vo_manager:
		vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.PLAY_SPELL, true)

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
	match_floops_used += 1
	match_total_mp_spent += floop_cost
	lane.set_flooped(true)
	if GameManager and GameManager.is_network_match and GameManager.network_protocol:
		GameManager.network_protocol.send_floop(lane.lane_index)
	log_message("Flooped %s!" % data.get("name", "Creature"))

	if vo_manager:
		vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.FLOOP, true)
	if ResourceLoader.exists("res://assets/audio/sfx/FX_Battle_FloopAnimation.wav"):
		Audio.play_sfx_with_variation(load("res://assets/audio/sfx/FX_Battle_FloopAnimation.wav"), -3.0)

	_execute_floop_ability(lane)
	_update_ui()

func _execute_floop_ability(source_lane: LaneSlot) -> void:
	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_FLOOP, source_lane)

func _on_player_leader_power_activated(char_id: String) -> void:
	if not is_action_allowed() or player_leader_cooldown > 0:
		return
	if GameManager and GameManager.is_network_match and GameManager.network_protocol:
		GameManager.network_protocol.send_leader_power(char_id)
	_execute_leader_power(true, char_id)

func _execute_leader_power(is_player_owner: bool, char_id: String) -> void:
	var leader = Database.get_leader(char_id)
	var script_name = leader.get("script_name", "")
	var hero_name = leader.get("name", char_id)

	# Audio feedback
	if ResourceLoader.exists("res://assets/audio/sfx/LeaderPower.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/LeaderPower.wav"))

	var lanes = player_lanes if is_player_owner else opponent_lanes
	var owner_tag = "YOU" if is_player_owner else GameManager.opponent_hero_name

	if is_player_owner:
		if player_face_rig:
			player_face_rig.play_emote(CharacterFaceRig.EmoteState.PLAY_CARD)
	else:
		if opponent_face_rig:
			opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.PLAY_CARD)

	if vo_manager:
		vo_manager.play_event(hero_name, VOManager.VOEvent.LEADER_ABILITY, is_player_owner)

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
			if ResourceLoader.exists("res://assets/audio/sfx/Ring_Crit.wav"):
				Audio.play_sfx(load("res://assets/audio/sfx/Ring_Crit.wav"))
		elif clash_res.id == "miss":
			log_message("❌ MISSED! %s's attack missed completely!" % attacker_name)
			if ResourceLoader.exists("res://assets/audio/sfx/Ring_Miss.wav"):
				Audio.play_sfx(load("res://assets/audio/sfx/Ring_Miss.wav"))
		else:
			log_message("⚔️ HIT! %s dealt %d damage to %s!" % [attacker_name, final_damage, target_name])
			if ResourceLoader.exists("res://assets/audio/sfx/Ring_Hit.wav"):
				Audio.play_sfx_with_variation(load("res://assets/audio/sfx/Ring_Hit.wav"))

		if o_lane.has_creature:
			var target_creature_name = o_lane.creature_data.get("name", "Creature")
			var destroyed = o_lane.apply_damage(final_damage)
			if destroyed:
				log_message("Opponent's %s was destroyed!" % target_creature_name)
				if opponent_face_rig:
					opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
				if vo_manager:
					vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.DESTROY_CREATURE, true)
					vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.CREATURE_DESTROYED, false)
		else:
			opponent_hp = max(0, opponent_hp - final_damage)
			if opponent_face_rig:
				opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
			if vo_manager:
				vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.HERO_DAMAGED, false)

		_update_ui()
		if opponent_hp <= 0:
			end_match(true)
			return

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_END)

	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.END_TURN)

	if GameManager and GameManager.is_network_match:
		if GameManager.network_protocol:
			GameManager.network_protocol.send_end_turn()
		turn_btn.disabled = true
		turn_btn.text = "%s's Turn..." % GameManager.remote_player_name
		log_message("⏳ Waiting for %s's move..." % GameManager.remote_player_name)
		return

	if GameManager and GameManager.is_local_versus:
		var rules = GameManager.match_rules
		var next_slot = 0 if active_versus_player == 1 else 1
		var next_name = GameManager.player_hero_name if next_slot == 0 else GameManager.opponent_hero_name
		if rules and rules.is_hotseat():
			hotseat_curtain.start_handoff(next_slot, next_name)
		else:
			if next_slot == 0:
				start_player_turn()
			else:
				execute_versus_p2_turn()
		return

	# Opponent AI turn
	var timer = get_tree().create_timer(1.2)
	await timer.timeout
	execute_opponent_turn()


func _update_controller_glyphs() -> void:
	var ctype = PlayerInputRouter.detect_controller_type(0)
	var rb_glyph = PlayerInputRouter.get_action_glyph("end_turn", ctype)
	if ctype != MatchRulesConfig.ControllerType.KEYBOARD_MOUSE:
		turn_btn.text = "End Turn [%s]" % rb_glyph


func _register_navigator_zones() -> void:
	if gamepad_navigator == null:
		return
	var hand_nodes: Array = hand_container.get_children()
	gamepad_navigator.register_zone_nodes(GamepadNavigator.FocusZone.HAND, hand_nodes)
	gamepad_navigator.register_zone_nodes(GamepadNavigator.FocusZone.LANES, player_lanes)
	gamepad_navigator.register_zone_nodes(GamepadNavigator.FocusZone.LEADER, [player_leader_btn])
	gamepad_navigator.register_zone_nodes(GamepadNavigator.FocusZone.END_TURN, [turn_btn])


func _on_network_action_executed(sender_id: int, action_type: String, payload: Dictionary) -> void:
	if not GameManager or not GameManager.is_network_match:
		return
	if GameManager.network_session and sender_id == GameManager.network_session.get_local_peer_id():
		return # Local action already handled locally

	match action_type:
		TurnActionProtocol.ACTION_PLAY_CARD:
			var card_id = str(payload.get("card_id", ""))
			var slot_idx = int(payload.get("target_slot", 0))
			var is_spell = bool(payload.get("is_spell", false))
			var c_data = Database.get_card(card_id)
			if c_data.is_empty():
				return

			if slot_idx >= 0 and slot_idx < opponent_lanes.size():
				var o_lane = opponent_lanes[slot_idx]
				if is_spell or c_data.get("type") == "SPELL":
					if spell_resolver:
						spell_resolver.execute_spell(c_data, o_lane, false)
				elif c_data.get("type") == "BUILDING":
					o_lane.place_building(c_data)
				else:
					o_lane.place_creature(c_data)
				log_message("%s played %s on Lane %d!" % [GameManager.remote_player_name, c_data.get("name", "Card"), slot_idx + 1])
				_update_ui()

		TurnActionProtocol.ACTION_FLOOP:
			var slot_idx = int(payload.get("slot_index", 0))
			if slot_idx >= 0 and slot_idx < opponent_lanes.size():
				var o_lane = opponent_lanes[slot_idx]
				if o_lane.has_creature and not o_lane.is_flooped:
					o_lane.set_flooped(true)
					_execute_floop_ability(o_lane)
					log_message("%s flooped %s on Lane %d!" % [GameManager.remote_player_name, o_lane.creature_data.get("name", "Creature"), slot_idx + 1])
					_update_ui()

		TurnActionProtocol.ACTION_LEADER_POWER:
			var hero_id = str(payload.get("hero_id", GameManager.opponent_hero_name))
			_execute_leader_power(false, hero_id)
			log_message("%s activated Leader Power!" % GameManager.remote_player_name)
			_update_ui()

		TurnActionProtocol.ACTION_END_TURN:
			log_message("=== Your Turn! (%s finished their turn) ===" % GameManager.remote_player_name)
			start_player_turn()

		TurnActionProtocol.ACTION_SURRENDER:
			log_message("🏳️ %s surrendered!" % GameManager.remote_player_name)
			end_match(true)


func _on_curtain_unveiled(next_slot: int) -> void:
	active_versus_player = next_slot
	if input_router:
		input_router.set_active_turn_player(next_slot)

	if next_slot == 1:
		execute_versus_p2_turn()
	else:
		start_player_turn()


func execute_versus_p2_turn() -> void:
	is_player_turn = true
	turn_btn.disabled = false
	turn_btn.text = "%s: End Turn ➔" % GameManager.opponent_hero_name
	log_message("=== %s's Turn (P2) ===" % GameManager.opponent_hero_name)
	_register_navigator_zones()
	gamepad_navigator.focus_zone(GamepadNavigator.FocusZone.HAND, 0)


func _unhandled_input(event: InputEvent) -> void:
	if hotseat_curtain and hotseat_curtain.visible:
		return
	if result_modal and result_modal.visible:
		return
	if input_router == null or gamepad_navigator == null:
		return

	var routed = input_router.route_input_event(event)
	if not routed.consumed:
		return

	if routed.action == "navigate":
		_register_navigator_zones()
		gamepad_navigator.navigate(routed.direction)
		get_viewport().set_input_as_handled()
	elif routed.action == "end_turn":
		if is_action_allowed() and not turn_btn.disabled:
			_on_turn_button_pressed()
			get_viewport().set_input_as_handled()
	elif routed.action == "leader_power":
		if is_action_allowed() and player_leader_cooldown <= 0:
			_on_player_leader_power_activated(GameManager.player_hero_name)
			get_viewport().set_input_as_handled()
	elif routed.action == "floop":
		var focused = gamepad_navigator.get_focused_node()
		if focused is LaneSlot and focused.has_creature and not focused.is_flooped:
			_on_floop_requested(focused)
			get_viewport().set_input_as_handled()
	elif routed.action == "confirm":
		var focused = gamepad_navigator.get_focused_node()
		if focused is CardView:
			_on_hand_card_clicked(focused)
			gamepad_navigator.focus_zone(GamepadNavigator.FocusZone.LANES, 0)
			get_viewport().set_input_as_handled()
		elif focused is LaneSlot:
			if selected_card_view != null:
				_on_lane_clicked(focused)
				gamepad_navigator.focus_zone(GamepadNavigator.FocusZone.HAND, 0)
				get_viewport().set_input_as_handled()
			elif focused.has_creature and not focused.is_flooped:
				_on_floop_requested(focused)
				get_viewport().set_input_as_handled()
		elif focused == turn_btn:
			_on_turn_button_pressed()
			get_viewport().set_input_as_handled()
		elif focused == player_leader_btn:
			_on_player_leader_power_activated(GameManager.player_hero_name)
			get_viewport().set_input_as_handled()
	elif routed.action == "cancel":
		if selected_card_view != null:
			_deselect_card()
			gamepad_navigator.focus_zone(GamepadNavigator.FocusZone.HAND, 0)
			get_viewport().set_input_as_handled()

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
					if opponent_face_rig:
						opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.PLAY_CARD)
					if vo_manager:
						vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.PLAY_CREATURE, false)
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
						if opponent_face_rig:
							opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.PLAY_CARD)
						if vo_manager:
							vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.PLAY_BUILDING, false)
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
					if opponent_face_rig:
						opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.PLAY_CARD)
					if vo_manager:
						vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.PLAY_SPELL, false)
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
			if ResourceLoader.exists("res://assets/audio/sfx/Ring_Crit.wav"):
				Audio.play_sfx(load("res://assets/audio/sfx/Ring_Crit.wav"))
		elif clash_res.id == "miss":
			log_message("❌ MISSED! %s's attack missed!" % attacker_name)
			if ResourceLoader.exists("res://assets/audio/sfx/Ring_Miss.wav"):
				Audio.play_sfx(load("res://assets/audio/sfx/Ring_Miss.wav"))
		else:
			log_message("⚔️ HIT! %s dealt %d damage to %s!" % [attacker_name, final_damage, target_name])
			if ResourceLoader.exists("res://assets/audio/sfx/Ring_Hit.wav"):
				Audio.play_sfx_with_variation(load("res://assets/audio/sfx/Ring_Hit.wav"))

		if p_lane.has_creature:
			var target_creature_name = p_lane.creature_data.get("name", "Creature")
			var destroyed = p_lane.apply_damage(final_damage)
			if destroyed:
				log_message("Your %s was destroyed!" % target_creature_name)
				if player_face_rig:
					player_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
				if vo_manager:
					vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.DESTROY_CREATURE, false)
					vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.CREATURE_DESTROYED, true)
		else:
			player_hp = max(0, player_hp - final_damage)
			match_player_hp_lost += final_damage
			if player_face_rig:
				player_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
			if vo_manager:
				vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.HERO_DAMAGED, true)

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

func get_match_stats(victory: bool) -> Dictionary:
	var distinct_types: Array[String] = []
	for t in match_card_types_played:
		if not distinct_types.has(t):
			distinct_types.append(t)
	var distinct_factions: Array[String] = []
	for f in match_factions_played:
		if not distinct_factions.has(f):
			distinct_factions.append(f)

	return {
		"won": victory,
		"turns": maxi(1, match_turn_count),
		"player_hp_lost": maxi(0, match_player_hp_lost),
		"player_creatures_lost": match_player_creatures_lost,
		"enemy_creatures_defeated": match_enemy_creatures_defeated,
		"card_types_played": distinct_types,
		"factions_played": distinct_factions,
		"landscapes_count": GameManager.player_landscapes.size() if GameManager else 4,
		"floops_used": match_floops_used,
		"mp_spent": match_total_mp_spent
	}


func end_match(victory: bool) -> void:
	if victory:
		if player_face_rig:
			player_face_rig.play_emote(CharacterFaceRig.EmoteState.VICTORY)
		if opponent_face_rig:
			opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.DEFEAT)
		if vo_manager:
			vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.WIN, true, true)
			vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.LOSE, false, true)
		if ResourceLoader.exists("res://assets/audio/sfx/FX_BattleEnd_P1Win.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/FX_BattleEnd_P1Win.wav"), -2.0)
	else:
		if player_face_rig:
			player_face_rig.play_emote(CharacterFaceRig.EmoteState.DEFEAT)
		if opponent_face_rig:
			opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.VICTORY)
		if vo_manager:
			vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.LOSE, true, true)
			vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.WIN, false, true)
		if ResourceLoader.exists("res://assets/audio/sfx/FX_BattleEnd_Defeat.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/FX_BattleEnd_Defeat.wav"), -2.0)

	if phase_manager != null:
		phase_manager.end_match(victory)
	if GameManager:
		GameManager.add_rewards(session_gold, session_loot_cards)

	var match_stats = get_match_stats(victory)
	var rewards_dict = {
		"coins": session_gold,
		"xp": 0,
		"cards": session_loot_cards.duplicate(),
		"leveled_up": false
	}
	var audit_report: Array = []
	var qid = GameManager.active_quest_id if GameManager else ""

	if qid != "":
		var quest = Database.get_quest(qid)
		var conditions = quest.get("conditions", [])
		audit_report = StarConditionEvaluator.audit_star_conditions(conditions, match_stats)
		if victory and GameManager:
			var prev_lvl = GameManager.get_hero_level(GameManager.player_hero_name)
			var q_res = GameManager.complete_campaign_quest(qid, match_stats)
			if q_res.get("ok", false):
				var q_rew = q_res.get("rewards", {})
				rewards_dict["coins"] += int(q_rew.get("coins", 0))
				rewards_dict["xp"] += int(q_rew.get("xp", 0))
				for c in q_rew.get("cards", []):
					rewards_dict["cards"].append(c)
				var new_lvl = GameManager.get_hero_level(GameManager.player_hero_name)
				if new_lvl > prev_lvl:
					rewards_dict["leveled_up"] = true

	if result_modal:
		result_modal.display_result(victory, qid, match_stats, rewards_dict, audit_report)
	else:
		dialog_panel.visible = true
		if victory:
			dialog_label.text = "🏆 VICTORY! 🏆\nYou are crowned a Cool Guy!\n💰 Gold: +%d" % rewards_dict["coins"]
		else:
			dialog_label.text = "💀 DEFEAT! 💀\nYou drank from the Dweeb Cup!"


func _on_creature_destroyed(lane: LaneSlot, dead_data: Dictionary) -> void:
	var creature_name = dead_data.get("name", "Creature")
	if not lane.is_player:
		match_enemy_creatures_defeated += 1
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
		match_player_creatures_lost += 1
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
