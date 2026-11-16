extends Control
class_name SellCardsModal

signal closed
signal cards_sold(count: int, coins_gained: int)

const MAX_SELECT_LIMIT := 10
const LONG_PRESS_TIME := 0.40

const CardViewScene := preload("res://scenes/components/CardView.tscn")
const TEX_STACK_CIRCLE := preload("res://assets/textures/ui/deck/Stack_Circle.png")
const TEX_BTN_BLUE := preload("res://assets/textures/ui/forge/uiButtonBlue.png")
const FONT_KB := preload("res://assets/fonts/KBPlanetEarth.ttf")

const SFX_SELECT := preload("res://assets/audio/sfx/UI_Select.wav")
const SFX_BACK := preload("res://assets/audio/sfx/UI_Back.wav")
const SFX_CLICK := preload("res://assets/audio/sfx/ButtonClick5.wav")
const SFX_SELL := preload("res://assets/audio/sfx/low_Deck_SellCard.wav")
const SFX_ZOOM := preload("res://assets/audio/sfx/Card_Double_Click.wav")

@onready var standalone_backdrop: ColorRect = get_node_or_null("StandaloneBackdrop")
@onready var dimmer: ColorRect = get_node_or_null("Dimmer")
@onready var e0_panel: Control = get_node_or_null("SellCanvas/E_0_SellCards")

@onready var card_count_lbl: Label = get_node_or_null("SellCanvas/E_0_SellCards/LeftPane/CardCounts/Card_Count")
@onready var hero_count_lbl: Label = get_node_or_null("SellCanvas/E_0_SellCards/LeftPane/CardCounts/Hero_Count")
@onready var creature_count_lbl: Label = get_node_or_null("SellCanvas/E_0_SellCards/LeftPane/CardCounts/Creature_Count")
@onready var spell_count_lbl: Label = get_node_or_null("SellCanvas/E_0_SellCards/LeftPane/CardCounts/Spell_Count")
@onready var building_count_lbl: Label = get_node_or_null("SellCanvas/E_0_SellCards/LeftPane/CardCounts/Building_Count")

@onready var sell_button: TextureButton = get_node_or_null("SellCanvas/E_0_SellCards/LeftPane/SellButton")
@onready var sell_price_lbl: Label = get_node_or_null("SellCanvas/E_0_SellCards/LeftPane/SellButton/SellPriceLabel")
@onready var back_btn: TextureButton = get_node_or_null("SellCanvas/E_0_SellCards/LeftPane/BackBtn")
@onready var sort_btn: TextureButton = get_node_or_null("SellCanvas/E_0_SellCards/LeftPane/SortButton")

@onready var creatures_tab: TextureButton = get_node_or_null("SellCanvas/E_0_SellCards/TopTabs/CreaturesButton")
@onready var creatures_scale: Control = get_node_or_null("SellCanvas/E_0_SellCards/TopTabs/CreaturesButton/ScaleRoot")
@onready var spells_tab: TextureButton = get_node_or_null("SellCanvas/E_0_SellCards/TopTabs/SpellsButton")
@onready var spells_scale: Control = get_node_or_null("SellCanvas/E_0_SellCards/TopTabs/SpellsButton/ScaleRoot")
@onready var buildings_tab: TextureButton = get_node_or_null("SellCanvas/E_0_SellCards/TopTabs/BuildingsButton")
@onready var buildings_scale: Control = get_node_or_null("SellCanvas/E_0_SellCards/TopTabs/BuildingsButton/ScaleRoot")

@onready var card_scroll: ScrollContainer = get_node_or_null("SellCanvas/E_0_SellCards/CardGridFrame/CardScroll")
@onready var card_columns: HBoxContainer = get_node_or_null("SellCanvas/E_0_SellCards/CardGridFrame/CardScroll/CardColumns")
@onready var empty_label: Label = get_node_or_null("SellCanvas/E_0_SellCards/CardGridFrame/EmptyLabel")
@onready var sb_bg: NinePatchRect = get_node_or_null("SellCanvas/E_0_SellCards/ScrollBarBG")
@onready var sb_thumb: NinePatchRect = get_node_or_null("SellCanvas/E_0_SellCards/ScrollBarBG/Thumb")

@onready var e1_confirm: Control = get_node_or_null("SellCanvas/E_1_SellConfirm")
@onready var e1_panel: Control = get_node_or_null("SellCanvas/E_1_SellConfirm/Panel")
@onready var e1_desc_lbl: Label = get_node_or_null("SellCanvas/E_1_SellConfirm/Panel/DescLabel")
@onready var e1_grid: GridContainer = get_node_or_null("SellCanvas/E_1_SellConfirm/Panel/CardsFrame/ConfirmScroll/ConfirmGrid")
@onready var e1_cancel_btn: TextureButton = get_node_or_null("SellCanvas/E_1_SellConfirm/Panel/CancelButton")
@onready var e1_sell_btn: TextureButton = get_node_or_null("SellCanvas/E_1_SellConfirm/Panel/ConfirmSellButton")

@onready var e2_error: Control = get_node_or_null("SellCanvas/E_2_ErrorPopup")
@onready var e2_panel: Control = get_node_or_null("SellCanvas/E_2_ErrorPopup/Panel")
@onready var e2_title_lbl: Label = get_node_or_null("SellCanvas/E_2_ErrorPopup/Panel/TitleLabel")
@onready var e2_msg_lbl: Label = get_node_or_null("SellCanvas/E_2_ErrorPopup/Panel/MsgLabel")
@onready var e2_ok_btn: TextureButton = get_node_or_null("SellCanvas/E_2_ErrorPopup/Panel/OKButton")

@onready var e3_sort: Control = get_node_or_null("SellCanvas/E_3_SortPanel")
@onready var e3_close_btn: TextureButton = get_node_or_null("SellCanvas/E_3_SortPanel/CloseButton")
@onready var e3_grid: GridContainer = get_node_or_null("SellCanvas/E_3_SortPanel/ButtonsGrid")

@onready var zoom_overlay: Control = get_node_or_null("SellCanvas/ZoomOverlay")
@onready var zoom_dimmer: ColorRect = get_node_or_null("SellCanvas/ZoomOverlay/Dimmer")
@onready var zoom_holder: Control = get_node_or_null("SellCanvas/ZoomOverlay/CardHolder")

var _active_tab := "CREATURE"
var _primary_sort := "NONE"
var _secondary_sort := "NONE"
var _is_closing := false

# Array of { "uid": int, "id": String, "in_deck": int }
var _owned_instances: Array[Dictionary] = []
# Ordered array of selected uid ints (max MAX_SELECT_LIMIT)
var _chosen_uids: Array[int] = []
# Map uid -> Card holder Control for live sequence updates without rebuilding scroll
var _tray_nodes_by_uid: Dictionary = {}

var _anim_tween: Tween = null
var _tab_pulse_tween: Tween = null
var _sell_pulse_tween: Tween = null
var _pending_long_press: Dictionary = {}


func _ready() -> void:
	var parent_node := get_parent()
	if parent_node == null or parent_node == get_tree().root:
		if standalone_backdrop:
			standalone_backdrop.visible = true
		visible = true
		call_deferred("open_modal")

	_bind_buttons()
	_build_sort_buttons()
	if card_scroll:
		var hbar := card_scroll.get_h_scroll_bar()
		if hbar:
			hbar.visible = false
			hbar.value_changed.connect(func(_v: float): _sync_scrollbar())
		card_scroll.gui_input.connect(_on_scroll_gui_input)


func _bind_buttons() -> void:
	for b in [sell_button, back_btn, sort_btn, creatures_tab, spells_tab, buildings_tab, e1_cancel_btn, e1_sell_btn, e2_ok_btn, e3_close_btn]:
		_attach_button_reaction(b)

	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if sell_button:
		sell_button.pressed.connect(_on_sell_pressed)
	if sort_btn:
		sort_btn.pressed.connect(_on_sort_pressed)
	if creatures_tab:
		creatures_tab.pressed.connect(func(): _on_tab_selected("CREATURE"))
	if spells_tab:
		spells_tab.pressed.connect(func(): _on_tab_selected("SPELL"))
	if buildings_tab:
		buildings_tab.pressed.connect(func(): _on_tab_selected("BUILDING"))

	if e1_cancel_btn:
		e1_cancel_btn.pressed.connect(_close_confirm_popup)
	if e1_sell_btn:
		e1_sell_btn.pressed.connect(_on_confirm_sell_yes)
	if e2_ok_btn:
		e2_ok_btn.pressed.connect(_close_error_popup)
	if e3_close_btn:
		e3_close_btn.pressed.connect(_close_sort_popup)
	if zoom_overlay:
		zoom_overlay.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_close_zoom()
		)


func _attach_button_reaction(btn: BaseButton) -> void:
	if btn == null:
		return
	btn.button_down.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.06)
	)
	btn.button_up.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08)
	)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if zoom_overlay and zoom_overlay.visible:
		_close_zoom()
	elif e2_error and e2_error.visible:
		_close_error_popup()
	elif e3_sort and e3_sort.visible:
		_close_sort_popup()
	elif e1_confirm and e1_confirm.visible:
		_close_confirm_popup()
	else:
		_on_back_pressed()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _pending_long_press.is_empty():
		return
	var ref: WeakRef = _pending_long_press.get("ref", null)
	var holder := ref.get_ref() as Control if ref != null else null
	if holder == null or not is_instance_valid(holder) or not holder.is_visible_in_tree():
		_pending_long_press.clear()
		return
	if bool(_pending_long_press.get("fired", false)):
		return
	var elapsed := float(_pending_long_press.get("elapsed", 0.0)) + delta
	_pending_long_press["elapsed"] = elapsed
	if elapsed >= LONG_PRESS_TIME:
		_pending_long_press["fired"] = true
		var cid := str(_pending_long_press.get("card_id", ""))
		_open_zoom_card(cid)


func _on_scroll_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and card_scroll:
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			card_scroll.scroll_horizontal += 90
			_sync_scrollbar()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			card_scroll.scroll_horizontal = maxi(0, card_scroll.scroll_horizontal - 90)
			_sync_scrollbar()


func open_modal() -> void:
	_is_closing = false
	_active_tab = "CREATURE"
	_primary_sort = "NONE"
	_secondary_sort = "NONE"
	_chosen_uids.clear()
	_pending_long_press.clear()
	if e1_confirm:
		e1_confirm.visible = false
	if e2_error:
		e2_error.visible = false
	if e3_sort:
		e3_sort.visible = false
	if zoom_overlay:
		zoom_overlay.visible = false

	visible = true
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	if e0_panel:
		e0_panel.scale = Vector2(0.05, 0.05)
		_anim_tween = create_tween()
		_anim_tween.tween_property(e0_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if dimmer:
		dimmer.modulate.a = 0.0
		create_tween().tween_property(dimmer, "modulate:a", 1.0, 0.18)

	_refresh_all()
	_play_tab_pulse()


func close_modal() -> void:
	if _is_closing or not visible:
		return
	_is_closing = true
	_pending_long_press.clear()
	_kill_pulse_tweens()
	for sub in [e1_confirm, e2_error, e3_sort, zoom_overlay]:
		if sub:
			sub.visible = false

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	if e0_panel:
		_anim_tween = create_tween()
		_anim_tween.tween_property(e0_panel, "scale", Vector2(0.05, 0.05), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		if dimmer:
			_anim_tween.parallel().tween_property(dimmer, "modulate:a", 0.0, 0.16)
		_anim_tween.tween_callback(func():
			visible = false
			e0_panel.scale = Vector2.ONE
			_is_closing = false
			closed.emit()
		)
	else:
		visible = false
		_is_closing = false
		closed.emit()


func _kill_pulse_tweens() -> void:
	if _tab_pulse_tween and _tab_pulse_tween.is_valid():
		_tab_pulse_tween.kill()
	if _sell_pulse_tween and _sell_pulse_tween.is_valid():
		_sell_pulse_tween.kill()
	for sr in [creatures_scale, spells_scale, buildings_scale]:
		if sr:
			sr.scale = Vector2.ONE
	if sell_button:
		sell_button.scale = Vector2.ONE


func _play_tab_pulse() -> void:
	if _tab_pulse_tween and _tab_pulse_tween.is_valid():
		_tab_pulse_tween.kill()
	for sr in [creatures_scale, spells_scale, buildings_scale]:
		if sr:
			sr.scale = Vector2.ONE
	var active_sr: Control = creatures_scale if _active_tab == "CREATURE" else (spells_scale if _active_tab == "SPELL" else buildings_scale)
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
# INVENTORY & DECK IN-USE MAPPING
# ==============================================================================

func _rebuild_owned_instances() -> void:
	_owned_instances.clear()
	var uid := 0

	# Active deck instances come from GameManager.player_deck
	var active_slot := GameManager.current_deck_index + 1
	for cid in GameManager.player_deck:
		var k := str(cid)
		if k != "" and not Database.get_card(k).is_empty():
			_owned_instances.append({"uid": uid, "id": k, "in_deck": active_slot})
			uid += 1

	# Remaining instances in player_inventory_cards: lock up to other decks' usage if any
	var other_deck_usage: Dictionary = {}
	for d_idx in range(GameManager.decks.size()):
		if d_idx == GameManager.current_deck_index:
			continue
		var slot_cards: Array = GameManager.decks[d_idx].get("cards", [])
		for c in slot_cards:
			var k := str(c)
			if k == "":
				continue
			if not other_deck_usage.has(k):
				other_deck_usage[k] = []
			(other_deck_usage[k] as Array).append(d_idx + 1)

	var consumed_other: Dictionary = {}
	for cid in GameManager.player_inventory_cards:
		var k := str(cid)
		if k == "" or Database.get_card(k).is_empty():
			continue
		var in_deck := 0
		if other_deck_usage.has(k):
			var arr: Array = other_deck_usage[k]
			var used_i := int(consumed_other.get(k, 0))
			if used_i < arr.size():
				in_deck = int(arr[used_i])
				consumed_other[k] = used_i + 1
		_owned_instances.append({"uid": uid, "id": k, "in_deck": in_deck})
		uid += 1


func _refresh_all() -> void:
	_rebuild_owned_instances()
	# Drop stale uids if inventory changed
	var valid_uids: Dictionary = {}
	for item in _owned_instances:
		if int(item["in_deck"]) == 0:
			valid_uids[int(item["uid"])] = true
	var filtered: Array[int] = []
	for u in _chosen_uids:
		if valid_uids.has(u):
			filtered.append(u)
	_chosen_uids = filtered

	_refresh_counts_panel()
	_refresh_sell_button()
	_refresh_grid()


func _refresh_counts_panel() -> void:
	var c_cnt := 0
	var s_cnt := 0
	var b_cnt := 0
	for item in _owned_instances:
		var ct := str(Database.get_card(str(item["id"])).get("type", "")).to_upper()
		if ct == "CREATURE":
			c_cnt += 1
		elif ct == "SPELL":
			s_cnt += 1
		elif ct == "BUILDING":
			b_cnt += 1
	var h_cnt := maxi(1, GameManager.unlocked_leaders.size())
	var total_collected := c_cnt + s_cnt + b_cnt + h_cnt

	if card_count_lbl:
		card_count_lbl.text = str(total_collected)
	if hero_count_lbl:
		hero_count_lbl.text = str(h_cnt)
	if creature_count_lbl:
		creature_count_lbl.text = str(c_cnt)
	if spell_count_lbl:
		spell_count_lbl.text = str(s_cnt)
	if building_count_lbl:
		building_count_lbl.text = str(b_cnt)


func _find_instance_by_uid(uid: int) -> Dictionary:
	for item in _owned_instances:
		if int(item["uid"]) == uid:
			return item
	return {}


func _compute_selected_coins() -> int:
	var total := 0
	for u in _chosen_uids:
		var item := _find_instance_by_uid(u)
		if item.is_empty():
			continue
		var cdata := Database.get_card(str(item["id"]))
		total += maxi(0, int(cdata.get("sale_price", 0)))
	return total


func _refresh_sell_button() -> void:
	var coins := _compute_selected_coins()
	if sell_price_lbl:
		sell_price_lbl.text = "%d Coins" % coins

	if _sell_pulse_tween and _sell_pulse_tween.is_valid():
		_sell_pulse_tween.kill()
	if sell_button == null:
		return
	if _chosen_uids.size() > 0:
		_sell_pulse_tween = create_tween().set_loops()
		_sell_pulse_tween.tween_property(sell_button, "scale", Vector2(1.05, 1.05), 0.25).set_trans(Tween.TRANS_SINE)
		_sell_pulse_tween.tween_property(sell_button, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	else:
		sell_button.scale = Vector2.ONE


# ==============================================================================
# CARD TRAY GRID & BADGES
# ==============================================================================

func _refresh_grid() -> void:
	if card_columns == null:
		return
	_tray_nodes_by_uid.clear()
	for ch in card_columns.get_children():
		card_columns.remove_child(ch)
		ch.queue_free()

	var filtered: Array[Dictionary] = []
	for item in _owned_instances:
		var cid := str(item["id"])
		var ct := str(Database.get_card(cid).get("type", "")).to_upper()
		if ct == _active_tab:
			filtered.append(item)

	filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _compare_instances(a, b)
	)

	if empty_label:
		empty_label.visible = filtered.is_empty()

	var card_w := 200.0
	var card_h := 282.0
	var col_vbox: VBoxContainer = null
	for i in range(filtered.size()):
		if i % 2 == 0:
			col_vbox = VBoxContainer.new()
			col_vbox.add_theme_constant_override("separation", 12)
			card_columns.add_child(col_vbox)
		var item := filtered[i]
		var uid := int(item["uid"])
		var cid := str(item["id"])
		var in_deck := int(item["in_deck"])
		var holder := _create_sell_card_node(uid, cid, in_deck, card_w, card_h)
		col_vbox.add_child(holder)
		_tray_nodes_by_uid[uid] = holder

		var cv := holder.get_node_or_null("CardView") as CardView
		if cv:
			var cdata := Database.get_card(cid)
			if not cdata.is_empty():
				cv.render_card(cdata)

	_update_selection_badges()
	if card_scroll:
		card_scroll.scroll_horizontal = 0
		call_deferred("_sync_scrollbar")


func _create_sell_card_node(uid: int, card_id: String, in_deck_slot: int, target_w: float, target_h: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(target_w, target_h)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var cv: CardView = CardViewScene.instantiate() as CardView
	cv.name = "CardView"
	cv.pivot_offset = Vector2.ZERO
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.set_render_size(Vector2(target_w, target_h))
	holder.add_child(cv)

	if in_deck_slot > 0:
		var in_use := _build_circle_badge("InUseBadge", Color(0.0, 1.0, 0.214, 1.0), 140.0, target_w, target_h, "In Deck", 31, 7)
		holder.add_child(in_use)
	else:
		var seq_badge := _build_circle_badge("SequenceBadge", Color(1.0, 0.0, 0.0, 1.0), 132.0, target_w, target_h, "1", 62, 7)
		seq_badge.visible = false
		holder.add_child(seq_badge)

	var press_state := {"down_pos": Vector2.ZERO, "dragging": false}
	holder.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
				_pending_long_press.clear()
				_open_zoom_card(card_id)
				return
			if ev.button_index == MOUSE_BUTTON_LEFT:
				if ev.pressed:
					if ev.double_click:
						_pending_long_press.clear()
						_open_zoom_card(card_id)
						return
					press_state["down_pos"] = ev.global_position
					press_state["dragging"] = false
					_pending_long_press = {
						"ref": weakref(holder),
						"card_id": card_id,
						"elapsed": 0.0,
						"fired": false,
					}
				else:
					var same_holder: bool = _pending_long_press.get("ref", null) != null and (_pending_long_press["ref"] as WeakRef).get_ref() == holder
					var was_long := bool(_pending_long_press.get("fired", false))
					if same_holder:
						_pending_long_press.clear()
					var dist: float = ev.global_position.distance_to(press_state["down_pos"])
					if not (same_holder and was_long) and dist < 18.0:
						_on_card_tapped(uid, in_deck_slot)
	)
	return holder


func _build_circle_badge(node_name: String, color: Color, bw: float, target_w: float, target_h: float, text_str: String, font_sz: int, outline_sz: int) -> TextureRect:
	var badge := TextureRect.new()
	badge.name = node_name
	badge.texture = TEX_STACK_CIRCLE
	badge.self_modulate = color
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2((target_w - bw) * 0.5, (target_h - bw) * 0.5 - 24.0)
	badge.size = Vector2(bw, bw)

	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = text_str
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FONT_KB)
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", outline_sz)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)
	return badge


func _on_card_tapped(uid: int, in_deck_slot: int) -> void:
	if in_deck_slot > 0:
		_play_sfx(SFX_CLICK)
		_show_error_popup("You can't sell this card, it's being used in Deck %d." % in_deck_slot)
		return

	var pos := _chosen_uids.find(uid)
	if pos != -1:
		_play_sfx(SFX_SELECT)
		_chosen_uids.remove_at(pos)
	else:
		if _chosen_uids.size() >= MAX_SELECT_LIMIT:
			_play_sfx(SFX_CLICK)
			return
		_play_sfx(SFX_SELECT)
		_chosen_uids.append(uid)

	_update_selection_badges()
	_refresh_sell_button()


func _update_selection_badges() -> void:
	var at_limit := _chosen_uids.size() >= MAX_SELECT_LIMIT
	for uid_key in _tray_nodes_by_uid.keys():
		var uid := int(uid_key)
		var holder := _tray_nodes_by_uid[uid_key] as Control
		if holder == null or not is_instance_valid(holder):
			continue
		var seq_badge := holder.get_node_or_null("SequenceBadge") as TextureRect
		var cv := holder.get_node_or_null("CardView") as CanvasItem
		if seq_badge == null:
			continue
		var idx := _chosen_uids.find(uid)
		if idx != -1:
			seq_badge.visible = true
			var lbl := seq_badge.get_node_or_null("Label") as Label
			if lbl:
				lbl.text = str(idx + 1)
			if cv:
				cv.modulate = Color.WHITE
		else:
			seq_badge.visible = false
			if cv:
				cv.modulate = Color(0.55, 0.55, 0.55, 1.0) if at_limit else Color.WHITE


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
# ACTIONS: BACK, SELL, CONFIRM, ERROR, SORT, ZOOM
# ==============================================================================

func _on_back_pressed() -> void:
	_play_sfx(SFX_BACK)
	close_modal()


func _build_selected_card_ids() -> Array[String]:
	var out: Array[String] = []
	for u in _chosen_uids:
		var item := _find_instance_by_uid(u)
		if not item.is_empty():
			out.append(str(item["id"]))
	return out


func _validate_sell_selection(card_ids: Array[String]) -> Dictionary:
	if card_ids.is_empty():
		return {"ok": false, "reason": "You haven't selected any cards to sell!"}

	var total_cards := GameManager.get_total_card_count()
	if total_cards - card_ids.size() < GameManager.MIN_CARDS_IN_INVENTORY:
		if card_ids.size() == 1:
			return {"ok": false, "reason": "Selling 1 card would leave less than %d cards in your inventory" % GameManager.MIN_CARDS_IN_INVENTORY}
		return {"ok": false, "reason": "Selling %d cards would leave less than %d cards in your inventory" % [card_ids.size(), GameManager.MIN_CARDS_IN_INVENTORY]}

	var sold_creatures := 0
	var total_coins := 0
	for cid in card_ids:
		var c := Database.get_card(cid)
		if str(c.get("type", "")).to_upper() == "CREATURE":
			sold_creatures += 1
		total_coins += maxi(0, int(c.get("sale_price", 0)))

	if sold_creatures > 0 and (GameManager.get_total_creature_count() - sold_creatures) < GameManager.MIN_CREATURES_IN_INVENTORY:
		return {"ok": false, "reason": "Selling these cards would leave you with less than %d creatures in your inventory." % GameManager.MIN_CREATURES_IN_INVENTORY}

	return {"ok": true, "coins": total_coins}


func _on_sell_pressed() -> void:
	_play_sfx(SFX_SELECT)
	var list := _build_selected_card_ids()
	var check := _validate_sell_selection(list)
	if not check.get("ok", false):
		_show_error_popup(str(check.get("reason", "Cannot sell selected cards.")))
		return
	_open_confirm_popup(list, int(check.get("coins", 0)))


func _open_confirm_popup(card_ids: Array[String], coins_total: int) -> void:
	if e1_desc_lbl:
		e1_desc_lbl.text = "Sell These Cards For %d Coins?" % coins_total
	if e1_grid:
		for ch in e1_grid.get_children():
			e1_grid.remove_child(ch)
			ch.queue_free()
		var cw := 180.0
		var ch_size := 254.0
		for cid in card_ids:
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(cw, ch_size)
			holder.mouse_filter = Control.MOUSE_FILTER_STOP
			holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var cv := CardViewScene.instantiate() as CardView
			cv.pivot_offset = Vector2.ZERO
			cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cv.scale = Vector2(cw / 130.0, ch_size / 184.0)
			holder.add_child(cv)
			e1_grid.add_child(holder)
			var cdata := Database.get_card(cid)
			if not cdata.is_empty():
				cv.render_card(cdata)
			holder.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_RIGHT or ev.double_click):
					_open_zoom_card(cid)
			)

	if e1_confirm:
		e1_confirm.visible = true
		if e1_panel:
			e1_panel.scale = Vector2(0.05, 0.05)
			create_tween().tween_property(e1_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_confirm_popup() -> void:
	_play_sfx(SFX_BACK)
	if e1_confirm:
		e1_confirm.visible = false


func _on_confirm_sell_yes() -> void:
	var list := _build_selected_card_ids()
	var res := GameManager.sell_cards(list)
	if e1_confirm:
		e1_confirm.visible = false
	if res.get("ok", false):
		_play_sfx(SFX_SELL)
		var gained := int(res.get("coins_gained", 0))
		var sold_n := int(res.get("sold_count", list.size()))
		_chosen_uids.clear()
		_refresh_all()
		cards_sold.emit(sold_n, gained)
	else:
		_play_sfx(SFX_CLICK)
		_show_error_popup(str(res.get("reason", "Sale failed.")))


func _show_error_popup(msg: String) -> void:
	if e2_title_lbl:
		e2_title_lbl.text = "Nope!"
	if e2_msg_lbl:
		e2_msg_lbl.text = msg
	if e2_error:
		e2_error.visible = true
		if e2_panel:
			e2_panel.scale = Vector2(0.05, 0.05)
			create_tween().tween_property(e2_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_error_popup() -> void:
	_play_sfx(SFX_SELECT)
	if e2_error:
		e2_error.visible = false


# ==============================================================================
# SORT PANEL & COMPARATOR
# ==============================================================================

func _build_sort_buttons() -> void:
	if e3_grid == null:
		return
	for ch in e3_grid.get_children():
		e3_grid.remove_child(ch)
		ch.queue_free()
	var old_fact := e3_sort.get_node_or_null("SortButtonFaction") if e3_sort else null
	if old_fact:
		old_fact.queue_free()

	var pair_specs := [
		{"key": "ATK", "label": "Attack"},
		{"key": "NONE", "label": "MP Cost"},
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
		e3_grid.add_child(btn)

	if e3_sort:
		var fbtn := _create_sort_button("Faction")
		fbtn.name = "SortButtonFaction"
		fbtn.position = Vector2(849.0, 887.0)
		fbtn.pressed.connect(func(): _apply_sort_option("FACTION"))
		e3_sort.add_child(fbtn)


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
	if e3_sort:
		e3_sort.visible = true


func _close_sort_popup() -> void:
	_play_sfx(SFX_BACK)
	if e3_sort:
		e3_sort.visible = false


func _apply_sort_option(sort_key: String) -> void:
	_play_sfx(SFX_SELECT)
	if _primary_sort != sort_key:
		_secondary_sort = _primary_sort
		_primary_sort = sort_key
	if e3_sort:
		e3_sort.visible = false
	_refresh_grid()


func _compare_instances(a: Dictionary, b: Dictionary) -> bool:
	var cid_a := str(a["id"])
	var cid_b := str(b["id"])
	if cid_a == cid_b:
		# Non-deck (sellable) copies vs In Deck copies keep consistent grouping
		var ad := int(a["in_deck"])
		var bd := int(b["in_deck"])
		if ad != bd:
			return ad > bd
		return int(a["uid"]) < int(b["uid"])
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
	cv.set_render_size(Vector2(zoom_w, zoom_h))
	cv.position = Vector2(-zoom_w * 0.5, -zoom_h * 0.5)
	cv.scale = Vector2.ONE
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_holder.add_child(cv)
	var cdata := Database.get_card(card_id)
	if not cdata.is_empty():
		cv.render_card(cdata)
	zoom_holder.position = Vector2(1024.0, 576.0) - zoom_overlay.position
	zoom_holder.scale = Vector2(0.35, 0.35)
	zoom_overlay.visible = true
	create_tween().tween_property(zoom_holder, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _close_zoom() -> void:
	if zoom_overlay and zoom_overlay.visible:
		_play_sfx(SFX_BACK)
		zoom_overlay.visible = false


func show_panel_preview(mode: String) -> void:
	if mode == "sell_sort":
		if e3_sort:
			e3_sort.visible = true
	elif mode == "sell_error":
		_show_error_popup("You haven't selected any cards to sell!")
	elif mode == "sell_confirm":
		var sample_ids: Array[String] = _build_selected_card_ids()
		if sample_ids.is_empty():
			for item in _owned_instances:
				sample_ids.append(str(item["id"]))
				if sample_ids.size() >= 3:
					break
		var coins := 0
		for cid in sample_ids:
			coins += maxi(0, int(Database.get_card(cid).get("sale_price", 0)))
		_open_confirm_popup(sample_ids, coins)


func _play_sfx(stream: AudioStream) -> void:
	if Audio and stream:
		Audio.play_sfx(stream)
