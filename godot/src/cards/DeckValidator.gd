class_name DeckValidator
extends RefCounted

## DeckValidator & Persistence Manager (Task 6.1)
## Enforces official Card Wars deck construction rules (10-25 cards, max 4 copies per card),
## computes mana cost distribution curves, filters card collections, and saves/loads custom decks
## to user://decks/*.json.

const MIN_DECK_SIZE: int = 10
const MAX_DECK_SIZE: int = 25
const MAX_COPIES_PER_CARD: int = 4
const DECKS_DIR: String = "user://decks"

const VALID_LANDSCAPES: Array[String] = ["Corn", "Plains", "Swamp", "Sand", "Cotton"]


## Validates a deck array of card IDs against official rules.
## Returns { "valid": bool, "errors": Array[String], "card_count": int, "counts_by_id": Dictionary }
static func validate_deck(
	cards: Array,
	owned_counts: Dictionary = {},
	enforce_ownership: bool = false
) -> Dictionary:
	var errors: Array[String] = []
	var counts_by_id: Dictionary = {}

	for raw_id in cards:
		var cid = str(raw_id).strip_edges()
		if cid == "":
			continue
		counts_by_id[cid] = counts_by_id.get(cid, 0) + 1

	var total_cards = cards.size()
	if total_cards < MIN_DECK_SIZE:
		errors.append("Deck has %d cards (minimum is %d)." % [total_cards, MIN_DECK_SIZE])
	elif total_cards > MAX_DECK_SIZE:
		errors.append("Deck has %d cards (maximum is %d)." % [total_cards, MAX_DECK_SIZE])

	for cid in counts_by_id.keys():
		var count: int = counts_by_id[cid]
		var card_info = Database.get_card(cid)
		var card_title = card_info.get("name", cid) if not card_info.is_empty() else cid
		if count > MAX_COPIES_PER_CARD:
			errors.append("Too many copies of '%s' (%d/%d max)." % [card_title, count, MAX_COPIES_PER_CARD])
		if enforce_ownership and not owned_counts.is_empty():
			var owned = int(owned_counts.get(cid, 0))
			if count > owned:
				errors.append("Not enough owned copies of '%s' (%d in deck, %d owned)." % [card_title, count, owned])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"card_count": total_cards,
		"counts_by_id": counts_by_id
	}


## Checks if a single card can be added to the given deck array.
## Returns { "can_add": bool, "reason": String }
static func can_add_card(
	cards: Array,
	card_id: String,
	owned_counts: Dictionary = {},
	enforce_ownership: bool = false
) -> Dictionary:
	if cards.size() >= MAX_DECK_SIZE:
		return {
			"can_add": false,
			"reason": "Deck is full (%d/%d cards)." % [cards.size(), MAX_DECK_SIZE]
		}

	var current_copies: int = 0
	for c in cards:
		if str(c) == card_id:
			current_copies += 1

	if current_copies >= MAX_COPIES_PER_CARD:
		return {
			"can_add": false,
			"reason": "Max %d copies per card reached (%d/%d)." % [MAX_COPIES_PER_CARD, current_copies, MAX_COPIES_PER_CARD]
		}

	if enforce_ownership and not owned_counts.is_empty():
		var owned = int(owned_counts.get(card_id, 0))
		if current_copies >= owned:
			return {
				"can_add": false,
				"reason": "All owned copies (%d) are already in deck." % owned
			}

	return {
		"can_add": true,
		"reason": ""
	}


## Computes the mana cost distribution for a deck array of card IDs.
## Bins: 0, 1, 2, 3, 4, 5 (where 5 represents 5+ MP cost).
static func compute_mana_curve(cards: Array) -> Dictionary:
	var curve: Dictionary = {
		0: 0,
		1: 0,
		2: 0,
		3: 0,
		4: 0,
		5: 0
	}
	for raw_id in cards:
		var cid = str(raw_id)
		var c_data = Database.get_card(cid)
		var cost = int(c_data.get("cost", 1))
		var bin = clampi(cost, 0, 5)
		curve[bin] = curve.get(bin, 0) + 1
	return curve


## Computes summary counts by card type (CREATURE, SPELL, BUILDING).
static func compute_type_breakdown(cards: Array) -> Dictionary:
	var breakdown: Dictionary = {
		"CREATURE": 0,
		"SPELL": 0,
		"BUILDING": 0
	}
	for raw_id in cards:
		var c_data = Database.get_card(str(raw_id))
		var c_type = str(c_data.get("type", "CREATURE"))
		breakdown[c_type] = breakdown.get(c_type, 0) + 1
	return breakdown


## Filters an array of card dictionaries by faction, card_type, cost, search query, and ownership.
## - faction_filter: "ALL" or specific faction ("Corn", "Plains", "Swamp", "Sand", "Cotton", "Universal")
## - type_filter: "ALL" or "CREATURE", "SPELL", "BUILDING"
## - cost_filter: -1 for all, 0..4 for exact cost, 5 for cost >= 5
static func filter_cards(
	all_cards: Array,
	faction_filter: String = "ALL",
	type_filter: String = "ALL",
	cost_filter: int = -1,
	search_query: String = "",
	owned_only: bool = false,
	owned_counts: Dictionary = {}
) -> Array:
	var result: Array = []
	var q_lower = search_query.strip_edges().to_lower()
	var f_upper = faction_filter.strip_edges().to_upper()
	var t_upper = type_filter.strip_edges().to_upper()

	for card in all_cards:
		if typeof(card) != TYPE_DICTIONARY:
			continue

		if f_upper != "" and f_upper != "ALL":
			if str(card.get("faction", "")).to_upper() != f_upper:
				continue

		if t_upper != "" and t_upper != "ALL":
			if str(card.get("type", "")).to_upper() != t_upper:
				continue

		if cost_filter >= 0:
			var c_cost = int(card.get("cost", 0))
			if cost_filter >= 5:
				if c_cost < 5:
					continue
			else:
				if c_cost != cost_filter:
					continue

		if q_lower != "":
			var c_name = str(card.get("name", "")).to_lower()
			var c_desc = str(card.get("desc", "")).to_lower()
			var c_id = str(card.get("id", "")).to_lower()
			if not (q_lower in c_name or q_lower in c_desc or q_lower in c_id):
				continue

		if owned_only:
			var cid = str(card.get("id", ""))
			if int(owned_counts.get(cid, 0)) <= 0:
				continue

		result.append(card)

	return result


## Sanitizes a deck name into a safe filename slug.
static func sanitize_filename(deck_name: String) -> String:
	var clean = deck_name.strip_edges()
	if clean == "":
		clean = "custom_deck"
	var out = ""
	for i in range(clean.length()):
		var ch = clean[i]
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			out += ch
		elif ch == " ":
			out += "_"
	if out == "":
		out = "custom_deck"
	return out.to_lower()


## Ensures user://decks directory exists.
static func ensure_decks_dir(custom_dir: String = DECKS_DIR) -> bool:
	if DirAccess.dir_exists_absolute(custom_dir):
		return true
	var err = DirAccess.make_dir_recursive_absolute(custom_dir)
	return err == OK


## Saves a deck payload to user://decks/<slug>.json.
## Refuses to save if the deck fails validation.
## Returns { "ok": bool, "path": String, "errors": Array[String] }
static func save_deck_to_file(
	deck_name: String,
	leader_id: String,
	landscapes: Array,
	cards: Array,
	custom_dir: String = DECKS_DIR
) -> Dictionary:
	var validation = validate_deck(cards)
	if not validation.get("valid", false):
		return {
			"ok": false,
			"path": "",
			"errors": validation.get("errors", ["Invalid deck."])
		}

	var trimmed_name = deck_name.strip_edges()
	if trimmed_name == "":
		trimmed_name = "Custom Deck"

	var normalized_landscapes: Array[String] = []
	for i in range(4):
		if i < landscapes.size() and str(landscapes[i]) in VALID_LANDSCAPES:
			normalized_landscapes.append(str(landscapes[i]))
		else:
			normalized_landscapes.append("Plains")

	var normalized_cards: Array[String] = []
	for c in cards:
		normalized_cards.append(str(c))

	ensure_decks_dir(custom_dir)
	var slug = sanitize_filename(trimmed_name)
	var file_path = custom_dir.path_join(slug + ".json")

	var payload: Dictionary = {
		"name": trimmed_name,
		"slug": slug,
		"leader": leader_id if leader_id != "" else "Finn",
		"landscapes": normalized_landscapes,
		"cards": normalized_cards,
		"updated_at": int(Time.get_unix_time_from_system())
	}

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"path": file_path,
			"errors": ["Failed to open '%s' for writing." % file_path]
		}

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	return {
		"ok": true,
		"path": file_path,
		"errors": [],
		"payload": payload
	}


## Loads a deck dictionary from a JSON file path or deck slug.
static func load_deck_from_file(path_or_slug: String, custom_dir: String = DECKS_DIR) -> Dictionary:
	var file_path = path_or_slug
	if not file_path.begins_with("user://") and not file_path.begins_with("res://") and not file_path.begins_with("/"):
		var clean_slug = sanitize_filename(path_or_slug.trim_suffix(".json"))
		file_path = custom_dir.path_join(clean_slug + ".json")

	if not FileAccess.file_exists(file_path):
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}

	return json.data


## Lists all saved deck dictionaries inside user://decks/*.json.
static func list_saved_decks(custom_dir: String = DECKS_DIR) -> Array[Dictionary]:
	ensure_decks_dir(custom_dir)
	var decks: Array[Dictionary] = []
	var dir = DirAccess.open(custom_dir)
	if dir == null:
		return decks

	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var full_path = custom_dir.path_join(fname)
			var data = load_deck_from_file(full_path, custom_dir)
			if not data.is_empty():
				data["file_path"] = full_path
				decks.append(data)
		fname = dir.get_next()
	dir.list_dir_end()

	decks.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return decks


## Deletes a saved deck file by slug or path.
static func delete_saved_deck(path_or_slug: String, custom_dir: String = DECKS_DIR) -> bool:
	var file_path = path_or_slug
	if not file_path.begins_with("user://") and not file_path.begins_with("res://") and not file_path.begins_with("/"):
		var clean_slug = sanitize_filename(path_or_slug.trim_suffix(".json"))
		file_path = custom_dir.path_join(clean_slug + ".json")

	if not FileAccess.file_exists(file_path):
		return false

	return DirAccess.remove_absolute(file_path) == OK
