extends Node

## Automated Test Suite for Epic 5 (Tasks 5.1 & 5.2: Gamepad Support & Local 2-Player Multiplayer)

const MatchRulesConfig = preload("res://src/systems/local_multiplayer/MatchRulesConfig.gd")
const PlayerInputRouter = preload("res://src/systems/local_multiplayer/PlayerInputRouter.gd")
const HotseatCurtain = preload("res://src/systems/local_multiplayer/HotseatCurtain.gd")
const GamepadNavigator = preload("res://src/systems/local_multiplayer/GamepadNavigator.gd")
const VersusSetupModal = preload("res://src/ui/VersusSetupModal.gd")
const LanDiscovery = preload("res://src/systems/network_multiplayer/LanDiscovery.gd")
const NetworkSessionManager = preload("res://src/systems/network_multiplayer/NetworkSessionManager.gd")
const TurnActionProtocol = preload("res://src/systems/network_multiplayer/TurnActionProtocol.gd")
const LanLobbyModal = preload("res://src/ui/LanLobbyModal.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING GAMEPAD & LOCAL MULTIPLAYER TEST SUITE (Epic 5)")
	print("==================================================\n")

	_test_glyph_detection()
	_test_gamepad_navigator()
	_test_versus_match_config()
	_test_hotseat_curtain()
	_test_versus_setup_modal()
	_test_battle_controller_multiplayer()
	_test_lan_discovery()
	_test_turn_action_protocol()
	_test_lan_lobby_modal()

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [_tests_passed, _tests_failed])
	print("==================================================")

	if _tests_failed == 0:
		print(">>> ALL GAMEPAD & LOCAL MULTIPLAYER TESTS COMPLETED SUCCESSFULLY! <<<\n")
		get_tree().quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		get_tree().quit(1)


func _assert_test(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s %s" % [test_name, details])


func _test_glyph_detection() -> void:
	print("[Test 1] Controller Type & Dynamic Glyph Detection (Task 5.1)")
	var kbd_type = PlayerInputRouter.detect_controller_type(-1)
	_assert_test(kbd_type == MatchRulesConfig.ControllerType.KEYBOARD_MOUSE, "Device -1 detected as Keyboard/Mouse")
	_assert_test(PlayerInputRouter.get_action_glyph("confirm", kbd_type) == "Enter / Space", "Keyboard confirm glyph is 'Enter / Space'")

	var ps_glyph = PlayerInputRouter.get_action_glyph("confirm", MatchRulesConfig.ControllerType.PLAYSTATION)
	_assert_test(ps_glyph.contains("Cross"), "PlayStation confirm glyph displays 'Cross (✕)'")
	_assert_test(PlayerInputRouter.get_action_glyph("end_turn", MatchRulesConfig.ControllerType.PLAYSTATION) == "R1", "PlayStation end turn is 'R1'")

	var deck_glyph = PlayerInputRouter.get_action_glyph("confirm", MatchRulesConfig.ControllerType.STEAM_DECK)
	_assert_test(deck_glyph == "A", "Steam Deck confirm glyph is 'A'")
	_assert_test(PlayerInputRouter.get_action_glyph("end_turn", MatchRulesConfig.ControllerType.STEAM_DECK) == "RB", "Steam Deck end turn is 'RB'")

	var switch_glyph = PlayerInputRouter.get_action_glyph("confirm", MatchRulesConfig.ControllerType.SWITCH)
	_assert_test(switch_glyph == "B", "Nintendo Switch confirm glyph is 'B'")


func _test_gamepad_navigator() -> void:
	print("\n[Test 2] GamepadNavigator 2D Focus Graph (Task 5.1)")
	var nav = GamepadNavigator.new()

	var hand_nodes: Array[Control] = []
	for i in range(4): hand_nodes.append(Button.new())
	var lane_nodes: Array[Control] = []
	for i in range(4): lane_nodes.append(Button.new())
	var leader_btn = Button.new()
	var turn_btn = Button.new()

	nav.register_zone_nodes(GamepadNavigator.FocusZone.HAND, hand_nodes)
	nav.register_zone_nodes(GamepadNavigator.FocusZone.LANES, lane_nodes)
	nav.register_zone_nodes(GamepadNavigator.FocusZone.LEADER, [leader_btn])
	nav.register_zone_nodes(GamepadNavigator.FocusZone.END_TURN, [turn_btn])

	# 1. Initial Hand focus
	nav.focus_zone(GamepadNavigator.FocusZone.HAND, 0)
	_assert_test(nav.current_zone == GamepadNavigator.FocusZone.HAND, "Focused on HAND zone")
	_assert_test(nav.current_index == 0, "Focused on Hand index 0")

	# 2. Horizontal navigation within hand
	nav.navigate(Vector2.RIGHT)
	_assert_test(nav.current_index == 1, "Navigated RIGHT to Hand index 1")

	# 3. Upward navigation to Lanes
	nav.navigate(Vector2.UP)
	_assert_test(nav.current_zone == GamepadNavigator.FocusZone.LANES, "Navigated UP to LANES zone")
	_assert_test(nav.current_index == 1, "Preserved slot index 1 in Lanes")

	# 4. Upward navigation to Leader
	nav.navigate(Vector2.UP)
	_assert_test(nav.current_zone == GamepadNavigator.FocusZone.LEADER, "Navigated UP to LEADER zone")

	# 5. Rightward navigation to End Turn
	nav.navigate(Vector2.RIGHT)
	_assert_test(nav.current_zone == GamepadNavigator.FocusZone.END_TURN, "Navigated RIGHT to END_TURN button")

	# 6. Downward return navigation
	nav.navigate(Vector2.DOWN)
	_assert_test(nav.current_zone == GamepadNavigator.FocusZone.LANES, "Navigated DOWN from END_TURN to LANES")
	nav.navigate(Vector2.DOWN)
	_assert_test(nav.current_zone == GamepadNavigator.FocusZone.HAND, "Navigated DOWN from LANES to HAND")


func _test_versus_match_config() -> void:
	print("\n[Test 3] MatchRulesConfig & GameManager Local Setup (Task 5.2)")
	var config = MatchRulesConfig.new(MatchRulesConfig.MatchMode.HOTSEAT_PASS_AND_PLAY)
	config.set_player_loadout(0, "Finn", "Finn", ["Card_1", "Card_2"], ["Plains", "Plains", "Cotton", "Plains"], -1)
	config.set_player_loadout(1, "Jake", "Jake", ["Card_A", "Card_B"], ["Corn", "Corn", "Sand", "Corn"], 0)

	_assert_test(config.is_hotseat() == true, "Config mode is HOTSEAT")
	_assert_test(config.get_player_name(0) == "Finn", "P1 name is Finn")
	_assert_test(config.get_player_name(1) == "Jake", "P2 name is Jake")

	GameManager.setup_local_versus_match(config)
	_assert_test(GameManager.is_local_versus == true, "GameManager.is_local_versus set to true")
	_assert_test(GameManager.active_quest_id == "", "active_quest_id cleared for versus match")
	_assert_test(GameManager.player_hero_name == "Finn", "GameManager player hero configured as Finn")
	_assert_test(GameManager.opponent_hero_name == "Jake", "GameManager opponent hero configured as Jake")


func _test_hotseat_curtain() -> void:
	print("\n[Test 4] HotseatCurtain Turn Transition & Privacy Screen (Task 5.2)")
	var root = Control.new()
	root.custom_minimum_size = Vector2(800, 600)
	var curtain = HotseatCurtain.new()
	root.add_child(curtain)
	curtain._ready()

	_assert_test(curtain.current_state == HotseatCurtain.CurtainState.INACTIVE, "HotseatCurtain starts INACTIVE")
	_assert_test(curtain.visible == false, "HotseatCurtain starts hidden")

	var handoff_fired = [false]
	var unveil_fired = [false]
	curtain.handoff_started.connect(func(_slot, _name): handoff_fired[0] = true)
	curtain.unveil_confirmed.connect(func(_slot): unveil_fired[0] = true)

	curtain.start_handoff(1, "Jake", MatchRulesConfig.ControllerType.STEAM_DECK)
	_assert_test(curtain.visible == true, "Curtain visible when handoff triggered")
	_assert_test(curtain.target_player_slot == 1, "Target player slot is 1")
	_assert_test(curtain.target_player_name == "Jake", "Target player name is Jake")

	# Simulate handoff confirmed
	curtain.current_state = HotseatCurtain.CurtainState.AWAITING_HANDOFF
	curtain._on_unveil_pressed()
	_assert_test(unveil_fired[0] == true, "unveil_confirmed signal emitted")

	root.queue_free()


func _test_versus_setup_modal() -> void:
	print("\n[Test 5] VersusSetupModal UI Lifecycle (Task 5.2)")
	var modal_scene = load("res://scenes/versus_setup_modal.tscn").instantiate()
	add_child(modal_scene)

	_assert_test(modal_scene.visible == false, "Modal hidden initially")
	modal_scene.open_modal()
	_assert_test(modal_scene.visible == true, "Modal visible after open_modal()")

	_assert_test(modal_scene.mode_option.get_item_count() == 2, "Mode option contains Hotseat and Dual-Pad modes")
	_assert_test(modal_scene.p1_hero_option.get_item_count() >= 5, "Hero option populated with >= 5 heroes")
	_assert_test(modal_scene.p1_deck_option.get_item_count() >= 2, "Deck option populated with preset decks")

	var started_fired = [false]
	modal_scene.match_started.connect(func(_cfg): started_fired[0] = true)
	modal_scene._on_start_pressed()
	_assert_test(started_fired[0] == true, "match_started signal fired on start press")
	_assert_test(modal_scene.visible == false, "Modal hidden after match started")

	modal_scene.queue_free()


func _test_battle_controller_multiplayer() -> void:
	print("\n[Test 6] BattleController Local Multiplayer & Input Routing (Task 5.2)")
	var config = MatchRulesConfig.new(MatchRulesConfig.MatchMode.HOTSEAT_PASS_AND_PLAY)
	config.set_player_loadout(0, "Finn", "Finn", ["Card_1", "Card_2"], ["Plains", "Plains", "Cotton", "Plains"], -1)
	config.set_player_loadout(1, "Jake", "Jake", ["Card_A", "Card_B"], ["Corn", "Corn", "Sand", "Corn"], 0)
	GameManager.setup_local_versus_match(config)

	var battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)

	_assert_test(battle.input_router != null, "PlayerInputRouter instantiated in BattleController")
	_assert_test(battle.gamepad_navigator != null, "GamepadNavigator instantiated in BattleController")
	_assert_test(battle.hotseat_curtain != null, "HotseatCurtain instantiated in BattleController")

	# Test input routing
	var key_space = InputEventKey.new()
	key_space.keycode = KEY_SPACE
	key_space.pressed = true
	var routed = battle.input_router.route_input_event(key_space)
	_assert_test(routed.consumed == true, "Key event routed and consumed")
	_assert_test(routed.action == "confirm", "Key event mapped to 'confirm'")

	battle.queue_free()
	GameManager.is_local_versus = false


func _test_lan_discovery() -> void:
	print("\n[Test 7] LanDiscovery UDP Broadcast & Beacon Protocol (SYS-11 / Task 5.2)")
	var discovery = LanDiscovery.new()
	_assert_test(discovery.game_identifier == LanDiscovery.DEFAULT_GAME_ID, "LanDiscovery game_identifier matches default")
	_assert_test(discovery.discovery_port == LanDiscovery.DEFAULT_DISCOVERY_PORT, "LanDiscovery discovery_port matches 47777")

	var err = discovery.start_broadcasting("Card Wars LAN Room", 8910, {"hero": "Finn"})
	_assert_test(err == OK, "start_broadcasting returns OK")
	_assert_test(discovery.is_broadcaster == true, "LanDiscovery state is broadcaster")

	# Mock received server packet
	var mock_server = {
		"ip": "192.168.1.150",
		"game_port": 8910,
		"server_name": "Card Wars LAN Room",
		"extra_info": {"hero": "Finn"},
		"last_seen": Time.get_ticks_msec() / 1000.0
	}
	discovery._discovered_servers["192.168.1.150"] = mock_server

	var servers = discovery.get_discovered_servers()
	_assert_test(servers.has("192.168.1.150"), "Discovered server recorded")
	_assert_test(servers["192.168.1.150"]["server_name"] == "Card Wars LAN Room", "Server name matches")

	discovery.stop()
	_assert_test(discovery.is_broadcaster == false, "Broadcaster stopped cleanly")
	discovery.free()


func _test_turn_action_protocol() -> void:
	print("\n[Test 8] TurnActionProtocol Action RPC Dispatch & Handshake (SYS-11 / Task 5.2)")
	var protocol = TurnActionProtocol.new()
	var state = {"action": "", "payload": {}, "handshake": false}

	protocol.action_executed.connect(func(sender_id: int, action_type: String, payload: Dictionary):
		state["action"] = action_type
		state["payload"] = payload
	)
	protocol.handshake_received.connect(func(sender_id: int, data: Dictionary):
		state["handshake"] = true
	)

	protocol.send_play_card("Creature_HuskerKnight", 2, false)
	_assert_test(state["action"] == TurnActionProtocol.ACTION_PLAY_CARD, "ACTION_PLAY_CARD dispatched")
	_assert_test(state["payload"].get("card_id") == "Creature_HuskerKnight", "Card ID matches")
	_assert_test(state["payload"].get("target_slot") == 2, "Target slot is 2")

	protocol.send_floop(1)
	_assert_test(state["action"] == TurnActionProtocol.ACTION_FLOOP, "ACTION_FLOOP dispatched")

	protocol.send_leader_power("Finn")
	_assert_test(state["action"] == TurnActionProtocol.ACTION_LEADER_POWER, "ACTION_LEADER_POWER dispatched")

	protocol.send_end_turn()
	_assert_test(state["action"] == TurnActionProtocol.ACTION_END_TURN, "ACTION_END_TURN dispatched")

	# Handshake test
	var p2_data = {
		"player_name": "Jake_LAN",
		"hero": "Jake",
		"deck": ["Creature_MaizeWalker", "Creature_Cornball"],
		"landscapes": ["Corn", "Corn", "Sand", "Corn"]
	}
	protocol.send_handshake(p2_data)
	_assert_test(state["handshake"] == true, "Handshake received signal emitted")

	GameManager.apply_remote_handshake(p2_data)
	_assert_test(GameManager.remote_player_name == "Jake_LAN", "GameManager remote_player_name updated")
	_assert_test(GameManager.opponent_hero_name == "Jake", "GameManager opponent_hero_name updated")
	_assert_test(GameManager.opponent_deck.size() == 2, "GameManager opponent_deck updated")

	protocol.free()


func _test_lan_lobby_modal() -> void:
	print("\n[Test 9] LanLobbyModal UI & Discovery Integration (Task 5.2)")
	var modal_scene = load("res://scenes/lan_lobby_modal.tscn").instantiate()
	add_child(modal_scene)

	_assert_test(modal_scene.visible == false, "LanLobbyModal starts hidden")
	modal_scene.open_modal()
	_assert_test(modal_scene.visible == true, "LanLobbyModal visible after open_modal()")

	_assert_test(modal_scene.host_hero_option.get_item_count() >= 5, "Host hero options populated")
	_assert_test(modal_scene.host_deck_option.get_item_count() >= 2, "Host deck options populated")
	_assert_test(modal_scene.join_hero_option.get_item_count() >= 5, "Join hero options populated")
	_assert_test(modal_scene.join_deck_option.get_item_count() >= 2, "Join deck options populated")

	# Test host button state toggle
	modal_scene._on_host_start_pressed()
	_assert_test(modal_scene._is_hosting == true, "Hosting state activated on start press")
	_assert_test(modal_scene.discovery.is_broadcaster == true, "LanDiscovery broadcaster started")

	modal_scene.close_modal()
	_assert_test(modal_scene.visible == false, "LanLobbyModal hidden after close_modal()")
	_assert_test(modal_scene._is_hosting == false, "Hosting state reset on close")

	modal_scene.queue_free()
