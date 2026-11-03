class_name LootRoller
extends RefCounted

## Utility class to resolve loot drops (Gold Bags, Card Chests, Tombstones) based on db_DropProfile.json.

static func roll_drop(
	drop_profile_id: String = "Quest01",
	drop_count: int = 0,
	candidate_cards: Array = [],
	force_type: String = ""
) -> Dictionary:
	var profile: Dictionary = {}
	if Engine.has_singleton("Database") or is_instance_valid(Database):
		profile = Database.get_drop_profile(drop_profile_id)
		if profile.is_empty() and not Database.drop_profiles_db.is_empty():
			# Fallback to first available profile
			profile = Database.drop_profiles_db.values()[0]

	# 1. Check if Card chest drops
	var should_drop_card = false
	if force_type == "CARD":
		should_drop_card = true
	elif force_type == "":
		var chest_pcts: Array = profile.get("chest_drop_percentages", [])
		if not chest_pcts.is_empty():
			var idx = clampi(drop_count, 0, chest_pcts.size() - 1)
			var pct = float(chest_pcts[idx])
			if pct > 0.0 and randf() <= pct:
				should_drop_card = true

	if should_drop_card:
		var card_weights: Array = profile.get("card_weights", [])
		var picked_card_id = _pick_weighted_card(candidate_cards, card_weights)
		var card_data: Dictionary = {}
		if Database and Database.cards_db.has(picked_card_id):
			card_data = Database.get_card(picked_card_id)
		elif candidate_cards.size() > 0 and typeof(candidate_cards[0]) == TYPE_DICTIONARY:
			card_data = candidate_cards[0]
			picked_card_id = card_data.get("id", "card_unknown")

		var card_name = card_data.get("name", "Mystery Card")
		return {
			"type": "CARD",
			"card_id": picked_card_id,
			"card_name": card_name,
			"amount": 1,
			"texture_path": "res://assets/textures/props/LootChest_01.png",
			"icon": "🎁",
			"label": "Card: %s" % card_name
		}

	# 2. Check if Gold bag drops
	var should_drop_gold = false
	if force_type == "GOLD":
		should_drop_gold = true
	elif force_type == "":
		var coin_pcts: Array = profile.get("coin_drop_percentages", [])
		if not coin_pcts.is_empty():
			var idx = clampi(drop_count, 0, coin_pcts.size() - 1)
			var pct = float(coin_pcts[idx])
			if pct > 0.0 and randf() <= pct:
				should_drop_gold = true

	if should_drop_gold:
		var coin_amounts: Array = profile.get("coin_amounts", [])
		var coin_weights: Array = profile.get("coin_weights", [])
		var gold_amount = _pick_weighted_coin(coin_amounts, coin_weights)
		if gold_amount <= 0:
			gold_amount = 25
		return {
			"type": "GOLD",
			"card_id": "",
			"card_name": "",
			"amount": gold_amount,
			"texture_path": "res://assets/textures/props/GoldBag.png",
			"icon": "💰",
			"label": "+%d 🪙" % gold_amount
		}

	# 3. Default: Empty Tombstone (no loot, just memorial)
	return {
		"type": "TOMBSTONE",
		"card_id": "",
		"card_name": "",
		"amount": 0,
		"texture_path": "res://assets/textures/props/Tombstone.png",
		"icon": "🪦",
		"label": "R.I.P."
	}

static func _pick_weighted_coin(amounts: Array, weights: Array) -> int:
	if amounts.is_empty():
		return 25
	if weights.is_empty() or amounts.size() != weights.size():
		return int(amounts[randi() % amounts.size()])

	var total_weight: int = 0
	for w in weights:
		total_weight += int(w)
	if total_weight <= 0:
		return int(amounts[0])

	var roll: int = randi() % total_weight
	var accum: int = 0
	for i in range(amounts.size()):
		accum += int(weights[i])
		if roll < accum:
			return int(amounts[i])
	return int(amounts[0])

static func _pick_weighted_card(candidate_cards: Array, weights: Array) -> String:
	# If candidate cards are provided as String IDs or Dictionaries
	if candidate_cards.is_empty():
		# Fallback to random card from Database
		if Database and not Database.creatures_list.is_empty():
			var c = Database.creatures_list[randi() % Database.creatures_list.size()]
			return c.get("id", "c_creature_01")
		return "c_creature_01"

	var list_size = candidate_cards.size()
	var total_weight: int = 0
	var clean_weights: Array[int] = []
	for i in range(list_size):
		var w = 10
		if i < weights.size():
			w = int(weights[i])
		clean_weights.append(w)
		total_weight += w

	if total_weight <= 0:
		return _extract_card_id(candidate_cards[0])

	var roll: int = randi() % total_weight
	var accum: int = 0
	for i in range(list_size):
		accum += clean_weights[i]
		if roll < accum:
			return _extract_card_id(candidate_cards[i])

	return _extract_card_id(candidate_cards[0])

static func _extract_card_id(item: Variant) -> String:
	if typeof(item) == TYPE_STRING:
		return str(item)
	elif typeof(item) == TYPE_DICTIONARY:
		return str(item.get("id", ""))
	return ""
