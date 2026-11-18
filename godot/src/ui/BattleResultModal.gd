class_name BattleResultModal
extends Control

## Authentic 4-Stage Card Wars Post-Match Result & Loot Flow:
##   Persistent top PlayerStatsBar (Hero portrait/XP/Stamina/Trophies + Inventory/Gems/Coins)
##   Stage 1 (optional): "You leveled up [Hero]"
##   Stage 2: "Quest Rewards" / "Defeat!" (Frame_Victory/Frame_Defeat + Win_Banner2 + XP + Stars + Loot/OK/Retry)
##   Stage 3 (if loot_cards > 0): 3D Chest Loot Floor ("TAP chests to unlock!")
##            -> ResultLootChest open + Card Flap -> CardView Reveal over chest -> fly to Inventory
##   Stage 4: "JAKE'S PRO TIP" (FloopPanel_BG) + green "OK" button

signal continue_pressed()
signal retry_pressed()

const Arena3DScript = preload("res://src/battle/BattleArena3D.gd")
const CardViewScene: PackedScene = preload("res://scenes/components/CardView.tscn")

const FONT_MAIN: FontFile = preload("res://assets/fonts/KBPlanetEarth.ttf")
const TEX_POPUP_BLUE: Texture2D = preload("res://assets/textures/battle/hud/PopUpSprite_2.png")
const TEX_FRAME_VICTORY: Texture2D = preload("res://assets/textures/battle/hud/Frame_Victory.png")
const TEX_FRAME_DEFEAT: Texture2D = preload("res://assets/textures/battle/hud/Frame_Defeat.png")
const TEX_FRAME_INDENT: Texture2D = preload("res://assets/textures/battle/hud/Frame_Indent.png")
const TEX_CW_GREY: Texture2D = preload("res://assets/textures/battle/hud/CW_Grey.png")
const TEX_CW_WHITE: Texture2D = preload("res://assets/textures/battle/hud/CW_White.png")
const TEX_FLOOP_BG: Texture2D = preload("res://assets/textures/battle/hud/FloopPanel_BG.png")
const TEX_WIN_BANNER: Texture2D = preload("res://assets/textures/battle/banners/Win_Banner2.png")
const TEX_LOSE_BANNER: Texture2D = preload("res://assets/textures/battle/banners/LoseBanner_Straight.png")
const TEX_BTN_GREEN: Texture2D = preload("res://assets/textures/battle/hud/uiButtonGreen.png")
const TEX_BTN_BLUE: Texture2D = preload("res://assets/textures/battle/hud/uiButtonBlue.png")
const TEX_COIN_ICON: Texture2D = preload("res://assets/textures/battle/hud/UI_Coin_Icon.png")
const TEX_TRAY_CHEST: Texture2D = preload("res://assets/textures/battle/hud/Tray_Chest.png")
const TEX_STAR: Texture2D = preload("res://assets/textures/battle/FX_QuestStar_PNG.png")
const TEX_XP_BAR: Texture2D = preload("res://assets/textures/battle/hud/PlayerData_XPBar.png")
const TEX_CARD_BACK: Texture2D = preload("res://assets/textures/battle/banners/card_back_cw.png")
const TEX_HUD_PLAYER: Texture2D = preload("res://assets/textures/battle/hud/HUD_PlayerInfo.png")
const TEX_HUD_TROPHY: Texture2D = preload("res://assets/textures/battle/hud/TrophyBar.png")
const TEX_TROPHY_ICON: Texture2D = preload("res://assets/textures/battle/hud/Trophy.png")
const TEX_HUD_INV: Texture2D = preload("res://assets/textures/battle/hud/HUD_Inventory.png")
const TEX_HUD_GEMS: Texture2D = preload("res://assets/textures/battle/hud/HUD_Gems.png")
const TEX_HUD_COINS: Texture2D = preload("res://assets/textures/battle/hud/HUD_Coins.png")

enum Stage { HIDDEN, LEVEL_UP, QUEST_REWARDS, CHEST_FLOOR, CARD_REVEAL, PRO_TIP }

var _stage: Stage = Stage.HIDDEN
var _arena: Arena3DScript = null
var _victory: bool = true
var _quest_id: String = ""
var _rewards: Dictionary = {}
var _audit_report: Array = []
var _loot_cards: Array[String] = []
var _chests_opened: int = 0
var _total_chests: int = 0
var _chest_busy: bool = false
var _inv_count_displayed: int = 0

var _dimmer: ColorRect = null

# Persistent Top Player Stats Bar
var _stats_bar: Control = null
var _sb_portrait: TextureRect = null
var _sb_name_lbl: Label = null
var _sb_lvl_lbl: Label = null
var _sb_xp_bar: ProgressBar = null
var _sb_xp_lbl: Label = null
var _sb_stamina_lbl: Label = null
var _sb_timer_lbl: Label = null
var _sb_trophy_lbl: Label = null
var _sb_inv_box: TextureRect = null
var _sb_inv_lbl: Label = null
var _sb_gems_lbl: Label = null
var _sb_coins_lbl: Label = null

# Stage 1: Level Up
var _levelup_root: Control = null
var _lu_title: Label = null
var _lu_portrait: TextureRect = null
var _lu_level_lbl: Label = null
var _lu_hp_lbl: Label = null
var _lu_deck_lbl: Label = null

# Stage 2: Quest Rewards
var _rewards_root: Control = null
var _rw_frame_border: NinePatchRect = null
var _rw_ribbon_tex: TextureRect = null
var _rw_ribbon_lbl: Label = null
var _rw_quest_lbl: Label = null
var _rw_coins_val: Label = null
var _rw_xp_val: Label = null
var _rw_xp_bar: ProgressBar = null
var _rw_xp_next_val: Label = null
var _rw_stars: Array[TextureRect] = []
var _rw_stars_row: Control = null
var _rw_loot_btn: Button = null
var _rw_loot_btn_icon: TextureRect = null
var _rw_loot_btn_lbl: Label = null
var _rw_retry_btn: Button = null

# Stage 3: 3D Chest Floor + Reveal
var _chest_hud: Control = null
var _chest_prompt_lbl: Label = null
var _reveal_root: Control = null
var _rev_card_back: TextureRect = null
var _rev_card_holder: Control = null
var _rev_tap_lbl: Label = null
var _rev_ready_to_close: bool = false

# Stage 4: Pro Tip
var _tip_root: Control = null
var _tip_header_lbl: Label = null
var _tip_body_lbl: Label = null
var _tip_ok_btn: Button = null

# Legacy compatibility fields (preserved for existing test harnesses)
var stars_earned_count: int = 0
var title_label: Label = null
var coins_label: Label = null
var xp_label: Label = null
var continue_btn: Button = null
var levelup_banner: Label = null
var objectives_section: Control = null
var objectives_list: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func bind_arena(arena: Arena3DScript) -> void:
	_arena = arena


func display_result(victory: bool, quest_id: String, _match_stats: Dictionary, rewards: Dictionary, audit_report: Array = []) -> void:
	visible = true
	_victory = victory
	_quest_id = quest_id
	_rewards = rewards.duplicate(true)
	_audit_report = audit_report.duplicate(true)
	_loot_cards.clear()
	for cid in rewards.get("cards", []):
		_loot_cards.append(str(cid))
	_chests_opened = 0
	_total_chests = mini(4, _loot_cards.size())
	_chest_busy = false

	var base_inv: int = GameManager.player_inventory_cards.size() if GameManager else 0
	_inv_count_displayed = maxi(0, base_inv - (_total_chests if victory else 0))

	stars_earned_count = 0
	for item in _audit_report:
		if bool(item.get("passed", false)):
			stars_earned_count += 1
	if title_label:
		title_label.text = "VICTORY!" if victory else "DEFEAT!"
	if coins_label:
		coins_label.text = "+%d Coins" % int(rewards.get("coins", 0))
	if xp_label:
		xp_label.text = "+%d XP" % int(rewards.get("xp", 0))
	if levelup_banner:
		levelup_banner.visible = bool(rewards.get("leveled_up", false))
	if objectives_section and objectives_list:
		objectives_section.visible = not _audit_report.is_empty()
		for c in objectives_list.get_children():
			c.queue_free()
		for _a in _audit_report:
			objectives_list.add_child(Label.new())
	if continue_btn:
		var q_info: Dictionary = Database.get_quest(quest_id) if (quest_id != "" and Database) else {}
		var is_dun := str(q_info.get("type", "")) == "dungeon"
		continue_btn.text = "Return to Dungeons" if is_dun else ("Continue to Map" if quest_id != "" else "Return to Menu")

	_hide_all_stages()
	_stats_bar.visible = true
	_update_player_stats_bar()

	if _arena:
		_arena.clear_all_entities()
		_arena.focus_loot_floor(0.55)

	if Audio and ResourceLoader.exists("res://assets/audio/sfx/FX_BattleEnd_PanelTween.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/FX_BattleEnd_PanelTween.wav"), -4.0)

	if victory and bool(rewards.get("leveled_up", false)):
		_enter_level_up()
	else:
		_enter_quest_rewards()


func _hide_all_stages() -> void:
	_dimmer.visible = false
	_levelup_root.visible = false
	_rewards_root.visible = false
	_chest_hud.visible = false
	_reveal_root.visible = false
	_tip_root.visible = false


func _update_player_stats_bar() -> void:
	if _stats_bar == null:
		return
	var hero := GameManager.player_hero_name if GameManager else "Jake"
	var leader := Database.get_leader(hero) if Database else {}
	var hero_disp := str(leader.get("name", hero))
	var lvl := GameManager.get_hero_level(hero) if GameManager else 2
	var tracker := GameManager.get_hero_tracker(hero) if GameManager else null
	var cur_xp := tracker.current_xp if tracker else 215
	var next_xp := tracker.get_xp_for_next_level() if (tracker and tracker.has_method("get_xp_for_next_level")) else 595
	var stamina := GameManager.get_stamina() if GameManager else 5
	var max_st := GameManager.get_max_stamina() if GameManager else 5
	var coins := GameManager.get_coins() if GameManager else 0
	var gems := GameManager.get_gems() if GameManager else 0
	var max_inv := GameManager.max_inventory if GameManager else 50
	var trophies := GameManager.elfisto_consecutive_wins if GameManager else 0

	var p_path := "res://assets/textures/leaders/%s.png" % hero
	if not ResourceLoader.exists(p_path):
		p_path = "res://assets/textures/leaders/Jake.png"
	_sb_portrait.texture = load(p_path)
	_sb_name_lbl.text = hero_disp
	_sb_lvl_lbl.text = "Lvl. %d" % lvl
	_sb_xp_bar.max_value = maxf(1.0, float(next_xp))
	_sb_xp_bar.value = float(cur_xp)
	_sb_xp_lbl.text = "%d / %d" % [cur_xp, next_xp]
	_sb_stamina_lbl.text = "%d/%d" % [stamina, max_st]
	_sb_timer_lbl.text = "MAX" if stamina >= max_st else "5:00"
	_sb_trophy_lbl.text = str(trophies)
	_sb_inv_lbl.text = "%d/%d" % [_inv_count_displayed, max_inv]
	_sb_gems_lbl.text = str(gems)
	_sb_coins_lbl.text = str(coins)


func _enter_level_up() -> void:
	_stage = Stage.LEVEL_UP
	_hide_all_stages()
	_dimmer.visible = true
	_dimmer.color = Color(0.0, 0.0, 0.0, 0.28)
	_stats_bar.visible = true
	_levelup_root.visible = true

	var hero := GameManager.player_hero_name if GameManager else "Jake"
	var leader := Database.get_leader(hero) if Database else {}
	var hero_disp := str(leader.get("name", hero))
	var lvl := GameManager.get_hero_level(hero) if GameManager else 2
	var max_hp := GameManager.get_hero_max_hp(hero) if GameManager else 20
	var deck_max := GameManager.get_hero_deck_max_size(hero) if GameManager else 16

	_lu_title.text = "You leveled up %s" % hero_disp
	var tex_path := "res://assets/textures/leaders/%s.png" % hero
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/textures/leaders/Jake.png"
	_lu_portrait.texture = load(tex_path)
	_lu_level_lbl.text = "%s is now level %d" % [hero_disp, lvl]
	_lu_hp_lbl.text = "Max HP is now   %d" % max_hp
	_lu_deck_lbl.text = "Max Deck Size is now   %d" % deck_max

	if Audio and ResourceLoader.exists("res://assets/audio/sfx/FX_BattleEnd_LevelUp.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/FX_BattleEnd_LevelUp.wav"), -3.0)

	_levelup_root.scale = Vector2(0.86, 0.86)
	_levelup_root.pivot_offset = _levelup_root.size * 0.5
	create_tween().tween_property(_levelup_root, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _enter_quest_rewards() -> void:
	_stage = Stage.QUEST_REWARDS
	_hide_all_stages()
	_dimmer.visible = true
	_dimmer.color = Color(0.0, 0.0, 0.0, 0.22)
	_stats_bar.visible = true
	_rewards_root.visible = true
	_update_player_stats_bar()

	_rw_frame_border.texture = TEX_FRAME_VICTORY if _victory else TEX_FRAME_DEFEAT
	_rw_ribbon_tex.texture = TEX_WIN_BANNER if _victory else TEX_LOSE_BANNER
	_rw_ribbon_lbl.text = "Quest Rewards" if _victory else "Defeat!"
	if _victory:
		_rw_ribbon_lbl.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04))
		_rw_ribbon_lbl.add_theme_constant_override("outline_size", 0)
	else:
		_rw_ribbon_lbl.add_theme_color_override("font_color", Color.WHITE)
		_rw_ribbon_lbl.add_theme_constant_override("outline_size", 5)

	var q_data := Database.get_quest(_quest_id) if (_quest_id != "" and Database) else {}
	var q_name := str(q_data.get("name", _quest_id if _quest_id != "" else "Skirmish"))
	if q_name.begins_with("!!"):
		q_name = _quest_id.replace("_0", " ").replace("_", " ")
	if q_name.is_valid_int():
		q_name = "Quest %s" % q_name
	_rw_quest_lbl.text = q_name

	var coins := int(_rewards.get("coins", 0))
	var xp := int(_rewards.get("xp", 0))
	_rw_coins_val.text = str(coins)
	_rw_xp_val.text = str(xp)

	var hero := GameManager.player_hero_name if GameManager else "Jake"
	var tracker := GameManager.get_hero_tracker(hero) if GameManager else null
	var cur_xp := tracker.current_xp if tracker else 100
	var next_xp := tracker.get_xp_for_next_level() if (tracker and tracker.has_method("get_xp_for_next_level")) else 500
	var rem_xp := maxi(0, next_xp - cur_xp)
	_rw_xp_next_val.text = str(rem_xp)
	_rw_xp_bar.max_value = maxf(1.0, float(next_xp))
	var xp_start := maxf(0.0, float(cur_xp - xp))
	var xp_end := maxf(float(xp), float(cur_xp))
	_rw_xp_bar.value = xp_start
	var xp_tw := create_tween()
	xp_tw.tween_property(_rw_xp_bar, "value", xp_end, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if xp > 0 and Audio and ResourceLoader.exists("res://assets/audio/sfx/FX_BattleEnd_XPGain.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/FX_BattleEnd_XPGain.wav"), -4.0)

	var stars := 0
	for item in _audit_report:
		if bool(item.get("passed", false)):
			stars += 1
	_rw_stars_row.visible = _victory
	for i in range(3):
		_rw_stars[i].modulate = Color(1.0, 0.94, 0.30, 1.0) if (i < stars and _victory) else Color(0.28, 0.22, 0.16, 0.45)

	_rw_retry_btn.visible = not _victory
	if _total_chests > 0 and _victory:
		_rw_loot_btn_icon.visible = true
		_rw_loot_btn_lbl.text = "x %d   Loot" % _total_chests
	else:
		_rw_loot_btn_icon.visible = false
		_rw_loot_btn_lbl.text = "OK"

	_rewards_root.scale = Vector2(0.86, 0.86)
	_rewards_root.pivot_offset = _rewards_root.size * 0.5
	create_tween().tween_property(_rewards_root, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_rewards_action_pressed() -> void:
	if Audio and ResourceLoader.exists("res://assets/audio/sfx/UI_Select.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/UI_Select.wav"), -4.0)
	if _victory and _total_chests > 0 and _arena != null:
		_enter_chest_floor()
	else:
		_enter_pro_tip()


func _enter_chest_floor() -> void:
	_stage = Stage.CHEST_FLOOR
	_hide_all_stages()
	_stats_bar.visible = true
	_chest_hud.visible = true
	_chest_hud.modulate.a = 1.0
	_chest_prompt_lbl.text = "TAP chests to unlock!"
	_arena.focus_loot_floor(0.45)
	_total_chests = _arena.spawn_loot_chests(_loot_cards)
	if _total_chests <= 0:
		_enter_pro_tip()


func _open_chest_at(idx: int) -> void:
	if _chest_busy or idx < 0 or idx >= _loot_cards.size():
		return
	_chest_busy = true
	_chest_hud.modulate.a = 0.58
	_arena.focus_loot_floor(0.25)
	var chest := _arena.open_loot_chest(idx)
	if Audio and ResourceLoader.exists("res://assets/audio/sfx/FX_LootDrop_ChestOpen_LootAfterBattle.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/FX_LootDrop_ChestOpen_LootAfterBattle.wav"), -3.0)
	if chest:
		await get_tree().create_timer(0.55).timeout
	else:
		await get_tree().create_timer(0.35).timeout
	await _play_card_flip_and_reveal(_loot_cards[idx], idx)


func _play_card_flip_and_reveal(card_id: String, chest_idx: int = 0) -> void:
	_stage = Stage.CARD_REVEAL
	_reveal_root.visible = true
	_rev_ready_to_close = false
	_rev_tap_lbl.visible = false
	for c in _rev_card_holder.get_children():
		c.queue_free()

	var spos := _arena.get_chest_screen_pos(chest_idx, size) if _arena else size * 0.5
	spos = Vector2(clampf(spos.x, 120.0, size.x - 120.0), clampf(spos.y - 26.0, 175.0, size.y - 170.0))

	_rev_card_back.visible = true
	_rev_card_back.size = Vector2(126, 176)
	_rev_card_back.position = spos - Vector2(63, 88)
	_rev_card_back.pivot_offset = _rev_card_back.size * 0.5
	_rev_card_back.scale = Vector2(0.18, 0.18)
	_rev_card_back.rotation_degrees = -8.0
	_rev_card_holder.visible = false

	if Audio and ResourceLoader.exists("res://assets/audio/sfx/FX_BattleEnd_CardFlap.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/FX_BattleEnd_CardFlap.wav"), -3.0)

	var spin_tw := create_tween()
	spin_tw.set_parallel(true)
	spin_tw.tween_property(_rev_card_back, "scale", Vector2(1.0, 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	spin_tw.tween_property(_rev_card_back, "rotation_degrees", 354.0, 0.28)
	spin_tw.set_parallel(false)
	spin_tw.tween_property(_rev_card_back, "scale:x", 0.02, 0.10)
	await spin_tw.finished

	_rev_card_back.visible = false
	_rev_card_back.rotation_degrees = 0.0

	var c_data := Database.get_card(card_id) if Database else {}
	_rev_card_holder.visible = true
	_rev_card_holder.size = Vector2(160, 224)
	_rev_card_holder.position = spos - Vector2(80, 112)
	_rev_card_holder.pivot_offset = Vector2(80, 112)
	_rev_card_holder.rotation_degrees = -4.0

	var cv := CardViewScene.instantiate()
	_rev_card_holder.add_child(cv)
	if not c_data.is_empty() and cv.has_method("render_card"):
		cv.render_card(c_data)
	cv.scale = Vector2(0.84, 0.84)

	_rev_card_holder.scale = Vector2(0.05, 1.02)
	var rev_tw := create_tween()
	rev_tw.tween_property(_rev_card_holder, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if Audio and ResourceLoader.exists("res://assets/audio/sfx/FX_BattleEnd_CardReveal.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/FX_BattleEnd_CardReveal.wav"), -3.0)
	await rev_tw.finished

	_rev_tap_lbl.visible = true
	_rev_ready_to_close = true
	_chests_opened += 1


func _finish_card_reveal() -> void:
	_rev_ready_to_close = false
	_rev_tap_lbl.visible = false

	# Fly the revealed card into the top-right Inventory box
	if _rev_card_holder.visible and _sb_inv_box != null:
		var dest := _sb_inv_box.global_position + _sb_inv_box.size * 0.5 - Vector2(80, 112)
		var fly_tw := create_tween()
		fly_tw.set_parallel(true)
		fly_tw.tween_property(_rev_card_holder, "position", dest, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly_tw.tween_property(_rev_card_holder, "scale", Vector2(0.18, 0.18), 0.28)
		fly_tw.tween_property(_rev_card_holder, "modulate:a", 0.2, 0.28)
		await fly_tw.finished

	_rev_card_holder.modulate.a = 1.0
	_reveal_root.visible = false
	_chest_busy = false

	_inv_count_displayed += 1
	var max_inv := GameManager.max_inventory if GameManager else 50
	_sb_inv_lbl.text = "%d/%d" % [_inv_count_displayed, max_inv]

	if _chests_opened >= _total_chests:
		_enter_pro_tip()
	else:
		_stage = Stage.CHEST_FLOOR
		_chest_hud.visible = true
		_chest_hud.modulate.a = 1.0
		_arena.focus_loot_floor(0.35)


func _enter_pro_tip() -> void:
	_stage = Stage.PRO_TIP
	_hide_all_stages()
	_stats_bar.visible = true
	if _arena:
		_arena.clear_loot_chests()
		_arena.focus_loot_floor(0.45)
	_tip_header_lbl.text = Database.get_battle_tip_header() if Database else "JAKE'S PRO TIP"
	_tip_body_lbl.text = Database.get_random_battle_tip() if Database else "Homies help homies, so tell your homies about Card Wars."
	_tip_root.visible = true
	_tip_root.modulate.a = 0.0
	create_tween().tween_property(_tip_root, "modulate:a", 1.0, 0.25)


func _on_tip_ok_pressed() -> void:
	if Audio and ResourceLoader.exists("res://assets/audio/sfx/UI_Select.wav"):
		Audio.play_sfx(load("res://assets/audio/sfx/UI_Select.wav"), -4.0)
	if _arena:
		_arena.clear_loot_chests()
		_arena.set_board_postmatch_green(false)
	visible = false
	_stage = Stage.HIDDEN
	continue_pressed.emit()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if _stage == Stage.LEVEL_UP:
			_enter_quest_rewards()
			accept_event()
		elif _stage == Stage.CHEST_FLOOR and not _chest_busy and _arena != null:
			var idx := _arena.pick_chest_at_screen_pos(mb.position, size)
			if idx >= 0:
				_open_chest_at(idx)
				accept_event()
		elif _stage == Stage.CARD_REVEAL and _rev_ready_to_close:
			_finish_card_reveal()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		if _stage == Stage.LEVEL_UP:
			_enter_quest_rewards()
			get_viewport().set_input_as_handled()
		elif _stage == Stage.CARD_REVEAL and _rev_ready_to_close:
			_finish_card_reveal()
			get_viewport().set_input_as_handled()
		elif _stage == Stage.PRO_TIP:
			_on_tip_ok_pressed()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_dimmer = ColorRect.new()
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.color = Color(0, 0, 0, 0.24)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dimmer)

	_build_player_stats_bar()

	# --- STAGE 1: LEVEL UP ---
	_levelup_root = Control.new()
	_levelup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_levelup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_levelup_root)

	var lu_banner := _make_floop_panel(Vector2(680, 96))
	lu_banner.anchor_top = 0.0
	lu_banner.anchor_bottom = 0.0
	lu_banner.offset_top = 86
	lu_banner.offset_bottom = 182
	_levelup_root.add_child(lu_banner)

	var lu_desc := _make_label("Your Hero Card leveled up! This means your Hero Health has increased and your Deck Size is increased so you can put more cards in it!", 17, Color.WHITE)
	lu_desc.set_anchors_preset(Control.PRESET_FULL_RECT)
	lu_desc.offset_left = 18
	lu_desc.offset_right = -18
	lu_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lu_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lu_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lu_banner.add_child(lu_desc)

	var lu_holder := _make_slate_victory_frame(Vector2(570, 420), true)
	lu_holder["root"].position.y += 46
	_levelup_root.add_child(lu_holder["root"])
	var lu_inner: Control = lu_holder["inner"]

	var lu_v := VBoxContainer.new()
	lu_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	lu_v.offset_left = 26
	lu_v.offset_right = -26
	lu_v.offset_top = 24
	lu_v.offset_bottom = -20
	lu_v.add_theme_constant_override("separation", 10)
	lu_v.alignment = BoxContainer.ALIGNMENT_CENTER
	lu_inner.add_child(lu_v)

	_lu_title = _make_label("You leveled up Jake", 28, Color.WHITE)
	_lu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lu_v.add_child(_lu_title)

	var port_center := CenterContainer.new()
	lu_v.add_child(port_center)
	var card_bg := PanelContainer.new()
	var c_sb := StyleBoxTexture.new()
	c_sb.texture = TEX_FRAME_INDENT
	c_sb.texture_margin_left = 6
	c_sb.texture_margin_top = 6
	c_sb.texture_margin_right = 6
	c_sb.texture_margin_bottom = 6
	card_bg.add_theme_stylebox_override("panel", c_sb)
	port_center.add_child(card_bg)

	_lu_portrait = TextureRect.new()
	_lu_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lu_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_lu_portrait.custom_minimum_size = Vector2(114, 140)
	card_bg.add_child(_lu_portrait)

	_lu_level_lbl = _make_label("Jake is now level 2", 20, Color.WHITE)
	_lu_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lu_v.add_child(_lu_level_lbl)
	_lu_hp_lbl = _make_label("Max HP is now   20", 20, Color.WHITE)
	_lu_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lu_v.add_child(_lu_hp_lbl)
	_lu_deck_lbl = _make_label("Max Deck Size is now   16", 20, Color.WHITE)
	_lu_deck_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lu_v.add_child(_lu_deck_lbl)

	var lu_tap := _make_label("Tap anywhere to continue", 14, Color(0.75, 0.90, 1.0))
	lu_tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lu_v.add_child(lu_tap)

	# --- STAGE 2: QUEST REWARDS ---
	_rewards_root = Control.new()
	_rewards_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rewards_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rewards_root)

	var rw_holder := _make_slate_victory_frame(Vector2(630, 480), true)
	rw_holder["root"].position.y += 40
	_rewards_root.add_child(rw_holder["root"])
	_rw_frame_border = rw_holder["border"]
	var rw_inner: Control = rw_holder["inner"]

	var rw_v := VBoxContainer.new()
	rw_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	rw_v.offset_left = 36
	rw_v.offset_right = -36
	rw_v.offset_top = 34
	rw_v.offset_bottom = -16
	rw_v.add_theme_constant_override("separation", 10)
	rw_inner.add_child(rw_v)

	_rw_quest_lbl = _make_label("Quest 1", 28, Color.WHITE)
	_rw_quest_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rw_v.add_child(_rw_quest_lbl)

	# Coins Row with CW_Grey subtle row backing
	var c_band := _make_grey_row_panel(44)
	rw_v.add_child(c_band)
	var c_row := HBoxContainer.new()
	c_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	c_row.offset_left = 10
	c_row.offset_right = -10
	c_row.add_theme_constant_override("separation", 10)
	c_band.add_child(c_row)
	var c_ic := TextureRect.new()
	c_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c_ic.custom_minimum_size = Vector2(36, 36)
	c_ic.texture = TEX_COIN_ICON
	c_row.add_child(c_ic)
	var c_lbl := _make_label("Coins Earned", 22, Color.WHITE)
	c_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c_row.add_child(c_lbl)
	_rw_coins_val = _make_label("0", 24, Color(0.98, 0.88, 0.22))
	_rw_coins_val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c_row.add_child(_rw_coins_val)

	# XP Row + XP Bar + XP to Next Level inside subtle dark band
	var xp_band := _make_grey_row_panel(106)
	rw_v.add_child(xp_band)
	var xp_vbox := VBoxContainer.new()
	xp_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_vbox.offset_left = 10
	xp_vbox.offset_right = -10
	xp_vbox.offset_top = 4
	xp_vbox.offset_bottom = -4
	xp_vbox.add_theme_constant_override("separation", 6)
	xp_band.add_child(xp_vbox)

	var x_row := HBoxContainer.new()
	x_row.add_theme_constant_override("separation", 10)
	var xp_tag := _make_label("XP", 24, Color(0.75, 0.84, 0.90))
	xp_tag.custom_minimum_size = Vector2(36, 0)
	xp_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x_row.add_child(xp_tag)
	var x_lbl := _make_label("Earned", 22, Color.WHITE)
	x_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	x_row.add_child(x_lbl)
	_rw_xp_val = _make_label("0", 24, Color(0.98, 0.88, 0.22))
	x_row.add_child(_rw_xp_val)
	xp_vbox.add_child(x_row)

	_rw_xp_bar = ProgressBar.new()
	_rw_xp_bar.custom_minimum_size = Vector2(0, 16)
	_rw_xp_bar.show_percentage = false
	var xp_bg := StyleBoxTexture.new()
	xp_bg.texture = TEX_CW_GREY
	xp_bg.modulate_color = Color(0.08, 0.11, 0.13, 0.95)
	_rw_xp_bar.add_theme_stylebox_override("background", xp_bg)
	var xp_fill := StyleBoxTexture.new()
	xp_fill.texture = TEX_XP_BAR
	xp_fill.texture_margin_left = 4
	xp_fill.texture_margin_right = 4
	_rw_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_vbox.add_child(_rw_xp_bar)

	var nx_row := HBoxContainer.new()
	var nx_lbl := _make_label("XP to next level", 20, Color.WHITE)
	nx_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nx_row.add_child(nx_lbl)
	_rw_xp_next_val = _make_label("0", 22, Color(0.98, 0.88, 0.22))
	nx_row.add_child(_rw_xp_next_val)
	xp_vbox.add_child(nx_row)

	_rw_stars_row = VBoxContainer.new()
	_rw_stars_row.add_theme_constant_override("separation", 6)
	var st_title := _make_label("Quest Star Awarded!", 20, Color.WHITE)
	st_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rw_stars_row.add_child(st_title)

	var st_h := HBoxContainer.new()
	st_h.alignment = BoxContainer.ALIGNMENT_CENTER
	st_h.add_theme_constant_override("separation", 24)
	_rw_stars.clear()
	for _s in range(3):
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(54, 54)
		tr.texture = TEX_STAR
		st_h.add_child(tr)
		_rw_stars.append(tr)
	_rw_stars_row.add_child(st_h)
	rw_v.add_child(_rw_stars_row)

	var btn_h := HBoxContainer.new()
	btn_h.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_h.add_theme_constant_override("separation", 18)
	rw_v.add_child(btn_h)

	_rw_retry_btn = _make_btn("Retry", TEX_BTN_BLUE, Vector2(180, 68))
	_rw_retry_btn.pressed.connect(func():
		visible = false
		retry_pressed.emit()
	)
	btn_h.add_child(_rw_retry_btn)

	_rw_loot_btn = _make_btn("", TEX_BTN_GREEN, Vector2(310, 78))
	_rw_loot_btn.pressed.connect(_on_rewards_action_pressed)
	var l_h := HBoxContainer.new()
	l_h.set_anchors_preset(Control.PRESET_FULL_RECT)
	l_h.alignment = BoxContainer.ALIGNMENT_CENTER
	l_h.add_theme_constant_override("separation", 10)
	l_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rw_loot_btn.add_child(l_h)
	_rw_loot_btn_icon = TextureRect.new()
	_rw_loot_btn_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rw_loot_btn_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rw_loot_btn_icon.custom_minimum_size = Vector2(46, 42)
	_rw_loot_btn_icon.texture = TEX_TRAY_CHEST
	_rw_loot_btn_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l_h.add_child(_rw_loot_btn_icon)
	_rw_loot_btn_lbl = _make_label("x 1   Loot", 28, Color.WHITE)
	l_h.add_child(_rw_loot_btn_lbl)
	btn_h.add_child(_rw_loot_btn)

	# Ribbon header overlapping top of Quest Rewards frame (Win_Banner2 / LoseBanner_Straight)
	_rw_ribbon_tex = TextureRect.new()
	_rw_ribbon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rw_ribbon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rw_ribbon_tex.texture = TEX_WIN_BANNER
	_rw_ribbon_tex.anchor_left = 0.5
	_rw_ribbon_tex.anchor_right = 0.5
	_rw_ribbon_tex.anchor_top = 0.5
	_rw_ribbon_tex.anchor_bottom = 0.5
	_rw_ribbon_tex.offset_left = -255
	_rw_ribbon_tex.offset_right = 255
	_rw_ribbon_tex.offset_top = -272
	_rw_ribbon_tex.offset_bottom = -138
	_rw_ribbon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rewards_root.add_child(_rw_ribbon_tex)

	_rw_ribbon_lbl = Label.new()
	_rw_ribbon_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rw_ribbon_lbl.offset_bottom = -22
	_rw_ribbon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rw_ribbon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rw_ribbon_lbl.add_theme_font_override("font", FONT_MAIN)
	_rw_ribbon_lbl.add_theme_font_size_override("font_size", 26)
	_rw_ribbon_lbl.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04))
	_rw_ribbon_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_rw_ribbon_tex.add_child(_rw_ribbon_lbl)

	# --- STAGE 3: 3D CHEST FLOOR + REVEAL ---
	_chest_hud = Control.new()
	_chest_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chest_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chest_hud)

	var cp_pill := _make_floop_panel(Vector2(660, 62))
	cp_pill.anchor_top = 0.0
	cp_pill.anchor_bottom = 0.0
	cp_pill.offset_top = 152
	cp_pill.offset_bottom = 214
	_chest_hud.add_child(cp_pill)

	_chest_prompt_lbl = _make_label("TAP chests to unlock!", 28, Color.WHITE)
	_chest_prompt_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chest_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chest_prompt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cp_pill.add_child(_chest_prompt_lbl)

	_reveal_root = Control.new()
	_reveal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reveal_root)

	_rev_card_back = TextureRect.new()
	_rev_card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rev_card_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rev_card_back.texture = TEX_CARD_BACK
	_rev_card_back.size = Vector2(126, 176)
	_rev_card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_root.add_child(_rev_card_back)

	_rev_card_holder = Control.new()
	_rev_card_holder.size = Vector2(160, 224)
	_rev_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_root.add_child(_rev_card_holder)

	_rev_tap_lbl = _make_label("Tap anywhere to collect", 22, Color.WHITE)
	_rev_tap_lbl.anchor_left = 0.5
	_rev_tap_lbl.anchor_right = 0.5
	_rev_tap_lbl.anchor_top = 1.0
	_rev_tap_lbl.anchor_bottom = 1.0
	_rev_tap_lbl.offset_left = -260
	_rev_tap_lbl.offset_right = 260
	_rev_tap_lbl.offset_top = -72
	_rev_tap_lbl.offset_bottom = -32
	_rev_tap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_root.add_child(_rev_tap_lbl)

	# --- STAGE 4: JAKE'S PRO TIP ---
	_tip_root = Control.new()
	_tip_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tip_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tip_root)

	var tip_h_pill := _make_floop_panel(Vector2(620, 62))
	tip_h_pill.offset_top = -182
	tip_h_pill.offset_bottom = -120
	_tip_root.add_child(tip_h_pill)
	_tip_header_lbl = _make_label("JAKE'S PRO TIP", 28, Color.WHITE)
	_tip_header_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tip_header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_header_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip_h_pill.add_child(_tip_header_lbl)

	var tip_b_pill := _make_floop_panel(Vector2(620, 210))
	tip_b_pill.offset_top = -112
	tip_b_pill.offset_bottom = 98
	_tip_root.add_child(tip_b_pill)
	_tip_body_lbl = _make_label("", 24, Color.WHITE)
	_tip_body_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tip_body_lbl.offset_left = 26
	_tip_body_lbl.offset_right = -26
	_tip_body_lbl.offset_top = 16
	_tip_body_lbl.offset_bottom = -16
	_tip_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_body_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip_b_pill.add_child(_tip_body_lbl)

	_tip_ok_btn = _make_btn("OK", TEX_BTN_GREEN, Vector2(300, 94))
	_tip_ok_btn.anchor_left = 0.5
	_tip_ok_btn.anchor_right = 0.5
	_tip_ok_btn.anchor_top = 1.0
	_tip_ok_btn.anchor_bottom = 1.0
	_tip_ok_btn.offset_left = -150
	_tip_ok_btn.offset_right = 150
	_tip_ok_btn.offset_top = -140
	_tip_ok_btn.offset_bottom = -46
	_tip_ok_btn.add_theme_font_size_override("font_size", 42)
	_tip_ok_btn.pressed.connect(_on_tip_ok_pressed)
	_tip_root.add_child(_tip_ok_btn)

	# Lightweight compatibility holders (invisible; preserves external unit-test contract)
	title_label = Label.new()
	title_label.visible = false
	add_child(title_label)
	coins_label = Label.new()
	coins_label.visible = false
	add_child(coins_label)
	xp_label = Label.new()
	xp_label.visible = false
	add_child(xp_label)
	continue_btn = Button.new()
	continue_btn.visible = false
	add_child(continue_btn)
	levelup_banner = Label.new()
	levelup_banner.visible = false
	add_child(levelup_banner)
	objectives_section = Control.new()
	objectives_section.visible = false
	add_child(objectives_section)
	objectives_list = VBoxContainer.new()
	objectives_section.add_child(objectives_list)


func _build_player_stats_bar() -> void:
	_stats_bar = Control.new()
	_stats_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stats_bar.offset_bottom = 120
	_stats_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats_bar)

	# Top-left HUD_PlayerInfo bar (502x97 scaled cleanly to 360x70)
	var p_bg := TextureRect.new()
	p_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p_bg.stretch_mode = TextureRect.STRETCH_SCALE
	p_bg.texture = TEX_HUD_PLAYER
	p_bg.position = Vector2(8, 6)
	p_bg.size = Vector2(360, 70)
	p_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_bar.add_child(p_bg)

	_sb_portrait = TextureRect.new()
	_sb_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sb_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sb_portrait.position = Vector2(9, 7)
	_sb_portrait.size = Vector2(47, 47)
	_sb_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_bg.add_child(_sb_portrait)

	_sb_name_lbl = Label.new()
	_sb_name_lbl.text = "Jake"
	_sb_name_lbl.position = Vector2(64, 8)
	_sb_name_lbl.size = Vector2(102, 20)
	_sb_name_lbl.add_theme_font_override("font", FONT_MAIN)
	_sb_name_lbl.add_theme_font_size_override("font_size", 13)
	_sb_name_lbl.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04))
	p_bg.add_child(_sb_name_lbl)

	_sb_lvl_lbl = _make_label("Lvl. 2", 12, Color.WHITE)
	_sb_lvl_lbl.position = Vector2(167, 8)
	_sb_lvl_lbl.size = Vector2(56, 20)
	_sb_lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_bg.add_child(_sb_lvl_lbl)

	var xp_tag := _make_label("XP", 12, Color.WHITE)
	xp_tag.position = Vector2(61, 30)
	xp_tag.size = Vector2(22, 17)
	xp_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_bg.add_child(xp_tag)

	_sb_xp_bar = ProgressBar.new()
	_sb_xp_bar.position = Vector2(84, 31)
	_sb_xp_bar.size = Vector2(139, 15)
	_sb_xp_bar.show_percentage = false
	var sb_bg := StyleBoxEmpty.new()
	_sb_xp_bar.add_theme_stylebox_override("background", sb_bg)
	var sb_fill := StyleBoxTexture.new()
	sb_fill.texture = TEX_XP_BAR
	sb_fill.texture_margin_left = 4
	sb_fill.texture_margin_right = 4
	_sb_xp_bar.add_theme_stylebox_override("fill", sb_fill)
	p_bg.add_child(_sb_xp_bar)

	_sb_xp_lbl = _make_label("215 / 595", 13, Color.WHITE)
	_sb_xp_lbl.position = Vector2(84, 29)
	_sb_xp_lbl.size = Vector2(139, 19)
	_sb_xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sb_xp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p_bg.add_child(_sb_xp_lbl)

	_sb_stamina_lbl = _make_label("5/5", 15, Color.WHITE)
	_sb_stamina_lbl.position = Vector2(230, 10)
	_sb_stamina_lbl.size = Vector2(50, 38)
	_sb_stamina_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sb_stamina_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p_bg.add_child(_sb_stamina_lbl)

	_sb_timer_lbl = _make_label("MAX", 14, Color.WHITE)
	_sb_timer_lbl.position = Vector2(282, 10)
	_sb_timer_lbl.size = Vector2(64, 38)
	_sb_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sb_timer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p_bg.add_child(_sb_timer_lbl)

	# Trophy Bar below top-left bar
	var tr_bar := TextureRect.new()
	tr_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr_bar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tr_bar.texture = TEX_HUD_TROPHY
	tr_bar.position = Vector2(8, 72)
	tr_bar.size = Vector2(114, 38)
	tr_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_bar.add_child(tr_bar)

	var tr_icon := TextureRect.new()
	tr_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr_icon.custom_minimum_size = Vector2(28, 32)
	tr_icon.position = Vector2(3, 3)
	tr_icon.size = Vector2(28, 32)
	tr_icon.texture = TEX_TROPHY_ICON
	tr_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr_bar.add_child(tr_icon)

	_sb_trophy_lbl = _make_label("0", 14, Color.WHITE)
	_sb_trophy_lbl.position = Vector2(38, 6)
	_sb_trophy_lbl.size = Vector2(68, 26)
	_sb_trophy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sb_trophy_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tr_bar.add_child(_sb_trophy_lbl)

	# Top-right Inventory / Gems / Coins boxes
	_sb_inv_box = TextureRect.new()
	_sb_inv_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sb_inv_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sb_inv_box.texture = TEX_HUD_INV
	_sb_inv_box.anchor_left = 1.0
	_sb_inv_box.anchor_right = 1.0
	_sb_inv_box.offset_left = -368
	_sb_inv_box.offset_right = -244
	_sb_inv_box.offset_top = 8
	_sb_inv_box.offset_bottom = 70
	_sb_inv_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_bar.add_child(_sb_inv_box)

	_sb_inv_lbl = _make_label("0/50", 14, Color.WHITE)
	_sb_inv_lbl.position = Vector2(48, 16)
	_sb_inv_lbl.size = Vector2(68, 30)
	_sb_inv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sb_inv_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sb_inv_box.add_child(_sb_inv_lbl)

	var gems_box := TextureRect.new()
	gems_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gems_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gems_box.texture = TEX_HUD_GEMS
	gems_box.anchor_left = 1.0
	gems_box.anchor_right = 1.0
	gems_box.offset_left = -238
	gems_box.offset_right = -132
	gems_box.offset_top = 10
	gems_box.offset_bottom = 68
	gems_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_bar.add_child(gems_box)

	_sb_gems_lbl = _make_label("5", 14, Color.WHITE)
	_sb_gems_lbl.position = Vector2(46, 14)
	_sb_gems_lbl.size = Vector2(50, 28)
	_sb_gems_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sb_gems_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gems_box.add_child(_sb_gems_lbl)

	var coins_box := TextureRect.new()
	coins_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coins_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coins_box.texture = TEX_HUD_COINS
	coins_box.anchor_left = 1.0
	coins_box.anchor_right = 1.0
	coins_box.offset_left = -126
	coins_box.offset_right = -8
	coins_box.offset_top = 10
	coins_box.offset_bottom = 68
	coins_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_bar.add_child(coins_box)

	_sb_coins_lbl = _make_label("0", 14, Color.WHITE)
	_sb_coins_lbl.position = Vector2(46, 14)
	_sb_coins_lbl.size = Vector2(62, 28)
	_sb_coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sb_coins_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coins_box.add_child(_sb_coins_lbl)


func _make_slate_victory_frame(sz: Vector2, is_victory: bool) -> Dictionary:
	var root := Control.new()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 0.5
	root.anchor_bottom = 0.5
	root.offset_left = -sz.x * 0.5
	root.offset_right = sz.x * 0.5
	root.offset_top = -sz.y * 0.5
	root.offset_bottom = sz.y * 0.5
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var inner := NinePatchRect.new()
	inner.texture = TEX_CW_GREY
	inner.self_modulate = Color(0.14, 0.25, 0.27, 0.93)
	inner.patch_margin_left = 12
	inner.patch_margin_top = 12
	inner.patch_margin_right = 12
	inner.patch_margin_bottom = 12
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 18
	inner.offset_right = -18
	inner.offset_top = 18
	inner.offset_bottom = -18
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)

	var border := NinePatchRect.new()
	border.texture = TEX_FRAME_VICTORY if is_victory else TEX_FRAME_DEFEAT
	border.patch_margin_left = 74
	border.patch_margin_top = 74
	border.patch_margin_right = 74
	border.patch_margin_bottom = 74
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(border)

	return {"root": root, "inner": inner, "border": border}


func _make_grey_row_panel(height_px: int) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = TEX_CW_GREY
	n.self_modulate = Color(0.06, 0.11, 0.13, 0.45)
	n.patch_margin_left = 8
	n.patch_margin_top = 8
	n.patch_margin_right = 8
	n.patch_margin_bottom = 8
	n.custom_minimum_size = Vector2(0, height_px)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


func _make_floop_panel(sz: Vector2) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = TEX_FLOOP_BG
	n.patch_margin_left = 20
	n.patch_margin_top = 20
	n.patch_margin_right = 20
	n.patch_margin_bottom = 20
	n.anchor_left = 0.5
	n.anchor_right = 0.5
	n.anchor_top = 0.5
	n.anchor_bottom = 0.5
	n.offset_left = -sz.x * 0.5
	n.offset_right = sz.x * 0.5
	n.offset_top = -sz.y * 0.5
	n.offset_bottom = sz.y * 0.5
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


func _make_label(txt: String, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", FONT_MAIN)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _make_btn(txt: String, tex: Texture2D, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = sz
	b.add_theme_font_override("font", FONT_MAIN)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 5)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 20
	sb.texture_margin_top = 22
	sb.texture_margin_right = 20
	sb.texture_margin_bottom = 26
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	return b
