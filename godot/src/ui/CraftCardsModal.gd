extends Control
class_name CraftCardsModal

signal closed
signal card_crafted(card_id: String)

const SFX_CLICK: AudioStream = preload("res://assets/audio/sfx/UI_Select.wav")
const SFX_BACK: AudioStream = preload("res://assets/audio/sfx/UI_Back.wav")
const SFX_ARM: AudioStream = preload("res://assets/audio/sfx/Recipe_Arm.wav")
const SFX_CRAFT_START: AudioStream = preload("res://assets/audio/sfx/Recipe_Craft_Start.wav")
const SFX_CRAFT_FLY: AudioStream = preload("res://assets/audio/sfx/Recipe_Craft_FuseCard.wav")
const SFX_CRAFT_HAMMER: AudioStream = preload("res://assets/audio/sfx/Recipe_Craft_Hammer.wav")
const SFX_CRAFT_WHITE: AudioStream = preload("res://assets/audio/sfx/Recipe_Craft_WhiteFX.wav")
const SFX_EARN: AudioStream = preload("res://assets/audio/sfx/Map_HeartEarn.wav")
const SFX_RARITY_1: AudioStream = preload("res://assets/audio/sfx/Gatcha_1_New_Card.wav")
const SFX_RARITY_2: AudioStream = preload("res://assets/audio/sfx/Gatcha_2_Nice_Card.wav")
const SFX_RARITY_3: AudioStream = preload("res://assets/audio/sfx/Gatcha_3_Rare.wav")
const SFX_RARITY_4: AudioStream = preload("res://assets/audio/sfx/Gatcha_4_Very_Rare.wav")
const SFX_RARITY_5: AudioStream = preload("res://assets/audio/sfx/Gatcha_5_Algebraic_Rare.wav")

const FusionEngine = preload("res://src/cards/FusionEngine.gd")
const CardViewScene: PackedScene = preload("res://scenes/components/CardView.tscn")

const TEX_QBG: Texture2D = preload("res://assets/textures/ui/forge/QuestInfo_BG.png")
const TEX_MATCARDS: Texture2D = preload("res://assets/textures/ui/forge/Craft_MaterialCardsFrame.png")
const TEX_NEW_BADGE: Texture2D = preload("res://assets/textures/ui/forge/Craft_NewCardBadge.png")
const TEX_CRAFT_MODEL: Texture2D = preload("res://assets/textures/ui/forge/Battle_Crafting.png")
const TEX_CARD_BACK: Texture2D = preload("res://assets/textures/ui/forge/Card_Back.png")
const FONT_KB: FontFile = preload("res://assets/fonts/KBPlanetEarth.ttf")

enum FusionSortType {
	NEW = 0,
	CRAFT = 1,
	ABC = 2,
	TYPE = 3,
	SPELL = 4,
	CRET = 5,
	BLDG = 6,
	ATK = 7,
	DEF = 8,
}

const SORT_NAMES: PackedStringArray = ["NEW", "CRAFT", "ABC", "TYPE", "SPELL", "CRET", "BLDG", "ATK", "DEF"]

@onready var forge_canvas: Control = $ForgeCanvas
@onready var arm_holder: Control = $ForgeCanvas/ArmHolder
@onready var target_card_holder: Control = $ForgeCanvas/ArmHolder/TargetCardHolder
@onready var inventory_pill: NinePatchRect = $ForgeCanvas/InventoryPill
@onready var inventory_label: Label = $ForgeCanvas/Label

@onready var ingredients_root: Control = $ForgeCanvas/NeededRoot/Ingredients
@onready var cost_label: Label = $ForgeCanvas/NeededRoot/CostPill/CostValue
@onready var craft_btn: TextureButton = $ForgeCanvas/NeededRoot/CraftButton

@onready var back_btn: BaseButton = $ForgeCanvas/BackBtn
@onready var sort_btn: TextureButton = $ForgeCanvas/SortBtn
@onready var sort_label: Label = $ForgeCanvas/SortBtn/SortLabel
@onready var tray_scroll: ScrollContainer = $ForgeCanvas/Scroll
@onready var recipe_hbox: HBoxContainer = $ForgeCanvas/Scroll/RecipeHBox
@onready var scrollbar_bg: Control = $ForgeCanvas/ScrollBarBg
@onready var scrollbar_thumb: Control = $ForgeCanvas/ScrollBarBg/ScrollBarThumb

@onready var quest_lock_overlay: Control = $ForgeCanvas/QuestLockOverlay
@onready var quest_lock_black: ColorRect = $ForgeCanvas/QuestLockOverlay/Black
@onready var quest_lock_panel: Control = $ForgeCanvas/QuestLockOverlay/Panel
@onready var quest_lock_label: Label = $ForgeCanvas/QuestLockOverlay/Panel/Text
@onready var error_overlay: Control = $ErrorOverlay
@onready var error_label: Label = $ErrorOverlay/Center/Panel/VBox/ErrorLabel
@onready var error_ok_btn: Button = $ErrorOverlay/Center/Panel/VBox/OkBtn

@onready var craft_seq_overlay: Control = $CraftSeqOverlay
@onready var seq_black: ColorRect = $CraftSeqOverlay/BlackPanel
@onready var forge_3d_container: SubViewportContainer = $CraftSeqOverlay/Forge3DContainer
@onready var forge_viewport: SubViewport = $CraftSeqOverlay/Forge3DContainer/ForgeViewport
@onready var crafting_model: Node3D = $CraftSeqOverlay/Forge3DContainer/ForgeViewport/Forge3DRoot/CraftingModel
@onready var flying_layer: Control = $CraftSeqOverlay/FlyingLayer
@onready var reveal_layer: Control = $CraftSeqOverlay/RevealLayer
@onready var card_back_rect: TextureRect = $CraftSeqOverlay/RevealLayer/CardBack
@onready var rarity_banner: Label = $CraftSeqOverlay/RevealLayer/RarityBanner
@onready var result_card_holder: Control = $CraftSeqOverlay/RevealLayer/ResultCardHolder
@onready var tap_anywhere_label: Label = $CraftSeqOverlay/RevealLayer/TapAnywhereLabel
@onready var white_flash: ColorRect = $CraftSeqOverlay/WhiteFlash

var _current_sort: int = FusionSortType.NEW
var _selected_recipe_id: String = ""
var _unlocked_recipes: Array[Dictionary] = []
var _arm_rest_pos: Vector2 = Vector2.ZERO
var _is_crafting: bool = false
var _is_animating_arm: bool = false
var _awaiting_tap: bool = false
var _tap_pressed: bool = false
var _arm_tween: Tween = null
var _craft_btn_tween: Tween = null
var _tap_tween: Tween = null
var _crafting_anim_player: AnimationPlayer = null

const LOCK_TEXT: String = "Welcome To The Card Forge!\n\nWe’re closed until you finish your 4th quest!\nGo battle your butt off and come back!"
var _lock_typing: bool = false
var _lock_fast_forward: bool = false
var _lock_char_index: int = 0
var _lock_next_char_timer: float = 0.0
var _lock_closing: bool = false


func _ready() -> void:
	visible = false
	if arm_holder:
		_arm_rest_pos = arm_holder.position
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if sort_btn:
		sort_btn.pressed.connect(_on_sort_pressed)
	if craft_btn:
		craft_btn.pressed.connect(_on_craft_pressed)
	if error_ok_btn:
		error_ok_btn.pressed.connect(func():
			_play_sfx(SFX_CLICK)
			if error_overlay:
				error_overlay.visible = false
		)
	if quest_lock_overlay:
		quest_lock_overlay.gui_input.connect(_on_quest_lock_gui_input)
	if craft_seq_overlay:
		craft_seq_overlay.gui_input.connect(_on_craft_seq_gui_input)
	if tray_scroll:
		tray_scroll.get_h_scroll_bar().value_changed.connect(func(_val): _update_scrollbar_thumb())
	_setup_3d_craft_model()


func _setup_3d_craft_model() -> void:
	if not crafting_model:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = TEX_CRAFT_MODEL
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_BACK

	var stack: Array[Node] = [crafting_model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			for idx in range(mi.get_surface_override_material_count()):
				mi.set_surface_override_material(idx, mat)
		elif n is AnimationPlayer and _crafting_anim_player == null:
			_crafting_anim_player = n as AnimationPlayer


func _play_sfx(stream: AudioStream) -> void:
	if stream != null and Audio:
		Audio.play_sfx(stream)


func open_modal(force_unlocked: bool = false) -> void:
	_is_crafting = false
	_awaiting_tap = false
	_tap_pressed = false
	_current_sort = FusionSortType.NEW
	_selected_recipe_id = ""
	if error_overlay:
		error_overlay.visible = false
	if craft_seq_overlay:
		craft_seq_overlay.visible = false

	visible = true
	var unlocked := force_unlocked or GameManager.is_card_forge_unlocked()
	if quest_lock_overlay:
		quest_lock_overlay.visible = not unlocked
		if not unlocked:
			_start_quest_lock_intro()

	# C_0_Fuse open TweenScale: (0,0) -> (1, 1) in 0.2s centered on screen
	pivot_offset = size * 0.5
	scale = Vector2(0.05, 0.05)
	var tw_open := create_tween()
	tw_open.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_rebuild_recipe_tray()
	if sort_label:
		sort_label.text = SORT_NAMES[_current_sort]
	_display_selected_recipe(false, true)
	call_deferred("_update_scrollbar_thumb")


func _start_quest_lock_intro() -> void:
	_lock_closing = false
	_lock_typing = true
	_lock_fast_forward = false
	_lock_char_index = 0
	_lock_next_char_timer = 0.08
	if quest_lock_black:
		quest_lock_black.color.a = 0.0
		create_tween().tween_property(quest_lock_black, "color:a", 0.50, 0.45)
	if quest_lock_panel:
		quest_lock_panel.pivot_offset = quest_lock_panel.size * 0.5
		quest_lock_panel.scale = Vector2(0.05, 0.05)
		create_tween().tween_property(quest_lock_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if quest_lock_label:
		quest_lock_label.text = LOCK_TEXT
		quest_lock_label.visible_characters = 0


func _process(delta: float) -> void:
	if not _lock_typing or not visible or not quest_lock_overlay or not quest_lock_overlay.visible:
		return
	if _lock_char_index >= LOCK_TEXT.length():
		_lock_typing = false
		return
	_lock_next_char_timer -= delta
	while _lock_next_char_timer <= 0.0 and _lock_char_index < LOCK_TEXT.length():
		_lock_char_index += 1
		if quest_lock_label:
			quest_lock_label.visible_characters = _lock_char_index
		var ch := LOCK_TEXT[_lock_char_index - 1]
		var cps := 40.0 * (100.0 if _lock_fast_forward else 1.0)
		var step := 1.0 / cps
		if ch in [".", "\n", "!", "?", ","]:
			step *= 6.0
		_lock_next_char_timer += step
	if _lock_char_index >= LOCK_TEXT.length():
		_lock_typing = false


func finish_lock_typewriter() -> void:
	_lock_typing = false
	_lock_char_index = LOCK_TEXT.length()
	if quest_lock_label:
		quest_lock_label.text = LOCK_TEXT
		quest_lock_label.visible_characters = -1


func close_modal() -> void:
	_lock_typing = false
	if _arm_tween and _arm_tween.is_valid():
		_arm_tween.kill()
	_stop_craft_btn_pulse()
	pivot_offset = size * 0.5
	var tw_close := create_tween()
	tw_close.tween_property(self, "scale", Vector2(0.05, 0.05), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_close.tween_callback(func():
		visible = false
		scale = Vector2.ONE
		closed.emit()
	)


func _on_back_pressed() -> void:
	if _is_crafting:
		return
	_play_sfx(SFX_BACK)
	close_modal()


func _on_quest_lock_gui_input(event: InputEvent) -> void:
	if _lock_closing:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		if _lock_typing and not _lock_fast_forward:
			# CWTutorialTapDelegate: first tap fast-forwards TypewriterEffectIgnoreTime
			_lock_fast_forward = true
			return
		finish_lock_typewriter()
		_lock_closing = true
		# Matches Unity TutorialTrigger.CloseCardCrafting -> B_1_BackToMenu/0. Back (UI_Back.wav)
		_play_sfx(SFX_BACK)
		if quest_lock_panel:
			quest_lock_panel.pivot_offset = quest_lock_panel.size * 0.5
			var tw_pop := create_tween()
			tw_pop.tween_property(quest_lock_panel, "scale", Vector2(0.05, 0.05), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if quest_lock_black:
			create_tween().tween_property(quest_lock_black, "color:a", 0.0, 0.18)
		close_modal()


func _on_craft_seq_gui_input(event: InputEvent) -> void:
	if not _awaiting_tap:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		_tap_pressed = true


func _refresh_all(animate_arm: bool) -> void:
	if sort_label:
		sort_label.text = SORT_NAMES[_current_sort]
	_rebuild_recipe_tray()
	_display_selected_recipe(animate_arm, false)


func _get_sorted_unlocked_recipes() -> Array[Dictionary]:
	var box_counts := GameManager.get_inventory_only_counts()
	var coins := GameManager.get_coins()
	var out: Array[Dictionary] = []

	for rec in Database.fusion_recipes_list:
		if not GameManager.is_fusion_recipe_unlocked(rec):
			continue
		var cid := str(rec.get("card_id", ""))
		var c_data := Database.get_card(cid)
		if c_data.is_empty():
			continue
		var check := FusionEngine.can_craft_recipe(rec, box_counts, coins)
		out.append({
			"rec": rec,
			"card": c_data,
			"can": bool(check.get("can_craft", false)),
			"viewed": GameManager.has_viewed_fusion_recipe(cid),
		})

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _compare_recipes(a, b)
	)
	return out


func _type_rank(c_data: Dictionary) -> int:
	match str(c_data.get("type", "")).to_upper():
		"CREATURE":
			return 0
		"SPELL":
			return 1
		"BUILDING":
			return 2
		_:
			return 3


func _compare_recipes(a: Dictionary, b: Dictionary) -> bool:
	var ca: Dictionary = a["card"]
	var cb: Dictionary = b["card"]
	var name_a := str(ca.get("name", ""))
	var name_b := str(cb.get("name", ""))

	match _current_sort:
		FusionSortType.NEW:
			var av := 1 if bool(a["viewed"]) else 0
			var bv := 1 if bool(b["viewed"]) else 0
			if av != bv:
				return av < bv
		FusionSortType.CRAFT:
			var ac := 0 if bool(a["can"]) else 1
			var bc := 0 if bool(b["can"]) else 1
			if ac != bc:
				return ac < bc
		FusionSortType.ABC:
			if name_a != name_b:
				return name_a < name_b
		FusionSortType.TYPE:
			var ta := _type_rank(ca)
			var tb := _type_rank(cb)
			if ta != tb:
				return ta < tb
		FusionSortType.SPELL:
			var sa := 0 if str(ca.get("type", "")).to_upper() == "SPELL" else 1
			var sb := 0 if str(cb.get("type", "")).to_upper() == "SPELL" else 1
			if sa != sb:
				return sa < sb
		FusionSortType.CRET:
			var ra := 0 if str(ca.get("type", "")).to_upper() == "CREATURE" else 1
			var rb := 0 if str(cb.get("type", "")).to_upper() == "CREATURE" else 1
			if ra != rb:
				return ra < rb
		FusionSortType.BLDG:
			var ba := 0 if str(ca.get("type", "")).to_upper() == "BUILDING" else 1
			var bb := 0 if str(cb.get("type", "")).to_upper() == "BUILDING" else 1
			if ba != bb:
				return ba < bb
		FusionSortType.ATK:
			var aa := int(ca.get("atk", 0))
			var ab := int(cb.get("atk", 0))
			if aa != ab:
				return aa > ab
		FusionSortType.DEF:
			var da := int(ca.get("def", 0))
			var db := int(cb.get("def", 0))
			if da != db:
				return da > db

	return name_a < name_b


func _rebuild_recipe_tray(auto_pick_first: bool = true) -> void:
	_unlocked_recipes = _get_sorted_unlocked_recipes()

	if recipe_hbox:
		for ch in recipe_hbox.get_children():
			recipe_hbox.remove_child(ch)
			ch.queue_free()

	if _unlocked_recipes.is_empty():
		_selected_recipe_id = ""
		return

	var has_sel := false
	for item in _unlocked_recipes:
		if str(item["card"].get("id", "")) == _selected_recipe_id:
			has_sel = true
			break
	if not has_sel or (auto_pick_first and _selected_recipe_id == ""):
		_selected_recipe_id = str(_unlocked_recipes[0]["card"].get("id", ""))

	for item in _unlocked_recipes:
		_add_tray_card(item)

	call_deferred("_update_scrollbar_thumb")


func _add_tray_card(item: Dictionary) -> void:
	var c_data: Dictionary = item["card"]
	var cid := str(c_data.get("id", ""))
	var can_craft := bool(item["can"])
	var is_unviewed := not bool(item["viewed"])

	var tile := Control.new()
	tile.custom_minimum_size = Vector2(296, 296)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	recipe_hbox.add_child(tile)

	# RecipeCard.prefab visual structure (SQUtils.SetGray(..., 0.4f, null, "New") excludes NEW! badge)
	var content := Control.new()
	content.size = Vector2(296, 296)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not can_craft:
		content.modulate = Color(0.4, 0.4, 0.4, 1.0)
	tile.add_child(content)

	var bg_frame := TextureRect.new()
	bg_frame.position = Vector2(0, 0)
	bg_frame.size = Vector2(296, 296)
	bg_frame.texture = TEX_QBG
	bg_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_frame.stretch_mode = TextureRect.STRETCH_SCALE
	bg_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bg_frame)

	var art := TextureRect.new()
	art.position = Vector2(18, 18)
	art.size = Vector2(260, 260)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_path := str(c_data.get("texture_path", ""))
	if tex_path != "":
		art.texture = Database.get_card_texture(tex_path)
	content.add_child(art)

	var type_bg := NinePatchRect.new()
	type_bg.position = Vector2(16, 226)
	type_bg.size = Vector2(264, 52)
	type_bg.texture = TEX_MATCARDS
	type_bg.patch_margin_left = 20
	type_bg.patch_margin_top = 12
	type_bg.patch_margin_right = 20
	type_bg.patch_margin_bottom = 12
	type_bg.modulate = Color(0.18, 0.24, 0.28, 0.94)
	type_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(type_bg)

	var sub_lbl := Label.new()
	sub_lbl.position = Vector2(16, 226)
	sub_lbl.size = Vector2(264, 52)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub_lbl.clip_text = true
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.add_theme_font_override("font", FONT_KB)
	sub_lbl.add_theme_font_size_override("font_size", 28)
	sub_lbl.add_theme_color_override("font_color", Color.WHITE)
	sub_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	sub_lbl.add_theme_constant_override("outline_size", 4)
	match _current_sort:
		FusionSortType.ATK:
			sub_lbl.text = "ATK %d" % int(c_data.get("atk", 0))
		FusionSortType.DEF:
			sub_lbl.text = "DEF %d" % int(c_data.get("def", 0))
		FusionSortType.CRAFT, FusionSortType.ABC, FusionSortType.SPELL, FusionSortType.CRET, FusionSortType.BLDG:
			sub_lbl.text = str(c_data.get("name", ""))
		_:
			sub_lbl.text = str(c_data.get("type", "")).capitalize()
	content.add_child(sub_lbl)

	var new_badge: TextureRect = null
	if is_unviewed:
		new_badge = TextureRect.new()
		new_badge.position = Vector2(-2, -2)
		new_badge.size = Vector2(133, 130)
		new_badge.texture = TEX_NEW_BADGE
		new_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		new_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		new_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(new_badge)

	tile.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
			_on_recipe_tile_clicked(cid, new_badge)
	)


func _update_scrollbar_thumb() -> void:
	if not tray_scroll or not scrollbar_bg or not scrollbar_thumb:
		return
	var sb := tray_scroll.get_h_scroll_bar()
	var total := maxf(1.0, sb.max_value)
	var page := sb.page
	var track_w := scrollbar_bg.size.x - 8.0
	if page >= total or total <= 0.0:
		scrollbar_thumb.size.x = track_w
		scrollbar_thumb.position.x = 4.0
		return
	var thumb_w := clampf(track_w * (page / total), 80.0, track_w)
	var ratio := sb.value / maxf(1.0, total - page)
	scrollbar_thumb.size.x = thumb_w
	scrollbar_thumb.position.x = 4.0 + ratio * (track_w - thumb_w)


func _find_selected_entry() -> Dictionary:
	for it in _unlocked_recipes:
		if str(it["card"].get("id", "")) == _selected_recipe_id:
			return it
	return _unlocked_recipes[0] if not _unlocked_recipes.is_empty() else {}


func _on_recipe_tile_clicked(cid: String, badge_node: Control) -> void:
	if _is_crafting or _is_animating_arm:
		return
	if cid == _selected_recipe_id:
		return
	_selected_recipe_id = cid
	if badge_node:
		badge_node.visible = false
	GameManager.mark_fusion_recipe_viewed(cid)
	_play_sfx(SFX_ARM)
	_rebuild_recipe_tray(false)
	_display_selected_recipe(true, false)


func _display_selected_recipe(retract_first: bool, slide_in_on_open: bool) -> void:
	var entry := _find_selected_entry()
	if entry.is_empty():
		return

	if arm_holder and retract_first:
		if _arm_tween and _arm_tween.is_valid():
			_arm_tween.kill()
		_is_animating_arm = true
		_arm_tween = create_tween()
		_arm_tween.tween_property(arm_holder, "position:x", _arm_rest_pos.x - 740.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_arm_tween.tween_callback(func():
			_populate_stage_from_entry(entry)
		)
		_arm_tween.tween_property(arm_holder, "position:x", _arm_rest_pos.x, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_arm_tween.tween_callback(func(): _is_animating_arm = false)
	elif arm_holder and slide_in_on_open:
		_populate_stage_from_entry(entry)
		if _arm_tween and _arm_tween.is_valid():
			_arm_tween.kill()
		arm_holder.position.x = _arm_rest_pos.x - 740.0
		_is_animating_arm = true
		_arm_tween = create_tween()
		_arm_tween.tween_property(arm_holder, "position:x", _arm_rest_pos.x, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_arm_tween.tween_callback(func(): _is_animating_arm = false)
	else:
		if arm_holder:
			arm_holder.position = _arm_rest_pos
		_populate_stage_from_entry(entry)


func _populate_stage_from_entry(entry: Dictionary) -> void:
	var rec: Dictionary = entry["rec"]
	var c_data: Dictionary = entry["card"]
	var cid := str(c_data.get("id", ""))
	var box_counts := GameManager.get_inventory_only_counts()
	var total_owned := GameManager.get_real_owned_card_counts(true)
	var check := FusionEngine.can_craft_recipe(rec, box_counts, GameManager.get_coins())
	var can_craft := bool(check.get("can_craft", false))

	if target_card_holder:
		for ch in target_card_holder.get_children():
			target_card_holder.remove_child(ch)
			ch.queue_free()
		var cv := CardViewScene.instantiate() as CardView
		cv.pivot_offset = Vector2.ZERO
		cv.scale = Vector2(1.942, 1.942)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target_card_holder.add_child(cv)
		cv.render_card(c_data)
		target_card_holder.modulate = Color.WHITE if can_craft else Color(0.45, 0.45, 0.45, 1.0)

	if inventory_label:
		inventory_label.text = "%d in inventory" % int(total_owned.get(cid, 0))

	if cost_label:
		cost_label.text = str(int(rec.get("cost", 0)))

	if craft_btn:
		craft_btn.modulate = Color.WHITE if can_craft else Color(0.4, 0.4, 0.4, 1.0)
	if can_craft:
		_start_craft_btn_pulse()
	else:
		_stop_craft_btn_pulse()

	if ingredients_root:
		var slot_nodes := ingredients_root.get_children()
		var ings: Array = rec.get("ingredients", [])
		for i in range(slot_nodes.size()):
			var slot := slot_nodes[i] as Control
			if i >= ings.size():
				slot.visible = false
				continue
			slot.visible = true
			var ing: Dictionary = ings[i]
			var icid := str(ing.get("card_id", ""))
			var ireq := int(ing.get("count", 1))
			var ihave := int(box_counts.get(icid, 0))
			var satisfied := (ihave >= ireq)
			var icard := Database.get_card(icid)

			var card_holder := slot.get_node_or_null("CardHolder")
			var check_mark := slot.get_node_or_null("CheckMark")
			var qty_lbl := slot.get_node_or_null("QtyLabel") as Label

			if card_holder:
				for ch in card_holder.get_children():
					card_holder.remove_child(ch)
					ch.queue_free()
				var icv := CardViewScene.instantiate() as CardView
				icv.pivot_offset = Vector2.ZERO
				icv.scale = Vector2(1.714, 1.714)
				icv.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card_holder.add_child(icv)
				if not icard.is_empty():
					icv.render_card(icard)
				card_holder.modulate = Color.WHITE if satisfied else Color(0.45, 0.45, 0.45, 1.0)

			if check_mark:
				check_mark.visible = satisfied
			if qty_lbl:
				qty_lbl.text = "%d/%d" % [ihave, ireq]
				qty_lbl.modulate = Color(0.45, 1.0, 0.55) if satisfied else Color.WHITE


func _start_craft_btn_pulse() -> void:
	if not craft_btn:
		return
	if _craft_btn_tween and _craft_btn_tween.is_valid():
		return
	craft_btn.scale = Vector2.ONE
	_craft_btn_tween = create_tween()
	_craft_btn_tween.set_loops()
	_craft_btn_tween.tween_property(craft_btn, "scale", Vector2(1.05, 1.05), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_craft_btn_tween.tween_property(craft_btn, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_craft_btn_pulse() -> void:
	if _craft_btn_tween and _craft_btn_tween.is_valid():
		_craft_btn_tween.kill()
	_craft_btn_tween = null
	if craft_btn:
		craft_btn.scale = Vector2.ONE


func _on_sort_pressed() -> void:
	if _is_crafting:
		return
	_play_sfx(SFX_CLICK)
	_current_sort = (_current_sort + 1) % SORT_NAMES.size()
	_refresh_all(true)


func _on_craft_pressed() -> void:
	if _is_crafting or _is_animating_arm:
		return
	var entry := _find_selected_entry()
	if entry.is_empty():
		return
	var rec: Dictionary = entry["rec"]
	var res := GameManager.craft_fusion_recipe(rec, true)
	if not bool(res.get("ok", false)):
		_play_sfx(SFX_CLICK)
		var reason := str(res.get("reason", ""))
		if reason == "min_creatures":
			_show_error("Hey Buddy! You can't use cards in your Decks or go below %d total Creatures to craft a new card!" % GameManager.MIN_CREATURES_IN_INVENTORY)
		elif reason == "insufficient_coins":
			_show_error("Not enough Coins! You need %d Coins to craft %s." % [int(rec.get("cost", 0)), str(entry["card"].get("name", ""))])
		else:
			_show_error("You don't have enough spare cards in your Card Box!\n(Cards currently in a Deck cannot be forged.)")
		return

	var c_data: Dictionary = entry["card"]
	card_crafted.emit(str(c_data.get("id", "")))
	_play_craft_sequence(c_data, rec)


func _play_craft_sequence(c_data: Dictionary, rec: Dictionary) -> void:
	_is_crafting = true
	_awaiting_tap = false
	_tap_pressed = false
	_stop_craft_btn_pulse()
	_play_sfx(SFX_CRAFT_START)

	if not craft_seq_overlay:
		_is_crafting = false
		_refresh_all(false)
		return

	craft_seq_overlay.visible = true
	if white_flash:
		white_flash.visible = false
	if card_back_rect:
		card_back_rect.visible = false
		card_back_rect.scale = Vector2.ONE
	if rarity_banner:
		rarity_banner.visible = false
	if result_card_holder:
		result_card_holder.visible = false
		result_card_holder.scale = Vector2.ONE
		for ch in result_card_holder.get_children():
			result_card_holder.remove_child(ch)
			ch.queue_free()
	if tap_anywhere_label:
		tap_anywhere_label.visible = false
	if flying_layer:
		for ch in flying_layer.get_children():
			flying_layer.remove_child(ch)
			ch.queue_free()

	# Stage 1: Fade in BlackPanel + 3D Crafting Anvil/Hammer
	if seq_black:
		seq_black.modulate.a = 0.0
		create_tween().tween_property(seq_black, "modulate:a", 1.0, 0.5)
	if forge_3d_container:
		forge_3d_container.visible = true
		forge_3d_container.modulate.a = 0.0
		create_tween().tween_property(forge_3d_container, "modulate:a", 1.0, 0.45)
	if forge_viewport:
		forge_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _crafting_anim_player:
		var anims := _crafting_anim_player.get_animation_list()
		if not anims.is_empty():
			var a := _crafting_anim_player.get_animation(anims[0])
			if a:
				a.loop_mode = Animation.LOOP_LINEAR
			_crafting_anim_player.play(anims[0])
			_crafting_anim_player.seek(0.0, true)

	await get_tree().create_timer(0.5).timeout

	# Stage 2: Spawn ingredient cards and fly them into the 3D Forge
	_play_sfx(SFX_CRAFT_HAMMER)
	var anvil_target := Vector2(640.0, 320.0)
	var ings: Array = rec.get("ingredients", [])
	var slot_nodes := ingredients_root.get_children() if ingredients_root else []
	for i in range(ings.size()):
		var icard := Database.get_card(str(ings[i].get("card_id", "")))
		if icard.is_empty() or not flying_layer:
			continue
		var start_pos := Vector2(560.0 + i * 160.0, 180.0)
		if i < slot_nodes.size():
			var ch_ctrl := (slot_nodes[i] as Control).get_node_or_null("CardHolder") as Control
			if ch_ctrl:
				start_pos = ch_ctrl.get_global_rect().position

		var fly_cv := CardViewScene.instantiate() as CardView
		fly_cv.pivot_offset = Vector2.ZERO
		fly_cv.position = start_pos
		fly_cv.scale = Vector2(1.07, 1.07)
		fly_cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flying_layer.add_child(fly_cv)
		fly_cv.render_card(icard)

		_play_sfx(SFX_CRAFT_FLY)
		var tw_fly := create_tween()
		tw_fly.set_parallel(true)
		tw_fly.tween_property(fly_cv, "position", anvil_target - Vector2(16, 22), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_fly.tween_property(fly_cv, "scale", Vector2(0.12, 0.12), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_fly.chain().tween_callback(fly_cv.queue_free)
		await get_tree().create_timer(0.25).timeout

	await get_tree().create_timer(0.55).timeout

	# Stage 3: Burst + White Flash
	_play_sfx(SFX_CRAFT_WHITE)
	if white_flash:
		white_flash.visible = true
		white_flash.modulate.a = 0.0
		var tw_wf_in := create_tween()
		tw_wf_in.tween_property(white_flash, "modulate:a", 1.0, 0.35)
		await tw_wf_in.finished

	if forge_3d_container:
		forge_3d_container.visible = false
	if forge_viewport:
		forge_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _crafting_anim_player:
		_crafting_anim_player.stop()

	# Spawn spinning CardBack (1080-degree Y-spin) as white flash fades out
	if card_back_rect:
		card_back_rect.visible = true
		card_back_rect.scale = Vector2.ONE
	if white_flash:
		var tw_wf_out := create_tween()
		tw_wf_out.tween_property(white_flash, "modulate:a", 0.0, 0.5)

	# 3 half-turns Y spin before reveal
	if card_back_rect:
		var tw_spin := create_tween()
		for _turn in range(3):
			tw_spin.tween_property(card_back_rect, "scale:x", 0.05, 0.16).set_trans(Tween.TRANS_SINE)
			tw_spin.tween_property(card_back_rect, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
		await tw_spin.finished
		card_back_rect.visible = false

	# Stage 4: Rarity Fanfare + Banner + Revealed CardView
	var rarity := clampi(int(c_data.get("rarity", 1)), 1, 5)
	_play_rarity_banner(rarity)

	if result_card_holder:
		result_card_holder.visible = true
		result_card_holder.scale = Vector2(0.1, 0.1)
		var cv := CardViewScene.instantiate() as CardView
		cv.pivot_offset = Vector2.ZERO
		cv.scale = Vector2(1.65, 1.65)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		result_card_holder.add_child(cv)
		cv.render_card(c_data)

		var tw_pop := create_tween()
		tw_pop.tween_property(result_card_holder, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw_pop.finished

	if tap_anywhere_label:
		tap_anywhere_label.visible = true
		tap_anywhere_label.modulate.a = 1.0
		if _tap_tween and _tap_tween.is_valid():
			_tap_tween.kill()
		_tap_tween = create_tween()
		_tap_tween.set_loops()
		_tap_tween.tween_property(tap_anywhere_label, "modulate:a", 0.3, 0.5)
		_tap_tween.tween_property(tap_anywhere_label, "modulate:a", 1.0, 0.5)

	_awaiting_tap = true
	while not _tap_pressed and visible:
		await get_tree().process_frame
	_awaiting_tap = false

	if _tap_tween and _tap_tween.is_valid():
		_tap_tween.kill()
		_tap_tween = null
	if tap_anywhere_label:
		tap_anywhere_label.visible = false
	if rarity_banner:
		rarity_banner.visible = false

	# Stage 5: Card flies into Inventory pill + PunchScale + Map_HeartEarn
	if seq_black:
		create_tween().tween_property(seq_black, "modulate:a", 0.0, 0.35)

	if result_card_holder:
		var dest_pos := Vector2(340.0, 440.0)
		if inventory_pill:
			dest_pos = inventory_pill.get_global_rect().get_center() - Vector2(20, 28)
		var tw_collect := create_tween()
		tw_collect.set_parallel(true)
		tw_collect.tween_property(result_card_holder, "position", dest_pos, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_collect.tween_property(result_card_holder, "scale", Vector2(0.15, 0.15), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw_collect.finished
		result_card_holder.visible = false
		result_card_holder.position = Vector2(533.0, 208.0)

	_play_sfx(SFX_EARN)
	if inventory_pill:
		inventory_pill.pivot_offset = inventory_pill.size * 0.5
		var tw_punch := create_tween()
		tw_punch.tween_property(inventory_pill, "scale", Vector2(1.22, 1.22), 0.12).set_trans(Tween.TRANS_BACK)
		tw_punch.tween_property(inventory_pill, "scale", Vector2.ONE, 0.16)

	craft_seq_overlay.visible = false
	_is_crafting = false
	_refresh_all(false)


func _play_rarity_banner(rarity: int) -> void:
	if rarity_banner:
		rarity_banner.visible = true
		rarity_banner.scale = Vector2(0.5, 0.5)
		match rarity:
			5:
				rarity_banner.text = "ALGEBRAIC RARE!"
				rarity_banner.add_theme_color_override("font_color", Color(1.0, 0.82, 0.15))
				_play_sfx(SFX_RARITY_5)
			4:
				rarity_banner.text = "VERY RARE!"
				rarity_banner.add_theme_color_override("font_color", Color(0.78, 0.48, 1.0))
				_play_sfx(SFX_RARITY_4)
			3:
				rarity_banner.text = "RARE!"
				rarity_banner.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
				_play_sfx(SFX_RARITY_3)
			2:
				rarity_banner.text = "NICE CARD!"
				rarity_banner.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
				_play_sfx(SFX_RARITY_2)
			_:
				rarity_banner.text = "NEW CARD!"
				rarity_banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35))
				_play_sfx(SFX_RARITY_1)
		create_tween().tween_property(rarity_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_error(msg: String) -> void:
	if error_label:
		error_label.text = msg
	if error_overlay:
		error_overlay.visible = true
