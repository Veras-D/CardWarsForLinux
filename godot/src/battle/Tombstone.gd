class_name Tombstone
extends Control

## Visual component for LaneSlot Tombstones & Loot Drops (Coins, Chests).

signal collected(loot_type: String, drop_data: Dictionary)

@export var auto_collect_delay: float = 0.0 # 0 means wait for user click or turn end

var drop_data: Dictionary = {
	"type": "TOMBSTONE",
	"amount": 0,
	"card_id": "",
	"card_name": "",
	"texture_path": "res://assets/textures/props/Tombstone.png",
	"icon": "🪦",
	"label": "R.I.P."
}

var is_collected: bool = false
var _idle_tween: Tween = null

@onready var icon_rect: TextureRect = $IconRect
@onready var fallback_label: Label = $FallbackLabel
@onready var badge_label: Label = $BadgeLabel
@onready var click_button: Button = $ClickButton

func _ready() -> void:
	# Click handler
	if click_button:
		click_button.pressed.connect(_on_clicked)
	
	_update_display()
	_play_spawn_animation()

	if auto_collect_delay > 0.0:
		get_tree().create_timer(auto_collect_delay).timeout.connect(func():
			if not is_collected and is_instance_valid(self):
				collect()
		)

func setup(data: Dictionary) -> void:
	drop_data = data.duplicate(true)
	if is_node_ready():
		_update_display()

func _update_display() -> void:
	var l_type = drop_data.get("type", "TOMBSTONE")
	var l_text = drop_data.get("label", "R.I.P.")
	var tex_path = drop_data.get("texture_path", "")
	var emoji_icon = drop_data.get("icon", "🪦")

	if badge_label:
		badge_label.text = l_text

	# Try loading texture
	var texture_loaded = false
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		if tex and icon_rect:
			icon_rect.texture = tex
			icon_rect.visible = true
			texture_loaded = true
	
	if fallback_label:
		fallback_label.visible = not texture_loaded
		fallback_label.text = emoji_icon

	# Theme styles based on type
	if l_type == "GOLD":
		if badge_label:
			badge_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	elif l_type == "CARD":
		if badge_label:
			badge_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	else:
		if badge_label:
			badge_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))

func _play_spawn_animation() -> void:
	pivot_offset = size / 2.0
	scale = Vector2(0.1, 0.1)
	modulate.a = 0.0

	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.1, 1.1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	tw.finished.connect(_start_idle_wobble)

func _start_idle_wobble() -> void:
	if is_collected or not is_inside_tree():
		return
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(self, "position:y", position.y - 4.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(self, "position:y", position.y, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_clicked() -> void:
	collect()

func collect() -> void:
	if is_collected:
		return
	is_collected = true
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()

	# Emit signal immediately so game state records reward
	var loot_type = drop_data.get("type", "TOMBSTONE")
	collected.emit(loot_type, drop_data)

	# Play floating collect animation
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 50.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(queue_free)

func fade_out_and_remove(duration: float = 0.4) -> void:
	if is_collected:
		return
	# If it has loot that wasn't collected yet, ensure it collects!
	var loot_type = drop_data.get("type", "TOMBSTONE")
	if loot_type == "GOLD" or loot_type == "CARD":
		collect()
		return

	is_collected = true
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_property(self, "scale", Vector2(0.5, 0.5), duration)
	tw.chain().tween_callback(queue_free)
