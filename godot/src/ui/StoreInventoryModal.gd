extends Control

signal closed
signal inventory_upgraded(new_max: int)

const SFX_CLICK: AudioStream = preload("res://assets/audio/sfx/Click.wav")

@onready var dimmer: ColorRect = $Dimmer
@onready var frame: Control = $Center/Frame
@onready var close_btn: BaseButton = $Center/Frame/TitleBar/CloseBtn
@onready var purchase_panel: Control = $Center/Frame/Body/PurchasePanel
@onready var prompt_label: Label = $Center/Frame/Body/PurchasePanel/PromptLabel
@onready var current_val_label: Label = $Center/Frame/Body/PurchasePanel/CurrentValLabel
@onready var coins_btn: BaseButton = $Center/Frame/Body/PurchasePanel/Buttons/CoinsBtn
@onready var coin_price_label: Label = $Center/Frame/Body/PurchasePanel/Buttons/CoinsBtn/HBox/PriceLabel
@onready var gems_btn: BaseButton = $Center/Frame/Body/PurchasePanel/Buttons/GemsBtn
@onready var gem_price_label: Label = $Center/Frame/Body/PurchasePanel/Buttons/GemsBtn/HBox/PriceLabel
@onready var max_reached_panel: Control = $Center/Frame/Body/MaxReachedPanel
@onready var max_ok_btn: BaseButton = $Center/Frame/Body/MaxReachedPanel/OkBtn
@onready var status_banner: Control = $Center/Frame/Body/StatusBanner
@onready var status_label: Label = $Center/Frame/Body/StatusBanner/StatusLabel

var _anim_tween: Tween = null
var _is_closing: bool = false


func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		StoreModalAnimator.attach_button_reaction(close_btn)
	if max_ok_btn:
		max_ok_btn.pressed.connect(_on_close_pressed)
		StoreModalAnimator.attach_button_reaction(max_ok_btn)
	if coins_btn:
		coins_btn.pressed.connect(_on_buy_with_coins)
		StoreModalAnimator.attach_button_reaction(coins_btn)
	if gems_btn:
		gems_btn.pressed.connect(_on_buy_with_gems)
		StoreModalAnimator.attach_button_reaction(gems_btn)
	if status_banner:
		status_banner.visible = false
	refresh_display()


func open_modal() -> void:
	_is_closing = false
	if status_banner:
		status_banner.visible = false
	refresh_display()
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
	var cur_max: int = GameManager.get_max_inventory()
	var tier: Dictionary = Database.get_card_box_tier(cur_max)
	var gain: int = int(tier.get("gain", 0))
	var at_max: bool = tier.is_empty() or gain <= 0 or cur_max + gain > Database.card_box_max_capacity

	if purchase_panel:
		purchase_panel.visible = not at_max
	if max_reached_panel:
		max_reached_panel.visible = at_max

	if not at_max:
		if prompt_label:
			prompt_label.text = "Increase box Space by %d" % gain
		if current_val_label:
			current_val_label.text = str(cur_max)
		if coin_price_label:
			coin_price_label.text = str(int(tier.get("coin_price", 0)))
		if gem_price_label:
			gem_price_label.text = str(int(tier.get("gem_price", 0)))


func _play_sfx() -> void:
	if Audio and SFX_CLICK:
		Audio.play_sfx(SFX_CLICK)


func _show_status(msg: String, is_error: bool) -> void:
	if status_banner and status_label:
		status_label.text = msg
		status_label.modulate = Color(1.0, 0.55, 0.55) if is_error else Color(1.0, 1.0, 1.0)
		status_banner.visible = true


func _on_buy_with_coins() -> void:
	_play_sfx()
	_attempt_purchase(false)


func _on_buy_with_gems() -> void:
	_play_sfx()
	_attempt_purchase(true)


func _attempt_purchase(use_gems: bool) -> void:
	var res: Dictionary = GameManager.purchase_inventory_increase(use_gems)
	if res.get("ok", false):
		var new_max: int = int(res.get("new_max", GameManager.get_max_inventory()))
		_show_status("Inventory is now %d!" % new_max, false)
		refresh_display()
		inventory_upgraded.emit(new_max)
	else:
		_show_status(str(res.get("reason", "Cannot increase inventory.")), true)


func _on_close_pressed() -> void:
	_play_sfx()
	close_modal()
