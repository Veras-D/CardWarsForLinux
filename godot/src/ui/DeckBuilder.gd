extends Control
class_name DeckBuilder

## Authentic Unity DeckManager Build Deck screen (B_0_BuildDeck + B_1_AddPanel +
## B_2_ZoomCard + B_2_ZoomLeader + B_3_Confirm + B_4_SelectHero + B_5_SortPanel +
## B_6_SortPanelB1 + B_7_BattleDeckError), plus backward-compatible API for
## DeckValidator/FusionEngine tests.

const DeckValidator = preload("res://src/cards/DeckValidator.gd")
const FusionEngine = preload("res://src/cards/FusionEngine.gd")
const CardViewScene: PackedScene = preload("res://scenes/components/CardView.tscn")

const FONT_KB: FontFile = preload("res://assets/fonts/KBPlanetEarth.ttf")
const TEX_HERO_FRAME: Texture2D = preload("res://assets/textures/ui/deck/Frame_Hero.png")
const TEX_CW_GREY: Texture2D = preload("res://assets/textures/ui/cards/CW_Grey.png")
const TEX_BTN_BLUE: Texture2D = preload("res://assets/textures/ui/forge/uiButtonBlue.png")
const TEX_STACK_CIRCLE: Texture2D = preload("res://assets/textures/ui/deck/Stack_Circle.png")
const TEX_IN_DECK_HERO: Texture2D = preload("res://assets/textures/ui/forge/Bottle_Empty.png")
const TEX_LANDSCAPE_FRAME: Texture2D = preload("res://assets/textures/ui/deck/Frame_Base_Landscape.png")

const LANDSCAPE_TEXTURES := {
	"Corn": preload("res://assets/textures/ui/deck/Landscape_Corn1.png"),
	"Cotton": preload("res://assets/textures/ui/deck/Landscape_Cotton1.png"),
	"Plains": preload("res://assets/textures/ui/deck/Landscape_Plains1.png"),
	"Swamp": preload("res://assets/textures/ui/deck/Landscape_Swamp1.png"),
	"Sand": preload("res://assets/textures/ui/deck/Landscape_Sand1.png"),
}

const LANDSCAPE_CYCLE: Array[String] = ["Corn", "Cotton", "Swamp", "Plains", "Sand"]
const LANDSCAPE_DISPLAY_NAMES := {
	"Corn": "Corn Fields",
	"Cotton": "Nice Lands",
	"Swamp": "Useless Swamp",
	"Plains": "Blue Plains",
	"Sand": "Sandy Lands",
}

const FACTION_COLORS := {
	"Corn": Color(1.0, 239.0 / 255.0, 108.0 / 255.0),
	"Plains": Color(108.0 / 255.0, 205.0 / 255.0, 240.0 / 255.0),
	"Cotton": Color(243.0 / 255.0, 122.0 / 255.0, 176.0 / 255.0),
	"Sand": Color(217.0 / 255.0, 170.0 / 255.0, 133.0 / 255.0),
	"Swamp": Color(103.0 / 255.0, 143.0 / 255.0, 47.0 / 255.0),
	"Universal": Color(1.0, 1.0, 1.0),
}

const SFX_SELECT: AudioStream = preload("res://assets/audio/sfx/UI_Select.wav")
const SFX_BACK: AudioStream = preload("res://assets/audio/sfx/UI_Back.wav")
const SFX_CARD_CLICK: AudioStream = preload("res://assets/audio/sfx/ButtonClick5.wav")
const SFX_ZOOM: AudioStream = preload("res://assets/audio/sfx/Card_Double_Click.wav")

signal closed
signal deck_saved(deck_name: String, file_path: String)
signal deck_loaded(deck_name: String)
signal card_fused(output_card_id: String)

enum SortField {
	NONE = 0,
	ATK = 1,
	DEF = 2,
	TYPE = 3,
	NAME = 4,
	FACT = 5,
	RARE = 6,
	MP = 7,
}

# Active state (synced with GameManager slot + test-compatible fields)
var current_deck_index: int = 0
var current_deck_name: String = "Jake Starter Deck"
var current_leader_id: String = "Jake"
var current_landscapes: Array[String] = ["Corn", "Corn", "Corn", "Swamp"]
var current_deck_cards: Array[String] = []

# B_0 sort/filter state
var _b0_primary_sort: int = SortField.TYPE
var _b0_secondary_sort: int = SortField.FACT
var _b0_filter_type: String = "" # "" = ALL, "CREATURE", "SPELL", "BUILDING"

# B_1 Edit Deck state
var _b1_chosen_cards: Array[String] = [] # copies added from owned_pool_order
var _b1_owned_pool: Array[String] = []  # fixed order of owned copies for active edit session
var _b1_chosen_indices: Dictionary = {} # pool_idx -> true
var _b1_filter_type: String = "CREATURE"
var _b1_primary_sort: int = SortField.NONE
var _b1_secondary_sort: int = SortField.NONE

# B_4 Select Hero & B_3 Landscape staging state
var _selected_hero_candidate_id: String = ""
var _staged_landscapes: Array[String] = ["Corn", "Corn", "Corn", "Corn"]
var _is_embedded_modal: bool = false
var _is_closing: bool = false
var _error_return_target: String = ""

# Node references
@onready var standalone_backdrop: ColorRect = $StandaloneBackdrop
@onready var standalone_topbar: Control = $DeckCanvas/StandaloneTopBar
@onready var standalone_player_lbl: Label = $DeckCanvas/StandaloneTopBar/PlayerLabel
@onready var standalone_inv_lbl: Label = $DeckCanvas/StandaloneTopBar/InventoryLabel

@onready var b0_panel: Control = $DeckCanvas/B_0_BuildDeck
@onready var popup_fade: ColorRect = $DeckCanvas/PopUpFade
@onready var deck_number_lbl: Label = $DeckCanvas/B_0_BuildDeck/LeftPane/NameplateRoot/DeckNumber
@onready var prev_deck_btn: TextureButton = $DeckCanvas/B_0_BuildDeck/LeftPane/NameplateRoot/ButtonPrevDeck
@onready var next_deck_btn: TextureButton = $DeckCanvas/B_0_BuildDeck/LeftPane/NameplateRoot/ButtonNextDeck

@onready var hero_card_btn: Control = $DeckCanvas/B_0_BuildDeck/LeftPane/HeroCard
@onready var hero_art_rect: TextureRect = $DeckCanvas/B_0_BuildDeck/LeftPane/HeroCard/CardArt
@onready var hero_xp_progress: TextureRect = $DeckCanvas/B_0_BuildDeck/LeftPane/HeroCard/XPBarProgress
@onready var hero_level_lbl: Label = $DeckCanvas/B_0_BuildDeck/LeftPane/HeroCard/LevelLabel
@onready var hero_hp_lbl: Label = $DeckCanvas/B_0_BuildDeck/LeftPane/HeroCard/HPLabel
@onready var hero_name_lbl: Label = $DeckCanvas/B_0_BuildDeck/LeftPane/HeroCard/NameLabel
@onready var hero_desc_lbl: Label = $DeckCanvas/B_0_BuildDeck/LeftPane/HeroCard/DescLabel
@onready var hero_tonext_lbl: Label = $DeckCanvas/B_0_BuildDeck/LeftPane/HeroCard/ToNextLabel
@onready var swap_hero_lbl: Label = $DeckCanvas/B_0_BuildDeck/LeftPane/HeroCard/SwapHeroLabel

@onready var battle_deck_btn: TextureButton = $DeckCanvas/B_0_BuildDeck/LeftPane/BattleDeckButton
@onready var battle_deck_bg: NinePatchRect = $DeckCanvas/B_0_BuildDeck/LeftPane/BattleDeckButton/BG
@onready var battle_deck_lbl: Label = $DeckCanvas/B_0_BuildDeck/LeftPane/BattleDeckButton/Label

@onready var deck_size_lbl: Label = $DeckCanvas/B_0_BuildDeck/DeckSizeRow
@onready var tab_creatures_lbl: Label = $DeckCanvas/B_0_BuildDeck/TopTabs/Creatures/SizeBG/SizeLabel
@onready var tab_spells_lbl: Label = $DeckCanvas/B_0_BuildDeck/TopTabs/Spells/SizeBG/SizeLabel
@onready var tab_buildings_lbl: Label = $DeckCanvas/B_0_BuildDeck/TopTabs/Buildings/SizeBG/SizeLabel

@onready var b0_scroll: ScrollContainer = $DeckCanvas/B_0_BuildDeck/CardGridBG/DeckScroll
@onready var b0_columns: HBoxContainer = $DeckCanvas/B_0_BuildDeck/CardGridBG/DeckScroll/DeckColumns
@onready var b0_sb_bg: NinePatchRect = $DeckCanvas/B_0_BuildDeck/CardGridBG/ScrollBarBG
@onready var b0_sb_thumb: NinePatchRect = $DeckCanvas/B_0_BuildDeck/CardGridBG/ScrollBarBG/Thumb

@onready var b0_sort_btn: TextureButton = $DeckCanvas/B_0_BuildDeck/BottomButtons/SortButton
@onready var b0_landscape_btn: TextureButton = $DeckCanvas/B_0_BuildDeck/BottomButtons/LandscapeButton
@onready var b0_edit_btn: TextureButton = $DeckCanvas/B_0_BuildDeck/BottomButtons/EditDeckButton
@onready var back_btn: TextureButton = $DeckCanvas/B_0_BuildDeck/BackBtn

# B_1 Edit Deck
@onready var b1_panel: Control = $DeckCanvas/B_1_AddPanel
@onready var b1_creatures_btn: TextureButton = $DeckCanvas/B_1_AddPanel/CreaturesButton
@onready var b1_creatures_scale: Control = $DeckCanvas/B_1_AddPanel/CreaturesButton/ScaleRoot
@onready var b1_creatures_count: Label = $DeckCanvas/B_1_AddPanel/CreaturesButton/ScaleRoot/StackBG/StackText
@onready var b1_spells_btn: TextureButton = $DeckCanvas/B_1_AddPanel/SpellsButton
@onready var b1_spells_scale: Control = $DeckCanvas/B_1_AddPanel/SpellsButton/ScaleRoot
@onready var b1_spells_count: Label = $DeckCanvas/B_1_AddPanel/SpellsButton/ScaleRoot/StackBG/StackText
@onready var b1_buildings_btn: TextureButton = $DeckCanvas/B_1_AddPanel/BuildingsButton
@onready var b1_buildings_scale: Control = $DeckCanvas/B_1_AddPanel/BuildingsButton/ScaleRoot
@onready var b1_buildings_count: Label = $DeckCanvas/B_1_AddPanel/BuildingsButton/ScaleRoot/StackBG/StackText
@onready var b1_scroll: ScrollContainer = $DeckCanvas/B_1_AddPanel/TableRoot/AddScroll
@onready var b1_columns: HBoxContainer = $DeckCanvas/B_1_AddPanel/TableRoot/AddScroll/AddColumns
@onready var b1_sb_bg: NinePatchRect = $DeckCanvas/B_1_AddPanel/TableRoot/ScrollBarBG
@onready var b1_sb_thumb: NinePatchRect = $DeckCanvas/B_1_AddPanel/TableRoot/ScrollBarBG/Thumb
@onready var b1_sort_btn: TextureButton = $DeckCanvas/B_1_AddPanel/SortButton
@onready var b1_total_lbl: Label = $DeckCanvas/B_1_AddPanel/TotalSizeLabel
@onready var b1_cancel_btn: TextureButton = $DeckCanvas/B_1_AddPanel/CancelButton
@onready var b1_confirm_btn: TextureButton = $DeckCanvas/B_1_AddPanel/ConfirmButton

# B_4 Select Hero
@onready var b4_panel: Control = $DeckCanvas/B_4_SelectHero
@onready var b4_scroll: ScrollContainer = $DeckCanvas/B_4_SelectHero/TableRoot/HeroScroll
@onready var b4_columns: HBoxContainer = $DeckCanvas/B_4_SelectHero/TableRoot/HeroScroll/HeroColumns
@onready var b4_sb_bg: NinePatchRect = $DeckCanvas/B_4_SelectHero/TableRoot/ScrollBarBG
@onready var b4_sb_thumb: NinePatchRect = $DeckCanvas/B_4_SelectHero/TableRoot/ScrollBarBG/Thumb
@onready var b4_cancel_btn: TextureButton = $DeckCanvas/B_4_SelectHero/CloseButton
@onready var b4_confirm_btn: TextureButton = $DeckCanvas/B_4_SelectHero/SelectButton

# B_3 Landscapes
@onready var b3_panel: Control = $DeckCanvas/B_3_Confirm
@onready var b3_cards_hbox: HBoxContainer = $DeckCanvas/B_3_Confirm/CardsFrame/CardsHBox
@onready var b3_cancel_btn: TextureButton = $DeckCanvas/B_3_Confirm/CloseButton
@onready var b3_confirm_btn: TextureButton = $DeckCanvas/B_3_Confirm/OKButton

# B_5 & B_6 Sort Popups
@onready var b5_panel: Control = $DeckCanvas/B_5_SortPanel
@onready var b5_close_btn: TextureButton = $DeckCanvas/B_5_SortPanel/CloseButton
@onready var b5_grid: GridContainer = $DeckCanvas/B_5_SortPanel/ButtonsGrid
@onready var b6_panel: Control = $DeckCanvas/B_6_SortPanelB1
@onready var b6_close_btn: TextureButton = $DeckCanvas/B_6_SortPanelB1/CloseButton
@onready var b6_grid: GridContainer = $DeckCanvas/B_6_SortPanelB1/ButtonsGrid

# Zoom & Error
@onready var zoom_overlay: Control = $DeckCanvas/ZoomOverlay
@onready var zoom_holder: Control = $DeckCanvas/ZoomOverlay/CardHolder
@onready var b7_error_panel: Control = $DeckCanvas/B_7_BattleDeckError
@onready var b7_panel_box: Control = $DeckCanvas/B_7_BattleDeckError/Panel
@onready var b7_message_lbl: Label = $DeckCanvas/B_7_BattleDeckError/Panel/MessageLabel
@onready var b7_ok_btn: TextureButton = $DeckCanvas/B_7_BattleDeckError/Panel/OKButton

# Backward-compatible test properties
@onready var deck_name_edit: LineEdit = $DeckNameEditCompat
@onready var fusion_modal: Panel = $FusionModal
@onready var fusion_coins_label: Label = $FusionModal/VBox/Header/CoinsLabel
@onready var close_fusion_btn: Button = $FusionModal/VBox/Header/CloseFusionBtn
@onready var fusion_search_edit: LineEdit = $FusionModal/VBox/FilterBar/FusionSearchEdit
@onready var quality_filter_select: OptionButton = $FusionModal/VBox/FilterBar/QualityFilterSelect
@onready var fusion_status_label: Label = $FusionModal/VBox/FilterBar/FusionStatusLabel
@onready var recipe_list_vbox: VBoxContainer = $FusionModal/VBox/RecipeScroll/RecipeListVBox
var save_btn: Button = null
var fusion_search_text: String = ""
var selected_fusion_quality: int = -1

# Idle / pulse tweens & non-leaking long-press tracker
var _swap_pulse_tween: Tween = null
var _arrow_pulse_tween: Tween = null
var _tab_pulse_tween: Tween = null
var _pending_long_press: Dictionary = {} # {"ref": WeakRef, "start_pos": Vector2, "elapsed": float, "fired": bool, "cb": Callable}


func _ready() -> void:
	GameManager.ensure_decks_initialized()
	save_btn = Button.new()
	save_btn.visible = false
	add_child(save_btn)

	_is_embedded_modal = get_parent() != null and get_parent() != get_tree().root
	if standalone_backdrop:
		standalone_backdrop.visible = not _is_embedded_modal
	if standalone_topbar:
		standalone_topbar.visible = not _is_embedded_modal

	current_deck_index = GameManager.current_deck_index
	_load_state_from_slot(current_deck_index)

	_setup_sort_panels()
	_connect_signals()
	_start_idle_pulses()
	refresh_all()

	if _is_embedded_modal:
		visible = false
	else:
		visible = true
		_play_b0_open_anim()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_modal()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _pending_long_press.is_empty():
		return
	var wr: WeakRef = _pending_long_press.get("ref", null)
	var target: Object = wr.get_ref() if wr != null else null
	if target == null or not is_instance_valid(target) or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_pending_long_press.clear()
		return
	if bool(_pending_long_press.get("fired", false)):
		return
	var dist := get_viewport().get_mouse_position().distance_to(_pending_long_press.get("start_pos", Vector2.ZERO))
	if dist >= 18.0:
		_pending_long_press.clear()
		return
	var elapsed := float(_pending_long_press.get("elapsed", 0.0)) + delta
	_pending_long_press["elapsed"] = elapsed
	if elapsed >= 0.45:
		_pending_long_press["fired"] = true
		var cb: Callable = _pending_long_press.get("cb", Callable())
		if cb.is_valid():
			cb.call(target)
		_pending_long_press.clear()


func open_modal() -> void:
	_is_closing = false
	GameManager.ensure_decks_initialized()
	current_deck_index = GameManager.current_deck_index
	_load_state_from_slot(current_deck_index)
	_b0_filter_type = ""
	_b0_primary_sort = SortField.TYPE
	_b0_secondary_sort = SortField.FACT
	_hide_all_subpanels()
	if popup_fade:
		popup_fade.visible = false
	visible = true
	b0_panel.visible = true
	refresh_all()
	_play_b0_open_anim()
	_start_idle_pulses()


func show_panel_preview(subpanel: String) -> void:
	## Deterministic helper for automated visual verification screenshots
	open_modal()
	if swap_hero_lbl:
		swap_hero_lbl.modulate.a = 1.0
	if subpanel == "build_deck":
		return
	elif subpanel == "edit_deck":
		_open_b1_add_panel(false)
	elif subpanel == "select_hero":
		_open_b4_select_hero(false)
	elif subpanel == "landscapes":
		_open_b3_landscapes(false)
	elif subpanel == "sort_deck":
		_open_b5_sort_panel(false)
	elif subpanel == "zoom_card":
		_open_zoom_card("Creature_BurningBush", null)
		if zoom_holder:
			zoom_holder.scale = Vector2.ONE


func close_modal() -> void:
	if zoom_overlay and zoom_overlay.visible:
		_close_zoom_overlay()
		return
	if b7_error_panel and b7_error_panel.visible:
		_close_b7_error()
		return
	if b6_panel and b6_panel.visible:
		_close_b6_sort_panel()
		return
	if b5_panel and b5_panel.visible:
		_close_b5_sort_panel()
		return
	if b1_panel and b1_panel.visible:
		_close_b1_add_panel()
		return
	if b4_panel and b4_panel.visible:
		_close_b4_select_hero()
		return
	if b3_panel and b3_panel.visible:
		_close_b3_landscapes()
		return
	_on_back_pressed()


func _hide_all_subpanels() -> void:
	for p in [b1_panel, b4_panel, b3_panel, b5_panel, b6_panel, zoom_overlay, b7_error_panel]:
		if p:
			p.visible = false


func _load_state_from_slot(idx: int) -> void:
	var slot := GameManager.get_deck_slot(idx)
	current_deck_name = str(slot.get("name", GameManager.active_deck_name))
	if idx == GameManager.battle_deck_index and GameManager.player_deck.size() > 0:
		# Keep live GameManager.player_deck synchronized when slot holds battle deck
		slot["cards"] = GameManager.player_deck.duplicate()
		slot["leader"] = GameManager._normalize_hero_id(GameManager.player_hero_name)
		slot["landscapes"] = GameManager.player_landscapes.duplicate()

	current_deck_cards.clear()
	for c in slot.get("cards", []):
		current_deck_cards.append(str(c))
	var lid := str(slot.get("leader", "Leader_Jake"))
	var ldata := Database.get_leader(lid)
	current_leader_id = str(ldata.get("character_id", lid.replace("Leader_", ""))) if not ldata.is_empty() else lid.replace("Leader_", "")
	if current_leader_id == "Fionna":
		current_leader_id = "Fiona"
	current_landscapes.clear()
	for l in slot.get("landscapes", ["Corn", "Corn", "Corn", "Corn"]):
		current_landscapes.append(str(l))
	while current_landscapes.size() < 4:
		current_landscapes.append("Corn")
	if deck_name_edit:
		deck_name_edit.text = current_deck_name


func _connect_signals() -> void:
	if prev_deck_btn:
		_attach_btn_bounce(prev_deck_btn, 1.0)
		prev_deck_btn.pressed.connect(_on_prev_deck_pressed)
	if next_deck_btn:
		_attach_btn_bounce(next_deck_btn, 1.0)
		next_deck_btn.pressed.connect(_on_next_deck_pressed)
	if battle_deck_btn:
		_attach_btn_bounce(battle_deck_btn, 0.9)
		battle_deck_btn.pressed.connect(_on_battle_deck_pressed)
	if b0_sort_btn:
		_attach_btn_bounce(b0_sort_btn, 0.9)
		b0_sort_btn.pressed.connect(func():
			_play_sfx(SFX_SELECT)
			_open_b5_sort_panel(true)
		)
	if b0_landscape_btn:
		_attach_btn_bounce(b0_landscape_btn, 0.9)
		b0_landscape_btn.pressed.connect(func():
			if current_deck_cards.is_empty():
				return
			_play_sfx(SFX_SELECT)
			_open_b3_landscapes(true)
		)
	if b0_edit_btn:
		_attach_btn_bounce(b0_edit_btn, 0.9)
		b0_edit_btn.pressed.connect(func():
			_play_sfx(SFX_SELECT)
			_open_b1_add_panel(true)
		)
	if back_btn:
		_attach_btn_bounce(back_btn, 1.0)
		back_btn.pressed.connect(_on_back_pressed)

	if hero_card_btn:
		hero_card_btn.gui_input.connect(_on_hero_card_gui_input)

	# B_1 Edit Deck
	if b1_creatures_btn:
		b1_creatures_btn.pressed.connect(func(): _on_b1_type_selected("CREATURE"))
	if b1_spells_btn:
		b1_spells_btn.pressed.connect(func(): _on_b1_type_selected("SPELL"))
	if b1_buildings_btn:
		b1_buildings_btn.pressed.connect(func(): _on_b1_type_selected("BUILDING"))
	if b1_sort_btn:
		_attach_btn_bounce(b1_sort_btn, 0.9)
		b1_sort_btn.pressed.connect(func():
			_play_sfx(SFX_SELECT)
			_open_b6_sort_panel(true)
		)
	if b1_cancel_btn:
		_attach_btn_bounce(b1_cancel_btn, 0.9)
		b1_cancel_btn.pressed.connect(func():
			_play_sfx(SFX_BACK)
			_close_b1_add_panel()
		)
	if b1_confirm_btn:
		_attach_btn_bounce(b1_confirm_btn, 0.9)
		b1_confirm_btn.pressed.connect(_on_b1_confirm_pressed)

	# B_4 Select Hero
	if b4_cancel_btn:
		_attach_btn_bounce(b4_cancel_btn, 1.0)
		b4_cancel_btn.pressed.connect(func():
			_play_sfx(SFX_BACK)
			_close_b4_select_hero()
		)
	if b4_confirm_btn:
		_attach_btn_bounce(b4_confirm_btn, 1.0)
		b4_confirm_btn.pressed.connect(_on_b4_confirm_pressed)

	# B_3 Landscapes
	if b3_cancel_btn:
		_attach_btn_bounce(b3_cancel_btn, 1.0)
		b3_cancel_btn.pressed.connect(func():
			_play_sfx(SFX_BACK)
			_close_b3_landscapes()
		)
	if b3_confirm_btn:
		_attach_btn_bounce(b3_confirm_btn, 1.0)
		b3_confirm_btn.pressed.connect(_on_b3_confirm_pressed)

	# Sort close buttons
	if b5_close_btn:
		_attach_btn_bounce(b5_close_btn, 0.7)
		b5_close_btn.pressed.connect(func():
			_play_sfx(SFX_BACK)
			_close_b5_sort_panel()
		)
	if b6_close_btn:
		_attach_btn_bounce(b6_close_btn, 0.7)
		b6_close_btn.pressed.connect(func():
			_play_sfx(SFX_BACK)
			_close_b6_sort_panel()
		)

	# Zoom close on tap anywhere
	if zoom_overlay:
		zoom_overlay.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_close_zoom_overlay()
		)

	# B_7 Error OK button
	if b7_ok_btn:
		_attach_btn_bounce(b7_ok_btn, 1.0)
		b7_ok_btn.pressed.connect(func():
			_play_sfx(SFX_SELECT)
			_close_b7_error()
		)

	# Scrollbar sync
	if b0_scroll:
		b0_scroll.get_h_scroll_bar().value_changed.connect(func(_v): _sync_scrollbar(b0_scroll, b0_sb_bg, b0_sb_thumb))
	if b1_scroll:
		b1_scroll.get_h_scroll_bar().value_changed.connect(func(_v): _sync_scrollbar(b1_scroll, b1_sb_bg, b1_sb_thumb))
	if b4_scroll:
		b4_scroll.get_h_scroll_bar().value_changed.connect(func(_v): _sync_scrollbar(b4_scroll, b4_sb_bg, b4_sb_thumb))

	# Compatibility fusion modal close
	if close_fusion_btn:
		close_fusion_btn.pressed.connect(close_fusion_modal)
	if fusion_search_edit:
		fusion_search_edit.text_changed.connect(func(q: String):
			fusion_search_text = q
			refresh_fusion_modal()
		)


func _start_idle_pulses() -> void:
	if _swap_pulse_tween and _swap_pulse_tween.is_valid():
		_swap_pulse_tween.kill()
	if swap_hero_lbl:
		swap_hero_lbl.modulate.a = 1.0
		_swap_pulse_tween = create_tween().set_loops()
		_swap_pulse_tween.tween_property(swap_hero_lbl, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_swap_pulse_tween.tween_property(swap_hero_lbl, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if _arrow_pulse_tween and _arrow_pulse_tween.is_valid():
		_arrow_pulse_tween.kill()
	if prev_deck_btn and next_deck_btn:
		_arrow_pulse_tween = create_tween().set_loops().set_parallel(true)
		_arrow_pulse_tween.tween_property(prev_deck_btn, "scale", Vector2(1.1, 1.1), 1.0).set_trans(Tween.TRANS_SINE)
		_arrow_pulse_tween.tween_property(next_deck_btn, "scale", Vector2(1.1, 1.1), 1.0).set_trans(Tween.TRANS_SINE)
		_arrow_pulse_tween.chain().tween_property(prev_deck_btn, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_SINE)
		_arrow_pulse_tween.parallel().tween_property(next_deck_btn, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_SINE)


func _attach_btn_bounce(btn: Control, base_scale: float = 1.0) -> void:
	if not btn:
		return
	btn.button_down.connect(func():
		btn.scale = Vector2(base_scale * 0.93, base_scale * 0.93)
	)
	btn.button_up.connect(func():
		btn.scale = Vector2(base_scale, base_scale)
	)


func _play_sfx(stream: AudioStream) -> void:
	if stream != null and Audio:
		Audio.play_sfx(stream)


func _play_b0_open_anim() -> void:
	if not b0_panel:
		return
	b0_panel.scale = Vector2(0.05, 0.05)
	var tw := create_tween()
	tw.tween_property(b0_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ==============================================================================
# B_0 BUILD DECK MAIN VIEW REFRESH
# ==============================================================================

func refresh_all() -> void:
	_refresh_nameplate()
	_refresh_hero_panel()
	_refresh_battle_deck_toggle()
	_refresh_counts_and_size()
	_refresh_b0_grid()
	_refresh_compat_save_state()


func _refresh_compat_save_state() -> void:
	if save_btn == null:
		return
	var max_sz := GameManager.get_hero_deck_max_size(current_leader_id)
	var dup_ok := true
	var counts: Dictionary = {}
	for cid in current_deck_cards:
		var k := str(cid)
		counts[k] = int(counts.get(k, 0)) + 1
		if int(counts[k]) > GameManager.MAX_DUPLICATES_IN_DECK:
			dup_ok = false
			break
	save_btn.disabled = not (current_deck_cards.size() >= GameManager.MIN_CARDS_IN_DECK and current_deck_cards.size() <= max_sz and dup_ok)


func _refresh_nameplate() -> void:
	if deck_number_lbl:
		deck_number_lbl.text = str(current_deck_index + 1)
	if b0_landscape_btn:
		var has_cards := not current_deck_cards.is_empty()
		b0_landscape_btn.disabled = not has_cards
		b0_landscape_btn.modulate = Color.WHITE if has_cards else Color(0.4, 0.4, 0.4, 1.0)
	if standalone_player_lbl:
		standalone_player_lbl.text = "%s   Lvl. %d" % [GameManager.player_hero_name, GameManager.get_hero_level(GameManager.player_hero_name)]
	if standalone_inv_lbl:
		standalone_inv_lbl.text = "%d/%d" % [GameManager.get_total_card_count(), GameManager.get_max_inventory()]


func _refresh_hero_panel() -> void:
	var norm_lid := GameManager._normalize_hero_id(current_leader_id)
	var ldata := Database.get_leader(norm_lid)
	var char_id := str(ldata.get("character_id", current_leader_id)) if not ldata.is_empty() else current_leader_id
	var lvl := GameManager.get_hero_level(norm_lid)
	var hp := GameManager.get_hero_max_hp(norm_lid)
	var tracker := GameManager.get_hero_tracker(norm_lid)
	var needed := tracker.get_xp_for_next_level()
	var to_next := maxi(0, needed - tracker.current_xp) if not tracker.is_max_level() else 0
	var ratio := tracker.get_progress_ratio()

	if hero_level_lbl:
		hero_level_lbl.text = "Level: %d" % lvl
	if hero_hp_lbl:
		hero_hp_lbl.text = str(hp)
	if hero_name_lbl:
		hero_name_lbl.text = str(ldata.get("name", char_id)) if not ldata.is_empty() else char_id
	if hero_desc_lbl:
		hero_desc_lbl.text = str(ldata.get("desc", ""))
	if hero_tonext_lbl:
		hero_tonext_lbl.text = "To Next:%d" % to_next
	if hero_xp_progress:
		hero_xp_progress.offset_right = 56.5 + 195.0 * ratio
	if hero_art_rect:
		hero_art_rect.texture = _load_hero_portrait(ldata, char_id)


func _load_hero_portrait(ldata: Dictionary, char_id: String) -> Texture2D:
	var candidates: Array[String] = []
	var sp_hero := str(ldata.get("sprite_name_hero", "")).strip_edges()
	var sp := str(ldata.get("sprite_name", "")).strip_edges()
	if sp != "":
		candidates.append("res://assets/textures/questmap/portraits/%s.png" % sp)
	if sp_hero != "":
		candidates.append("res://assets/textures/questmap/portraits/%s.png" % sp_hero)
	var ch_info := Database.get_character(char_id)
	var p_frame := str(ch_info.get("portrait", "")).strip_edges()
	if p_frame != "":
		candidates.append("res://assets/textures/questmap/portraits/%s.png" % p_frame)
	candidates.append("res://assets/textures/questmap/portraits/Portrait_%s_Frame.png" % char_id)
	candidates.append("res://assets/textures/questmap/portraits/Portrait_%s_Hero.png" % char_id)
	for path in candidates:
		if ResourceLoader.exists(path):
			var tex = load(path)
			if tex is Texture2D:
				return tex
	return load("res://assets/textures/questmap/portraits/Portrait_Jake_Frame.png")


func _refresh_battle_deck_toggle() -> void:
	var is_on := (GameManager.battle_deck_index == current_deck_index)
	if battle_deck_bg:
		battle_deck_bg.modulate = Color(1.0, 0.6, 0.0, 1.0) if is_on else Color(0.537, 0.322, 0.0, 1.0)
	if battle_deck_lbl:
		battle_deck_lbl.text = "ON" if is_on else "OFF"


func _refresh_counts_and_size() -> void:
	var max_sz := GameManager.get_hero_deck_max_size(current_leader_id)
	var total := current_deck_cards.size()
	if deck_size_lbl:
		deck_size_lbl.text = "Deck Size:%d/%d" % [total, max_sz]
		var out_of_bounds := total > max_sz or (total > 0 and total < GameManager.MIN_CARDS_IN_DECK)
		deck_size_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0) if out_of_bounds else Color.WHITE)

	var c_count := 0
	var s_count := 0
	var b_count := 0
	for cid in current_deck_cards:
		var ctype := str(Database.get_card(str(cid)).get("type", "CREATURE")).to_upper()
		if ctype == "CREATURE":
			c_count += 1
		elif ctype == "SPELL":
			s_count += 1
		elif ctype == "BUILDING":
			b_count += 1
	if tab_creatures_lbl:
		tab_creatures_lbl.text = str(c_count)
	if tab_spells_lbl:
		tab_spells_lbl.text = str(s_count)
	if tab_buildings_lbl:
		tab_buildings_lbl.text = str(b_count)


func _refresh_b0_grid() -> void:
	if not b0_columns:
		return
	for ch in b0_columns.get_children():
		ch.queue_free()

	var display_ids: Array[String] = []
	for cid in current_deck_cards:
		var s := str(cid)
		if _b0_filter_type != "":
			var ct := str(Database.get_card(s).get("type", "")).to_upper()
			if ct != _b0_filter_type:
				continue
		display_ids.append(s)

	display_ids.sort_custom(func(a: String, b: String):
		return _compare_cards(a, b, _b0_primary_sort, _b0_secondary_sort)
	)

	var card_w := 210.0
	var card_h := 296.0
	var col_vbox: VBoxContainer = null
	for i in range(display_ids.size()):
		if i % 2 == 0:
			col_vbox = VBoxContainer.new()
			col_vbox.add_theme_constant_override("separation", 12)
			b0_columns.add_child(col_vbox)
		var cid := display_ids[i]
		var holder_ref := {"node": null}
		var wrapper := _create_tray_card_node(cid, card_w, card_h, false, func():
			_open_zoom_card(cid, holder_ref["node"] as Control)
		, func(holder: Control):
			_open_zoom_card(cid, holder)
		)
		holder_ref["node"] = wrapper
		col_vbox.add_child(wrapper)
		_render_tray_card(wrapper, cid)

	if b0_scroll:
		b0_scroll.scroll_horizontal = 0
		call_deferred("_sync_scrollbar", b0_scroll, b0_sb_bg, b0_sb_thumb)


func _create_tray_card_node(card_id: String, target_w: float, target_h: float, is_in_use: bool, on_tap: Callable, on_zoom: Callable) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(target_w, target_h)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var cv: CardView = CardViewScene.instantiate()
	cv.name = "CardView"
	cv.pivot_offset = Vector2.ZERO
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.set_render_size(Vector2(target_w, target_h))
	holder.add_child(cv)
	var cdata := Database.get_card(card_id)
	if not cdata.is_empty():
		cv.card_data = cdata

	if is_in_use:
		var badge := TextureRect.new()
		badge.name = "InUseBadge"
		badge.texture = TEX_STACK_CIRCLE
		badge.self_modulate = Color(0.0, 1.0, 0.214, 1.0)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bw := 146.0
		badge.position = Vector2((target_w - bw) * 0.5, (target_h - bw) * 0.5 - 24.0)
		badge.size = Vector2(bw, bw)

		var lbl := Label.new()
		lbl.text = "In Deck"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", FONT_KB)
		lbl.add_theme_font_size_override("font_size", 32)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 7)
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(lbl)
		holder.add_child(badge)

	var press_state := {"down_pos": Vector2.ZERO, "dragging": false}
	holder.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
				_pending_long_press.clear()
				on_zoom.call(holder)
				return
			if ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.pressed:
					if ev.double_click:
						_pending_long_press.clear()
						on_zoom.call(holder)
						return
					press_state["down_pos"] = ev.global_position
					press_state["dragging"] = false
					_pending_long_press = {
						"ref": weakref(holder),
						"start_pos": get_viewport().get_mouse_position(),
						"elapsed": 0.0,
						"fired": false,
						"cb": on_zoom,
					}
				else:
					var was_long_fired := not _pending_long_press.is_empty() and bool(_pending_long_press.get("fired", false))
					var lp_ref: WeakRef = _pending_long_press.get("ref", null)
					var same_holder: bool = lp_ref != null and lp_ref.get_ref() == holder
					if same_holder:
						_pending_long_press.clear()
					var dist: float = ev.global_position.distance_to(press_state["down_pos"])
					if not (same_holder and was_long_fired) and dist < 18.0:
						on_tap.call()
	)
	return holder


func _render_tray_card(holder: Control, card_id: String) -> void:
	var cv := holder.get_node_or_null("CardView") as CardView
	if cv:
		var cdata := Database.get_card(card_id)
		if not cdata.is_empty():
			cv.render_card(cdata)


# ==============================================================================
# NAVIGATION & B_0 ACTIONS
# ==============================================================================

func _on_prev_deck_pressed() -> void:
	_play_sfx(SFX_SELECT)
	current_deck_index = (current_deck_index + GameManager.MAX_NUM_DECKS - 1) % GameManager.MAX_NUM_DECKS
	GameManager.current_deck_index = current_deck_index
	_b0_filter_type = ""
	_load_state_from_slot(current_deck_index)
	refresh_all()


func _on_next_deck_pressed() -> void:
	_play_sfx(SFX_SELECT)
	current_deck_index = (current_deck_index + 1) % GameManager.MAX_NUM_DECKS
	GameManager.current_deck_index = current_deck_index
	_b0_filter_type = ""
	_load_state_from_slot(current_deck_index)
	refresh_all()


func _on_battle_deck_pressed() -> void:
	_play_sfx(SFX_SELECT)
	if GameManager.battle_deck_index == current_deck_index:
		# Unity ChooseBattleDeck.OnClick returns immediately if already active
		return
	var res := GameManager.set_battle_deck_index(current_deck_index)
	if not res.get("ok", false):
		var reason := str(res.get("reason", ""))
		if "Fionna" in reason:
			_show_b7_error(reason, "b0")
		return
	_refresh_battle_deck_toggle()


func _on_hero_card_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT or ev.button_index == MOUSE_BUTTON_RIGHT:
			_play_sfx(SFX_SELECT)
			_open_b4_select_hero(true)


func _on_back_pressed() -> void:
	if _is_closing:
		return
	var err := GameManager.check_all_decks_validity()
	if err != "":
		_play_sfx(SFX_SELECT)
		_show_b7_error(err, "b0")
		return

	_play_sfx(SFX_BACK)
	GameManager.save_profile()
	if _is_embedded_modal:
		_is_closing = true
		var tw := create_tween()
		tw.tween_property(b0_panel, "scale", Vector2(0.05, 0.05), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			visible = false
			b0_panel.scale = Vector2.ONE
			_is_closing = false
			closed.emit()
		)
	else:
		GameManager.return_to_menu()


# ==============================================================================
# B_1 ADD PANEL (EDIT DECK)
# ==============================================================================

func _open_b1_add_panel(animate: bool = true) -> void:
	# Build fixed pool of owned copies in current inventory + current deck
	_b1_owned_pool.clear()
	_b1_chosen_indices.clear()
	var counts := GameManager.get_real_owned_card_counts(true)
	for cid in current_deck_cards:
		var k := str(cid)
		counts[k] = maxi(int(counts.get(k, 0)), 0)

	# Reconcile if current slot had cards not in starter pool
	var slot_counts: Dictionary = {}
	for cid in current_deck_cards:
		slot_counts[str(cid)] = int(slot_counts.get(str(cid), 0)) + 1
	for k in slot_counts.keys():
		counts[k] = maxi(int(counts.get(k, 0)), int(slot_counts[k]))

	# Put in-use copies first just like CWDeckAddCards.cs!
	var temp_remaining := counts.duplicate()
	for cid in current_deck_cards:
		var k := str(cid)
		if int(temp_remaining.get(k, 0)) > 0:
			var idx := _b1_owned_pool.size()
			_b1_owned_pool.append(k)
			_b1_chosen_indices[idx] = true
			temp_remaining[k] = int(temp_remaining[k]) - 1
	var rem_ids: Array = temp_remaining.keys()
	rem_ids.sort()
	for k in rem_ids:
		var n := int(temp_remaining[k])
		for _j in range(n):
			_b1_owned_pool.append(str(k))

	_rebuild_b1_chosen_cards()
	_b1_filter_type = "CREATURE"
	_b1_primary_sort = SortField.NONE
	_b1_secondary_sort = SortField.NONE

	b0_panel.visible = false
	_set_popup_fade(true, animate)
	b1_panel.visible = true
	_refresh_b1_ui()
	_play_tab_pulse()
	if animate:
		b1_panel.scale = Vector2(0.05, 0.05)
		create_tween().tween_property(b1_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		b1_panel.scale = Vector2.ONE


func _close_b1_add_panel() -> void:
	b1_panel.visible = false
	_set_popup_fade(false, false)
	b0_panel.visible = true
	_play_b0_open_anim()
	refresh_all()


func _rebuild_b1_chosen_cards() -> void:
	_b1_chosen_cards.clear()
	for idx in _b1_chosen_indices.keys():
		var i := int(idx)
		if i >= 0 and i < _b1_owned_pool.size() and bool(_b1_chosen_indices[idx]):
			_b1_chosen_cards.append(_b1_owned_pool[i])


func _on_b1_type_selected(card_type: String) -> void:
	if _b1_filter_type == card_type:
		return
	_play_sfx(SFX_SELECT)
	_b1_filter_type = card_type
	_play_tab_pulse()
	_refresh_b1_grid()


func _play_tab_pulse() -> void:
	if _tab_pulse_tween and _tab_pulse_tween.is_valid():
		_tab_pulse_tween.kill()
	for sr in [b1_creatures_scale, b1_spells_scale, b1_buildings_scale]:
		if sr:
			sr.scale = Vector2.ONE
	var active_sr: Control = b1_creatures_scale if _b1_filter_type == "CREATURE" else (b1_spells_scale if _b1_filter_type == "SPELL" else b1_buildings_scale)
	if active_sr:
		_tab_pulse_tween = create_tween().set_loops()
		_tab_pulse_tween.tween_property(active_sr, "scale", Vector2(1.1, 1.1), 0.25).set_trans(Tween.TRANS_SINE)
		_tab_pulse_tween.tween_property(active_sr, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)


func _refresh_b1_ui() -> void:
	_refresh_b1_counts()
	_refresh_b1_grid()


func _refresh_b1_counts() -> void:
	_rebuild_b1_chosen_cards()
	var cc := 0
	var sc := 0
	var bc := 0
	for cid in _b1_chosen_cards:
		var ct := str(Database.get_card(cid).get("type", "")).to_upper()
		if ct == "CREATURE":
			cc += 1
		elif ct == "SPELL":
			sc += 1
		elif ct == "BUILDING":
			bc += 1
	if b1_creatures_count:
		b1_creatures_count.text = str(cc)
	if b1_spells_count:
		b1_spells_count.text = str(sc)
	if b1_buildings_count:
		b1_buildings_count.text = str(bc)

	var max_sz := GameManager.get_hero_deck_max_size(current_leader_id)
	var total := _b1_chosen_cards.size()
	if b1_total_lbl:
		b1_total_lbl.text = "Deck Size: %d/%d" % [total, max_sz]
		var invalid := total > max_sz or total < GameManager.MIN_CARDS_IN_DECK
		b1_total_lbl.add_theme_color_override("font_color", Color(0.88, 0.08, 0.08, 1.0) if invalid else Color.BLACK)


func _refresh_b1_grid(preserve_scroll: bool = false) -> void:
	if not b1_columns:
		return
	var saved_scroll := b1_scroll.scroll_horizontal if (preserve_scroll and b1_scroll) else 0
	for ch in b1_columns.get_children():
		ch.queue_free()

	# Filter and sort: InUse indices first (matching CWDeckAddCards.cs) then non-in-use sorted
	var in_use_indices: Array[int] = []
	var other_indices: Array[int] = []
	for i in range(_b1_owned_pool.size()):
		var cid := _b1_owned_pool[i]
		var ct := str(Database.get_card(cid).get("type", "")).to_upper()
		if _b1_filter_type != "" and ct != _b1_filter_type:
			continue
		if bool(_b1_chosen_indices.get(i, false)):
			in_use_indices.append(i)
		else:
			other_indices.append(i)

	in_use_indices.sort_custom(func(a: int, b: int): return _compare_cards(_b1_owned_pool[a], _b1_owned_pool[b], _b1_primary_sort, _b1_secondary_sort))
	other_indices.sort_custom(func(a: int, b: int): return _compare_cards(_b1_owned_pool[a], _b1_owned_pool[b], _b1_primary_sort, _b1_secondary_sort))

	var ordered: Array[int] = []
	ordered.append_array(in_use_indices)
	ordered.append_array(other_indices)

	var card_w := 208.0
	var card_h := 292.0
	var col_vbox: VBoxContainer = null
	for k in range(ordered.size()):
		if k % 2 == 0:
			col_vbox = VBoxContainer.new()
			col_vbox.add_theme_constant_override("separation", 12)
			b1_columns.add_child(col_vbox)
		var pool_idx := ordered[k]
		var cid := _b1_owned_pool[pool_idx]
		var is_in := bool(_b1_chosen_indices.get(pool_idx, false))
		var wrapper := _create_tray_card_node(cid, card_w, card_h, is_in, func():
			_toggle_b1_card(pool_idx)
		, func(holder: Control):
			_open_zoom_card(cid, holder)
		)
		col_vbox.add_child(wrapper)
		_render_tray_card(wrapper, cid)

	if b1_scroll:
		b1_scroll.scroll_horizontal = saved_scroll
		call_deferred("_restore_b1_scroll", saved_scroll)


func _restore_b1_scroll(pos_x: int) -> void:
	if b1_scroll:
		b1_scroll.scroll_horizontal = pos_x
		_sync_scrollbar(b1_scroll, b1_sb_bg, b1_sb_thumb)


func _toggle_b1_card(pool_idx: int) -> void:
	_play_sfx(SFX_CARD_CLICK)
	var cur := bool(_b1_chosen_indices.get(pool_idx, false))
	_b1_chosen_indices[pool_idx] = not cur
	_refresh_b1_counts()
	_refresh_b1_grid(true)


func _on_b1_confirm_pressed() -> void:
	_rebuild_b1_chosen_cards()
	var max_sz := GameManager.get_hero_deck_max_size(current_leader_id)
	if _b1_chosen_cards.size() > max_sz:
		_play_sfx(SFX_SELECT)
		_show_b7_error("You have too many cards in this deck! Level up your Hero Cards to increase your deck size.", "b1")
		return
	if _b1_chosen_cards.size() < GameManager.MIN_CARDS_IN_DECK:
		_play_sfx(SFX_SELECT)
		_show_b7_error("You don't have enough cards in this deck! Add more!", "b1")
		return
	var dup_counts: Dictionary = {}
	for cid in _b1_chosen_cards:
		dup_counts[cid] = int(dup_counts.get(cid, 0)) + 1
		if int(dup_counts[cid]) > GameManager.MAX_DUPLICATES_IN_DECK:
			_play_sfx(SFX_SELECT)
			_show_b7_error("You have too many duplicate cards! Only four of the same card are allowed in one deck.", "b1")
			return

	_play_sfx(SFX_CARD_CLICK)
	current_deck_cards = _b1_chosen_cards.duplicate()
	GameManager.set_deck_slot_cards(current_deck_index, current_deck_cards, true)
	current_landscapes = GameManager.auto_calculate_landscapes(current_deck_cards)
	_close_b1_add_panel()


# ==============================================================================
# B_4 SELECT HERO (CHOOSE HERO)
# ==============================================================================

func _open_b4_select_hero(animate: bool = true) -> void:
	_selected_hero_candidate_id = GameManager._normalize_hero_id(current_leader_id)
	b0_panel.visible = false
	_set_popup_fade(true, animate)
	b4_panel.visible = true
	_refresh_b4_grid()
	if animate:
		b4_panel.scale = Vector2(0.05, 0.05)
		create_tween().tween_property(b4_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		b4_panel.scale = Vector2.ONE


func _close_b4_select_hero() -> void:
	b4_panel.visible = false
	_set_popup_fade(false, false)
	b0_panel.visible = true
	_play_b0_open_anim()
	refresh_all()


func _refresh_b4_grid() -> void:
	if not b4_columns:
		return
	for ch in b4_columns.get_children():
		ch.queue_free()

	var heroes := GameManager.unlocked_leaders.duplicate()
	if heroes.is_empty():
		heroes = ["Leader_Jake"]

	var col_vbox: VBoxContainer = null
	for i in range(heroes.size()):
		if i % 2 == 0:
			col_vbox = VBoxContainer.new()
			col_vbox.add_theme_constant_override("separation", 14)
			b4_columns.add_child(col_vbox)
		var lid := GameManager._normalize_hero_id(str(heroes[i]))
		var is_sel := (lid == _selected_hero_candidate_id)
		var node := _create_hero_tile(lid, is_sel)
		col_vbox.add_child(node)

	if b4_scroll:
		b4_scroll.scroll_horizontal = 0
		call_deferred("_sync_scrollbar", b4_scroll, b4_sb_bg, b4_sb_thumb)


func _create_hero_tile(leader_id: String, is_selected: bool) -> Control:
	var ldata := Database.get_leader(leader_id)
	var char_id := str(ldata.get("character_id", leader_id.replace("Leader_", ""))) if not ldata.is_empty() else leader_id.replace("Leader_", "")
	var is_fc_blocked := bool(ldata.get("fc_world", false)) and (GameManager.battle_deck_index == current_deck_index)
	var lvl := GameManager.get_hero_level(leader_id)
	var hp := GameManager.get_hero_max_hp(leader_id)
	var tracker := GameManager.get_hero_tracker(leader_id)
	var to_next := maxi(0, tracker.get_xp_for_next_level() - tracker.current_xp) if not tracker.is_max_level() else 0

	var tile := Control.new()
	tile.custom_minimum_size = Vector2(176, 250)
	tile.clip_contents = true
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var inner := Control.new()
	inner.pivot_offset = Vector2.ZERO
	inner.size = Vector2(267, 378)
	inner.scale = Vector2(176.0 / 267.0, 250.0 / 378.0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_fc_blocked:
		inner.modulate = Color(0.25, 0.25, 0.25, 1.0)
	tile.add_child(inner)

	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(14, 11)
	art.size = Vector2(239, 239)
	art.texture = _load_hero_portrait(ldata, char_id)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(art)

	var xp_bg := TextureRect.new()
	xp_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	xp_bg.texture = TEX_CW_GREY
	xp_bg.modulate = Color(0.996, 0.996, 0.796, 1.0)
	xp_bg.position = Vector2(56.5, 342)
	xp_bg.size = Vector2(200, 25)
	xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(xp_bg)

	var xp_fg := TextureRect.new()
	xp_fg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	xp_fg.texture = TEX_CW_GREY
	xp_fg.modulate = Color(0.0, 0.616, 0.929, 1.0)
	xp_fg.position = Vector2(56.5, 342)
	xp_fg.size = Vector2(195.0 * tracker.get_progress_ratio(), 25)
	xp_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(xp_fg)

	var frame := TextureRect.new()
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture = TEX_HERO_FRAME
	frame.size = Vector2(267, 378)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(frame)

	var lvl_lbl := _make_kb_label("Level: %d" % lvl, 18, Color.BLACK, Color.TRANSPARENT, 0)
	lvl_lbl.position = Vector2(10, 13)
	lvl_lbl.size = Vector2(82, 32)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(lvl_lbl)

	var hp_lbl := _make_kb_label(str(hp), 32, Color.WHITE, Color.BLACK, 6)
	hp_lbl.position = Vector2(194, 10)
	hp_lbl.size = Vector2(60, 52)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(hp_lbl)

	var name_lbl := _make_kb_label(str(ldata.get("name", char_id)), 18, Color.BLACK, Color.TRANSPARENT, 0)
	name_lbl.position = Vector2(18, 236)
	name_lbl.size = Vector2(231, 28)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(name_lbl)

	var desc_lbl := _make_kb_label(str(ldata.get("desc", "")), 16, Color.BLACK, Color.TRANSPARENT, 0)
	desc_lbl.offset_left = 16.0
	desc_lbl.offset_top = 266.0
	desc_lbl.offset_right = 251.0
	desc_lbl.offset_bottom = 334.0
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc_lbl)

	var next_lbl := _make_kb_label("To Next:%d" % to_next, 15, Color.BLACK, Color.TRANSPARENT, 0)
	next_lbl.position = Vector2(60, 342)
	next_lbl.size = Vector2(192, 25)
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(next_lbl)

	if is_selected:
		var in_use := TextureRect.new()
		in_use.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		in_use.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		in_use.texture = TEX_IN_DECK_HERO
		in_use.modulate = Color(0.85, 0.95, 0.88, 0.94)
		in_use.position = Vector2(38, 45)
		in_use.size = Vector2(190, 190)
		in_use.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(in_use)

		var in_use_lbl := _make_kb_label("In Deck", 42, Color.WHITE, Color.BLACK, 8)
		in_use_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		in_use_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		in_use_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		in_use_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		in_use.add_child(in_use_lbl)

	var h_press := {"down_pos": Vector2.ZERO}
	tile.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
				_pending_long_press.clear()
				_open_zoom_leader(leader_id)
				return
			if ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.pressed:
					h_press["down_pos"] = ev.global_position
					_pending_long_press = {
						"ref": weakref(tile),
						"start_pos": get_viewport().get_mouse_position(),
						"elapsed": 0.0,
						"fired": false,
						"cb": func(_t): _open_zoom_leader(leader_id),
					}
				else:
					var was_long := not _pending_long_press.is_empty() and bool(_pending_long_press.get("fired", false))
					var lp_ref: WeakRef = _pending_long_press.get("ref", null)
					var same: bool = lp_ref != null and lp_ref.get_ref() == tile
					if same:
						_pending_long_press.clear()
					if not (same and was_long) and ev.global_position.distance_to(h_press["down_pos"]) < 18.0 and not is_fc_blocked:
						_play_sfx(SFX_SELECT)
						_selected_hero_candidate_id = leader_id
						_refresh_b4_grid()
	)
	return tile


func _on_b4_confirm_pressed() -> void:
	_play_sfx(SFX_SELECT)
	if _selected_hero_candidate_id != "":
		GameManager.set_deck_slot_leader(current_deck_index, _selected_hero_candidate_id)
		var ldata := Database.get_leader(_selected_hero_candidate_id)
		current_leader_id = str(ldata.get("character_id", _selected_hero_candidate_id.replace("Leader_", ""))) if not ldata.is_empty() else _selected_hero_candidate_id.replace("Leader_", "")
		if current_leader_id == "Fionna":
			current_leader_id = "Fiona"
	_close_b4_select_hero()


# ==============================================================================
# B_3 CONFIRM (MANUAL LANDSCAPES)
# ==============================================================================

func _open_b3_landscapes(animate: bool = true) -> void:
	_staged_landscapes = current_landscapes.duplicate()
	while _staged_landscapes.size() < 4:
		_staged_landscapes.append("Corn")
	b0_panel.visible = false
	_set_popup_fade(true, animate)
	b3_panel.visible = true
	_refresh_b3_cards()
	if animate:
		b3_panel.scale = Vector2(0.05, 0.05)
		create_tween().tween_property(b3_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		b3_panel.scale = Vector2.ONE


func _close_b3_landscapes() -> void:
	b3_panel.visible = false
	_set_popup_fade(false, false)
	b0_panel.visible = true
	_play_b0_open_anim()
	refresh_all()


func _refresh_b3_cards() -> void:
	if not b3_cards_hbox:
		return
	for ch in b3_cards_hbox.get_children():
		ch.queue_free()

	for i in range(4):
		var ltype := str(_staged_landscapes[i])
		if not LANDSCAPE_TEXTURES.has(ltype):
			ltype = "Corn"
		var card_btn := Control.new()
		card_btn.custom_minimum_size = Vector2(260, 368)
		card_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		card_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var art := TextureRect.new()
		art.position = Vector2(10, 12)
		art.size = Vector2(240, 294)
		art.texture = LANDSCAPE_TEXTURES[ltype]
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_btn.add_child(art)

		var frame := TextureRect.new()
		frame.size = Vector2(260, 368)
		frame.texture = TEX_LANDSCAPE_FRAME
		frame.modulate = FACTION_COLORS.get(ltype, Color.WHITE)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_btn.add_child(frame)

		var lbl := _make_kb_label(str(LANDSCAPE_DISPLAY_NAMES.get(ltype, ltype)), 30, Color.BLACK, Color.TRANSPARENT, 0)
		lbl.position = Vector2(8, 306)
		lbl.size = Vector2(244, 52)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_btn.add_child(lbl)

		var lane_idx := i
		card_btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_play_sfx(SFX_SELECT)
				var cur_i := LANDSCAPE_CYCLE.find(str(_staged_landscapes[lane_idx]))
				var next_i := (cur_i + 1) % LANDSCAPE_CYCLE.size()
				_staged_landscapes[lane_idx] = LANDSCAPE_CYCLE[next_i]
				_refresh_b3_cards()
		)
		b3_cards_hbox.add_child(card_btn)


func _on_b3_confirm_pressed() -> void:
	_play_sfx(SFX_SELECT)
	current_landscapes = _staged_landscapes.duplicate()
	GameManager.set_deck_slot_landscapes(current_deck_index, current_landscapes)
	_close_b3_landscapes()


# ==============================================================================
# B_5 & B_6 SORT OPTIONS POPUPS
# ==============================================================================

func _setup_sort_panels() -> void:
	if b5_grid:
		for ch in b5_grid.get_children():
			ch.queue_free()
		var b5_options := [
			{"label": "Attack", "sort": SortField.ATK, "filter": ""},
			{"label": "MP Cost", "sort": SortField.MP, "filter": ""},
			{"label": "Defense", "sort": SortField.DEF, "filter": ""},
			{"label": "Type", "sort": SortField.TYPE, "filter": ""},
			{"label": "Name", "sort": SortField.NAME, "filter": ""},
			{"label": "Rarity", "sort": SortField.RARE, "filter": ""},
			{"label": "Faction", "sort": SortField.FACT, "filter": ""},
			{"label": "Creatures", "sort": -1, "filter": "CREATURE"},
			{"label": "Buildings", "sort": -1, "filter": "BUILDING"},
			{"label": "Spells", "sort": -1, "filter": "SPELL"},
		]
		for opt in b5_options:
			var btn := _create_blue_sort_button(opt["label"])
			btn.pressed.connect(func():
				_play_sfx(SFX_SELECT)
				var sf := int(opt["sort"])
				if sf >= 0:
					_b0_primary_sort = sf
					_b0_secondary_sort = SortField.NONE if sf == SortField.NAME else SortField.NAME
				_b0_filter_type = str(opt["filter"])
				_refresh_b0_grid()
				_close_b5_sort_panel()
			)
			b5_grid.add_child(btn)

	if b6_grid:
		for ch in b6_grid.get_children():
			ch.queue_free()
		var b6_options := [
			{"label": "Attack", "sort": SortField.ATK},
			{"label": "MP Cost", "sort": SortField.MP},
			{"label": "Defense", "sort": SortField.DEF},
			{"label": "Type", "sort": SortField.TYPE},
			{"label": "Name", "sort": SortField.NAME},
			{"label": "Rarity", "sort": SortField.RARE},
			{"label": "Faction", "sort": SortField.FACT},
		]
		for opt in b6_options:
			var btn := _create_blue_sort_button(opt["label"])
			btn.pressed.connect(func():
				_play_sfx(SFX_SELECT)
				var sf := int(opt["sort"])
				_b1_primary_sort = sf
				_b1_secondary_sort = SortField.NONE if sf == SortField.NAME else SortField.NAME
				_refresh_b1_grid()
				_close_b6_sort_panel()
			)
			b6_grid.add_child(btn)


func _create_blue_sort_button(title: String) -> TextureButton:
	var btn := TextureButton.new()
	btn.custom_minimum_size = Vector2(350, 158)
	btn.pivot_offset = Vector2(175, 79)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var np := NinePatchRect.new()
	np.texture = TEX_BTN_BLUE
	np.patch_margin_left = 70
	np.patch_margin_top = 60
	np.patch_margin_right = 60
	np.patch_margin_bottom = 90
	np.set_anchors_preset(Control.PRESET_FULL_RECT)
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(np)

	var lbl := _make_kb_label(title, 34, Color.WHITE, Color.BLACK, 7)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)

	_attach_btn_bounce(btn, 1.0)
	return btn


func _open_b5_sort_panel(animate: bool = true) -> void:
	_set_popup_fade(true, animate)
	b5_panel.visible = true
	if animate:
		b5_panel.scale = Vector2(0.05, 0.05)
		create_tween().tween_property(b5_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		b5_panel.scale = Vector2.ONE


func _close_b5_sort_panel() -> void:
	b5_panel.visible = false
	_set_popup_fade(false, false)


func _open_b6_sort_panel(animate: bool = true) -> void:
	_set_popup_fade(true, animate)
	b6_panel.visible = true
	if animate:
		b6_panel.scale = Vector2(0.05, 0.05)
		create_tween().tween_property(b6_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		b6_panel.scale = Vector2.ONE


func _close_b6_sort_panel() -> void:
	b6_panel.visible = false
	_set_popup_fade(true, false)


# ==============================================================================
# ZOOM OVERLAY & B_7 ERROR MODAL
# ==============================================================================

func _open_zoom_card(card_id: String, source_node: Control = null) -> void:
	if not zoom_overlay or not zoom_holder:
		return
	_play_sfx(SFX_ZOOM)
	for ch in zoom_holder.get_children():
		ch.queue_free()
	var cv: CardView = CardViewScene.instantiate()
	var cdata := Database.get_card(card_id)
	var zoom_w := 460.0
	var zoom_h := 650.0
	cv.set_render_size(Vector2(zoom_w, zoom_h))
	cv.position = Vector2(-zoom_w * 0.5, -zoom_h * 0.5)
	cv.scale = Vector2.ONE
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_holder.add_child(cv)
	if not cdata.is_empty():
		cv.render_card(cdata)

	var zoom_origin := -zoom_overlay.position
	var target_center := Vector2(1024.0, 576.0) + zoom_origin
	zoom_overlay.visible = true
	zoom_holder.scale = Vector2(0.35, 0.35)
	if source_node and is_instance_valid(source_node):
		var start_center := (source_node.global_position + source_node.size * 0.5) / 0.625 + zoom_origin
		zoom_holder.position = start_center
		var tw := create_tween().set_parallel(true)
		tw.tween_property(zoom_holder, "position", target_center, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(zoom_holder, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		zoom_holder.position = target_center
		create_tween().tween_property(zoom_holder, "scale", Vector2.ONE, 0.2)


func _open_zoom_leader(leader_id: String) -> void:
	if not zoom_overlay or not zoom_holder:
		return
	_play_sfx(SFX_ZOOM)
	for ch in zoom_holder.get_children():
		ch.queue_free()
	var tile := _create_hero_tile(leader_id, false)
	tile.scale = Vector2(2.4, 2.4)
	tile.position = Vector2(-188.0 * 1.2, -266.0 * 1.2)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_holder.add_child(tile)
	zoom_holder.position = Vector2(1024.0, 576.0) - zoom_overlay.position
	zoom_holder.scale = Vector2(0.4, 0.4)
	zoom_overlay.visible = true
	create_tween().tween_property(zoom_holder, "scale", Vector2.ONE, 0.2)


func _close_zoom_overlay() -> void:
	if zoom_overlay and zoom_overlay.visible:
		_play_sfx(SFX_BACK)
		zoom_overlay.visible = false


func _show_b7_error(msg: String, return_to: String = "b0") -> void:
	_error_return_target = return_to
	if b7_message_lbl:
		b7_message_lbl.text = msg
	if b7_error_panel:
		b7_error_panel.visible = true
		if b7_panel_box:
			b7_panel_box.scale = Vector2(0.05, 0.05)
			create_tween().tween_property(b7_panel_box, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_b7_error() -> void:
	if b7_error_panel:
		b7_error_panel.visible = false


func _set_popup_fade(show_fade: bool, animate: bool) -> void:
	if not popup_fade:
		return
	if show_fade:
		popup_fade.visible = true
		if animate:
			popup_fade.color.a = 0.0
			create_tween().tween_property(popup_fade, "color:a", 0.72, 0.3)
		else:
			popup_fade.color.a = 0.72
	else:
		popup_fade.visible = false
		popup_fade.color.a = 0.0


# ==============================================================================
# HELPERS (SORTING + SCROLLBAR + LABELS)
# ==============================================================================

func _compare_cards(id_a: String, id_b: String, pri: int, sec: int) -> bool:
	var cmp := _cmp_single(id_a, id_b, pri)
	if cmp == 0 and sec != SortField.NONE:
		cmp = _cmp_single(id_a, id_b, sec)
	if cmp == 0:
		cmp = str(Database.get_card(id_a).get("name", id_a)).naturalnocasecmp_to(str(Database.get_card(id_b).get("name", id_b)))
	return cmp < 0


func _cmp_single(id_a: String, id_b: String, field: int) -> int:
	if field == SortField.NONE:
		return 0
	var ca := Database.get_card(id_a)
	var cb := Database.get_card(id_b)
	match field:
		SortField.ATK:
			return int(cb.get("atk", 0)) - int(ca.get("atk", 0))
		SortField.DEF:
			return int(cb.get("def", 0)) - int(ca.get("def", 0))
		SortField.TYPE:
			var rank := {"CREATURE": 0, "SPELL": 1, "BUILDING": 2}
			return int(rank.get(str(ca.get("type", "")).to_upper(), 9)) - int(rank.get(str(cb.get("type", "")).to_upper(), 9))
		SortField.NAME:
			return str(ca.get("name", id_a)).naturalnocasecmp_to(str(cb.get("name", id_b)))
		SortField.FACT:
			var f_order := {"Corn": 0, "Cotton": 1, "Plains": 2, "Sand": 3, "Swamp": 4, "Universal": 5}
			return int(f_order.get(str(ca.get("faction", "Universal")), 9)) - int(f_order.get(str(cb.get("faction", "Universal")), 9))
		SortField.RARE:
			return int(cb.get("rarity", 1)) - int(ca.get("rarity", 1))
		SortField.MP:
			return int(cb.get("cost", 0)) - int(ca.get("cost", 0))
	return 0


func _sync_scrollbar(sc: ScrollContainer, bg: NinePatchRect, thumb: NinePatchRect) -> void:
	if not sc or not bg or not thumb:
		return
	var hb := sc.get_h_scroll_bar()
	if not hb:
		return
	var track_w := bg.size.x
	var max_v := hb.max_value
	var page_v := hb.page
	if max_v <= page_v or max_v <= 0.0:
		thumb.position.x = 0.0
		thumb.size.x = track_w
		return
	var ratio := clampf(page_v / max_v, 0.12, 1.0)
	var thumb_w := track_w * ratio
	var scroll_frac := clampf(hb.value / maxf(1.0, max_v - page_v), 0.0, 1.0)
	thumb.size.x = thumb_w
	thumb.position.x = (track_w - thumb_w) * scroll_frac


func _make_kb_label(txt: String, font_size: int, fill_col: Color, outline_col: Color, outline_sz: int) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_override("font", FONT_KB)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", fill_col)
	if outline_sz > 0:
		lbl.add_theme_color_override("font_outline_color", outline_col)
		lbl.add_theme_constant_override("outline_size", outline_sz)
	return lbl


# ==============================================================================
# TEST-COMPATIBLE PUBLIC API (test_deck_builder_node.gd & test_fusion_engine_node.gd)
# ==============================================================================

func add_card_to_deck(card_id: String) -> bool:
	var check := DeckValidator.can_add_card(current_deck_cards, card_id)
	if not check.get("can_add", false):
		return false
	current_deck_cards.append(card_id)
	refresh_all()
	return true


func remove_card_from_deck(card_id: String) -> bool:
	var idx := current_deck_cards.find(card_id)
	if idx == -1:
		return false
	current_deck_cards.remove_at(idx)
	refresh_all()
	return true


func clear_deck() -> void:
	current_deck_cards.clear()
	refresh_all()


func save_current_deck(custom_dir: String = DeckValidator.DECKS_DIR) -> Dictionary:
	if deck_name_edit and deck_name_edit.text.strip_edges() != "":
		current_deck_name = deck_name_edit.text.strip_edges()
	var res := DeckValidator.save_deck_to_file(
		current_deck_name,
		current_leader_id,
		current_landscapes,
		current_deck_cards,
		custom_dir
	)
	if res.get("ok", false):
		var payload: Dictionary = res.get("payload", {})
		GameManager.apply_custom_deck(payload)
		deck_saved.emit(current_deck_name, str(res.get("path", "")))
	return res


func load_saved_deck(path_or_slug: String, custom_dir: String = DeckValidator.DECKS_DIR) -> bool:
	var data := DeckValidator.load_deck_from_file(path_or_slug, custom_dir)
	if data.is_empty():
		return false
	current_deck_name = str(data.get("name", "Custom Deck"))
	if deck_name_edit:
		deck_name_edit.text = current_deck_name
	current_leader_id = str(data.get("leader", "Finn"))
	current_landscapes.clear()
	for l in data.get("landscapes", ["Plains", "Plains", "Cotton", "Plains"]):
		current_landscapes.append(str(l))
	while current_landscapes.size() < 4:
		current_landscapes.append("Plains")
	current_deck_cards.clear()
	for c in data.get("cards", []):
		current_deck_cards.append(str(c))
	GameManager.apply_custom_deck(data)
	refresh_all()
	deck_loaded.emit(current_deck_name)
	return true


func open_fusion_modal() -> void:
	if fusion_modal:
		fusion_modal.visible = true
		refresh_fusion_modal()


func close_fusion_modal() -> void:
	if fusion_modal:
		fusion_modal.visible = false


func refresh_fusion_modal() -> void:
	if recipe_list_vbox == null:
		return
	if fusion_coins_label:
		fusion_coins_label.text = "%d Coins" % GameManager.player_coins
	for child in recipe_list_vbox.get_children():
		recipe_list_vbox.remove_child(child)
		child.queue_free()
	var owned := GameManager.get_owned_card_counts()
	var q_lower := fusion_search_text.strip_edges().to_lower()
	var shown_count := 0
	for rec in Database.fusion_recipes_list:
		var out_id := str(rec.get("card_id", ""))
		var out_card := Database.get_card(out_id)
		var out_name := str(out_card.get("name", out_id))
		var r_quality := int(rec.get("quality", FusionEngine.QualityTier.STANDARD))
		if selected_fusion_quality >= 0 and r_quality != selected_fusion_quality:
			continue
		if q_lower != "" and not (q_lower in out_name.to_lower()) and not (q_lower in out_id.to_lower()):
			continue
		shown_count += 1
		if shown_count > 60:
			break
		var check := FusionEngine.can_craft_recipe(rec, owned, GameManager.player_coins)
		var row := HBoxContainer.new()
		var out_lbl := Label.new()
		out_lbl.text = "%s (Own: %d)" % [out_name, int(owned.get(out_id, 0))]
		row.add_child(out_lbl)
		var fuse_btn := Button.new()
		fuse_btn.text = "Fuse!" if check.get("can_craft", false) else "Locked"
		fuse_btn.disabled = not check.get("can_craft", false)
		fuse_btn.pressed.connect(func(): craft_recipe(rec))
		row.add_child(fuse_btn)
		recipe_list_vbox.add_child(row)


func craft_recipe(recipe: Dictionary) -> Dictionary:
	var res := GameManager.craft_fusion_recipe(recipe)
	if res.get("ok", false):
		var out_id := str(res.get("output_card_id", ""))
		refresh_fusion_modal()
		refresh_all()
		card_fused.emit(out_id)
	return res
