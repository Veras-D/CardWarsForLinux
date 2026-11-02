extends SceneTree

func _init() -> void:
	print("==> Slicing Landscape textures...")
	var atlas_path = "../Assets/Texture2D/LandscapeAtlas.png"
	var img = Image.load_from_file(atlas_path)
	if not img:
		print("Error: Could not load LandscapeAtlas.png")
		quit(1)
		return

	var w = img.get_width()
	var h = img.get_height()
	print("Atlas loaded: ", w, "x", h)

	DirAccess.make_dir_recursive_absolute("res://assets/textures/landscapes")

	var sprites = {
		"Plains": Rect2i(int(round(0.0 * w)), int(round((1.0 - 1.0) * h)), int(round(0.3291016 * w)), int(round(0.3974609 * h))),
		"Sand": Rect2i(int(round(0.3310547 * w)), int(round((1.0 - 1.0) * h)), int(round(0.3291016 * w)), int(round(0.3974609 * h))),
		"Corn": Rect2i(int(round(0.6621094 * w)), int(round((1.0 - 1.0) * h)), int(round(0.3291016 * w)), int(round(0.3974609 * h))),
		"Cotton": Rect2i(int(round(0.0 * w)), int(round((1.0 - (0.203125 + 0.3974609)) * h)), int(round(0.3291016 * w)), int(round(0.3974609 * h))),
		"Swamp": Rect2i(int(round(0.3310547 * w)), int(round((1.0 - (0.203125 + 0.3974609)) * h)), int(round(0.3291016 * w)), int(round(0.3974609 * h))),
		"Frame": Rect2i(int(round(0.6621094 * w)), int(round((1.0 - (0.2099609 + 0.390625)) * h)), int(round(0.2744141 * w)), int(round(0.390625 * h)))
	}

	for name in sprites:
		var rect: Rect2i = sprites[name]
		var sub_img = img.get_region(rect)
		var out_path = "res://assets/textures/landscapes/%s.png" % name
		var err = sub_img.save_png(out_path)
		print("Saved ", out_path, " (", rect.size.x, "x", rect.size.y, ") err: ", err)

	quit(0)
