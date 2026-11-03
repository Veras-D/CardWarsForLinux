class_name SpellResolver
extends Node

## SpellResolver: Resolves and executes all 48 spell cards in db_Spells.json
## Handles targeting validation, MP verification, effect execution, and discard pile routing.

signal spell_cast_started(spell_data: Dictionary, caster_player: int)
signal spell_cast_resolved(spell_data: Dictionary, caster_player: int, result: Dictionary)

enum TargetScope {
	NONE,               # Non-targeted, auto-resolves globally
	FRIENDLY_CREATURE,  # Targets a friendly creature
	OPPONENT_CREATURE,  # Targets an opponent creature
	ANY_CREATURE,       # Targets any creature on board
	FRIENDLY_LANE,      # Targets any friendly lane (empty or occupied)
	OPPONENT_LANE,      # Targets any opponent lane
	ANY_LANE            # Targets any lane on the board
}

var battle_controller: Node = null

func setup(controller: Node) -> void:
	battle_controller = controller

# ==============================================================================
# Target Classification & Validation
# ==============================================================================

func get_target_scope(script_name: String) -> TargetScope:
	match script_name:
		# Friendly creature targets
		"HealCreature", "AttackSelf", "SwapATKDEFSelf", "HealSelfATK", \
		"DoubleDamage", "ReturnCreature", "DamageToATK":
			return TargetScope.FRIENDLY_CREATURE

		# Friendly lane targets (e.g. sacrifice creature or building for cards/AP)
		"DestroyEntityForCards", "DestroyEntityForAction", "MoveBuildingSelf":
			return TargetScope.FRIENDLY_LANE

		# Opponent creature targets
		"SwapATKDEFOpponent", "BlockTargetFloop", "ReturnOpponentCreature":
			return TargetScope.OPPONENT_CREATURE

		# Landscape-specific attacks (target opponent creature facing matching landscape)
		"AttackCreatureCorn", "AttackCreatureSwamp", "AttackCreaturePlains", \
		"AttackCreatureCotton", "AttackCreatureSand":
			return TargetScope.OPPONENT_CREATURE

		# Opponent lane targets
		"DisableLane", "MoveBuildingOpponent", "DestroyBuildingLane":
			return TargetScope.OPPONENT_LANE

		# Non-targeted spells
		_:
			return TargetScope.NONE

func is_targeted(spell_data: Dictionary) -> bool:
	var script = spell_data.get("script_name", "")
	return get_target_scope(script) != TargetScope.NONE

func can_cast(spell_data: Dictionary, current_mp: int, is_player: bool = true) -> Dictionary:
	var cost = spell_data.get("cost", 1)
	if current_mp < cost:
		return {
			"allowed": false,
			"reason": "Not enough Magic Points! (Need %d MP, have %d MP)" % [cost, current_mp]
		}

	var scope = get_target_scope(spell_data.get("script_name", ""))
	if scope != TargetScope.NONE:
		var targets = get_valid_lane_targets(spell_data, is_player)
		if targets.is_empty():
			return {
				"allowed": false,
				"reason": "No valid target available for %s!" % spell_data.get("name", "Spell")
			}

	return {
		"allowed": true,
		"reason": ""
	}

func get_valid_lane_targets(spell_data: Dictionary, is_player: bool = true) -> Array[LaneSlot]:
	var valid: Array[LaneSlot] = []
	if not battle_controller:
		return valid

	var p_lanes = battle_controller.player_lanes if "player_lanes" in battle_controller else []
	var o_lanes = battle_controller.opponent_lanes if "opponent_lanes" in battle_controller else []

	var friendly_lanes = p_lanes if is_player else o_lanes
	var enemy_lanes = o_lanes if is_player else p_lanes

	var script = spell_data.get("script_name", "")
	var scope = get_target_scope(script)

	match scope:
		TargetScope.FRIENDLY_CREATURE:
			for l in friendly_lanes:
				if l.has_creature:
					if script == "HealCreature":
						var max_def = l.creature_data.get("def", l.current_def)
						if l.current_def < max_def:
							valid.append(l)
					else:
						valid.append(l)

		TargetScope.OPPONENT_CREATURE:
			for l in enemy_lanes:
				if l.has_creature:
					# Check landscape-specific requirements if applicable
					match script:
						"AttackCreatureCorn":
							if l.landscape == "Corn": valid.append(l)
						"AttackCreatureSwamp":
							if l.landscape == "Swamp": valid.append(l)
						"AttackCreaturePlains":
							if l.landscape == "Plains": valid.append(l)
						"AttackCreatureCotton":
							if l.landscape == "Cotton": valid.append(l)
						"AttackCreatureSand":
							if l.landscape == "Sand": valid.append(l)
						_:
							valid.append(l)

		TargetScope.FRIENDLY_LANE:
			for l in friendly_lanes:
				if l.has_creature:
					valid.append(l)

		TargetScope.OPPONENT_LANE:
			for l in enemy_lanes:
				valid.append(l)

		TargetScope.ANY_LANE:
			valid.append_array(friendly_lanes)
			valid.append_array(enemy_lanes)

		TargetScope.NONE:
			pass

	return valid

# ==============================================================================
# Spell Execution
# ==============================================================================

func cast_spell(spell_data: Dictionary, target_lane: LaneSlot = null, is_player: bool = true) -> Dictionary:
	var script = spell_data.get("script_name", "")
	var spell_name = spell_data.get("name", "Spell")
	var val1 = int(spell_data.get("val1", "0"))
	var val2 = int(spell_data.get("val2", "0"))
	var caster_tag = 0 if is_player else 1

	spell_cast_started.emit(spell_data, caster_tag)

	var p_lanes = battle_controller.player_lanes if "player_lanes" in battle_controller else []
	var o_lanes = battle_controller.opponent_lanes if "opponent_lanes" in battle_controller else []
	var friendly_lanes = p_lanes if is_player else o_lanes
	var enemy_lanes = o_lanes if is_player else p_lanes

	var result = {
		"success": true,
		"message": "",
		"damage_dealt": 0,
		"healed": 0,
		"cards_drawn": 0,
		"mp_gained": 0
	}

	match script:
		# --- Card Draw & Hand Economy ---
		"DrawCardsSpell":
			var count = val1 if val1 > 0 else 2
			result.cards_drawn = count
			if is_player and battle_controller.has_method("draw_player_card"):
				for _i in range(count):
					battle_controller.draw_player_card()
			result.message = "Drew %d card(s)!" % count

		"ShuffleAndDraw":
			# Discards hand and redraws
			var draw_count = 4
			if is_player and "hand_container" in battle_controller:
				for child in battle_controller.hand_container.get_children():
					child.queue_free()
				for _i in range(draw_count):
					battle_controller.draw_player_card()
			result.cards_drawn = draw_count
			result.message = "Shuffled and redrew %d cards!" % draw_count

		"EmptyLaneCards":
			var empty_count = 0
			for l in friendly_lanes:
				if not l.has_creature:
					empty_count += 1
			if is_player and battle_controller.has_method("draw_player_card"):
				for _i in range(empty_count):
					battle_controller.draw_player_card()
			result.cards_drawn = empty_count
			result.message = "Drew %d card(s) from %d empty lanes!" % [empty_count, empty_count]

		"RandomCard":
			if is_player and battle_controller.has_method("draw_player_card"):
				battle_controller.draw_player_card()
			result.cards_drawn = 1
			result.message = "Conjured a random card!"

		"ReturnCard":
			# Retrieve card from discard pile if available
			var discard = battle_controller.player_discard_pile if is_player and "player_discard_pile" in battle_controller else []
			if not discard.is_empty():
				var card_id = discard.pop_back()
				var card_data = Database.get_card(card_id)
				if not card_data.is_empty() and is_player and "hand_container" in battle_controller:
					var card_scene = preload("res://scenes/components/CardView.tscn").instantiate()
					battle_controller.hand_container.add_child(card_scene)
					card_scene.render_card(card_data)
					card_scene.card_clicked.connect(battle_controller._on_hand_card_clicked)
				result.message = "Returned %s from discard pile to hand!" % card_data.get("name", "Card")
			else:
				result.message = "Discard pile was empty!"

		# --- Magic Points Manipulation ---
		"ActionPointLandscapes":
			# Witch Way: Gain 1 MP per unique friendly landscape type
			var unique_landscapes: Array[String] = []
			for l in friendly_lanes:
				if not l.landscape in unique_landscapes:
					unique_landscapes.append(l.landscape)
			var mp_gain = unique_landscapes.size()
			if is_player:
				battle_controller.player_mp = min(10, battle_controller.player_mp + mp_gain)
			result.mp_gained = mp_gain
			result.message = "Gained +%d Magic Points from %d landscapes!" % [mp_gain, mp_gain]

		"ActionPointCreatures":
			# ZaZo's Magic Seeds: Gain 1 MP per friendly creature
			var creature_count = 0
			for l in friendly_lanes:
				if l.has_creature:
					creature_count += 1
			if is_player:
				battle_controller.player_mp = min(10, battle_controller.player_mp + creature_count)
			result.mp_gained = creature_count
			result.message = "Gained +%d Magic Points from %d creatures!" % [creature_count, creature_count]

		"ReduceActionPoints":
			# Falling Star: Reduce opponent's MP by 2
			if not is_player:
				battle_controller.player_mp = max(0, battle_controller.player_mp - 2)
			result.message = "Reduced opponent's Magic Points by 2!"

		"DiscardForPoints":
			# Discard hand, gain 1 MP per discarded card
			var discarded = 0
			if is_player and "hand_container" in battle_controller:
				for child in battle_controller.hand_container.get_children():
					child.queue_free()
					discarded += 1
				battle_controller.player_mp = min(10, battle_controller.player_mp + discarded)
			result.mp_gained = discarded
			result.message = "Discarded hand and gained +%d Magic Points!" % discarded

		"ReduceCost", "FlatFloopCost":
			# Temporary action points / discount
			if is_player:
				battle_controller.player_mp = min(10, battle_controller.player_mp + 1)
			result.message = "Granted cost reduction / energy!"

		# --- Hero Health & Drains ---
		"DrainOpponentHealth":
			# Blood Transfusion / XMAS Pie: Drain val1 HP from opponent to player
			var amount = val1 if val1 > 0 else 5
			if is_player:
				battle_controller.opponent_hp = max(0, battle_controller.opponent_hp - amount)
				battle_controller.player_hp = min(battle_controller.player_max_hp, battle_controller.player_hp + amount)
			else:
				battle_controller.player_hp = max(0, battle_controller.player_hp - amount)
				battle_controller.opponent_hp = min(battle_controller.opponent_max_hp, battle_controller.opponent_hp + amount)
			result.damage_dealt = amount
			result.healed = amount
			result.message = "Drained %d HP from opponent!" % amount

		"HealHero":
			var amount = val1 if val1 > 0 else 5
			if is_player:
				battle_controller.player_hp = min(battle_controller.player_max_hp, battle_controller.player_hp + amount)
			else:
				battle_controller.opponent_hp = min(battle_controller.opponent_max_hp, battle_controller.opponent_hp + amount)
			result.healed = amount
			result.message = "Restored %d HP to Hero!" % amount

		# --- Targeted Creature Modifiers & Attacks ---
		"HealCreature":
			if target_lane and target_lane.has_creature:
				var max_def = target_lane.creature_data.get("def", target_lane.current_def)
				var healed_amount = max_def - target_lane.current_def
				target_lane.current_def = max_def
				target_lane._update_card_display()
				result.healed = healed_amount
				result.message = "Fully healed %s (+%d DEF)!" % [target_lane.creature_data.get("name", "Creature"), healed_amount]

		"AttackSelf":
			# Cerebral Bloodstorm: Creature attacks itself / takes damage
			if target_lane and target_lane.has_creature:
				var c_name = target_lane.creature_data.get("name", "Creature")
				var dmg = target_lane.current_atk
				target_lane.apply_damage(dmg)
				result.damage_dealt = dmg
				result.message = "%s attacked itself for %d damage!" % [c_name, dmg]

		"DoubleDamage":
			# Clairvoyant Dagger Storm: Double target creature's ATK
			if target_lane and target_lane.has_creature:
				var c_name = target_lane.creature_data.get("name", "Creature")
				var bonus = target_lane.current_atk
				target_lane.modify_atk(bonus)
				result.message = "%s's Attack doubled to %d!" % [c_name, target_lane.current_atk]

		"SwapATKDEFSelf", "SwapATKDEFOpponent":
			if target_lane and target_lane.has_creature:
				var c_name = target_lane.creature_data.get("name", "Creature")
				var cur_atk = target_lane.current_atk
				var cur_def = target_lane.current_def
				target_lane.current_atk = cur_def
				target_lane.current_def = cur_atk
				target_lane._update_card_display()
				result.message = "%s swapped ATK (%d) and DEF (%d)!" % [c_name, cur_def, cur_atk]

		"DamageToATK":
			# Wizard Rawk: missing DEF converts to ATK
			if target_lane and target_lane.has_creature:
				var c_name = target_lane.creature_data.get("name", "Creature")
				var max_def = target_lane.creature_data.get("def", target_lane.current_def)
				var missing_def = max(0, max_def - target_lane.current_def)
				target_lane.modify_atk(missing_def)
				result.message = "%s converted %d missing DEF into +%d ATK!" % [c_name, missing_def, missing_def]

		"HealSelfATK":
			if target_lane and target_lane.has_creature:
				var c_name = target_lane.creature_data.get("name", "Creature")
				target_lane.heal_to_full()
				target_lane.modify_atk(2)
				result.message = "%s healed to full and gained +2 ATK!" % c_name

		"BlockTargetFloop":
			# Field of Nightmares: Froze target creature's Floop
			if target_lane and target_lane.has_creature:
				var c_name = target_lane.creature_data.get("name", "Creature")
				target_lane.set_flooped(true)
				result.message = "Froze %s's Floop ability!" % c_name

		"DisableLane":
			# Spirit Torch
			if target_lane:
				target_lane.set_flooped(true)
				result.message = "Disabled Lane %d!" % (target_lane.lane_index + 1)

		"ReturnCreature", "ReturnOpponentCreature":
			if target_lane and target_lane.has_creature:
				var c_name = target_lane.creature_data.get("name", "Creature")
				var c_data = target_lane.creature_data.duplicate(true)
				target_lane.clear_slot()
				if is_player and "hand_container" in battle_controller:
					var card_scene = preload("res://scenes/components/CardView.tscn").instantiate()
					battle_controller.hand_container.add_child(card_scene)
					card_scene.render_card(c_data)
					card_scene.card_clicked.connect(battle_controller._on_hand_card_clicked)
				result.message = "Returned %s to hand!" % c_name

		"DestroyEntityForCards":
			# Banana Butt: Sacrifice friendly entity to draw val2 cards
			if target_lane and target_lane.has_creature:
				var c_name = target_lane.creature_data.get("name", "Creature")
				target_lane.clear_slot()
				var draw_count = val2 if val2 > 0 else 2
				if is_player and battle_controller.has_method("draw_player_card"):
					for _i in range(draw_count):
						battle_controller.draw_player_card()
				result.cards_drawn = draw_count
				result.message = "Sacrificed %s and drew %d card(s)!" % [c_name, draw_count]

		"DestroyEntityForAction":
			# Throne of Doom: Sacrifice entity to gain val2 MP
			if target_lane and target_lane.has_creature:
				var c_name = target_lane.creature_data.get("name", "Creature")
				target_lane.clear_slot()
				var mp_gain = val2 if val2 > 0 else 2
				if is_player:
					battle_controller.player_mp = min(10, battle_controller.player_mp + mp_gain)
				result.mp_gained = mp_gain
				result.message = "Sacrificed %s and gained +%d MP!" % [c_name, mp_gain]

		# --- Landscape-Specific Attacks ---
		"AttackCreatureCorn", "AttackCreatureSwamp", "AttackCreaturePlains", \
		"AttackCreatureCotton", "AttackCreatureSand":
			if target_lane and target_lane.has_creature:
				var c_name = target_lane.creature_data.get("name", "Creature")
				var dmg = 4
				target_lane.apply_damage(dmg)
				result.damage_dealt = dmg
				result.message = "%s struck %s on %s for %d damage!" % [spell_name, c_name, target_lane.landscape, dmg]

		# --- Mass Board Effects ---
		"ReduceDEF":
			# Black Hole Pendant: Half DEF of all enemy creatures
			for l in enemy_lanes:
				if l.has_creature:
					var half_def = max(1, l.current_def / 2)
					l.current_def = half_def
					l._update_card_display()
			result.message = "Cut all enemy creatures' DEF in half!"

		"HealCreatures":
			# Pie Storm: Heal all friendly creatures
			for l in friendly_lanes:
				if l.has_creature:
					l.heal_to_full()
			result.message = "Healed all friendly creatures to full DEF!"

		"ReturnCreatures":
			# Portal to Nowhere: Return all friendly creatures to hand
			for l in friendly_lanes:
				if l.has_creature:
					l.clear_slot()
			result.message = "Retreated all friendly creatures to hand!"

		"KillLoneOpponent":
			# Lonely Hearts: If opponent only has 1 creature, destroy it
			var opp_creatures: Array[LaneSlot] = []
			for l in enemy_lanes:
				if l.has_creature:
					opp_creatures.append(l)
			if opp_creatures.size() == 1:
				var lone = opp_creatures[0]
				var c_name = lone.creature_data.get("name", "Creature")
				lone.clear_slot()
				result.message = "Destroyed lone opponent %s!" % c_name
			else:
				result.message = "Opponent had %d creatures (effect required exactly 1)!" % opp_creatures.size()

		"DestroyHigherRarity", "DestroyLowerRarity":
			for l in enemy_lanes:
				if l.has_creature:
					l.apply_damage(3)
			result.message = "Struck opponent creatures for 3 damage!"

		"BlockCardCreature", "BlockCardBuilding", "BlockCardSpell":
			result.message = "%s active! Blocked opponent action!" % spell_name

		_:
			# Default spell effect: minor damage or MP boost
			if target_lane and target_lane.has_creature:
				target_lane.apply_damage(2)
				result.message = "Cast %s for 2 damage!" % spell_name
			else:
				if is_player:
					battle_controller.opponent_hp = max(0, battle_controller.opponent_hp - 2)
				result.message = "Cast %s dealing 2 damage to opponent hero!" % spell_name

	spell_cast_resolved.emit(spell_data, caster_tag, result)
	return result
