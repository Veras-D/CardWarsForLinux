extends Control
class_name CardBoxModal

signal closed
signal open_store_inventory_requested

const SFX_CLICK: AudioStream = preload("res://assets/audio/sfx/UI_Select.wav")
const CardViewScene: PackedScene = preload("res://scenes/components/CardView.tscn")

@onready var dimmer: ColorRect = $Dimmer
@onready var frame: Control = $Center/Frame
@onready var close_btn: BaseButton = $Center/Frame/TitleBar/CloseBtn
@onready var capacity_label: Label = $Center/Frame/Body/TopInfoRow/CapacityLabel
@onready var expand_btn: Button = $Center/Frame/Body/TopInfoRow/ExpandBtn
@onready var view_mode_btn: Button = $Center/Frame/Body/TopInfoRow/ViewModeBtn
@onready var type_select: OptionButton = $Center/Frame/Body/FilterRow/TypeSelect
@onready var faction_select: OptionButton = $Center/Frame/Body/FilterRow/FactionSelect
@onready var search_edit: LineEdit = $Center/Frame/Body/FilterRow/SearchEdit
@onready var count_label: Label = $Center/Frame/Body/FilterRow/CountLabel
@onready var cards_grid: GridContainer = $Center/Frame/Body/Scroll/CardsGrid
@onready var empty_label: Label = $Center/Frame/Body/EmptyLabel
@onready var detail_overlay: Control = $DetailOverlay
@onready var detail_card_holder: Control = $DetailOverlay/Center/Panel/VBox/HBox/CardHolder
@onready var detail_title: Label = $DetailOverlay/Center/Panel/VBox/HBox/InfoVBox/CardTitle
@onready var detail_stats: Label = $DetailOverlay/Center/Panel/VBox/HBox/InfoVBox/StatsLabel
@onready var detail_desc: Label = $DetailOverlay/Center/Panel/VBox/HBox/InfoVBox/DescLabel
@onready var detail_close_btn: BaseButton = $DetailOverlay/Center/Panel/VBox/CloseDetailBtn

var _anim_tween: Tween = null
var _is_closing: bool = false
var _show_all_compendium: bool = false
var _selected_type: String = "ALL"
var _selected_faction: String = "ALL"
var _search_text: String = ""


func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		StoreModalAnimator.attach_button_reaction(close_btn)
	if expand_btn:
		expand_btn.pressed.connect(_on_expand_pressed)
		StoreModalAnimator.attach_button_reaction(expand_btn)
	if view_mode_btn:
		view_mode_btn.pressed.connect(_on_toggle_view_mode)
		StoreModalAnimator.attach_button_reaction(view_mode_btn)
	if detail_close_btn:
		detail_close_btn.pressed.connect(func():
			_play_sfx()
			if detail_overlay:
				detail_overlay.visible = false
		)
	if detail_overlay:
		detail_overlay.visible = false

	_setup_filters()


func _setup_filters() -> void:
	if type_select:
		type_select.clear()
		for t in [["Type: ALL", "ALL"], ["Creatures", "CREATURE"], ["Spells", "SPELL"], ["Buildings", "BUILDING"]]:
			type_select.add_item(t[0])
			type_select.set_item_metadata(type_select.item_count - 1, t[1])
		type_select.item_selected.connect(func(idx: int):
			_selected_type = str(type_select.get_item_metadata(idx))
			_refresh_grid()
		)
	if faction_select:
		faction_select.clear()
		for f in ["ALL", "Corn", "Plains", "Sand", "Swamp", "Cotton", "Universal"]:
			faction_select.add_item("Faction: ALL" if f == "ALL" else f)
			faction_select.set_item_metadata(faction_select.item_count - 1, f)
		faction_select.item_selected.connect(func(idx: int):
			_selected_faction = str(faction_select.get_item_metadata(idx))
			_refresh_grid()
		)
	if search_edit:
		search_edit.text_changed.connect(func(q: String):
			_search_text = q
			_refresh_grid()
		)


func open_modal(show_compendium: bool = false) -> void:
	_is_closing = false
	_show_all_compendium = show_compendium
	if detail_overlay:
		detail_overlay.visible = false
	_refresh_all()
	_anim_tween = StoreModalAnimator.play_open(self, dimmer, frame, _anim_tween)


func close_modal() -> void:
	if _is_closing or not visible:
		return
	_is_closing = true
	if detail_overlay:
		detail_overlay.visible = false
	_anim_tween = StoreModalAnimator.play_close(self, dimmer, frame, _anim_tween, func():
		_is_closing = false
		closed.emit()
	)


func _refresh_all() -> void:
	var total := GameManager.get_total_card_count()
	var max_inv := GameManager.get_max_inventory()
	if capacity_label:
		capacity_label.text = "Card Box: %d / %d Cards" % [total, max_inv]
	if view_mode_btn:
		view_mode_btn.text = "Showing: Compendium (All)" if _show_all_compendium else "Showing: My Card Box"
	if expand_btn:
		var tier := Database.get_card_box_tier(max_inv)
		expand_btn.disabled = tier.is_empty() or (max_inv + int(tier.get("gain", 0)) > Database.card_box_max_capacity)
	_refresh_grid()


func _refresh_grid() -> void:
	if cards_grid == null:
		return
	for ch in cards_grid.get_children():
		cards_grid.remove_child(ch)
		ch.queue_free()

	var box_counts := GameManager.get_inventory_only_counts()
	var deck_counts := GameManager.get_deck_card_counts()
	var q_lower := _search_text.strip_edges().to_lower()
	var items: Array[Dictionary] = []

	if _show_all_compendium:
		for c in Database.all_cards_list:
			if _matches_filter(c, q_lower):
				items.append(c)
	else:
		var seen: Dictionary = {}
		for cid in GameManager.player_deck:
			var k := str(cid)
			if not seen.has(k):
				seen[k] = true
				var card := Database.get_card(k)
				if not card.is_empty() and _matches_filter(card, q_lower):
					items.append(card)
		for cid in GameManager.player_inventory_cards:
			var k := str(cid)
			if not seen.has(k):
				seen[k] = true
				var card := Database.get_card(k)
				if not card.is_empty() and _matches_filter(card, q_lower):
					items.append(card)

	var render_limit := mini(items.size(), 90)
	if count_label:
		if items.size() > render_limit:
			count_label.text = "Showing %d of %d" % [render_limit, items.size()]
		else:
			count_label.text = "%d Unique" % items.size()
	if empty_label:
		empty_label.visible = items.is_empty()

	for i in range(render_limit):
		var c_data := items[i]
		var cid := str(c_data.get("id", ""))
		var in_box := int(box_counts.get(cid, 0))
		var in_deck := int(deck_counts.get(cid, 0))
		var owned_total := in_box + in_deck
		var sale_val := maxi(0, int(c_data.get("sale_price", 0)))

		var slot := VBoxContainer.new()
		slot.custom_minimum_size = Vector2(146, 224)
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_theme_constant_override("separation", 3)
		cards_grid.add_child(slot)

		var cv := CardViewScene.instantiate() as CardView
		slot.add_child(cv)
		cv.render_card(c_data)
		cv.card_clicked.connect(func(_node): _show_detail(c_data, in_box, in_deck))

		var info_lbl := Label.new()
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_lbl.add_theme_font_size_override("font_size", 11)
		if _show_all_compendium:
			info_lbl.text = "Own:%d  Sale:%dc" % [owned_total, sale_val]
		elif in_deck > 0 and in_box > 0:
			info_lbl.text = "Deck:%d  Box:%d  (%dc)" % [in_deck, in_box, sale_val]
		elif in_deck > 0:
			info_lbl.text = "In Deck x%d (%dc)" % [in_deck, sale_val]
			info_lbl.modulate = Color(0.75, 0.92, 1.0)
		else:
			info_lbl.text = "In Box x%d (%dc)" % [in_box, sale_val]
			info_lbl.modulate = Color(0.95, 0.92, 0.72)
		slot.add_child(info_lbl)


func _matches_filter(card: Dictionary, q_lower: String) -> bool:
	if _selected_type != "ALL" and str(card.get("type", "")) != _selected_type:
		return false
	if _selected_faction != "ALL" and str(card.get("faction", "")) != _selected_faction:
		return false
	if q_lower != "":
		var cname := str(card.get("name", "")).to_lower()
		var cid := str(card.get("id", "")).to_lower()
		if not (q_lower in cname or q_lower in cid):
			return false
	return true


func _show_detail(c_data: Dictionary, in_box: int, in_deck: int) -> void:
	_play_sfx()
	if detail_overlay == null:
		return
	if detail_card_holder:
		for ch in detail_card_holder.get_children():
			detail_card_holder.remove_child(ch)
			ch.queue_free()
		var preview := CardViewScene.instantiate() as CardView
		preview.scale = Vector2(1.15, 1.15)
		detail_card_holder.add_child(preview)
		preview.render_card(c_data)

	if detail_title:
		detail_title.text = str(c_data.get("name", ""))
	if detail_stats:
		var sale_val := maxi(0, int(c_data.get("sale_price", 0)))
		detail_stats.text = "%s • %s • Cost %d MP • Sale: %d Coins\nOwned: %d (In Active Deck: %d | In Card Box: %d)" % [
			str(c_data.get("type", "")),
			str(c_data.get("faction", "")),
			int(c_data.get("cost", 0)),
			sale_val,
			in_box + in_deck,
			in_deck,
			in_box
		]
	if detail_desc:
		detail_desc.text = str(c_data.get("desc", ""))
	detail_overlay.visible = true


func _on_toggle_view_mode() -> void:
	_play_sfx()
	_show_all_compendium = not _show_all_compendium
	_refresh_all()


func _on_expand_pressed() -> void:
	_play_sfx()
	close_modal()
	open_store_inventory_requested.emit()


func _play_sfx() -> void:
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)


func _on_close_pressed() -> void:
	_play_sfx()
	close_modal()
