extends Node

signal match_state_changed(new_state)
signal player_currencies_updated(coins: int, gems: int)
signal hero_leveled_up(hero_id: String, old_level: int, new_level: int, new_max_hp: int)
signal chest_opened(chest_type: String, rolls: Array)
signal quest_completed(quest_id: String, stars: int, rewards: Dictionary)

enum MatchState {
	MENU,
	BATTLE,
	VICTORY,
	DEFEAT
}

const CurrencyWallet = preload("res://src/systems/progression_engine/CurrencyWallet.gd")
const ProgressionTracker = preload("res://src/systems/progression_engine/ProgressionTracker.gd")
const GachaRoller = preload("res://src/systems/progression_engine/GachaRoller.gd")
const NodeMapGraph = preload("res://src/systems/node_map_system/NodeMapGraph.gd")
const StarConditionEvaluator = preload("res://src/systems/node_map_system/StarConditionEvaluator.gd")
const MatchRulesConfig = preload("res://src/systems/local_multiplayer/MatchRulesConfig.gd")
const LanDiscovery = preload("res://src/systems/network_multiplayer/LanDiscovery.gd")
const NetworkSessionManager = preload("res://src/systems/network_multiplayer/NetworkSessionManager.gd")
const TurnActionProtocol = preload("res://src/systems/network_multiplayer/TurnActionProtocol.gd")

# Local Multiplayer & Gamepad (SYS-10 / Epic 5)
var match_rules: MatchRulesConfig
var is_local_versus: bool = false

# Network LAN Multiplayer (SYS-11 / Task 5.2)
var is_network_match: bool = false
var is_network_host: bool = false
var network_session: NetworkSessionManager = null
var network_protocol: TurnActionProtocol = null
var network_discovery: LanDiscovery = null
var remote_player_name: String = "Opponent"
var remote_hero_name: String = "Jake"
var remote_deck: Array[String] = []
var remote_landscapes: Array[String] = []

var current_state: MatchState = MatchState.MENU

# Default Player Deck (Finn's deck)
var player_deck: Array[String] = [
	"Creature_Pig",
	"Creature_CoolDog",
	"Creature_AngelEye",
	"Creature_AncientScholar",
	"Creature_Pig",
	"Creature_CoolDog",
	"Creature_AngelEye",
	"Spell_CerebralBloodstorm",
	"Building_RedDome",
	"Creature_Axey"
]

# Default Opponent Deck (Jake's deck)
var opponent_deck: Array[String] = [
	"Creature_Cornball",
	"Creature_HuskerKnight",
	"Creature_ArcherDan",
	"Creature_CornRonin",
	"Creature_CactusThug",
	"Creature_HuskerKnight",
	"Creature_ArcherDan",
	"Spell_PieStorm",
	"Creature_MaizeWalker",
	"Creature_Cornball"
]

var player_hero_name: String = "Finn"
var player_hero_max_hp: int = 25
var player_landscapes: Array[String] = ["Plains", "Plains", "Cotton", "Plains"]

var opponent_hero_name: String = "Jake"
var opponent_hero_max_hp: int = 25
var opponent_landscapes: Array[String] = ["Corn", "Corn", "Sand", "Corn"]

# Wheel mode: "NORMAL" (interactive roulette), "QUICK" (auto quick-resolve)
var wheel_mode: String = "NORMAL"

# Session & persistent rewards
var _raw_player_coins: int = 5000
var player_coins: int:
	get:
		if wallet:
			return wallet.get_balance("coins")
		return _raw_player_coins
	set(val):
		_raw_player_coins = val
		if wallet:
			var curr = wallet.get_balance("coins")
			var diff = val - curr
			if diff > 0:
				wallet.deposit("coins", diff)
			elif diff < 0:
				wallet.withdraw("coins", -diff)
var player_inventory_cards: Array[String] = []
var owned_card_counts: Dictionary = {}
var active_deck_name: String = "Finn Starter Deck"

# Core Economy & Progression Systems (SYS-8)
var wallet: CurrencyWallet
var hero_trackers: Dictionary = {}
var gacha_roller: GachaRoller

# Campaign & World Map System (SYS-9)
var campaign_graph: NodeMapGraph
var active_quest_id: String = ""

# Star Milestones & Rewards (Task 7.2)
const STAR_MILESTONES: Array[Dictionary] = [
	{"stars": 5, "type": "coins", "amount": 5000, "label": "5 ⭐ Milestone: 5,000 Coins"},
	{"stars": 15, "type": "gems", "amount": 5, "label": "15 ⭐ Milestone: 5 Gems"},
	{"stars": 30, "type": "chest", "chest_type": "cool_chest", "amount": 1, "label": "30 ⭐ Milestone: Free Cool Chest"},
	{"stars": 50, "type": "gems", "amount": 10, "label": "50 ⭐ Milestone: 10 Gems"},
	{"stars": 75, "type": "coins", "amount": 25000, "label": "75 ⭐ Milestone: 25,000 Coins"},
	{"stars": 100, "type": "chest", "chest_type": "algebraic_chest", "amount": 1, "label": "100 ⭐ Milestone: Free Algebraic Chest"},
	{"stars": 150, "type": "gems", "amount": 25, "label": "150 ⭐ Milestone: 25 Gems"},
	{"stars": 200, "type": "chest", "chest_type": "algebraic_chest", "amount": 3, "label": "200 ⭐ Milestone: 3x Algebraic Chests"}
]
var claimed_star_milestones: Array[int] = []

const DEFAULT_PROFILE_PATH: String = "user://player_profile.json"


func _ready() -> void:
	_init_wallet()
	_init_gacha()
	_init_campaign()
	load_profile()
	_update_active_hero_hp()


# ==============================================================================
# WALLET & CURRENCY METHODS
# ==============================================================================

func _init_wallet() -> void:
	if wallet == null:
		wallet = CurrencyWallet.new()
		wallet.register_currency("coins", player_coins, 99999999)
		wallet.register_currency("gems", 50, 999999)
		wallet.register_currency("energy", 100, 100)

		wallet.balance_changed.connect(func(cid, _old, new_bal):
			if cid == "coins":
				player_coins = new_bal
			player_currencies_updated.emit(get_coins(), get_gems())
		)


func get_coins() -> int:
	if wallet == null:
		_init_wallet()
	return wallet.get_balance("coins")


func get_gems() -> int:
	if wallet == null:
		_init_wallet()
	return wallet.get_balance("gems")


func add_coins(amount: int) -> int:
	if wallet == null:
		_init_wallet()
	var new_bal = wallet.deposit("coins", amount)
	player_coins = new_bal
	return new_bal


func spend_coins(amount: int) -> bool:
	if wallet == null:
		_init_wallet()
	var ok = wallet.withdraw("coins", amount)
	if ok:
		player_coins = wallet.get_balance("coins")
	return ok


func add_gems(amount: int) -> int:
	if wallet == null:
		_init_wallet()
	return wallet.deposit("gems", amount)


func spend_gems(amount: int) -> bool:
	if wallet == null:
		_init_wallet()
	return wallet.withdraw("gems", amount)


# ==============================================================================
# HERO LEVEL & PROGRESSION METHODS
# ==============================================================================

## Returns or initializes a ProgressionTracker for the given hero.
## Builds a 50-level XP table using Card Wars original formula: CeilToInt(LvIndex * pow(level * 1.02, 2.5)).
func get_hero_tracker(hero_id: String) -> ProgressionTracker:
	var hid = _normalize_hero_id(hero_id)
	if hero_trackers.has(hid):
		return hero_trackers[hid]

	# Build authentic Card Wars XP curve from db_LvUpScheme
	var scheme_id = "A"
	var leader_info = Database.get_leader(hid)
	if not leader_info.is_empty():
		scheme_id = str(leader_info.get("lv_up_scheme", "A"))

	var lv_index = Database.get_lvup_scheme_index(scheme_id)
	var xp_table: Array[int] = []
	for lvl in range(1, 50): # 49 steps from lvl 1 to 50
		var req = int(ceil(lv_index * pow(float(lvl) * 1.02, 2.5)))
		xp_table.append(maxi(100, req))

	var tracker = ProgressionTracker.new(50, 100, 2.5)
	tracker.set_custom_xp_table(xp_table)

	tracker.level_up.connect(func(old_lvl, new_lvl):
		var new_hp = get_hero_max_hp(hid)
		if hid == _normalize_hero_id(player_hero_name):
			player_hero_max_hp = new_hp
		hero_leveled_up.emit(hid, old_lvl, new_lvl, new_hp)
	)

	hero_trackers[hid] = tracker
	return tracker


func get_hero_level(hero_id: String) -> int:
	return get_hero_tracker(hero_id).current_level


func get_hero_xp(hero_id: String) -> int:
	return get_hero_tracker(hero_id).current_xp


## Awards XP to a hero. Returns progress telemetry dictionary.
func add_hero_xp(hero_id: String, amount: int) -> Dictionary:
	var tracker = get_hero_tracker(hero_id)
	var res = tracker.add_xp(amount)
	_update_active_hero_hp()
	return res


## Computes hero max HP: BaseHP (from db_Leaders) + (Level * 5).
func get_hero_max_hp(hero_id: String) -> int:
	var hid = _normalize_hero_id(hero_id)
	var leader_info = Database.get_leader(hid)
	var base_hp = 20
	if not leader_info.is_empty():
		base_hp = int(leader_info.get("base_hp", 20))
	var lvl = get_hero_level(hid)
	return base_hp + (lvl * 5)


## Retrieves the hero's maximum deck capacity from db_RankUp.json.
func get_hero_deck_max_size(hero_id: String) -> int:
	var lvl = get_hero_level(hero_id)
	var r_info = Database.get_rank_info(lvl)
	return int(r_info.get("deck_max_size", 25))


func _update_active_hero_hp() -> void:
	player_hero_max_hp = get_hero_max_hp(player_hero_name)


func _normalize_hero_id(hero_id: String) -> String:
	var hid = hero_id.strip_edges()
	if not hid.begins_with("Leader_") and Database.leaders_db.has("Leader_" + hid):
		return "Leader_" + hid
	return hid


# ==============================================================================
# PROFILE PERSISTENCE (SAVE / LOAD)
# ==============================================================================

## Serializes wallet balances, hero progression, decks, and inventory to JSON.
func save_profile(save_path: String = DEFAULT_PROFILE_PATH) -> bool:
	_init_wallet()
	var hero_data: Dictionary = {}
	for hid in hero_trackers.keys():
		var tr: ProgressionTracker = hero_trackers[hid]
		hero_data[hid] = tr.serialize()

	var profile_dict = {
		"version": 1,
		"wallet": wallet.serialize(),
		"heroes": hero_data,
		"gacha_pity": gacha_roller.serialize_pity() if gacha_roller != null else {},
		"campaign": campaign_graph.serialize() if campaign_graph != null else {},
		"claimed_star_milestones": claimed_star_milestones,
		"active_deck_name": active_deck_name,
		"player_hero_name": player_hero_name,
		"player_inventory_cards": player_inventory_cards,
		"owned_card_counts": owned_card_counts
	}

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(profile_dict, "\t"))
	return true


## Loads player profile from JSON file. Initializes defaults if missing.
func load_profile(save_path: String = DEFAULT_PROFILE_PATH) -> bool:
	_init_wallet()
	if not FileAccess.file_exists(save_path):
		# Default initial hero: Finn
		get_hero_tracker("Finn")
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false

	var data: Dictionary = json.data
	if data.has("wallet") and typeof(data["wallet"]) == TYPE_DICTIONARY:
		wallet.deserialize(data["wallet"])
		player_coins = wallet.get_balance("coins")

	if data.has("heroes") and typeof(data["heroes"]) == TYPE_DICTIONARY:
		for hid in data["heroes"].keys():
			var h_dict = data["heroes"][hid]
			if typeof(h_dict) == TYPE_DICTIONARY:
				var tr = get_hero_tracker(hid)
				tr.deserialize(h_dict)

	if data.has("active_deck_name"):
		active_deck_name = str(data["active_deck_name"])
	if data.has("player_hero_name"):
		player_hero_name = str(data["player_hero_name"])
	if data.has("player_inventory_cards") and typeof(data["player_inventory_cards"]) == TYPE_ARRAY:
		player_inventory_cards.clear()
		for c in data["player_inventory_cards"]:
			player_inventory_cards.append(str(c))
	if data.has("owned_card_counts") and typeof(data["owned_card_counts"]) == TYPE_DICTIONARY:
		owned_card_counts = data["owned_card_counts"].duplicate(true)
	if data.has("gacha_pity") and typeof(data["gacha_pity"]) == TYPE_DICTIONARY and gacha_roller != null:
		gacha_roller.deserialize_pity(data["gacha_pity"])
	if data.has("campaign") and typeof(data["campaign"]) == TYPE_DICTIONARY and campaign_graph != null:
		campaign_graph.deserialize(data["campaign"])
	if data.has("claimed_star_milestones") and typeof(data["claimed_star_milestones"]) == TYPE_ARRAY:
		claimed_star_milestones.clear()
		for m in data["claimed_star_milestones"]:
			claimed_star_milestones.append(int(m))

	_update_active_hero_hp()
	player_currencies_updated.emit(get_coins(), get_gems())
	return true


# ==============================================================================
# GACHA & CHEST LOOT BOXES
# ==============================================================================

func _init_gacha() -> void:
	if gacha_roller == null:
		gacha_roller = GachaRoller.new()
	var cool_items = Database.get_gacha_pool("cool_chest")
	var algebraic_items = Database.get_gacha_pool("algebraic_chest")
	if not cool_items.is_empty():
		gacha_roller.register_pool("cool_chest", cool_items)
	if not algebraic_items.is_empty():
		gacha_roller.register_pool("algebraic_chest", algebraic_items)
		gacha_roller.set_pity_rule("algebraic_chest", 10, "Gold")


func open_chest(chest_type: String, count: int = 1, rng: RandomNumberGenerator = null) -> Dictionary:
	_init_wallet()
	_init_gacha()

	var chest_def = Database.get_chest_def(chest_type)
	if chest_def.is_empty():
		return {
			"ok": false,
			"reason": "Unknown chest type: " + chest_type,
			"rolls": [],
			"card_ids": []
		}

	var unit_cost = int(chest_def.get("cost", 0))
	var total_cost = unit_cost * maxi(1, count)
	var currency_type = str(chest_def.get("currency", "coins"))
	var pool_name = str(chest_def.get("pool", ""))

	if not wallet.has_enough(currency_type, total_cost):
		return {
			"ok": false,
			"reason": "Insufficient %s (Need %d, have %d)" % [currency_type.capitalize(), total_cost, wallet.get_balance(currency_type)],
			"rolls": [],
			"card_ids": []
		}

	if not wallet.withdraw(currency_type, total_cost):
		return {
			"ok": false,
			"reason": "Failed to deduct %s" % currency_type,
			"rolls": [],
			"card_ids": []
		}

	var rolls = gacha_roller.roll_multi(pool_name, count, rng)
	var card_ids: Array[String] = []
	for r in rolls:
		var cid = str(r.get("id", ""))
		if cid != "":
			card_ids.append(cid)
			player_inventory_cards.append(cid)
			if not owned_card_counts.is_empty():
				owned_card_counts[cid] = int(owned_card_counts.get(cid, 0)) + 1

	save_profile()
	player_currencies_updated.emit(get_coins(), get_gems())
	chest_opened.emit(chest_type, rolls)

	return {
		"ok": true,
		"chest_type": chest_type,
		"chest_name": str(chest_def.get("name", chest_type)),
		"currency_spent": currency_type,
		"cost": total_cost,
		"rolls": rolls,
		"card_ids": card_ids
	}


func get_chest_pity(chest_type: String) -> int:
	_init_gacha()
	var chest_def = Database.get_chest_def(chest_type)
	var pool_name = str(chest_def.get("pool", chest_type))
	return gacha_roller.get_pity_count(pool_name)


# ==============================================================================
# REWARDS & GAMEPLAY INTEGRATION
# ==============================================================================

func add_rewards(coins: int, cards: Array[String], xp: int = 0) -> void:
	if coins > 0:
		add_coins(coins)
	if xp > 0:
		add_hero_xp(player_hero_name, xp)
	for c in cards:
		player_inventory_cards.append(c)
		if not owned_card_counts.is_empty():
			owned_card_counts[c] = int(owned_card_counts.get(c, 0)) + 1


func get_owned_card_counts() -> Dictionary:
	if owned_card_counts.is_empty():
		for c in Database.all_cards_list:
			var cid = str(c.get("id", ""))
			if cid != "":
				owned_card_counts[cid] = 4
		for c in player_inventory_cards:
			owned_card_counts[c] = int(owned_card_counts.get(c, 0)) + 1
	return owned_card_counts


func craft_fusion_recipe(recipe: Dictionary) -> Dictionary:
	var counts = get_owned_card_counts()
	var FusionEngine = preload("res://src/cards/FusionEngine.gd")
	var res = FusionEngine.execute_fusion(recipe, counts, get_coins())
	if res.get("ok", false):
		wallet.withdraw("coins", int(recipe.get("cost", 0)))
		var out_id = str(res.get("output_card_id", ""))
		if out_id != "":
			player_inventory_cards.append(out_id)
	return res


func apply_custom_deck(deck_data: Dictionary) -> void:
	if deck_data.is_empty():
		return
	active_deck_name = str(deck_data.get("name", "Custom Deck"))
	var leader_id = str(deck_data.get("leader", player_hero_name))
	if leader_id != "":
		player_hero_name = leader_id
		_update_active_hero_hp()

	var lands = deck_data.get("landscapes", [])
	if typeof(lands) == TYPE_ARRAY and lands.size() == 4:
		var typed_lands: Array[String] = []
		for l in lands:
			typed_lands.append(str(l))
		player_landscapes = typed_lands

	var cards_arr = deck_data.get("cards", [])
	if typeof(cards_arr) == TYPE_ARRAY and cards_arr.size() >= 10:
		var typed_cards: Array[String] = []
		for c in cards_arr:
			typed_cards.append(str(c))
		player_deck = typed_cards


func open_deck_builder() -> void:
	current_state = MatchState.MENU
	get_tree().change_scene_to_file("res://scenes/deck_builder.tscn")


func setup_local_versus_match(rules: MatchRulesConfig) -> void:
	match_rules = rules
	is_local_versus = true
	active_quest_id = ""

	player_hero_name = rules.p1_hero_id
	player_hero_max_hp = get_hero_max_hp(player_hero_name)
	player_deck = rules.p1_deck.duplicate()
	player_landscapes = rules.p1_landscapes.duplicate()

	opponent_hero_name = rules.p2_hero_id
	opponent_hero_max_hp = get_hero_max_hp(opponent_hero_name)
	opponent_deck = rules.p2_deck.duplicate()
	opponent_landscapes = rules.p2_landscapes.duplicate()


func setup_network_match(p_is_host: bool, local_hero: String, local_deck: Array[String], local_lands: Array[String], session: NetworkSessionManager, protocol: TurnActionProtocol, discovery: LanDiscovery = null) -> void:
	is_network_match = true
	is_network_host = p_is_host
	is_local_versus = false
	active_quest_id = ""

	network_session = session
	network_protocol = protocol
	network_discovery = discovery

	player_hero_name = local_hero
	player_hero_max_hp = get_hero_max_hp(player_hero_name)
	player_deck = local_deck.duplicate()
	player_landscapes = local_lands.duplicate()


func apply_remote_handshake(data: Dictionary) -> void:
	remote_player_name = str(data.get("player_name", "Remote Player"))
	remote_hero_name = str(data.get("hero", "Jake"))
	opponent_hero_name = remote_hero_name
	opponent_hero_max_hp = get_hero_max_hp(opponent_hero_name)

	var r_deck: Array[String] = []
	for c in data.get("deck", []):
		r_deck.append(str(c))
	if not r_deck.is_empty():
		opponent_deck = r_deck
		remote_deck = r_deck

	var r_lands: Array[String] = []
	for l in data.get("landscapes", []):
		r_lands.append(str(l))
	if not r_lands.is_empty():
		opponent_landscapes = r_lands
		remote_landscapes = r_lands


func start_battle() -> void:
	current_state = MatchState.BATTLE
	get_tree().call_deferred("change_scene_to_file", "res://scenes/battle.tscn")


func return_to_menu() -> void:
	is_local_versus = false
	if is_network_match:
		if network_discovery:
			network_discovery.stop()
		if network_session:
			network_session.close_session()
		is_network_match = false
	current_state = MatchState.MENU
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ==============================================================================
# CAMPAIGN PROGRESSION & QUEST MAP (SYS-9)
# ==============================================================================

func _init_campaign() -> void:
	if campaign_graph != null and not campaign_graph.get_all_nodes().is_empty():
		return
	if campaign_graph == null:
		campaign_graph = NodeMapGraph.new()

	for qid in Database.quests_db.keys():
		var q = Database.quests_db[qid]
		campaign_graph.add_node({
			"id": qid,
			"title": "Quest " + str(q.get("label", qid)),
			"position": q.get("position", Vector2.ZERO),
			"state": NodeMapGraph.NodeState.LOCKED,
			"prerequisites": q.get("prerequisites", []),
			"connections": q.get("unlock_ids", []),
			"conditions": q.get("conditions", []),
			"metadata": q
		})

	# Ensure Quest 1 starts UNLOCKED
	if campaign_graph.has_node("1"):
		campaign_graph.set_node_state("1", NodeMapGraph.NodeState.UNLOCKED)
	campaign_graph.evaluate_unlocks()


func complete_campaign_quest(quest_id: String, match_stats: Dictionary) -> Dictionary:
	_init_campaign()
	var quest = Database.get_quest(quest_id)
	if quest.is_empty():
		return {
			"ok": false,
			"reason": "Quest not found: " + quest_id,
			"stars": 0,
			"unlocked_quests": [],
			"rewards": {}
		}

	# Evaluate 3-star conditions
	var conditions = quest.get("conditions", [])
	var raw_stars = StarConditionEvaluator.count_stars_earned(conditions, match_stats)
	# Victory awards at least 1 star
	var stars_earned = clampi(maxi(1, raw_stars), 1, 3)
	var audit_report = StarConditionEvaluator.audit_star_conditions(conditions, match_stats)

	var comp_res = campaign_graph.complete_node(quest_id, stars_earned)

	# Compute rewards
	var min_c = int(quest.get("min_coins", 0))
	var max_c = int(quest.get("max_coins", 0))
	var awarded_coins = randi_range(min_c, max_c) if max_c >= min_c else min_c

	var min_xp = int(quest.get("min_xp", 0))
	var max_xp = int(quest.get("max_xp", 0))
	var awarded_xp = randi_range(min_xp, max_xp) if max_xp >= min_xp else min_xp

	var card_drops: Array[String] = []
	for cd in quest.get("card_drops", []):
		card_drops.append(str(cd))

	add_rewards(awarded_coins, card_drops, awarded_xp)
	save_profile()

	var rewards_dict = {
		"coins": awarded_coins,
		"xp": awarded_xp,
		"cards": card_drops
	}

	quest_completed.emit(quest_id, stars_earned, rewards_dict)

	return {
		"ok": true,
		"quest_id": quest_id,
		"stars": stars_earned,
		"first_clear": comp_res.get("first_clear", false),
		"unlocked_quests": comp_res.get("unlocked_nodes", []),
		"rewards": rewards_dict,
		"audit_report": audit_report
	}


func get_total_campaign_stars() -> int:
	if campaign_graph == null:
		_init_campaign()
	return campaign_graph.get_total_stars()


func can_claim_milestone(star_threshold: int) -> bool:
	if claimed_star_milestones.has(star_threshold):
		return false
	return get_total_campaign_stars() >= star_threshold


func claim_star_milestone(star_threshold: int) -> Dictionary:
	if not can_claim_milestone(star_threshold):
		return {"ok": false, "reason": "Milestone not available or already claimed"}

	var milestone: Dictionary = {}
	for m in STAR_MILESTONES:
		if int(m.get("stars", 0)) == star_threshold:
			milestone = m
			break
	if milestone.is_empty():
		return {"ok": false, "reason": "Unknown milestone"}

	claimed_star_milestones.append(star_threshold)

	var mtype = str(milestone.get("type", "coins"))
	var amt = int(milestone.get("amount", 0))
	if mtype == "coins":
		add_coins(amt)
	elif mtype == "gems":
		add_gems(amt)
	elif mtype == "chest":
		var ctype = str(milestone.get("chest_type", "cool_chest"))
		open_chest(ctype, amt)

	save_profile()
	return {"ok": true, "milestone": milestone}


func launch_quest_battle(quest_id: String) -> bool:
	_init_campaign()
	var quest = Database.get_quest(quest_id)
	if quest.is_empty():
		return false

	var node_data = campaign_graph.get_node(quest_id)
	if node_data.is_empty() or int(node_data.get("state", 0)) == NodeMapGraph.NodeState.LOCKED:
		return false

	# Deduct stamina
	var stamina_cost = int(quest.get("stamina", 1))
	if wallet and not wallet.withdraw("energy", stamina_cost):
		# If out of energy, refill to min 10 for test/offline convenience
		wallet.deposit("energy", stamina_cost)
		wallet.withdraw("energy", stamina_cost)

	active_quest_id = quest_id

	# Set opponent hero
	var opp_name = str(quest.get("opponent", "Jake"))
	if opp_name != "":
		opponent_hero_name = opp_name

	# Opponent Leader & Level
	var leader_lvl = int(quest.get("leader_level", 1))
	var base_hp = 25
	var leader_data = Database.leaders_db.get(quest.get("leader_id", ""), {})
	if not leader_data.is_empty():
		base_hp = int(leader_data.get("base_hp", 25))
	opponent_hero_max_hp = base_hp + (leader_lvl * 5)

	# Opponent Deck
	var deck_id = str(quest.get("deck_id", ""))
	if deck_id != "" and Database.preset_decks_db.has(deck_id):
		var raw_deck = Database.get_preset_deck(deck_id)
		if not raw_deck.is_empty():
			var typed_deck: Array[String] = []
			for c in raw_deck:
				typed_deck.append(str(c))
			opponent_deck = typed_deck

	start_battle()
	return true


func open_campaign_map() -> void:
	current_state = MatchState.MENU
	get_tree().change_scene_to_file("res://scenes/campaign_map.tscn")

