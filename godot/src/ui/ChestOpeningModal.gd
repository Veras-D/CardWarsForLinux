extends Control

signal closed
signal card_revealed(card_id: String, rarity: String)

const CardViewScene = preload("res://scenes/components/CardView.tscn")
const ChestShakeSfx = preload("res://assets/audio/sfx/FX_LootDrop_Chest.wav")
const ChestOpenSfx = preload("res://assets/audio/sfx/FX_LootDrop_ChestOpen.wav")

@export var skip_animations: bool = false

@onready var close_btn: Button = $Panel/VBox/Header/CloseBtn
@onready var coins_label: Label = $Panel/VBox/Header/Currencies/CoinsLabel
@onready var gems_label: Label = $Panel/VBox/Header/Currencies/GemsLabel

@onready var selection_container: Control = $Panel/VBox/Content/SelectionContainer
@onready var cool_open_1_btn: Button = $Panel/VBox/Content/SelectionContainer/HBox/CoolChestCard/VBox/Open1Btn
@onready var cool_open_5_btn: Button = $Panel/VBox/Content/SelectionContainer/HBox/CoolChestCard/VBox/Open5Btn
@onready var algebraic_open_1_btn: Button = $Panel/VBox/Content/SelectionContainer/HBox/AlgebraicChestCard/VBox/Open1Btn
@onready var algebraic_open_5_btn: Button = $Panel/VBox/Content/SelectionContainer/HBox/AlgebraicChestCard/VBox/Open5Btn
@onready var algebraic_pity_label: Label = $Panel/VBox/Content/SelectionContainer/HBox/AlgebraicChestCard/VBox/PityLabel
@onready var status_label: Label = $Panel/VBox/StatusLabel

@onready var reveal_container: Control = $Panel/VBox/Content/RevealContainer
@onready var animated_chest_rect: TextureRect = $Panel/VBox/Content/RevealContainer/ChestCenter/AnimatedChest
@onready var burst_flash: ColorRect = $Panel/VBox/Content/RevealContainer/ChestCenter/BurstFlash
@onready var cards_scroll: ScrollContainer = $Panel/VBox/Content/RevealContainer/CardsScroll
@onready var cards_grid: HBoxContainer = $Panel/VBox/Content/RevealContainer/CardsScroll/CardsGrid
@onready var collect_btn: Button = $Panel/VBox/Content/RevealContainer/CollectBtn
@onready var reveal_title: Label = $Panel/VBox/Content/RevealContainer/RevealTitle

@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var _is_opening: bool = false


func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	if cool_open_1_btn:
		cool_open_1_btn.pressed.connect(func(): _on_open_chest_pressed("cool_chest", 1))
	if cool_open_5_btn:
		cool_open_5_btn.pressed.connect(func(): _on_open_chest_pressed("cool_chest", 5))
	if algebraic_open_1_btn:
		algebraic_open_1_btn.pressed.connect(func(): _on_open_chest_pressed("algebraic_chest", 1))
	if algebraic_open_5_btn:
		algebraic_open_5_btn.pressed.connect(func(): _on_open_chest_pressed("algebraic_chest", 5))
	if collect_btn:
		collect_btn.pressed.connect(_on_collect_pressed)

	GameManager.player_currencies_updated.connect(_on_currencies_updated)
	refresh_display()
	_show_selection_view()


func refresh_display() -> void:
	if coins_label:
		coins_label.text = "🪙 %d" % GameManager.get_coins()
	if gems_label:
		gems_label.text = "💎 %d" % GameManager.get_gems()
	if algebraic_pity_label:
		var pity = GameManager.get_chest_pity("algebraic_chest")
		algebraic_pity_label.text = "Pity: %d / 10 until guaranteed Gold!" % pity


func _on_currencies_updated(_coins: int, _gems: int) -> void:
	refresh_display()


func _show_selection_view() -> void:
	_is_opening = false
	if selection_container:
		selection_container.visible = true
	if reveal_container:
		reveal_container.visible = false
	if status_label:
		status_label.text = ""
	refresh_display()


func _on_close_pressed() -> void:
	if _is_opening:
		return
	visible = false
	closed.emit()


func _on_collect_pressed() -> void:
	_show_selection_view()


func _on_open_chest_pressed(chest_type: String, count: int) -> void:
	if _is_opening:
		return

	status_label.text = ""
	var result = GameManager.open_chest(chest_type, count)
	if not result.get("ok", false):
		status_label.text = "⚠️ " + str(result.get("reason", "Cannot open chest."))
		status_label.modulate = Color(1.0, 0.35, 0.35)
		return

	_is_opening = true
	selection_container.visible = false
	reveal_container.visible = true
	refresh_display()

	_play_open_sequence(chest_type, result.get("rolls", []))


func _play_open_sequence(chest_type: String, rolls: Array) -> void:
	# Clear previous cards
	for child in cards_grid.get_children():
		child.queue_free()

	cards_scroll.visible = false
	collect_btn.visible = false
	reveal_title.text = "Opening %s..." % ("Algebraic Chest" if chest_type == "algebraic_chest" else "Cool Chest")

	# Set chest tint / theme
	if chest_type == "algebraic_chest":
		animated_chest_rect.modulate = Color(1.2, 1.0, 0.3) # Gold glow
	else:
		animated_chest_rect.modulate = Color(0.8, 0.95, 1.1) # Cool blue-silver glow

	animated_chest_rect.scale = Vector2.ONE
	animated_chest_rect.rotation = 0.0

	if skip_animations:
		_reveal_cards_immediately(rolls)
		return

	# Play shake SFX
	if sfx_player and ChestShakeSfx:
		sfx_player.stream = ChestShakeSfx
		sfx_player.play()

	# Wobble Tween animation
	var shake_tween = create_tween().set_parallel(false)
	for i in range(3):
		shake_tween.tween_property(animated_chest_rect, "rotation", deg_to_rad(-8.0), 0.08)
		shake_tween.tween_property(animated_chest_rect, "rotation", deg_to_rad(8.0), 0.08)
	shake_tween.tween_property(animated_chest_rect, "rotation", 0.0, 0.05)
	shake_tween.parallel().tween_property(animated_chest_rect, "scale", Vector2(1.25, 1.25), 0.15)

	await shake_tween.finished

	# Open burst
	if sfx_player and ChestOpenSfx:
		sfx_player.stream = ChestOpenSfx
		sfx_player.play()

	# Burst flash
	if burst_flash:
		burst_flash.visible = true
		burst_flash.modulate = Color(1, 1, 1, 1)
		var flash_tween = create_tween()
		flash_tween.tween_property(burst_flash, "modulate", Color(1, 1, 1, 0), 0.3)
		await flash_tween.finished
		burst_flash.visible = false

	# Show cards
	_reveal_cards_immediately(rolls)


func _reveal_cards_immediately(rolls: Array) -> void:
	reveal_title.text = "Discovered %d Cards!" % rolls.size()
	cards_scroll.visible = true
	collect_btn.visible = true

	for roll_data in rolls:
		var card_id = str(roll_data.get("id", ""))
		var rarity = str(roll_data.get("rarity", "Standard"))
		var is_pity = bool(roll_data.get("is_pity", false))

		var card_db_info = Database.get_card(card_id)
		if card_db_info.is_empty():
			card_db_info = {
				"id": card_id,
				"name": card_id,
				"cost": 1,
				"desc": "A rare gacha discovery!",
				"type": "CREATURE",
				"atk": 1,
				"def": 1,
				"quality": rarity
			}

		# Card container with rarity banner
		var card_slot = VBoxContainer.new()
		card_slot.alignment = BoxContainer.ALIGNMENT_CENTER
		card_slot.add_theme_constant_override("separation", 6)

		var badge_label = Label.new()
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if is_pity:
			badge_label.text = "⭐ PITY GUARANTEE! ⭐"
			badge_label.modulate = Color(1.0, 0.85, 0.2)
		elif rarity.to_lower() == "gold":
			badge_label.text = "✨ GOLD RARITY! ✨"
			badge_label.modulate = Color(1.0, 0.9, 0.3)
		elif rarity.to_lower() == "obsidian":
			badge_label.text = "🔮 OBSIDIAN RARITY! 🔮"
			badge_label.modulate = Color(0.8, 0.4, 1.0)
		else:
			badge_label.text = "STANDARD"
			badge_label.modulate = Color(0.7, 0.8, 0.9)
		badge_label.add_theme_font_size_override("font_size", 11)
		card_slot.add_child(badge_label)

		var card_view = CardViewScene.instantiate()
		card_slot.add_child(card_view)
		cards_grid.add_child(card_slot)
		card_view.render_card(card_db_info)

		card_revealed.emit(card_id, rarity)

	_is_opening = false
