class_name BattleResultModal
extends Control

## BattleResultModal: Post-Battle Quest Objectives & Rewards Audit Screen (Task 7.2)
## Displays 3-star objective evaluations, match telemetry details, currency/XP awards,
## and level-up feedback with animated reveals.

signal continue_pressed()
signal retry_pressed()

@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var dialog_panel: PanelContainer = $CenterContainer/DialogPanel

# Banner
@onready var title_label: Label = $CenterContainer/DialogPanel/VBox/Header/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/DialogPanel/VBox/Header/SubtitleLabel

# Quest Objectives Container
@onready var objectives_section: VBoxContainer = $CenterContainer/DialogPanel/VBox/ObjectivesSection
@onready var objectives_title: Label = $CenterContainer/DialogPanel/VBox/ObjectivesSection/ObjectivesTitle
@onready var objectives_list: VBoxContainer = $CenterContainer/DialogPanel/VBox/ObjectivesSection/ObjectivesList

# Rewards Container
@onready var rewards_section: VBoxContainer = $CenterContainer/DialogPanel/VBox/RewardsSection
@onready var rewards_grid: GridContainer = $CenterContainer/DialogPanel/VBox/RewardsSection/RewardsGrid
@onready var coins_label: Label = $CenterContainer/DialogPanel/VBox/RewardsSection/RewardsGrid/CoinsLabel
@onready var xp_label: Label = $CenterContainer/DialogPanel/VBox/RewardsSection/RewardsGrid/XpLabel
@onready var cards_label: Label = $CenterContainer/DialogPanel/VBox/RewardsSection/RewardsGrid/CardsLabel
@onready var levelup_banner: Label = $CenterContainer/DialogPanel/VBox/RewardsSection/LevelUpBanner

# Buttons
@onready var continue_btn: Button = $CenterContainer/DialogPanel/VBox/ButtonContainer/ContinueBtn
@onready var retry_btn: Button = $CenterContainer/DialogPanel/VBox/ButtonContainer/RetryBtn

var is_campaign_match: bool = false
var active_quest_id: String = ""
var stars_earned_count: int = 0


func _ready() -> void:
	visible = false
	if continue_btn and not continue_btn.pressed.is_connected(_on_continue_pressed):
		continue_btn.pressed.connect(_on_continue_pressed)
	if retry_btn and not retry_btn.pressed.is_connected(_on_retry_pressed):
		retry_btn.pressed.connect(_on_retry_pressed)


func display_result(victory: bool, quest_id: String, match_stats: Dictionary, rewards: Dictionary, audit_report: Array = []) -> void:
	visible = true
	active_quest_id = quest_id
	is_campaign_match = (quest_id != "")

	# Animate dark overlay fade
	modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Setup Banner
	if victory:
		title_label.text = "🏆 VICTORY! 🏆"
		title_label.modulate = Color(1.0, 0.85, 0.2)
		subtitle_label.text = "You are crowned a Cool Guy!"
	else:
		title_label.text = "💀 DEFEAT! 💀"
		title_label.modulate = Color(0.9, 0.25, 0.25)
		subtitle_label.text = "You drank from the Dweeb Cup!"

	# Setup Objectives
	_populate_objectives(victory, quest_id, audit_report)

	# Setup Rewards
	_populate_rewards(victory, rewards)

	# Setup Buttons
	if is_campaign_match:
		continue_btn.text = "Continue to Map 🗺️"
	else:
		continue_btn.text = "Return to Menu 🏠"
	retry_btn.text = "Retry Battle ⚔️"

	# Pop-in scale on dialog
	dialog_panel.scale = Vector2(0.85, 0.85)
	dialog_panel.pivot_offset = dialog_panel.size / 2.0
	var scale_tween = create_tween()
	scale_tween.tween_property(dialog_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _populate_objectives(victory: bool, quest_id: String, audit_report: Array) -> void:
	# Clear previous items
	for child in objectives_list.get_children():
		child.queue_free()

	if not is_campaign_match and audit_report.is_empty():
		objectives_section.visible = false
		return

	objectives_section.visible = true
	stars_earned_count = 0
	for item in audit_report:
		if bool(item.get("passed", false)):
			stars_earned_count += 1

	var star_summary = ""
	for i in range(3):
		star_summary += "★" if i < stars_earned_count else "☆"

	objectives_title.text = "🗺️ QUEST %s OBJECTIVES — %s (%d / 3 ⭐)" % [quest_id, star_summary, stars_earned_count]

	# Build rows
	for i in range(audit_report.size()):
		var report_item: Dictionary = audit_report[i]
		var passed = bool(report_item.get("passed", false))
		var desc = str(report_item.get("description", "Objective " + str(i + 1)))
		var detail = str(report_item.get("detail", ""))

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)

		# Star Icon
		var star_lbl = Label.new()
		star_lbl.text = "★" if passed else "☆"
		star_lbl.custom_minimum_size = Vector2(28, 0)
		star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_lbl.add_theme_font_size_override("font_size", 20)
		if passed:
			star_lbl.modulate = Color(1.0, 0.88, 0.1)
		else:
			star_lbl.modulate = Color(0.45, 0.45, 0.45)
		row.add_child(star_lbl)

		# Description
		var desc_lbl = Label.new()
		desc_lbl.text = desc
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 14)
		if passed:
			desc_lbl.modulate = Color(1.0, 1.0, 1.0)
		else:
			desc_lbl.modulate = Color(0.7, 0.7, 0.7)
		row.add_child(desc_lbl)

		# Status & Details
		var status_lbl = Label.new()
		if passed:
			status_lbl.text = "[PASSED] %s" % detail if detail != "" else "[PASSED]"
			status_lbl.modulate = Color(0.2, 0.9, 0.3)
		else:
			status_lbl.text = "[FAILED] %s" % detail if detail != "" else "[FAILED]"
			status_lbl.modulate = Color(0.85, 0.3, 0.3)
		status_lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(status_lbl)

		objectives_list.add_child(row)

		# Sequential punch animation on passed stars
		if passed:
			row.modulate.a = 0.0
			var row_tween = create_tween()
			row_tween.tween_interval(0.15 * (i + 1))
			row_tween.tween_property(row, "modulate:a", 1.0, 0.2)


func _populate_rewards(victory: bool, rewards: Dictionary) -> void:
	if not victory and rewards.is_empty():
		rewards_section.visible = false
		return

	rewards_section.visible = true
	var coins = int(rewards.get("coins", 0))
	var xp = int(rewards.get("xp", 0))
	var cards: Array = rewards.get("cards", [])

	coins_label.text = "💰 +%d Coins" % coins
	coins_label.visible = (coins > 0)

	var hero_name = GameManager.player_hero_name if GameManager else "Hero"
	var hero_lvl = GameManager.get_hero_level(hero_name) if GameManager else 1
	xp_label.text = "✨ +%d XP (%s Lv. %d)" % [xp, hero_name, hero_lvl]
	xp_label.visible = (xp > 0)

	if cards.is_empty():
		cards_label.text = "🎁 Cards: None"
	else:
		var card_names: Array[String] = []
		for cid in cards:
			var cdata = Database.get_card(str(cid)) if Database else {}
			card_names.append(str(cdata.get("name", cid)))
		cards_label.text = "🎁 Cards (%d): %s" % [cards.size(), ", ".join(card_names)]

	levelup_banner.visible = bool(rewards.get("leveled_up", false))


func _on_continue_pressed() -> void:
	continue_pressed.emit()
	if is_campaign_match and GameManager:
		GameManager.open_campaign_map()
	elif GameManager:
		GameManager.return_to_menu()


func _on_retry_pressed() -> void:
	retry_pressed.emit()
	if GameManager:
		if is_campaign_match and active_quest_id != "":
			GameManager.launch_quest_battle(active_quest_id)
		GameManager.start_battle()
