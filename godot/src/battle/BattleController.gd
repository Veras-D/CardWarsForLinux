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
const BattleJukebox = preload("res://src/battle/BattleJukebox.gd")
const BattleArena3D = preload("res://src/battle/BattleArena3D.gd")
const LandscapePlacementOverlay = preload("res://src/battle/LandscapePlacementOverlay.gd")
const KetchupBottleSpinner = preload("res://src/battle/KetchupBottleSpinner.gd")
const BattleModals = preload("res://src/battle/BattleModals.gd")
const BattleResultModal = preload("res://src/ui/BattleResultModal.gd")
const StarConditionEvaluator = preload("res://src/systems/node_map_system/StarConditionEvaluator.gd")
const MatchRulesConfig = preload("res://src/systems/local_multiplayer/MatchRulesConfig.gd")
const PlayerInputRouter = preload("res://src/systems/local_multiplayer/PlayerInputRouter.gd")
const HotseatCurtain = preload("res://src/systems/local_multiplayer/HotseatCurtain.gd")
const GamepadNavigator = preload("res://src/systems/local_multiplayer/GamepadNavigator.gd")
const TurnActionProtocol = preload("res://src/systems/network_multiplayer/TurnActionProtocol.gd")
const TEX_CREATURE_HP_BG = preload("res://assets/textures/battle/hud/HealthBar_Creature.png")
const TEX_CREATURE_HP_FILL = preload("res://assets/textures/battle/hud/CW_White.png")
const TEX_CREATURE_ARROW = preload("res://assets/textures/battle/hud/HealthBar_UpDown_Arrow.png")
const TEX_FLOOP_PANEL_BG = preload("res://assets/textures/battle/hud/FloopPanel_BG.png")

@onready var opponent_hp_bar: ProgressBar = $Header/OpponentInfo/HBox/StatsCol/HpBar
@onready var opponent_hp_label: Label = $Header/OpponentInfo/HBox/StatsCol/HpBar/HpLabel
@onready var opponent_name_label: Label = $Header/OpponentInfo/HBox/StatsCol/NameLabel
@onready var opponent_mp_label: Label = $Header/OpponentInfo/HBox/StatsCol/OppMpLabel
@onready var opponent_leader_btn: LeaderPowerButton = $Header/OpponentInfo/HBox/PortraitCol/OpponentLeaderPower
@onready var opponent_face_rig: CharacterFaceRig = $Header/OpponentInfo/HBox/PortraitCol/OpponentFaceRig

@onready var player_hp_bar: ProgressBar = $Header/PlayerCornerHud/HBox/StatsCol/HpBar
@onready var player_hp_label: Label = $Header/PlayerCornerHud/HBox/StatsCol/HpBar/HpLabel
@onready var player_name_label: Label = $Header/PlayerCornerHud/HBox/StatsCol/NameLabel
@onready var player_leader_btn: LeaderPowerButton = $Header/PlayerCornerHud/HBox/PortraitCol/PlayerLeaderPower
@onready var player_face_rig: CharacterFaceRig = $Header/PlayerCornerHud/HBox/PortraitCol/PlayerFaceRig
@onready var player_mp_label: Label = $Header/PlayerCornerHud/HBox/StatsCol/MpLabel

@onready var opponent_lanes_box: HBoxContainer = $Field/OpponentLanes
@onready var player_lanes_box: HBoxContainer = $Field/PlayerLanes
@onready var hand_container: HBoxContainer = $Footer/HandScroll/HandContainer

@onready var magic_orb_label: Label = $Footer/RightControls/MagicOrb/MagicOrbLabel
@onready var turn_btn: Button = $Footer/RightControls/TurnBtn
@onready var draw_count_label: Label = $Footer/LeftCounters/PilesRow/DrawPileBox/DrawCountLabel
@onready var discard_btn: Button = $Footer/LeftCounters/PilesRow/DiscardPileBtn
@onready var discard_count_label: Label = $Footer/LeftCounters/PilesRow/DiscardPileBtn/DiscardCountLabel
@onready var loot_count_label: Label = $Footer/LeftCounters/LootCoinRow/LootBadge/HBox/LootCountLabel
@onready var coins_count_label: Label = $Footer/LeftCounters/LootCoinRow/CoinsBadge/HBox/CoinsCountLabel
@onready var quest_quick_btn: TextureButton = $QuestQuickBtn
@onready var pause_quick_btn: TextureButton = $PauseQuickBtn

@onready var log_label: Label = $BattleLog/Label
@onready var dialog_panel: Panel = $EndGameDialog
@onready var dialog_label: Label = $EndGameDialog/VBox/ResultLabel
@onready var dialog_btn: Button = $EndGameDialog/VBox/MenuBtn

@onready var match_intro: Control = $MatchIntro
@onready var rps_modal: Control = $RockPaperScissors
@onready var landscape_overlay: LandscapePlacementOverlay = $LandscapePlacementOverlay
@onready var ketchup_spinner: KetchupBottleSpinner = $KetchupBottleSpinner
@onready var battle_modals: BattleModals = $BattleModals
@onready var wheel_modal: BattleWheelModal = $BattleWheelModal
@onready var result_modal: BattleResultModal = $BattleResultModal
@onready var arena_3d: BattleArena3D = get_node_or_null("ViewportContainer/SubViewport/BattleArena3D")
@onready var board_click_surface: Control = $BoardClickSurface
@onready var creature_stats_layer: Control = $CreatureStatsLayer
@onready var header_bar: Control = $Header
@onready var field_box: Control = $Field
@onready var footer_bar: Control = $Footer
@onready var battle_log_box: Control = $BattleLog

const FONT_BATTLE_HUD: FontFile = preload("res://assets/fonts/KBPlanetEarth.ttf")

var _stat_badges: Array[Dictionary] = []
var _pending_confirm_mode: String = ""
var _pending_confirm_lane: LaneSlot = null
var _pending_confirm_leader: String = ""
var _match_ended: bool = false

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
var opponent_mp: int = 2
var opponent_hand: Array[Dictionary] = []

var _first_player_idx: int = 0
var _round_magic_cap: int = 2
var _game_turn_count: int = 1

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
var jukebox: BattleJukebox = null

func _set_gameplay_hud_visible(show_hud: bool) -> void:
	if header_bar:
		header_bar.visible = show_hud
	if field_box:
		field_box.visible = false
	if board_click_surface:
		board_click_surface.visible = show_hud
	if creature_stats_layer:
		creature_stats_layer.visible = show_hud
	if footer_bar:
		footer_bar.visible = show_hud
	if battle_log_box:
		battle_log_box.visible = show_hud
	if turn_btn:
		turn_btn.visible = show_hud
	if quest_quick_btn:
		quest_quick_btn.visible = show_hud
	if pause_quick_btn:
		pause_quick_btn.visible = show_hud

func _ready() -> void:
	vo_manager = VOManager.new()
	add_child(vo_manager)

	jukebox = BattleJukebox.new()
	add_child(jukebox)

	hotseat_curtain = HotseatCurtain.new()
	add_child(hotseat_curtain)
	hotseat_curtain.unveil_confirmed.connect(_on_curtain_unveiled)

	var match_cfg = GameManager.match_rules if (GameManager and GameManager.is_local_versus) else MatchRulesConfig.new(MatchRulesConfig.MatchMode.SOLO_VS_AI)
	input_router = PlayerInputRouter.new(match_cfg)
	gamepad_navigator = GamepadNavigator.new()

	turn_btn.pressed.connect(_on_turn_button_pressed)
	dialog_btn.pressed.connect(_on_menu_button_pressed)
	if quest_quick_btn:
		quest_quick_btn.pressed.connect(_on_quest_quick_pressed)
	if pause_quick_btn:
		pause_quick_btn.pressed.connect(_on_pause_quick_pressed)
	if discard_btn:
		discard_btn.pressed.connect(_on_discard_pile_pressed)
	if battle_modals:
		battle_modals.quit_battle_confirmed.connect(_on_menu_button_pressed)
		battle_modals.force_battle_confirmed.connect(execute_battle_phase)
		battle_modals.ability_confirmed.connect(_on_ability_confirmed)
		battle_modals.ability_cancelled.connect(_on_ability_cancelled)
		battle_modals.info_dismissed.connect(_on_info_dismissed)
	if board_click_surface:
		board_click_surface.gui_input.connect(_on_board_surface_gui_input)
	_build_creature_stat_badges()
	match_intro.intro_completed.connect(_on_intro_completed)
	rps_modal.rps_completed.connect(_on_rps_completed)
	if landscape_overlay:
		landscape_overlay.landscapes_placed.connect(_on_landscapes_placed)
	if ketchup_spinner:
		ketchup_spinner.spin_completed.connect(_on_rps_completed)

	if GameManager and GameManager.is_network_match and GameManager.network_protocol:
		GameManager.network_protocol.action_executed.connect(_on_network_action_executed)

	setup_match()
	_update_controller_glyphs()

	if arena_3d:
		arena_3d.setup_heroes(GameManager.player_hero_name, GameManager.opponent_hero_name)
		if match_intro.has_method("bind_arena"):
			match_intro.bind_arena(arena_3d)
		if landscape_overlay:
			landscape_overlay.bind_arena(arena_3d)
		if ketchup_spinner:
			ketchup_spinner.bind_arena(arena_3d)
		if result_modal and result_modal.has_method("bind_arena"):
			result_modal.bind_arena(arena_3d)
	if result_modal:
		if not result_modal.continue_pressed.is_connected(_on_menu_button_pressed):
			result_modal.continue_pressed.connect(_on_menu_button_pressed)
		if not result_modal.retry_pressed.is_connected(_on_retry_match_pressed):
			result_modal.retry_pressed.connect(_on_retry_match_pressed)

	_set_gameplay_hud_visible(false)
	var arena_name := "Tree House"
	if GameManager and GameManager.active_quest_id != "" and Database:
		var q_data := Database.get_quest(GameManager.active_quest_id)
		var q_lvl := str(q_data.get("level_name", "")).strip_edges()
		if q_lvl != "" and not q_lvl.begins_with("!!"):
			arena_name = q_lvl

	if jukebox:
		jukebox.play_intro_sequence()
	if match_intro.has_method("play_intro"):
		var p1_disp := GameManager.player_hero_name
		var p2_disp := GameManager.opponent_hero_name
		if Database:
			var p1c := Database.get_character(p1_disp)
			if not p1c.is_empty():
				p1_disp = str(p1c.get("name", p1_disp))
			var p2c := Database.get_character(p2_disp)
			if not p2c.is_empty():
				p2_disp = str(p2c.get("name", p2_disp))
		match_intro.play_intro(
			p1_disp,
			p2_disp,
			player_max_hp,
			opponent_max_hp,
			arena_name
		)

func _on_intro_completed() -> void:
	if jukebox:
		var q_type := ""
		if GameManager and GameManager.active_quest_id != "" and Database:
			q_type = str(Database.get_quest(GameManager.active_quest_id).get("type", ""))
		jukebox.play_battle_theme(GameManager.opponent_hero_name, q_type)

	_set_gameplay_hud_visible(false)
	if landscape_overlay:
		landscape_overlay.start_placement(GameManager.player_landscapes, GameManager.opponent_landscapes)
	else:
		_on_landscapes_placed(GameManager.player_landscapes)


func _on_landscapes_placed(final_order: Array[String]) -> void:
	if GameManager:
		GameManager.player_landscapes = final_order.duplicate()
	for i in range(mini(4, player_lanes.size())):
		if i < final_order.size():
			player_lanes[i].update_landscape(final_order[i])
			if arena_3d:
				arena_3d.set_lane_landscape(true, i, final_order[i], false)
	if arena_3d and GameManager:
		for j in range(mini(4, GameManager.opponent_landscapes.size())):
			arena_3d.set_lane_landscape(false, j, GameManager.opponent_landscapes[j], false)

	var is_fc := false
	if GameManager and GameManager.active_quest_id != "" and Database:
		is_fc = str(Database.get_quest(GameManager.active_quest_id).get("type", "")) == "fc"

	var forced_winner := -1
	if GameManager and GameManager.is_network_match:
		forced_winner = 1 if GameManager.is_network_host else 0

	if ketchup_spinner:
		ketchup_spinner.start_spin(GameManager.player_hero_name, GameManager.opponent_hero_name, is_fc, forced_winner)
	else:
		_on_rps_completed(forced_winner != 0)


func _on_rps_completed(player_goes_first: bool) -> void:
	if ketchup_spinner:
		ketchup_spinner.visible = false
	if arena_3d:
		arena_3d.focus_setup_board(0.65)
	_set_gameplay_hud_visible(true)
	_first_player_idx = 0 if player_goes_first else 1
	_game_turn_count = 1
	_round_magic_cap = 2
	player_max_mp = 2
	player_mp = 2
	opponent_mp = 2
	if player_goes_first:
		log_message("⚡ YOU GO FIRST! (Turn 1)")
		if phase_manager:
			phase_manager.start_battle(0)
		start_player_turn()
	else:
		log_message("🛡️ %s GOES FIRST! (Turn 1)" % GameManager.opponent_hero_name.to_upper())
		turn_btn.disabled = true
		turn_btn.text = ""
		if phase_manager:
			phase_manager.start_battle(1)
		var timer = get_tree().create_timer(1.1)
		timer.timeout.connect(execute_opponent_turn)

func setup_match() -> void:
	player_name_label.text = GameManager.player_hero_name.to_upper()
	player_max_hp = GameManager.player_hero_max_hp
	player_hp = player_max_hp

	opponent_name_label.text = GameManager.opponent_hero_name.to_upper()
	opponent_max_hp = GameManager.opponent_hero_max_hp
	opponent_hp = opponent_max_hp

	player_draw_pile = GameManager.player_deck.duplicate()
	player_draw_pile.shuffle()

	opponent_draw_pile = GameManager.opponent_deck.duplicate()
	opponent_draw_pile.shuffle()
	opponent_hand.clear()
	for _i in range(4):
		_draw_opponent_card()

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

	# Play Battle Intro theme first; opponent BGM begins when 3D intro ends
	if jukebox:
		jukebox.play_intro_sequence()

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

	if battle_modals:
		battle_modals.play_turn_banner(true, _game_turn_count > 1)
	player_max_mp = _round_magic_cap
	player_mp = player_max_mp

	# Decrement Leader Cooldown
	if player_leader_cooldown > 0:
		player_leader_cooldown = max(0, player_leader_cooldown - 1)
	player_leader_btn.update_cooldown(player_leader_cooldown)

	for lane in player_lanes:
		lane.clear_tombstone()
		lane.reset_turn()
		if arena_3d:
			arena_3d.set_lane_flooped(true, lane.lane_index, false, lane.has_creature)
	for lane in opponent_lanes:
		lane.clear_tombstone()

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_START)

	draw_player_card()
	_update_ui()

	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.ACTION_PHASE)

	log_message("Your Turn!" if _game_turn_count > 1 else "Turn 1: Place Creatures (No Attack on Turn 1)")
	turn_btn.text = ""
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
				var ok: bool = lane in valid_targets
				lane.set_highlight(ok, ok)
				if arena_3d:
					arena_3d.set_lane_highlight(true, lane.lane_index, ok)
			for lane in opponent_lanes:
				var ok_o: bool = lane in valid_targets
				lane.set_highlight(ok_o, ok_o)
				if arena_3d:
					arena_3d.set_lane_highlight(false, lane.lane_index, ok_o)
		else:
			log_message("Selected %s (Spell, Cost: %d MP). Click again or click any lane to cast." % [card_name, cost])
			for lane in player_lanes:
				lane.set_highlight(true, true)
				if arena_3d:
					arena_3d.set_lane_highlight(true, lane.lane_index, true)
	elif card_type == "BUILDING":
		log_message("Selected %s (Building, Cost: %d MP). Click an empty building slot to construct." % [card_name, cost])
		for lane in player_lanes:
			var check = lane.can_accept_building(card_data)
			lane.set_highlight(check.allowed, check.allowed)
			if arena_3d:
				arena_3d.set_lane_highlight(true, lane.lane_index, check.allowed)
	else:
		log_message("Selected %s (%s, Cost: %d MP). Click an empty lane to summon." % [card_name, faction, cost])
		for lane in player_lanes:
			if not lane.has_creature:
				var check = lane.can_accept_creature(card_data)
				lane.set_highlight(true, check.allowed)
				if arena_3d:
					var hcol := Color(0.98, 0.88, 0.15, 0.50) if check.allowed else Color(0.88, 0.20, 0.20, 0.42)
					arena_3d.set_lane_highlight(true, lane.lane_index, true, hcol)

func _deselect_card() -> void:
	if selected_card_view:
		selected_card_view.modulate = Color.WHITE
		selected_card_view = null
	for lane in player_lanes:
		lane.set_highlight(false)
	for lane in opponent_lanes:
		lane.set_highlight(false)
	if arena_3d:
		arena_3d.clear_all_highlights()

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
		if arena_3d:
			arena_3d.spawn_lane_building(true, lane.lane_index, card_data, true)
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
	if arena_3d:
		arena_3d.spawn_lane_creature(true, lane.lane_index, card_data, true)
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
	_execute_floop_confirmed(lane)


func _prompt_floop_confirmation(lane: LaneSlot) -> void:
	if not is_action_allowed() or lane == null or not lane.has_creature or lane.is_flooped:
		return

	var data = lane.creature_data
	var floop_cost := int(data.get("floop_cost", 0))

	if player_mp < floop_cost:
		log_message("Not enough MP to Floop! (Need %d MP)" % floop_cost)
		return

	if battle_modals:
		_pending_confirm_mode = "floop"
		_pending_confirm_lane = lane
		if footer_bar:
			footer_bar.visible = false
		if battle_log_box:
			battle_log_box.visible = false
		if arena_3d:
			arena_3d.focus_lane_zoom(lane.is_player, lane.lane_index, 0.35)
		battle_modals.show_ability_confirmation(
			str(data.get("name", "Creature")),
			str(data.get("desc", "")),
			str(data.get("texture_path", "")),
			floop_cost,
			"Floop the\n%s?" % str(data.get("name", "Creature")),
			"Floop Ability"
		)
	else:
		_execute_floop_confirmed(lane)

func _execute_floop_confirmed(lane: LaneSlot) -> void:
	if lane == null or not lane.has_creature or lane.is_flooped:
		return
	var data = lane.creature_data
	var floop_cost := int(data.get("floop_cost", 0))
	if player_mp < floop_cost:
		log_message("Not enough MP to Floop! (Need %d MP)" % floop_cost)
		return

	player_mp -= floop_cost
	match_floops_used += 1
	match_total_mp_spent += floop_cost
	lane.set_flooped(true)
	if arena_3d:
		arena_3d.set_lane_flooped(lane.is_player, lane.lane_index, true, true)
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
	if battle_modals:
		var leader := Database.get_leader(char_id)
		var hero_name := str(leader.get("name", char_id))
		var p_tex := "res://assets/textures/leaders/%s.png" % char_id
		if not ResourceLoader.exists(p_tex):
			p_tex = "res://assets/textures/leaders/%s.png" % GameManager.player_hero_name
		_pending_confirm_mode = "leader"
		_pending_confirm_leader = char_id
		if footer_bar:
			footer_bar.visible = false
		if battle_log_box:
			battle_log_box.visible = false
		battle_modals.show_ability_confirmation(
			hero_name,
			str(leader.get("desc", "Activate Hero Power!")),
			p_tex,
			0,
			"Activate?",
			"Hero Ability"
		)
	else:
		_confirm_leader_power(char_id)

func _confirm_leader_power(char_id: String) -> void:
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

func _has_playable_hand_card() -> bool:
	for c in hand_container.get_children():
		if c is CardView and int(c.card_data.get("cost", 99)) <= player_mp:
			return true
	return false

func _on_turn_button_pressed() -> void:
	if not is_action_allowed():
		return
	_deselect_card()
	if _game_turn_count > 1 and player_mp > 0 and _has_playable_hand_card() and battle_modals:
		battle_modals.open_unused_magic_warning()
		return
	execute_battle_phase()

func execute_battle_phase() -> void:
	is_player_turn = false
	turn_btn.disabled = true

	# Original Card Wars rule: Turn 1 (first player's opening turn) skips combat phase
	if _game_turn_count <= 1:
		log_message("Turn 1 complete — passing turn!")
		if ability_system:
			ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_END)
		if phase_manager != null:
			phase_manager.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
			phase_manager.transition_to(BattlePhaseManager.Phase.END_TURN)
		_advance_turn_counter(0)
		var timer1 = get_tree().create_timer(0.8)
		await timer1.timeout
		execute_opponent_turn()
		return

	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.BATTLE_WHEEL_PHASE)
	_set_battle_phase_hud(true)
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

		if arena_3d:
			arena_3d.focus_duel_lane(i, true, 0.36)
			await get_tree().create_timer(0.28).timeout

		var attacker_name = p_lane.creature_data.get("name", "Creature")
		var atk = p_lane.current_atk
		var o_lane = opponent_lanes[i]
		var target_name = o_lane.creature_data.get("name", "Creature") if o_lane.has_creature else GameManager.opponent_hero_name

		# Trigger Card Wars Battle Wheel (leader & quest hit/crit params)
		wheel_modal.start_attack_clash(
			attacker_name,
			target_name,
			atk,
			true,
			-1.0,
			-1.0,
			false,
			o_lane.has_creature
		)
		var clash_res = await wheel_modal.clash_resolved
		var final_damage: int = int(clash_res.get("final_damage", atk))

		if phase_manager != null:
			phase_manager.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
			phase_manager.resolve_combat_lane(i, clash_res)

		if clash_res.id == "crit":
			log_message("⚡ CRITICAL HIT! %s dealt 2x damage (%d DMG)!" % [attacker_name, final_damage])
			_spawn_combat_callout("CRIT x2!", Color(0.22, 1.0, 0.32))
		elif clash_res.id == "miss":
			log_message("❌ MISSED! %s's attack missed completely!" % attacker_name)
			_spawn_combat_callout("MISS!", Color(0.98, 0.32, 0.28))
		else:
			log_message("⚔️ HIT! %s dealt %d damage to %s!" % [attacker_name, final_damage, target_name])
			_spawn_combat_callout("ATTACK x1", Color(1.0, 0.90, 0.18))

		if final_damage > 0:
			if arena_3d:
				arena_3d.animate_creature_lunge(true, i)
			await get_tree().create_timer(0.14).timeout
			if o_lane.has_creature:
				var target_creature_name = o_lane.creature_data.get("name", "Creature")
				if arena_3d:
					arena_3d.animate_creature_hit(false, i)
				_spawn_floating_damage(false, i, final_damage)
				var destroyed = o_lane.apply_damage(final_damage)
				if destroyed:
					log_message("Opponent's %s was destroyed!" % target_creature_name)
					if opponent_face_rig:
						opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
					if vo_manager:
						vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.DESTROY_CREATURE, true)
						vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.CREATURE_DESTROYED, false)
			else:
				if arena_3d:
					arena_3d.play_lane_direct_hit_vfx(false, i)
				_spawn_floating_damage(false, i, final_damage)
				opponent_hp = max(0, opponent_hp - final_damage)
				if opponent_face_rig:
					opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
				if vo_manager:
					vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.HERO_DAMAGED, false)
		await get_tree().create_timer(0.32).timeout

		_update_ui()
		if opponent_hp <= 0:
			_set_battle_phase_hud(false)
			end_match(true)
			return

	_set_battle_phase_hud(false)
	if arena_3d:
		arena_3d.focus_setup_board(0.45)

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_END)

	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.END_TURN)

	_advance_turn_counter(0)

	if GameManager and GameManager.is_network_match:
		if GameManager.network_protocol:
			GameManager.network_protocol.send_end_turn()
		turn_btn.disabled = true
		turn_btn.text = ""
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
		turn_btn.tooltip_text = "End Turn [%s]" % rb_glyph


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
					if arena_3d:
						arena_3d.spawn_lane_building(false, slot_idx, c_data, true)
				else:
					o_lane.place_creature(c_data)
					if arena_3d:
						arena_3d.spawn_lane_creature(false, slot_idx, c_data, true)
				log_message("%s played %s on Lane %d!" % [GameManager.remote_player_name, c_data.get("name", "Card"), slot_idx + 1])
				_update_ui()

		TurnActionProtocol.ACTION_FLOOP:
			var slot_idx = int(payload.get("slot_index", 0))
			if slot_idx >= 0 and slot_idx < opponent_lanes.size():
				var o_lane = opponent_lanes[slot_idx]
				if o_lane.has_creature and not o_lane.is_flooped:
					o_lane.set_flooped(true)
					if arena_3d:
						arena_3d.set_lane_flooped(false, slot_idx, true, true)
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
	turn_btn.text = ""
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

	if battle_modals:
		battle_modals.play_turn_banner(false, false)
	elif ResourceLoader.exists("res://assets/audio/sfx/OpponentTurn.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/OpponentTurn.wav"))
	log_message("%s's Turn" % GameManager.opponent_hero_name)

	for lane in player_lanes:
		lane.clear_tombstone()
	for lane in opponent_lanes:
		lane.clear_tombstone()

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_START)

	opponent_mp = _round_magic_cap
	_draw_opponent_card()

	# Decrement Opponent Leader Cooldown
	if opponent_leader_cooldown > 0:
		opponent_leader_cooldown = max(0, opponent_leader_cooldown - 1)
	opponent_leader_btn.update_cooldown(opponent_leader_cooldown)
	_update_ui()

	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.ACTION_PHASE)

	# Wait briefly for Opponent's Turn banner
	await get_tree().create_timer(0.85).timeout

	# If Opponent Leader Ability is ready, trigger it during Action Phase!
	if opponent_leader_cooldown == 0:
		_execute_leader_power(false, opponent_leader_id)

	# AI plays affordable cards from its real hand using opponent_mp budget
	var played_any := true
	while played_any and opponent_mp > 0:
		played_any = false
		for i in range(opponent_hand.size()):
			var c_data: Dictionary = opponent_hand[i]
			var cost := int(c_data.get("cost", 1))
			if cost > opponent_mp:
				continue
			var c_type := str(c_data.get("type", "CREATURE"))
			if c_type == "CREATURE":
				var target_lane: LaneSlot = null
				for o_lane in opponent_lanes:
					if not o_lane.has_creature and o_lane.can_accept_creature(c_data).allowed:
						target_lane = o_lane
						break
				if target_lane != null:
					opponent_hand.remove_at(i)
					opponent_mp -= cost
					target_lane.place_creature(c_data)
					if arena_3d:
						arena_3d.spawn_lane_creature(false, target_lane.lane_index, c_data, true)
					log_message("%s summoned %s on Lane %d!" % [
						GameManager.opponent_hero_name, c_data.get("name", "Creature"), target_lane.lane_index + 1
					])
					if opponent_face_rig:
						opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.PLAY_CARD)
					if vo_manager:
						vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.PLAY_CREATURE, false)
					if ability_system:
						ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_SUMMON, target_lane)
					_update_ui()
					played_any = true
					await get_tree().create_timer(0.35).timeout
					break
			elif c_type == "BUILDING":
				var target_lane: LaneSlot = null
				for o_lane in opponent_lanes:
					if not o_lane.has_building and o_lane.can_accept_building(c_data).allowed:
						target_lane = o_lane
						break
				if target_lane != null:
					opponent_hand.remove_at(i)
					opponent_mp -= cost
					target_lane.place_building(c_data)
					if arena_3d:
						arena_3d.spawn_lane_building(false, target_lane.lane_index, c_data, true)
					log_message("%s constructed %s on Lane %d!" % [
						GameManager.opponent_hero_name, c_data.get("name", "Building"), target_lane.lane_index + 1
					])
					if opponent_face_rig:
						opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.PLAY_CARD)
					if vo_manager:
						vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.PLAY_BUILDING, false)
					_update_ui()
					played_any = true
					await get_tree().create_timer(0.35).timeout
					break
			elif c_type == "SPELL" and spell_resolver != null:
				var check = spell_resolver.can_cast(c_data, opponent_mp, false)
				if check.allowed:
					var target: LaneSlot = null
					if spell_resolver.is_targeted(c_data):
						var targets = spell_resolver.get_valid_lane_targets(c_data, false)
						if targets.is_empty():
							continue
						target = targets[0]
					opponent_hand.remove_at(i)
					opponent_mp -= cost
					var res = spell_resolver.cast_spell(c_data, target, false)
					opponent_discard_pile.append(str(c_data.get("id", "")))
					log_message("%s cast %s! %s" % [
						GameManager.opponent_hero_name, c_data.get("name", "Spell"), res.get("message", "")
					])
					if opponent_face_rig:
						opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.PLAY_CARD)
					if vo_manager:
						vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.PLAY_SPELL, false)
					_update_ui()
					played_any = true
					await get_tree().create_timer(0.35).timeout
					break

	# Turn 1 No-Attack parity
	if _game_turn_count <= 1:
		log_message("%s ended Turn 1!" % GameManager.opponent_hero_name)
		if ability_system:
			ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_END)
		if phase_manager != null:
			phase_manager.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
			phase_manager.transition_to(BattlePhaseManager.Phase.END_TURN)
		_advance_turn_counter(1)
		await get_tree().create_timer(0.6).timeout
		start_player_turn()
		return

	# Opponent attacks
	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.BATTLE_WHEEL_PHASE)
	_set_battle_phase_hud(true)

	for i in range(4):
		var o_lane = opponent_lanes[i]
		if not o_lane.has_creature:
			continue

		if phase_manager != null:
			phase_manager.start_combat_lane(i)

		if ability_system:
			ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_ATTACK, o_lane)

		if arena_3d:
			arena_3d.focus_duel_lane(i, false, 0.36)
			await get_tree().create_timer(0.28).timeout

		var attacker_name = o_lane.creature_data.get("name", "Creature")
		var atk = o_lane.current_atk
		var p_lane = player_lanes[i]
		var target_name = p_lane.creature_data.get("name", "Creature") if p_lane.has_creature else GameManager.player_hero_name

		if p_lane.has_creature:
			# Player gets interactive Defend Wheel!
			wheel_modal.start_defend_clash(attacker_name, target_name, atk, p_lane.current_atk, false)
			var clash_res = await wheel_modal.clash_resolved
			var final_damage: int = int(clash_res.get("final_damage", atk))
			var counter_damage: int = int(clash_res.get("counter_damage", 0))

			if phase_manager != null:
				phase_manager.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
				phase_manager.resolve_combat_lane(i, clash_res)

			if bool(clash_res.get("is_counter", false)):
				_spawn_combat_callout("COUNTER!", Color(0.18, 0.98, 0.35))
				log_message("⚡ COUNTER! %s blocked and struck back for %d DMG!" % [target_name, counter_damage])
				if arena_3d:
					arena_3d.animate_creature_lunge(true, i)
				await get_tree().create_timer(0.14).timeout
				if counter_damage > 0:
					if arena_3d:
						arena_3d.animate_creature_hit(false, i)
					_spawn_floating_damage(false, i, counter_damage)
					var o_dead = o_lane.apply_damage(counter_damage)
					if o_dead and opponent_face_rig:
						opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
			elif bool(clash_res.get("is_blocked", false)):
				_spawn_combat_callout("BLOCK!", Color(0.32, 0.88, 1.0))
				log_message("🛡️ BLOCKED! %s blocked %s's attack!" % [target_name, attacker_name])
			else:
				_spawn_combat_callout("ATTACK x1", Color(1.0, 0.88, 0.22))
				log_message("⚔️ HIT! %s dealt %d damage to %s!" % [attacker_name, final_damage, target_name])
				if arena_3d:
					arena_3d.animate_creature_lunge(false, i)
				await get_tree().create_timer(0.14).timeout
				if arena_3d:
					arena_3d.animate_creature_hit(true, i)
				_spawn_floating_damage(true, i, final_damage)
				var destroyed = p_lane.apply_damage(final_damage)
				if destroyed:
					log_message("Your %s was destroyed!" % target_name)
					if player_face_rig:
						player_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
					if vo_manager:
						vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.DESTROY_CREATURE, false)
						vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.CREATURE_DESTROYED, true)
		else:
			# Undefended Player lane -> direct Hero damage + Jake warning banner (Screenshot 10)
			if phase_manager != null:
				phase_manager.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
			_show_undefended_warning()
			if arena_3d:
				arena_3d.animate_creature_lunge(false, i)
				arena_3d.play_lane_direct_hit_vfx(true, i)
			if ResourceLoader.exists("res://assets/audio/sfx/Ring_Hit.wav"):
				Audio.play_sfx_with_variation(load("res://assets/audio/sfx/Ring_Hit.wav"))
			await get_tree().create_timer(0.15).timeout
			_spawn_floating_damage(true, i, atk)
			player_hp = max(0, player_hp - atk)
			match_player_hp_lost += atk
			if player_face_rig:
				player_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
			if vo_manager:
				vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.HERO_DAMAGED, true)
			log_message("💥 %s attacked undefended Hero for %d damage!" % [attacker_name, atk])
			await get_tree().create_timer(0.60).timeout

		await get_tree().create_timer(0.32).timeout
		_update_ui()
		if player_hp <= 0:
			_set_battle_phase_hud(false)
			end_match(false)
			return

	_set_battle_phase_hud(false)
	if arena_3d:
		arena_3d.focus_setup_board(0.45)

	if ability_system:
		ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_END)

	if phase_manager != null:
		phase_manager.transition_to(BattlePhaseManager.Phase.END_TURN)

	_advance_turn_counter(1)

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
	if _match_ended:
		return
	_match_ended = true
	_set_battle_phase_hud(true)
	if board_click_surface:
		board_click_surface.visible = false
	if creature_stats_layer:
		creature_stats_layer.visible = false

	if jukebox:
		jukebox.play_battle_end_theme()
	if arena_3d:
		arena_3d.play_ko_slump(not victory)
		arena_3d.focus_ko_camera(not victory, 0.25)
	_spawn_combat_callout("K.O.", Color(1.0, 0.78, 0.14))

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
			var is_dungeon := str(quest.get("type", "")) == "dungeon"
			var q_res = GameManager.complete_dungeon_quest(qid, match_stats) if is_dungeon else GameManager.complete_campaign_quest(qid, match_stats)
			if q_res.get("ok", false):
				var q_rew = q_res.get("rewards", {})
				rewards_dict["coins"] += int(q_rew.get("coins", 0))
				rewards_dict["xp"] += int(q_rew.get("xp", 0))
				for c in q_rew.get("cards", []):
					rewards_dict["cards"].append(c)
				var new_lvl = GameManager.get_hero_level(GameManager.player_hero_name)
				if new_lvl > prev_lvl:
					rewards_dict["leveled_up"] = true

	await get_tree().create_timer(1.15).timeout
	_set_gameplay_hud_visible(false)

	if result_modal:
		result_modal.display_result(victory, qid, match_stats, rewards_dict, audit_report)
	else:
		dialog_panel.visible = true
		if victory:
			dialog_label.text = "🏆 VICTORY! 🏆\nYou are crowned a Cool Guy!\n💰 Gold: +%d" % rewards_dict["coins"]
		else:
			dialog_label.text = "💀 DEFEAT! 💀\nYou drank from the Dweeb Cup!"


func _on_retry_match_pressed() -> void:
	if get_tree():
		get_tree().reload_current_scene()


func _on_creature_destroyed(lane: LaneSlot, dead_data: Dictionary) -> void:
	if arena_3d:
		arena_3d.spawn_lane_creature(lane.is_player, lane.lane_index, {}, false)
	var creature_name = dead_data.get("name", "Creature")
	if not lane.is_player:
		match_enemy_creatures_defeated += 1
		if ResourceLoader.exists("res://assets/audio/sfx/CreatureDeath.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/CreatureDeath.wav"), -4.0)
		var q_max_drops := 99
		if GameManager and GameManager.active_quest_id != "" and Database:
			q_max_drops = int(Database.get_quest(GameManager.active_quest_id).get("max_loot_drops", 99))
		var candidate_cards = GameManager.opponent_deck
		var drop = LootRoller.roll_drop(drop_profile_id, loot_drops_count, candidate_cards)
		if drop.type == "CARD" and session_loot_cards.size() >= q_max_drops:
			drop = {"type": "GOLD", "amount": 25}
		if drop.type == "CARD":
			loot_drops_count += 1
			session_loot_cards.append(str(drop.get("card_id", "")))
			_spawn_loot_fly_to_counter(false, lane.lane_index, true)
			log_message("🎁 Opponent's %s dropped a Card Chest!" % creature_name)
		elif drop.type == "GOLD":
			var gold_amt := int(drop.get("amount", 15))
			session_gold += gold_amt
			_spawn_loot_fly_to_counter(false, lane.lane_index, false)
			log_message("💰 Opponent's %s dropped +%d Coins!" % [creature_name, gold_amt])
		else:
			log_message("🪦 Opponent's %s was destroyed!" % creature_name)
		lane.spawn_tombstone(drop)
		if arena_3d:
			arena_3d.spawn_lane_drop_prop(false, lane.lane_index, drop.type)
		_update_ui()
	else:
		match_player_creatures_lost += 1
		if ResourceLoader.exists("res://assets/audio/sfx/CreatureDeath.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/CreatureDeath.wav"), -4.0)
		if arena_3d:
			arena_3d.spawn_lane_drop_prop(true, lane.lane_index, "TOMBSTONE")
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

func _draw_opponent_card() -> void:
	if opponent_draw_pile.is_empty():
		var q_id := GameManager.active_quest_id if GameManager else ""
		var ai_reshuffle := bool(Database.get_quest(q_id).get("ai_reshuffle", false)) if (q_id != "" and Database) else false
		if ai_reshuffle and not opponent_discard_pile.is_empty():
			opponent_draw_pile = opponent_discard_pile.duplicate()
			opponent_discard_pile.clear()
			opponent_draw_pile.shuffle()
	if opponent_draw_pile.is_empty():
		return
	var c_id: String = str(opponent_draw_pile.pop_back())
	var c_data := Database.get_card(c_id)
	if not c_data.is_empty():
		opponent_hand.append(c_data)

func _advance_turn_counter(ending_player_idx: int) -> void:
	_game_turn_count += 1
	var next_player_idx := 1 - ending_player_idx
	if _game_turn_count >= 3 and next_player_idx == _first_player_idx:
		_round_magic_cap = mini(10, _round_magic_cap + 1)

func _on_quest_quick_pressed() -> void:
	if not battle_modals:
		return
	var qid := GameManager.active_quest_id if GameManager else ""
	battle_modals.open_current_quest(qid, get_match_stats(true))

func _on_pause_quick_pressed() -> void:
	if battle_modals:
		battle_modals.open_leave_battle()

func _on_discard_pile_pressed() -> void:
	if battle_modals:
		battle_modals.open_discard_pile(player_discard_pile, "Player's Discard Pile")

func log_message(text: String) -> void:
	if log_label:
		log_label.text = text

func _update_ui() -> void:
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp
	player_hp_label.text = str(player_hp)

	opponent_hp_bar.max_value = opponent_max_hp
	opponent_hp_bar.value = opponent_hp
	opponent_hp_label.text = str(opponent_hp)

	if player_mp_label:
		player_mp_label.text = str(player_mp)
	if opponent_mp_label:
		opponent_mp_label.text = str(opponent_mp)
	if magic_orb_label:
		magic_orb_label.text = str(player_mp)
	if draw_count_label:
		draw_count_label.text = str(player_draw_pile.size())
	if discard_count_label:
		discard_count_label.text = str(player_discard_pile.size())
	if loot_count_label:
		loot_count_label.text = str(loot_drops_count)
	if coins_count_label:
		coins_count_label.text = str(session_gold)

func _on_menu_button_pressed() -> void:
	GameManager.return_to_menu()


func _process(_delta: float) -> void:
	_update_creature_stat_badges()


func _build_creature_stat_badges() -> void:
	_stat_badges.clear()
	if creature_stats_layer == null:
		return
	for c in creature_stats_layer.get_children():
		c.queue_free()

	for is_player in [true, false]:
		for i in range(4):
			var root := Control.new()
			root.name = "Badge_%s_%d" % ["P" if is_player else "O", i]
			root.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.visible = false
			creature_stats_layer.add_child(root)

			var atk_lbl := Label.new()
			atk_lbl.position = Vector2(-42, -21)
			atk_lbl.size = Vector2(28, 26)
			atk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			atk_lbl.add_theme_font_override("font", FONT_BATTLE_HUD)
			atk_lbl.add_theme_font_size_override("font_size", 22)
			atk_lbl.add_theme_color_override("font_color", Color.WHITE)
			atk_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			atk_lbl.add_theme_constant_override("outline_size", 5)
			root.add_child(atk_lbl)

			var hp_lbl := Label.new()
			hp_lbl.position = Vector2(-12, -24)
			hp_lbl.size = Vector2(64, 16)
			hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hp_lbl.add_theme_font_override("font", FONT_BATTLE_HUD)
			hp_lbl.add_theme_font_size_override("font_size", 14)
			hp_lbl.add_theme_color_override("font_color", Color.WHITE)
			hp_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			hp_lbl.add_theme_constant_override("outline_size", 4)
			root.add_child(hp_lbl)

			var bar := Control.new()
			bar.position = Vector2(-12, -7)
			bar.size = Vector2(64, 7)
			bar.custom_minimum_size = Vector2(64, 7)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(bar)

			var bar_bg := NinePatchRect.new()
			bar_bg.texture = TEX_CREATURE_HP_BG
			bar_bg.patch_margin_left = 2
			bar_bg.patch_margin_top = 2
			bar_bg.patch_margin_right = 2
			bar_bg.patch_margin_bottom = 2
			bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.add_child(bar_bg)

			var bar_fill := TextureRect.new()
			bar_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bar_fill.stretch_mode = TextureRect.STRETCH_SCALE
			bar_fill.texture = TEX_CREATURE_HP_FILL
			bar_fill.position = Vector2(1, 1)
			bar_fill.size = Vector2(62, 5)
			bar_fill.modulate = Color(0.95, 0.72, 0.14, 1.0)
			bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.add_child(bar_fill)

			var arrow_rect := TextureRect.new()
			arrow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			arrow_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			arrow_rect.custom_minimum_size = Vector2(14, 18)
			arrow_rect.position = Vector2(-56, -18)
			arrow_rect.size = Vector2(14, 18)
			arrow_rect.texture = TEX_CREATURE_ARROW
			arrow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arrow_rect.visible = false
			root.add_child(arrow_rect)

			_stat_badges.append({
				"is_player": is_player,
				"lane_idx": i,
				"root": root,
				"atk": atk_lbl,
				"hp": hp_lbl,
				"bar_fill": bar_fill,
				"arrow": arrow_rect,
			})


func _update_creature_stat_badges() -> void:
	if creature_stats_layer == null or not creature_stats_layer.visible or arena_3d == null:
		for b in _stat_badges:
			(b["root"] as Control).visible = false
		return
	var c_size := creature_stats_layer.size
	if c_size.x <= 1.0:
		c_size = Vector2(1280, 720)
	var hide_for_modal := battle_modals != null and battle_modals.is_any_modal_open()
	for b in _stat_badges:
		var is_p: bool = b["is_player"]
		var idx: int = b["lane_idx"]
		var lanes := player_lanes if is_p else opponent_lanes
		var root := b["root"] as Control
		if hide_for_modal or idx >= lanes.size() or not lanes[idx].has_creature:
			root.visible = false
			continue
		var lane := lanes[idx]
		var spos := arena_3d.get_creature_head_screen_pos(is_p, idx, c_size)
		if spos.x < -1000.0:
			root.visible = false
			continue
		root.visible = true
		root.position = spos
		var lane_max_def: int = maxi(lane.current_def, int(lane.creature_data.get("def", lane.current_def)))
		(b["atk"] as Label).text = str(lane.current_atk)
		(b["hp"] as Label).text = "%d/%d" % [lane.current_def, lane_max_def]
		var pct := clampf(float(lane.current_def) / maxf(1.0, float(lane_max_def)), 0.0, 1.0)
		var bar_fill := b["bar_fill"] as TextureRect
		bar_fill.size = Vector2(roundf(62.0 * pct), 5.0)
		bar_fill.modulate = Color(0.95, 0.72, 0.14) if pct > 0.5 else Color(0.92, 0.24, 0.16)
		var base_atk := int(lane.creature_data.get("atk", lane.current_atk))
		var atk_lbl := b["atk"] as Label
		var arrow_rect := b["arrow"] as TextureRect
		var diff := lane.current_atk - base_atk
		if diff > 0:
			arrow_rect.visible = true
			arrow_rect.flip_v = false
			arrow_rect.modulate = Color(1.0, 0.38, 0.72)
			atk_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.76))
		elif diff < 0:
			arrow_rect.visible = true
			arrow_rect.flip_v = true
			arrow_rect.modulate = Color(0.32, 0.65, 1.0)
			atk_lbl.add_theme_color_override("font_color", Color(0.38, 0.70, 1.0))
		else:
			arrow_rect.visible = false
			atk_lbl.add_theme_color_override("font_color", Color.WHITE)


func _on_board_surface_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if arena_3d == null or not board_click_surface.visible:
		return
	if battle_modals and battle_modals.is_any_modal_open():
		return

	var pick := arena_3d.pick_board_at_screen_pos(mb.position, board_click_surface.size)
	if not bool(pick.get("valid", false)):
		if selected_card_view != null:
			_deselect_card()
		elif battle_modals and battle_modals.is_inspection_open():
			battle_modals.dismiss_inspection(true)
		return

	var is_p: bool = bool(pick.get("is_player", true))
	var idx: int = int(pick.get("lane_idx", 0))
	var zone: String = str(pick.get("zone", "lane"))
	var target_lane := player_lanes[idx] if is_p else opponent_lanes[idx]

	if selected_card_view != null:
		_on_lane_clicked(target_lane)
		return

	_inspect_or_floop_lane(target_lane, zone)


func _inspect_or_floop_lane(lane: LaneSlot, zone: String) -> void:
	if lane == null:
		return
	if lane.is_player and zone == "floop" and lane.has_creature and not lane.is_flooped and is_action_allowed():
		_prompt_floop_confirmation(lane)
		return
	if zone == "building" and lane.has_building:
		if footer_bar:
			footer_bar.visible = false
		if arena_3d:
			arena_3d.focus_lane_zoom(lane.is_player, lane.lane_index, 0.40)
		if battle_modals:
			battle_modals.show_card_info(lane.building_data)
		return
	if lane.has_creature:
		if footer_bar:
			footer_bar.visible = false
		var lane_max_def: int = maxi(lane.current_def, int(lane.creature_data.get("def", lane.current_def)))
		if arena_3d:
			arena_3d.focus_lane_zoom(lane.is_player, lane.lane_index, 0.40)
		if battle_modals:
			battle_modals.show_card_info(lane.creature_data, lane.current_atk, lane.current_def, lane_max_def, lane.is_flooped)
		return
	if lane.has_building:
		if footer_bar:
			footer_bar.visible = false
		if arena_3d:
			arena_3d.focus_lane_zoom(lane.is_player, lane.lane_index, 0.40)
		if battle_modals:
			battle_modals.show_card_info(lane.building_data)


func _restore_hud_after_inspect() -> void:
	if footer_bar:
		footer_bar.visible = true
	if battle_log_box:
		battle_log_box.visible = true
	if arena_3d:
		arena_3d.focus_setup_board(0.35)


func _on_ability_confirmed() -> void:
	var mode := _pending_confirm_mode
	var lane := _pending_confirm_lane
	var l_id := _pending_confirm_leader
	_pending_confirm_mode = ""
	_pending_confirm_lane = null
	_pending_confirm_leader = ""
	_restore_hud_after_inspect()
	if mode == "floop" and lane != null:
		_execute_floop_confirmed(lane)
	elif mode == "leader" and l_id != "":
		_confirm_leader_power(l_id)


func _on_ability_cancelled() -> void:
	_pending_confirm_mode = ""
	_pending_confirm_lane = null
	_pending_confirm_leader = ""
	_restore_hud_after_inspect()


func _on_info_dismissed() -> void:
	if _pending_confirm_mode == "":
		_restore_hud_after_inspect()


func _set_battle_phase_hud(active_combat: bool) -> void:
	if footer_bar:
		footer_bar.visible = not active_combat
	if turn_btn:
		turn_btn.visible = not active_combat
	if quest_quick_btn:
		quest_quick_btn.visible = not active_combat
	if pause_quick_btn:
		pause_quick_btn.visible = not active_combat
	if battle_log_box:
		battle_log_box.visible = not active_combat


func _spawn_combat_callout(text: String, col: Color = Color(1.0, 0.90, 0.22)) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.anchor_left = 0.5
	lbl.anchor_right = 0.5
	lbl.anchor_top = 0.5
	lbl.anchor_bottom = 0.5
	lbl.offset_left = -280
	lbl.offset_right = 280
	lbl.offset_top = -60
	lbl.offset_bottom = 30
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", FONT_BATTLE_HUD)
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	lbl.add_theme_constant_override("outline_size", 10)
	lbl.rotation_degrees = -4.0
	lbl.scale = Vector2(0.35, 0.35)
	add_child(lbl)
	lbl.pivot_offset = Vector2(280, 45)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.08, 1.08), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.08)
	tw.tween_interval(0.35)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.22)
	tw.tween_callback(lbl.queue_free)


func _spawn_floating_damage(is_player_target: bool, lane_idx: int, dmg: int) -> void:
	if dmg <= 0:
		return
	var spos := size * 0.5
	if arena_3d:
		spos = arena_3d.get_lane_screen_pos(is_player_target, lane_idx, size)
	var lbl := Label.new()
	lbl.text = str(dmg)
	lbl.position = spos - Vector2(24, 30)
	lbl.size = Vector2(60, 44)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", FONT_BATTLE_HUD)
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", Color(0.98, 0.16, 0.14))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 7)
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 54.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.65).set_delay(0.20)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)


func _show_undefended_warning() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = 18
	panel.offset_bottom = 112
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_FLOOP_PANEL_BG
	sb.texture_margin_left = 20.0
	sb.texture_margin_top = 20.0
	sb.texture_margin_right = 20.0
	sb.texture_margin_bottom = 20.0
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "Whoah, man! You didn't have any creatures defending your lane so your Hero took some damage."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FONT_BATTLE_HUD)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	panel.add_child(lbl)
	add_child(panel)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(panel, "modulate:a", 0.0, 0.25)
	tw.tween_callback(panel.queue_free)


func _spawn_loot_fly_to_counter(is_player_lane: bool, lane_idx: int, is_chest: bool) -> void:
	var start_pos := size * 0.5
	if arena_3d:
		start_pos = arena_3d.get_lane_screen_pos(is_player_lane, lane_idx, size)
	var tex_path := "res://assets/textures/battle/hud/IconLoot.png" if is_chest else "res://assets/textures/battle/hud/HUD_Coins.png"
	if not ResourceLoader.exists(tex_path):
		return
	var icon := TextureRect.new()
	icon.texture = load(tex_path)
	icon.custom_minimum_size = Vector2(42, 42)
	icon.size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = start_pos - Vector2(21, 21)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	var target_pos := Vector2(40, size.y - 175)
	var tw := create_tween()
	tw.tween_property(icon, "position", target_pos, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(icon.queue_free)
