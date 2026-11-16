extends Control
class_name ChestFlowOverlay

signal closed
signal chest_opening_started(chest_key: String)
signal chest_collect_started(chest_key: String)
signal flow_finished
signal open_store_inventory_requested
signal open_store_gems_requested

const CardViewScene: PackedScene = preload("res://scenes/components/CardView.tscn")
const TEX_COIN: Texture2D = preload("res://assets/textures/ui/store/UI_Coin_Icon.png")
const TEX_GEM: Texture2D = preload("res://assets/textures/ui/store/GsGems.png")

const SFX_CLICK: AudioStream = preload("res://assets/audio/sfx/UI_Select.wav")
const SFX_BACK: AudioStream = preload("res://assets/audio/sfx/UI_Back.wav")
const SFX_RARITY_1: AudioStream = preload("res://assets/audio/sfx/Gatcha_1_New_Card.wav")
const SFX_RARITY_2: AudioStream = preload("res://assets/audio/sfx/Gatcha_2_Nice_Card.wav")
const SFX_RARITY_3: AudioStream = preload("res://assets/audio/sfx/Gatcha_3_Rare.wav")
const SFX_RARITY_4: AudioStream = preload("res://assets/audio/sfx/Gatcha_4_Very_Rare.wav")
const SFX_RARITY_5: AudioStream = preload("res://assets/audio/sfx/Gatcha_5_Algebraic_Rare.wav")

enum Stage { HIDDEN, CONFIRM, OPENING, REVEAL, CLOSING }

@onready var confirm_dimmer: ColorRect = $ConfirmDimmer
@onready var confirm_center: Control = $ConfirmCenter
@onready var confirm_frame: Control = $ConfirmCenter/Frame
@onready var title_label: Label = $ConfirmCenter/Frame/TitleBar/TitleLabel
@onready var close_btn: BaseButton = $ConfirmCenter/Frame/TitleBar/CloseBtn
@onready var prompt_label: Label = $ConfirmCenter/Frame/Body/PromptLabel
@onready var price_pill: Panel = $ConfirmCenter/Frame/Body/PricePill
@onready var currency_icon: TextureRect = $ConfirmCenter/Frame/Body/PricePill/HBox/CurrencyIcon
@onready var price_label: Label = $ConfirmCenter/Frame/Body/PricePill/HBox/PriceLabel
@onready var sub_note_label: Label = $ConfirmCenter/Frame/Body/SubNoteLabel
@onready var primary_btn: BaseButton = $ConfirmCenter/Frame/Body/Buttons/PrimaryBtn
@onready var primary_btn_label: Label = $ConfirmCenter/Frame/Body/Buttons/PrimaryBtn/Label
@onready var secondary_btn: BaseButton = $ConfirmCenter/Frame/Body/Buttons/SecondaryBtn
@onready var secondary_btn_label: Label = $ConfirmCenter/Frame/Body/Buttons/SecondaryBtn/Label

@onready var opening_hud: Control = $OpeningHud
@onready var skip_area: Button = $OpeningHud/SkipArea
@onready var hint_label: Label = $OpeningHud/HintBanner/HintLabel

@onready var reveal_panel: Control = $RevealPanel
@onready var rarity_badge: Label = $RevealPanel/VBox/RarityBadge
@onready var stars_label: Label = $RevealPanel/VBox/StarsLabel
@onready var card_pivot: Control = $RevealPanel/VBox/CardAnchor/CardPivot
@onready var card_name_label: Label = $RevealPanel/VBox/CardNameLabel
@onready var collect_btn: BaseButton = $RevealPanel/VBox/CollectBtn

@onready var flash_rect: ColorRect = $FlashRect

var _stage: Stage = Stage.HIDDEN
var _chest_key: String = "cool"
var _chest_type: String = "cool_chest"
var _confirm_action: String = "confirm" # "confirm", "full_inventory", "need_gems", "need_coins"
var _active_icon: ChestIconBase = null
var _pending_rolls: Array = []
var _anim_tween: Tween = null
var _flash_tween: Tween = null
var _reveal_tween: Tween = null
var _is_closing_confirm: bool = false


func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_cancel_pressed)
		StoreModalAnimator.attach_button_reaction(close_btn)
	if primary_btn:
		primary_btn.pressed.connect(_on_primary_pressed)
		StoreModalAnimator.attach_button_reaction(primary_btn)
	if secondary_btn:
		secondary_btn.pressed.connect(_on_secondary_pressed)
		StoreModalAnimator.attach_button_reaction(secondary_btn)
	if skip_area:
		skip_area.pressed.connect(_on_skip_opening_pressed)
	if collect_btn:
		collect_btn.pressed.connect(_on_collect_pressed)
		StoreModalAnimator.attach_button_reaction(collect_btn)


func _format_commas(value: int) -> String:
	var neg := value < 0
	var s := str(abs(value))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return "-" + out if neg else out


func _play_sfx(stream: AudioStream) -> void:
	if Audio and stream:
		Audio.play_sfx(stream)


func open_confirm(chest_key: String, chest_icon: ChestIconBase = null) -> void:
	_chest_key = "cool" if (chest_key == "cool" or chest_key == "cool_chest") else "algebraic"
	_chest_type = "cool_chest" if _chest_key == "cool" else "algebraic_chest"
	_set_active_icon(chest_icon)
	_is_closing_confirm = false
	_stage = Stage.CONFIRM

	var def: Dictionary = Database.get_chest_def(_chest_type)
	var cost: int = int(def.get("cost", 10000 if _chest_key == "cool" else 3))
	var currency: String = str(def.get("currency", "coins" if _chest_key == "cool" else "gems"))
	var display_title := "COOL CHEST" if _chest_key == "cool" else "ALGEBRAIC CHEST"
	var display_name := "Cool Chest" if _chest_key == "cool" else "Algebraic Chest"

	if title_label:
		title_label.text = display_title

	var inv_count: int = GameManager.get_total_card_count()
	var max_inv: int = GameManager.get_max_inventory()
	var cur_balance: int = GameManager.get_coins() if currency == "coins" else GameManager.get_gems()

	if inv_count >= max_inv:
		_confirm_action = "full_inventory"
		if prompt_label:
			prompt_label.text = "Your Card Box is full!\n(%d / %d)" % [inv_count, max_inv]
		if price_pill:
			price_pill.visible = false
		if sub_note_label:
			sub_note_label.text = "Visit the Store to expand?"
		if primary_btn:
			primary_btn.visible = true
		if primary_btn_label:
			primary_btn_label.text = "STORE"
		if secondary_btn:
			secondary_btn.visible = true
		if secondary_btn_label:
			secondary_btn_label.text = "CLOSE"
	elif cur_balance < cost:
		_confirm_action = "need_coins" if currency == "coins" else "need_gems"
		if price_pill:
			price_pill.visible = true
		if currency_icon:
			currency_icon.texture = TEX_COIN if currency == "coins" else TEX_GEM
		if price_label:
			price_label.text = _format_commas(cost)
		if currency == "gems":
			if prompt_label:
				prompt_label.text = "You don't have enough Gems for the %s!" % display_name
			if sub_note_label:
				sub_note_label.text = "Visit the Store to get more Gems?"
			if primary_btn:
				primary_btn.visible = true
			if primary_btn_label:
				primary_btn_label.text = "STORE"
			if secondary_btn:
				secondary_btn.visible = true
			if secondary_btn_label:
				secondary_btn_label.text = "CLOSE"
		else:
			if prompt_label:
				prompt_label.text = "You don't have enough Coins for the %s!" % display_name
			if sub_note_label:
				sub_note_label.text = "Win battles or sell cards to earn %s more Coins." % _format_commas(cost - cur_balance)
			if primary_btn:
				primary_btn.visible = false
			if secondary_btn:
				secondary_btn.visible = true
			if secondary_btn_label:
				secondary_btn_label.text = "OK"
	else:
		_confirm_action = "confirm"
		if prompt_label:
			prompt_label.text = "Open 1 %s?" % display_name
		if price_pill:
			price_pill.visible = true
		if currency_icon:
			currency_icon.texture = TEX_COIN if currency == "coins" else TEX_GEM
		if price_label:
			price_label.text = _format_commas(cost)
		if sub_note_label:
			if _chest_key == "algebraic":
				var pity: int = GameManager.get_chest_pity(_chest_type)
				sub_note_label.text = "Grants 1 rare+ card! (Pity: %d / 10)" % pity
			else:
				sub_note_label.text = "Grants 1 random card!"
		if primary_btn:
			primary_btn.visible = true
		if primary_btn_label:
			primary_btn_label.text = "YES"
		if secondary_btn:
			secondary_btn.visible = true
		if secondary_btn_label:
			secondary_btn_label.text = "NO"

	if opening_hud:
		opening_hud.visible = false
	if reveal_panel:
		reveal_panel.visible = false
	if flash_rect:
		flash_rect.visible = false
		flash_rect.color.a = 0.0
	if confirm_dimmer:
		confirm_dimmer.visible = true
	if confirm_center:
		confirm_center.visible = true
	visible = true
	_anim_tween = StoreModalAnimator.play_open(confirm_center, confirm_dimmer, confirm_frame, _anim_tween)


func close_confirm(emit_signal: bool = true) -> void:
	if _stage != Stage.CONFIRM or _is_closing_confirm:
		return
	_is_closing_confirm = true
	_anim_tween = StoreModalAnimator.play_close(confirm_center, confirm_dimmer, confirm_frame, _anim_tween, func():
		_is_closing_confirm = false
		_stage = Stage.HIDDEN
		if confirm_center:
			confirm_center.visible = false
		if confirm_dimmer:
			confirm_dimmer.visible = false
		visible = false
		if emit_signal:
			closed.emit()
	)


func start_preview_opening(chest_key: String, chest_icon: ChestIconBase, card_id: String, preview_time: float = -1.0) -> void:
	# Helper used for deterministic visual testing without mutating persistent wallet.
	_chest_key = "cool" if (chest_key == "cool" or chest_key == "cool_chest") else "algebraic"
	_chest_type = "cool_chest" if _chest_key == "cool" else "algebraic_chest"
	_set_active_icon(chest_icon)
	_pending_rolls = [{"id": card_id, "rarity": "Standard", "is_pity": false}]
	if confirm_center:
		confirm_center.visible = false
	if confirm_dimmer:
		confirm_dimmer.visible = false
	visible = true
	_stage = Stage.OPENING
	if opening_hud:
		opening_hud.visible = true
	if reveal_panel:
		reveal_panel.visible = false
	if hint_label:
		hint_label.text = "Opening %s..." % ("Cool Chest" if _chest_key == "cool" else "Algebraic Chest")
	if _active_icon:
		if preview_time >= 0.0:
			_active_icon.set_open_preview_time(preview_time)
		else:
			_active_icon.play_open()


func show_preview_reveal(card_id: String, rarity_str: String = "Gold", is_pity: bool = false) -> void:
	_pending_rolls = [{"id": card_id, "rarity": rarity_str, "is_pity": is_pity}]
	if confirm_center:
		confirm_center.visible = false
	if confirm_dimmer:
		confirm_dimmer.visible = false
	visible = true
	_show_reveal(false)


func reset_immediately() -> void:
	_kill_tweens()
	_stage = Stage.HIDDEN
	_is_closing_confirm = false
	_pending_rolls.clear()
	_clear_card_pivot()
	if confirm_dimmer:
		confirm_dimmer.visible = false
	if confirm_center:
		confirm_center.visible = false
	if opening_hud:
		opening_hud.visible = false
	if reveal_panel:
		reveal_panel.visible = false
	if flash_rect:
		flash_rect.visible = false
	visible = false


func _set_active_icon(icon: ChestIconBase) -> void:
	if _active_icon and _active_icon != icon:
		if _active_icon.card_pop.is_connected(_on_chest_card_pop):
			_active_icon.card_pop.disconnect(_on_chest_card_pop)
		if _active_icon.open_finished.is_connected(_on_chest_open_finished):
			_active_icon.open_finished.disconnect(_on_chest_open_finished)
		if _active_icon.close_finished.is_connected(_on_chest_close_finished):
			_active_icon.close_finished.disconnect(_on_chest_close_finished)
	_active_icon = icon
	if _active_icon:
		if not _active_icon.card_pop.is_connected(_on_chest_card_pop):
			_active_icon.card_pop.connect(_on_chest_card_pop)
		if not _active_icon.open_finished.is_connected(_on_chest_open_finished):
			_active_icon.open_finished.connect(_on_chest_open_finished)
		if not _active_icon.close_finished.is_connected(_on_chest_close_finished):
			_active_icon.close_finished.connect(_on_chest_close_finished)


func _on_cancel_pressed() -> void:
	_play_sfx(SFX_BACK)
	close_confirm(true)


func _on_secondary_pressed() -> void:
	_play_sfx(SFX_BACK)
	close_confirm(true)


func _on_primary_pressed() -> void:
	_play_sfx(SFX_CLICK)
	if _confirm_action == "full_inventory":
		_is_closing_confirm = true
		_anim_tween = StoreModalAnimator.play_close(confirm_center, confirm_dimmer, confirm_frame, _anim_tween, func():
			_is_closing_confirm = false
			_stage = Stage.HIDDEN
			if confirm_center:
				confirm_center.visible = false
			if confirm_dimmer:
				confirm_dimmer.visible = false
			visible = false
			open_store_inventory_requested.emit()
		)
		return
	if _confirm_action == "need_gems":
		_is_closing_confirm = true
		_anim_tween = StoreModalAnimator.play_close(confirm_center, confirm_dimmer, confirm_frame, _anim_tween, func():
			_is_closing_confirm = false
			_stage = Stage.HIDDEN
			if confirm_center:
				confirm_center.visible = false
			if confirm_dimmer:
				confirm_dimmer.visible = false
			visible = false
			open_store_gems_requested.emit()
		)
		return
	if _confirm_action != "confirm":
		close_confirm(true)
		return

	var result: Dictionary = GameManager.open_chest(_chest_type, 1)
	if not bool(result.get("ok", false)):
		open_confirm(_chest_key, _active_icon)
		return

	_pending_rolls = result.get("rolls", [])
	_stage = Stage.OPENING
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	if confirm_center:
		confirm_center.visible = false
	if confirm_dimmer:
		confirm_dimmer.visible = false
	if opening_hud:
		opening_hud.visible = true
	if hint_label:
		hint_label.text = "Tap anywhere to skip..."
	chest_opening_started.emit(_chest_key)
	if _active_icon:
		_active_icon.play_open()
	else:
		_show_reveal(true)


func _on_chest_card_pop() -> void:
	if _stage != Stage.OPENING:
		return
	if hint_label:
		hint_label.text = "Tap to reveal!"
	_trigger_flash(0.75, 0.35)


func _on_chest_open_finished() -> void:
	if _stage != Stage.OPENING:
		return
	_show_reveal(true)


func _on_skip_opening_pressed() -> void:
	if _stage == Stage.OPENING:
		_play_sfx(SFX_CLICK)
		if _active_icon:
			_active_icon.stop_audio()
			# Snap 3D chest to end of open animation so lid remains open behind card
			_active_icon.set_open_preview_time(5.99)
		_show_reveal(true)


func _show_reveal(play_jingle: bool) -> void:
	_stage = Stage.REVEAL
	if opening_hud:
		opening_hud.visible = false
	if not reveal_panel:
		return
	reveal_panel.visible = true
	_clear_card_pivot()

	var roll: Dictionary = _pending_rolls[0] if not _pending_rolls.is_empty() else {}
	var card_id: String = str(roll.get("id", ""))
	var roll_rarity: String = str(roll.get("rarity", "Standard"))
	var is_pity: bool = bool(roll.get("is_pity", false))

	var db_info: Dictionary = Database.get_card(card_id)
	var card_info: Dictionary
	if db_info.is_empty():
		card_info = {
			"id": card_id,
			"name": card_id if card_id != "" else "Mystery Card",
			"cost": 1,
			"desc": "",
			"type": "CREATURE",
			"atk": 1,
			"def": 1,
			"rarity": 1,
			"quality": roll_rarity,
		}
	else:
		card_info = db_info.duplicate()
		if roll_rarity != "" and str(card_info.get("quality", "")).is_empty():
			card_info["quality"] = roll_rarity
		elif roll_rarity.to_lower() == "gold" or roll_rarity.to_lower() == "obsidian":
			card_info["quality"] = roll_rarity

	var star_count: int = clampi(int(card_info.get("rarity", 1)), 1, 5)
	var is_gold: bool = roll_rarity.to_lower() == "gold" or str(card_info.get("quality", "")).to_lower() == "gold"
	if is_gold and star_count < 4:
		star_count = 4
	if is_pity and star_count < 5:
		star_count = 5

	if stars_label:
		var stars := ""
		for i in range(star_count):
			stars += "★"
		stars_label.text = stars

	if rarity_badge:
		if is_pity:
			rarity_badge.text = "ALGEBRAIC PITY!"
			rarity_badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.25))
		elif is_gold:
			rarity_badge.text = "GOLD CARD!"
			rarity_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
		elif star_count >= 5:
			rarity_badge.text = "ALGEBRAIC RARE!"
			rarity_badge.add_theme_color_override("font_color", Color(1.0, 0.82, 0.15))
		elif star_count == 4:
			rarity_badge.text = "VERY RARE!"
			rarity_badge.add_theme_color_override("font_color", Color(0.76, 0.45, 1.0))
		elif star_count == 3:
			rarity_badge.text = "RARE!"
			rarity_badge.add_theme_color_override("font_color", Color(0.35, 0.8, 1.0))
		elif star_count == 2:
			rarity_badge.text = "NICE CARD!"
			rarity_badge.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
		else:
			rarity_badge.text = "NEW CARD!"
			rarity_badge.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

	if card_name_label:
		var c_faction := str(card_info.get("faction", "")).capitalize()
		var c_type := str(card_info.get("type", "CREATURE")).capitalize()
		var sub := ("%s · %s" % [c_faction, c_type]) if c_faction != "" else c_type
		card_name_label.text = "%s — Added to Card Box!" % sub

	if card_pivot and CardViewScene:
		var cv = CardViewScene.instantiate()
		card_pivot.add_child(cv)
		if cv.has_method("render_card"):
			cv.render_card(card_info)
		card_pivot.scale = Vector2(0.2, 0.2)
		if _reveal_tween and _reveal_tween.is_valid():
			_reveal_tween.kill()
		_reveal_tween = create_tween()
		_reveal_tween.tween_property(card_pivot, "scale", Vector2(1.9, 1.9), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if play_jingle:
		_trigger_flash(0.85, 0.28)
		match star_count:
			1: _play_sfx(SFX_RARITY_1)
			2: _play_sfx(SFX_RARITY_2)
			3: _play_sfx(SFX_RARITY_3)
			4: _play_sfx(SFX_RARITY_4)
			_: _play_sfx(SFX_RARITY_5)


func _on_collect_pressed() -> void:
	if _stage != Stage.REVEAL:
		return
	_play_sfx(SFX_CLICK)
	_stage = Stage.CLOSING
	if reveal_panel:
		reveal_panel.visible = false
	_clear_card_pivot()
	chest_collect_started.emit(_chest_key)
	if _active_icon:
		_active_icon.play_close()
	else:
		_finish_flow()


func _on_chest_close_finished() -> void:
	if _stage == Stage.CLOSING:
		_finish_flow()


func _finish_flow() -> void:
	_stage = Stage.HIDDEN
	visible = false
	flow_finished.emit()


func _clear_card_pivot() -> void:
	if not card_pivot:
		return
	for child in card_pivot.get_children():
		child.queue_free()


func _trigger_flash(peak_alpha: float, fade_sec: float) -> void:
	if not flash_rect:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	flash_rect.visible = true
	flash_rect.color = Color(1, 1, 1, peak_alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_rect, "color:a", 0.0, fade_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_callback(func():
		if flash_rect:
			flash_rect.visible = false
	)


func _kill_tweens() -> void:
	for tw in [_anim_tween, _flash_tween, _reveal_tween]:
		if tw and tw.is_valid():
			tw.kill()
	_anim_tween = null
	_flash_tween = null
	_reveal_tween = null
