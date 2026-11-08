extends Control

@onready var play_btn: Button = $CenterContainer/VBox/PlayBtn
@onready var campaign_btn: Button = $CenterContainer/VBox/CampaignBtn
@onready var versus_btn: Button = $CenterContainer/VBox/VersusBtn
@onready var lan_btn: Button = $CenterContainer/VBox/LanBtn
@onready var deck_builder_btn: Button = $CenterContainer/VBox/DeckBuilderBtn
@onready var chests_btn: Button = $CenterContainer/VBox/ChestsBtn
@onready var compendium_btn: Button = $CenterContainer/VBox/CompendiumBtn
@onready var quit_btn: Button = $CenterContainer/VBox/QuitBtn

@onready var compendium_dialog: Panel = $CompendiumDialog
@onready var close_compendium_btn: Button = $CompendiumDialog/VBox/Header/CloseBtn
@onready var cards_grid: GridContainer = $CompendiumDialog/VBox/Scroll/Grid
@onready var card_count_label: Label = $CompendiumDialog/VBox/CountLabel
@onready var chest_modal: Control = $ChestOpeningModal
@onready var versus_modal: Control = $VersusSetupModal
@onready var lan_modal: Control = $LanLobbyModal

func _ready() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	if campaign_btn:
		campaign_btn.pressed.connect(_on_campaign_pressed)
	if versus_btn:
		versus_btn.pressed.connect(_on_versus_pressed)
	if lan_btn:
		lan_btn.pressed.connect(_on_lan_pressed)
	if deck_builder_btn:
		deck_builder_btn.pressed.connect(_on_deck_builder_pressed)
	if chests_btn:
		chests_btn.pressed.connect(_on_chests_pressed)
	compendium_btn.pressed.connect(_on_compendium_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	close_compendium_btn.pressed.connect(_on_close_compendium_pressed)
	compendium_dialog.visible = false
	if chest_modal:
		chest_modal.visible = false
	if versus_modal:
		versus_modal.visible = false
	if lan_modal:
		lan_modal.visible = false
	play_btn.text = "⚔️ Quick Battle (%s vs %s)" % [GameManager.player_hero_name, GameManager.opponent_hero_name]

func _on_play_pressed() -> void:
	GameManager.active_quest_id = ""
	GameManager.is_local_versus = false
	GameManager.is_network_match = false
	GameManager.start_battle()

func _on_versus_pressed() -> void:
	if versus_modal:
		versus_modal.open_modal()

func _on_lan_pressed() -> void:
	if lan_modal:
		lan_modal.open_modal()

func _on_campaign_pressed() -> void:
	GameManager.open_campaign_map()

func _on_deck_builder_pressed() -> void:
	GameManager.open_deck_builder()

func _on_chests_pressed() -> void:
	if chest_modal:
		chest_modal.refresh_display()
		chest_modal.visible = true

func _on_compendium_pressed() -> void:
	compendium_dialog.visible = true
	if cards_grid.get_child_count() == 0:
		_populate_compendium()

func _populate_compendium() -> void:
	var creatures = Database.creatures_list
	card_count_label.text = "Browsing %d Original Cards" % creatures.size()
	for card in creatures:
		var card_view = preload("res://scenes/components/CardView.tscn").instantiate()
		cards_grid.add_child(card_view)
		card_view.render_card(card)

func _on_close_compendium_pressed() -> void:
	compendium_dialog.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()
