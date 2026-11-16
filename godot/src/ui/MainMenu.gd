extends Control

# Audio
const BGM_TREEHOUSE = preload("res://assets/audio/bgm/MainMenu.wav")
const SFX_CLICK = preload("res://assets/audio/sfx/Click.wav")
const SFX_UI_SELECT = preload("res://assets/audio/sfx/UI_Select.wav")
const SFX_UI_BACK = preload("res://assets/audio/sfx/UI_Back.wav")

var _press_select_sfx_played: bool = false

# 3D Treehouse & UI Nodes
@onready var treehouse_3d: Node3D = $ViewportContainer/SubViewport/TreehouseMenu3D
@onready var top_bar: Control = $TopBar
@onready var bottom_dock: Control = $BottomDock
@onready var start_overlay: Control = $StartOverlay

# Top Bar Data Labels
@onready var level_label: Label = $TopBar/PlayerBadge/LevelLabel
@onready var xp_bar: ProgressBar = $TopBar/PlayerBadge/XPBar
@onready var xp_label: Label = $TopBar/PlayerBadge/XPLabel
@onready var stamina_label: Label = $TopBar/PlayerBadge/StaminaValue
@onready var stamina_value_label: Label = $TopBar/PlayerBadge/StaminaValue
@onready var stamina_status_label: Label = $TopBar/PlayerBadge/StaminaStatus
@onready var cards_label: Label = $TopBar/Currencies/InventoryBadge/CardsLabel
@onready var gems_label: Label = $TopBar/Currencies/GemsBadge/GemsLabel
@onready var coins_label: Label = $TopBar/Currencies/CoinsBadge/CoinsLabel
@onready var trophy_label: Label = $TopBar/TrophyBadge/TrophyLabel

# Bottom Dock Buttons
@onready var quit_btn: BaseButton = get_node_or_null("BottomDock/QuitBtn")
@onready var settings_btn: BaseButton = $BottomDock/HBox/SettingsBtn
@onready var dungeons_btn: BaseButton = $BottomDock/HBox/DungeonsBtn
@onready var deck_btn: BaseButton = $BottomDock/HBox/DeckBtn
@onready var store_btn: BaseButton = $BottomDock/HBox/StoreBtn
@onready var chests_btn: BaseButton = $BottomDock/HBox/ChestsBtn
@onready var battle_btn: BaseButton = $BottomDock/HBox/BattleBtn

# Extra Navigation Buttons
@onready var versus_shortcut_btn: BaseButton = $BottomDock/ExtraRow/VersusBtn
@onready var lan_shortcut_btn: BaseButton = $BottomDock/ExtraRow/LanBtn

# Modals
@onready var quit_modal: Control = $QuitConfirmModal
@onready var quit_confirm_btn: BaseButton = $QuitConfirmModal/Panel/Buttons/QuitBtn
@onready var quit_cancel_btn: BaseButton = $QuitConfirmModal/Panel/Buttons/DontQuitBtn

@onready var chest_modal: Control = $ChestOpeningModal
@onready var versus_modal: Control = $VersusSetupModal
@onready var lan_modal: Control = $LanLobbyModal
@onready var settings_modal: Control = $SettingsModal
@onready var dungeon_modal: Control = $DungeonArenaModal
@onready var store_inventory_modal: Control = get_node_or_null("StoreInventoryModal")
@onready var store_gems_modal: Control = get_node_or_null("StoreGemsModal")
@onready var chest_flow_overlay: ChestFlowOverlay = get_node_or_null("ChestFlowOverlay")
@onready var compendium_dialog: Control = $CompendiumDialog
@onready var cards_grid: GridContainer = $CompendiumDialog/VBox/Scroll/Grid
@onready var compendium_count_label: Label = $CompendiumDialog/VBox/CountLabel
@onready var close_compendium_btn: BaseButton = $CompendiumDialog/VBox/Header/CloseBtn

# Sub-menu Deck Choice Popup
@onready var deck_choice_modal: Control = $DeckChoiceModal
@onready var choice_builder_btn: BaseButton = $DeckChoiceModal/Panel/VBox/BuilderBtn
@onready var choice_compendium_btn: BaseButton = $DeckChoiceModal/Panel/VBox/CompendiumBtn
@onready var choice_cancel_btn: BaseButton = $DeckChoiceModal/Panel/VBox/CancelBtn

# Quest Mode Selection Overlay
@onready var quest_overlay: Control = get_node_or_null("QuestModeOverlay")
@onready var quest_back_btn: BaseButton = get_node_or_null("QuestModeOverlay/BackBtn")
@onready var quad_deck_wars: BaseButton = get_node_or_null("QuestModeOverlay/QuadDeckWars")
@onready var quad_fionna: BaseButton = get_node_or_null("QuestModeOverlay/QuadFionna")
@onready var quad_quests: BaseButton = get_node_or_null("QuestModeOverlay/QuadQuests")

# Store Overlay
@onready var store_overlay: Control = get_node_or_null("StoreOverlay")
@onready var store_back_btn: BaseButton = get_node_or_null("StoreOverlay/BackBtn")
@onready var quad_inventory: BaseButton = get_node_or_null("StoreOverlay/QuadInventory")
@onready var quad_gems: BaseButton = get_node_or_null("StoreOverlay/QuadGems")

# Chests Overlay
@onready var chests_overlay: Control = get_node_or_null("ChestsOverlay")
@onready var chests_back_btn: BaseButton = get_node_or_null("ChestsOverlay/BackBtn")
@onready var quad_cool_chest: BaseButton = get_node_or_null("ChestsOverlay/QuadCoolChest")
@onready var quad_algebraic_chest: BaseButton = get_node_or_null("ChestsOverlay/QuadAlgebraicChest")

func _ready() -> void:
	# Autoplay Treehouse BGM
	if Audio and BGM_TREEHOUSE:
		Audio.play_bgm(BGM_TREEHOUSE)
	
	# Connect Dock Buttons
	if quit_btn:
		quit_btn.pressed.connect(_show_quit_modal)
	if battle_btn:
		battle_btn.pressed.connect(_on_battle_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if dungeons_btn:
		dungeons_btn.pressed.connect(_on_dungeons_pressed)
	if deck_btn:
		deck_btn.pressed.connect(_on_deck_pressed)
	if store_btn:
		store_btn.pressed.connect(_on_store_pressed)
	if chests_btn:
		chests_btn.pressed.connect(_on_chests_pressed)
	if versus_shortcut_btn:
		versus_shortcut_btn.pressed.connect(_on_versus_pressed)
	if lan_shortcut_btn:
		lan_shortcut_btn.pressed.connect(_on_lan_pressed)
	
	# Quit Modal Buttons
	if quit_confirm_btn:
		quit_confirm_btn.pressed.connect(_on_quit_confirm_pressed)
	if quit_cancel_btn:
		quit_cancel_btn.pressed.connect(_on_quit_cancel_pressed)
	
	# Start Overlay Button
	if start_overlay:
		var start_tap_btn = start_overlay.get_node_or_null("TapButton")
		if start_tap_btn:
			start_tap_btn.pressed.connect(_on_start_tapped)
	
	# Compendium Buttons
	if close_compendium_btn:
		close_compendium_btn.pressed.connect(_on_close_compendium_pressed)
	
	# Deck Choice Modal
	if choice_builder_btn:
		choice_builder_btn.pressed.connect(_on_open_deck_builder)
	if choice_compendium_btn:
		choice_compendium_btn.pressed.connect(_on_open_compendium)
	if choice_cancel_btn:
		choice_cancel_btn.pressed.connect(func(): deck_choice_modal.visible = false)
	
	# Quest Mode Selection Overlay Buttons
	if quest_back_btn:
		quest_back_btn.pressed.connect(_on_quest_back_pressed)
	_connect_board_button(quad_deck_wars, "set_deckwars_pressed", _on_deck_wars_pressed)
	if quad_fionna:
		quad_fionna.pressed.connect(_on_fionna_pressed)
	if quad_quests:
		quad_quests.pressed.connect(_on_quests_pressed)
	
	# Store Overlay Buttons & Modals
	if store_back_btn:
		store_back_btn.pressed.connect(_on_store_back_pressed)
	_connect_board_button(quad_inventory, "set_store_inventory_pressed", _on_quad_inventory_pressed)
	_connect_board_button(quad_gems, "set_store_gems_pressed", _on_quad_gems_pressed)
	if store_inventory_modal and store_inventory_modal.has_signal("inventory_upgraded"):
		store_inventory_modal.inventory_upgraded.connect(func(_new_max: int): _update_player_stats())
	if store_gems_modal and store_gems_modal.has_signal("gems_purchased"):
		store_gems_modal.gems_purchased.connect(func(_added: int): _update_player_stats())

	# Chests Overlay Buttons & Flow
	if chests_back_btn:
		chests_back_btn.pressed.connect(_on_chests_back_pressed)
	_connect_board_button(quad_cool_chest, "set_cool_chest_pressed", _on_quad_cool_chest_pressed)
	_connect_board_button(quad_algebraic_chest, "set_algebraic_chest_pressed", _on_quad_algebraic_chest_pressed)
	if chest_flow_overlay:
		chest_flow_overlay.closed.connect(_on_chest_flow_closed)
		chest_flow_overlay.chest_opening_started.connect(_on_chest_opening_started)
		chest_flow_overlay.flow_finished.connect(_on_chest_flow_finished)
		chest_flow_overlay.open_store_inventory_requested.connect(_on_chest_request_store_inventory)
		chest_flow_overlay.open_store_gems_requested.connect(_on_chest_request_store_gems)
	if GameManager:
		if GameManager.has_signal("player_currencies_updated"):
			GameManager.player_currencies_updated.connect(_update_player_stats)
		if GameManager.has_signal("inventory_capacity_changed"):
			GameManager.inventory_capacity_changed.connect(func(_new_max: int): _update_player_stats())
	
	# Hide all modals initially
	if quit_modal:
		quit_modal.visible = false
	if chest_modal:
		chest_modal.visible = false
	if versus_modal:
		versus_modal.visible = false
	if lan_modal:
		lan_modal.visible = false
	if settings_modal:
		settings_modal.visible = false
	if dungeon_modal:
		dungeon_modal.visible = false
	if store_inventory_modal:
		store_inventory_modal.visible = false
	if store_gems_modal:
		store_gems_modal.visible = false
	if compendium_dialog:
		compendium_dialog.visible = false
	if deck_choice_modal:
		deck_choice_modal.visible = false
	if quest_overlay:
		quest_overlay.visible = false
	if store_overlay:
		store_overlay.visible = false
	if chests_overlay:
		chests_overlay.visible = false
	if chest_flow_overlay:
		chest_flow_overlay.reset_immediately()
	
	restore_return_view()
	
	# Update Top Bar Data
	_update_player_stats()

	# Screenshot helper if requested via environment
	if OS.has_environment("SCREENSHOT_TEST"):
		_auto_screenshot()

func restore_return_view() -> void:
	# Restore previous view ("quest_select", "store", or "hub") or start at exterior title screen ("start")
	var return_view = GameManager.menu_return_view if "menu_return_view" in GameManager else "start"
	if return_view == "quest_select":
		if start_overlay:
			start_overlay.visible = false
		if top_bar:
			top_bar.visible = true
			top_bar.modulate.a = 1.0
		if bottom_dock:
			bottom_dock.visible = false
		if quest_overlay:
			quest_overlay.visible = true
			quest_overlay.modulate.a = 1.0
		if store_overlay:
			store_overlay.visible = false
		if chests_overlay:
			chests_overlay.visible = false
		if treehouse_3d and treehouse_3d.has_method("set_quest_modes_view"):
			treehouse_3d.set_quest_modes_view()
	elif return_view == "store":
		if start_overlay:
			start_overlay.visible = false
		if top_bar:
			top_bar.visible = true
			top_bar.modulate.a = 1.0
		if bottom_dock:
			bottom_dock.visible = false
		if quest_overlay:
			quest_overlay.visible = false
		if store_overlay:
			store_overlay.visible = true
			store_overlay.modulate.a = 1.0
		if chests_overlay:
			chests_overlay.visible = false
		if treehouse_3d and treehouse_3d.has_method("set_store_modes_view"):
			treehouse_3d.set_store_modes_view()
	elif return_view == "chests":
		if start_overlay:
			start_overlay.visible = false
		if top_bar:
			top_bar.visible = true
			top_bar.modulate.a = 1.0
		if bottom_dock:
			bottom_dock.visible = false
		if quest_overlay:
			quest_overlay.visible = false
		if store_overlay:
			store_overlay.visible = false
		if chests_overlay:
			chests_overlay.visible = true
			chests_overlay.modulate.a = 1.0
		if treehouse_3d and treehouse_3d.has_method("set_chests_modes_view"):
			treehouse_3d.set_chests_modes_view()
	elif return_view == "hub":
		if start_overlay:
			start_overlay.visible = false
		if top_bar:
			top_bar.visible = true
			top_bar.modulate.a = 1.0
		if bottom_dock:
			bottom_dock.visible = true
			bottom_dock.modulate.a = 1.0
		if quest_overlay:
			quest_overlay.visible = false
		if store_overlay:
			store_overlay.visible = false
		if chests_overlay:
			chests_overlay.visible = false
		if treehouse_3d and treehouse_3d.has_method("set_hub_view"):
			treehouse_3d.set_hub_view()
	else:
		if start_overlay:
			start_overlay.visible = true
			start_overlay.modulate.a = 1.0
			if top_bar:
				top_bar.visible = false
			if bottom_dock:
				bottom_dock.visible = false
			if quest_overlay:
				quest_overlay.visible = false
			if store_overlay:
				store_overlay.visible = false
			if chests_overlay:
				chests_overlay.visible = false
			if treehouse_3d and treehouse_3d.has_method("set_start_view"):
				treehouse_3d.set_start_view()
	_update_player_stats()

func _auto_screenshot() -> void:
	var mode = OS.get_environment("SCREENSHOT_TEST")
	if mode == "battle_select":
		if start_overlay and start_overlay.visible:
			_on_start_tapped()
		await get_tree().create_timer(1.0).timeout
		_on_battle_pressed()
		await get_tree().create_timer(1.0).timeout
	elif mode == "quest_fx_in":
		if start_overlay and start_overlay.visible:
			_on_start_tapped()
		await get_tree().create_timer(1.0).timeout
		_on_battle_pressed()
		await get_tree().create_timer(0.25).timeout
	elif mode == "quest_fx_out":
		if start_overlay and start_overlay.visible:
			_on_start_tapped()
		await get_tree().create_timer(1.0).timeout
		_on_battle_pressed()
		await get_tree().create_timer(1.0).timeout
		close_quest_mode_select()
		await get_tree().create_timer(0.22).timeout
	elif mode == "store_fx_in":
		if start_overlay and start_overlay.visible:
			_on_start_tapped()
		await get_tree().create_timer(1.0).timeout
		open_store()
		await get_tree().create_timer(0.25).timeout
	elif mode == "store_fx_out":
		if start_overlay and start_overlay.visible:
			_on_start_tapped()
		await get_tree().create_timer(1.0).timeout
		open_store()
		await get_tree().create_timer(1.0).timeout
		close_store()
		await get_tree().create_timer(0.22).timeout
	elif mode in ["store", "store_inventory", "store_gems", "store_gems_anim", "store_click_inv", "store_click_gems"]:
		if start_overlay and start_overlay.visible:
			_on_start_tapped()
		await get_tree().create_timer(1.0).timeout
		open_store()
		await get_tree().create_timer(1.2).timeout
		if mode == "store_inventory":
			_on_quad_inventory_pressed()
			await get_tree().create_timer(1.1).timeout
		elif mode == "store_gems":
			_on_quad_gems_pressed()
			await get_tree().create_timer(1.1).timeout
		elif mode == "store_gems_anim":
			_on_quad_gems_pressed()
			await get_tree().create_timer(0.35).timeout
		elif mode == "store_click_inv":
			_on_quad_inventory_pressed()
			await get_tree().create_timer(0.05).timeout
		elif mode == "store_click_gems":
			_on_quad_gems_pressed()
			await get_tree().create_timer(0.05).timeout
	elif mode in ["chests", "chests_fx_in", "chests_confirm", "chests_confirm_alg", "chests_opening", "chests_opening_alg", "chests_reveal"]:
		if start_overlay and start_overlay.visible:
			_on_start_tapped()
		await get_tree().create_timer(1.0).timeout
		open_chests()
		if mode == "chests_fx_in":
			await get_tree().create_timer(0.25).timeout
		else:
			await get_tree().create_timer(1.2).timeout
			if mode == "chests_confirm":
				_open_chest_confirm("cool")
				await get_tree().create_timer(0.45).timeout
			elif mode == "chests_confirm_alg":
				_open_chest_confirm("algebraic")
				await get_tree().create_timer(0.45).timeout
			elif mode == "chests_opening":
				if chests_overlay:
					chests_overlay.visible = false
				if treehouse_3d:
					treehouse_3d.focus_chest("cool", 0.0)
				if chest_flow_overlay and treehouse_3d:
					chest_flow_overlay.start_preview_opening("cool", treehouse_3d.get_chest_icon("cool"), "Creature_CoolDog", 4.7)
				await get_tree().create_timer(0.15).timeout
			elif mode == "chests_opening_alg":
				if chests_overlay:
					chests_overlay.visible = false
				if treehouse_3d:
					treehouse_3d.focus_chest("algebraic", 0.0)
				if chest_flow_overlay and treehouse_3d:
					chest_flow_overlay.start_preview_opening("algebraic", treehouse_3d.get_chest_icon("algebraic"), "Creature_GL_HuskerKnight", 4.6)
				await get_tree().create_timer(0.15).timeout
			elif mode == "chests_reveal":
				if chests_overlay:
					chests_overlay.visible = false
				if treehouse_3d:
					treehouse_3d.focus_chest("algebraic", 0.0)
					var alg_icon: ChestIconBase = treehouse_3d.get_chest_icon("algebraic")
					if alg_icon:
						alg_icon.set_open_preview_time(5.99)
				if chest_flow_overlay:
					chest_flow_overlay.show_preview_reveal("Creature_GL_HuskerKnight", "Gold", false)
				await get_tree().create_timer(0.4).timeout
	elif mode == "hub":
		# Auto tap start to transition into hub
		if start_overlay and start_overlay.visible:
			_on_start_tapped()
		await get_tree().create_timer(1.2).timeout
	else:
		await get_tree().create_timer(0.8).timeout
	
	var vp = get_viewport()
	if vp:
		var img = vp.get_texture().get_image()
		if img:
			var out_file = "../captured_godot_menu.png"
			if mode == "hub":
				out_file = "../captured_godot_hub.png"
			elif mode == "battle_select":
				out_file = "../captured_godot_battle_select.png"
			elif mode == "quest_fx_in":
				out_file = "../captured_godot_quest_fx_in.png"
			elif mode == "quest_fx_out":
				out_file = "../captured_godot_quest_fx_out.png"
			elif mode == "store":
				out_file = "../captured_godot_store.png"
			elif mode == "store_fx_in":
				out_file = "../captured_godot_store_fx_in.png"
			elif mode == "store_fx_out":
				out_file = "../captured_godot_store_fx_out.png"
			elif mode == "store_inventory":
				out_file = "../captured_godot_store_inventory.png"
			elif mode == "store_gems":
				out_file = "../captured_godot_store_gems.png"
			elif mode == "store_gems_anim":
				out_file = "../captured_godot_store_gems_anim.png"
			elif mode == "store_click_inv":
				out_file = "../captured_godot_store_click_inv.png"
			elif mode == "store_click_gems":
				out_file = "../captured_godot_store_click_gems.png"
			elif mode != "":
				out_file = "../captured_godot_%s.png" % mode
			img.save_png(out_file)
			print(">>> SCREENSHOT SAVED TO " + out_file + " <<<")
	get_tree().quit(0)

func _input(event: InputEvent) -> void:
	if start_overlay and start_overlay.visible:
		if event is InputEventKey and event.pressed:
			_on_start_tapped()
			return
		elif event is InputEventJoypadButton and event.pressed:
			_on_start_tapped()
			return
	
	if event.is_action_pressed("ui_cancel"):
		if store_inventory_modal and store_inventory_modal.visible:
			if store_inventory_modal.has_method("close_modal"):
				store_inventory_modal.close_modal()
			else:
				store_inventory_modal.visible = false
			return
		if store_gems_modal and store_gems_modal.visible:
			if store_gems_modal.has_method("close_modal"):
				store_gems_modal.close_modal()
			else:
				store_gems_modal.visible = false
			return
		if store_overlay and store_overlay.visible:
			_on_store_back_pressed()
			return
		if quest_overlay and quest_overlay.visible:
			_on_quest_back_pressed()
			return
		if quit_modal and not quit_modal.visible:
			_show_quit_modal()
		elif quit_modal and quit_modal.visible:
			quit_modal.visible = false

func _play_sfx() -> void:
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)

func _play_select_sfx() -> void:
	if Audio and SFX_UI_SELECT:
		Audio.play_sfx(SFX_UI_SELECT)
	elif Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)

func _connect_board_button(btn: BaseButton, press_method: String, pressed_handler: Callable) -> void:
	if not btn:
		return
	btn.button_down.connect(func():
		_press_select_sfx_played = true
		_play_select_sfx()
		if treehouse_3d and treehouse_3d.has_method(press_method):
			treehouse_3d.call(press_method, true)
	)
	btn.button_up.connect(func():
		if not btn.is_hovered():
			_press_select_sfx_played = false
			if treehouse_3d and treehouse_3d.has_method(press_method):
				treehouse_3d.call(press_method, false)
	)
	btn.pressed.connect(pressed_handler)

func _set_buttons_disabled(buttons: Array, disabled: bool) -> void:
	for btn in buttons:
		if btn:
			btn.disabled = disabled

func _trigger_board_icon_activate(buttons: Array, activate_method: String, on_done: Callable) -> void:
	if not _press_select_sfx_played:
		_play_select_sfx()
	_press_select_sfx_played = false
	if treehouse_3d and treehouse_3d.has_method(activate_method):
		_set_buttons_disabled(buttons, true)
		treehouse_3d.call(activate_method, func():
			_set_buttons_disabled(buttons, false)
			on_done.call()
		)
	else:
		on_done.call()

func _update_player_stats() -> void:
	var level = GameManager.player_level if "player_level" in GameManager else 1
	var xp = GameManager.player_xp if "player_xp" in GameManager else 56
	var max_xp = GameManager.xp_to_next_level if "xp_to_next_level" in GameManager else 106
	var stamina = GameManager.stamina if "stamina" in GameManager else 5
	var max_stamina = GameManager.max_stamina if "max_stamina" in GameManager else 5
	var gems: int = GameManager.get_gems() if GameManager.has_method("get_gems") else 5
	var coins: int = GameManager.get_coins() if GameManager.has_method("get_coins") else 143
	var total_cards: int = GameManager.get_total_card_count() if GameManager.has_method("get_total_card_count") else 14
	var max_inv: int = GameManager.get_max_inventory() if GameManager.has_method("get_max_inventory") else 50

	if level_label:
		level_label.text = "Lvl. %d" % level
	if xp_bar:
		xp_bar.max_value = max_xp
		xp_bar.value = xp
	if xp_label:
		xp_label.text = "%d/%d" % [xp, max_xp]
	if stamina_value_label:
		stamina_value_label.text = "%d/%d" % [stamina, max_stamina]
	if stamina_status_label:
		stamina_status_label.text = "Full" if stamina >= max_stamina else "04:30"
	if cards_label:
		cards_label.text = "%d/%d" % [total_cards, max_inv]
	if gems_label:
		gems_label.text = "%d" % gems
	if coins_label:
		coins_label.text = "%d" % coins
	if trophy_label:
		trophy_label.text = "0"

func _on_start_tapped() -> void:
	_play_sfx()
	if "menu_return_view" in GameManager:
		GameManager.menu_return_view = "hub"
	if start_overlay:
		var tween = create_tween()
		tween.tween_property(start_overlay, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): start_overlay.visible = false)
	
	if treehouse_3d and treehouse_3d.has_method("transition_to_hub"):
		treehouse_3d.transition_to_hub(0.8)
	
	if top_bar:
		top_bar.visible = true
		top_bar.modulate.a = 0.0
		create_tween().tween_property(top_bar, "modulate:a", 1.0, 0.4)
	if bottom_dock:
		bottom_dock.visible = true
		bottom_dock.modulate.a = 0.0
		create_tween().tween_property(bottom_dock, "modulate:a", 1.0, 0.4)

func _on_battle_pressed() -> void:
	_play_sfx()
	open_quest_mode_select()

func open_quest_mode_select() -> void:
	if "menu_return_view" in GameManager:
		GameManager.menu_return_view = "quest_select"
	if bottom_dock:
		var tw = create_tween()
		tw.tween_property(bottom_dock, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func(): bottom_dock.visible = false)
	
	if quest_overlay:
		quest_overlay.visible = true
		quest_overlay.modulate.a = 0.0
		var tw_o = create_tween()
		tw_o.tween_property(quest_overlay, "modulate:a", 1.0, 0.3)
	
	if treehouse_3d and treehouse_3d.has_method("show_quest_modes"):
		treehouse_3d.show_quest_modes()

func _on_quest_back_pressed() -> void:
	_play_sfx()
	close_quest_mode_select()

func close_quest_mode_select() -> void:
	if "menu_return_view" in GameManager:
		GameManager.menu_return_view = "hub"
	if quest_overlay:
		var tw_o = create_tween()
		tw_o.tween_property(quest_overlay, "modulate:a", 0.0, 0.2)
		tw_o.tween_callback(func(): quest_overlay.visible = false)
	
	if bottom_dock:
		bottom_dock.visible = true
		bottom_dock.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(bottom_dock, "modulate:a", 1.0, 0.3)
	
	if treehouse_3d and treehouse_3d.has_method("hide_quest_modes"):
		treehouse_3d.hide_quest_modes()

func _on_quests_pressed() -> void:
	_play_select_sfx()
	if treehouse_3d and treehouse_3d.has_method("play_quests_activate"):
		_set_buttons_disabled([quad_quests, quad_fionna, quad_deck_wars], true)
		treehouse_3d.play_quests_activate(func():
			_set_buttons_disabled([quad_quests, quad_fionna, quad_deck_wars], false)
			GameManager.open_campaign_map(0)
		)
	else:
		GameManager.open_campaign_map(0)

func _on_fionna_pressed() -> void:
	_play_select_sfx()
	if treehouse_3d and treehouse_3d.has_method("play_fionna_activate"):
		_set_buttons_disabled([quad_quests, quad_fionna, quad_deck_wars], true)
		treehouse_3d.play_fionna_activate(func():
			_set_buttons_disabled([quad_quests, quad_fionna, quad_deck_wars], false)
			GameManager.open_campaign_map(1)
		)
	else:
		GameManager.open_campaign_map(1)

func _on_deck_wars_pressed() -> void:
	_trigger_board_icon_activate([quad_quests, quad_fionna, quad_deck_wars], "play_deckwars_activate", func():
		if lan_modal:
			lan_modal.open_modal()
	)

func _on_dungeons_pressed() -> void:
	_play_sfx()
	if dungeon_modal:
		dungeon_modal.open_modal()

func _on_deck_pressed() -> void:
	_play_sfx()
	if deck_choice_modal:
		deck_choice_modal.visible = true
	else:
		GameManager.open_deck_builder()

func _on_open_deck_builder() -> void:
	_play_sfx()
	if deck_choice_modal:
		deck_choice_modal.visible = false
	GameManager.open_deck_builder()

func _on_open_compendium() -> void:
	_play_sfx()
	if deck_choice_modal:
		deck_choice_modal.visible = false
	_show_compendium()

func _on_store_pressed() -> void:
	_play_sfx()
	open_store()


func open_store() -> void:
	if "menu_return_view" in GameManager:
		GameManager.menu_return_view = "store"
	if bottom_dock:
		var tw = create_tween()
		tw.tween_property(bottom_dock, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func(): bottom_dock.visible = false)

	if store_overlay:
		store_overlay.visible = true
		store_overlay.modulate.a = 0.0
		var tw_o = create_tween()
		tw_o.tween_property(store_overlay, "modulate:a", 1.0, 0.3)

	if treehouse_3d and treehouse_3d.has_method("show_store_modes"):
		treehouse_3d.show_store_modes()


func _on_store_back_pressed() -> void:
	_play_sfx()
	close_store()


func close_store() -> void:
	if "menu_return_view" in GameManager:
		GameManager.menu_return_view = "hub"
	if store_overlay:
		var tw_o = create_tween()
		tw_o.tween_property(store_overlay, "modulate:a", 0.0, 0.2)
		tw_o.tween_callback(func(): store_overlay.visible = false)

	if bottom_dock:
		bottom_dock.visible = true
		bottom_dock.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(bottom_dock, "modulate:a", 1.0, 0.3)

	if treehouse_3d and treehouse_3d.has_method("hide_store_modes"):
		treehouse_3d.hide_store_modes()


func _open_store_modal(modal: Control) -> void:
	if modal:
		if modal.has_method("open_modal"):
			modal.open_modal()
		else:
			modal.visible = true


func _on_quad_inventory_pressed() -> void:
	_trigger_board_icon_activate([quad_inventory, quad_gems], "play_store_inventory_activate", func():
		_open_store_modal(store_inventory_modal)
	)


func _on_quad_gems_pressed() -> void:
	_trigger_board_icon_activate([quad_inventory, quad_gems], "play_store_gems_activate", func():
		_open_store_modal(store_gems_modal)
	)

func _on_chests_pressed() -> void:
	_play_select_sfx()
	open_chests()


func open_chests() -> void:
	if "menu_return_view" in GameManager:
		GameManager.menu_return_view = "chests"
	if bottom_dock:
		var tw = create_tween()
		tw.tween_property(bottom_dock, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func(): bottom_dock.visible = false)

	if chests_overlay:
		chests_overlay.visible = true
		chests_overlay.modulate.a = 0.0
		var tw_o = create_tween()
		tw_o.tween_property(chests_overlay, "modulate:a", 1.0, 0.3)

	if treehouse_3d and treehouse_3d.has_method("show_chests_modes"):
		treehouse_3d.show_chests_modes()


func _on_chests_back_pressed() -> void:
	if Audio and SFX_UI_BACK:
		Audio.play_sfx(SFX_UI_BACK)
	else:
		_play_sfx()
	close_chests()


func close_chests() -> void:
	if "menu_return_view" in GameManager:
		GameManager.menu_return_view = "hub"
	if chest_flow_overlay:
		chest_flow_overlay.reset_immediately()
	if chests_overlay:
		var tw_o = create_tween()
		tw_o.tween_property(chests_overlay, "modulate:a", 0.0, 0.2)
		tw_o.tween_callback(func(): chests_overlay.visible = false)

	if bottom_dock:
		bottom_dock.visible = true
		bottom_dock.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(bottom_dock, "modulate:a", 1.0, 0.3)

	if treehouse_3d and treehouse_3d.has_method("hide_chests_modes"):
		treehouse_3d.hide_chests_modes()


func _on_quad_cool_chest_pressed() -> void:
	_trigger_board_icon_activate([quad_cool_chest, quad_algebraic_chest], "play_cool_chest_activate", func():
		_open_chest_confirm("cool")
	)


func _on_quad_algebraic_chest_pressed() -> void:
	_trigger_board_icon_activate([quad_cool_chest, quad_algebraic_chest], "play_algebraic_chest_activate", func():
		_open_chest_confirm("algebraic")
	)


func _open_chest_confirm(chest_key: String) -> void:
	if treehouse_3d and treehouse_3d.has_method("set_chests_idle_audio_enabled"):
		treehouse_3d.set_chests_idle_audio_enabled(false)
	var icon: ChestIconBase = treehouse_3d.get_chest_icon(chest_key) if treehouse_3d and treehouse_3d.has_method("get_chest_icon") else null
	if chest_flow_overlay:
		chest_flow_overlay.open_confirm(chest_key, icon)


func _on_chest_flow_closed() -> void:
	if chests_overlay and chests_overlay.visible and treehouse_3d and treehouse_3d.has_method("set_chests_idle_audio_enabled"):
		treehouse_3d.set_chests_idle_audio_enabled(true)


func _on_chest_opening_started(chest_key: String) -> void:
	if chests_overlay:
		chests_overlay.visible = false
	if treehouse_3d and treehouse_3d.has_method("focus_chest"):
		treehouse_3d.focus_chest(chest_key, 0.45)
	_update_player_stats()


func _on_chest_flow_finished() -> void:
	if treehouse_3d and treehouse_3d.has_method("unfocus_chest"):
		treehouse_3d.unfocus_chest(0.35)
	if chests_overlay:
		chests_overlay.visible = true
		chests_overlay.modulate.a = 0.0
		var tw_o := create_tween()
		tw_o.tween_property(chests_overlay, "modulate:a", 1.0, 0.28)
	if treehouse_3d and treehouse_3d.has_method("set_chests_idle_audio_enabled"):
		treehouse_3d.set_chests_idle_audio_enabled(true)
	_update_player_stats()


func _on_chest_request_store_inventory() -> void:
	_switch_chests_to_store_modal(store_inventory_modal)


func _on_chest_request_store_gems() -> void:
	_switch_chests_to_store_modal(store_gems_modal)


func _switch_chests_to_store_modal(modal: Control) -> void:
	if "menu_return_view" in GameManager:
		GameManager.menu_return_view = "store"
	if chests_overlay:
		chests_overlay.visible = false
	if store_overlay:
		store_overlay.visible = true
		store_overlay.modulate.a = 1.0
	if treehouse_3d and treehouse_3d.has_method("set_store_modes_view"):
		treehouse_3d.set_store_modes_view()
	_open_store_modal(modal)

func _on_settings_pressed() -> void:
	_play_sfx()
	if settings_modal:
		settings_modal.open_modal()

func _on_versus_pressed() -> void:
	_play_sfx()
	if versus_modal:
		versus_modal.open_modal()

func _on_lan_pressed() -> void:
	_play_sfx()
	if lan_modal:
		lan_modal.open_modal()

func _show_quit_modal() -> void:
	_play_sfx()
	if quit_modal:
		quit_modal.visible = true

func _on_quit_confirm_pressed() -> void:
	_play_sfx()
	get_tree().quit()

func _on_quit_cancel_pressed() -> void:
	_play_sfx()
	if quit_modal:
		quit_modal.visible = false

func _show_compendium() -> void:
	if compendium_dialog:
		compendium_dialog.visible = true
		if cards_grid and cards_grid.get_child_count() == 0:
			_populate_compendium()

func _populate_compendium() -> void:
	var creatures = Database.creatures_list
	if compendium_count_label:
		compendium_count_label.text = "Browsing %d Original Cards" % creatures.size()
	for card in creatures:
		var card_view = preload("res://scenes/components/CardView.tscn").instantiate()
		cards_grid.add_child(card_view)
		card_view.render_card(card)

func _on_close_compendium_pressed() -> void:
	_play_sfx()
	if compendium_dialog:
		compendium_dialog.visible = false
