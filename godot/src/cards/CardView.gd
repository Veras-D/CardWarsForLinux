extends Control
class_name CardView

const FusionEngine = preload("res://src/cards/FusionEngine.gd")
const GoldFoilShader = preload("res://src/shaders/card_gold_foil.gdshader")
const ObsidianDarkShader = preload("res://src/shaders/card_obsidian_dark.gdshader")

signal card_clicked(card_view)

@export var card_data: Dictionary = {}
var is_flooped: bool = false
var can_play: bool = true
var current_quality: int = FusionEngine.QualityTier.STANDARD

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var texture_rect: TextureRect = $Panel/Margin/VBox/TextureRect
@onready var desc_label: Label = $Panel/Margin/VBox/DescLabel
@onready var cost_label: Label = $CostBadge/CostLabel
@onready var atk_badge: Control = $AtkBadge
@onready var atk_label: Label = $AtkBadge/AtkLabel
@onready var def_badge: Control = $DefBadge
@onready var def_label: Label = $DefBadge/DefLabel
@onready var floop_badge: Control = $FloopBadge
@onready var floop_label: Label = $FloopBadge/FloopLabel

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if not card_data.is_empty():
		render_card(card_data)

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

	_apply_quality_visuals(q_tier)

	var tex_path = data.get("texture_path", "")
	if tex_path != "":
		texture_rect.texture = Database.get_card_texture(tex_path)

	var card_type = data.get("type", "CREATURE")
	if card_type == "CREATURE":
		atk_badge.visible = true
		def_badge.visible = true
		atk_label.text = str(data.get("atk", 0))
		def_label.text = str(data.get("def", 0))

		var floop_cost = data.get("floop_cost", 0)
		if floop_cost > 0:
			floop_badge.visible = true
			floop_label.text = "F:" + str(floop_cost)
		else:
			floop_badge.visible = false
	else:
		atk_badge.visible = false
		def_badge.visible = false
		floop_badge.visible = false

func _apply_quality_visuals(q_tier: int) -> void:
	if panel == null:
		return
	if q_tier == FusionEngine.QualityTier.GOLD:
		var mat = ShaderMaterial.new()
		mat.shader = GoldFoilShader
		panel.material = mat
		title_label.modulate = Color(1.0, 0.92, 0.45, 1.0)
	elif q_tier == FusionEngine.QualityTier.OBSIDIAN:
		var mat = ShaderMaterial.new()
		mat.shader = ObsidianDarkShader
		panel.material = mat
		title_label.modulate = Color(0.88, 0.65, 1.0, 1.0)
	else:
		panel.material = null
		title_label.modulate = Color.WHITE

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
