extends Control
class_name DeckBuilder

## Deck Builder Interface (Task 6.1)
## Supports filtering all 416 cards by Faction, Type, Cost, and Search query,
## live Mana Curve Bar Chart (0..5+ MP), legal Deck Validator (10-25 cards, max 4 copies),
## Leader & 4-Lane Landscape configuration, and saving/loading custom decks to user://decks/*.json.

const DeckValidator = preload("res://src/cards/DeckValidator.gd")
const FusionEngine = preload("res://src/cards/FusionEngine.gd")
const CardViewScene = preload("res://scenes/components/CardView.tscn")

signal deck_saved(deck_name: String, file_path: String)
signal deck_loaded(deck_name: String)
signal card_fused(output_card_id: String)

const AVAILABLE_LEADERS: Array[String] = [
	"Finn",
	"Jake",
	"PrincessBubblegum",
	"Marceline",
	"IceKing",
	"FlamePrincess",
	"BMO",
	"LumpySpacePrincess",
	"EarlOfLemongrab",
	"HunsonAbadeer",
	"MagicMan",
	"Fiona",
	"Cake"
]

const LANDSCAPES: Array[String] = ["Plains", "Corn", "Swamp", "Sand", "Cotton"]

# State
var current_deck_name: String = "Finn Starter Deck"
var current_leader_id: String = "Finn"
var current_landscapes: Array[String] = ["Plains", "Plains", "Cotton", "Plains"]
var current_deck_cards: Array[String] = []

var selected_faction: String = "ALL"
var selected_type: String = "ALL"
var selected_cost: int = -1
var search_text: String = ""

var max_grid_render: int = 80 # Cap live Node instantiation per page/query for instant responsiveness

# UI References
@onready var back_btn: Button = $MainVBox/TopBar/HBox/BackBtn
@onready var deck_name_edit: LineEdit = $MainVBox/TopBar/HBox/DeckNameEdit
@onready var preset_select: OptionButton = $MainVBox/TopBar/HBox/PresetSelect
@onready var save_btn: Button = $MainVBox/TopBar/HBox/SaveBtn
@onready var fusion_btn: Button = $MainVBox/TopBar/HBox/FusionBtn
@onready var clear_btn: Button = $MainVBox/TopBar/HBox/ClearBtn
@onready var status_banner: Label = $MainVBox/TopBar/StatusBanner

@onready var fusion_modal: Panel = $FusionModal
@onready var fusion_coins_label: Label = $FusionModal/VBox/Header/CoinsLabel
@onready var close_fusion_btn: Button = $FusionModal/VBox/Header/CloseFusionBtn
@onready var fusion_search_edit: LineEdit = $FusionModal/VBox/FilterBar/FusionSearchEdit
@onready var quality_filter_select: OptionButton = $FusionModal/VBox/FilterBar/QualityFilterSelect
@onready var fusion_status_label: Label = $FusionModal/VBox/FilterBar/FusionStatusLabel
@onready var recipe_list_vbox: VBoxContainer = $FusionModal/VBox/RecipeScroll/RecipeListVBox

var fusion_search_text: String = ""
var selected_fusion_quality: int = -1 # -1 = ALL, 0 = Standard, 1 = Gold, 2 = Obsidian

@onready var search_edit: LineEdit = $MainVBox/ContentSplit/LeftCollection/FilterRow/SearchEdit
@onready var faction_select: OptionButton = $MainVBox/ContentSplit/LeftCollection/FilterRow/FactionSelect
@onready var type_select: OptionButton = $MainVBox/ContentSplit/LeftCollection/FilterRow/TypeSelect
@onready var cost_select: OptionButton = $MainVBox/ContentSplit/LeftCollection/FilterRow/CostSelect
@onready var collection_count_label: Label = $MainVBox/ContentSplit/LeftCollection/FilterRow/CollectionCountLabel
@onready var collection_grid: GridContainer = $MainVBox/ContentSplit/LeftCollection/Scroll/CollectionGrid

@onready var leader_select: OptionButton = $MainVBox/ContentSplit/RightDeckPanel/ConfigBox/LeaderRow/LeaderSelect
@onready var lane0_btn: Button = $MainVBox/ContentSplit/RightDeckPanel/ConfigBox/LandscapesRow/Lane0Btn
@onready var lane1_btn: Button = $MainVBox/ContentSplit/RightDeckPanel/ConfigBox/LandscapesRow/Lane1Btn
@onready var lane2_btn: Button = $MainVBox/ContentSplit/RightDeckPanel/ConfigBox/LandscapesRow/Lane2Btn
@onready var lane3_btn: Button = $MainVBox/ContentSplit/RightDeckPanel/ConfigBox/LandscapesRow/Lane3Btn

@onready var mana_bars_box: HBoxContainer = $MainVBox/ContentSplit/RightDeckPanel/ManaCurveBox/BarsHBox
@onready var deck_count_label: Label = $MainVBox/ContentSplit/RightDeckPanel/DeckHeaderRow/DeckCountLabel
@onready var validation_label: Label = $MainVBox/ContentSplit/RightDeckPanel/DeckHeaderRow/ValidationLabel
@onready var deck_list_vbox: VBoxContainer = $MainVBox/ContentSplit/RightDeckPanel/DeckScroll/DeckListVBox


func _ready() -> void:
	# Initialize state from GameManager
	current_deck_name = GameManager.active_deck_name
	current_leader_id = GameManager.player_hero_name
	current_landscapes = GameManager.player_landscapes.duplicate()
	while current_landscapes.size() < 4:
		current_landscapes.append("Plains")
	current_deck_cards = GameManager.player_deck.duplicate()

	_setup_filter_controls()
	_setup_leader_and_landscape_controls()
	_connect_signals()
	_refresh_saved_decks_dropdown()

	if deck_name_edit:
		deck_name_edit.text = current_deck_name

	refresh_all()


func _setup_filter_controls() -> void:
	if faction_select:
		faction_select.clear()
		for f in ["ALL", "Corn", "Plains", "Swamp", "Sand", "Cotton", "Universal"]:
			faction_select.add_item("Faction: " + f)
			faction_select.set_item_metadata(faction_select.item_count - 1, f)

	if type_select:
		type_select.clear()
		for t in ["ALL", "CREATURE", "SPELL", "BUILDING"]:
			type_select.add_item("Type: " + t)
			type_select.set_item_metadata(type_select.item_count - 1, t)

	if cost_select:
		cost_select.clear()
		cost_select.add_item("Cost: ALL")
		cost_select.set_item_metadata(0, -1)
		for c in range(0, 5):
			cost_select.add_item("Cost: %d MP" % c)
			cost_select.set_item_metadata(cost_select.item_count - 1, c)
		cost_select.add_item("Cost: 5+ MP")
		cost_select.set_item_metadata(cost_select.item_count - 1, 5)

	if quality_filter_select:
		quality_filter_select.clear()
		quality_filter_select.add_item("Quality: ALL")
		quality_filter_select.set_item_metadata(0, -1)
		quality_filter_select.add_item("Quality: Standard")
		quality_filter_select.set_item_metadata(1, FusionEngine.QualityTier.STANDARD)
		quality_filter_select.add_item("✨ Quality: Gold (+10%)")
		quality_filter_select.set_item_metadata(2, FusionEngine.QualityTier.GOLD)
		quality_filter_select.add_item("🔮 Quality: Obsidian (+25%)")
		quality_filter_select.set_item_metadata(3, FusionEngine.QualityTier.OBSIDIAN)


func _setup_leader_and_landscape_controls() -> void:
	if leader_select:
		leader_select.clear()
		var selected_idx = 0
		for i in range(AVAILABLE_LEADERS.size()):
			var lid = AVAILABLE_LEADERS[i]
			var l_data = Database.get_leader(lid)
			var l_title = l_data.get("name", lid) if not l_data.is_empty() else lid
			leader_select.add_item("%s (%s)" % [l_title, lid])
			leader_select.set_item_metadata(i, lid)
			if lid == current_leader_id:
				selected_idx = i
		leader_select.select(selected_idx)

	_update_landscape_buttons()


func _connect_signals() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)
	if fusion_btn:
		fusion_btn.pressed.connect(open_fusion_modal)
	if close_fusion_btn:
		close_fusion_btn.pressed.connect(close_fusion_modal)
	if fusion_search_edit:
		fusion_search_edit.text_changed.connect(func(q):
			fusion_search_text = q
			refresh_fusion_modal()
		)
	if quality_filter_select:
		quality_filter_select.item_selected.connect(func(idx):
			selected_fusion_quality = int(quality_filter_select.get_item_metadata(idx))
			refresh_fusion_modal()
		)
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_pressed)
	if deck_name_edit:
		deck_name_edit.text_changed.connect(func(new_text): current_deck_name = new_text)
	if preset_select:
		preset_select.item_selected.connect(_on_preset_selected)

	if search_edit:
		search_edit.text_changed.connect(func(q):
			search_text = q
			refresh_collection_grid()
		)
	if faction_select:
		faction_select.item_selected.connect(func(idx):
			selected_faction = str(faction_select.get_item_metadata(idx))
			refresh_collection_grid()
		)
	if type_select:
		type_select.item_selected.connect(func(idx):
			selected_type = str(type_select.get_item_metadata(idx))
			refresh_collection_grid()
		)
	if cost_select:
		cost_select.item_selected.connect(func(idx):
			selected_cost = int(cost_select.get_item_metadata(idx))
			refresh_collection_grid()
		)
	if leader_select:
		leader_select.item_selected.connect(func(idx):
			current_leader_id = str(leader_select.get_item_metadata(idx))
		)

	if lane0_btn:
		lane0_btn.pressed.connect(func(): _cycle_landscape(0))
	if lane1_btn:
		lane1_btn.pressed.connect(func(): _cycle_landscape(1))
	if lane2_btn:
		lane2_btn.pressed.connect(func(): _cycle_landscape(2))
	if lane3_btn:
		lane3_btn.pressed.connect(func(): _cycle_landscape(3))


func _cycle_landscape(lane_idx: int) -> void:
	if lane_idx < 0 or lane_idx >= current_landscapes.size():
		return
	var cur = current_landscapes[lane_idx]
	var pos = LANDSCAPES.find(cur)
	var next_land = LANDSCAPES[(pos + 1) % LANDSCAPES.size()]
	current_landscapes[lane_idx] = next_land
	_update_landscape_buttons()


func _update_landscape_buttons() -> void:
	var btns = [lane0_btn, lane1_btn, lane2_btn, lane3_btn]
	for i in range(4):
		if btns[i] != null and i < current_landscapes.size():
			btns[i].text = "L%d: %s" % [i + 1, current_landscapes[i]]


func refresh_all() -> void:
	refresh_collection_grid()
	refresh_deck_panel()


func get_filtered_collection() -> Array:
	return DeckValidator.filter_cards(
		Database.all_cards_list,
		selected_faction,
		selected_type,
		selected_cost,
		search_text,
		false,
		GameManager.get_owned_card_counts()
	)


func refresh_collection_grid() -> void:
	if collection_grid == null:
		return

	for child in collection_grid.get_children():
		collection_grid.remove_child(child)
		child.queue_free()

	var filtered = get_filtered_collection()
	if collection_count_label:
		collection_count_label.text = "%d / %d Cards" % [filtered.size(), Database.all_cards_list.size()]

	var val_res = DeckValidator.validate_deck(current_deck_cards)
	var counts_by_id: Dictionary = val_res.get("counts_by_id", {})

	var render_limit = min(filtered.size(), max_grid_render)
	for i in range(render_limit):
		var c_data: Dictionary = filtered[i]
		var cid = str(c_data.get("id", ""))
		var in_deck: int = int(counts_by_id.get(cid, 0))

		var slot_vbox = VBoxContainer.new()
		slot_vbox.custom_minimum_size = Vector2(136, 212)
		slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		collection_grid.add_child(slot_vbox)

		var card_view = CardViewScene.instantiate() as CardView
		slot_vbox.add_child(card_view)
		card_view.render_card(c_data)
		card_view.card_clicked.connect(func(_cv): add_card_to_deck(cid))

		var add_btn = Button.new()
		add_btn.custom_minimum_size = Vector2(130, 26)
		add_btn.text = "+ Add (%d/%d)" % [in_deck, DeckValidator.MAX_COPIES_PER_CARD]
		add_btn.disabled = (in_deck >= DeckValidator.MAX_COPIES_PER_CARD) or (current_deck_cards.size() >= DeckValidator.MAX_DECK_SIZE)
		add_btn.pressed.connect(func(): add_card_to_deck(cid))
		slot_vbox.add_child(add_btn)


func refresh_deck_panel() -> void:
	var val_res = DeckValidator.validate_deck(current_deck_cards)
	var is_valid: bool = val_res.get("valid", false)
	var errors: Array = val_res.get("errors", [])
	var counts_by_id: Dictionary = val_res.get("counts_by_id", {})
	var breakdown: Dictionary = DeckValidator.compute_type_breakdown(current_deck_cards)

	if deck_count_label:
		deck_count_label.text = "Deck: %d / %d Cards (Min %d) • C:%d S:%d B:%d" % [
			current_deck_cards.size(),
			DeckValidator.MAX_DECK_SIZE,
			DeckValidator.MIN_DECK_SIZE,
			breakdown.get("CREATURE", 0),
			breakdown.get("SPELL", 0),
			breakdown.get("BUILDING", 0)
		]

	if validation_label:
		if is_valid:
			validation_label.text = "✅ Legal Deck"
			validation_label.modulate = Color(0.25, 0.95, 0.45, 1.0)
		else:
			validation_label.text = "⚠️ " + (str(errors[0]) if not errors.is_empty() else "Invalid Deck")
			validation_label.modulate = Color(1.0, 0.45, 0.4, 1.0)

	if save_btn:
		save_btn.disabled = not is_valid

	_refresh_mana_curve()
	_refresh_deck_card_rows(counts_by_id)


func _refresh_mana_curve() -> void:
	if mana_bars_box == null:
		return

	var curve = DeckValidator.compute_mana_curve(current_deck_cards)
	var max_bin_count: int = 1
	for k in curve.keys():
		if int(curve[k]) > max_bin_count:
			max_bin_count = int(curve[k])

	for child in mana_bars_box.get_children():
		mana_bars_box.remove_child(child)
		child.queue_free()

	for bin_cost in range(0, 6):
		var count: int = int(curve.get(bin_cost, 0))
		var col = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_END

		var count_lbl = Label.new()
		count_lbl.text = str(count)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_size_override("font_size", 11)
		col.add_child(count_lbl)

		var bar_track = Control.new()
		bar_track.custom_minimum_size = Vector2(22, 48)
		var bar_fill = ColorRect.new()
		var ratio = float(count) / float(max_bin_count) if count > 0 else 0.05
		var bar_h = roundi(clampf(ratio * 44.0, 3.0, 44.0))
		bar_fill.color = Color(0.22, 0.65, 0.98, 1.0) if count > 0 else Color(0.25, 0.3, 0.38, 0.5)
		bar_fill.size = Vector2(20, bar_h)
		bar_fill.position = Vector2(4, 48 - bar_h)
		bar_track.add_child(bar_fill)
		col.add_child(bar_track)

		var cost_lbl = Label.new()
		cost_lbl.text = "%d+" % bin_cost if bin_cost == 5 else "%dMP" % bin_cost
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 10)
		col.add_child(cost_lbl)

		mana_bars_box.add_child(col)


func _refresh_deck_card_rows(counts_by_id: Dictionary) -> void:
	if deck_list_vbox == null:
		return

	for child in deck_list_vbox.get_children():
		deck_list_vbox.remove_child(child)
		child.queue_free()

	var unique_ids = counts_by_id.keys()
	unique_ids.sort_custom(func(a, b):
		var ca = Database.get_card(str(a))
		var cb = Database.get_card(str(b))
		var cost_a = int(ca.get("cost", 0))
		var cost_b = int(cb.get("cost", 0))
		if cost_a != cost_b:
			return cost_a < cost_b
		return str(ca.get("name", a)) < str(cb.get("name", b))
	)

	for raw_id in unique_ids:
		var cid = str(raw_id)
		var qty: int = int(counts_by_id[cid])
		var c_data = Database.get_card(cid)
		var c_name = str(c_data.get("name", cid))
		var c_cost = int(c_data.get("cost", 1))
		var c_faction = str(c_data.get("faction", "Universal"))

		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 30)

		var cost_badge = Label.new()
		cost_badge.custom_minimum_size = Vector2(36, 0)
		cost_badge.text = "[%dMP]" % c_cost
		cost_badge.modulate = Color(0.45, 0.8, 1.0, 1.0)
		row.add_child(cost_badge)

		var title_lbl = Label.new()
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.text = "%s (%s)" % [c_name, c_faction]
		title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(title_lbl)

		var qty_lbl = Label.new()
		qty_lbl.custom_minimum_size = Vector2(38, 0)
		qty_lbl.text = "x%d" % qty
		qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(qty_lbl)

		var minus_btn = Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(28, 26)
		minus_btn.pressed.connect(func(): remove_card_from_deck(cid))
		row.add_child(minus_btn)

		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(28, 26)
		plus_btn.disabled = (qty >= DeckValidator.MAX_COPIES_PER_CARD) or (current_deck_cards.size() >= DeckValidator.MAX_DECK_SIZE)
		plus_btn.pressed.connect(func(): add_card_to_deck(cid))
		row.add_child(plus_btn)

		deck_list_vbox.add_child(row)


func add_card_to_deck(card_id: String) -> bool:
	var check = DeckValidator.can_add_card(current_deck_cards, card_id)
	if not check.get("can_add", false):
		_set_status("⚠️ " + str(check.get("reason", "Cannot add card.")), Color(1.0, 0.55, 0.3, 1.0))
		return false

	current_deck_cards.append(card_id)
	var c_info = Database.get_card(card_id)
	_set_status("➕ Added '%s' (%d/%d cards)." % [c_info.get("name", card_id), current_deck_cards.size(), DeckValidator.MAX_DECK_SIZE], Color(0.6, 0.9, 1.0, 1.0))
	refresh_all()
	return true


func remove_card_from_deck(card_id: String) -> bool:
	var idx = current_deck_cards.find(card_id)
	if idx == -1:
		return false
	current_deck_cards.remove_at(idx)
	var c_info = Database.get_card(card_id)
	_set_status("➖ Removed '%s' (%d/%d cards)." % [c_info.get("name", card_id), current_deck_cards.size(), DeckValidator.MAX_DECK_SIZE], Color(0.85, 0.85, 0.85, 1.0))
	refresh_all()
	return true


func clear_deck() -> void:
	current_deck_cards.clear()
	_set_status("🗑️ Cleared deck cards.", Color(0.9, 0.75, 0.4, 1.0))
	refresh_all()


func save_current_deck(custom_dir: String = DeckValidator.DECKS_DIR) -> Dictionary:
	if deck_name_edit and deck_name_edit.text.strip_edges() != "":
		current_deck_name = deck_name_edit.text.strip_edges()

	var res = DeckValidator.save_deck_to_file(
		current_deck_name,
		current_leader_id,
		current_landscapes,
		current_deck_cards,
		custom_dir
	)
	if res.get("ok", false):
		var payload = res.get("payload", {})
		GameManager.apply_custom_deck(payload)
		_refresh_saved_decks_dropdown(custom_dir)
		_set_status("💾 Saved & equipped deck '%s' (%s)!" % [current_deck_name, res.get("path", "")], Color(0.3, 0.98, 0.5, 1.0))
		deck_saved.emit(current_deck_name, str(res.get("path", "")))
	else:
		var errs = res.get("errors", ["Invalid deck."])
		_set_status("❌ Cannot save: " + str(errs[0]), Color(1.0, 0.4, 0.4, 1.0))
	return res


func load_saved_deck(path_or_slug: String, custom_dir: String = DeckValidator.DECKS_DIR) -> bool:
	var data = DeckValidator.load_deck_from_file(path_or_slug, custom_dir)
	if data.is_empty():
		_set_status("❌ Failed to load deck '%s'." % path_or_slug, Color(1.0, 0.4, 0.4, 1.0))
		return false

	current_deck_name = str(data.get("name", "Custom Deck"))
	if deck_name_edit:
		deck_name_edit.text = current_deck_name

	current_leader_id = str(data.get("leader", "Finn"))
	current_landscapes.clear()
	for l in data.get("landscapes", ["Plains", "Plains", "Cotton", "Plains"]):
		current_landscapes.append(str(l))
	while current_landscapes.size() < 4:
		current_landscapes.append("Plains")

	current_deck_cards.clear()
	for c in data.get("cards", []):
		current_deck_cards.append(str(c))

	_setup_leader_and_landscape_controls()
	GameManager.apply_custom_deck(data)
	refresh_all()
	_set_status("📂 Loaded & equipped deck '%s' (%d cards)." % [current_deck_name, current_deck_cards.size()], Color(0.4, 0.95, 0.6, 1.0))
	deck_loaded.emit(current_deck_name)
	return true


func _refresh_saved_decks_dropdown(custom_dir: String = DeckValidator.DECKS_DIR) -> void:
	if preset_select == null:
		return
	preset_select.clear()
	preset_select.add_item("📂 Load Saved / Preset Deck...")
	preset_select.set_item_metadata(0, {"type": "NONE"})

	# Saved user decks
	var saved = DeckValidator.list_saved_decks(custom_dir)
	for s in saved:
		var label = "💾 %s (%d cards)" % [s.get("name", "Deck"), s.get("cards", []).size()]
		preset_select.add_item(label)
		preset_select.set_item_metadata(preset_select.item_count - 1, {
			"type": "USER",
			"slug": s.get("slug", "")
		})

	# Built-in starter presets from db_Decks.json
	for preset_id in ["Quest_1_Deck", "Player_Finn_Deck", "Player_Jake_Deck"]:
		if Database.preset_decks_db.has(preset_id):
			var p_cards = Database.get_preset_deck(preset_id)
			if p_cards.size() >= DeckValidator.MIN_DECK_SIZE and p_cards.size() <= DeckValidator.MAX_DECK_SIZE:
				preset_select.add_item("⭐ Preset: %s (%d cards)" % [preset_id, p_cards.size()])
				preset_select.set_item_metadata(preset_select.item_count - 1, {
					"type": "PRESET",
					"preset_id": preset_id
				})


func _on_preset_selected(idx: int) -> void:
	if preset_select == null or idx <= 0:
		return
	var meta = preset_select.get_item_metadata(idx)
	if typeof(meta) != TYPE_DICTIONARY:
		return
	var m_type = str(meta.get("type", "NONE"))
	if m_type == "USER":
		load_saved_deck(str(meta.get("slug", "")))
	elif m_type == "PRESET":
		var pid = str(meta.get("preset_id", ""))
		var p_cards = Database.get_preset_deck(pid)
		if not p_cards.is_empty():
			current_deck_name = pid
			if deck_name_edit:
				deck_name_edit.text = current_deck_name
			current_deck_cards.clear()
			for c in p_cards:
				if current_deck_cards.size() < DeckValidator.MAX_DECK_SIZE:
					current_deck_cards.append(str(c))
			refresh_all()
			_set_status("⭐ Loaded preset '%s'." % pid, Color(0.5, 0.9, 1.0, 1.0))


func _on_save_pressed() -> void:
	save_current_deck()


func _on_clear_pressed() -> void:
	clear_deck()


func _on_back_pressed() -> void:
	GameManager.return_to_menu()


func open_fusion_modal() -> void:
	if fusion_modal:
		fusion_modal.visible = true
		refresh_fusion_modal()


func close_fusion_modal() -> void:
	if fusion_modal:
		fusion_modal.visible = false


func refresh_fusion_modal() -> void:
	if recipe_list_vbox == null:
		return

	if fusion_coins_label:
		fusion_coins_label.text = "🪙 %d Coins" % GameManager.player_coins

	for child in recipe_list_vbox.get_children():
		recipe_list_vbox.remove_child(child)
		child.queue_free()

	var owned = GameManager.get_owned_card_counts()
	var q_lower = fusion_search_text.strip_edges().to_lower()
	var shown_count = 0

	for rec in Database.fusion_recipes_list:
		var out_id = str(rec.get("card_id", ""))
		var out_card = Database.get_card(out_id)
		var out_name = str(out_card.get("name", out_id))
		var r_quality = int(rec.get("quality", FusionEngine.QualityTier.STANDARD))

		if selected_fusion_quality >= 0 and r_quality != selected_fusion_quality:
			continue

		if q_lower != "":
			var match_found = (q_lower in out_name.to_lower()) or (q_lower in out_id.to_lower())
			if not match_found:
				for ing in rec.get("ingredients", []):
					var ing_id = str(ing.get("card_id", ""))
					var ing_card = Database.get_card(ing_id)
					var ing_name = str(ing_card.get("name", ing_id))
					if (q_lower in ing_name.to_lower()) or (q_lower in ing_id.to_lower()):
						match_found = true
						break
			if not match_found:
				continue

		shown_count += 1
		if shown_count > 60:
			break

		var check = FusionEngine.can_craft_recipe(rec, owned, GameManager.player_coins)
		var can_craft = check.get("can_craft", false)

		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 34)

		var q_badge = "✨ [GOLD] " if r_quality == FusionEngine.QualityTier.GOLD else ("🔮 [OBSIDIAN] " if r_quality == FusionEngine.QualityTier.OBSIDIAN else "")
		var out_lbl = Label.new()
		out_lbl.custom_minimum_size = Vector2(230, 0)
		out_lbl.text = "%s%s (Own: %d)" % [q_badge, out_name, int(owned.get(out_id, 0))]
		out_lbl.modulate = Color(1.0, 0.9, 0.4, 1.0) if r_quality == FusionEngine.QualityTier.GOLD else Color.WHITE
		row.add_child(out_lbl)

		var ing_parts: Array[String] = []
		for ing in rec.get("ingredients", []):
			var icid = str(ing.get("card_id", ""))
			var ireq = int(ing.get("count", 1))
			var ihave = int(owned.get(icid, 0))
			var icard = Database.get_card(icid)
			var iname = str(icard.get("name", icid))
			ing_parts.append("%s (%d/%d)" % [iname, ihave, ireq])

		var ing_lbl = Label.new()
		ing_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ing_lbl.text = "Requires: " + ", ".join(ing_parts)
		ing_lbl.modulate = Color(0.8, 0.88, 0.96, 1.0)
		row.add_child(ing_lbl)

		var cost_lbl = Label.new()
		cost_lbl.custom_minimum_size = Vector2(95, 0)
		cost_lbl.text = "🪙 %d" % int(rec.get("cost", 0))
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(cost_lbl)

		var fuse_action_btn = Button.new()
		fuse_action_btn.custom_minimum_size = Vector2(95, 28)
		fuse_action_btn.text = "⚗️ Fuse!" if can_craft else "Locked"
		fuse_action_btn.disabled = not can_craft
		fuse_action_btn.pressed.connect(func(): craft_recipe(rec))
		row.add_child(fuse_action_btn)

		recipe_list_vbox.add_child(row)


func craft_recipe(recipe: Dictionary) -> Dictionary:
	var res = GameManager.craft_fusion_recipe(recipe)
	if res.get("ok", false):
		var out_id = str(res.get("output_card_id", ""))
		var out_card = Database.get_card(out_id)
		var out_name = str(out_card.get("name", out_id))
		if fusion_status_label:
			fusion_status_label.text = "✅ Fused %s! Added to inventory." % out_name
			fusion_status_label.modulate = Color(0.3, 0.98, 0.5, 1.0)
		_set_status("⚗️ Fused '%s'!" % out_name, Color(0.3, 0.98, 0.5, 1.0))
		refresh_fusion_modal()
		refresh_all()
		card_fused.emit(out_id)
	else:
		var reason = str(res.get("reason", "Cannot fuse."))
		if fusion_status_label:
			fusion_status_label.text = "⚠️ " + reason
			fusion_status_label.modulate = Color(1.0, 0.45, 0.4, 1.0)
	return res


func _set_status(msg: String, col: Color = Color.WHITE) -> void:
	if status_banner:
		status_banner.text = msg
		status_banner.modulate = col
