extends Control
class_name CardView

const FusionEngine = preload("res://src/cards/FusionEngine.gd")
const GoldFoilShader = preload("res://src/shaders/card_gold_foil.gdshader")
const ObsidianDarkShader = preload("res://src/shaders/card_obsidian_dark.gdshader")

const TEX_FRAME_WHITE: Texture2D = preload("res://assets/textures/ui/cards/Frame_White.png")
const TEX_FRAME_COLORLESS: Texture2D = preload("res://assets/textures/ui/cards/Frame_Colorless.png")
const TEX_FRAME_GOLD: Texture2D = preload("res://assets/textures/ui/cards/Frame_Gold.png")
const TEX_FRAME_OBSIDIAN: Texture2D = preload("res://assets/textures/ui/cards/Frame_Obsidian.png")

const FACTION_ICONS := {
	"Corn": preload("res://assets/textures/ui/cards/UI_CornIcon.png"),
	"Plains": preload("res://assets/textures/ui/cards/UI_PlainsIcon.png"),
	"Cotton": preload("res://assets/textures/ui/cards/UI_CottonIcon.png"),
	"Sand": preload("res://assets/textures/ui/cards/UI_SandIcon.png"),
	"Swamp": preload("res://assets/textures/ui/cards/UI_SwampIcon.png"),
}

const FACTION_COLORS := {
	"Corn": Color(1.0, 239.0 / 255.0, 108.0 / 255.0),
	"Plains": Color(108.0 / 255.0, 205.0 / 255.0, 240.0 / 255.0),
	"Cotton": Color(243.0 / 255.0, 122.0 / 255.0, 176.0 / 255.0),
	"Sand": Color(217.0 / 255.0, 170.0 / 255.0, 133.0 / 255.0),
	"Swamp": Color(103.0 / 255.0, 143.0 / 255.0, 47.0 / 255.0),
	"Universal": Color(1.0, 1.0, 1.0),
}

signal card_clicked(card_view)

@export var card_data: Dictionary = {}
var is_flooped: bool = false
var can_play: bool = true
var current_quality: int = FusionEngine.QualityTier.STANDARD
var _ui_scale: Vector2 = Vector2.ONE
var _base_metrics: Dictionary = {}

@onready var panel: Panel = $Panel
@onready var bg_type: TextureRect = $BgType
@onready var bg_name: TextureRect = $BgName
@onready var texture_rect: TextureRect = $CardArt
@onready var icon_magic: TextureRect = $IconMagic
@onready var card_frame: TextureRect = $CardFrame
@onready var card_frame_quality: TextureRect = $CardFrameQuality
@onready var icon_fact: TextureRect = $IconFact
@onready var title_label: Label = $TitleLabel
@onready var type_label: Label = $TypeLabel
@onready var desc_label: Label = $DescLabel
@onready var cost_label: Label = $CostLabel
@onready var atk_badge: Control = $AtkBadge
@onready var atk_frame: TextureRect = $AtkBadge/Frame
@onready var atk_label: Label = $AtkBadge/AtkLabel
@onready var def_badge: Control = $DefBadge
@onready var def_frame: TextureRect = $DefBadge/Frame
@onready var def_label: Label = $DefBadge/DefLabel
@onready var floop_badge: Control = $FloopBadge
@onready var floop_label: Label = $FloopBadge/FloopLabel
@onready var rarity_hbox: HBoxContainer = $RarityHBox


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	_capture_base_metrics(self)
	if not card_data.is_empty():
		render_card(card_data)


func render_card_at_size(data: Dictionary, target_size: Vector2) -> void:
	set_render_size(target_size)
	render_card(data)


func set_render_size(target_size: Vector2) -> void:
	if _base_metrics.is_empty():
		_capture_base_metrics(self)
	var sx := target_size.x / 130.0
	var sy := target_size.y / 184.0
	_ui_scale = Vector2(sx, sy)
	custom_minimum_size = target_size
	size = target_size
	pivot_offset = target_size * 0.5
	scale = Vector2.ONE
	_apply_scaled_metrics(self, sx, sy)


func _capture_base_metrics(root: Node) -> void:
	for ch in root.get_children():
		if ch is Control:
			var c := ch as Control
			var entry: Dictionary = {
				"full_rect": is_equal_approx(c.anchor_right, 1.0) and is_equal_approx(c.anchor_bottom, 1.0),
				"left": c.offset_left,
				"top": c.offset_top,
				"right": c.offset_right,
				"bottom": c.offset_bottom,
				"min_size": c.custom_minimum_size,
			}
			if c is Label:
				entry["font_size"] = c.get_theme_font_size("font_size")
				if c.has_theme_constant("shadow_offset_x"):
					entry["shadow_x"] = c.get_theme_constant("shadow_offset_x")
					entry["shadow_y"] = c.get_theme_constant("shadow_offset_y")
			if c is HBoxContainer:
				entry["sep"] = c.get_theme_constant("separation")
			_base_metrics[c.get_instance_id()] = entry
		_capture_base_metrics(ch)


func _apply_scaled_metrics(root: Node, sx: float, sy: float) -> void:
	var font_scale := minf(sx, sy)
	for ch in root.get_children():
		if ch is Control:
			var c := ch as Control
			var entry: Dictionary = _base_metrics.get(c.get_instance_id(), {})
			if not entry.is_empty():
				if not bool(entry.get("full_rect", false)):
					c.offset_left = float(entry["left"]) * sx
					c.offset_top = float(entry["top"]) * sy
					c.offset_right = float(entry["right"]) * sx
					c.offset_bottom = float(entry["bottom"]) * sy
				var base_min: Vector2 = entry["min_size"]
				if base_min != Vector2.ZERO:
					c.custom_minimum_size = Vector2(base_min.x * sx, base_min.y * sy)
				if c is Label and entry.has("font_size"):
					c.add_theme_font_size_override("font_size", maxi(1, roundi(float(entry["font_size"]) * font_scale)))
					if entry.has("shadow_x"):
						c.add_theme_constant_override("shadow_offset_x", maxi(1, roundi(float(entry["shadow_x"]) * font_scale)))
						c.add_theme_constant_override("shadow_offset_y", maxi(1, roundi(float(entry["shadow_y"]) * font_scale)))
				if c is HBoxContainer and entry.has("sep"):
					c.add_theme_constant_override("separation", maxi(1, roundi(float(entry["sep"]) * sx)))
		_apply_scaled_metrics(ch, sx, sy)


func render_card(data: Dictionary) -> void:
	card_data = data
	var q_tier = FusionEngine.get_card_quality(data)
	current_quality = q_tier

	var prefix = ""
	if q_tier == FusionEngine.QualityTier.GOLD:
		prefix = "✨ "
	elif q_tier == FusionEngine.QualityTier.OBSIDIAN:
		prefix = "🔮 "

	title_label.text = prefix + str(data.get("name", "Card"))
	desc_label.text = str(data.get("desc", ""))
	cost_label.text = str(data.get("cost", 1))

	var faction := str(data.get("faction", "Universal"))
	var f_color: Color = FACTION_COLORS.get(faction, FACTION_COLORS["Universal"])
	var banner_tint := f_color.lerp(Color.WHITE, 0.5)
	if faction == "Universal" or not FACTION_ICONS.has(faction):
		card_frame.texture = TEX_FRAME_COLORLESS
		card_frame.modulate = Color.WHITE
		icon_fact.visible = false
		icon_magic.visible = false
		banner_tint = Color(0.93, 0.88, 0.99)
	else:
		card_frame.texture = TEX_FRAME_WHITE
		card_frame.modulate = f_color
		icon_fact.texture = FACTION_ICONS[faction]
		icon_fact.visible = true
		icon_magic.visible = true

	bg_name.modulate = banner_tint
	bg_type.modulate = banner_tint
	atk_frame.modulate = banner_tint
	def_frame.modulate = banner_tint

	_apply_quality_visuals(q_tier)

	var tex_path := str(data.get("texture_path", ""))
	if tex_path != "":
		texture_rect.texture = Database.get_card_texture(tex_path)

	var card_type := str(data.get("type", "CREATURE")).to_upper()
	type_label.text = card_type.capitalize()

	if card_type == "CREATURE":
		atk_badge.visible = true
		def_badge.visible = true
		atk_label.text = str(data.get("atk", 0))
		def_label.text = str(data.get("def", 0))

		var floop_cost := int(data.get("floop_cost", 0))
		if floop_cost > 0:
			floop_badge.visible = true
			floop_label.text = "FLOOP (%d Magic)" % floop_cost
			desc_label.offset_top = 133.5 * _ui_scale.y
			desc_label.offset_bottom = 161.5 * _ui_scale.y
			desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		else:
			floop_badge.visible = false
			desc_label.offset_top = 124.5 * _ui_scale.y
			desc_label.offset_bottom = 161.5 * _ui_scale.y
			desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		atk_badge.visible = false
		def_badge.visible = false
		floop_badge.visible = false
		desc_label.offset_top = 124.5 * _ui_scale.y
		desc_label.offset_bottom = 166.0 * _ui_scale.y
		desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var rarity := clampi(int(data.get("rarity", 1)), 1, 5)
	var stars := rarity_hbox.get_children()
	for i in range(stars.size()):
		stars[i].visible = (i < rarity)


func _apply_quality_visuals(q_tier: int) -> void:
	if panel == null:
		return
	if q_tier == FusionEngine.QualityTier.GOLD:
		var mat = ShaderMaterial.new()
		mat.shader = GoldFoilShader
		panel.material = mat
		card_frame_quality.texture = TEX_FRAME_GOLD
		card_frame_quality.visible = true
	elif q_tier == FusionEngine.QualityTier.OBSIDIAN:
		var mat = ShaderMaterial.new()
		mat.shader = ObsidianDarkShader
		panel.material = mat
		card_frame_quality.texture = TEX_FRAME_OBSIDIAN
		card_frame_quality.visible = true
	else:
		panel.material = null
		card_frame_quality.visible = false


func set_flooped(flooped: bool) -> void:
	is_flooped = flooped
	if is_flooped:
		rotation_degrees = 20.0
		modulate = Color(0.7, 0.7, 0.7, 1.0)
	else:
		rotation_degrees = 0.0
		modulate = Color.WHITE


func update_stats(new_atk: int, new_def: int) -> void:
	atk_label.text = str(new_atk)
	def_label.text = str(new_def)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)
