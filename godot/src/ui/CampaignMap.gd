extends Control

const NodeMapRenderer = preload("res://src/systems/node_map_system/NodeMapRenderer.gd")
const NodeMapGraph = preload("res://src/systems/node_map_system/NodeMapGraph.gd")

@onready var map_renderer: NodeMapRenderer = $VBox/MapArea/MapRenderer
@onready var total_stars_label: Label = $VBox/TopBar/RightGroup/TotalStarsLabel
@onready var back_btn: Button = $VBox/TopBar/BackBtn
@onready var regions_bar: HBoxContainer = $VBox/RegionsBar

# Quest Detail Modal
@onready var detail_modal: Control = $QuestDetailModal
@onready var modal_title: Label = $QuestDetailModal/Panel/VBox/Header/Title
@onready var modal_close_btn: Button = $QuestDetailModal/Panel/VBox/Header/CloseBtn
@onready var modal_opponent_label: Label = $QuestDetailModal/Panel/VBox/OpponentLabel
@onready var modal_deck_label: Label = $QuestDetailModal/Panel/VBox/DeckLabel
@onready var modal_stamina_label: Label = $QuestDetailModal/Panel/VBox/StaminaLabel
@onready var modal_rewards_label: Label = $QuestDetailModal/Panel/VBox/RewardsLabel
@onready var modal_cond1_label: Label = $QuestDetailModal/Panel/VBox/Conditions/Cond1
@onready var modal_cond2_label: Label = $QuestDetailModal/Panel/VBox/Conditions/Cond2
@onready var modal_cond3_label: Label = $QuestDetailModal/Panel/VBox/Conditions/Cond3
@onready var modal_battle_btn: Button = $QuestDetailModal/Panel/VBox/BattleBtn

var _selected_quest_id: String = ""


func _ready() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if modal_close_btn:
		modal_close_btn.pressed.connect(func(): detail_modal.visible = false)
	if modal_battle_btn:
		modal_battle_btn.pressed.connect(_on_battle_pressed)

	detail_modal.visible = false

	_setup_regions_bar()

	if GameManager.campaign_graph == null:
		GameManager._init_campaign()

	if map_renderer:
		map_renderer.graph = GameManager.campaign_graph
		map_renderer.node_selected.connect(_on_quest_selected)

	GameManager.campaign_graph.node_updated.connect(func(_nid): _refresh_stats())
	GameManager.campaign_graph.node_completed.connect(func(_nid, _s, _f): _refresh_stats())

	_refresh_stats()


func _setup_regions_bar() -> void:
	for child in regions_bar.get_children():
		child.queue_free()

	var regions = Database.get_map_regions()
	for i in range(regions.size()):
		var r = regions[i]
		var r_name = str(r.get("RegionName", "Region " + str(i + 1)))
		var btn = Button.new()
		btn.text = "%d. %s" % [i + 1, r_name.capitalize()]
		btn.pressed.connect(func(): _jump_to_region(i))
		regions_bar.add_child(btn)


func _jump_to_region(region_index: int) -> void:
	if map_renderer == null:
		return
	# Target Y coordinate for region
	var target_y = -(120.0 + (region_index * 200.0) - 200.0)
	var target_x = -200.0
	map_renderer._canvas_offset = Vector2(target_x, target_y)
	map_renderer._apply_transform()


func _refresh_stats() -> void:
	if GameManager.campaign_graph == null:
		return
	var total_stars = GameManager.campaign_graph.get_total_stars()
	if total_stars_label:
		total_stars_label.text = "⭐ Stars: %d" % total_stars


func _on_quest_selected(quest_id: String) -> void:
	_selected_quest_id = quest_id
	var quest = Database.get_quest(quest_id)
	if quest.is_empty():
		return

	var node_data = GameManager.campaign_graph.get_node(quest_id)
	var state = int(node_data.get("state", NodeMapGraph.NodeState.LOCKED))
	var stars = int(node_data.get("stars", 0))

	modal_title.text = "Quest %s: %s" % [quest_id, str(quest.get("level_name", "Battle")).replace("!!LEVEL_", "").capitalize()]
	modal_opponent_label.text = "👤 Opponent: %s (Lv. %d)" % [quest.get("opponent", "Jake"), quest.get("leader_level", 1)]
	modal_deck_label.text = "🃏 Enemy Deck: %s" % quest.get("deck_id", "Default")
	modal_stamina_label.text = "⚡ Stamina Cost: %d" % quest.get("stamina", 1)

	var drops_str = ", ".join(quest.get("card_drops", []))
	if drops_str == "":
		drops_str = "None"
	modal_rewards_label.text = "💰 Coins: %d-%d | ✨ XP: %d-%d\n🎁 Loot: %s" % [
		quest.get("min_coins", 0), quest.get("max_coins", 0),
		quest.get("min_xp", 0), quest.get("max_xp", 0),
		drops_str
	]

	# Setup 3 star conditions
	var cond_ids = quest.get("condition_ids", [])
	_format_condition_label(modal_cond1_label, cond_ids, 0, stars)
	_format_condition_label(modal_cond2_label, cond_ids, 1, stars)
	_format_condition_label(modal_cond3_label, cond_ids, 2, stars)

	if state == NodeMapGraph.NodeState.LOCKED:
		modal_battle_btn.disabled = true
		modal_battle_btn.text = "🔒 Quest Locked"
	else:
		modal_battle_btn.disabled = false
		modal_battle_btn.text = "⚔️ Battle Quest %s!" % quest_id

	detail_modal.visible = true


func _format_condition_label(label: Label, cond_ids: Array, index: int, stars: int) -> void:
	if label == null:
		return
	if index >= cond_ids.size():
		label.visible = false
		return

	label.visible = true
	var cid = str(cond_ids[index])
	var is_cleared = (stars > index)
	var prefix = "★ " if is_cleared else "☆ "
	var desc = _get_friendly_cond_desc(cid)
	label.text = prefix + desc
	label.modulate = Color(1.0, 0.85, 0.3) if is_cleared else Color(0.8, 0.8, 0.8)


func _get_friendly_cond_desc(cond_id: String) -> String:
	match cond_id:
		"JustWin": return "Win the match"
		"Forbid_Spells": return "Win without using Spells"
		"Forbid_Buildings": return "Win without using Buildings"
		"Only_Creatures": return "Win using only Creatures"
		"Only_Corn": return "Win using only Corn cards"
		"Only_Plains": return "Win using only Plains cards"
		"Only_Cotton": return "Win using only Cotton cards"
		"Only_Swamp": return "Win using only Swamp cards"
		"Only_Sand": return "Win using only Sand cards"
		"Forbid_Corn": return "Win without using Corn cards"
		"Forbid_Plains": return "Win without using Plains cards"
		"Landscapes_Four": return "Win using 4 distinct Landscapes"
		"Landscapes_Three": return "Win using at least 3 Landscapes"
		"Landscapes_Two": return "Win using at least 2 Landscapes"
	if cond_id.begins_with("FastWin"):
		return "Win in %s turns or less" % cond_id.replace("FastWin", "")
	if cond_id.begins_with("Only") and cond_id.ends_with("HP"):
		return "Lose at most %s HP" % cond_id.replace("Only", "").replace("HP", "")
	if cond_id.begins_with("OnlyLose") and cond_id.ends_with("Creatures"):
		return "Lose at most %s creatures" % cond_id.replace("OnlyLose", "").replace("Creatures", "")
	if cond_id.begins_with("Defeat"):
		return "Defeat at least %s enemy creatures" % cond_id.replace("Defeat", "")
	return cond_id


func _on_battle_pressed() -> void:
	if _selected_quest_id == "":
		return
	detail_modal.visible = false
	GameManager.launch_quest_battle(_selected_quest_id)


func _on_back_pressed() -> void:
	GameManager.return_to_menu()
