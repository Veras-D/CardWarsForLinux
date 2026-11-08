extends Control

const NodeMapRenderer = preload("res://src/systems/node_map_system/NodeMapRenderer.gd")
const NodeMapGraph = preload("res://src/systems/node_map_system/NodeMapGraph.gd")

enum CampaignWorld { LAND_OF_OOO, FIONNA_AND_CAKE }
var current_world: CampaignWorld = CampaignWorld.LAND_OF_OOO

@onready var map_renderer: NodeMapRenderer = $VBox/MapArea/MapRenderer
@onready var title_label: Label = $VBox/TopBar/Title
@onready var world_toggle_btn: Button = $VBox/TopBar/WorldToggleBtn
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
	if world_toggle_btn:
		world_toggle_btn.pressed.connect(_toggle_campaign_world)
	if modal_close_btn:
		modal_close_btn.pressed.connect(func(): detail_modal.visible = false)
	if modal_battle_btn:
		modal_battle_btn.pressed.connect(_on_battle_pressed)

	detail_modal.visible = false

	if GameManager.campaign_graph == null or GameManager.fc_campaign_graph == null:
		GameManager._init_campaign()

	_setup_regions_bar()

	if map_renderer:
		map_renderer.graph = GameManager.campaign_graph
		map_renderer.node_selected.connect(_on_quest_selected)

	if GameManager.campaign_graph:
		GameManager.campaign_graph.node_updated.connect(func(_nid): _refresh_stats())
		GameManager.campaign_graph.node_completed.connect(func(_nid, _s, _f): _refresh_stats())
	if GameManager.fc_campaign_graph:
		GameManager.fc_campaign_graph.node_updated.connect(func(_nid): _refresh_stats())
		GameManager.fc_campaign_graph.node_completed.connect(func(_nid, _s, _f): _refresh_stats())

	_refresh_stats()


func _toggle_campaign_world() -> void:
	if current_world == CampaignWorld.LAND_OF_OOO:
		set_campaign_world(CampaignWorld.FIONNA_AND_CAKE)
	else:
		set_campaign_world(CampaignWorld.LAND_OF_OOO)


func set_campaign_world(world: CampaignWorld) -> void:
	current_world = world
	if world == CampaignWorld.FIONNA_AND_CAKE:
		if title_label:
			title_label.text = "🍰 FIONNA & CAKE EXPANSION"
			title_label.modulate = Color(1.0, 0.75, 0.9, 1.0)
		if world_toggle_btn:
			world_toggle_btn.text = "🌟 Land of Ooo"
		if map_renderer:
			map_renderer.graph = GameManager.fc_campaign_graph
	else:
		if title_label:
			title_label.text = "🗺️ LAND OF OOO CAMPAIGN"
			title_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if world_toggle_btn:
			world_toggle_btn.text = "🍰 Fionna & Cake"
		if map_renderer:
			map_renderer.graph = GameManager.campaign_graph

	_setup_regions_bar()
	if map_renderer:
		map_renderer._canvas_offset = Vector2(-150.0, 50.0)
		map_renderer.queue_redraw()
	_refresh_stats()


func _setup_regions_bar() -> void:
	for child in regions_bar.get_children():
		regions_bar.remove_child(child)
		child.queue_free()

	var regions = Database.get_fc_map_regions() if (current_world == CampaignWorld.FIONNA_AND_CAKE) else Database.get_map_regions()
	for i in range(regions.size()):
		var r = regions[i]
		var r_name = str(r.get("RegionName", ""))
		if r_name.strip_edges() == "":
			r_name = "Stage %d" % (i + 1)
		var btn = Button.new()
		btn.text = "%d. %s" % [i + 1, r_name.capitalize()]
		btn.pressed.connect(func(): _jump_to_region(i))
		regions_bar.add_child(btn)


func _jump_to_region(region_index: int) -> void:
	if map_renderer == null:
		return
	# Target Y coordinate for region
	var target_y = -(120.0 + (region_index * 180.0) - 200.0)
	var target_x = -150.0
	map_renderer._canvas_offset = Vector2(target_x, target_y)
	map_renderer._apply_transform()


func _refresh_stats() -> void:
	if GameManager.campaign_graph == null:
		return
	var total_stars = GameManager.get_total_campaign_stars()

	# Check Star Milestones (Task 7.2)
	var next_m: Dictionary = {}
	var claimable_threshold: int = -1
	for m in GameManager.STAR_MILESTONES:
		var st = int(m.get("stars", 0))
		if GameManager.can_claim_milestone(st):
			claimable_threshold = st
			next_m = m
			break
		elif not GameManager.claimed_star_milestones.has(st):
			if next_m.is_empty():
				next_m = m

	if total_stars_label:
		if claimable_threshold >= 0:
			total_stars_label.text = "⭐ Stars: %d | 🎁 [CLAIM %s]" % [total_stars, next_m.get("label", "Reward")]
			total_stars_label.modulate = Color(1.0, 0.9, 0.2)
		elif not next_m.is_empty():
			total_stars_label.text = "⭐ Stars: %d / %d (Next: %s)" % [total_stars, next_m.get("stars", 0), next_m.get("label", "Reward")]
			total_stars_label.modulate = Color(1.0, 1.0, 1.0)
		else:
			total_stars_label.text = "⭐ Stars: %d (All Milestones Claimed!)" % total_stars
			total_stars_label.modulate = Color(0.8, 1.0, 0.8)


func _on_quest_selected(quest_id: String) -> void:
	_selected_quest_id = quest_id
	var quest = Database.get_quest(quest_id)
	if quest.is_empty():
		return

	var active_graph = GameManager.fc_campaign_graph if (current_world == CampaignWorld.FIONNA_AND_CAKE and GameManager.fc_campaign_graph != null) else GameManager.campaign_graph
	var node_data = active_graph.get_node(quest_id)
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
	if Database:
		return Database.get_condition_description(cond_id)
	return cond_id


func _on_battle_pressed() -> void:
	if _selected_quest_id == "":
		return
	detail_modal.visible = false
	GameManager.launch_quest_battle(_selected_quest_id)


func _on_back_pressed() -> void:
	GameManager.return_to_menu()
