extends Control
class_name BattleModals

## Hosts in-match Card Wars modals & turn banners matching original screenshots:
##   - TurnBanner ("Your Turn" 3D ribbon+burst+cards Take 001_18 & "Opponent's Turn" 3D skull Take 001_19)
##   - CurrentQuestModal (GoldPlaque, "Achievable" status, 3 stars, live counters)
##   - DiscardPileModal ("Player's Discard Pile" card grid)
##   - LeaveBattleModal ("Leave this Battle?" QUIT / DON'T QUIT)
##   - UnusedMagicWarning ("End Turn with unused Magic?" YES / NO)

signal quit_battle_confirmed
signal force_battle_confirmed
signal modal_closed
signal ability_confirmed
signal ability_cancelled
signal info_dismissed

const FONT_MAIN: FontFile = preload("res://assets/fonts/KBPlanetEarth.ttf")
const CardViewScene: PackedScene = preload("res://scenes/components/CardView.tscn")
const StarConditionEvaluator = preload("res://src/systems/node_map_system/StarConditionEvaluator.gd")

const CLIP_YOUR_TURN: StringName = &"Take 001_18"
const CLIP_OPP_TURN: StringName = &"Take 001_19"
const TEX_STAR_FULL: Texture2D = preload("res://assets/textures/battle/FX_QuestStar_PNG.png")
const TEX_ATK_ICON: Texture2D = preload("res://assets/textures/battle/hud/Combat_Icon_ATK.png")
const TEX_DEF_ICON: Texture2D = preload("res://assets/textures/battle/hud/Combat_Icon_DEF.png")
const TEX_POPUP_BLUE: Texture2D = preload("res://assets/textures/battle/hud/PopUpSprite_2.png")
const TEX_BTN_GREEN: Texture2D = preload("res://assets/textures/battle/hud/uiButtonGreen.png")
const TEX_BTN_RED: Texture2D = preload("res://assets/textures/battle/hud/uiButtonRed.png")
const TEX_FLOOP_BG: Texture2D = preload("res://assets/textures/battle/hud/FloopPanel_BG.png")
const TEX_FLOOP_INFO: Texture2D = preload("res://assets/textures/battle/hud/FloopInfo.png")
const TEX_FLOOP_COST: Texture2D = preload("res://assets/textures/battle/hud/FloopCostBadge.png")
const TEX_FRAME_INDENT: Texture2D = preload("res://assets/textures/battle/hud/Frame_Indent.png")
const TEX_SUMMON_CORN: Texture2D = preload("res://assets/textures/battle/hud/SummonPanelCorn.png")
const TEX_SUMMON_COTTON: Texture2D = preload("res://assets/textures/battle/hud/SummonPanelCotton.png")
const TEX_SUMMON_PLAINS: Texture2D = preload("res://assets/textures/battle/hud/SummonPanelPlains.png")
const TEX_SUMMON_SAND: Texture2D = preload("res://assets/textures/battle/hud/SummonPanelSand.png")
const TEX_SUMMON_SWAMP: Texture2D = preload("res://assets/textures/battle/hud/SummonPanelSwamp.png")
const TEX_SUMMON_COLORLESS: Texture2D = preload("res://assets/textures/battle/hud/SummonPanelColorless.png")
const TEX_ICON_CORN: Texture2D = preload("res://assets/textures/battle/hud/UI_CornIcon.png")
const TEX_ICON_COTTON: Texture2D = preload("res://assets/textures/battle/hud/UI_CottonIcon.png")
const TEX_ICON_PLAINS: Texture2D = preload("res://assets/textures/battle/hud/UI_PlainsIcon.png")
const TEX_ICON_SAND: Texture2D = preload("res://assets/textures/battle/hud/UI_SandIcon.png")
const TEX_ICON_SWAMP: Texture2D = preload("res://assets/textures/battle/hud/UI_SwampIcon.png")
const TEX_ICON_COLORLESS: Texture2D = preload("res://assets/textures/battle/hud/UI_ColorlessIcon.png")
const TEX_TYPE_CREATURE: Texture2D = preload("res://assets/textures/battle/hud/IconCreatures.png")
const TEX_TYPE_BUILDING: Texture2D = preload("res://assets/textures/battle/hud/IconBuildings.png")
const TEX_TYPE_SPELL: Texture2D = preload("res://assets/textures/battle/hud/IconSpells.png")
const TEX_BOOK: Texture2D = preload("res://assets/textures/battle/hud/Book.png")

@onready var dimmer: ColorRect = $Dimmer

@onready var turn_banner_viewport: SubViewportContainer = $TurnBannerViewportContainer
@onready var your_turn_banner: Node3D = $TurnBannerViewportContainer/SubViewport/Battle_YourTurn
@onready var opp_turn_banner: Node3D = $TurnBannerViewportContainer/SubViewport/Battle_OpponentsTurn

@onready var quest_modal: Control = $CurrentQuestModal
@onready var quest_rows_box: VBoxContainer = $CurrentQuestModal/Frame/VBox/ConditionsScroll/Rows
@onready var quest_close_btn: Button = $CurrentQuestModal/Frame/CloseBtn

@onready var discard_modal: Control = $DiscardPileModal
@onready var discard_title_lbl: Label = $DiscardPileModal/Frame/TitleLabel
@onready var discard_grid: GridContainer = $DiscardPileModal/Frame/Scroll/Grid
@onready var discard_empty_lbl: Label = $DiscardPileModal/Frame/EmptyLabel
@onready var discard_close_btn: Button = $DiscardPileModal/Frame/CloseBtn

@onready var leave_modal: Control = $LeaveBattleModal
@onready var leave_quit_btn: Button = $LeaveBattleModal/Frame/Buttons/QuitBtn
@onready var leave_stay_btn: Button = $LeaveBattleModal/Frame/Buttons/StayBtn

@onready var magic_warn_modal: Control = $UnusedMagicModal
@onready var magic_yes_btn: Button = $UnusedMagicModal/Frame/Buttons/YesBtn
@onready var magic_no_btn: Button = $UnusedMagicModal/Frame/Buttons/NoBtn

var _your_turn_anim: AnimationPlayer = null
var _opp_turn_anim: AnimationPlayer = null
var _turn_seq_id: int = 0

var _info_backdrop: Control = null
var _card_info_bar: PanelContainer = null
var _ci_title: Label = null
var _ci_portrait: TextureRect = null
var _ci_desc: Label = null
var _ci_atk_row: HBoxContainer = null
var _ci_atk_lbl: Label = null
var _ci_type_lbl: Label = null
var _ci_def_row: HBoxContainer = null
var _ci_def_lbl: Label = null
var _ci_faction_icon: TextureRect = null
var _ci_type_icon: TextureRect = null
var _ab_bg_tint: NinePatchRect = null

var _ability_banner: NinePatchRect = null
var _ab_title: Label = null
var _ab_portrait: TextureRect = null
var _ab_desc: Label = null
var _ab_subtitle: Label = null
var _ab_book_badge: TextureRect = null
var _ab_book_lbl: Label = null

var _ability_confirm_bar: NinePatchRect = null
var _ac_question: Label = null
var _ac_yes_btn: Button = null
var _ac_no_btn: Button = null
var _ac_cost_orb: TextureRect = null
var _ac_cost_lbl: Label = null


func _ready() -> void:
	dimmer.visible = false
	_your_turn_anim = _setup_turn_banner_anim(your_turn_banner, CLIP_YOUR_TURN)
	_opp_turn_anim = _setup_turn_banner_anim(opp_turn_banner, CLIP_OPP_TURN)
	_stop_turn_banners()
	quest_modal.visible = false
	discard_modal.visible = false
	leave_modal.visible = false
	magic_warn_modal.visible = false

	quest_close_btn.pressed.connect(close_all_modals)
	discard_close_btn.pressed.connect(close_all_modals)
	leave_stay_btn.pressed.connect(close_all_modals)
	leave_quit_btn.pressed.connect(func():
		close_all_modals()
		quit_battle_confirmed.emit()
	)
	magic_no_btn.pressed.connect(close_all_modals)
	magic_yes_btn.pressed.connect(func():
		close_all_modals()
		force_battle_confirmed.emit()
	)
	_build_inspection_and_confirm_ui()


func is_any_modal_open() -> bool:
	return quest_modal.visible or discard_modal.visible or leave_modal.visible or magic_warn_modal.visible or (_ability_confirm_bar != null and _ability_confirm_bar.visible)


func is_inspection_open() -> bool:
	return (_card_info_bar != null and _card_info_bar.visible) or (_ability_confirm_bar != null and _ability_confirm_bar.visible)


func close_all_modals() -> void:
	_stop_turn_banners()
	dimmer.visible = false
	quest_modal.visible = false
	discard_modal.visible = false
	leave_modal.visible = false
	magic_warn_modal.visible = false
	dismiss_inspection(false)
	modal_closed.emit()


func dismiss_inspection(emit_signal: bool = true) -> void:
	if _info_backdrop:
		_info_backdrop.visible = false
	if _card_info_bar:
		_card_info_bar.visible = false
	if _ability_banner:
		_ability_banner.visible = false
	if _ability_confirm_bar:
		_ability_confirm_bar.visible = false
	if emit_signal:
		info_dismissed.emit()


func _setup_turn_banner_anim(banner_root: Node3D, clip_name: StringName) -> AnimationPlayer:
	if not banner_root:
		return null
	var anim_player := banner_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		return null
	var anim_res := anim_player.get_animation(clip_name)
	if anim_res:
		anim_res.loop_mode = Animation.LOOP_NONE
	anim_player.animation_finished.connect(_on_turn_banner_anim_finished)
	return anim_player


func _stop_turn_banners() -> void:
	_turn_seq_id += 1
	if _your_turn_anim:
		_your_turn_anim.stop()
	if _opp_turn_anim:
		_opp_turn_anim.stop()
	if your_turn_banner:
		your_turn_banner.visible = false
	if opp_turn_banner:
		opp_turn_banner.visible = false
	if turn_banner_viewport:
		turn_banner_viewport.visible = false


func _on_turn_banner_anim_finished(_anim_name: StringName) -> void:
	_stop_turn_banners()


func play_turn_banner(is_player_turn: bool, _include_draw_card: bool = true) -> void:
	_stop_turn_banners()
	var seq := _turn_seq_id

	var sfx_path := "res://assets/audio/sfx/SFX_Banner_YourTurn.wav" if is_player_turn else "res://assets/audio/sfx/SFX_Banner_OpponentTurn.wav"
	if Audio and ResourceLoader.exists(sfx_path):
		Audio.play_sfx(load(sfx_path), -4.0)

	var active_banner: Node3D = your_turn_banner if is_player_turn else opp_turn_banner
	var active_anim: AnimationPlayer = _your_turn_anim if is_player_turn else _opp_turn_anim
	var clip_name: StringName = CLIP_YOUR_TURN if is_player_turn else CLIP_OPP_TURN

	if turn_banner_viewport:
		turn_banner_viewport.visible = true
	if your_turn_banner:
		your_turn_banner.visible = is_player_turn
	if opp_turn_banner:
		opp_turn_banner.visible = not is_player_turn

	if active_banner and active_anim and active_anim.has_animation(clip_name):
		active_anim.play(clip_name)
		active_anim.seek(0.0, true)
	else:
		# Fallback hide if clip missing (never silently leave viewport blocking).
		var t := get_tree().create_timer(1.1)
		t.timeout.connect(func():
			if seq == _turn_seq_id:
				_stop_turn_banners()
		)


func open_current_quest(quest_id: String, live_stats: Dictionary) -> void:
	close_all_modals()
	dimmer.visible = true
	quest_modal.visible = true

	for c in quest_rows_box.get_children():
		c.queue_free()

	var q_data: Dictionary = Database.get_quest(quest_id) if (quest_id != "" and Database) else {}
	var conditions: Array = q_data.get("conditions", [])

	if conditions.is_empty():
		var lbl := Label.new()
		lbl.text = "Defeat your opponent in battle!\n(No bonus quest conditions for this match)"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		quest_rows_box.add_child(lbl)
		return

	var eval_stats := live_stats.duplicate(true)
	eval_stats["won"] = true # Evaluate mid-match achievability assuming player wins
	var audit: Array = StarConditionEvaluator.audit_star_conditions(conditions, eval_stats)

	for i in range(audit.size()):
		var item: Dictionary = audit[i]
		var desc := str(item.get("description", "Objective %d" % (i + 1)))
		var detail := str(item.get("detail", ""))
		var achievable := bool(item.get("passed", true))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var star := TextureRect.new()
		star.custom_minimum_size = Vector2(36, 36)
		star.texture = TEX_STAR_FULL
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.modulate = Color(1.0, 0.92, 0.3, 1.0) if achievable else Color(0.45, 0.45, 0.45, 0.65)
		row.add_child(star)

		var text_col := VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var d_lbl := Label.new()
		d_lbl.text = desc if detail == "" else "%s\n%s" % [desc, detail]
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.add_theme_font_size_override("font_size", 17)
		d_lbl.add_theme_color_override("font_color", Color.WHITE)
		d_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		d_lbl.add_theme_constant_override("outline_size", 4)
		text_col.add_child(d_lbl)
		row.add_child(text_col)

		var status_pill := PanelContainer.new()
		status_pill.custom_minimum_size = Vector2(124, 0)
		var sb := StyleBoxTexture.new()
		sb.texture = TEX_BTN_GREEN if achievable else TEX_BTN_RED
		sb.texture_margin_left = 18
		sb.texture_margin_top = 12
		sb.texture_margin_right = 18
		sb.texture_margin_bottom = 14
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 4
		sb.content_margin_bottom = 6
		status_pill.add_theme_stylebox_override("panel", sb)
		var st_lbl := Label.new()
		st_lbl.text = "Achievable" if achievable else "Failed"
		st_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st_lbl.add_theme_font_size_override("font_size", 15)
		st_lbl.add_theme_color_override("font_color", Color.WHITE)
		st_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		st_lbl.add_theme_constant_override("outline_size", 3)
		status_pill.add_child(st_lbl)
		row.add_child(status_pill)

		quest_rows_box.add_child(row)


func open_discard_pile(card_ids: Array[String], title_text: String = "Player's Discard Pile") -> void:
	close_all_modals()
	dimmer.visible = true
	discard_modal.visible = true
	discard_title_lbl.text = title_text

	for c in discard_grid.get_children():
		c.queue_free()

	discard_empty_lbl.visible = card_ids.is_empty()
	for cid in card_ids:
		var c_data := Database.get_card(cid) if Database else {}
		if c_data.is_empty():
			continue
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(138, 192)
		discard_grid.add_child(holder)
		var cv := CardViewScene.instantiate()
		holder.add_child(cv)
		if cv.has_method("render_card"):
			cv.render_card(c_data)
		cv.scale = Vector2(0.84, 0.84)


func open_leave_battle() -> void:
	close_all_modals()
	dimmer.visible = true
	leave_modal.visible = true


func open_unused_magic_warning() -> void:
	close_all_modals()
	dimmer.visible = true
	magic_warn_modal.visible = true


func show_card_info(card_data: Dictionary, current_atk: int = -1, current_def: int = -1, max_def: int = -1, is_flooped: bool = false) -> void:
	close_all_modals()
	if card_data.is_empty():
		return
	var c_type := str(card_data.get("type", "CREATURE"))
	var c_fac := str(card_data.get("faction", "Universal"))
	var bar_sb := _card_info_bar.get_theme_stylebox("panel") as StyleBoxTexture
	if bar_sb:
		bar_sb.texture = _get_summon_panel_tex(c_fac)

	_ci_title.text = str(card_data.get("name", "Card"))
	var desc_txt := str(card_data.get("desc", ""))
	var floop_cost := int(card_data.get("floop_cost", 0))
	if c_type == "CREATURE" and floop_cost > 0 and desc_txt != "":
		var status := " (Flooped)" if is_flooped else (" (Floop: %d MP)" % floop_cost)
		desc_txt += status
	_ci_desc.text = desc_txt if desc_txt != "" else "No ability text."

	var tex_path := str(card_data.get("texture_path", ""))
	if tex_path != "" and ResourceLoader.exists(tex_path):
		_ci_portrait.texture = load(tex_path)
	else:
		_ci_portrait.texture = null

	if _ci_faction_icon:
		_ci_faction_icon.texture = _get_faction_icon_tex(c_fac)
	var type_word := "Building" if c_type == "BUILDING" else ("Spell" if c_type == "SPELL" else "Creature")
	_ci_type_lbl.text = type_word
	if _ci_type_icon:
		_ci_type_icon.texture = TEX_TYPE_BUILDING if c_type == "BUILDING" else (TEX_TYPE_SPELL if c_type == "SPELL" else TEX_TYPE_CREATURE)

	if c_type == "CREATURE":
		var atk_val := current_atk if current_atk >= 0 else int(card_data.get("atk", 0))
		var def_val := current_def if current_def >= 0 else int(card_data.get("def", 0))
		_ci_atk_row.visible = true
		_ci_def_row.visible = true
		_ci_atk_lbl.text = str(atk_val)
		_ci_def_lbl.text = "%d/%d" % [def_val, max_def] if (max_def > 0 and def_val != max_def) else str(def_val)
	else:
		_ci_atk_row.visible = false
		_ci_def_row.visible = false

	_info_backdrop.visible = true
	_card_info_bar.visible = true


func show_ability_confirmation(title_text: String, desc_text: String, tex_path: String, cost: int, question_text: String, subtitle_text: String = "Floop Ability") -> void:
	close_all_modals()
	_ab_title.text = title_text
	_ab_desc.text = desc_text if desc_text != "" else "Activate ability."
	_ab_subtitle.text = subtitle_text
	var is_hero := subtitle_text.find("Hero") >= 0 or subtitle_text.find("Leader") >= 0
	if _ability_banner:
		_ability_banner.self_modulate = Color(0.95, 0.80, 0.44, 1.0) if is_hero else Color(0.55, 0.96, 0.58, 1.0)
	if _ab_book_badge:
		_ab_book_badge.visible = is_hero
		if _ab_book_lbl:
			_ab_book_lbl.text = "0"
	if tex_path != "" and ResourceLoader.exists(tex_path):
		_ab_portrait.texture = load(tex_path)
	else:
		_ab_portrait.texture = null

	_ac_question.text = question_text
	if cost > 0:
		_ac_cost_orb.visible = true
		_ac_cost_lbl.text = str(cost)
	else:
		_ac_cost_orb.visible = false

	_info_backdrop.visible = true
	_ability_banner.visible = true
	_ability_confirm_bar.visible = true


func _get_summon_panel_tex(fac: String) -> Texture2D:
	match fac:
		"Corn": return TEX_SUMMON_CORN
		"Cotton", "Nicelands": return TEX_SUMMON_COTTON
		"Plain", "Plains", "Blue Plains": return TEX_SUMMON_PLAINS
		"Sand", "SandyLands": return TEX_SUMMON_SAND
		"Swamp", "Useless Swamp": return TEX_SUMMON_SWAMP
		_: return TEX_SUMMON_COLORLESS


func _get_faction_icon_tex(fac: String) -> Texture2D:
	match fac:
		"Corn": return TEX_ICON_CORN
		"Cotton", "Nicelands": return TEX_ICON_COTTON
		"Plain", "Plains", "Blue Plains": return TEX_ICON_PLAINS
		"Sand", "SandyLands": return TEX_ICON_SAND
		"Swamp", "Useless Swamp": return TEX_ICON_SWAMP
		_: return TEX_ICON_COLORLESS


func _build_inspection_and_confirm_ui() -> void:
	_info_backdrop = Control.new()
	_info_backdrop.name = "InfoBackdrop"
	_info_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_info_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_backdrop.visible = false
	_info_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			if Audio and ResourceLoader.exists("res://assets/audio/sfx/Cancel.wav"):
				Audio.play_sfx(load("res://assets/audio/sfx/Cancel.wav"), -6.0)
			if _ability_confirm_bar.visible:
				dismiss_inspection(true)
				ability_cancelled.emit()
			else:
				dismiss_inspection(true)
	)
	add_child(_info_backdrop)
	move_child(_info_backdrop, 0)

	# 1. Horizontal Card / Building Info Bar (bottom-center, authentic SummonPanel* 9-slice)
	_card_info_bar = PanelContainer.new()
	_card_info_bar.name = "CardInfoBar"
	_card_info_bar.anchor_left = 0.5
	_card_info_bar.anchor_right = 0.5
	_card_info_bar.anchor_top = 1.0
	_card_info_bar.anchor_bottom = 1.0
	_card_info_bar.offset_left = -290
	_card_info_bar.offset_right = 290
	_card_info_bar.offset_top = -224
	_card_info_bar.offset_bottom = -12
	_card_info_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_info_bar.visible = false

	var ci_sb := StyleBoxTexture.new()
	ci_sb.texture = TEX_SUMMON_CORN
	ci_sb.texture_margin_left = 36
	ci_sb.texture_margin_top = 44
	ci_sb.texture_margin_right = 36
	ci_sb.texture_margin_bottom = 38
	ci_sb.content_margin_left = 28
	ci_sb.content_margin_right = 28
	ci_sb.content_margin_top = 18
	ci_sb.content_margin_bottom = 24
	_card_info_bar.add_theme_stylebox_override("panel", ci_sb)
	add_child(_card_info_bar)

	var ci_vbox := VBoxContainer.new()
	ci_vbox.add_theme_constant_override("separation", 4)
	_card_info_bar.add_child(ci_vbox)

	var ci_top := HBoxContainer.new()
	ci_vbox.add_child(ci_top)
	_ci_title = Label.new()
	_ci_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ci_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ci_title.add_theme_font_override("font", FONT_MAIN)
	_ci_title.add_theme_font_size_override("font_size", 21)
	_ci_title.add_theme_color_override("font_color", Color(0.08, 0.08, 0.10))
	ci_top.add_child(_ci_title)

	_ci_faction_icon = TextureRect.new()
	_ci_faction_icon.custom_minimum_size = Vector2(36, 36)
	_ci_faction_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ci_faction_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ci_top.add_child(_ci_faction_icon)

	var ci_mid := HBoxContainer.new()
	ci_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ci_mid.add_theme_constant_override("separation", 14)
	ci_vbox.add_child(ci_mid)

	var port_frame := PanelContainer.new()
	var p_sb := StyleBoxTexture.new()
	p_sb.texture = TEX_FRAME_INDENT
	p_sb.texture_margin_left = 12
	p_sb.texture_margin_top = 12
	p_sb.texture_margin_right = 12
	p_sb.texture_margin_bottom = 12
	p_sb.content_margin_left = 4
	p_sb.content_margin_top = 4
	p_sb.content_margin_right = 4
	p_sb.content_margin_bottom = 4
	port_frame.add_theme_stylebox_override("panel", p_sb)
	port_frame.custom_minimum_size = Vector2(96, 82)
	ci_mid.add_child(port_frame)

	_ci_portrait = TextureRect.new()
	_ci_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ci_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	port_frame.add_child(_ci_portrait)

	_ci_desc = Label.new()
	_ci_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ci_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ci_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ci_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ci_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ci_desc.add_theme_font_override("font", FONT_MAIN)
	_ci_desc.add_theme_font_size_override("font_size", 16)
	_ci_desc.add_theme_color_override("font_color", Color(0.06, 0.06, 0.08))
	ci_mid.add_child(_ci_desc)

	var ci_bot := HBoxContainer.new()
	ci_vbox.add_child(ci_bot)

	_ci_atk_row = HBoxContainer.new()
	_ci_atk_row.add_theme_constant_override("separation", 4)
	_ci_atk_lbl = _make_card_stat_label("3", 20, Color(0.06, 0.06, 0.08))
	_ci_atk_row.add_child(_ci_atk_lbl)
	var atk_ic := TextureRect.new()
	atk_ic.custom_minimum_size = Vector2(22, 22)
	atk_ic.texture = TEX_ATK_ICON
	atk_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	atk_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ci_atk_row.add_child(atk_ic)
	ci_bot.add_child(_ci_atk_row)

	var type_wrap := HBoxContainer.new()
	type_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	type_wrap.add_theme_constant_override("separation", 6)
	_ci_type_icon = TextureRect.new()
	_ci_type_icon.custom_minimum_size = Vector2(26, 22)
	_ci_type_icon.texture = TEX_TYPE_CREATURE
	_ci_type_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ci_type_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	type_wrap.add_child(_ci_type_icon)
	_ci_type_lbl = _make_card_stat_label("Creature", 20, Color(0.06, 0.06, 0.08))
	type_wrap.add_child(_ci_type_lbl)
	ci_bot.add_child(type_wrap)

	_ci_def_row = HBoxContainer.new()
	_ci_def_row.add_theme_constant_override("separation", 4)
	var def_ic := TextureRect.new()
	def_ic.custom_minimum_size = Vector2(22, 22)
	def_ic.texture = TEX_DEF_ICON
	def_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	def_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ci_def_row.add_child(def_ic)
	_ci_def_lbl = _make_card_stat_label("3", 20, Color(0.06, 0.06, 0.08))
	_ci_def_row.add_child(_ci_def_lbl)
	ci_bot.add_child(_ci_def_row)

	# 2. Top-center green Floop / Ability Info Banner (FloopInfo 9-slice)
	_ability_banner = NinePatchRect.new()
	_ability_banner.name = "AbilityInfoBanner"
	_ability_banner.texture = TEX_FLOOP_INFO
	_ability_banner.self_modulate = Color(0.55, 0.96, 0.58, 1.0)
	_ability_banner.patch_margin_left = 40
	_ability_banner.patch_margin_top = 28
	_ability_banner.patch_margin_right = 40
	_ability_banner.patch_margin_bottom = 28
	_ability_banner.anchor_left = 0.5
	_ability_banner.anchor_right = 0.5
	_ability_banner.offset_left = -250
	_ability_banner.offset_right = 250
	_ability_banner.offset_top = 12
	_ability_banner.offset_bottom = 186
	_ability_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	_ability_banner.visible = false
	add_child(_ability_banner)

	var ab_v := VBoxContainer.new()
	ab_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	ab_v.offset_left = 24
	ab_v.offset_right = -24
	ab_v.offset_top = 14
	ab_v.offset_bottom = -14
	ab_v.add_theme_constant_override("separation", 4)
	_ability_banner.add_child(ab_v)

	_ab_title = _make_outlined_label("Cornball", 22, Color(0.98, 0.86, 0.16))
	_ab_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ab_v.add_child(_ab_title)

	var ab_mid := HBoxContainer.new()
	ab_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ab_mid.add_theme_constant_override("separation", 12)
	ab_v.add_child(ab_mid)

	var ab_port_frame := PanelContainer.new()
	ab_port_frame.custom_minimum_size = Vector2(84, 74)
	var ab_pf_sb := StyleBoxTexture.new()
	ab_pf_sb.texture = TEX_FRAME_INDENT
	ab_pf_sb.texture_margin_left = 4.0
	ab_pf_sb.texture_margin_top = 4.0
	ab_pf_sb.texture_margin_right = 4.0
	ab_pf_sb.texture_margin_bottom = 4.0
	ab_port_frame.add_theme_stylebox_override("panel", ab_pf_sb)
	ab_mid.add_child(ab_port_frame)

	_ab_portrait = TextureRect.new()
	_ab_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ab_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ab_port_frame.add_child(_ab_portrait)

	_ab_desc = _make_outlined_label("+1 Attack.", 16, Color.WHITE)
	_ab_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ab_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ab_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ab_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ab_mid.add_child(_ab_desc)

	_ab_book_badge = TextureRect.new()
	_ab_book_badge.custom_minimum_size = Vector2(58, 68)
	_ab_book_badge.texture = TEX_BOOK
	_ab_book_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ab_book_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ab_book_badge.visible = false
	ab_mid.add_child(_ab_book_badge)

	_ab_book_lbl = _make_outlined_label("0", 24, Color.WHITE)
	_ab_book_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ab_book_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ab_book_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ab_book_badge.add_child(_ab_book_lbl)

	_ab_subtitle = _make_outlined_label("Floop Ability", 18, Color(0.98, 0.86, 0.16))
	_ab_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ab_v.add_child(_ab_subtitle)

	# 3. Bottom-center Confirm Bar ("No | Floop the ...? | Yes (cost)")
	_ability_confirm_bar = NinePatchRect.new()
	_ability_confirm_bar.name = "AbilityConfirmBar"
	_ability_confirm_bar.texture = TEX_POPUP_BLUE
	_ability_confirm_bar.patch_margin_left = 54
	_ability_confirm_bar.patch_margin_top = 36
	_ability_confirm_bar.patch_margin_right = 62
	_ability_confirm_bar.patch_margin_bottom = 36
	_ability_confirm_bar.anchor_left = 0.5
	_ability_confirm_bar.anchor_right = 0.5
	_ability_confirm_bar.anchor_top = 1.0
	_ability_confirm_bar.anchor_bottom = 1.0
	_ability_confirm_bar.offset_left = -265
	_ability_confirm_bar.offset_right = 265
	_ability_confirm_bar.offset_top = -124
	_ability_confirm_bar.offset_bottom = -16
	_ability_confirm_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_ability_confirm_bar.visible = false
	add_child(_ability_confirm_bar)

	var ac_h := HBoxContainer.new()
	ac_h.set_anchors_preset(Control.PRESET_FULL_RECT)
	ac_h.offset_left = 20
	ac_h.offset_right = -20
	ac_h.offset_top = 16
	ac_h.offset_bottom = -16
	ac_h.add_theme_constant_override("separation", 12)
	_ability_confirm_bar.add_child(ac_h)

	_ac_no_btn = _make_textured_btn("No", TEX_BTN_RED)
	_ac_no_btn.pressed.connect(func():
		if Audio and ResourceLoader.exists("res://assets/audio/sfx/Cancel.wav"):
			Audio.play_sfx(load("res://assets/audio/sfx/Cancel.wav"), -4.0)
		dismiss_inspection(true)
		ability_cancelled.emit()
	)
	ac_h.add_child(_ac_no_btn)

	_ac_question = _make_outlined_label("Floop the Cornball?", 18, Color.WHITE)
	_ac_question.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ac_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ac_question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ac_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ac_h.add_child(_ac_question)

	var yes_holder := Control.new()
	yes_holder.custom_minimum_size = Vector2(140, 68)
	ac_h.add_child(yes_holder)

	_ac_yes_btn = _make_textured_btn("Yes", TEX_BTN_GREEN)
	_ac_yes_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ac_yes_btn.pressed.connect(func():
		dismiss_inspection(true)
		ability_confirmed.emit()
	)
	yes_holder.add_child(_ac_yes_btn)

	_ac_cost_orb = TextureRect.new()
	_ac_cost_orb.texture = TEX_FLOOP_COST
	_ac_cost_orb.custom_minimum_size = Vector2(44, 48)
	_ac_cost_orb.size = Vector2(44, 48)
	_ac_cost_orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ac_cost_orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ac_cost_orb.position = Vector2(110, -18)
	yes_holder.add_child(_ac_cost_orb)

	_ac_cost_lbl = _make_outlined_label("2", 20, Color.WHITE)
	_ac_cost_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ac_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ac_cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ac_cost_orb.add_child(_ac_cost_lbl)


func _make_card_stat_label(txt: String, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", FONT_MAIN)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	return l


func _make_outlined_label(txt: String, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", FONT_MAIN)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _make_textured_btn(txt: String, tex: Texture2D) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(140, 68)
	b.add_theme_font_override("font", FONT_MAIN)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 5)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 20
	sb.texture_margin_top = 20
	sb.texture_margin_right = 20
	sb.texture_margin_bottom = 20
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	return b
