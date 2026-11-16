extends Control
class_name SellCardsModal

signal closed
signal cards_sold(sold_count: int, coins_gained: int)

const SFX_CLICK: AudioStream = preload("res://assets/audio/sfx/UI_Select.wav")
const SFX_SELL: AudioStream = preload("res://assets/audio/sfx/low_Deck_SellCard.wav")
const CardViewScene: PackedScene = preload("res://scenes/components/CardView.tscn")

@onready var dimmer: ColorRect = $Dimmer
@onready var frame: Control = $Center/Frame
@onready var close_btn: BaseButton = $Center/Frame/TitleBar/CloseBtn
@onready var stats_label: Label = $Center/Frame/Body/TopBar/StatsLabel
@onready var type_select: OptionButton = $Center/Frame/Body/TopBar/TypeSelect
@onready var cards_grid: GridContainer = $Center/Frame/Body/Scroll/CardsGrid
@onready var empty_label: Label = $Center/Frame/Body/EmptyLabel
@onready var status_label: Label = $Center/Frame/Body/FooterRow/StatusLabel
@onready var value_label: Label = $Center/Frame/Body/FooterRow/ValueLabel
@onready var clear_btn: Button = $Center/Frame/Body/FooterRow/ClearBtn
@onready var sell_btn: Button = $Center/Frame/Body/FooterRow/SellBtn
@onready var confirm_overlay: Control = $ConfirmOverlay
@onready var confirm_label: Label = $ConfirmOverlay/Center/Panel/VBox/ConfirmLabel
@onready var confirm_yes_btn: Button = $ConfirmOverlay/Center/Panel/VBox/Buttons/YesBtn
@onready var confirm_no_btn: Button = $ConfirmOverlay/Center/Panel/VBox/Buttons/NoBtn

var _anim_tween: Tween = null
var _is_closing: bool = false
var _selected_type: String = "ALL"
var _selected_counts: Dictionary = {} # card_id -> int selected


func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		StoreModalAnimator.attach_button_reaction(close_btn)
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_pressed)
		StoreModalAnimator.attach_button_reaction(clear_btn)
	if sell_btn:
		sell_btn.pressed.connect(_on_sell_pressed)
		StoreModalAnimator.attach_button_reaction(sell_btn)
	if confirm_yes_btn:
		confirm_yes_btn.pressed.connect(_on_confirm_yes)
		StoreModalAnimator.attach_button_reaction(confirm_yes_btn)
	if confirm_no_btn:
		confirm_no_btn.pressed.connect(func():
			_play_sfx(SFX_CLICK)
			if confirm_overlay:
				confirm_overlay.visible = false
		)
		StoreModalAnimator.attach_button_reaction(confirm_no_btn)
	if type_select:
		type_select.clear()
		for t in [["Type: ALL", "ALL"], ["Creatures", "CREATURE"], ["Spells", "SPELL"], ["Buildings", "BUILDING"]]:
			type_select.add_item(t[0])
			type_select.set_item_metadata(type_select.item_count - 1, t[1])
		type_select.item_selected.connect(func(idx: int):
			_selected_type = str(type_select.get_item_metadata(idx))
			_refresh_grid()
		)
	if confirm_overlay:
		confirm_overlay.visible = false


func open_modal() -> void:
	_is_closing = false
	_selected_counts.clear()
	if confirm_overlay:
		confirm_overlay.visible = false
	_set_status("", false)
	_refresh_all()
	_anim_tween = StoreModalAnimator.play_open(self, dimmer, frame, _anim_tween)


func close_modal() -> void:
	if _is_closing or not visible:
		return
	_is_closing = true
	if confirm_overlay:
		confirm_overlay.visible = false
	_anim_tween = StoreModalAnimator.play_close(self, dimmer, frame, _anim_tween, func():
		_is_closing = false
		closed.emit()
	)


func _refresh_all() -> void:
	var box_counts := GameManager.get_inventory_only_counts()
	for cid in _selected_counts.keys():
		var max_sellable := int(box_counts.get(cid, 0))
		if max_sellable <= 0:
			_selected_counts.erase(cid)
		else:
			_selected_counts[cid] = mini(int(_selected_counts[cid]), max_sellable)
	_refresh_header_and_footer()
	_refresh_grid()


func _refresh_header_and_footer() -> void:
	var total_cards := GameManager.get_total_card_count()
	var total_creatures := GameManager.get_total_creature_count()
	if stats_label:
		stats_label.text = "Box: %d / %d  |  Creatures: %d (Min %d)" % [
			total_cards, GameManager.get_max_inventory(), total_creatures, GameManager.MIN_CREATURES_IN_INVENTORY
		]
	var sel_total := 0
	var coin_total := 0
	for cid in _selected_counts.keys():
		var cnt := int(_selected_counts[cid])
		if cnt > 0:
			sel_total += cnt
			var c_data := Database.get_card(str(cid))
			coin_total += maxi(0, int(c_data.get("sale_price", 0))) * cnt
	if value_label:
		value_label.text = "Selected: %d  |  Total: %d Coins" % [sel_total, coin_total]
	if clear_btn:
		clear_btn.disabled = sel_total == 0


func _refresh_grid() -> void:
	if cards_grid == null:
		return
	for ch in cards_grid.get_children():
		cards_grid.remove_child(ch)
		ch.queue_free()

	var box_counts := GameManager.get_inventory_only_counts()
	var deck_counts := GameManager.get_deck_card_counts()

	var sellable_ids: Array[String] = []
	var deck_locked_ids: Array[String] = []
	for cid in box_counts.keys():
		sellable_ids.append(str(cid))
	for cid in deck_counts.keys():
		var k := str(cid)
		if not box_counts.has(k):
			deck_locked_ids.append(k)
	sellable_ids.sort()
	deck_locked_ids.sort()

	var ordered_ids: Array[String] = []
	for cid in sellable_ids:
		var c := Database.get_card(cid)
		if not c.is_empty() and (_selected_type == "ALL" or str(c.get("type", "")) == _selected_type):
			ordered_ids.append(cid)
	for cid in deck_locked_ids:
		var c := Database.get_card(cid)
		if not c.is_empty() and (_selected_type == "ALL" or str(c.get("type", "")) == _selected_type):
			ordered_ids.append(cid)

	if empty_label:
		empty_label.visible = ordered_ids.is_empty()

	for cid in ordered_ids:
		var c_data := Database.get_card(cid)
		var avail := int(box_counts.get(cid, 0))
		var in_deck := int(deck_counts.get(cid, 0))
		var sel := int(_selected_counts.get(cid, 0))
		var price := maxi(0, int(c_data.get("sale_price", 0)))

		var slot := VBoxContainer.new()
		slot.custom_minimum_size = Vector2(146, 240)
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_theme_constant_override("separation", 3)
		cards_grid.add_child(slot)

		var cv := CardViewScene.instantiate() as CardView
		slot.add_child(cv)
		cv.render_card(c_data)
		if avail <= 0:
			cv.modulate = Color(0.55, 0.58, 0.65, 0.85)
			cv.card_clicked.connect(func(_n): _set_status("Cards currently in your active deck cannot be sold!", true))
		else:
			if sel > 0:
				cv.modulate = Color(1.0, 0.96, 0.72, 1.0)
			cv.card_clicked.connect(func(_n): _step_select(cid, 1, avail))

		var ctrl_row := HBoxContainer.new()
		ctrl_row.alignment = BoxContainer.ALIGNMENT_CENTER
		ctrl_row.add_theme_constant_override("separation", 4)
		slot.add_child(ctrl_row)

		if avail <= 0:
			var lock_lbl := Label.new()
			lock_lbl.text = "In Deck x%d (Locked)" % in_deck
			lock_lbl.add_theme_font_size_override("font_size", 11)
			lock_lbl.modulate = Color(0.75, 0.85, 0.95)
			ctrl_row.add_child(lock_lbl)
		else:
			var minus_btn := Button.new()
			minus_btn.text = "-"
			minus_btn.custom_minimum_size = Vector2(26, 24)
			minus_btn.disabled = (sel <= 0)
			minus_btn.pressed.connect(func(): _step_select(cid, -1, avail))
			ctrl_row.add_child(minus_btn)

			var qty_lbl := Label.new()
			qty_lbl.text = "%d/%d (%dc)" % [sel, avail, price]
			qty_lbl.add_theme_font_size_override("font_size", 11)
			qty_lbl.modulate = Color(0.4, 1.0, 0.55) if sel > 0 else Color.WHITE
			ctrl_row.add_child(qty_lbl)

			var plus_btn := Button.new()
			plus_btn.text = "+"
			plus_btn.custom_minimum_size = Vector2(26, 24)
			plus_btn.disabled = (sel >= avail)
			plus_btn.pressed.connect(func(): _step_select(cid, 1, avail))
			ctrl_row.add_child(plus_btn)


func _step_select(cid: String, delta: int, max_avail: int) -> void:
	_play_sfx(SFX_CLICK)
	var cur := int(_selected_counts.get(cid, 0))
	var next := clampi(cur + delta, 0, max_avail)
	if next <= 0:
		_selected_counts.erase(cid)
	else:
		_selected_counts[cid] = next
	_set_status("", false)
	_refresh_header_and_footer()
	_refresh_grid()


func _build_selected_list() -> Array[String]:
	var out: Array[String] = []
	for cid in _selected_counts.keys():
		var cnt := int(_selected_counts[cid])
		for _i in range(cnt):
			out.append(str(cid))
	return out


func _validate_selection(list: Array[String]) -> Dictionary:
	if list.is_empty():
		return {"ok": false, "reason": "Select one or more extra cards to sell!"}
	if GameManager.get_total_card_count() - list.size() < GameManager.MIN_CARDS_IN_INVENTORY:
		return {
			"ok": false,
			"reason": "You must keep at least %d cards in your Card Box!" % GameManager.MIN_CARDS_IN_INVENTORY
		}
	var sold_creatures := 0
	var total_coins := 0
	for cid in list:
		var c := Database.get_card(cid)
		if str(c.get("type", "")) == "CREATURE":
			sold_creatures += 1
		total_coins += maxi(0, int(c.get("sale_price", 0)))
	if sold_creatures > 0 and (GameManager.get_total_creature_count() - sold_creatures) < GameManager.MIN_CREATURES_IN_INVENTORY:
		return {
			"ok": false,
			"reason": "You must keep at least %d creatures in your Card Box!" % GameManager.MIN_CREATURES_IN_INVENTORY
		}
	return {"ok": true, "coins": total_coins}


func _on_clear_pressed() -> void:
	_play_sfx(SFX_CLICK)
	_selected_counts.clear()
	_set_status("", false)
	_refresh_all()


func _on_sell_pressed() -> void:
	_play_sfx(SFX_CLICK)
	var list := _build_selected_list()
	var check := _validate_selection(list)
	if not check.get("ok", false):
		_set_status(str(check.get("reason", "Cannot sell selected cards.")), true)
		return
	if confirm_label:
		confirm_label.text = "Sell %d Card(s) For %d Coins?" % [list.size(), int(check.get("coins", 0))]
	if confirm_overlay:
		confirm_overlay.visible = true


func _on_confirm_yes() -> void:
	var list := _build_selected_list()
	var res := GameManager.sell_cards(list)
	if confirm_overlay:
		confirm_overlay.visible = false
	if res.get("ok", false):
		_play_sfx(SFX_SELL)
		var gained := int(res.get("coins_gained", 0))
		var sold_n := int(res.get("sold_count", list.size()))
		_selected_counts.clear()
		_set_status("Sold %d card(s) for +%d Coins!" % [sold_n, gained], false)
		_refresh_all()
		cards_sold.emit(sold_n, gained)
	else:
		_play_sfx(SFX_CLICK)
		_set_status(str(res.get("reason", "Sale failed.")), true)


func _set_status(msg: String, is_err: bool) -> void:
	if status_label:
		status_label.text = msg
		status_label.modulate = Color(1.0, 0.45, 0.45) if is_err else Color(0.45, 1.0, 0.6)


func _play_sfx(stream: AudioStream) -> void:
	if Audio and stream:
		Audio.play_sfx(stream)


func _on_close_pressed() -> void:
	_play_sfx(SFX_CLICK)
	close_modal()
