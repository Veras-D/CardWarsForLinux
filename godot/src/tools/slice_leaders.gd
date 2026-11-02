extends SceneTree

func _init() -> void:
	print("==> Extracting true 2D leader portraits...")
	var atlas_path = "../Assets/Texture2D/CharacterIconAtlas.png"
	var img = Image.load_from_file(atlas_path)
	if not img:
		print("Error: Could not load CharacterIconAtlas.png")
		quit(1)
		return

	# Finn Hero: x=514, y=677, w=256, h=256
	var finn_rect = Rect2i(514, 677, 256, 256)
	var finn_img = img.get_region(finn_rect)
	finn_img.save_png("res://assets/textures/leaders/Finn.png")
	print("Saved Finn.png: ", finn_rect)

	# Jake Hero: x=257, y=934, w=256, h=256
	var jake_rect = Rect2i(257, 934, 256, 256)
	var jake_img = img.get_region(jake_rect)
	jake_img.save_png("res://assets/textures/leaders/Jake.png")
	print("Saved Jake.png: ", jake_rect)

	# Also save round variants for icon usage
	var finn_round = img.get_region(Rect2i(1415, 675, 128, 128))
	finn_round.save_png("res://assets/textures/leaders/Finn_Round.png")

	var jake_round = img.get_region(Rect2i(1286, 1062, 128, 128))
	jake_round.save_png("res://assets/textures/leaders/Jake_Round.png")

	quit(0)
