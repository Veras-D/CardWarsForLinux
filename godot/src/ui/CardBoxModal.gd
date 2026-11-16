extends Control
class_name CardBoxModal

signal closed
signal open_store_inventory_requested

const TRAY_CARD_SIZE := Vector2(204.0, 288.0)

const CardViewScene := preload("res://scenes/components/CardView.tscn")
const TEX_HERO_FRAME := preload("res://assets/textures/ui/deck/Frame_Hero.png")
const TEX_CW_GREY := preload("res://assets/textures/ui/cards/CW_Grey.png")
const TEX_BTN_BLUE := preload("res://assets/textures/ui/forge/uiButtonBlue.png")
const FONT_KB := preload("res://assets/fonts/KBPlanetEarth.ttf")

const SFX_SELECT := preload("res://assets/audio/sfx/UI_Select.wav")
const SFX_BACK := preload("res://assets/audio/sfx/UI_Back.wav")
const SFX_CLICK := preload("res://assets/audio/sfx/ButtonClick5.wav")
const SFX_ZOOM := preload("res://assets/audio/sfx/Card_Double_Click.wav")

@onready var standalone_backdrop: ColorRect = get_node_or_null("StandaloneBackdrop")
@onready var dimmer: ColorRect = get_node_or_null("Dimmer")
@onready var d0_panel: Control = get_node_or_null("BoxCanvas/D_0_Inventory")

@onready var card_count_lbl: Label = get_node_or_null("BoxCanvas/D_0_Inventory/LeftPane/CardCounts/Card_Count")
@onready var hero_count_lbl: Label = get_node_or_null("BoxCanvas/D_0_Inventory/LeftPane/CardCounts/Hero_Count")
@onready var creature_count_lbl: Label = get_node_or_null("BoxCanvas/D_0_Inventory/LeftPane/CardCounts/Creature_Count")
@onready var spell_count_lbl: Label = get_node_or_null("BoxCanvas/D_0_Inventory/LeftPane/CardCounts/Spell_Count")
@onready var building_count_lbl: Label = get_node_or_null("BoxCanvas/D_0_Inventory/LeftPane/CardCounts/Building_Count")

@onready var back_btn: TextureButton = get_node_or_null("BoxCanvas/D_0_Inventory/LeftPane/BackBtn")
@onready var sort_btn: TextureButton = get_node_or_null("BoxCanvas/D_0_Inventory/LeftPane/SortButton")

@onready var creatures_btn: TextureButton = get_node_or_null("BoxCanvas/D_0_Inventory/TopTabs/CreaturesButton")
@onready var creatures_scale: Control = get_node_or_null("BoxCanvas/D_0_Inventory/TopTabs/CreaturesButton/ScaleRoot")
@onready var spells_btn: TextureButton = get_node_or_null("BoxCanvas/D_0_Inventory/TopTabs/SpellsButton")
@onready var spells_scale: Control = get_node_or_null("BoxCanvas/D_0_Inventory/TopTabs/SpellsButton/ScaleRoot")
@onready var buildings_btn: TextureButton = get_node_or_null("BoxCanvas/D_0_Inventory/TopTabs/BuildingsButton")
@onready var buildings_scale: Control = get_node_or_null("BoxCanvas/D_0_Inventory/TopTabs/BuildingsButton/ScaleRoot")
@onready var heroes_btn: TextureButton = get_node_or_null("BoxCanvas/D_0_Inventory/TopTabs/HeroesButton")
@onready var heroes_scale: Control = get_node_or_null("BoxCanvas/D_0_Inventory/TopTabs/HeroesButton/ScaleRoot")

@onready var card_scroll: ScrollContainer = get_node_or_null("BoxCanvas/D_0_Inventory/CardGridFrame/CardScroll")
@onready var card_columns: HBoxContainer = get_node_or_null("BoxCanvas/D_0_Inventory/CardGridFrame/CardScroll/CardColumns")
@onready var empty_label: Label = get_node_or_null("BoxCanvas/D_0_Inventory/CardGridFrame/EmptyLabel")
@onready var sb_bg: NinePatchRect = get_node_or_null("BoxCanvas/D_0_Inventory/ScrollBarBG")
@onready var sb_thumb: NinePatchRect = get_node_or_null("BoxCanvas/D_0_Inventory/ScrollBarBG/Thumb")

@onready var d5_sort: Control = get_node_or_null("BoxCanvas/D_5_SortPanel")
@onready var d5_close: TextureButton = get_node_or_null("BoxCanvas/D_5_SortPanel/CloseButton")
@onready var d5_grid: GridContainer = get_node_or_null("BoxCanvas/D_5_SortPanel/ButtonsGrid")

@onready var zoom_overlay: Control = get_node_or_null("BoxCanvas/ZoomOverlay")
@onready var zoom_holder: Control = get_node_or_null("BoxCanvas/ZoomOverlay/CardHolder")

var _active_tab: String = "CREATURE"
var _primary_sort: String = "COST"
var _secondary_sort: String = "NAME"
var _is_closing: bool = false
var _tab_pulse_tween: Tween = null


func _ready() -> void:
	visible = false

	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		_attach_button_reaction(back_btn)
	if sort_btn:
		sort_btn.pressed.connect(_on_sort_pressed)
		_attach_button_reaction(sort_btn)

	if creatures_btn:
		creatures_btn.pressed.connect(func(): _on_tab_selected("CREATURE"))
		_attach_button_reaction(creatures_btn, creatures_scale)
	if spells_btn:
		spells_btn.pressed.connect(func(): _on_tab_selected("SPELL"))
		_attach_button_reaction(spells_btn, spells_scale)
	if buildings_btn:
		buildings_btn.pressed.connect(func(): _on_tab_selected("BUILDING"))
		_attach_button_reaction(buildings_btn, buildings_scale)
	if heroes_btn:
		heroes_btn.pressed.connect(func(): _on_tab_selected("HERO"))
		_attach_button_reaction(heroes_btn, heroes_scale)

	if card_scroll:
		var hbar := card_scroll.get_h_scroll_bar()
		if hbar:
			hbar.modulate.a = 0.0
			hbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbar.changed.connect(_sync_scrollbar)
			hbar.value_changed.connect(func(_v): _sync_scrollbar())
		card_scroll.gui_input.connect(_on_scroll_wheel_input)

	if d5_close:
		d5_close.pressed.connect(_close_sort_popup)
		_attach_button_reaction(d5_close)
	_populate_sort_buttons()

	if zoom_overlay:
		zoom_overlay.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_close_zoom()
		)

	if get_tree().current_scene == self:
		if standalone_backdrop:
			standalone_backdrop.visible = true
		open_modal()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _is_closing:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if zoom_overlay and zoom_overlay.visible:
			_close_zoom()
		elif d5_sort and d5_sort.visible:
			_close_sort_popup()
		else:
			_play_sfx(SFX_BACK)
			close_modal()


func _on_scroll_wheel_input(ev: InputEvent) -> void:
	if card_scroll == null:
		return
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN or ev.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			card_scroll.scroll_horizontal += 110
			card_scroll.accept_event()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			card_scroll.scroll_horizontal = maxi(0, card_scroll.scroll_horizontal - 110)
			card_scroll.accept_event()


func _attach_button_reaction(btn: BaseButton, scale_node: Control = null) -> void:
	var target := scale_node if scale_node != null else btn
	btn.button_down.connect(func():
		create_tween().tween_property(target, "scale", Vector2(0.93, 0.93), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func():
		create_tween().tween_property(target, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		if not btn.button_pressed:
			create_tween().tween_property(target, "scale", Vector2.ONE, 0.08)
	)


# ==============================================================================
# OPEN / CLOSE & TAB PULSE
# ==============================================================================

func open_modal(_show_compendium: bool = false) -> void:
	_is_closing = false
	_active_tab = "CREATURE"
	_primary_sort = "COST"
	_secondary_sort = "NAME"

	if d5_sort:
		d5_sort.visible = false
	if zoom_overlay:
		zoom_overlay.visible = false

	visible = true
	if dimmer:
		dimmer.color.a = 0.0
		create_tween().tween_property(dimmer, "color:a", 0.12, 0.25)

	if d0_panel:
		d0_panel.visible = true
		d0_panel.scale = Vector2(0.05, 0.05)
		d0_panel.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(d0_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(d0_panel, "modulate:a", 1.0, 0.22)

	_refresh_all()
	_play_tab_pulse()


func close_modal() -> void:
	if _is_closing:
		return
	_is_closing = true
	_kill_pulse_tweens()

	if dimmer:
		create_tween().tween_property(dimmer, "color:a", 0.0, 0.18)

	var done := func():
		visible = false
		_is_closing = false
		closed.emit()

	if d0_panel:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(d0_panel, "scale", Vector2(0.05, 0.05), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(d0_panel, "modulate:a", 0.0, 0.16)
		tw.chain().tween_callback(done)
	else:
		done.call()


func _kill_pulse_tweens() -> void:
	if _tab_pulse_tween and _tab_pulse_tween.is_valid():
		_tab_pulse_tween.kill()
	for sr in [creatures_scale, spells_scale, buildings_scale, heroes_scale]:
		if sr:
			sr.scale = Vector2.ONE


func _play_tab_pulse() -> void:
	if _tab_pulse_tween and _tab_pulse_tween.is_valid():
		_tab_pulse_tween.kill()
	for sr in [creatures_scale, spells_scale, buildings_scale, heroes_scale]:
		if sr:
			sr.scale = Vector2.ONE
	var active_sr: Control = creatures_scale
	match _active_tab:
		"SPELL":
			active_sr = spells_scale
		"BUILDING":
			active_sr = buildings_scale
		"HERO":
			active_sr = heroes_scale
		_:
			active_sr = creatures_scale
	if active_sr:
		_tab_pulse_tween = create_tween().set_loops()
		_tab_pulse_tween.tween_property(active_sr, "scale", Vector2(1.1, 1.1), 0.25).set_trans(Tween.TRANS_SINE)
		_tab_pulse_tween.tween_property(active_sr, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)


func _on_tab_selected(tab_type: String) -> void:
	if _active_tab == tab_type:
		return
	_play_sfx(SFX_SELECT)
	_active_tab = tab_type
	_play_tab_pulse()
	_refresh_grid()


# ==============================================================================
# COUNTS & GRID POPULATION
# ==============================================================================

func _collect_all_owned_card_ids() -> Array[String]:
	var out: Array[String] = []
	for cid in GameManager.player_deck:
		var k := str(cid)
		if k != "" and not Database.get_card(k).is_empty():
			out.append(k)
	for cid in GameManager.player_inventory_cards:
		var k := str(cid)
		if k != "" and not Database.get_card(k).is_empty():
			out.append(k)
	return out


func _refresh_all() -> void:
	_refresh_counts_panel()
	_refresh_grid()


func _refresh_counts_panel() -> void:
	var c_count := 0
	var s_count := 0
	var b_count := 0
	for cid in _collect_all_owned_card_ids():
		var ctype := str(Database.get_card(cid).get("type", "")).to_upper()
		if ctype == "CREATURE":
			c_count += 1
		elif ctype == "SPELL":
			s_count += 1
		elif ctype == "BUILDING":
			b_count += 1
	var h_count := GameManager.unlocked_leaders.size()
	var total := c_count + s_count + b_count + h_count

	if card_count_lbl:
		card_count_lbl.text = str(total)
	if hero_count_lbl:
		hero_count_lbl.text = str(h_count)
	if creature_count_lbl:
		creature_count_lbl.text = str(c_count)
	if spell_count_lbl:
		spell_count_lbl.text = str(s_count)
	if building_count_lbl:
		building_count_lbl.text = str(b_count)


func _refresh_grid() -> void:
	if card_columns == null:
		return
	for ch in card_columns.get_children():
		card_columns.remove_child(ch)
		ch.queue_free()

	if _active_tab == "HERO":
		_populate_heroes_grid()
		return

	var filtered: Array[String] = []
	for cid in _collect_all_owned_card_ids():
		var cdata := Database.get_card(cid)
		if str(cdata.get("type", "")).to_upper() == _active_tab:
			filtered.append(cid)

	filtered.sort_custom(_compare_cards)

	if empty_label:
		empty_label.visible = filtered.is_empty()
		empty_label.text = "No cards in this category."

	var col_vbox: VBoxContainer = null
	for i in range(filtered.size()):
		if i % 2 == 0:
			col_vbox = VBoxContainer.new()
			col_vbox.add_theme_constant_override("separation", 16)
			card_columns.add_child(col_vbox)

		var cid := filtered[i]
		_add_card_tile(col_vbox, cid)

	if card_scroll:
		card_scroll.scroll_horizontal = 0
		call_deferred("_sync_scrollbar")


func _add_card_tile(parent_col: VBoxContainer, cid: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = TRAY_CARD_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent_col.add_child(holder)

	var cv := CardViewScene.instantiate() as CardView
	cv.name = "CardView"
	cv.position = Vector2.ZERO
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cv)
	cv.set_render_size(TRAY_CARD_SIZE)
	cv.render_card(Database.get_card(cid))

	var press_state := {"down_pos": Vector2.ZERO}
	holder.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
				_open_zoom_card(cid)
				return
			if ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.pressed:
					press_state["down_pos"] = ev.global_position
				elif ev.global_position.distance_to(press_state["down_pos"]) < 18.0:
					_open_zoom_card(cid)
	)
	return holder


func _populate_heroes_grid() -> void:
	var heroes: Array = GameManager.unlocked_leaders.duplicate()
	if _primary_sort == "NAME":
		heroes.sort_custom(func(a, b):
			var la := Database.get_leader(GameManager._normalize_hero_id(str(a)))
			var lb := Database.get_leader(GameManager._normalize_hero_id(str(b)))
			return str(la.get("name", str(a))).naturalnocasecmp_to(str(lb.get("name", str(b)))) < 0
		)

	if empty_label:
		empty_label.visible = heroes.is_empty()
		empty_label.text = "No heroes unlocked."

	var col_vbox: VBoxContainer = null
	for i in range(heroes.size()):
		if i % 2 == 0:
			col_vbox = VBoxContainer.new()
			col_vbox.add_theme_constant_override("separation", 16)
			card_columns.add_child(col_vbox)
		var lid := GameManager._normalize_hero_id(str(heroes[i]))
		var tile := _create_hero_tile(lid)
		col_vbox.add_child(tile)

	if card_scroll:
		card_scroll.scroll_horizontal = 0
		call_deferred("_sync_scrollbar")


func _create_hero_tile(leader_id: String, interactive: bool = true, target_size: Vector2 = TRAY_CARD_SIZE) -> Control:
	var ldata := Database.get_leader(leader_id)
	var char_id := str(ldata.get("character_id", leader_id.replace("Leader_", ""))) if not ldata.is_empty() else leader_id.replace("Leader_", "")
	var lvl := GameManager.get_hero_level(leader_id)
	var hp := GameManager.get_hero_max_hp(leader_id)
	var tracker := GameManager.get_hero_tracker(leader_id)
	var to_next := maxi(0, tracker.get_xp_for_next_level() - tracker.current_xp) if not tracker.is_max_level() else 0

	var sx := target_size.x / 267.0
	var sy := target_size.y / 378.0
	var fs := minf(sx, sy)

	var tile := Control.new()
	tile.custom_minimum_size = target_size
	tile.size = target_size
	tile.clip_contents = true
	tile.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	if interactive:
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(14.0 * sx, 11.0 * sy)
	art.size = Vector2(239.0 * sx, 239.0 * sy)
	art.texture = _load_hero_portrait(ldata, char_id)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(art)

	var xp_bg := TextureRect.new()
	xp_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	xp_bg.texture = TEX_CW_GREY
	xp_bg.modulate = Color(0.996, 0.996, 0.796, 1.0)
	xp_bg.position = Vector2(56.5 * sx, 343.0 * sy)
	xp_bg.size = Vector2(200.0 * sx, 23.0 * sy)
	xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(xp_bg)

	var xp_fg := TextureRect.new()
	xp_fg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	xp_fg.texture = TEX_CW_GREY
	xp_fg.modulate = Color(0.0, 0.616, 0.929, 1.0)
	xp_fg.position = Vector2(56.5 * sx, 343.0 * sy)
	xp_fg.size = Vector2(195.0 * tracker.get_progress_ratio() * sx, 23.0 * sy)
	xp_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(xp_fg)

	var frame := TextureRect.new()
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture = TEX_HERO_FRAME
	frame.size = target_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(frame)

	var lvl_lbl := _make_kb_label("Level: %d" % lvl, maxi(1, roundi(17.5 * fs)), Color.BLACK, Color.TRANSPARENT, 0)
	lvl_lbl.position = Vector2(10.0 * sx, 13.0 * sy)
	lvl_lbl.size = Vector2(82.0 * sx, 32.0 * sy)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(lvl_lbl)

	var hp_lbl := _make_kb_label(str(hp), maxi(1, roundi(32.0 * fs)), Color.WHITE, Color.BLACK, maxi(1, roundi(6.0 * fs)))
	hp_lbl.position = Vector2(194.0 * sx, 10.0 * sy)
	hp_lbl.size = Vector2(60.0 * sx, 52.0 * sy)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(hp_lbl)

	var name_lbl := _make_kb_label(str(ldata.get("name", char_id)), maxi(1, roundi(17.5 * fs)), Color.BLACK, Color.TRANSPARENT, 0)
	name_lbl.position = Vector2(18.0 * sx, 240.0 * sy)
	name_lbl.size = Vector2(231.0 * sx, 22.0 * sy)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(name_lbl)

	var desc_lbl := _make_kb_label(str(ldata.get("desc", "")), maxi(1, roundi(16.0 * fs)), Color.BLACK, Color.TRANSPARENT, 0)
	desc_lbl.offset_left = 18.0 * sx
	desc_lbl.offset_top = 271.5 * sy
	desc_lbl.offset_right = 249.0 * sx
	desc_lbl.offset_bottom = 335.5 * sy
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.add_child(desc_lbl)

	var next_lbl := _make_kb_label("To Next:%d" % to_next, maxi(1, roundi(14.5 * fs)), Color.BLACK, Color.TRANSPARENT, 0)
	next_lbl.position = Vector2(60.0 * sx, 343.0 * sy)
	next_lbl.size = Vector2(192.0 * sx, 23.0 * sy)
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(next_lbl)

	if interactive:
		var h_press := {"down_pos": Vector2.ZERO}
		tile.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton:
				if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
					_open_zoom_leader(leader_id)
					return
				if ev.button_index == MOUSE_BUTTON_LEFT:
					if ev.pressed:
						h_press["down_pos"] = ev.global_position
					elif ev.global_position.distance_to(h_press["down_pos"]) < 18.0:
						_open_zoom_leader(leader_id)
		)
	return tile


func _make_kb_label(txt: String, sz: int, col: Color, outline_col: Color, outline_sz: int) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_override("font", FONT_KB)
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	if outline_sz > 0:
		lbl.add_theme_color_override("font_outline_color", outline_col)
		lbl.add_theme_constant_override("outline_size", outline_sz)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


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


func _sync_scrollbar() -> void:
	if card_scroll == null or sb_bg == null or sb_thumb == null:
		return
	var hbar := card_scroll.get_h_scroll_bar()
	if hbar == null:
		return
	var max_val := maxf(1.0, hbar.max_value)
	var page := clampf(hbar.page, 1.0, max_val)
	var track_w := maxf(20.0, sb_bg.size.x - 4.0)
	var ratio := clampf(page / max_val, 0.12, 1.0)
	var thumb_w := maxf(64.0, track_w * ratio)
	var scrollable := maxf(1.0, max_val - page)
	var scroll_t := clampf(float(card_scroll.scroll_horizontal) / scrollable, 0.0, 1.0)
	if ratio >= 0.995:
		scroll_t = 0.0
	sb_thumb.position.x = 2.0 + (track_w - thumb_w) * scroll_t
	sb_thumb.size.x = thumb_w


# ==============================================================================
# ACTIONS: BACK, SORT, ZOOM
# ==============================================================================

func _on_back_pressed() -> void:
	_play_sfx(SFX_BACK)
	close_modal()


func _populate_sort_buttons() -> void:
	if d5_grid == null:
		return
	for ch in d5_grid.get_children():
		ch.queue_free()

	var pair_specs: Array[Dictionary] = [
		{"key": "ATK", "label": "Attack"},
		{"key": "COST", "label": "MP Cost"},
		{"key": "DEF", "label": "Defense"},
		{"key": "TYPE", "label": "Type"},
		{"key": "NAME", "label": "Name"},
		{"key": "RARITY", "label": "Rarity"},
	]
	for spec in pair_specs:
		var key := str(spec["key"])
		var text_lbl := str(spec["label"])
		var btn := _create_sort_button(text_lbl)
		btn.pressed.connect(func(): _apply_sort_option(key))
		d5_grid.add_child(btn)

	if d5_sort:
		var fbtn := _create_sort_button("Faction")
		fbtn.name = "SortButtonFaction"
		fbtn.position = Vector2(849.0, 887.0)
		fbtn.pressed.connect(func(): _apply_sort_option("FACTION"))
		d5_sort.add_child(fbtn)


func _create_sort_button(label_text: String) -> TextureButton:
	var btn := TextureButton.new()
	btn.custom_minimum_size = Vector2(350, 180)
	btn.pivot_offset = Vector2(175, 90)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var bg := NinePatchRect.new()
	bg.texture = TEX_BTN_BLUE
	bg.patch_margin_left = 70
	bg.patch_margin_top = 60
	bg.patch_margin_right = 60
	bg.patch_margin_bottom = 90
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bg)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FONT_KB)
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)

	_attach_button_reaction(btn)
	return btn


func _on_sort_pressed() -> void:
	_play_sfx(SFX_SELECT)
	if d5_sort:
		d5_sort.visible = true


func _close_sort_popup() -> void:
	_play_sfx(SFX_BACK)
	if d5_sort:
		d5_sort.visible = false


func _apply_sort_option(sort_key: String) -> void:
	_play_sfx(SFX_SELECT)
	if _primary_sort != sort_key:
		_secondary_sort = _primary_sort
		_primary_sort = sort_key
	if d5_sort:
		d5_sort.visible = false
	_refresh_grid()


func _compare_cards(cid_a: String, cid_b: String) -> bool:
	if cid_a == cid_b:
		return false
	var c1 := _cmp_by_mode(cid_a, cid_b, _primary_sort)
	if c1 != 0:
		return c1 < 0
	var c2 := _cmp_by_mode(cid_a, cid_b, _secondary_sort)
	if c2 != 0:
		return c2 < 0
	return str(Database.get_card(cid_a).get("name", cid_a)) < str(Database.get_card(cid_b).get("name", cid_b))


func _cmp_by_mode(cid_a: String, cid_b: String, mode: String) -> int:
	var da := Database.get_card(cid_a)
	var db := Database.get_card(cid_b)
	match mode:
		"ATK":
			return int(db.get("atk", 0)) - int(da.get("atk", 0))
		"DEF":
			return int(db.get("def", 0)) - int(da.get("def", 0))
		"TYPE":
			var ta := str(da.get("type", ""))
			var tb := str(db.get("type", ""))
			return -1 if ta < tb else (1 if ta > tb else 0)
		"NAME":
			var na := str(da.get("name", cid_a)).to_lower()
			var nb := str(db.get("name", cid_b)).to_lower()
			return -1 if na < nb else (1 if na > nb else 0)
		"RARITY":
			return int(db.get("rarity", 0)) - int(da.get("rarity", 0))
		"FACTION":
			var fa := str(da.get("faction", ""))
			var fb := str(db.get("faction", ""))
			return -1 if fa < fb else (1 if fa > fb else 0)
		_:
			return int(da.get("cost", 0)) - int(db.get("cost", 0))


# ==============================================================================
# ZOOM OVERLAY & SCREENSHOT PREVIEW HELPERS
# ==============================================================================

func _open_zoom_card(card_id: String) -> void:
	if zoom_overlay == null or zoom_holder == null:
		return
	_play_sfx(SFX_ZOOM)
	for ch in zoom_holder.get_children():
		zoom_holder.remove_child(ch)
		ch.queue_free()
	var cv := CardViewScene.instantiate() as CardView
	var zoom_w := 460.0
	var zoom_h := 650.0
	cv.position = Vector2(-zoom_w * 0.5, -zoom_h * 0.5)
	cv.scale = Vector2.ONE
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_holder.add_child(cv)
	cv.set_render_size(Vector2(zoom_w, zoom_h))
	var cdata := Database.get_card(card_id)
	if not cdata.is_empty():
		cv.render_card(cdata)
	zoom_holder.position = Vector2(1024.0, 576.0) - zoom_overlay.position
	zoom_holder.scale = Vector2(0.35, 0.35)
	zoom_overlay.visible = true
	create_tween().tween_property(zoom_holder, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _open_zoom_leader(leader_id: String) -> void:
	if zoom_overlay == null or zoom_holder == null:
		return
	_play_sfx(SFX_ZOOM)
	for ch in zoom_holder.get_children():
		zoom_holder.remove_child(ch)
		ch.queue_free()
	var zoom_size := Vector2(460.0, 651.0)
	var tile := _create_hero_tile(leader_id, false, zoom_size)
	tile.scale = Vector2.ONE
	tile.position = -zoom_size * 0.5
	zoom_holder.add_child(tile)
	zoom_holder.position = Vector2(1024.0, 576.0) - zoom_overlay.position
	zoom_holder.scale = Vector2(0.35, 0.35)
	zoom_overlay.visible = true
	create_tween().tween_property(zoom_holder, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _close_zoom() -> void:
	if zoom_overlay and zoom_overlay.visible:
		_play_sfx(SFX_BACK)
		zoom_overlay.visible = false


func show_panel_preview(mode: String) -> void:
	if mode == "card_box_heroes":
		_active_tab = "HERO"
		_play_tab_pulse()
		_refresh_grid()
	elif mode == "card_box_hero_zoom":
		_active_tab = "HERO"
		_play_tab_pulse()
		_refresh_grid()
		if not GameManager.unlocked_leaders.is_empty():
			_open_zoom_leader(GameManager._normalize_hero_id(str(GameManager.unlocked_leaders[0])))
	elif mode == "card_box_sort":
		if d5_sort:
			d5_sort.visible = true
	elif mode == "card_box_zoom":
		var all_ids := _collect_all_owned_card_ids()
		if not all_ids.is_empty():
			_open_zoom_card(all_ids[0])


func _play_sfx(stream: AudioStream) -> void:
	if Audio and stream:
		Audio.play_sfx(stream)
