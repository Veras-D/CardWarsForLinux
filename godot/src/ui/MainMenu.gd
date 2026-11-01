extends Control

@onready var play_btn: Button = $CenterContainer/VBox/PlayBtn
@onready var compendium_btn: Button = $CenterContainer/VBox/CompendiumBtn
@onready var quit_btn: Button = $CenterContainer/VBox/QuitBtn

@onready var compendium_dialog: Panel = $CompendiumDialog
@onready var close_compendium_btn: Button = $CompendiumDialog/VBox/Header/CloseBtn
@onready var cards_grid: GridContainer = $CompendiumDialog/VBox/Scroll/Grid
@onready var card_count_label: Label = $CompendiumDialog/VBox/CountLabel

func _ready() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	compendium_btn.pressed.connect(_on_compendium_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	close_compendium_btn.pressed.connect(_on_close_compendium_pressed)
	compendium_dialog.visible = false

func _on_play_pressed() -> void:
	GameManager.start_battle()

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
