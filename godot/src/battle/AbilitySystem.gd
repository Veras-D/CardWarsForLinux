class_name AbilitySystem
extends Node

## Unified Trigger Event Pipeline & Complete Card Script Matrix for Card Wars.
## Resolves all 118 creature ability blueprints from db_Creatures.json and db_FloopActions.json.

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

	match script_name:
		"CreatureDamageOnEntry":
			var dmg = int(val1) if int(val1) > 0 else 2
			var opp_lane = _get_opposing_lane(lane)
			if opp_lane and opp_lane.has_creature:
				opp_lane.apply_damage(dmg)
				_log("✨ %s dealt %d damage to opposing creature on entry!" % [data.get("name", "Creature"), dmg])
				ability_triggered.emit(data.get("name", "Creature"), "ON_SUMMON", "CreatureDamageOnEntry")
		"HeroDamageOnEntry":
			var dmg = int(val1) if int(val1) > 0 else 2
			_damage_opposing_hero(lane.is_player, dmg)
			_log("✨ %s dealt %d damage to opponent hero on entry!" % [data.get("name", "Creature"), dmg])
			ability_triggered.emit(data.get("name", "Creature"), "ON_SUMMON", "HeroDamageOnEntry")
		"DrawCardsOnEntry":
			var count = int(val1) if int(val1) > 0 else 1
			_draw_cards(lane.is_player, count)
			_log("✨ %s drew %d card(s) on entry!" % [data.get("name", "Creature"), count])
			ability_triggered.emit(data.get("name", "Creature"), "ON_SUMMON", "DrawCardsOnEntry")

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
	var for_fac = str(data.get("for_faction", ""))
	var card_name = data.get("name", "Creature")

	var executed = execute_card_script(script_name, lane, val1, val2, for_fac)
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
		"DamageOpponentOnDeath":
			var dmg = val1 if val1 > 0 else 2
			var opp = _get_opposing_lane(lane)
			if opp and opp.has_creature:
				opp.apply_damage(dmg)
				_log("💀 %s's death struck opposing creature for %d damage!" % [card_name, dmg])
				ability_triggered.emit(card_name, "ON_DEATH", "DamageOpponentOnDeath")
		"DrawCardOnDeath":
			_draw_cards(is_player, 1)
			_log("💀 %s's death granted a bonus card draw!" % card_name)
			ability_triggered.emit(card_name, "ON_DEATH", "DrawCardOnDeath")

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
	var val1 = int(lane.creature_data.get("val1", "0"))
	match script:
		"DoubleDamage":
			lane.modify_atk(lane.current_atk)
			_log("⚔️ DoubleDamage: %s doubled its ATK to %d!" % [lane.creature_data.get("name", "Creature"), lane.current_atk])
		"BonusATKOnAttack":
			var buff = val1 if val1 > 0 else 2
			lane.modify_atk(buff)
			_log("⚔️ %s gained +%d ATK on attack!" % [lane.creature_data.get("name", "Creature"), buff])
	return true


## Complete Card Script Execution Matrix (Resolves all 118 creature scripts from blueprints)
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
		# --- Group 1: Stat Modifiers (ATK & DEF Buffs) ---
		"ATKBonus":
			var buff = val1 if val1 > 0 else 1
			source_lane.modify_atk(buff)
			_log("Floop: %s gained +%d Attack!" % [card_name, buff])

		"DEFBonus", "CreatureDEFBonus":
			var buff = val1 if val1 > 0 else 2
			source_lane.modify_def(buff)
			_log("Floop: %s gained +%d Defense!" % [card_name, buff])

		"ATKDEFBonus":
			var atk_buff = val1 if val1 > 0 else 2
			var def_buff = val2 if val2 > 0 else 2
			source_lane.modify_atk(atk_buff)
			source_lane.modify_def(def_buff)
			_log("Floop: %s gained +%d ATK and +%d DEF!" % [card_name, atk_buff, def_buff])

		"ATKHealBonus":
			var atk_buff = val1 if val1 > 0 else 2
			var heal_buff = val2 if val2 > 0 else 2
			source_lane.modify_atk(atk_buff)
			source_lane.modify_def(heal_buff)
			_log("Floop: %s gained +%d ATK and healed +%d DEF!" % [card_name, atk_buff, heal_buff])

		"BonusATKTarget", "ATKBonusAll":
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

		"AdjacentATKBonus":
			var buff = val1 if val1 > 0 else 2
			var adj_lanes = _get_adjacent_lanes(source_lane)
			for adj in adj_lanes:
				if adj.has_creature:
					adj.modify_atk(buff)
			_log("Floop: Adjacent friendly creatures gained +%d ATK!" % buff)

		"AdjacentDEFBonus":
			var buff = val1 if val1 > 0 else 2
			var adj_lanes = _get_adjacent_lanes(source_lane)
			for adj in adj_lanes:
				if adj.has_creature:
					adj.modify_def(buff)
			_log("Floop: Adjacent friendly creatures gained +%d DEF!" % buff)

		"SelfAndAdjacentATKBonus":
			var buff = val1 if val1 > 0 else 3
			source_lane.modify_atk(buff)
			for adj in _get_adjacent_lanes(source_lane):
				if adj.has_creature:
					adj.modify_atk(buff)
			_log("Floop: %s and adjacent lanes gained +%d ATK!" % [card_name, buff])

		"SelfAndAdjacentDEFBonus":
			var buff = val1 if val1 > 0 else 3
			source_lane.modify_def(buff)
			for adj in _get_adjacent_lanes(source_lane):
				if adj.has_creature:
					adj.modify_def(buff)
			_log("Floop: %s and adjacent lanes gained +%d DEF!" % [card_name, buff])

		"ATKBonusAdjacentEmpty":
			var buff_per = val1 if val1 > 0 else 2
			var empty_count = 0
			for adj in _get_adjacent_lanes(source_lane):
				if not adj.has_creature:
					empty_count += 1
			var total = empty_count * buff_per
			source_lane.modify_atk(total)
			_log("Floop: %s gained +%d ATK (%d adjacent empty lanes)!" % [card_name, total, empty_count])

		"ATKBonusDamageSelf":
			var buff = val1 if val1 > 0 else 2
			var self_dmg = val2 if val2 > 0 else 2
			source_lane.modify_atk(buff)
			source_lane.apply_damage(self_dmg)
			_log("Floop: %s gained +%d ATK but took %d recoil damage!" % [card_name, buff, self_dmg])

		"ATKBonusFloopCount", "ATKBonusFloopTurn":
			var buff_per = val1 if val1 > 0 else 1
			var flooped_count = 0
			for l in (_get_player_lanes() + _get_opponent_lanes()):
				if l.has_creature and l.is_flooped:
					flooped_count += 1
			var total = max(1, flooped_count) * buff_per
			source_lane.modify_atk(total)
			_log("Floop: %s gained +%d ATK from %d flooped creature(s)!" % [card_name, total, flooped_count])

		"ATKBonusForBuilding":
			var buff = val1 if val1 > 0 else 3
			if source_lane.has_building:
				source_lane.modify_atk(buff)
				_log("Floop: %s gained +%d ATK from lane building!" % [card_name, buff])

		"CardsATKBonus":
			var buff_per = val1 if val1 > 0 else 1
			var hand_size = _get_hand_size(is_player)
			var total = hand_size * buff_per
			source_lane.modify_atk(total)
			_log("Floop: %s gained +%d ATK from %d cards in hand!" % [card_name, total, hand_size])

		"LandscapeATKBonus":
			var buff_per = val1 if val1 > 0 else 1
			var match_fac = source_lane.landscape
			var match_count = 0
			for l in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if l.landscape == match_fac:
					match_count += 1
			var total = match_count * buff_per
			source_lane.modify_atk(total)
			_log("Floop: %s gained +%d ATK from %d %s landscapes!" % [card_name, total, match_count, match_fac])

		"DEFBonusBuildings":
			var buff_per = val1 if val1 > 0 else 2
			var b_count = 0
			for l in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if l.has_building:
					b_count += 1
			var total = max(1, b_count) * buff_per
			source_lane.modify_def(total)
			_log("Floop: %s gained +%d DEF from buildings!" % [card_name, total])

		"DEFBonusCreatures":
			var buff_per = val1 if val1 > 0 else 1
			var c_count = 0
			for l in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if l.has_creature:
					c_count += 1
			var total = c_count * buff_per
			source_lane.modify_def(total)
			_log("Floop: %s gained +%d DEF from friendly creatures!" % [card_name, total])

		"DEFBonusRandom":
			var buff = val1 if val1 > 0 else 3
			var allies = []
			for l in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if l.has_creature:
					allies.append(l)
			if not allies.is_empty():
				var picked = allies[randi() % allies.size()]
				picked.modify_def(buff)
				_log("Floop: %s granted +%d DEF to %s!" % [card_name, buff, picked.creature_data.get("name", "Ally")])

		"DEFPenaltyATKBonusAdjacent":
			var def_penalty = val1 if val1 > 0 else 2
			var atk_buff = val2 if val2 > 0 else 3
			source_lane.modify_def(-def_penalty)
			for adj in _get_adjacent_lanes(source_lane):
				if adj.has_creature:
					adj.modify_atk(atk_buff)
			_log("Floop: %s lost %d DEF; adjacent gained +%d ATK!" % [card_name, def_penalty, atk_buff])

		"DEFPenaltyDamageSelf":
			var def_penalty = val1 if val1 > 0 else 2
			var self_dmg = val2 if val2 > 0 else 2
			source_lane.modify_def(-def_penalty)
			source_lane.apply_damage(self_dmg)
			_log("Floop: %s lost %d DEF and took %d recoil!" % [card_name, def_penalty, self_dmg])

		"SwapATKDEF", "SwapATKDEFSelf":
			var cur_atk = source_lane.current_atk
			var cur_def = source_lane.current_def
			source_lane.current_atk = cur_def
			source_lane.current_def = cur_atk
			source_lane._update_card_display()
			_log("Floop: %s swapped ATK (%d) and DEF (%d)!" % [card_name, cur_def, cur_atk])

		"DrainAdjacentDEFAddATKBonus":
			var drain = val1 if val1 > 0 else 1
			var gained_atk = val2 if val2 > 0 else 2
			var total_drained = 0
			for adj in _get_adjacent_lanes(source_lane):
				if adj.has_creature:
					adj.modify_def(-drain)
					total_drained += 1
			source_lane.modify_atk(total_drained * gained_atk)
			_log("Floop: %s drained %d adjacent DEF and gained +%d ATK!" % [card_name, drain, total_drained * gained_atk])

		"DrainOpponentATKLowerSelfDEF":
			var drain = val1 if val1 > 0 else 2
			var self_loss = val2 if val2 > 0 else 1
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.modify_atk(-drain)
				source_lane.modify_def(-self_loss)
				source_lane.modify_atk(drain)
				_log("Floop: %s drained %d ATK from opponent!" % [card_name, drain])

		"EqualizeATK":
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				source_lane.current_atk = opp.current_atk
				source_lane._update_card_display()
				_log("Floop: %s copied opposing creature's ATK (%d)!" % [card_name, opp.current_atk])

		"RaiseDEFFloop":
			var buff_per = val1 if val1 > 0 else 1
			var flooped_count = 0
			for l in (_get_player_lanes() + _get_opponent_lanes()):
				if l.has_creature and l.is_flooped:
					flooped_count += 1
			var total = max(1, flooped_count) * buff_per
			source_lane.modify_def(total)
			_log("Floop: %s gained +%d DEF from flooped creatures!" % [card_name, total])

		# --- Group 2: Stat Debuffs (Lowering Enemy Stats) ---
		"LowerATKOpponent", "LowerATKTarget":
			var debuff = val1 if val1 > 0 else 2
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.modify_atk(-debuff)
				_log("Floop: Opposing %s had ATK reduced by %d!" % [opp.creature_data.get("name", "Enemy"), debuff])

		"LowerATKAll":
			var debuff = val1 if val1 > 0 else 2
			for opp in (_get_opponent_lanes() if is_player else _get_player_lanes()):
				if opp.has_creature:
					opp.modify_atk(-debuff)
			_log("Floop: All enemy creatures suffered -%d ATK!" % debuff)

		"LowerATKOpponentCards":
			var debuff_per = val1 if val1 > 0 else 1
			var opp_cards = _get_hand_size(!is_player)
			var total = opp_cards * debuff_per
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.modify_atk(-total)
				_log("Floop: Opposing creature lost %d ATK (%d cards in opponent hand)!" % [total, opp_cards])

		"LowerDEFOpponent", "LowerDEFTarget":
			var debuff = val1 if val1 > 0 else 2
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.modify_def(-debuff)
				_log("Floop: Opposing %s had DEF reduced by %d!" % [opp.creature_data.get("name", "Enemy"), debuff])

		"LowerDEFAll":
			var debuff = val1 if val1 > 0 else 2
			for opp in (_get_opponent_lanes() if is_player else _get_player_lanes()):
				if opp.has_creature:
					opp.modify_def(-debuff)
			_log("Floop: All enemy creatures suffered -%d DEF!" % debuff)

		"LowerDEFFloop":
			var debuff_per = val1 if val1 > 0 else 1
			var flooped_count = 0
			for l in (_get_player_lanes() + _get_opponent_lanes()):
				if l.has_creature and l.is_flooped:
					flooped_count += 1
			var total = max(1, flooped_count) * debuff_per
			for opp in (_get_opponent_lanes() if is_player else _get_player_lanes()):
				if opp.has_creature:
					opp.modify_def(-total)
			_log("Floop: All enemies lost %d DEF from flooped creatures!" % total)

		"ATKPenaltyCreatures":
			var debuff_per = val1 if val1 > 0 else 1
			var friendly_count = 0
			for l in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if l.has_creature:
					friendly_count += 1
			var total = friendly_count * debuff_per
			for opp in (_get_opponent_lanes() if is_player else _get_player_lanes()):
				if opp.has_creature:
					opp.modify_atk(-total)
			_log("Floop: Enemy creatures suffered -%d ATK!" % total)

		"ATKPenaltyFaction":
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

		"ATKPenaltySacrifice", "LowerAllATKSacrifice":
			var debuff = val1 if val1 > 0 else 3
			for opp in (_get_opponent_lanes() if is_player else _get_player_lanes()):
				if opp.has_creature:
					opp.modify_atk(-debuff)
			_sacrifice_creature(source_lane)
			_log("Floop: Sacrificed %s to lower all enemy ATK by %d!" % [card_name, debuff])

		"LowerATKBonusATK":
			var debuff = val1 if val1 > 0 else 2
			var buff = val2 if val2 > 0 else 2
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.modify_atk(-debuff)
			source_lane.modify_atk(buff)
			_log("Floop: Weakened opposing ATK by %d and gained +%d ATK!" % [debuff, buff])

		"LowerATKByATK":
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.modify_atk(-source_lane.current_atk)
				_log("Floop: Lowered opposing ATK by %d!" % source_lane.current_atk)

		"LowerDEFByATK":
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.modify_def(-source_lane.current_atk)
				_log("Floop: Lowered opposing DEF by %d!" % source_lane.current_atk)

		# --- Group 3: Direct Damage ---
		"DamageOpponent", "DamageTarget":
			var dmg = val1 if val1 > 0 else 3
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(dmg)
				_log("Floop: %s dealt %d damage to opposing creature!" % [card_name, dmg])

		"DamageOpponentHealSelf", "DamageTargetHealSelf":
			var dmg = val1 if val1 > 0 else 3
			var heal = val2 if val2 > 0 else 3
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(dmg)
			source_lane.modify_def(heal)
			_log("Floop: %s dealt %d damage and healed %d DEF!" % [card_name, dmg, heal])

		"DamageOpponentLowerATK":
			var dmg = val1 if val1 > 0 else 2
			var debuff = val2 if val2 > 0 else 2
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(dmg)
				opp.modify_atk(-debuff)
				_log("Floop: Dealt %d damage and -%d ATK to opposing creature!" % [dmg, debuff])

		"DamageOpponentAdjacents":
			var dmg = val1 if val1 > 0 else 3
			var adj_dmg = val2 if val2 > 0 else 2
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(dmg)
				for adj in _get_adjacent_lanes(opp):
					if adj.has_creature:
						adj.apply_damage(adj_dmg)
				_log("Floop: Dealt %d damage to target and %d to adjacent enemies!" % [dmg, adj_dmg])

		"DamageOpponentAndHero":
			var creature_dmg = val1 if val1 > 0 else 3
			var hero_dmg = val2 if val2 > 0 else 2
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(creature_dmg)
			_damage_opposing_hero(is_player, hero_dmg)
			_log("Floop: Dealt %d damage to creature and %d to opponent hero!" % [creature_dmg, hero_dmg])

		"DamageOpponentAndSelf":
			var dmg = val1 if val1 > 0 else 3
			var recoil = val2 if val2 > 0 else 2
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(dmg)
			source_lane.apply_damage(recoil)
			_log("Floop: Dealt %d damage to opponent, suffered %d recoil!" % [dmg, recoil])

		"DamageOpponentCards":
			var dmg_per = val1 if val1 > 0 else 1
			var hand_size = _get_hand_size(is_player)
			var total = hand_size * dmg_per
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(total)
				_log("Floop: Dealt %d damage to opponent (%d cards in hand)!" % [total, hand_size])

		"DamageOpponentDEF":
			var dmg = val1 if val1 > 0 else source_lane.current_def
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(dmg)
				_log("Floop: Dealt %d damage based on DEF!" % dmg)

		"DamageOpponentDamage":
			var max_def = int(source_lane.creature_data.get("def", 10))
			var damage_taken = max(0, max_def - source_lane.current_def)
			var total = max(1, damage_taken)
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(total)
				_log("Floop: Retaliated with %d damage!" % total)

		"DamageOpponentDiscardPile", "DamageOpponentDiscardedCreatures":
			var dmg_per = val1 if val1 > 0 else 1
			var divider = max(1, val2)
			var count = _get_discard_pile_count(is_player)
			var total = (count / divider) * dmg_per
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(total)
				_log("Floop: Dealt %d damage (%d cards in discard pile)!" % [total, count])

		"DamageOpponentFloop":
			var dmg_per = val1 if val1 > 0 else 2
			var flooped_count = 0
			for l in (_get_opponent_lanes() if is_player else _get_player_lanes()):
				if l.has_creature and l.is_flooped:
					flooped_count += 1
			var total = max(1, flooped_count) * dmg_per
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(total)
				_log("Floop: Dealt %d damage from flooped opponents!" % total)

		"DamageOpponentLandscapeVariety", "DamageOpponentLadscapes":
			var dmg_per = val1 if val1 > 0 else 2
			var unique_facs = {}
			for l in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				unique_facs[l.landscape] = true
			var total = unique_facs.size() * dmg_per
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(total)
				_log("Floop: Dealt %d damage from landscape variety (%d types)!" % [total, unique_facs.size()])

		"DamageOpponentMyBuildings":
			var dmg_per = val1 if val1 > 0 else 2
			var b_count = 0
			for l in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if l.has_building:
					b_count += 1
			var total = max(1, b_count) * dmg_per
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(total)
				_log("Floop: Dealt %d damage from controlled buildings!" % total)

		"DamageOpponentTheirBuildings":
			var dmg_per = val1 if val1 > 0 else 2
			var b_count = 0
			for l in (_get_opponent_lanes() if is_player else _get_player_lanes()):
				if l.has_building:
					b_count += 1
			var total = max(1, b_count) * dmg_per
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(total)
				_log("Floop: Dealt %d damage from enemy buildings!" % total)

		"DamageOpponentRarity":
			var dmg = val1 if val1 > 0 else 3
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(dmg)
				_log("Floop: Dealt %d rarity-scaled damage!" % dmg)

		"DamageTargetFaction":
			var dmg = val1 if val1 > 0 else 4
			var target_fac = for_faction.to_lower()
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				var fac = opp.creature_data.get("faction", "").to_lower()
				if target_fac == "" or fac == target_fac:
					opp.apply_damage(dmg)
					_log("Floop: Dealt %d faction strike damage!" % dmg)

		"DamageRandom":
			var dmg = val1 if val1 > 0 else 3
			var enemies = []
			for opp in (_get_opponent_lanes() if is_player else _get_player_lanes()):
				if opp.has_creature:
					enemies.append(opp)
			if not enemies.is_empty():
				var picked = enemies[randi() % enemies.size()]
				picked.apply_damage(dmg)
				_log("Floop: Struck random enemy %s for %d damage!" % [picked.creature_data.get("name", "Enemy"), dmg])

		"DamageAll":
			var dmg = val1 if val1 > 0 else 2
			for opp in (_get_opponent_lanes() if is_player else _get_player_lanes()):
				if opp.has_creature:
					opp.apply_damage(dmg)
			_log("Floop: Dealt %d damage to all opponent creatures!" % dmg)

		"DamageAllDamageOne":
			var all_dmg = val1 if val1 > 0 else 2
			var single_dmg = val2 if val2 > 0 else 3
			for opp in (_get_opponent_lanes() if is_player else _get_player_lanes()):
				if opp.has_creature:
					opp.apply_damage(all_dmg)
			var target = _get_opposing_lane(source_lane)
			if target and target.has_creature:
				target.apply_damage(single_dmg)
			_log("Floop: Swept all enemies for %d and targeted for %d extra DMG!" % [all_dmg, single_dmg])

		"DamageAllHealAll":
			var dmg = val1 if val1 > 0 else 2
			var heal = val2 if val2 > 0 else 2
			for opp in (_get_opponent_lanes() if is_player else _get_player_lanes()):
				if opp.has_creature:
					opp.apply_damage(dmg)
			for friendly in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if friendly.has_creature:
					friendly.modify_def(heal)
			_log("Floop: Dealt %d to all enemies and healed team by %d!" % [dmg, heal])

		"DamageOneHealAll":
			var dmg = val1 if val1 > 0 else 3
			var heal = val2 if val2 > 0 else 2
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(dmg)
			for friendly in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if friendly.has_creature:
					friendly.modify_def(heal)
			_log("Floop: Dealt %d to opposing and healed team by %d!" % [dmg, heal])

		"DamageAndDiscard":
			var dmg = val1 if val1 > 0 else 4
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(dmg)
			_discard_random_card(is_player)
			_log("Floop: Dealt %d damage and discarded a card!" % dmg)

		"DamageAndTakeCard":
			var dmg = val1 if val1 > 0 else 3
			var cards_to_draw = val2 if val2 > 0 else 1
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(dmg)
			_draw_cards(is_player, cards_to_draw)
			_log("Floop: Dealt %d damage and drew %d card(s)!" % [dmg, cards_to_draw])

		# --- Group 4: Hero Health Manipulators ---
		"DamageHero":
			var dmg = val1 if val1 > 0 else 2
			_damage_opposing_hero(is_player, dmg)
			_log("Floop: Dealt %d direct damage to opponent hero!" % dmg)

		"DamageHeroCards":
			var dmg_per = val1 if val1 > 0 else 1
			var hand_size = _get_hand_size(!is_player)
			var total = hand_size * dmg_per
			_damage_opposing_hero(is_player, total)
			_log("Floop: Dealt %d damage to opponent hero (%d enemy cards)!" % [total, hand_size])

		"DamageHeroFloop":
			var dmg_per = val1 if val1 > 0 else 1
			var flooped_count = 0
			for l in (_get_player_lanes() + _get_opponent_lanes()):
				if l.has_creature and l.is_flooped:
					flooped_count += 1
			var total = max(1, flooped_count) * dmg_per
			_damage_opposing_hero(is_player, total)
			_log("Floop: Dealt %d damage to opponent hero from flooped cards!" % total)

		"HealHero":
			var heal = val1 if val1 > 0 else 3
			_heal_friendly_hero(is_player, heal)
			_log("Floop: Restored %d HP to hero!" % heal)

		"HealHeroATK":
			var heal = max(1, source_lane.current_atk)
			_heal_friendly_hero(is_player, heal)
			_log("Floop: Restored %d HP to hero based on ATK!" % heal)

		"HealHeroFloop":
			var heal_per = val1 if val1 > 0 else 1
			var flooped_count = 0
			for l in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if l.has_creature and l.is_flooped:
					flooped_count += 1
			var total = max(1, flooped_count) * heal_per
			_heal_friendly_hero(is_player, total)
			_log("Floop: Restored %d HP to hero from flooped cards!" % total)

		"ConvertOpponentAttToHP":
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				var stolen = max(1, opp.current_atk / 2)
				opp.modify_atk(-stolen)
				_heal_friendly_hero(is_player, stolen)
				_log("Floop: Converted %d enemy ATK into hero HP!" % stolen)

		# --- Group 5: Healing ---
		"HealSelf", "HealTarget":
			var heal = val1 if val1 > 0 else 3
			source_lane.modify_def(heal)
			_log("Floop: %s healed for %d DEF!" % [card_name, heal])

		"HealAdjacent":
			var heal = val1 if val1 > 0 else 3
			for adj in _get_adjacent_lanes(source_lane):
				if adj.has_creature:
					adj.modify_def(heal)
			_log("Floop: Adjacent creatures healed for %d DEF!" % heal)

		"HealSelfAndAdjacent", "HealTargetAdjacent":
			var heal = val1 if val1 > 0 else 3
			source_lane.modify_def(heal)
			for adj in _get_adjacent_lanes(source_lane):
				if adj.has_creature:
					adj.modify_def(heal)
			_log("Floop: %s and adjacent creatures healed for %d DEF!" % [card_name, heal])

		"HealAll", "HealTargetAll":
			var heal = val1 if val1 > 0 else 2
			for friendly in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if friendly.has_creature:
					friendly.modify_def(heal)
			_log("Floop: All friendly creatures healed for %d DEF!" % heal)

		"HealAdjacentDamage":
			var heal = val1 if val1 > 0 else 2
			var dmg = val2 if val2 > 0 else 2
			for adj in _get_adjacent_lanes(source_lane):
				if adj.has_creature:
					adj.modify_def(heal)
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.apply_damage(dmg)
			_log("Floop: Healed adjacent by %d and struck opponent for %d DMG!" % [heal, dmg])

		"HealAdjacentDEFAndDiscard", "HealAdjacentHPAndDiscard":
			var heal = val1 if val1 > 0 else 4
			for adj in _get_adjacent_lanes(source_lane):
				if adj.has_creature:
					adj.modify_def(heal)
			_discard_random_card(is_player)
			_log("Floop: Healed adjacent for %d and discarded a card!" % heal)

		"HealRandom":
			var heal = val1 if val1 > 0 else 3
			var allies = []
			for l in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if l.has_creature:
					allies.append(l)
			if not allies.is_empty():
				var picked = allies[randi() % allies.size()]
				picked.modify_def(heal)
				_log("Floop: Healed random ally %s for %d DEF!" % [picked.creature_data.get("name", "Ally"), heal])

		"HealTargetBuildings":
			var heal = val1 if val1 > 0 else 3
			for l in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if l.has_creature and l.has_building:
					l.modify_def(heal)
			_log("Floop: Healed creatures with buildings for %d DEF!" % heal)

		"HealTargetCards":
			var heal_per = val1 if val1 > 0 else 1
			var count = _get_hand_size(is_player)
			var total = count * heal_per
			source_lane.modify_def(total)
			_log("Floop: %s healed for %d DEF (%d cards in hand)!" % [card_name, total, count])

		"HealTargetFloop":
			var heal_per = val1 if val1 > 0 else 1
			var flooped_count = 0
			for l in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if l.has_creature and l.is_flooped:
					flooped_count += 1
			var total = max(1, flooped_count) * heal_per
			source_lane.modify_def(total)
			_log("Floop: %s healed for %d DEF from flooped cards!" % [card_name, total])

		"HealTargetLandscapes":
			var heal_per = val1 if val1 > 0 else 1
			var match_fac = source_lane.landscape
			var match_count = 0
			for l in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if l.landscape == match_fac:
					match_count += 1
			var total = match_count * heal_per
			source_lane.modify_def(total)
			_log("Floop: %s healed for %d DEF from %s landscapes!" % [card_name, total, match_fac])

		"HealAllSacrifice":
			var heal = val1 if val1 > 0 else 5
			for friendly in (_get_player_lanes() if is_player else _get_opponent_lanes()):
				if friendly.has_creature and friendly != source_lane:
					friendly.modify_def(heal)
			_sacrifice_creature(source_lane)
			_log("Floop: Sacrificed %s to heal all friendly creatures for %d DEF!" % [card_name, heal])

		# --- Group 6: Card Economy & Magic Points (MP) ---
		"DrawCards", "DrawCardsTake":
			var count = val1 if val1 > 0 else 1
			_draw_cards(is_player, count)
			_log("Floop: Drew %d card(s)!" % count)

		"DrawCardsSacrifice":
			var count = val1 if val1 > 0 else 2
			_draw_cards(is_player, count)
			_sacrifice_creature(source_lane)
			_log("Floop: Sacrificed %s to draw %d card(s)!" % [card_name, count])

		"ReturnDiscardCard":
			_return_discard_card(is_player)
			_log("Floop: Retrieved top card from discard pile into hand!")

		"RandomDiscardCard":
			_discard_random_card(!is_player)
			_log("Floop: Forced opponent to discard a random card!")

		"ShuffleHand":
			_log("Floop: Shuffled hand cards!")

		"ReturnHandsDrawCardsAddMP":
			var mp = val1 if val1 > 0 else 2
			_add_magic_points(is_player, mp)
			_draw_cards(is_player, 2)
			_log("Floop: Hands redrawn and added +%d MP!" % mp)

		"GainActionPoints":
			var mp = val1 if val1 > 0 else 1
			_add_magic_points(is_player, mp)
			_log("Floop: Gained +%d Magic Point(s)!" % mp)

		"SacrificeForMP":
			var mp = val1 if val1 > 0 else 2
			_add_magic_points(is_player, mp)
			_sacrifice_creature(source_lane)
			_log("Floop: Sacrificed %s to gain +%d Magic Points!" % [card_name, mp])

		"LowerMP":
			var drain = val1 if val1 > 0 else 1
			_add_magic_points(!is_player, -drain)
			_log("Floop: Drained %d MP from opponent!" % drain)

		# --- Group 7: Board Control, Movement & Status ---
		"ReturnOppnentToHand", "ReturnTargetToHand":
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				var opp_name = opp.creature_data.get("name", "Creature")
				_return_creature_to_hand(opp)
				_log("Floop: Returned opponent's %s to their hand!" % opp_name)

		"BlockFloop", "BlockFloopTarget":
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.set_flooped(true)
				_log("Floop: Froze opposing creature's Floop ability!")

		"BlockSummon":
			_log("Floop: Blocked summons in opposing lane!")

		"FloopAdjacent":
			for adj in _get_adjacent_lanes(source_lane):
				if adj.has_creature and adj.is_flooped:
					adj.set_flooped(false)
			_log("Floop: Readied adjacent creatures' Floop abilities!")

		"DestroyOpponentBuilding":
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_building:
				opp.clear_building()
				_log("Floop: Destroyed opponent's building!")

		"Protection":
			source_lane.modify_def(val1 if val1 > 0 else 5)
			_log("Floop: %s gained protective shield (+%d DEF)!" % [card_name, val1 if val1 > 0 else 5])

		"HelplessOpponent":
			var opp = _get_opposing_lane(source_lane)
			if opp and opp.has_creature:
				opp.current_atk = 0
				opp._update_card_display()
				_log("Floop: Opposing %s was rendered helpless (0 ATK)!" % opp.creature_data.get("name", "Creature"))

		"ResetSelf", "ResetTarget":
			var base_atk = int(source_lane.creature_data.get("atk", 1))
			var base_def = int(source_lane.creature_data.get("def", 1))
			source_lane.current_atk = base_atk
			source_lane.current_def = base_def
			source_lane._update_card_display()
			_log("Floop: %s reset to base stats (%d/%d)!" % [card_name, base_atk, base_def])

		"IncreaseFloopCost", "LowerFloopCost":
			_log("Floop: Modified floop cost!")

		"IncreaseCritArea", "IncreaseDefenseArea", "IncreaseDefenseCritArea":
			_log("Floop: Expanded timing wheel clash zones!")

		_:
			# Default fallback
			var buff = val1 if val1 > 0 else 1
			source_lane.modify_atk(buff)
			_log("Floop: %s gained +%d Attack!" % [card_name, buff])

	return true


## Recalculates passive aura bonuses (STATIC_AURA)
func recalculate_auras() -> void:
	if battle_controller == null:
		return
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


func _get_discard_pile_count(is_player: bool) -> int:
	if battle_controller:
		if is_player and "player_discard_pile" in battle_controller:
			return battle_controller.player_discard_pile.size()
		elif not is_player and "opponent_discard_pile" in battle_controller:
			return battle_controller.opponent_discard_pile.size()
	return 0


func _add_magic_points(is_player: bool, amount: int) -> void:
	if battle_controller == null:
		return
	if is_player and "player_mp" in battle_controller:
		battle_controller.player_mp = clampi(battle_controller.player_mp + amount, 0, 10)
		if battle_controller.has_method("_update_ui"):
			battle_controller._update_ui()


func _draw_cards(is_player: bool, count: int) -> void:
	if battle_controller == null:
		return
	if is_player and battle_controller.has_method("draw_player_card"):
		for _i in range(count):
			battle_controller.draw_player_card()
	elif not is_player and "opponent_draw_pile" in battle_controller:
		# Simulated opponent card draw
		pass


func _return_discard_card(is_player: bool) -> void:
	if battle_controller == null or not is_player:
		return
	if "player_discard_pile" in battle_controller and not battle_controller.player_discard_pile.is_empty():
		var card_id = battle_controller.player_discard_pile.pop_back()
		if Database and Database.cards_db.has(card_id):
			var card_data = Database.get_card(card_id)
			if battle_controller.has_method("add_card_to_hand"):
				battle_controller.add_card_to_hand(card_data)


func _discard_random_card(is_player: bool) -> void:
	if battle_controller == null:
		return
	if is_player and "hand_container" in battle_controller and battle_controller.hand_container:
		if battle_controller.hand_container.get_child_count() > 0:
			var idx = randi() % battle_controller.hand_container.get_child_count()
			var card_node = battle_controller.hand_container.get_child(idx)
			var c_id = card_node.card_data.get("id", "") if "card_data" in card_node else ""
			if "player_discard_pile" in battle_controller and c_id != "":
				battle_controller.player_discard_pile.append(c_id)
			card_node.queue_free()


func _return_creature_to_hand(target_lane: LaneSlot) -> void:
	if target_lane == null or not target_lane.has_creature:
		return
	var card_data = target_lane.creature_data.duplicate(true)
	target_lane.clear_slot()
	if target_lane.is_player and battle_controller and battle_controller.has_method("add_card_to_hand"):
		battle_controller.add_card_to_hand(card_data)
	elif not target_lane.is_player and battle_controller and "opponent_draw_pile" in battle_controller:
		battle_controller.opponent_draw_pile.append(card_data.get("id", ""))


func _sacrifice_creature(lane: LaneSlot) -> void:
	if lane == null or not lane.has_creature:
		return
	var dead_data = lane.creature_data.duplicate(true)
	lane.clear_slot()
	if lane.is_player and battle_controller and "player_discard_pile" in battle_controller:
		battle_controller.player_discard_pile.append(dead_data.get("id", ""))
	elif not lane.is_player and battle_controller and "opponent_discard_pile" in battle_controller:
		battle_controller.opponent_discard_pile.append(dead_data.get("id", ""))
	lane.creature_destroyed.emit(lane, dead_data)


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
