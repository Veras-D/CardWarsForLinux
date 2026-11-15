extends Control

signal closed
signal gems_purchased(gems_added: int)

const SFX_CLICK: AudioStream = preload("res://assets/audio/sfx/Click.wav")
const SFX_SELECT: AudioStream = preload("res://assets/audio/sfx/UI_Select.wav")

const PACK_ICONS: Array[Texture2D] = [
	preload("res://assets/textures/ui/store/GsGems.png"),
	preload("res://assets/textures/ui/store/GsSpoon.png"),
	preload("res://assets/textures/ui/store/GsGoblet.png"),
	preload("res://assets/textures/ui/store/GsSkull.png"),
	preload("res://assets/textures/ui/store/GsBox.png"),
	preload("res://assets/textures/ui/store/GsChest.png"),
]

const ICON_SIZES: Array[Vector2] = [
	Vector2(56, 46),
	Vector2(98, 92),
	Vector2(66, 98),
	Vector2(86, 84),
	Vector2(90, 102),
	Vector2(114, 104),
]

@onready var dimmer: ColorRect = $Dimmer
@onready var frame: Control = $Center/Frame
@onready var close_btn: BaseButton = $Center/Frame/TitleBanner/CloseBtn
@onready var slots_grid: GridContainer = $Center/Frame/SlotsGrid
@onready var footer: Control = $Footer
@onready var status_label: Label = $Footer/StatusLabel

var _slot_nodes: Array[Control] = []
var _sparkle_nodes: Array[Control] = []
var _products: Array[Dictionary] = []
var _anim_tween: Tween = null
var _is_closing: bool = false
var _sparkle_time: float = 0.0


func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		StoreModalAnimator.attach_button_reaction(close_btn)
	_collect_slots()
	refresh_display()


func _process(delta: float) -> void:
	if not visible or _sparkle_nodes.is_empty():
		return
	_sparkle_time += delta * 3.2
	for i in range(_sparkle_nodes.size()):
		var sp := _sparkle_nodes[i]
		if not sp or not sp.visible:
			continue
		var children := sp.get_children()
		for j in range(children.size()):
			var star := children[j] as Control
			if star:
				var phase := _sparkle_time + float(i) * 1.1 + float(j) * 1.7
				var s := 0.65 + 0.45 * absf(sin(phase))
				star.pivot_offset = star.size * 0.5
				star.scale = Vector2(s, s)
				star.modulate.a = 0.45 + 0.55 * absf(sin(phase))


func _collect_slots() -> void:
	_slot_nodes.clear()
	_sparkle_nodes.clear()
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
		var sp: Control = slot.get_node_or_null("Sparkles")
		if sp:
			sp.visible = (i >= 3)
			_sparkle_nodes.append(sp)
		var buy_btn: BaseButton = slot.get_node_or_null("BuyBtn")
		if buy_btn:
			var idx: int = i
			buy_btn.pressed.connect(func(): _on_buy_pack(idx))
			StoreModalAnimator.attach_button_reaction(buy_btn)


func open_modal() -> void:
	_is_closing = false
	refresh_display()
	if footer:
		footer.visible = false
	_anim_tween = StoreModalAnimator.play_open(self, dimmer, frame, _anim_tween)


func close_modal() -> void:
	if _is_closing or not visible:
		return
	_is_closing = true
	_anim_tween = StoreModalAnimator.play_close(self, dimmer, frame, _anim_tween, func():
		_is_closing = false
		closed.emit()
	)


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
	var clip := SFX_SELECT if SFX_SELECT else SFX_CLICK
	if Audio and clip:
		Audio.play_sfx(clip)


func _on_buy_pack(idx: int) -> void:
	_play_sfx()
	if idx < 0 or idx >= _products.size():
		return
	var prod: Dictionary = _products[idx]
	var product_id: String = str(prod.get("product_id", ""))
	var res: Dictionary = GameManager.purchase_gem_pack(product_id)
	if footer:
		footer.visible = true
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
	close_modal()


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
