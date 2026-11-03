class_name BattlePhaseManager
extends Node

## BattlePhaseManager: Formal Phase State Machine for Card Wars Battles
## Enforces sequence: START_TURN -> ACTION_PHASE -> BATTLE_WHEEL_PHASE -> COMBAT_RESOLUTION -> END_TURN

enum Phase {
	NONE,
	START_TURN,
	ACTION_PHASE,
	BATTLE_WHEEL_PHASE,
	COMBAT_RESOLUTION,
	END_TURN,
	MATCH_OVER
}

signal phase_changed(new_phase: Phase, old_phase: Phase)
signal turn_started(active_player: int, turn_number: int)
signal turn_ended(active_player: int, turn_number: int)
signal combat_lane_started(lane_index: int, attacking_side: int)
signal combat_lane_resolved(lane_index: int, attacking_side: int, result: Dictionary)
signal match_ended(victory: bool)

var current_phase: Phase = Phase.NONE
var active_player: int = 0 # 0: Player 1 (You), 1: Player 2 (Opponent)
var turn_number: int = 1
var current_combat_lane: int = 0
var max_lanes: int = 4

# Valid state transition map
const ALLOWED_TRANSITIONS: Dictionary = {
	Phase.NONE: [Phase.START_TURN, Phase.MATCH_OVER],
	Phase.START_TURN: [Phase.ACTION_PHASE, Phase.MATCH_OVER],
	Phase.ACTION_PHASE: [Phase.BATTLE_WHEEL_PHASE, Phase.COMBAT_RESOLUTION, Phase.MATCH_OVER],
	Phase.BATTLE_WHEEL_PHASE: [Phase.COMBAT_RESOLUTION, Phase.MATCH_OVER],
	Phase.COMBAT_RESOLUTION: [Phase.BATTLE_WHEEL_PHASE, Phase.COMBAT_RESOLUTION, Phase.END_TURN, Phase.MATCH_OVER],
	Phase.END_TURN: [Phase.START_TURN, Phase.MATCH_OVER],
	Phase.MATCH_OVER: []
}

func start_battle(starting_player: int = 0) -> void:
	active_player = starting_player
	turn_number = 1
	current_combat_lane = 0
	transition_to(Phase.START_TURN)

func can_transition_to(target_phase: Phase) -> bool:
	if current_phase == Phase.MATCH_OVER:
		return false
	var allowed: Array = ALLOWED_TRANSITIONS.get(current_phase, [])
	return target_phase in allowed

func transition_to(target_phase: Phase) -> bool:
	if not can_transition_to(target_phase):
		push_warning("BattlePhaseManager: Illegal phase transition attempted from %s to %s!" % [
			phase_to_string(current_phase), phase_to_string(target_phase)
		])
		return false

	var old_phase = current_phase
	current_phase = target_phase

	# Lifecycle triggers on entering phase
	match current_phase:
		Phase.START_TURN:
			current_combat_lane = 0
			turn_started.emit(active_player, turn_number)
		Phase.END_TURN:
			turn_ended.emit(active_player, turn_number)
			# Advance player and turn counter
			active_player = 1 - active_player
			if active_player == 0:
				turn_number += 1

	phase_changed.emit(current_phase, old_phase)
	return true

func is_action_allowed(player_idx: int = 0) -> bool:
	return current_phase == Phase.ACTION_PHASE and active_player == player_idx

func is_player_turn() -> bool:
	return active_player == 0

func get_current_phase() -> Phase:
	return current_phase

func get_active_player() -> int:
	return active_player

func get_turn_number() -> int:
	return turn_number

func get_current_combat_lane() -> int:
	return current_combat_lane

func start_combat_lane(lane_idx: int) -> void:
	current_combat_lane = lane_idx
	combat_lane_started.emit(lane_idx, active_player)

func resolve_combat_lane(lane_idx: int, result: Dictionary = {}) -> void:
	combat_lane_resolved.emit(lane_idx, active_player, result)

func advance_combat_lane() -> int:
	current_combat_lane += 1
	return current_combat_lane

func end_match(victory: bool) -> void:
	current_phase = Phase.MATCH_OVER
	match_ended.emit(victory)

static func phase_to_string(phase: Phase) -> String:
	match phase:
		Phase.NONE: return "NONE"
		Phase.START_TURN: return "START_TURN"
		Phase.ACTION_PHASE: return "ACTION_PHASE"
		Phase.BATTLE_WHEEL_PHASE: return "BATTLE_WHEEL_PHASE"
		Phase.COMBAT_RESOLUTION: return "COMBAT_RESOLUTION"
		Phase.END_TURN: return "END_TURN"
		Phase.MATCH_OVER: return "MATCH_OVER"
		_: return "UNKNOWN"
