class_name AbilitySystem
extends Node

const AbilityResolver = preload("res://src/systems/ability_engine/AbilityResolver.gd")
const AbilityDefinition = preload("res://src/systems/ability_engine/AbilityDefinition.gd")
const EffectData = preload("res://src/systems/ability_engine/EffectData.gd")
const EffectContext = preload("res://src/systems/ability_engine/EffectContext.gd")
const SystemEventBus = preload("res://src/systems/ability_engine/SystemEventBus.gd")

enum Trigger {
	ON_FLOOP,         # Manual activation during Action Phase
	ON_SUMMON,        # Fired when card is deployed onto a lane
	ON_DEATH,         # Fired when creature DEF reaches 0
	ON_TURN_START,    # Fired at the beginning of active turn
	ON_TURN_END,      # Fired at the conclusion of active turn
	ON_ATTACK,        # Fired immediately before combat damage resolution
	STATIC_AURA       # Continuous passive recalculation when board state changes
}

signal ability_triggered(card_name: String, trigger_name: String, effect_desc: String)

var battle_controller: Node = null
var resolver: AbilityResolver = null
var event_bus: SystemEventBus = null


func setup(controller: Node) -> void:
	battle_controller = controller
	resolver = AbilityResolver.new()
	event_bus = SystemEventBus.new()
	add_child(resolver)
	add_child(event_bus)
	event_bus.connect_resolver(resolver)

	# Connect death signals from all active lanes
	var lanes = _get_player_lanes() + _get_opponent_lanes()
	for lane in lanes:
		if lane and not lane.creature_destroyed.is_connected(_on_lane_creature_destroyed):
			lane.creature_destroyed.connect(_on_lane_creature_destroyed)


func _on_lane_creature_destroyed(lane: LaneSlot, dead_data: Dictionary) -> void:
	dispatch_trigger(Trigger.ON_DEATH, lane, {"creature_data": dead_data})


## Unified Trigger Dispatcher
func dispatch_trigger(
	trigger: Trigger,
	source_lane: LaneSlot = null,
	extra_context: Dictionary = {}
) -> bool:
	match trigger:
		Trigger.ON_SUMMON:
			return _handle_summon(source_lane, extra_context)
		Trigger.ON_FLOOP:
			return _handle_floop(source_lane, extra_context)
		Trigger.ON_DEATH:
			return _handle_death(source_lane, extra_context)
		Trigger.ON_TURN_START:
			return _handle_turn_start(extra_context)
		Trigger.ON_TURN_END:
			return _handle_turn_end(extra_context)
		Trigger.ON_ATTACK:
			return _handle_attack(source_lane, extra_context)
		Trigger.STATIC_AURA:
			recalculate_auras()
			return true
	return false


## Handles ON_SUMMON trigger
func _handle_summon(lane: LaneSlot, _ctx: Dictionary) -> bool:
	if lane == null or not lane.has_creature:
		return false

	var data = lane.creature_data
	var script_name = data.get("script_name", "")
	var val1 = str(data.get("val1", "0"))

	# Entry effects (e.g. CreatureDamageOnEntry, HeroDamageOnEntry)
	match script_name:
		"CreatureDamageOnEntry":
			var dmg = int(val1) if int(val1) > 0 else 2
			var opp_lane = _get_opposing_lane(lane)
			if opp_lane and opp_lane.has_creature:
				opp_lane.apply_damage(dmg)
				_log("✨ %s dealt %d damage to opposing creature on entry!" % [data.get("name", "Creature"), dmg])
		"HeroDamageOnEntry":
			var dmg = int(val1) if int(val1) > 0 else 2
			_damage_opposing_hero(lane.is_player, dmg)
			_log("✨ %s dealt %d damage to opponent hero on entry!" % [data.get("name", "Creature"), dmg])

	# Recalculate passive auras on the board
	recalculate_auras()
	return true


## Handles ON_FLOOP trigger
func _handle_floop(lane: LaneSlot, _ctx: Dictionary) -> bool:
	if lane == null or not lane.has_creature:
		return false

	var data = lane.creature_data
	var script_name = data.get("script_name", "")
	var val1 = str(data.get("val1", "0"))
	var val2 = str(data.get("val2", "0"))
	var card_name = data.get("name", "Creature")

	var executed = execute_card_script(script_name, lane, val1, val2)
	if executed:
		ability_triggered.emit(card_name, "ON_FLOOP", script_name)
	return executed


## Handles ON_DEATH trigger
func _handle_death(lane: LaneSlot, ctx: Dictionary) -> bool:
	var data = ctx.get("creature_data", lane.creature_data if lane else {})
	if data.is_empty():
		return false

	var script_name = data.get("script_name", "")
	var val1 = int(data.get("val1", "2"))
	var card_name = data.get("name", "Creature")
	var is_player = ctx.get("is_player", lane.is_player if lane else true)

	match script_name:
		"DamageHeroOnDeath":
			var dmg = val1 if val1 > 0 else 2
			_damage_opposing_hero(is_player, dmg)
			_log("💀 %s's death dealt %d damage to opponent hero!" % [card_name, dmg])
			ability_triggered.emit(card_name, "ON_DEATH", "DamageHeroOnDeath")
		"HealHeroOnDeath":
			var heal = val1 if val1 > 0 else 3
			_heal_friendly_hero(is_player, heal)
			_log("💖 %s's death restored %d HP to friendly hero!" % [card_name, heal])
			ability_triggered.emit(card_name, "ON_DEATH", "HealHeroOnDeath")

	recalculate_auras()
	return true


## Handles ON_TURN_START trigger
func _handle_turn_start(_ctx: Dictionary) -> bool:
	if battle_controller == null:
		return false

	var is_player = battle_controller.is_player_turn if "is_player_turn" in battle_controller else true
	var lanes = _get_player_lanes() if is_player else _get_opponent_lanes()

	for lane in lanes:
		if not lane.has_creature:
			continue
		var script = lane.creature_data.get("script_name", "")
		var val1 = int(lane.creature_data.get("val1", "0"))
		match script:
			"StartTurnHealCreatures":
				var heal = val1 if val1 > 0 else 1
				lane.modify_def(heal)
				_log("🌿 Turn Start: %s healed %d DEF!" % [lane.creature_data.get("name", "Creature"), heal])

	recalculate_auras()
	return true


## Handles ON_TURN_END trigger
func _handle_turn_end(_ctx: Dictionary) -> bool:
	recalculate_auras()
	return true


## Handles ON_ATTACK trigger
func _handle_attack(lane: LaneSlot, _ctx: Dictionary) -> bool:
	if lane == null or not lane.has_creature:
		return false
	var script = lane.creature_data.get("script_name", "")
	match script:
		"DoubleDamage":
			lane.modify_atk(lane.current_atk)
			_log("⚔️ DoubleDamage: %s doubled its ATK to %d!" % [lane.creature_data.get("name", "Creature"), lane.current_atk])
	return true


## Core Card Script Execution Matrix (Resolves 20+ standard Card Wars ability patterns)
func execute_card_script(
	script_name: String,
	source_lane: LaneSlot,
	val1_str: String = "0",
	val2_str: String = "0",
	for_faction: String = ""
) -> bool:
	var val1 = int(val1_str)
	var val2 = int(val2_str)
	var card_name = source_lane.creature_data.get("name", "Card") if source_lane else "Card"
	var is_player = source_lane.is_player if source_lane else true

	match script_name:
		"ATKBonus":
			var buff = val1 if val1 > 0 else 1
			source_lane.modify_atk(buff)
			_log("Floop: %s gained +%d Attack!" % [card_name, buff])

		"ATKDEFBonus":
			var atk_buff = val1 if val1 > 0 else 2
			var def_buff = val2 if val2 > 0 else 2
			source_lane.modify_atk(atk_buff)
			source_lane.modify_def(def_buff)
			_log("Floop: %s gained +%d ATK and +%d DEF!" % [card_name, atk_buff, def_buff])

		"BonusATKTarget":
			var buff = val1 if val1 > 0 else 2
			var friendly_lanes = _get_player_lanes() if is_player else _get_opponent_lanes()
			for l in friendly_lanes:
				if l.has_creature:
					l.modify_atk(buff)
			_log("Floop: All friendly creatures gained +%d Attack!" % buff)

		"BonusDEFTarget":
			var buff = val1 if val1 > 0 else 2
			var friendly_lanes = _get_player_lanes() if is_player else _get_opponent_lanes()
			for l in friendly_lanes:
				if l.has_creature:
					l.modify_def(buff)
			_log("Floop: All friendly creatures gained +%d Defense!" % buff)

		"LowerATKTarget", "LowerATKOpponent":
			var debuff = val1 if val1 > 0 else 2
			var opp_lane = _get_opposing_lane(source_lane)
			if opp_lane and opp_lane.has_creature:
				opp_lane.modify_atk(-debuff)
				_log("Floop: Opposing %s had Attack reduced by %d!" % [opp_lane.creature_data.get("name", "Creature"), debuff])
			else:
				_log("Floop: No opposing creature to weaken!")

		"ATKPenaltyFaction":
			# e.g. The Pig: Decreases ATK of opposite creatures matching faction
			var debuff = val2 if val2 > 0 else (val1 if val1 > 0 else 1)
			var target_fac = for_faction.to_lower()
			var opp_lanes = _get_opponent_lanes() if is_player else _get_player_lanes()
			var count = 0
			for opp in opp_lanes:
				if opp.has_creature:
					var fac = opp.creature_data.get("faction", "").to_lower()
					if target_fac == "" or fac == target_fac:
						opp.modify_atk(-debuff)
						count += 1
			_log("Floop: %d enemy creature(s) suffered -%d ATK!" % [count, debuff])

		"SelfAndAdjacentATKBonus":
			var buff = val1 if val1 > 0 else 3
			source_lane.modify_atk(buff)
			var adj_lanes = _get_adjacent_lanes(source_lane)
			for adj in adj_lanes:
				if adj.has_creature:
					adj.modify_atk(buff)
			_log("Floop: %s and adjacent lanes gained +%d ATK!" % [card_name, buff])

		"LandscapeATKBonus":
			# Gains +val1 ATK per friendly matching landscape
			var buff_per = val1 if val1 > 0 else 1
			var match_fac = source_lane.landscape
			var match_count = 0
			var lanes = _get_player_lanes() if is_player else _get_opponent_lanes()
			for l in lanes:
				if l.landscape == match_fac:
					match_count += 1
			var total_buff = match_count * buff_per
			source_lane.modify_atk(total_buff)
			_log("Floop: %s gained +%d ATK (%d matching %s landscapes)!" % [card_name, total_buff, match_count, match_fac])

		"CardsATKBonus":
			# Gains +val1 ATK per card in hand
			var buff_per = val1 if val1 > 0 else 1
			var hand_size = _get_hand_size(is_player)
			var total_buff = hand_size * buff_per
			source_lane.modify_atk(total_buff)
			_log("Floop: %s gained +%d ATK from %d cards in hand!" % [card_name, total_buff, hand_size])

		"ATKBonusDamageSelf":
			var buff = val1 if val1 > 0 else 2
			var self_dmg = val2 if val2 > 0 else 2
			source_lane.modify_atk(buff)
			source_lane.apply_damage(self_dmg)
			_log("Floop: %s gained +%d ATK but took %d recoil damage!" % [card_name, buff, self_dmg])

		"SwapATKDEF", "SwapATKDEFSelf":
			var cur_atk = source_lane.current_atk
			var cur_def = source_lane.current_def
			source_lane.current_atk = cur_def
			source_lane.current_def = cur_atk
			source_lane._update_card_display()
			_log("Floop: %s swapped ATK (%d) and DEF (%d)!" % [card_name, cur_def, cur_atk])

		"DrawCards", "DrawCardsSpell":
			var count = val1 if val1 > 0 else 1
			if is_player and battle_controller:
				for _i in range(count):
					battle_controller.draw_player_card()
			_log("Floop: Drew %d card(s)!" % count)

		"HealHero":
			var heal = val1 if val1 > 0 else 2
			_heal_friendly_hero(is_player, heal)
			_log("Floop: Restored %d HP to hero!" % heal)

		"DamageAll":
			var dmg = val1 if val1 > 0 else 2
			var opp_lanes = _get_opponent_lanes() if is_player else _get_player_lanes()
			for opp in opp_lanes:
				if opp.has_creature:
					opp.apply_damage(dmg)
			_log("Floop: Dealt %d damage to all opponent creatures!" % dmg)

		"HealTarget":
			var heal = val1 if val1 > 0 else 3
			source_lane.modify_def(heal)
			_log("Floop: %s healed for %d DEF!" % [card_name, heal])

		"ReturnOppnentToHand":
			var opp_lane = _get_opposing_lane(source_lane)
			if opp_lane and opp_lane.has_creature:
				var opp_name = opp_lane.creature_data.get("name", "Creature")
				opp_lane.clear_slot()
				_log("Floop: Returned opponent's %s to their hand!" % opp_name)

		"BlockFloop":
			var opp_lane = _get_opposing_lane(source_lane)
			if opp_lane and opp_lane.has_creature:
				opp_lane.set_flooped(true)
				_log("Floop: Froze opposing creature's Floop ability!" % [])

		"DamageHeroCards":
			var dmg_per = val1 if val1 > 0 else 1
			var hand_size = _get_hand_size(!is_player)
			var total_dmg = dmg_per * hand_size
			_damage_opposing_hero(is_player, total_dmg)
			_log("Floop: Dealt %d damage to opponent hero (%d cards in opponent hand)!" % [total_dmg, hand_size])

		_:
			# Default fallback
			source_lane.modify_atk(1)
			_log("Floop: %s gained +1 Attack!" % card_name)

	return true


## Recalculates passive aura bonuses (STATIC_AURA)
func recalculate_auras() -> void:
	if battle_controller == null:
		return
	# Reserved for Epic 4 terrain and building auras
	if battle_controller.has_method("_update_ui"):
		battle_controller._update_ui()


# --- Helper Methods ---

func _get_player_lanes() -> Array[LaneSlot]:
	if battle_controller and "player_lanes" in battle_controller:
		return battle_controller.player_lanes
	return []


func _get_opponent_lanes() -> Array[LaneSlot]:
	if battle_controller and "opponent_lanes" in battle_controller:
		return battle_controller.opponent_lanes
	return []


func _get_opposing_lane(lane: LaneSlot) -> LaneSlot:
	if battle_controller == null or lane == null:
		return null
	var idx = lane.lane_index
	if lane.is_player:
		var opps = _get_opponent_lanes()
		return opps[idx] if idx < opps.size() else null
	else:
		var players = _get_player_lanes()
		return players[idx] if idx < players.size() else null


func _get_adjacent_lanes(lane: LaneSlot) -> Array[LaneSlot]:
	var result: Array[LaneSlot] = []
	if lane == null:
		return result
	var lanes = _get_player_lanes() if lane.is_player else _get_opponent_lanes()
	var idx = lane.lane_index
	for offset in [-1, 1]:
		var target_idx = idx + offset
		if target_idx >= 0 and target_idx < lanes.size():
			result.append(lanes[target_idx])
	return result


func _get_hand_size(is_player: bool) -> int:
	if battle_controller:
		if is_player and "hand_container" in battle_controller and battle_controller.hand_container:
			return battle_controller.hand_container.get_child_count()
		elif not is_player and "opponent_draw_pile" in battle_controller:
			return battle_controller.opponent_draw_pile.size()
	return 0


func _damage_opposing_hero(from_player: bool, amount: int) -> void:
	if battle_controller == null:
		return
	if from_player and "opponent_hp" in battle_controller:
		battle_controller.opponent_hp = max(0, battle_controller.opponent_hp - amount)
	elif not from_player and "player_hp" in battle_controller:
		battle_controller.player_hp = max(0, battle_controller.player_hp - amount)
	if battle_controller.has_method("_update_ui"):
		battle_controller._update_ui()


func _heal_friendly_hero(is_player: bool, amount: int) -> void:
	if battle_controller == null:
		return
	if is_player and "player_hp" in battle_controller:
		var max_hp = battle_controller.player_max_hp if "player_max_hp" in battle_controller else 25
		battle_controller.player_hp = min(max_hp, battle_controller.player_hp + amount)
	elif not is_player and "opponent_hp" in battle_controller:
		var max_hp = battle_controller.opponent_max_hp if "opponent_max_hp" in battle_controller else 25
		battle_controller.opponent_hp = min(max_hp, battle_controller.opponent_hp + amount)
	if battle_controller.has_method("_update_ui"):
		battle_controller._update_ui()


func _log(msg: String) -> void:
	if battle_controller and battle_controller.has_method("log_message"):
		battle_controller.log_message(msg)
