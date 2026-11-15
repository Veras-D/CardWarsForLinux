extends Control

signal closed
signal gems_purchased(gems_added: int)

const SFX_CLICK: AudioStream = preload("res://assets/audio/sfx/Click.wav")

const PACK_ICONS: Array[Texture2D] = [
	preload("res://assets/textures/ui/store/GsGems.png"),
	preload("res://assets/textures/ui/store/GsSpoon.png"),
	preload("res://assets/textures/ui/store/GsGoblet.png"),
	preload("res://assets/textures/ui/store/GsSkull.png"),
	preload("res://assets/textures/ui/store/GsBox.png"),
	preload("res://assets/textures/ui/store/GsChest.png"),
]

const ICON_SIZES: Array[Vector2] = [
	Vector2(62, 52),
	Vector2(90, 84),
	Vector2(56, 92),
	Vector2(78, 76),
	Vector2(82, 96),
	Vector2(106, 98),
]

@onready var close_btn: BaseButton = $Center/Frame/CloseBtn
@onready var slots_grid: GridContainer = $Center/Frame/SlotsGrid
@onready var status_label: Label = $Center/Frame/Footer/StatusLabel

var _slot_nodes: Array[Control] = []
var _products: Array[Dictionary] = []


func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	_collect_slots()
	refresh_display()


func _collect_slots() -> void:
	_slot_nodes.clear()
	if not slots_grid or slots_grid.get_child_count() == 0:
		return
	var template: Control = slots_grid.get_child(0)
	while slots_grid.get_child_count() < PACK_ICONS.size():
		var clone: Control = template.duplicate()
		clone.name = "Slot%d" % (slots_grid.get_child_count() + 1)
		slots_grid.add_child(clone)
	for i in range(slots_grid.get_child_count()):
		var slot: Control = slots_grid.get_child(i)
		_slot_nodes.append(slot)
		var buy_btn: BaseButton = slot.get_node_or_null("BuyBtn")
		if buy_btn:
			var idx: int = i
			buy_btn.pressed.connect(func(): _on_buy_pack(idx))


func open_modal() -> void:
	refresh_display()
	if status_label:
		status_label.text = "Exchange Coins for Magic Gems! (Coins: %s)" % _format_int(GameManager.get_coins())
		status_label.modulate = Color(1, 1, 1, 1)
	visible = true


func refresh_display() -> void:
	_products = Database.get_gem_shop_products()
	for i in range(_slot_nodes.size()):
		var slot: Control = _slot_nodes[i]
		if i >= _products.size():
			slot.visible = false
			continue
		slot.visible = true
		var prod: Dictionary = _products[i]
		var gem_count: int = int(prod.get("gems", 0))
		var coin_price: int = int(prod.get("coin_price", 0))

		var amount_lbl: Label = slot.get_node_or_null("AmountLabel")
		if amount_lbl:
			amount_lbl.text = "%d %s" % [gem_count, "Gem" if gem_count == 1 else "Gems"]

		var icon_rect: TextureRect = slot.get_node_or_null("IconCenter/Icon")
		if icon_rect and i < PACK_ICONS.size():
			icon_rect.texture = PACK_ICONS[i]
			icon_rect.custom_minimum_size = ICON_SIZES[i]

		var price_lbl: Label = slot.get_node_or_null("BuyBtn/HBox/PriceLabel")
		if price_lbl:
			price_lbl.text = _format_int(coin_price)


func _play_sfx() -> void:
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)


func _on_buy_pack(idx: int) -> void:
	_play_sfx()
	if idx < 0 or idx >= _products.size():
		return
	var prod: Dictionary = _products[idx]
	var product_id: String = str(prod.get("product_id", ""))
	var res: Dictionary = GameManager.purchase_gem_pack(product_id)
	if res.get("ok", false):
		var added: int = int(res.get("gems_added", 0))
		if status_label:
			status_label.text = "Purchased +%d %s! (Coins: %s)" % [
				added,
				"Gem" if added == 1 else "Gems",
				_format_int(GameManager.get_coins())
			]
			status_label.modulate = Color(0.65, 1.0, 0.65)
		gems_purchased.emit(added)
	else:
		if status_label:
			status_label.text = "Not enough coins! Need %s Coins." % _format_int(int(prod.get("coin_price", 0)))
			status_label.modulate = Color(1.0, 0.45, 0.45)


func _on_close_pressed() -> void:
	_play_sfx()
	visible = false
	closed.emit()


static func _format_int(val: int) -> String:
	var s: String = str(abs(val))
	var out: String = ""
	var count: int = 0
	for idx in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[idx] + out
		count += 1
	return ("-" + out) if val < 0 else out
