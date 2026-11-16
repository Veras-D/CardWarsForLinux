class_name CardWarsUIStyle
extends RefCounted

const FONT_KB := preload("res://assets/fonts/KBPlanetEarth.ttf")
const TEX_BTN_BLUE := preload("res://assets/textures/ui/forge/uiButtonBlue.png")
const TEX_BTN_RED := preload("res://assets/textures/ui/deck/uiButtonRed.png")
const TEX_BTN_GREEN := preload("res://assets/textures/ui/store/uiButtonGreen.png")
const TEX_BTN_GREY := preload("res://assets/textures/ui/deck/uiButtonGrey.png")
const TEX_ARROW := preload("res://assets/textures/questmap/nodes/Arrow_Icon.png")


static func build_resized_texture(tex: Texture2D, target_sz: Vector2i, rotate_cw: bool = false, make_opaque: bool = false) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	var work := img.duplicate() as Image
	if rotate_cw:
		work.rotate_90(CLOCKWISE)
	work.resize(target_sz.x, target_sz.y, Image.INTERPOLATE_BILINEAR)
	if make_opaque:
		for py in range(work.get_height()):
			for px in range(work.get_width()):
				var c := work.get_pixel(px, py)
				if c.a > 0.25:
					c.a = 1.0
					work.set_pixel(px, py, c)
	return ImageTexture.create_from_image(work)


static func make_compact_button_sb(tex: Texture2D, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.modulate_color = tint
	sb.texture_margin_left = 15
	sb.texture_margin_top = 13
	sb.texture_margin_right = 13
	sb.texture_margin_bottom = 16
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	return sb


static func make_popup_frame_sb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.20, 0.28, 0.98)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.04, 0.08, 0.12, 1.0)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 8
	return sb


static func make_popup_hover_sb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.45, 0.72, 1.0)
	sb.set_corner_radius_all(6)
	return sb


static func style_option_button(ob: OptionButton, normal_sb: StyleBox, hover_sb: StyleBox, arrow_tex: Texture2D, popup_frame_sb: StyleBox, popup_hover_sb: StyleBox) -> void:
	if not ob:
		return
	ob.add_theme_stylebox_override("normal", normal_sb)
	ob.add_theme_stylebox_override("hover", hover_sb)
	ob.add_theme_stylebox_override("pressed", hover_sb)
	ob.add_theme_stylebox_override("focus", hover_sb)
	if arrow_tex:
		ob.add_theme_icon_override("arrow", arrow_tex)
	ob.add_theme_constant_override("arrow_margin", 18)

	var popup := ob.get_popup()
	if popup:
		if popup_frame_sb:
			popup.add_theme_stylebox_override("panel", popup_frame_sb)
		if popup_hover_sb:
			popup.add_theme_stylebox_override("hover", popup_hover_sb)
		popup.add_theme_font_override("font", FONT_KB)
		popup.add_theme_font_size_override("font_size", 24)
		popup.add_theme_color_override("font_color", Color.WHITE)
		popup.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.45))
		popup.add_theme_constant_override("v_separation", 8)


static func style_line_edit(le: LineEdit) -> void:
	if not le:
		return
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color(0.15, 0.11, 0.08, 0.95)
	normal_sb.set_border_width_all(3)
	normal_sb.border_color = Color(0.05, 0.03, 0.02, 1.0)
	normal_sb.set_corner_radius_all(12)
	normal_sb.content_margin_left = 18
	normal_sb.content_margin_top = 8
	normal_sb.content_margin_right = 18
	normal_sb.content_margin_bottom = 10

	var focus_sb := normal_sb.duplicate() as StyleBoxFlat
	focus_sb.bg_color = Color(0.19, 0.14, 0.09, 0.98)
	focus_sb.border_color = Color(0.95, 0.78, 0.25, 1.0)

	le.add_theme_stylebox_override("normal", normal_sb)
	le.add_theme_stylebox_override("focus", focus_sb)
	le.add_theme_stylebox_override("read_only", normal_sb)
	le.add_theme_font_override("font", FONT_KB)
	le.add_theme_font_size_override("font_size", 26)
	le.add_theme_color_override("font_color", Color.WHITE)
	le.add_theme_color_override("font_placeholder_color", Color(0.75, 0.70, 0.62, 0.75))
	le.add_theme_color_override("caret_color", Color(1.0, 0.92, 0.45, 1.0))
	le.add_theme_color_override("selection_color", Color(0.08, 0.45, 0.72, 0.75))


static func style_item_list(il: ItemList, hover_sb: StyleBoxFlat) -> void:
	if not il:
		return
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.10, 0.15, 0.20, 0.94)
	panel_sb.set_border_width_all(3)
	panel_sb.border_color = Color(0.05, 0.04, 0.03, 1.0)
	panel_sb.set_corner_radius_all(12)
	panel_sb.content_margin_left = 14
	panel_sb.content_margin_top = 10
	panel_sb.content_margin_right = 14
	panel_sb.content_margin_bottom = 10

	il.add_theme_stylebox_override("panel", panel_sb)
	il.add_theme_stylebox_override("focus", panel_sb)
	if hover_sb:
		il.add_theme_stylebox_override("selected", hover_sb)
		il.add_theme_stylebox_override("selected_focus", hover_sb)
	il.add_theme_font_override("font", FONT_KB)
	il.add_theme_font_size_override("font_size", 24)
	il.add_theme_color_override("font_color", Color.WHITE)
	il.add_theme_color_override("font_selected_color", Color(1.0, 0.92, 0.45))
	il.add_theme_color_override("font_outline_color", Color.BLACK)
	il.add_theme_constant_override("outline_size", 5)
	il.add_theme_constant_override("v_separation", 8)
