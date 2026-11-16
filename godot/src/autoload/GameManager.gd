extends Node

signal match_state_changed(new_state)
signal player_currencies_updated(coins: int, gems: int)
signal hero_leveled_up(hero_id: String, old_level: int, new_level: int, new_max_hp: int)
signal chest_opened(chest_type: String, rolls: Array)
signal quest_completed(quest_id: String, stars: int, rewards: Dictionary)
signal leader_unlocked(leader_id: String)
signal inventory_capacity_changed(new_max_inventory: int)
signal elfisto_round_cleared(round_num: int, reward: Dictionary)
signal elfisto_run_ended(cleared_all: bool, final_round: int)

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
const SettingsManager = preload("res://src/systems/settings_vault/SettingsManager.gd")

# Settings Vault (SYS-12 / Task 9.1)
var settings_manager: SettingsManager = null

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

# Default Player Deck (Unity PlayerDeck1 — Jake's 12-card Corn/Swamp starter deck)
var player_deck: Array[String] = [
	"Creature_Cornball",
	"Creature_Cornball",
	"Creature_Cornball",
	"Creature_Cornball",
	"Creature_WanderingBaldMan",
	"Creature_WanderingBaldMan",
	"Creature_WanderingBaldMan",
	"Creature_BurningBush",
	"Creature_BurningBush",
	"Creature_Mouthball",
	"Creature_Mouthball",
	"Creature_Mouthball"
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

var player_hero_name: String = "Jake"
var player_hero_max_hp: int = 15
var player_landscapes: Array[String] = ["Corn", "Corn", "Corn", "Swamp"]
var unlocked_leaders: Array[String] = ["Leader_Jake"]

var opponent_hero_name: String = "Jake"
var opponent_hero_max_hp: int = 25
var opponent_landscapes: Array[String] = ["Corn", "Corn", "Sand", "Corn"]

# Wheel mode: "NORMAL" (interactive roulette), "QUICK" (auto quick-resolve)
var wheel_mode: String = "NORMAL"

# Session & persistent rewards (Unity db_Parameters: New_Player_Coins = 0, New_Player_Gems = 5, New_Player_Max_Stamina = 5)
var _raw_player_coins: int = 0
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
const DEFAULT_MAX_INVENTORY: int = 50
const MIN_CARDS_IN_INVENTORY: int = 10
const MIN_CREATURES_IN_INVENTORY: int = 10
const MAX_NUM_DECKS: int = 5
const MIN_CARDS_IN_DECK: int = 10
const MAX_DUPLICATES_IN_DECK: int = 4
const CARD_FORGE_UNLOCK_QUEST: String = "4"
var viewed_fusion_recipes: Array[String] = []
var max_inventory: int = DEFAULT_MAX_INVENTORY
var active_deck_name: String = "Deck 1"
var decks: Array[Dictionary] = []
var current_deck_index: int = 0
var battle_deck_index: int = 0

# Core Economy & Progression Systems (SYS-8)
var wallet: CurrencyWallet
var hero_trackers: Dictionary = {}
var gacha_roller: GachaRoller

# Campaign & World Map System (SYS-9)
var campaign_graph: NodeMapGraph
var fc_campaign_graph: NodeMapGraph
var active_quest_id: String = ""
var active_fc_quest_id: String = "5001"

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

# Daily Dungeons & El Fisto Arena (Task 7.4)
const MIN_DUNGEON_LEVEL: int = 5
const DAILY_GIFT_REFRESH_SEC: int = 86400
var max_stamina: int = 5
var stamina: int:
	get:
		return wallet.get_balance("energy") if wallet else 5
var dungeon_stage_clears: Dictionary = {}
var active_dungeon_name: String = ""
var active_dungeon_stage_index: int = -1
var last_daily_gift_timestamp: int = 0
var elfisto_current_round: int = 1
var elfisto_highest_round: int = 1
var elfisto_consecutive_wins: int = 0
var elfisto_hero_hp_current: int = -1
var elfisto_is_active_run: bool = false

const DEFAULT_PROFILE_PATH: String = "user://player_profile.json"


func _ready() -> void:
	_init_settings()
	_init_wallet()
	_init_gacha()
	_init_campaign()
	load_profile()
	_update_active_hero_hp()


func _init_settings() -> void:
	if settings_manager == null:
		settings_manager = SettingsManager.new()
		add_child(settings_manager)
		if not settings_manager.load_settings():
			settings_manager.apply_audio_settings()
		elif Localization and settings_manager.display_settings.has("language"):
			Localization.set_language(str(settings_manager.display_settings["language"]))


# ==============================================================================
# WALLET & CURRENCY METHODS
# ==============================================================================

func _init_wallet() -> void:
	if wallet == null:
		wallet = CurrencyWallet.new()
		wallet.register_currency("coins", _raw_player_coins, 99999999)
		wallet.register_currency("gems", 5, 999999)
		wallet.register_currency("energy", 5, 9999)

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
	var start_lvl = 1
	var leader_info = Database.get_leader(hid)
	if not leader_info.is_empty():
		scheme_id = str(leader_info.get("lv_up_scheme", "A"))
		start_lvl = maxi(1, int(leader_info.get("start_level", 1)))

	var lv_index = Database.get_lvup_scheme_index(scheme_id)
	var xp_table: Array[int] = []
	for lvl in range(1, 50): # 49 steps from lvl 1 to 50
		var req = int(ceil(lv_index * pow(float(lvl) * 1.02, 2.5)))
		xp_table.append(maxi(100, req))

	var tracker = ProgressionTracker.new(50, 100, 2.5)
	tracker.set_custom_xp_table(xp_table)
	tracker.current_level = clampi(start_lvl, 1, tracker.max_level)

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
	if hid == "Fionna":
		return "Leader_Fionna"
	if Database.leaders_db.has(hid):
		return str(Database.leaders_db[hid].get("id", hid))
	if not hid.begins_with("Leader_") and Database.leaders_db.has("Leader_" + hid):
		return "Leader_" + hid
	return hid


func get_leader_character_id(hero_id: String) -> String:
	var hid = _normalize_hero_id(hero_id)
	var leader_info = Database.get_leader(hid)
	if not leader_info.is_empty():
		return str(leader_info.get("character_id", hero_id))
	return hero_id


func is_leader_unlocked(hero_id: String) -> bool:
	var hid = _normalize_hero_id(hero_id)
	return unlocked_leaders.has(hid)


func unlock_leader(hero_id: String) -> bool:
	var hid = _normalize_hero_id(hero_id)
	if hid == "" or Database.get_leader(hid).is_empty():
		return false
	if unlocked_leaders.has(hid):
		return false
	unlocked_leaders.append(hid)
	get_hero_tracker(hid)
	leader_unlocked.emit(hid)
	return true


func ensure_fc_leaders_unlocked() -> void:
	# Matches Unity FCMapController.ValidateFCLeaders(): entering Fionna & Cake grants Fionna and Cake
	var changed = false
	if unlock_leader("Leader_Fionna"):
		changed = true
	if unlock_leader("Leader_Cake"):
		changed = true
	if changed:
		save_profile()


func can_use_leader_for_quest(hero_id: String, quest_id: String) -> bool:
	var hid = _normalize_hero_id(hero_id)
	if not is_leader_unlocked(hid):
		return false
	var leader_info = Database.get_leader(hid)
	if leader_info.is_empty():
		return false

	var quest = Database.get_quest(quest_id)
	if quest.is_empty():
		return true

	# 1. Fionna & Cake vs Main Campaign world lock (CWQuestLoad.CanStartQuest FCWorld check)
	var quest_is_fc: bool = (str(quest.get("type", "")) == "fc") or Database.is_leader_fc(str(quest.get("leader_id", "")))
	var leader_is_fc: bool = bool(leader_info.get("fc_world", false))
	if leader_is_fc != quest_is_fc:
		return false

	# 2. Cannot play against yourself or Jake vs BMO (CWQuestLoad.CanStartQuest)
	var char_id = str(leader_info.get("character_id", ""))
	var opp_id = str(quest.get("opponent", ""))
	if char_id != "" and opp_id != "":
		if char_id == opp_id:
			return false
		if (char_id == "BMO" and opp_id == "Jake") or (char_id == "Jake" and opp_id == "BMO"):
			return false

	# 3. Quest-specific LeaderRules (Allow / NotAllow, e.g. FC quests 5059/5060)
	var rules = str(quest.get("leader_rules", "")).to_lower()
	var restricted: Array = quest.get("restricted_leaders", [])
	if rules == "allow" and not restricted.is_empty():
		var matched = false
		for r_id in restricted:
			if _normalize_hero_id(str(r_id)) == hid:
				matched = true
				break
		if not matched:
			return false
	elif rules == "notallow" and not restricted.is_empty():
		for r_id in restricted:
			if _normalize_hero_id(str(r_id)) == hid:
				return false

	return true


func get_valid_leaders_for_quest(quest_id: String) -> Array[String]:
	var result: Array[String] = []
	for hid in unlocked_leaders:
		if can_use_leader_for_quest(hid, quest_id):
			var char_id = get_leader_character_id(hid)
			if char_id != "" and not result.has(char_id):
				result.append(char_id)
	return result


func _sync_legacy_unlocked_leaders() -> void:
	if not unlocked_leaders.has("Leader_Jake"):
		unlocked_leaders.append("Leader_Jake")
	for graph_ref in [campaign_graph, fc_campaign_graph]:
		if graph_ref == null:
			continue
		var nodes_dict = graph_ref.nodes
		for qid in nodes_dict.keys():
			var nd: Dictionary = nodes_dict[qid]
			if int(nd.get("stars", 0)) > 0:
				var q = Database.get_quest(str(qid))
				var la = str(q.get("leader_awarded", "")).strip_edges()
				if la != "":
					unlock_leader(la)
				if graph_ref == fc_campaign_graph:
					unlock_leader("Leader_Fionna")
					unlock_leader("Leader_Cake")


# ==============================================================================
# PROFILE PERSISTENCE (SAVE / LOAD)
# ==============================================================================

## Serializes wallet balances, hero progression, decks, and inventory to JSON.
var suppress_profile_save: bool = false

func save_profile(save_path: String = DEFAULT_PROFILE_PATH) -> bool:
	if suppress_profile_save and save_path == DEFAULT_PROFILE_PATH:
		return true
	_init_wallet()
	var hero_data: Dictionary = {}
	for hid in hero_trackers.keys():
		var tracker: ProgressionTracker = hero_trackers[hid]
		hero_data[hid] = tracker.serialize()

	var profile_dict = {
		"version": 1,
		"wallet": wallet.serialize(),
		"heroes": hero_data,
		"gacha_pity": gacha_roller.serialize_pity() if gacha_roller != null else {},
		"campaign": campaign_graph.serialize() if campaign_graph != null else {},
		"fc_campaign": fc_campaign_graph.serialize() if fc_campaign_graph != null else {},
		"claimed_star_milestones": claimed_star_milestones,
		"dungeon_stage_clears": dungeon_stage_clears,
		"last_daily_gift_timestamp": last_daily_gift_timestamp,
		"max_stamina": max_stamina,
		"elfisto": {
			"current_round": elfisto_current_round,
			"highest_round": elfisto_highest_round,
			"consecutive_wins": elfisto_consecutive_wins
		},
		"active_deck_name": active_deck_name,
		"player_hero_name": player_hero_name,
		"player_deck": player_deck,
		"player_landscapes": player_landscapes,
		"decks": decks,
		"current_deck_index": current_deck_index,
		"battle_deck_index": battle_deck_index,
		"unlocked_leaders": unlocked_leaders,
		"player_inventory_cards": player_inventory_cards,
		"owned_card_counts": owned_card_counts,
		"max_inventory": max_inventory,
		"viewed_fusion_recipes": viewed_fusion_recipes
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
		# Default initial hero: Jake
		unlocked_leaders = ["Leader_Jake"]
		get_hero_tracker("Jake")
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
				var tracker = get_hero_tracker(hid)
				tracker.deserialize(h_dict)
				var leader_info = Database.get_leader(_normalize_hero_id(hid))
				var start_lvl = maxi(1, int(leader_info.get("start_level", 1))) if not leader_info.is_empty() else 1
				if tracker.current_level < start_lvl:
					tracker.current_level = start_lvl

	if data.has("active_deck_name"):
		active_deck_name = str(data["active_deck_name"])
	if data.has("player_hero_name"):
		player_hero_name = str(data["player_hero_name"])
		if player_hero_name == "Fionna":
			player_hero_name = "Fiona"
	if data.has("player_deck") and typeof(data["player_deck"]) == TYPE_ARRAY:
		player_deck.clear()
		for c in data["player_deck"]:
			player_deck.append(str(c))
	if data.has("player_landscapes") and typeof(data["player_landscapes"]) == TYPE_ARRAY and data["player_landscapes"].size() == 4:
		player_landscapes.clear()
		for l in data["player_landscapes"]:
			player_landscapes.append(str(l))
	if data.has("decks") and typeof(data["decks"]) == TYPE_ARRAY:
		decks.clear()
		for d in data["decks"]:
			if typeof(d) == TYPE_DICTIONARY:
				decks.append(d.duplicate(true))
	if data.has("current_deck_index"):
		current_deck_index = clampi(int(data["current_deck_index"]), 0, MAX_NUM_DECKS - 1)
	if data.has("battle_deck_index"):
		battle_deck_index = clampi(int(data["battle_deck_index"]), 0, MAX_NUM_DECKS - 1)
	if data.has("player_inventory_cards") and typeof(data["player_inventory_cards"]) == TYPE_ARRAY:
		player_inventory_cards.clear()
		for c in data["player_inventory_cards"]:
			player_inventory_cards.append(str(c))
	if data.has("owned_card_counts") and typeof(data["owned_card_counts"]) == TYPE_DICTIONARY:
		owned_card_counts = data["owned_card_counts"].duplicate(true)
	if data.has("max_inventory"):
		max_inventory = maxi(DEFAULT_MAX_INVENTORY, int(data["max_inventory"]))
	if data.has("viewed_fusion_recipes") and typeof(data["viewed_fusion_recipes"]) == TYPE_ARRAY:
		viewed_fusion_recipes.clear()
		for cid in data["viewed_fusion_recipes"]:
			var s := str(cid)
			if s != "" and not viewed_fusion_recipes.has(s):
				viewed_fusion_recipes.append(s)
	if data.has("gacha_pity") and typeof(data["gacha_pity"]) == TYPE_DICTIONARY and gacha_roller != null:
		gacha_roller.deserialize_pity(data["gacha_pity"])
	if data.has("campaign") and typeof(data["campaign"]) == TYPE_DICTIONARY and campaign_graph != null:
		campaign_graph.deserialize(data["campaign"])
	if data.has("fc_campaign") and typeof(data["fc_campaign"]) == TYPE_DICTIONARY and fc_campaign_graph != null:
		fc_campaign_graph.deserialize(data["fc_campaign"])

	if data.has("unlocked_leaders") and typeof(data["unlocked_leaders"]) == TYPE_ARRAY:
		unlocked_leaders.clear()
		for lid in data["unlocked_leaders"]:
			var norm = _normalize_hero_id(str(lid))
			if norm != "" and not Database.get_leader(norm).is_empty() and not unlocked_leaders.has(norm):
				unlocked_leaders.append(norm)
		if not unlocked_leaders.has("Leader_Jake"):
			unlocked_leaders.insert(0, "Leader_Jake")
	else:
		unlocked_leaders = ["Leader_Jake"]
		_sync_legacy_unlocked_leaders()
	if data.has("claimed_star_milestones") and typeof(data["claimed_star_milestones"]) == TYPE_ARRAY:
		claimed_star_milestones.clear()
		for m in data["claimed_star_milestones"]:
			claimed_star_milestones.append(int(m))
	if data.has("dungeon_stage_clears") and typeof(data["dungeon_stage_clears"]) == TYPE_DICTIONARY:
		dungeon_stage_clears = data["dungeon_stage_clears"].duplicate(true)
	if data.has("last_daily_gift_timestamp"):
		last_daily_gift_timestamp = int(data["last_daily_gift_timestamp"])
	if data.has("max_stamina"):
		max_stamina = maxi(5, int(data["max_stamina"]))
	if data.has("elfisto") and typeof(data["elfisto"]) == TYPE_DICTIONARY:
		var ef = data["elfisto"]
		elfisto_current_round = int(ef.get("current_round", 1))
		elfisto_highest_round = int(ef.get("highest_round", 1))
		elfisto_consecutive_wins = int(ef.get("consecutive_wins", 0))

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
		add_card_to_inventory(c)


func add_card_to_inventory(card_id: String) -> void:
	if card_id != "":
		player_inventory_cards.append(card_id)
		if not owned_card_counts.is_empty():
			owned_card_counts[card_id] = int(owned_card_counts.get(card_id, 0)) + 1


func is_quest_completed(quest_id: String) -> bool:
	if campaign_graph == null or not campaign_graph.has_node(quest_id):
		return false
	return int(campaign_graph.get_node(quest_id).get("state", NodeMapGraph.NodeState.LOCKED)) == NodeMapGraph.NodeState.COMPLETED


func is_card_forge_unlocked() -> bool:
	return is_quest_completed(CARD_FORGE_UNLOCK_QUEST)


func is_fusion_recipe_unlocked(recipe: Dictionary) -> bool:
	var q_unlock := int(recipe.get("quest_unlock", 0))
	if q_unlock <= 0:
		return true
	return is_quest_completed(str(q_unlock))


func has_viewed_fusion_recipe(card_id: String) -> bool:
	return viewed_fusion_recipes.has(card_id)


func mark_fusion_recipe_viewed(card_id: String) -> bool:
	if card_id == "" or viewed_fusion_recipes.has(card_id):
		return false
	viewed_fusion_recipes.append(card_id)
	save_profile()
	return true


func get_owned_card_counts() -> Dictionary:
	if owned_card_counts.is_empty():
		for c in Database.all_cards_list:
			var cid = str(c.get("id", ""))
			if cid != "":
				owned_card_counts[cid] = 4
		for c in player_inventory_cards:
			owned_card_counts[c] = int(owned_card_counts.get(c, 0)) + 1
	return owned_card_counts


func get_deck_card_counts() -> Dictionary:
	var counts: Dictionary = {}
	for cid in player_deck:
		var k := str(cid)
		if k != "":
			counts[k] = int(counts.get(k, 0)) + 1
	return counts


func get_inventory_only_counts() -> Dictionary:
	var counts: Dictionary = {}
	for cid in player_inventory_cards:
		var k := str(cid)
		if k != "":
			counts[k] = int(counts.get(k, 0)) + 1
	return counts


func get_real_owned_card_counts(include_deck: bool = true) -> Dictionary:
	var counts := get_inventory_only_counts()
	if include_deck:
		for cid in player_deck:
			var k := str(cid)
			if k != "":
				counts[k] = int(counts.get(k, 0)) + 1
	return counts


func get_total_creature_count() -> int:
	var total := 0
	for cid in player_deck:
		var card := Database.get_card(str(cid))
		if str(card.get("type", "")) == "CREATURE":
			total += 1
	for cid in player_inventory_cards:
		var card := Database.get_card(str(cid))
		if str(card.get("type", "")) == "CREATURE":
			total += 1
	return total


func _consume_inventory_card(card_id: String, count: int = 1) -> void:
	var rem := count
	while rem > 0:
		var idx := player_inventory_cards.find(card_id)
		if idx == -1:
			break
		player_inventory_cards.remove_at(idx)
		rem -= 1


func sell_cards(card_ids: Array[String]) -> Dictionary:
	_init_wallet()
	if card_ids.is_empty():
		return {"ok": false, "reason": "Select one or more cards to sell!"}

	var inv_counts := get_inventory_only_counts()
	var req_counts: Dictionary = {}
	var sold_creatures := 0
	var total_coins := 0

	for cid in card_ids:
		var k := str(cid)
		req_counts[k] = int(req_counts.get(k, 0)) + 1
		if int(req_counts[k]) > int(inv_counts.get(k, 0)):
			return {"ok": false, "reason": "Cannot sell more copies than you own in your Card Box."}
		var card := Database.get_card(k)
		if str(card.get("type", "")) == "CREATURE":
			sold_creatures += 1
		total_coins += maxi(0, int(card.get("sale_price", 0)))

	if get_total_card_count() - card_ids.size() < MIN_CARDS_IN_INVENTORY:
		return {
			"ok": false,
			"reason": "You must keep at least %d cards in your Card Box!" % MIN_CARDS_IN_INVENTORY
		}

	if sold_creatures > 0 and (get_total_creature_count() - sold_creatures) < MIN_CREATURES_IN_INVENTORY:
		return {
			"ok": false,
			"reason": "You must keep at least %d creatures in your Card Box!" % MIN_CREATURES_IN_INVENTORY
		}

	for cid in req_counts.keys():
		var q := int(req_counts[cid])
		_consume_inventory_card(str(cid), q)
		if not owned_card_counts.is_empty():
			owned_card_counts[cid] = maxi(0, int(owned_card_counts.get(cid, 0)) - q)

	if total_coins > 0:
		wallet.deposit("coins", total_coins)
	player_currencies_updated.emit(get_coins(), get_gems())
	save_profile()
	return {"ok": true, "sold_count": card_ids.size(), "coins_gained": total_coins}


func craft_fusion_recipe(recipe: Dictionary, use_real_inventory: bool = false) -> Dictionary:
	_init_wallet()
	var FusionEngine = preload("res://src/cards/FusionEngine.gd")
	var counts: Dictionary = get_inventory_only_counts() if use_real_inventory else get_owned_card_counts()

	if use_real_inventory:
		var precheck: Dictionary = FusionEngine.can_craft_recipe(recipe, counts, get_coins())
		if not precheck.get("can_craft", false):
			return {
				"ok": false,
				"output_card_id": "",
				"new_coins": get_coins(),
				"owned_counts": counts,
				"reason": str(precheck.get("reason", "Requirements not met."))
			}
		var creatures_consumed := 0
		for ing in recipe.get("ingredients", []):
			var icard := Database.get_card(str(ing.get("card_id", "")))
			if str(icard.get("type", "")) == "CREATURE":
				creatures_consumed += int(ing.get("count", 1))
		var out_card := Database.get_card(str(recipe.get("card_id", "")))
		var out_is_creature := 1 if str(out_card.get("type", "")) == "CREATURE" else 0
		var net_creature_loss := creatures_consumed - out_is_creature
		if net_creature_loss > 0 and (get_total_creature_count() - net_creature_loss) < MIN_CREATURES_IN_INVENTORY:
			return {
				"ok": false,
				"output_card_id": "",
				"new_coins": get_coins(),
				"owned_counts": counts,
				"reason": "Crafting this would leave you with fewer than %d creatures!" % MIN_CREATURES_IN_INVENTORY
			}

	var res = FusionEngine.execute_fusion(recipe, counts, get_coins())
	if res.get("ok", false):
		var cost := int(recipe.get("cost", 0))
		if cost > 0:
			wallet.withdraw("coins", cost)
		for ing in recipe.get("ingredients", []):
			var icid := str(ing.get("card_id", ""))
			var icnt := int(ing.get("count", 1))
			_consume_inventory_card(icid, icnt)
			if use_real_inventory and not owned_card_counts.is_empty():
				owned_card_counts[icid] = maxi(0, int(owned_card_counts.get(icid, 0)) - icnt)
		var out_id = str(res.get("output_card_id", ""))
		if out_id != "":
			player_inventory_cards.append(out_id)
			if use_real_inventory and not owned_card_counts.is_empty():
				owned_card_counts[out_id] = int(owned_card_counts.get(out_id, 0)) + 1
		player_currencies_updated.emit(get_coins(), get_gems())
		save_profile()
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
	if not decks.is_empty():
		var slot := decks[clampi(current_deck_index, 0, decks.size() - 1)]
		slot["name"] = active_deck_name
		slot["leader"] = _normalize_hero_id(player_hero_name)
		slot["landscapes"] = player_landscapes.duplicate()
		slot["cards"] = player_deck.duplicate()


func open_deck_menu() -> void:
	menu_return_view = "deck_transition"
	return_to_menu()


func open_deck_builder() -> void:
	current_state = MatchState.MENU
	_clear_cached_menu_scenes(get_tree().current_scene)
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


func _clear_cached_menu_scenes(except_node: Node = null) -> void:
	if _cached_main_menu != null and is_instance_valid(_cached_main_menu) and _cached_main_menu != except_node:
		_cached_main_menu.queue_free()
	_cached_main_menu = null if _cached_main_menu != except_node else _cached_main_menu
	if _cached_main_map != null and is_instance_valid(_cached_main_map) and _cached_main_map != except_node:
		_cached_main_map.queue_free()
	_cached_main_map = null if _cached_main_map != except_node else _cached_main_map
	if _cached_fc_map != null and is_instance_valid(_cached_fc_map) and _cached_fc_map != except_node:
		_cached_fc_map.queue_free()
	_cached_fc_map = null if _cached_fc_map != except_node else _cached_fc_map


func start_battle() -> void:
	current_state = MatchState.BATTLE
	_clear_cached_menu_scenes(get_tree().current_scene)
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

	var tree = get_tree()
	var cur = tree.current_scene
	if _cached_main_menu != null and is_instance_valid(_cached_main_menu):
		if cur != null and cur != _cached_main_menu:
			if cur == _cached_fc_map or cur == _cached_main_map:
				cur.visible = false
				cur.process_mode = Node.PROCESS_MODE_DISABLED
			else:
				cur.queue_free()
		_cached_main_menu.visible = true
		_cached_main_menu.process_mode = Node.PROCESS_MODE_INHERIT
		tree.current_scene = _cached_main_menu
		if _cached_main_menu.has_method("restore_return_view"):
			_cached_main_menu.restore_return_view()
		return

	tree.change_scene_to_file("res://scenes/main_menu.tscn")


# ==============================================================================
# CAMPAIGN PROGRESSION & QUEST MAP (SYS-9)
# ==============================================================================

func _init_campaign() -> void:
	if campaign_graph == null:
		campaign_graph = NodeMapGraph.new()
	if fc_campaign_graph == null:
		fc_campaign_graph = NodeMapGraph.new()

	if campaign_graph.get_all_nodes().is_empty():
		for q in Database.main_quests_list:
			var qid = q.get("id", "")
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

	if fc_campaign_graph.get_all_nodes().is_empty():
		for q in Database.fc_quests_list:
			var qid = q.get("id", "")
			fc_campaign_graph.add_node({
				"id": qid,
				"title": "FC " + str(q.get("label", qid)),
				"position": q.get("position", Vector2.ZERO),
				"state": NodeMapGraph.NodeState.LOCKED,
				"prerequisites": q.get("prerequisites", []),
				"connections": q.get("unlock_ids", []),
				"conditions": q.get("conditions", []),
				"metadata": q
			})

		# Ensure Quest 5001 starts UNLOCKED
		if fc_campaign_graph.has_node("5001"):
			fc_campaign_graph.set_node_state("5001", NodeMapGraph.NodeState.UNLOCKED)
		fc_campaign_graph.evaluate_unlocks()


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

	var target_graph = fc_campaign_graph if (quest.get("type") == "fc" and fc_campaign_graph != null) else campaign_graph
	var comp_res = target_graph.complete_node(quest_id, stars_earned)

	# Also unlock star-specific UnlockQuestIDs (1..stars_earned) per MapControllerBase.GetQuestListToUnlock
	var unlocked_list: Array = comp_res.get("unlocked_nodes", []).duplicate()
	var unlock_by_star: Array = quest.get("unlock_ids_by_star", [])
	for s_idx in range(mini(stars_earned, unlock_by_star.size())):
		for u_id in unlock_by_star[s_idx]:
			var u_str = str(u_id)
			if target_graph.has_node(u_str):
				var u_node = target_graph.get_node(u_str)
				if int(u_node.get("state", 0)) == NodeMapGraph.NodeState.LOCKED:
					target_graph.set_node_state(u_str, NodeMapGraph.NodeState.UNLOCKED)
					if not unlocked_list.has(u_str):
						unlocked_list.append(u_str)
	comp_res["unlocked_nodes"] = unlocked_list

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

	var leader_awarded = str(quest.get("leader_awarded", "")).strip_edges()
	var newly_unlocked_leader = ""
	if leader_awarded != "" and unlock_leader(leader_awarded):
		newly_unlocked_leader = leader_awarded

	add_rewards(awarded_coins, card_drops, awarded_xp)
	save_profile()

	var rewards_dict = {
		"coins": awarded_coins,
		"xp": awarded_xp,
		"cards": card_drops,
		"leader_awarded": newly_unlocked_leader
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
	if campaign_graph == null or fc_campaign_graph == null:
		_init_campaign()
	var total = campaign_graph.get_total_stars()
	if fc_campaign_graph != null:
		total += fc_campaign_graph.get_total_stars()
	return total


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

	var target_graph = fc_campaign_graph if (quest.get("type") == "fc" and fc_campaign_graph != null) else campaign_graph
	var node_data = target_graph.get_node(quest_id)
	if node_data.is_empty() or int(node_data.get("state", 0)) == NodeMapGraph.NodeState.LOCKED:
		return false

	# Deduct stamina
	var stamina_cost = int(quest.get("stamina", 1))
	if wallet and not wallet.withdraw("energy", stamina_cost):
		# If out of energy, refill to min 10 for test/offline convenience
		wallet.deposit("energy", stamina_cost)
		wallet.withdraw("energy", stamina_cost)

	active_quest_id = quest_id
	if quest.get("type") == "fc":
		ensure_fc_leaders_unlocked()
		active_fc_quest_id = quest_id
		initial_campaign_world = 1
	else:
		initial_campaign_world = 0

	if not can_use_leader_for_quest(player_hero_name, quest_id):
		var valid_leaders = get_valid_leaders_for_quest(quest_id)
		if valid_leaders.is_empty():
			return false
		player_hero_name = valid_leaders[0]
		_update_active_hero_hp()

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


var initial_campaign_world: int = 0
var menu_return_view: String = "start"
var _cached_main_menu: Node = null
var _cached_main_map: Node = null
var _cached_fc_map: Node = null


func _open_cached_map(scene_path: String, cached_node: Node) -> Node:
	var tree = get_tree()
	var cur = tree.current_scene
	if cur != null and cur.name == "MainMenu":
		_cached_main_menu = cur
		cur.visible = false
		cur.process_mode = Node.PROCESS_MODE_DISABLED
	elif cur != null and cur != cached_node:
		if cur == _cached_fc_map or cur == _cached_main_map:
			cur.visible = false
			cur.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			cur.queue_free()

	if cached_node == null or not is_instance_valid(cached_node):
		var packed = load(scene_path)
		cached_node = packed.instantiate()
		tree.root.add_child(cached_node)
	else:
		cached_node.visible = true
		cached_node.process_mode = Node.PROCESS_MODE_INHERIT
		if cached_node.has_method("on_map_opened"):
			cached_node.on_map_opened()
	tree.current_scene = cached_node
	return cached_node


func open_campaign_map(world: int = -1) -> void:
	if world < 0:
		world = initial_campaign_world
	initial_campaign_world = world
	menu_return_view = "quest_select"
	current_state = MatchState.MENU
	if world == 1:
		ensure_fc_leaders_unlocked()
		_cached_fc_map = _open_cached_map("res://scenes/fc_campaign_map.tscn", _cached_fc_map)
	else:
		_cached_main_map = _open_cached_map("res://scenes/campaign_map.tscn", _cached_main_map)


# ==============================================================================
# DAILY DUNGEONS & EL FISTO ARENA (Task 7.4)
# ==============================================================================

## Daily Dungeon stage queries & progression
func get_dungeon_max_cleared_stage(dungeon_name: String) -> int:
	return int(dungeon_stage_clears.get(dungeon_name, 0))


func is_dungeon_stage_unlocked(dungeon_name: String, stage_index: int) -> bool:
	if stage_index == 0:
		return true
	return get_dungeon_max_cleared_stage(dungeon_name) >= stage_index


func complete_dungeon_stage(dungeon_name: String, stage_index: int) -> void:
	var curr = get_dungeon_max_cleared_stage(dungeon_name)
	if stage_index + 1 > curr:
		dungeon_stage_clears[dungeon_name] = stage_index + 1
	save_profile()


func get_stamina() -> int:
	if wallet == null:
		_init_wallet()
	return wallet.get_balance("energy")


func get_max_stamina() -> int:
	return max_stamina


func refill_stamina_with_gems() -> Dictionary:
	_init_wallet()
	if not spend_gems(1):
		return {"ok": false, "reason": "Not enough Gems!", "not_enough_gems": true}
	var cur := get_stamina()
	if cur < max_stamina:
		wallet.deposit("energy", max_stamina - cur)
	save_profile()
	player_currencies_updated.emit(get_coins(), get_gems())
	return {"ok": true, "stamina": get_stamina()}


func validate_dungeon_entry() -> Dictionary:
	var cur_lvl := get_hero_level(player_hero_name)
	var is_fc := Database.is_leader_fc(player_hero_name)
	if cur_lvl < MIN_DUNGEON_LEVEL:
		return {
			"ok": false,
			"reason": "Your Leader is not at a rad enough level to enter the Dungeons! You must have a leader that is level %d or higher to enter." % MIN_DUNGEON_LEVEL,
			"fail_type": "level",
			"level": cur_lvl
		}
	if is_fc:
		return {
			"ok": false,
			"reason": "Fionna & Cake World Leaders cannot enter the Daily Dungeons of Doom! Switch to an Ooo Leader in Deck Builder.",
			"fail_type": "fc_hero",
			"level": cur_lvl
		}
	return {"ok": true, "level": cur_lvl}


func launch_dungeon_stage(dungeon_name: String, stage_index: int, quest_id: String, heart_cost: int) -> Dictionary:
	var entry_chk := validate_dungeon_entry()
	if not bool(entry_chk.get("ok", false)):
		return entry_chk
	if not is_dungeon_stage_unlocked(dungeon_name, stage_index):
		return {"ok": false, "reason": "Clear the previous stage first!", "fail_type": "locked"}
	if get_total_card_count() > get_max_inventory():
		return {"ok": false, "reason": "Your Card Box is full! Expand or sell cards first.", "fail_type": "inventory"}
	var quest: Dictionary = Database.get_quest(quest_id)
	if quest.is_empty():
		return {"ok": false, "reason": "Dungeon quest not found.", "fail_type": "missing"}
	_init_wallet()
	var cost := maxi(1, heart_cost)
	if get_stamina() < cost:
		return {"ok": false, "reason": "Not enough Hearts! Spend 1 Gem to refill?", "fail_type": "stamina", "needed": cost}
	wallet.withdraw("energy", cost)
	player_currencies_updated.emit(get_coins(), get_gems())

	active_quest_id = quest_id
	active_dungeon_name = dungeon_name
	active_dungeon_stage_index = stage_index
	menu_return_view = "dungeon_list"

	var opp_name = str(quest.get("opponent", "Finn"))
	if opp_name != "":
		opponent_hero_name = opp_name
	var leader_lvl = int(quest.get("leader_level", 1))
	var base_hp = 25
	var leader_data = Database.leaders_db.get(quest.get("leader_id", ""), {})
	if not leader_data.is_empty():
		base_hp = int(leader_data.get("base_hp", 25))
	opponent_hero_max_hp = base_hp + (leader_lvl * 5)

	var deck_id = str(quest.get("deck_id", ""))
	if deck_id != "" and Database.preset_decks_db.has(deck_id):
		var raw_deck = Database.get_preset_deck(deck_id)
		if not raw_deck.is_empty():
			var typed_deck: Array[String] = []
			for c in raw_deck:
				typed_deck.append(str(c))
			opponent_deck = typed_deck

	save_profile()
	start_battle()
	return {"ok": true}


func retry_active_dungeon() -> bool:
	if active_dungeon_name == "" or active_dungeon_stage_index < 0 or active_quest_id == "":
		return false
	var stages := Database.get_dungeon_stages(active_dungeon_name)
	var h_cost := 5
	if active_dungeon_stage_index < stages.size():
		h_cost = int(stages[active_dungeon_stage_index].get("heart_cost", 5))
	var res := launch_dungeon_stage(active_dungeon_name, active_dungeon_stage_index, active_quest_id, h_cost)
	return bool(res.get("ok", false))


func complete_dungeon_quest(quest_id: String, match_stats: Dictionary) -> Dictionary:
	var quest: Dictionary = Database.get_quest(quest_id)
	if quest.is_empty():
		return {"ok": false, "rewards": {}}

	var prev_cleared := get_dungeon_max_cleared_stage(active_dungeon_name)
	var newly_cleared := (active_dungeon_name != "" and active_dungeon_stage_index >= 0 and active_dungeon_stage_index + 1 > prev_cleared)
	if active_dungeon_name != "" and active_dungeon_stage_index >= 0:
		complete_dungeon_stage(active_dungeon_name, active_dungeon_stage_index)

	var min_c := int(quest.get("min_coins", 0))
	var max_c := int(quest.get("max_coins", 0))
	var awarded_coins := randi_range(min_c, max_c) if max_c >= min_c else min_c
	var min_xp := int(quest.get("min_xp", 0))
	var max_xp := int(quest.get("max_xp", 0))
	var awarded_xp := randi_range(min_xp, max_xp) if max_xp >= min_xp else min_xp

	var card_drops: Array[String] = []
	for cd in quest.get("card_drops", []):
		card_drops.append(str(cd))

	var leader_awarded := str(quest.get("leader_awarded", "")).strip_edges()
	var newly_unlocked_leader := ""
	if newly_cleared and leader_awarded != "" and unlock_leader(leader_awarded):
		newly_unlocked_leader = leader_awarded

	var stamina_award := int(quest.get("stamina_awarded", 0)) if newly_cleared else 0
	if stamina_award > 0:
		max_stamina += stamina_award
		if wallet:
			wallet.deposit("energy", stamina_award)

	add_rewards(awarded_coins, card_drops, awarded_xp)
	save_profile()
	player_currencies_updated.emit(get_coins(), get_gems())

	return {
		"ok": true,
		"newly_cleared": newly_cleared,
		"rewards": {
			"coins": awarded_coins,
			"xp": awarded_xp,
			"cards": card_drops,
			"leader_awarded": newly_unlocked_leader,
			"stamina_awarded": stamina_award
		}
	}


func open_dungeon_menu() -> void:
	menu_return_view = "dungeon_list"
	current_state = MatchState.MENU
	return_to_menu()


# ==============================================================================
# DAILY GIFT ROULETTE
# ==============================================================================

func get_daily_gift_seconds_left() -> int:
	if last_daily_gift_timestamp <= 0:
		return 0
	var now_sec := int(Time.get_unix_time_from_system())
	var elapsed := now_sec - last_daily_gift_timestamp
	return maxi(0, DAILY_GIFT_REFRESH_SEC - elapsed)


func is_daily_gift_free_ready() -> bool:
	return get_daily_gift_seconds_left() <= 0


func start_daily_gift_spin(use_gem_retry: bool = false, rng: RandomNumberGenerator = null) -> Dictionary:
	_init_wallet()
	var free_ready := is_daily_gift_free_ready()
	var retry_cost := Database.get_daily_gift_retry_cost()
	if not free_ready:
		if not use_gem_retry:
			return {"ok": false, "reason": "Free Daily Gift on cooldown.", "cooldown": get_daily_gift_seconds_left()}
		if not spend_gems(retry_cost):
			return {"ok": false, "reason": "Not enough Gems!", "not_enough_gems": true}
	else:
		last_daily_gift_timestamp = int(Time.get_unix_time_from_system())

	var entry := Database.roll_daily_gift(rng)
	if entry.is_empty():
		return {"ok": false, "reason": "Daily Gift table empty."}

	var gtype := str(entry.get("type", ""))
	var card_id := ""
	if gtype == "Card normal":
		card_id = Database.pick_daily_gift_card_id("Standard", rng)
	elif gtype == "Card gold":
		card_id = Database.pick_daily_gift_card_id("Gold", rng)
	elif gtype == "Card obsidian":
		card_id = Database.pick_daily_gift_card_id("Obsidian", rng)

	save_profile()
	player_currencies_updated.emit(get_coins(), get_gems())
	return {
		"ok": true,
		"used_free": free_ready,
		"cell_index": int(entry.get("index", 0)),
		"entry": entry,
		"card_id": card_id
	}


func grant_daily_gift_reward(spin_res: Dictionary) -> Dictionary:
	_init_wallet()
	var entry: Dictionary = spin_res.get("entry", {})
	var gtype := str(entry.get("type", ""))
	var qty := maxi(1, int(entry.get("quantity", 1)))
	var card_id := str(spin_res.get("card_id", ""))
	match gtype:
		"Coins":
			add_coins(qty)
		"Gems":
			add_gems(qty)
		"Hearts":
			wallet.deposit("energy", qty)
		"Card normal", "Card gold", "Card obsidian":
			if card_id != "":
				add_card_to_inventory(card_id)
	save_profile()
	player_currencies_updated.emit(get_coins(), get_gems())
	return {"ok": true, "type": gtype, "quantity": qty, "card_id": card_id}


## El Fisto Survival Gauntlet lifecycle
func start_elfisto_run() -> void:
	elfisto_current_round = 1
	elfisto_consecutive_wins = 0
	_update_active_hero_hp()
	elfisto_hero_hp_current = player_hero_max_hp
	elfisto_is_active_run = true


func record_elfisto_battle_result(won: bool, remaining_hp: int) -> Dictionary:
	if not elfisto_is_active_run:
		start_elfisto_run()

	if won:
		elfisto_consecutive_wins += 1
		elfisto_hero_hp_current = maxi(1, remaining_hp)
		var round_data = Database.get_elfisto_round(elfisto_current_round)

		var reward_type = str(round_data.get("reward_type", ""))
		var reward_qty = int(round_data.get("reward_quantity", 1))
		var awarded_dict: Dictionary = {"type": reward_type, "quantity": reward_qty}

		if reward_type == "Gems":
			add_gems(reward_qty)
		elif reward_type.begins_with("Card "):
			var card_id = reward_type.replace("Card ", "").strip_edges()
			add_card_to_inventory(card_id)
			awarded_dict["card_id"] = card_id

		var completed_round = elfisto_current_round
		var is_cleared_all = (completed_round >= 8)
		elfisto_round_cleared.emit(completed_round, awarded_dict)

		if not is_cleared_all:
			elfisto_current_round += 1
			elfisto_highest_round = maxi(elfisto_highest_round, elfisto_current_round)
		else:
			elfisto_is_active_run = false
			elfisto_hero_hp_current = -1
			elfisto_run_ended.emit(true, 8)

		save_profile()
		return {
			"won": true,
			"round": completed_round,
			"reward": awarded_dict,
			"cleared_gauntlet": is_cleared_all,
			"next_round": elfisto_current_round,
			"remaining_hp": elfisto_hero_hp_current
		}
	else:
		var ended_round = elfisto_current_round
		elfisto_is_active_run = false
		elfisto_hero_hp_current = -1
		elfisto_current_round = 1
		elfisto_run_ended.emit(false, ended_round)
		save_profile()
		return {
			"won": false,
			"round": ended_round,
			"reset": true
		}


# ==============================================================================
# STORE (INVENTORY CAPACITY & GEM BUNDLES)
# ==============================================================================

func get_max_inventory() -> int:
	return maxi(DEFAULT_MAX_INVENTORY, max_inventory)


func get_total_card_count() -> int:
	return player_deck.size() + player_inventory_cards.size()


func purchase_inventory_increase(use_gems: bool) -> Dictionary:
	_init_wallet()
	var tier: Dictionary = Database.get_card_box_tier(max_inventory)
	var gain: int = int(tier.get("gain", 0))
	if tier.is_empty() or gain <= 0 or max_inventory + gain > Database.card_box_max_capacity:
		return {"ok": false, "reason": "Your card box space has reached its maximum size."}

	if use_gems:
		var gem_price: int = int(tier.get("gem_price", 0))
		if gem_price <= 0 or not spend_gems(gem_price):
			return {"ok": false, "reason": "Not enough gems!", "not_enough_gems": true}
	else:
		var coin_price: int = int(tier.get("coin_price", 0))
		if coin_price <= 0 or not spend_coins(coin_price):
			return {"ok": false, "reason": "Not enough coins!", "not_enough_coins": true}

	max_inventory += gain
	inventory_capacity_changed.emit(max_inventory)
	player_currencies_updated.emit(get_coins(), get_gems())
	save_profile()
	return {"ok": true, "new_max": max_inventory, "gain": gain}


func purchase_gem_pack(product_id: String) -> Dictionary:
	_init_wallet()
	for pack in Database.get_gem_shop_products():
		if str(pack.get("product_id", "")) == product_id:
			var coin_price: int = int(pack.get("coin_price", 0))
			var gem_gain: int = int(pack.get("gems", 0))
			if gem_gain <= 0:
				return {"ok": false, "reason": "Invalid gem bundle."}
			if not spend_coins(coin_price):
				return {"ok": false, "reason": "Not enough coins!"}
			add_gems(gem_gain)
			save_profile()
			return {"ok": true, "gems_added": gem_gain, "coin_price": coin_price}
	return {"ok": false, "reason": "Product not found."}


# ==============================================================================
# MULTI-DECK BUILDER SLOTS (UNITY PlayerDeckManager + CWDeckController)
# ==============================================================================

func ensure_decks_initialized() -> void:
	if decks.is_empty():
		var starter_cards: Array[String] = []
		for c in player_deck:
			starter_cards.append(str(c))
		var starter_lands: Array[String] = []
		for l in player_landscapes:
			starter_lands.append(str(l))
		while starter_lands.size() < 4:
			starter_lands.append("Corn")
		decks.append({
			"name": active_deck_name if active_deck_name != "" else "Deck 1",
			"leader": _normalize_hero_id(player_hero_name),
			"cards": starter_cards,
			"landscapes": starter_lands.slice(0, 4),
		})
	while decks.size() < MAX_NUM_DECKS:
		var idx := decks.size()
		decks.append({
			"name": "Deck %d" % (idx + 1),
			"leader": "Leader_Jake",
			"cards": [] as Array[String],
			"landscapes": ["Corn", "Corn", "Corn", "Corn"] as Array[String],
		})
	if decks.size() > MAX_NUM_DECKS:
		decks.resize(MAX_NUM_DECKS)
	current_deck_index = clampi(current_deck_index, 0, MAX_NUM_DECKS - 1)
	battle_deck_index = clampi(battle_deck_index, 0, MAX_NUM_DECKS - 1)


func get_deck_slot(idx: int) -> Dictionary:
	ensure_decks_initialized()
	var slot_idx := clampi(idx, 0, MAX_NUM_DECKS - 1)
	return decks[slot_idx]


func get_all_owned_card_instances() -> Array[String]:
	var list: Array[String] = []
	for c in player_deck:
		var s := str(c)
		if s != "":
			list.append(s)
	for c in player_inventory_cards:
		var s := str(c)
		if s != "":
			list.append(s)
	return list


func _apply_equipped_slot_to_active_player(slot_idx: int) -> void:
	ensure_decks_initialized()
	if slot_idx < 0 or slot_idx >= decks.size():
		return
	var slot: Dictionary = decks[slot_idx]
	var slot_cards: Array = slot.get("cards", [])
	if slot_cards.is_empty():
		return

	# Reconcile player_inventory_cards so total owned multiset (player_deck + player_inventory_cards) never changes
	var total_pool: Array[String] = get_all_owned_card_instances()
	var new_player_deck: Array[String] = []
	for c in slot_cards:
		var s := str(c)
		new_player_deck.append(s)
		var pool_i := total_pool.find(s)
		if pool_i != -1:
			total_pool.remove_at(pool_i)
	player_deck = new_player_deck
	player_inventory_cards = total_pool

	var leader_id := str(slot.get("leader", "Leader_Jake"))
	var leader_data := Database.get_leader(leader_id)
	player_hero_name = str(leader_data.get("character_id", leader_id.replace("Leader_", ""))) if not leader_data.is_empty() else leader_id.replace("Leader_", "")
	if player_hero_name == "Fionna":
		player_hero_name = "Fiona"
	_update_active_hero_hp()

	var lands: Array[String] = []
	for l in slot.get("landscapes", []):
		lands.append(str(l))
	while lands.size() < 4:
		lands.append("Corn")
	player_landscapes = lands.slice(0, 4)
	active_deck_name = str(slot.get("name", "Deck %d" % (slot_idx + 1)))


func set_deck_slot_cards(slot_idx: int, cards: Array[String], recalculate_landscapes: bool = true) -> void:
	ensure_decks_initialized()
	slot_idx = clampi(slot_idx, 0, MAX_NUM_DECKS - 1)
	var typed_cards: Array[String] = []
	for c in cards:
		typed_cards.append(str(c))
	decks[slot_idx]["cards"] = typed_cards
	if recalculate_landscapes:
		decks[slot_idx]["landscapes"] = auto_calculate_landscapes(typed_cards)
	if slot_idx == battle_deck_index or (slot_idx == current_deck_index and typed_cards.size() >= MIN_CARDS_IN_DECK):
		_apply_equipped_slot_to_active_player(slot_idx)
	save_profile()


func set_deck_slot_leader(slot_idx: int, leader_id: String) -> void:
	ensure_decks_initialized()
	slot_idx = clampi(slot_idx, 0, MAX_NUM_DECKS - 1)
	decks[slot_idx]["leader"] = _normalize_hero_id(leader_id)
	if slot_idx == battle_deck_index or slot_idx == current_deck_index:
		var slot: Dictionary = decks[slot_idx]
		var l_id := str(slot.get("leader", "Leader_Jake"))
		var leader_data := Database.get_leader(l_id)
		player_hero_name = str(leader_data.get("character_id", l_id.replace("Leader_", ""))) if not leader_data.is_empty() else l_id.replace("Leader_", "")
		if player_hero_name == "Fionna":
			player_hero_name = "Fiona"
		_update_active_hero_hp()
	save_profile()


func set_deck_slot_landscapes(slot_idx: int, landscapes: Array[String]) -> void:
	ensure_decks_initialized()
	slot_idx = clampi(slot_idx, 0, MAX_NUM_DECKS - 1)
	var typed: Array[String] = []
	for l in landscapes:
		typed.append(str(l))
	while typed.size() < 4:
		typed.append("Corn")
	decks[slot_idx]["landscapes"] = typed.slice(0, 4)
	if slot_idx == battle_deck_index or slot_idx == current_deck_index:
		player_landscapes = typed.slice(0, 4)
	save_profile()


func set_battle_deck_index(slot_idx: int) -> Dictionary:
	ensure_decks_initialized()
	slot_idx = clampi(slot_idx, 0, MAX_NUM_DECKS - 1)
	var slot: Dictionary = decks[slot_idx]
	var cards: Array = slot.get("cards", [])
	if cards.is_empty():
		return {"ok": false, "reason": "Deck %d has no cards!" % (slot_idx + 1)}
	var l_data := Database.get_leader(str(slot.get("leader", "Leader_Jake")))
	if bool(l_data.get("fc_world", false)):
		return {"ok": false, "reason": "Fionna & Cake Heroes cannot be used in Battle Decks."}
	battle_deck_index = slot_idx
	_apply_equipped_slot_to_active_player(slot_idx)
	save_profile()
	return {"ok": true}


func auto_calculate_landscapes(cards: Array[String]) -> Array[String]:
	## Mirrors Unity CWDeckController.SetLandscapes() exact faction distribution algorithm
	if cards.is_empty():
		return ["Corn", "Corn", "Corn", "Corn"]
	var counts: Dictionary = {}
	var non_uni_total := 0
	for cid in cards:
		var c := Database.get_card(str(cid))
		var fact := str(c.get("faction", "Universal"))
		if fact == "Universal" or fact == "" or fact == "None":
			continue
		counts[fact] = int(counts.get(fact, 0)) + 1
		non_uni_total += 1
	if counts.is_empty():
		return ["Corn", "Corn", "Corn", "Corn"]
	var sorted_factions: Array = counts.keys()
	sorted_factions.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]))
	var out: Array[String] = []
	var n := sorted_factions.size()
	if n >= 4:
		for i in range(4):
			out.append(str(sorted_factions[i]))
	elif n == 3:
		var ratio := float(counts[sorted_factions[0]]) / float(maxi(1, non_uni_total))
		if ratio >= 0.5:
			out.append(str(sorted_factions[0]))
			out.append(str(sorted_factions[0]))
			out.append(str(sorted_factions[1]))
			out.append(str(sorted_factions[2]))
		else:
			out.append(str(sorted_factions[0]))
			out.append(str(sorted_factions[1]))
			out.append(str(sorted_factions[1]))
			out.append(str(sorted_factions[2]))
	elif n == 2:
		var ratio := float(counts[sorted_factions[0]]) / float(maxi(1, non_uni_total))
		if ratio >= 0.65:
			out.append(str(sorted_factions[0]))
			out.append(str(sorted_factions[0]))
			out.append(str(sorted_factions[0]))
			out.append(str(sorted_factions[1]))
		else:
			out.append(str(sorted_factions[0]))
			out.append(str(sorted_factions[0]))
			out.append(str(sorted_factions[1]))
			out.append(str(sorted_factions[1]))
	else:
		var f0 := str(sorted_factions[0])
		out = [f0, f0, f0, f0]
	return out


func check_all_decks_validity() -> String:
	## Mirrors Unity PlayerDeckManager.CheckValidity()
	ensure_decks_initialized()
	for i in range(decks.size()):
		var slot: Dictionary = decks[i]
		var cards: Array = slot.get("cards", [])
		if cards.is_empty():
			continue
		var deck_num := i + 1
		if cards.size() < MIN_CARDS_IN_DECK:
			return "Deck %d contains less than %d cards.  Edit Deck to add more." % [deck_num, MIN_CARDS_IN_DECK]
		var leader_id := str(slot.get("leader", "Leader_Jake"))
		var leader_data := Database.get_leader(leader_id)
		var leader_name := str(leader_data.get("name", leader_id))
		var max_size := get_hero_deck_max_size(leader_id)
		if cards.size() > max_size:
			return "Deck %d, %s can only hold %d cards in a deck" % [deck_num, leader_name, max_size]
		var dup_counts: Dictionary = {}
		for cid in cards:
			var k := str(cid)
			dup_counts[k] = int(dup_counts.get(k, 0)) + 1
			if int(dup_counts[k]) > MAX_DUPLICATES_IN_DECK:
				var cname := str(Database.get_card(k).get("name", k))
				return "Deck %d contains more than %d of the card \"%s\"" % [deck_num, MAX_DUPLICATES_IN_DECK, cname]
	return ""


