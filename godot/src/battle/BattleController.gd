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
const TEX_FX_SMOKE: Texture2D = preload("res://assets/textures/battle/fx/FX_Smoke_Grey_PNG.png")
const TEX_FX_BUBBLES: Texture2D = preload("res://assets/textures/battle/fx/FX_Bubbles2x2_PNG.png")
const TEX_FX_FLARE: Texture2D = preload("res://assets/textures/battle/fx/Flare1_PNG.png")
const TEX_FX_GLOW: Texture2D = preload("res://assets/textures/battle/fx/FX_Glow_ball3_grey_TGA.png")
const TEX_FX_SKULL: Texture2D = preload("res://assets/textures/battle/fx/FX_Skull2_PNG.png")
const TEX_FX_STARBURST: Texture2D = preload("res://assets/textures/battle/fx/FX_StarBurst4_PNG.png")
const TEX_BATTLE_FLASH: Texture2D = preload("res://assets/textures/battle/hud/Battle_Flash.png")
const TEX_BATTLE_SHIELD: Texture2D = preload("res://assets/textures/battle/hud/Battle_Shield.png")
const TEX_BOTTLE_FULL: Texture2D = preload("res://assets/textures/battle/hud/Bottle_Full.png")
const SHADER_MAGIC_ORB_LIQUID: Shader = preload("res://assets/shaders/magic_orb_liquid.gdshader")
const SFX_DAMAGE_BURST_PATH := "res://assets/audio/sfx/SFX_DamageBurst.wav"
const SFX_BATTLE_DAMAGE_HIT_PATH := "res://assets/audio/sfx/FX_BattleRing_Damage_Hit.wav"
const SFX_BATTLE_DAMAGE_CRIT_PATH := "res://assets/audio/sfx/FX_BattleRing_Damage_Crit.wav"
const SFX_BATTLE_DAMAGE_BLOCK_PATH := "res://assets/audio/sfx/FX_BattleRing_Damage_Block.wav"

@onready var opponent_hp_damage_bar: ProgressBar = $Header/OpponentInfo/HBox/StatsCol/HpDamageBar
@onready var opponent_hp_bar: ProgressBar = $Header/OpponentInfo/HBox/StatsCol/HpBar
@onready var opponent_hp_label: Label = $Header/OpponentInfo/HBox/StatsCol/HpBar/HpLabel
@onready var opponent_name_label: Label = $Header/OpponentInfo/HBox/StatsCol/NameLabel
@onready var opponent_mp_label: Label = $Header/OpponentInfo/HBox/StatsCol/OppMpLabel
@onready var opponent_leader_btn: LeaderPowerButton = $Header/OpponentInfo/HBox/PortraitCol/OpponentLeaderPower
@onready var opponent_face_rig: CharacterFaceRig = $Header/OpponentInfo/HBox/PortraitCol/OpponentFaceRig
@onready var opponent_mp_orb_bar: TextureProgressBar = $Header/OpponentInfo/HBox/PortraitCol/OppMpOrbIcon

@onready var player_hp_damage_bar: ProgressBar = $Header/PlayerCornerHud/HBox/StatsCol/HpDamageBar
@onready var player_hp_bar: ProgressBar = $Header/PlayerCornerHud/HBox/StatsCol/HpBar
@onready var player_hp_label: Label = $Header/PlayerCornerHud/HBox/StatsCol/HpBar/HpLabel
@onready var player_name_label: Label = $Header/PlayerCornerHud/HBox/StatsCol/NameLabel
@onready var player_leader_btn: LeaderPowerButton = $Header/PlayerCornerHud/HBox/PortraitCol/PlayerLeaderPower
@onready var player_face_rig: CharacterFaceRig = $Header/PlayerCornerHud/HBox/PortraitCol/PlayerFaceRig
@onready var player_mp_label: Label = $Header/PlayerCornerHud/HBox/StatsCol/MpLabel
@onready var player_mp_orb_bar: TextureProgressBar = $Header/PlayerCornerHud/HBox/PortraitCol/MpOrbIcon

@onready var opponent_lanes_box: HBoxContainer = $Field/OpponentLanes
@onready var player_lanes_box: HBoxContainer = $Field/PlayerLanes
@onready var hand_container: Control = $Footer/HandContainer

@onready var magic_orb_bar: TextureProgressBar = $Footer/MagicOrb
@onready var magic_orb_label: Label = $Footer/RightControls/MagicOrbLabel
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

const MP_LABEL_OPTICAL_DX := {
	"0": -0.5,
	"1": -2.0,
	"2": -1.2,
	"3": -1.5,
	"4": -1.0,
	"5": -1.0,
	"6": -0.5,
	"7": -1.0,
	"8": 0.0,
	"9": -1.0,
}

var _stat_badges: Array[Dictionary] = []
var _mp_label_base_x: Dictionary = {}
var _pending_confirm_mode: String = ""
var _pending_confirm_lane: LaneSlot = null
var _pending_confirm_leader: String = ""
var _in_battle_phase_hud: bool = false
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
var _prev_player_mp: int = -1
var _prev_opponent_mp: int = -1
var _mp_bar_tweens: Dictionary = {}
var _mp_liquid_mats: Dictionary = {}
var _mp_slosh_tweens: Dictionary = {}
var _already_summoned_cards: Dictionary = {}
var _is_summon_cinematic_active: bool = false
var _hp_anim_state: Dictionary = {
	"player": {"prev": -1.0, "pulse": 0.0, "last": -1},
	"opponent": {"prev": -1.0, "pulse": 0.0, "last": -1},
}

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
		battle_log_box.visible = false
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

	_setup_mp_orb_liquid(player_mp_orb_bar, 0.0)
	_setup_mp_orb_liquid(opponent_mp_orb_bar, 2.1)
	_setup_mp_orb_liquid(magic_orb_bar, 4.2)
	if player_mp_label:
		_mp_label_base_x[player_mp_label.get_instance_id()] = player_mp_label.position.x
	if opponent_mp_label:
		_mp_label_base_x[opponent_mp_label.get_instance_id()] = opponent_mp_label.position.x

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
		arena_3d.update_holding_cards_count(true, hand_container.get_child_count() if hand_container else 0)
		arena_3d.update_holding_cards_count(false, opponent_hand.size())
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

	var p1_disp := GameManager.player_hero_name
	var p2_disp := GameManager.opponent_hero_name
	if Database:
		var p1c := Database.get_character(p1_disp)
		if not p1c.is_empty():
			p1_disp = str(p1c.get("name", p1_disp))
		var p2c := Database.get_character(p2_disp)
		if not p2c.is_empty():
			p2_disp = str(p2c.get("name", p2_disp))
	call_deferred("_begin_battle_intro_after_render", arena_name, p1_disp, p2_disp)


func _begin_battle_intro_after_render(arena_name: String, p1_disp: String, p2_disp: String) -> void:
	if GameManager and GameManager.is_battle_loading_screen_active():
		# Allow the 3D SubViewport to render at least two frames behind the loading artwork
		# before revealing Cut 1 so no empty/unrendered viewport frame appears.
		for _i in range(2):
			if not is_inside_tree():
				return
			await get_tree().process_frame
		GameManager.hide_battle_loading_screen()
	if jukebox:
		jukebox.play_intro_sequence()
	if match_intro.has_method("play_intro"):
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

	if vo_manager:
		vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.OPENING, true)

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
	_reset_hp_anim_state("player", player_hp, player_max_hp, player_hp_bar, player_hp_damage_bar, player_hp_label)
	_reset_hp_anim_state("opponent", opponent_hp, opponent_max_hp, opponent_hp_bar, opponent_hp_damage_bar, opponent_hp_label)

	player_draw_pile = GameManager.player_deck.duplicate()
	player_draw_pile.shuffle()

	opponent_draw_pile = GameManager.opponent_deck.duplicate()
	opponent_draw_pile.shuffle()
	opponent_hand.clear()
	for _i in range(4):
		_draw_opponent_card()

	player_lanes.clear()
	opponent_lanes.clear()
	_prev_player_mp = -1
	_prev_opponent_mp = -1
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
	_already_summoned_cards.clear()
	_is_summon_cinematic_active = false

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
		if not p_lane.building_destroyed.is_connected(_on_building_destroyed):
			p_lane.building_destroyed.connect(_on_building_destroyed)
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
		if not o_lane.building_destroyed.is_connected(_on_building_destroyed):
			o_lane.building_destroyed.connect(_on_building_destroyed)
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
	if _is_summon_cinematic_active:
		return false
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
	_layout_hand_cards()


func _layout_hand_cards() -> void:
	if hand_container == null:
		return
	var cards: Array[Control] = []
	for c in hand_container.get_children():
		if c is Control and not c.is_queued_for_deletion():
			cards.append(c)
	var count := cards.size()
	if count == 0:
		return
	const CARD_SCALE := 1.10
	const CARD_W := 130.0 * CARD_SCALE
	const MAX_STEP := 74.0
	var container_w := hand_container.size.x if hand_container.size.x > 0.0 else 592.0
	var step := MAX_STEP
	if count > 1:
		step = minf(MAX_STEP, maxf(24.0, (container_w - CARD_W) / float(count - 1)))
	var selected_idx := -1
	for i in range(count):
		var card := cards[i]
		card.pivot_offset = Vector2.ZERO
		card.scale = Vector2(CARD_SCALE, CARD_SCALE)
		card.position = Vector2(float(i) * step, 1.0)
		card.z_index = i
		if card == selected_card_view:
			selected_idx = i
	if selected_idx >= 0:
		var sel := cards[selected_idx]
		sel.position.y = -14.0
		sel.z_index = count + 4


func _consume_selected_hand_card() -> void:
	var to_free := selected_card_view
	_deselect_card()
	if to_free:
		if to_free.get_parent() == hand_container:
			hand_container.remove_child(to_free)
		to_free.queue_free()
	_layout_hand_cards()

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
	_layout_hand_cards()
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
	_layout_hand_cards()
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

		_consume_selected_hand_card()
		_update_ui()
		await _run_summon_presentation(true, lane.lane_index, card_data, true, lane.has_creature)
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
	_consume_selected_hand_card()
	_update_ui()
	await _run_summon_presentation(true, lane.lane_index, card_data, false, lane.has_building)


func _run_summon_presentation(is_player: bool, lane_idx: int, card_data: Dictionary, is_building: bool, trigger_building_fx: bool = false) -> void:
	if arena_3d == null or card_data.is_empty():
		return
	var cid := str(card_data.get("id", card_data.get("object_name", "")))
	var first_time := not _already_summoned_cards.has(cid)
	if first_time:
		_already_summoned_cards[cid] = true
		_is_summon_cinematic_active = true
		_sync_floop_buttons_visual_state()
		arena_3d.focus_summon_camera(is_player, lane_idx, is_building, 0.50)
		var mesh_info: Dictionary = Database.get_entity_mesh_info(card_data) if Database else {}
		var intro_len := float(mesh_info.get("intro_length", 2.0 if is_building else 1.5))
		var rez_delay := 0.75 if is_building else 1.0
		var wait_dur := clampf(rez_delay + intro_len + 0.15, 2.50, 3.25)
		await get_tree().create_timer(wait_dur).timeout
		if not is_inside_tree():
			_is_summon_cinematic_active = false
			return
		if trigger_building_fx and arena_3d:
			arena_3d.play_entity_floop(is_player, lane_idx, true)
		if arena_3d:
			arena_3d.focus_setup_board(0.45)
		_is_summon_cinematic_active = false
		_sync_floop_buttons_visual_state()
	elif trigger_building_fx:
		var t_b := get_tree().create_timer(0.40)
		t_b.timeout.connect(func():
			if is_inside_tree() and arena_3d:
				arena_3d.play_entity_floop(is_player, lane_idx, true)
		)

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
	_consume_selected_hand_card()
	_update_ui()
	return true

func _on_floop_requested(lane: LaneSlot) -> void:
	if not is_action_allowed() or not lane.has_creature or lane.is_flooped:
		return
	_prompt_floop_confirmation(lane)


func _prompt_floop_confirmation(lane: LaneSlot) -> void:
	if not is_action_allowed() or lane == null or not lane.has_creature or lane.is_flooped:
		return

	var data = lane.creature_data
	var floop_cost := int(data.get("floop_cost", 0))

	if floop_cost <= 0 or player_mp < floop_cost:
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
			# Matches Unity FLOOPButton OnClick: PushFloop() + FX_Battle_FloopButton_Action + ToFloopPanel (0.3s)
			arena_3d.set_lane_floop_button_state(lane.is_player, lane.lane_index, true, false, false)
			arena_3d.play_floop_button_action_fx(lane.is_player, lane.lane_index)
			arena_3d.focus_floop_panel(lane.is_player, lane.lane_index, 0.30)
		var short_name := str(data.get("short_hand", "")).strip_edges()
		if short_name == "":
			short_name = str(data.get("name", "Creature"))
		battle_modals.show_ability_confirmation(
			str(data.get("name", "Creature")),
			str(data.get("desc", "")),
			str(data.get("texture_path", "")),
			floop_cost,
			"Floop the %s?" % short_name,
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

	## Matches Unity CWFloopActionManager.PlayFloopAction() + DoWaitThenTrigger(1f, anim, "Floop"):
	## 1. Q_2_YesNo (bottom confirm bar) closes, while Q_3_FloopDescription (top banner) STAYS VISIBLE!
	## 2. FloopCameraTrigger(target, false) zooms to creature (0.2s).
	## 3. Creature plays "Floop" anim + FX_Battle_FloopAnimation swirl + SFX.
	## 4. After 1.0s wait, GameInstance.FloopCard executes: MP is deducted, ability effect + stat VFX fire,
	##    and after 1.0s FloopCameraDelay the top banner closes, camera returns to ToP1Setup, and footer returns.
	_is_summon_cinematic_active = true
	if footer_bar:
		footer_bar.visible = false
	if arena_3d:
		arena_3d.set_lane_floop_button_state(lane.is_player, lane.lane_index, true, false, false)
		arena_3d.focus_floop_action(lane.is_player, lane.lane_index, false, 0.20, false)
		arena_3d.play_entity_floop(lane.is_player, lane.lane_index, false)
		if lane.has_building:
			arena_3d.play_entity_floop(lane.is_player, lane.lane_index, true)
	if ResourceLoader.exists("res://assets/audio/sfx/FX_Battle_FloopAnimation.wav"):
		Audio.play_sfx_with_variation(load("res://assets/audio/sfx/FX_Battle_FloopAnimation.wav"), -3.0)

	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		_is_summon_cinematic_active = false
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

	_spawn_floop_ability_vfx_for_lane(lane, data)
	_execute_floop_ability(lane)
	_update_ui()

	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		_is_summon_cinematic_active = false
		return
	_is_summon_cinematic_active = false
	if battle_modals:
		battle_modals.dismiss_inspection(false)
	_restore_hud_after_inspect()
	_sync_floop_buttons_visual_state()


func _spawn_floop_ability_vfx_for_lane(source_lane: LaneSlot, card_data: Dictionary) -> void:
	if arena_3d == null or source_lane == null:
		return
	var script_name := str(card_data.get("script_name", ""))
	var is_p := source_lane.is_player
	var idx := source_lane.lane_index
	if arena_3d:
		arena_3d.focus_floop_action(is_p, idx, false, 0.20, true)
	if script_name.find("ATKDEFBonus") >= 0:
		arena_3d.play_floop_stat_vfx(is_p, idx, "FX_Battle_AttackUp")
		arena_3d.play_floop_stat_vfx(is_p, idx, "FX_Battle_DefenseUp")
	elif script_name.find("ATKBonus") >= 0 or script_name.find("BonusATK") >= 0:
		arena_3d.play_floop_stat_vfx(is_p, idx, "FX_Battle_AttackUp")
	elif script_name.find("DEFBonus") >= 0 or script_name.find("BonusDEF") >= 0:
		arena_3d.play_floop_stat_vfx(is_p, idx, "FX_Battle_DefenseUp")
	elif script_name.find("Heal") >= 0:
		arena_3d.play_floop_stat_vfx(is_p, idx, "FX_Battle_HealthUp")
	elif script_name.find("LowerATK") >= 0 or script_name.find("ATKPenalty") >= 0:
		var opp_lanes := opponent_lanes if is_p else player_lanes
		if idx < opp_lanes.size() and opp_lanes[idx].has_creature:
			arena_3d.focus_floop_action(not is_p, idx, false, 0.20, true)
			arena_3d.play_floop_stat_vfx(not is_p, idx, "FX_Battle_AttackDown")
		else:
			arena_3d.play_floop_stat_vfx(is_p, idx, "FX_Battle_AttackDown")
	elif script_name.find("LowerDEF") >= 0 or script_name.find("DEFPenalty") >= 0 or script_name.find("ReduceDEF") >= 0:
		var opp_lanes2 := opponent_lanes if is_p else player_lanes
		if idx < opp_lanes2.size() and opp_lanes2[idx].has_creature:
			arena_3d.focus_floop_action(not is_p, idx, false, 0.20, true)
			arena_3d.play_floop_stat_vfx(not is_p, idx, "FX_Battle_DefenseDown")
		else:
			arena_3d.play_floop_stat_vfx(is_p, idx, "FX_Battle_DefenseDown")
	else:
		arena_3d.play_floop_stat_vfx(is_p, idx, "FX_Battle_AttackUp")

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
	_pending_confirm_mode = ""
	_pending_confirm_lane = null
	_pending_confirm_leader = ""
	if battle_modals and battle_modals.is_inspection_open():
		battle_modals.dismiss_inspection(false)
		if arena_3d and not _is_summon_cinematic_active:
			arena_3d.focus_setup_board(0.25)

	# Original Card Wars rule: Turn 1 (first player's opening turn) skips combat phase
	if _game_turn_count <= 1:
		log_message("Turn 1 complete — passing turn!")
		if ability_system:
			ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_END)
		_end_turn_phase()
		_advance_turn_counter(0)
		var timer1 = get_tree().create_timer(0.8)
		await timer1.timeout
		execute_opponent_turn()
		return

	if _has_lane_creature(player_lanes):
		if phase_manager != null:
			phase_manager.transition_to(BattlePhaseManager.Phase.BATTLE_WHEEL_PHASE)
		_set_battle_phase_hud(true)
		log_message("=== BATTLE PHASE! ===")
		if battle_modals:
			await battle_modals.play_battle_banner(true)
		if not is_inside_tree():
			return

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
				var duel_tw: Tween = arena_3d.focus_duel_lane(i, true, 1.0)
				if duel_tw:
					await duel_tw.finished
				else:
					await get_tree().create_timer(1.0).timeout

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

			if clash_res.id == "miss":
				log_message("❌ MISSED! %s's attack missed completely!" % attacker_name)
				if arena_3d:
					arena_3d.animate_creature_lunge(true, i)
				await get_tree().create_timer(0.20).timeout
				if o_lane.has_creature:
					# Unity TweenDamage_P1Missed: 1_P1_Crash -> 2_UI_BlockOnP2 -> 3_P2_Crash -> 4_P2_DealDamage -> 5_P1_CheckForDefeat
					_spawn_battle_fx_prefab("block", false)
					await get_tree().create_timer(0.20).timeout
					if arena_3d:
						arena_3d.animate_creature_lunge(false, i)
					await get_tree().create_timer(0.20).timeout
					var opp_counter_atk: int = maxi(0, o_lane.current_atk)
					_spawn_battle_fx_prefab("crit", true, 2)
					if arena_3d:
						arena_3d.shake_duel_camera(true, 0.50)
					if opp_counter_atk > 0:
						if arena_3d:
							arena_3d.animate_creature_hit(true, i)
						_spawn_floating_damage(true, i, opp_counter_atk)
						var p_dead := p_lane.apply_damage(opp_counter_atk)
						if p_dead and player_face_rig:
							player_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
					await get_tree().create_timer(0.20).timeout
				else:
					# Unity TweenDamage_P1Missed_noCreature: 1_P1_Crash -> 2_UI_MissOnP2
					_spawn_battle_fx_prefab("miss", false)
					await get_tree().create_timer(0.20).timeout
			elif final_damage > 0:
				# Unity TweenDamage_P1Hit / TweenDamage_P1Crit:
				# Step 1 (t=0.0s): 1_P1_Crash -> wait 0.2s -> Step 2 (t=0.2s): 2_P1_DealDamage (CameraShake P2 + FX_BattleFXHit/Crit on TargetP2 + DealDamage) -> wait 0.2s -> Step 3: 3_P2_CheckForDefeat
				if clash_res.id == "crit":
					log_message("⚡ CRITICAL HIT! %s dealt 2x damage (%d DMG)!" % [attacker_name, final_damage])
				else:
					log_message("⚔️ HIT! %s dealt %d damage to %s!" % [attacker_name, final_damage, target_name])
				if arena_3d:
					arena_3d.animate_creature_lunge(true, i)
				await get_tree().create_timer(0.20).timeout
				_spawn_battle_fx_prefab("crit" if clash_res.id == "crit" else "hit", false, 2)
				if arena_3d:
					arena_3d.shake_duel_camera(false, 0.50)
				if o_lane.has_creature:
					var target_creature_name = o_lane.creature_data.get("name", "Creature")
					if arena_3d:
						arena_3d.animate_creature_hit(false, i, clash_res.id == "crit")
					_spawn_floating_damage(false, i, final_damage)
					var destroyed = o_lane.apply_damage(final_damage)
					if destroyed:
						log_message("Opponent's %s was destroyed!" % target_creature_name)
						if opponent_face_rig:
							opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
				else:
					if arena_3d:
						arena_3d.play_lane_direct_hit_vfx(false, i)
					opponent_hp = max(0, opponent_hp - final_damage)
					if opponent_face_rig:
						opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
					if vo_manager:
						vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.HERO_DAMAGED, false)
				await get_tree().create_timer(0.20).timeout
			await get_tree().create_timer(0.50).timeout

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

	_end_turn_phase()

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
						arena_3d.play_entity_floop(false, slot_idx, false)
						if o_lane.has_building:
							arena_3d.play_entity_floop(false, slot_idx, true)
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
	_pending_confirm_mode = ""
	_pending_confirm_lane = null
	_pending_confirm_leader = ""
	if battle_modals and battle_modals.is_inspection_open():
		battle_modals.dismiss_inspection(false)
		if arena_3d and not _is_summon_cinematic_active:
			arena_3d.focus_setup_board(0.25)
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
					await _run_summon_presentation(false, target_lane.lane_index, c_data, false, target_lane.has_building)
					await get_tree().create_timer(0.25).timeout
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
					await _run_summon_presentation(false, target_lane.lane_index, c_data, true, target_lane.has_creature)
					await get_tree().create_timer(0.25).timeout
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
		_end_turn_phase()
		_advance_turn_counter(1)
		await get_tree().create_timer(0.6).timeout
		start_player_turn()
		return

	# Opponent attacks
	if _has_lane_creature(opponent_lanes):
		if phase_manager != null:
			phase_manager.transition_to(BattlePhaseManager.Phase.BATTLE_WHEEL_PHASE)
		_set_battle_phase_hud(true)
		if battle_modals:
			await battle_modals.play_battle_banner(false)
		if not is_inside_tree():
			return

		for j in range(4):
			var i: int = 3 - j
			var o_lane = opponent_lanes[i]
			if not o_lane.has_creature:
				continue

			if phase_manager != null:
				phase_manager.start_combat_lane(i)

			if ability_system:
				ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_ATTACK, o_lane)

			if arena_3d:
				var duel_tw: Tween = arena_3d.focus_duel_lane(i, false, 1.0)
				if duel_tw:
					await duel_tw.finished
				else:
					await get_tree().create_timer(1.0).timeout

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
					# Unity TweenDamage_P2Crit: 1_P2_Crash -> 2_BlockOnP1 -> 3_P1_Crash -> 4_P1_DealDamage -> 5_P2_CheckForDefeat (each step 0.2s)
					log_message("⚡ COUNTER! %s blocked and struck back for %d DMG!" % [target_name, counter_damage])
					if arena_3d:
						arena_3d.animate_creature_lunge(false, i)
					await get_tree().create_timer(0.20).timeout
					_spawn_battle_fx_prefab("block", true)
					await get_tree().create_timer(0.20).timeout
					if arena_3d:
						arena_3d.animate_creature_lunge(true, i)
					await get_tree().create_timer(0.20).timeout
					_spawn_battle_fx_prefab("crit", false, 2)
					if arena_3d:
						arena_3d.shake_duel_camera(false, 0.50)
					if counter_damage > 0:
						if arena_3d:
							arena_3d.animate_creature_hit(false, i)
						_spawn_floating_damage(false, i, counter_damage)
						var o_dead = o_lane.apply_damage(counter_damage)
						if o_dead and opponent_face_rig:
							opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
					await get_tree().create_timer(0.20).timeout
				elif bool(clash_res.get("is_blocked", false)):
					# Unity TweenDamage_P2Hit: 1_P2_Crash -> 2_BlockOnP1
					log_message("🛡️ BLOCKED! %s blocked %s's attack!" % [target_name, attacker_name])
					if arena_3d:
						arena_3d.animate_creature_lunge(false, i)
					await get_tree().create_timer(0.20).timeout
					_spawn_battle_fx_prefab("block", true)
					await get_tree().create_timer(0.20).timeout
				else:
					# Unity TweenDamage_P2Missed: 1_P2_Crash -> 2_P2_DealDamage (CameraShake P1 + FX_BattleFXHit on TargetP1 + DealDamage) -> 3_P1_CheckForDefeat
					log_message("⚔️ HIT! %s dealt %d damage to %s!" % [attacker_name, final_damage, target_name])
					if arena_3d:
						arena_3d.animate_creature_lunge(false, i)
					await get_tree().create_timer(0.20).timeout
					_spawn_battle_fx_prefab("hit", true)
					if arena_3d:
						arena_3d.shake_duel_camera(true, 0.50)
						arena_3d.animate_creature_hit(true, i)
					_spawn_floating_damage(true, i, final_damage)
					var destroyed = p_lane.apply_damage(final_damage)
					if destroyed:
						log_message("Your %s was destroyed!" % target_name)
						if player_face_rig:
							player_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
					await get_tree().create_timer(0.20).timeout
			else:
				# Undefended Player lane: Unity CWBattleSequenceController sets undefendedFlag=true, forceMiss=true -> StopRing (0.5s) -> TweenDamage_P2Missed
				# 1_P2_Crash (t=0.0s) -> wait 0.2s -> 2_P2_DealDamage (CameraShake P1 + FX_BattleFXHit on TargetP1 + DealDamage -> SpawnLandDamageFX + C_P1Damaged) -> wait 0.2s
				wheel_modal.start_undefended_clash(attacker_name, target_name, atk)
				await wheel_modal.clash_resolved
				if phase_manager != null:
					phase_manager.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
				_show_undefended_warning()
				if arena_3d:
					arena_3d.animate_creature_lunge(false, i)
				await get_tree().create_timer(0.20).timeout
				_spawn_battle_fx_prefab("hit", true)
				if arena_3d:
					arena_3d.shake_duel_camera(true, 0.50)
					arena_3d.play_lane_direct_hit_vfx(true, i)
				player_hp = max(0, player_hp - atk)
				match_player_hp_lost += atk
				if player_face_rig:
					player_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
				if vo_manager:
					vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.HERO_DAMAGED, true)
				log_message("💥 %s attacked undefended Hero for %d damage!" % [attacker_name, atk])
				await get_tree().create_timer(0.20).timeout

			await get_tree().create_timer(0.50).timeout
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

	_end_turn_phase()

	_advance_turn_counter(1)

	var timer = get_tree().create_timer(1.0)
	await timer.timeout
	start_player_turn()


func _has_lane_creature(lanes: Array[LaneSlot]) -> bool:
	for l in lanes:
		if l != null and l.has_creature:
			return true
	return false


func _end_turn_phase() -> void:
	## Ensures legal state progression through COMBAT_RESOLUTION into END_TURN even with 0 attackers.
	if phase_manager == null:
		return
	var cur := phase_manager.get_current_phase()
	if cur == BattlePhaseManager.Phase.ACTION_PHASE or cur == BattlePhaseManager.Phase.BATTLE_WHEEL_PHASE:
		phase_manager.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
	if phase_manager.get_current_phase() != BattlePhaseManager.Phase.MATCH_OVER:
		phase_manager.transition_to(BattlePhaseManager.Phase.END_TURN)

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
		arena_3d.despawn_lane_entity_animated(lane.is_player, lane.lane_index, false)
	var creature_name = dead_data.get("name", "Creature")
	if not lane.is_player:
		match_enemy_creatures_defeated += 1
		if ResourceLoader.exists("res://assets/audio/sfx/CreatureDeath.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/CreatureDeath.wav"), -4.0)
		if opponent_face_rig:
			opponent_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
		# Matches Unity CreatureBattleScript.DeathActions(): victim CreatureDestroyed first, then attacker DestroyCreature
		if vo_manager and GameManager:
			vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.CREATURE_DESTROYED, false)
			vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.DESTROY_CREATURE, true)
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
		if player_face_rig:
			player_face_rig.play_emote(CharacterFaceRig.EmoteState.TAKE_DAMAGE)
		# Matches Unity CreatureBattleScript.DeathActions(): victim CreatureDestroyed first, then attacker DestroyCreature
		if vo_manager and GameManager:
			vo_manager.play_event(GameManager.player_hero_name, VOManager.VOEvent.CREATURE_DESTROYED, true)
			vo_manager.play_event(GameManager.opponent_hero_name, VOManager.VOEvent.DESTROY_CREATURE, false)
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

func _on_building_destroyed(lane: LaneSlot, _dead_data: Dictionary) -> void:
	if arena_3d:
		arena_3d.despawn_lane_entity_animated(lane.is_player, lane.lane_index, true)
	if vo_manager and GameManager:
		var owner_hero := GameManager.player_hero_name if lane.is_player else GameManager.opponent_hero_name
		vo_manager.play_event(owner_hero, VOManager.VOEvent.BUILDING_DESTROYED, lane.is_player)


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
	_step_hp_bar_anim("player", player_hp, player_max_hp, player_hp_bar, player_hp_damage_bar, player_hp_label, 0.0)
	_step_hp_bar_anim("opponent", opponent_hp, opponent_max_hp, opponent_hp_bar, opponent_hp_damage_bar, opponent_hp_label, 0.0)

	_set_mp_label_text(player_mp_label, player_mp)
	_set_mp_label_text(opponent_mp_label, opponent_mp)
	if magic_orb_label:
		magic_orb_label.text = str(player_mp)
	var p_mp_cap := float(maxi(1, maxi(player_max_mp, player_mp)))
	if _prev_player_mp < 0:
		_prev_player_mp = player_mp
		_set_mp_orbs_immediate([player_mp_orb_bar, magic_orb_bar], p_mp_cap, float(player_mp))
	elif player_mp != _prev_player_mp:
		var is_p_gain := player_mp > _prev_player_mp
		_prev_player_mp = player_mp
		_tween_mp_orb_bar(player_mp_orb_bar, p_mp_cap, float(player_mp))
		_tween_mp_orb_bar(magic_orb_bar, p_mp_cap, float(player_mp))
		_pulse_mp_label(player_mp_label)
		_pulse_mp_label(magic_orb_label)
		_spawn_magic_orb_vfx(magic_orb_bar, is_p_gain, 1.0)
	else:
		_sync_mp_orb_cap([player_mp_orb_bar, magic_orb_bar], p_mp_cap, float(player_mp))

	var o_mp_cap := float(maxi(1, maxi(_round_magic_cap, opponent_mp)))
	if _prev_opponent_mp < 0:
		_prev_opponent_mp = opponent_mp
		_set_mp_orbs_immediate([opponent_mp_orb_bar], o_mp_cap, float(opponent_mp))
	elif opponent_mp != _prev_opponent_mp:
		_prev_opponent_mp = opponent_mp
		_tween_mp_orb_bar(opponent_mp_orb_bar, o_mp_cap, float(opponent_mp))
		_pulse_mp_label(opponent_mp_label)
	else:
		_sync_mp_orb_cap([opponent_mp_orb_bar], o_mp_cap, float(opponent_mp))
	if draw_count_label:
		draw_count_label.text = str(player_draw_pile.size())
	if discard_count_label:
		discard_count_label.text = str(player_discard_pile.size())
	if loot_count_label:
		loot_count_label.text = str(loot_drops_count)
	if coins_count_label:
		coins_count_label.text = str(session_gold)
	if arena_3d:
		arena_3d.update_holding_cards_count(true, hand_container.get_child_count() if hand_container else 0)
		arena_3d.update_holding_cards_count(false, opponent_hand.size())
		_sync_floop_buttons_visual_state()


func _can_lane_floop_now(lane: LaneSlot) -> bool:
	if lane == null or not lane.has_creature or lane.is_flooped:
		return false
	if not is_player_turn or _in_battle_phase_hud or _is_summon_cinematic_active or _match_ended:
		return false
	if _pending_confirm_mode == "floop" and _pending_confirm_lane == lane:
		return false
	var floop_cost := int(lane.creature_data.get("floop_cost", 0))
	if floop_cost <= 0 or player_mp < floop_cost:
		return false
	return true


func _sync_floop_buttons_visual_state() -> void:
	if arena_3d == null:
		return
	for i in range(player_lanes.size()):
		var p_lane := player_lanes[i]
		var can_f := _can_lane_floop_now(p_lane)
		arena_3d.set_lane_floop_button_state(true, i, p_lane.has_creature, can_f, false)
	for i in range(opponent_lanes.size()):
		var o_lane := opponent_lanes[i]
		arena_3d.set_lane_floop_button_state(false, i, o_lane.has_creature, false, false)


func _setup_mp_orb_liquid(bar: TextureProgressBar, phase: float) -> void:
	## Adds an animated liquid wave overlay shader on top of Bottle_Empty while keeping TextureProgressBar value.
	if bar == null:
		return
	bar.step = 0.0
	bar.texture_progress = null
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_MAGIC_ORB_LIQUID
	mat.set_shader_parameter("wave_phase", phase)
	mat.set_shader_parameter("fill_level", 1.0)
	mat.set_shader_parameter("slosh_amp", 0.0)
	var overlay := TextureRect.new()
	overlay.name = "LiquidOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.texture = TEX_BOTTLE_FULL
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = mat
	bar.add_child(overlay)
	_mp_liquid_mats[bar.get_instance_id()] = mat


func _set_mp_orbs_immediate(bars: Array, cap: float, val: float) -> void:
	for b in bars:
		var bar := b as TextureProgressBar
		if bar == null:
			continue
		bar.max_value = cap
		bar.value = clampf(val, 0.0, cap)
		_sync_one_mp_liquid(bar)


func _sync_mp_orb_cap(bars: Array, cap: float, val: float) -> void:
	for b in bars:
		var bar := b as TextureProgressBar
		if bar == null:
			continue
		bar.max_value = cap
		var key: int = bar.get_instance_id()
		var tw := _mp_bar_tweens.get(key) as Tween
		if tw == null or not tw.is_valid() or not tw.is_running():
			bar.value = clampf(val, 0.0, cap)
		_sync_one_mp_liquid(bar)


func _sync_one_mp_liquid(bar: TextureProgressBar) -> void:
	if bar == null:
		return
	var mat := _mp_liquid_mats.get(bar.get_instance_id()) as ShaderMaterial
	if mat:
		mat.set_shader_parameter("fill_level", clampf(bar.value / maxf(1.0, bar.max_value), 0.0, 1.0))


func _trigger_mp_liquid_slosh(bar: TextureProgressBar, drain_dur: float = 0.9) -> void:
	if bar == null:
		return
	var key := bar.get_instance_id()
	var mat := _mp_liquid_mats.get(key) as ShaderMaterial
	if mat == null:
		return
	if _mp_slosh_tweens.has(key):
		var old_tw := _mp_slosh_tweens[key] as Tween
		if old_tw and old_tw.is_valid():
			old_tw.kill()
	var peak := 0.044
	var tw := create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(bar) and mat:
			mat.set_shader_parameter("slosh_amp", v)
	, float(mat.get_shader_parameter("slosh_amp")), peak, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float):
		if is_instance_valid(bar) and mat:
			mat.set_shader_parameter("slosh_amp", v)
	, peak, 0.0, drain_dur + 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mp_slosh_tweens[key] = tw


func _tween_mp_orb_bar(bar: TextureProgressBar, cap: float, target_val: float) -> void:
	if bar == null:
		return
	bar.max_value = cap
	var key := bar.get_instance_id()
	if _mp_bar_tweens.has(key):
		var old_tw := _mp_bar_tweens[key] as Tween
		if old_tw and old_tw.is_valid():
			old_tw.kill()
	var clamped := clampf(target_val, 0.0, cap)
	var delta_ratio := absf(clamped - bar.value) / maxf(1.0, cap)
	var dur := lerpf(0.85, 1.45, clampf(delta_ratio, 0.0, 1.0))
	var tw := create_tween()
	tw.tween_property(bar, "value", clamped, dur).set_trans(Tween.TRANS_LINEAR)
	_mp_bar_tweens[key] = tw
	_trigger_mp_liquid_slosh(bar, dur)


func _set_mp_label_text(lbl: Label, mp_val: int) -> void:
	## Sets the MP count and applies per-digit optical horizontal centering for proportional glyph widths.
	if lbl == null:
		return
	var text_str := str(mp_val)
	lbl.text = text_str
	var key := lbl.get_instance_id()
	if _mp_label_base_x.has(key):
		lbl.position.x = float(_mp_label_base_x[key]) + float(MP_LABEL_OPTICAL_DX.get(text_str, 0.0))


func _pulse_mp_label(lbl: Label) -> void:
	if lbl == null:
		return
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale = Vector2(1.28, 1.28)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _spawn_magic_orb_vfx(orb: Control, is_gain: bool, scale_mult: float = 1.0) -> void:
	if orb == null or not orb.is_visible_in_tree():
		return
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.z_index = 40
	add_child(host)
	var center := orb.get_global_rect().get_center()
	host.global_position = center

	var dur := 0.78 if is_gain else 0.72
	# Additive purple glow pulse on gain (FX_GUI_ActionPointUp FX_Glow)
	if is_gain:
		var glow := TextureRect.new()
		glow.texture = TEX_FX_GLOW
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		var g_sz := 128.0 * scale_mult
		glow.size = Vector2(g_sz, g_sz)
		glow.position = -glow.size * 0.5
		glow.pivot_offset = glow.size * 0.5
		var mat_add := CanvasItemMaterial.new()
		mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = mat_add
		glow.modulate = Color(0.75, 0.25, 0.92, 0.85)
		host.add_child(glow)
		var g_tw := glow.create_tween()
		g_tw.set_parallel(true)
		g_tw.tween_property(glow, "scale", Vector2(1.35, 1.35), 0.28).set_ease(Tween.EASE_OUT)
		g_tw.tween_property(glow, "modulate:a", 0.0, 0.32)

	# Radial purple/lavender smoke cloud burst (FX_SmokeBurst with FX_Smoke_Grey_PNG)
	var puff_count := 8 if is_gain else 7
	var base_r := 36.0 * scale_mult
	var travel_r := (34.0 if is_gain else 22.0) * scale_mult
	for i in range(puff_count):
		var ang := (TAU * float(i) / float(puff_count)) + randf_range(-0.24, 0.24)
		var puff := TextureRect.new()
		puff.texture = TEX_FX_SMOKE
		puff.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		puff.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var p_sz := randf_range(38.0, 52.0) * scale_mult * (1.25 if is_gain else 1.0)
		puff.size = Vector2(p_sz, p_sz)
		puff.pivot_offset = puff.size * 0.5
		var start_pos := Vector2(cos(ang), sin(ang)) * base_r - puff.pivot_offset
		var end_pos := Vector2(cos(ang), sin(ang)) * (base_r + travel_r) - puff.pivot_offset
		puff.position = start_pos
		puff.rotation = randf_range(-0.6, 0.6)
		puff.scale = Vector2(0.45, 0.45)
		puff.modulate = Color(0.95, 0.77, 1.0, 0.94)
		host.add_child(puff)
		var p_tw := puff.create_tween()
		p_tw.set_parallel(true)
		p_tw.tween_property(puff, "position", end_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		p_tw.tween_property(puff, "scale", Vector2(1.12, 1.12), dur * 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		p_tw.tween_property(puff, "modulate:a", 0.0, dur * 0.55).set_delay(dur * 0.45)

	# Rising pastel purple bubbles (FX_CardArt_Bubbles1) + light flare glints
	var bubble_atlas := AtlasTexture.new()
	bubble_atlas.atlas = TEX_FX_BUBBLES
	bubble_atlas.region = Rect2(0, 0, 64, 64)
	for j in range(5):
		var bub := TextureRect.new()
		bub.texture = bubble_atlas
		bub.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var b_sz := randf_range(12.0, 20.0) * scale_mult
		bub.size = Vector2(b_sz, b_sz)
		var bx := randf_range(-34.0, 34.0) * scale_mult - b_sz * 0.5
		var by := randf_range(-16.0, 24.0) * scale_mult - b_sz * 0.5
		bub.position = Vector2(bx, by)
		bub.modulate = Color(0.93, 0.68, 1.0, 0.85)
		host.add_child(bub)
		var b_tw := bub.create_tween()
		b_tw.set_parallel(true)
		b_tw.tween_property(bub, "position:y", by - randf_range(28.0, 52.0) * scale_mult, 0.72)
		b_tw.tween_property(bub, "modulate:a", 0.0, 0.45).set_delay(0.28)

	for k in range(3):
		var flare := TextureRect.new()
		flare.texture = TEX_FX_FLARE
		flare.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var f_sz := randf_range(22.0, 34.0) * scale_mult
		flare.size = Vector2(f_sz, f_sz)
		flare.pivot_offset = flare.size * 0.5
		var fa := randf_range(0.0, TAU)
		flare.position = Vector2(cos(fa), sin(fa)) * randf_range(14.0, 38.0) * scale_mult - flare.pivot_offset
		var f_mat := CanvasItemMaterial.new()
		f_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		flare.material = f_mat
		flare.modulate = Color(0.85, 0.65, 1.0, 0.95)
		flare.scale = Vector2(0.3, 0.3)
		host.add_child(flare)
		var f_tw := flare.create_tween()
		f_tw.set_parallel(true)
		f_tw.tween_property(flare, "scale", Vector2(1.1, 1.1), 0.18)
		f_tw.tween_property(flare, "modulate:a", 0.0, 0.35).set_delay(0.12)

	get_tree().create_timer(dur + 0.12).timeout.connect(func():
		if is_instance_valid(host):
			host.queue_free()
	)

func _on_menu_button_pressed() -> void:
	GameManager.return_to_menu()


func _process(delta: float) -> void:
	_step_hp_bar_anim("player", player_hp, player_max_hp, player_hp_bar, player_hp_damage_bar, player_hp_label, delta)
	_step_hp_bar_anim("opponent", opponent_hp, opponent_max_hp, opponent_hp_bar, opponent_hp_damage_bar, opponent_hp_label, delta)
	_sync_one_mp_liquid(player_mp_orb_bar)
	_sync_one_mp_liquid(opponent_mp_orb_bar)
	_sync_one_mp_liquid(magic_orb_bar)
	_update_creature_stat_badges()


func _reset_hp_anim_state(
	key: String,
	current_hp: int,
	max_hp: int,
	hp_bar: ProgressBar,
	dmg_bar: ProgressBar,
	hp_label: Label
) -> void:
	## Resets trailing damage interpolation and low-HP pulse for a hero corner bar.
	var state: Dictionary = _hp_anim_state[key]
	state["prev"] = float(current_hp)
	state["last"] = current_hp
	state["pulse"] = 0.0
	var cap := float(maxi(1, max_hp))
	if hp_bar:
		hp_bar.max_value = cap
		hp_bar.value = float(current_hp)
		hp_bar.modulate.a = 1.0
	if dmg_bar:
		dmg_bar.max_value = cap
		dmg_bar.value = float(current_hp)
	if hp_label:
		hp_label.text = str(current_hp)


func _step_hp_bar_anim(
	key: String,
	current_hp: int,
	max_hp: int,
	hp_bar: ProgressBar,
	dmg_bar: ProgressBar,
	hp_label: Label,
	delta: float
) -> void:
	## Mirrors CWUpdatePlayerData: cyan snaps on damage while red trails smoothly; heals slide up.
	var state: Dictionary = _hp_anim_state[key]
	var prev_hp: float = float(state.get("prev", -1.0))
	if prev_hp < 0.0:
		_reset_hp_anim_state(key, current_hp, max_hp, hp_bar, dmg_bar, hp_label)
		return
	var last_hp: int = int(state.get("last", current_hp))
	if current_hp < last_hp:
		_play_hero_damage_portrait_fx(key == "player")
	state["last"] = current_hp
	var cap := float(maxi(1, max_hp))
	var target := float(current_hp)
	if hp_bar:
		hp_bar.max_value = cap
	if dmg_bar:
		dmg_bar.max_value = cap

	if absf(target - prev_hp) >= 0.01:
		if delta > 0.0:
			prev_hp = lerpf(prev_hp, target, minf(1.0, delta * 2.0))
			if absf(target - prev_hp) < 0.01:
				prev_hp = target
			state["prev"] = prev_hp
		if dmg_bar:
			dmg_bar.value = prev_hp
		if prev_hp < target:
			if hp_bar:
				hp_bar.value = prev_hp
			if hp_label:
				hp_label.text = str(int(prev_hp))
		else:
			if hp_bar:
				hp_bar.value = target
			if hp_label:
				hp_label.text = str(current_hp)
	else:
		state["prev"] = target
		if dmg_bar:
			dmg_bar.value = target
		if hp_bar:
			hp_bar.value = target
		if hp_label:
			hp_label.text = str(current_hp)

	# Low-HP alpha pulse matching Unity TweenAlpha (PingPong 1.0 <-> 0.2 every 0.5s <= 25% HP)
	if hp_bar:
		if current_hp > 0 and float(current_hp) <= cap * 0.25:
			state["pulse"] = float(state.get("pulse", 0.0)) + delta
			hp_bar.modulate.a = lerpf(1.0, 0.2, pingpong(float(state["pulse"]) / 0.5, 1.0))
		else:
			state["pulse"] = 0.0
			hp_bar.modulate.a = 1.0


func _play_hero_damage_portrait_fx(is_player: bool) -> void:
	## Plays Unity FX_GUI_Land_Damage_Portrait (StarBurst + Skull), portrait shake, SFX, and P1 red flash.
	if ResourceLoader.exists(SFX_DAMAGE_BURST_PATH):
		Audio.play_sfx(load(SFX_DAMAGE_BURST_PATH))

	var face_rig: CharacterFaceRig = player_face_rig if is_player else opponent_face_rig
	var hp_bar: ProgressBar = player_hp_bar if is_player else opponent_hp_bar
	var fx_parent: Control = hp_bar.get_parent() if hp_bar else null
	if fx_parent == null:
		return

	var base_pos := Vector2(19.0 if is_player else 132.0, 52.0)
	var rig_size := Vector2(89.0, 89.0)
	if face_rig:
		if not face_rig.has_meta("base_portrait_pos"):
			face_rig.set_meta("base_portrait_pos", face_rig.position)
		base_pos = face_rig.get_meta("base_portrait_pos")
		rig_size = face_rig.size
		var shake_tw := face_rig.create_tween()
		shake_tw.tween_method(func(t: float):
			if not is_instance_valid(face_rig):
				return
			var amp := (1.0 - t) * 10.0
			face_rig.position = base_pos + Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		, 0.0, 1.0, 0.45)
		shake_tw.tween_callback(func():
			if is_instance_valid(face_rig):
				face_rig.position = base_pos
		)

	if is_player:
		var red_flash := ColorRect.new()
		red_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		red_flash.color = Color(1.0, 0.0, 0.0, 0.40)
		red_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(red_flash)
		move_child(red_flash, 0)
		var r_tw := red_flash.create_tween()
		r_tw.tween_property(red_flash, "color:a", 0.0, 0.50)
		r_tw.tween_callback(red_flash.queue_free)

	var host := Control.new()
	host.position = base_pos + rig_size * 0.5 + Vector2(0.0, 4.0)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_parent.add_child(host)

	# Unity Layer 23 camera (ortho 5.76 -> 11.52 units @ 720px = 62.5 px/unit) with scalingMode=Hierarchy @ world scale 1:
	# FX_StarBurst startSize=5.0 -> 312.5px; FX_StarBurst_Skull startSize=2.5 -> 156.25px
	var burst := TextureRect.new()
	burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	burst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	burst.texture = TEX_FX_STARBURST
	burst.size = Vector2(312.0, 312.0)
	burst.position = Vector2(-156.0, -156.0)
	burst.pivot_offset = Vector2(156.0, 156.0)
	burst.rotation = PI
	burst.scale = Vector2(0.2545, 0.2545)
	burst.modulate.a = 0.0
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(burst)

	# Unity FX_StarBurst: startDelay=0.10s, startLifetime=0.25s, Hermite ease-out 0.2545 -> 1.0
	var b_tw := burst.create_tween()
	b_tw.tween_interval(0.10)
	b_tw.tween_method(func(t: float):
		if not is_instance_valid(burst):
			return
		var s := _eval_unity_damage_curve(t)
		burst.scale = Vector2(s, s)
		burst.modulate.a = clampf(1.8 * (1.0 - t), 0.0, 1.0)
	, 0.0, 1.0, 0.25)

	var skull := TextureRect.new()
	skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skull.texture = TEX_FX_SKULL
	skull.size = Vector2(156.0, 156.0)
	skull.position = Vector2(-78.0, -78.0)
	skull.pivot_offset = Vector2(78.0, 78.0)
	skull.scale = Vector2(0.2545, 0.2545)
	skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(skull)

	# Unity FX_StarBurst_Skull: 0.50s Hermite ease-out 0.2545 -> 1.0; opaque first half (2x Alpha Blended)
	var s_tw := skull.create_tween()
	s_tw.tween_method(func(t: float):
		if not is_instance_valid(skull):
			return
		var s := _eval_unity_damage_curve(t)
		skull.scale = Vector2(s, s)
		skull.modulate.a = clampf(2.0 * (1.0 - t), 0.0, 1.0)
	, 0.0, 1.0, 0.50)
	s_tw.tween_callback(host.queue_free)


func _eval_unity_damage_curve(t: float) -> float:
	## Evaluates Unity FX_GUI_Land_Damage_Portrait SizeModule Hermite spline (0.2545 -> 1.0, slope 1.77 -> 0).
	var u := clampf(t, 0.0, 1.0)
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * 0.2545454 + (u3 - 2.0 * u2 + u) * 1.769944 + (-2.0 * u3 + 3.0 * u2) * 1.0


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
	var hide_for_modal := battle_modals != null and battle_modals.is_fullscreen_modal_open()
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
	if battle_modals and (battle_modals.is_any_modal_open() or battle_modals.is_inspection_open()):
		return
	if not is_action_allowed() or _in_battle_phase_hud or (wheel_modal and wheel_modal.visible):
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
	if lane == null or not is_action_allowed() or _in_battle_phase_hud:
		return
	# Matches Unity CWCommandCardSet.OnClick() (lines 52-61) + FLOOPButton OnClick:
	# - Clicking the FLOOP button when can_floop is true opens the Floop Prompt.
	# - Clicking the FLOOP button when can_floop is false does nothing (collider disabled in Unity).
	# - Clicking a player creature directly when can_floop is true ALSO triggers floopButton.SendMessage("OnClick")!
	if zone == "floop":
		if lane.is_player and _can_lane_floop_now(lane):
			_prompt_floop_confirmation(lane)
		return
	if lane.is_player and zone != "building" and lane.has_creature and _can_lane_floop_now(lane):
		_prompt_floop_confirmation(lane)
		return
	if zone == "building" and lane.has_building:
		if footer_bar:
			footer_bar.visible = false
		if arena_3d:
			arena_3d.focus_lane_zoom(lane.is_player, lane.lane_index, 0.30, true)
		if battle_modals:
			battle_modals.show_card_info(lane.building_data)
		return
	if lane.has_creature:
		if footer_bar:
			footer_bar.visible = false
		var lane_max_def: int = maxi(lane.current_def, int(lane.creature_data.get("def", lane.current_def)))
		if arena_3d:
			arena_3d.focus_lane_zoom(lane.is_player, lane.lane_index, 0.30, false)
		if battle_modals:
			battle_modals.show_card_info(lane.creature_data, lane.current_atk, lane.current_def, lane_max_def, lane.is_flooped)
		return
	if lane.has_building:
		if footer_bar:
			footer_bar.visible = false
		if arena_3d:
			arena_3d.focus_lane_zoom(lane.is_player, lane.lane_index, 0.30, true)
		if battle_modals:
			battle_modals.show_card_info(lane.building_data)


func _restore_hud_after_inspect() -> void:
	if _in_battle_phase_hud:
		return
	if footer_bar:
		footer_bar.visible = true
	if battle_log_box:
		battle_log_box.visible = false
	if arena_3d and not _is_summon_cinematic_active:
		arena_3d.focus_setup_board(0.35)


func _on_ability_confirmed() -> void:
	var mode := _pending_confirm_mode
	var lane := _pending_confirm_lane
	var l_id := _pending_confirm_leader
	_pending_confirm_mode = ""
	_pending_confirm_lane = null
	_pending_confirm_leader = ""
	if mode == "floop" and lane != null:
		_execute_floop_confirmed(lane)
	elif mode == "leader" and l_id != "":
		if battle_modals:
			battle_modals.dismiss_inspection(false)
		_restore_hud_after_inspect()
		_confirm_leader_power(l_id)


func _on_ability_cancelled() -> void:
	_pending_confirm_mode = ""
	_pending_confirm_lane = null
	_pending_confirm_leader = ""
	_restore_hud_after_inspect()
	_sync_floop_buttons_visual_state()


func _on_info_dismissed() -> void:
	if _pending_confirm_mode == "":
		_restore_hud_after_inspect()


func _set_battle_phase_hud(active_combat: bool) -> void:
	_in_battle_phase_hud = active_combat
	if active_combat:
		_pending_confirm_mode = ""
		_pending_confirm_lane = null
		_pending_confirm_leader = ""
		_deselect_card()
		if battle_modals and battle_modals.is_inspection_open():
			battle_modals.dismiss_inspection(false)
	if footer_bar:
		footer_bar.visible = not active_combat
	if turn_btn:
		turn_btn.visible = not active_combat
	if quest_quick_btn:
		quest_quick_btn.visible = not active_combat
	if pause_quick_btn:
		pause_quick_btn.visible = not active_combat
	if battle_log_box:
		battle_log_box.visible = false
	if board_click_surface:
		board_click_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE if active_combat else Control.MOUSE_FILTER_PASS
	_sync_floop_buttons_visual_state()


func _spawn_battle_fx_prefab(kind: String, target_is_player: bool, crit_mult: int = 2) -> void:
	## Authentically reproduces Unity FX_BattleFXHit, FX_BattleFXCrit, FX_BattleFXBlock, and FX_BattleFXMiss
	## spawned on TargetP1 (x = -350 / 1280 -> left half) or TargetP2 (x = +350 / 1280 -> right half).
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var anchor_x := 0.2265625 if target_is_player else 0.7734375
	host.anchor_left = anchor_x
	host.anchor_right = anchor_x
	host.anchor_top = 0.5
	host.anchor_bottom = 0.5
	host.z_index = 60
	add_child(host)

	match kind:
		"hit", "crit":
			var is_crit := (kind == "crit")
			var sfx_path := SFX_BATTLE_DAMAGE_CRIT_PATH if is_crit else SFX_BATTLE_DAMAGE_HIT_PATH
			if ResourceLoader.exists(sfx_path):
				Audio.play_sfx(load(sfx_path))
			if battle_modals:
				battle_modals.play_damage_burst_3d(target_is_player)
			if is_crit:
				# FX_BattleRingCrit: Battle_Flash (600->900 over 0.1s, alpha 0.776 -> 0.0 over 0.8s)
				var flash := TextureRect.new()
				flash.texture = TEX_BATTLE_FLASH
				flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				flash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				flash.size = Vector2(540.0, 540.0)
				flash.position = -flash.size * 0.5
				flash.pivot_offset = flash.size * 0.5
				flash.scale = Vector2(0.667, 0.667)
				flash.modulate = Color(1.0, 1.0, 1.0, 0.7764706)
				flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
				host.add_child(flash)
				var f_tw := flash.create_tween()
				f_tw.set_parallel(true)
				f_tw.tween_property(flash, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				f_tw.tween_property(flash, "modulate:a", 0.0, 0.80).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

			var text_str := ("CRITICAL x %d" % crit_mult) if is_crit else "ATTACK x 1"
			# 1. AttackLevel_Label (base yellow r=0.862,g=1,b=0 with orange outline r=1,g=0.412,b=0, alpha 0.6 -> 0 over 1.0s)
			var base_lbl := Label.new()
			base_lbl.text = text_str
			base_lbl.size = Vector2(680.0, 140.0)
			base_lbl.position = -base_lbl.size * 0.5
			base_lbl.pivot_offset = base_lbl.size * 0.5
			base_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			base_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			base_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			base_lbl.add_theme_font_override("font", FONT_BATTLE_HUD)
			base_lbl.add_theme_font_size_override("font_size", 68)
			base_lbl.add_theme_color_override("font_color", Color(0.862069, 1.0, 0.0, 1.0))
			base_lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.4117647, 0.0, 1.0))
			base_lbl.add_theme_constant_override("outline_size", 10)
			base_lbl.modulate.a = 0.92
			host.add_child(base_lbl)
			var b_tw := base_lbl.create_tween()
			b_tw.tween_property(base_lbl, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

			# 2. AttackLevel_Label_Scale (white with yellow outline r=0.945,g=1,b=0, scale 0.625 -> 1.25 (or 1.875 for crit) and alpha 0.6 -> 0 over 0.5s)
			var scale_lbl := Label.new()
			scale_lbl.text = text_str
			scale_lbl.size = Vector2(680.0, 140.0)
			scale_lbl.position = -scale_lbl.size * 0.5
			scale_lbl.pivot_offset = scale_lbl.size * 0.5
			scale_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			scale_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			scale_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			scale_lbl.add_theme_font_override("font", FONT_BATTLE_HUD)
			scale_lbl.add_theme_font_size_override("font_size", 68)
			scale_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			scale_lbl.add_theme_color_override("font_outline_color", Color(0.9448276, 1.0, 0.0, 1.0))
			scale_lbl.add_theme_constant_override("outline_size", 10)
			scale_lbl.scale = Vector2(0.625, 0.625)
			scale_lbl.modulate.a = 0.65
			host.add_child(scale_lbl)
			var end_s := 1.875 if is_crit else 1.25
			var s_tw := scale_lbl.create_tween()
			s_tw.set_parallel(true)
			s_tw.tween_property(scale_lbl, "scale", Vector2(end_s, end_s), 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			s_tw.tween_property(scale_lbl, "modulate:a", 0.0, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		"block":
			if ResourceLoader.exists(SFX_BATTLE_DAMAGE_BLOCK_PATH):
				Audio.play_sfx(load(SFX_BATTLE_DAMAGE_BLOCK_PATH))
			# FX_BattleFXBlock: Battle_Shield + FX_BattleFXBlockDup (scale 1.0 -> 2.0 over 0.5s) + "BLOCKED!" label above
			for dup_idx in range(2):
				var sh := TextureRect.new()
				sh.texture = TEX_BATTLE_SHIELD
				sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				sh.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				sh.size = Vector2(210.0, 210.0)
				sh.position = -sh.size * 0.5
				sh.pivot_offset = sh.size * 0.5
				sh.modulate = Color(1.0, 1.0, 1.0, 0.55 if dup_idx == 0 else 0.4431373)
				sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
				host.add_child(sh)
				var sh_tw := sh.create_tween()
				sh_tw.set_parallel(true)
				if dup_idx == 1:
					sh_tw.tween_property(sh, "scale", Vector2(2.0, 2.0), 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				sh_tw.tween_property(sh, "modulate:a", 0.0, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			var blk_lbl := Label.new()
			blk_lbl.text = "BLOCKED!"
			blk_lbl.size = Vector2(480.0, 100.0)
			blk_lbl.position = Vector2(-240.0, -210.0)
			blk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			blk_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			blk_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			blk_lbl.add_theme_font_override("font", FONT_BATTLE_HUD)
			blk_lbl.add_theme_font_size_override("font_size", 52)
			blk_lbl.add_theme_color_override("font_color", Color(0.0, 0.9172416, 1.0, 1.0))
			blk_lbl.add_theme_color_override("font_outline_color", Color(0.9448276, 1.0, 0.0, 1.0))
			blk_lbl.add_theme_constant_override("outline_size", 8)
			host.add_child(blk_lbl)
			var bl_tw := blk_lbl.create_tween()
			bl_tw.tween_property(blk_lbl, "modulate:a", 0.0, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		"miss":
			var miss_lbl := Label.new()
			miss_lbl.text = "MISS!"
			miss_lbl.size = Vector2(480.0, 120.0)
			miss_lbl.position = -miss_lbl.size * 0.5
			miss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			miss_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			miss_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			miss_lbl.add_theme_font_override("font", FONT_BATTLE_HUD)
			miss_lbl.add_theme_font_size_override("font_size", 68)
			miss_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			miss_lbl.add_theme_color_override("font_outline_color", Color(0.9448276, 1.0, 0.0, 1.0))
			miss_lbl.add_theme_constant_override("outline_size", 10)
			host.add_child(miss_lbl)
			var m_tw := miss_lbl.create_tween()
			m_tw.tween_property(miss_lbl, "modulate:a", 0.0, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	get_tree().create_timer(1.15).timeout.connect(func():
		if is_instance_valid(host):
			host.queue_free()
	)


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
