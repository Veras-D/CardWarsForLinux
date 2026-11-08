class_name EconomyHeader
extends PanelContainer

## Live Economy & Hero Progression Header Component (Task 8.1)
## Automatically subscribes to GameManager currency and hero progression signals
## to keep Gold, Gems, and Active Hero Level displayed and updated in real time.

@onready var hero_name_lbl: Label = $Margin/HBox/HeroGroup/VBox/HeroName
@onready var hero_level_lbl: Label = $Margin/HBox/HeroGroup/VBox/HeroLevel
@onready var hero_xp_bar: ProgressBar = $Margin/HBox/HeroGroup/VBox/XPBar
@onready var coins_lbl: Label = $Margin/HBox/Currencies/CoinsPill/Label
@onready var gems_lbl: Label = $Margin/HBox/Currencies/GemsPill/Label


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if GameManager:
		GameManager.player_currencies_updated.connect(_on_currencies_updated)
		GameManager.hero_leveled_up.connect(_on_hero_leveled_up)
	refresh()


func refresh() -> void:
	if GameManager == null:
		return
	_update_currencies(GameManager.get_coins(), GameManager.get_gems())
	_update_hero()


func _update_currencies(coins: int, gems: int) -> void:
	if coins_lbl:
		coins_lbl.text = "🪙 %s" % _format_number(coins)
	if gems_lbl:
		gems_lbl.text = "💎 %s" % _format_number(gems)


func _update_hero() -> void:
	if GameManager == null:
		return
	var h_name = GameManager.player_hero_name
	var lvl = GameManager.get_hero_level(h_name)
	var max_hp = GameManager.get_hero_max_hp(h_name)
	var tracker = GameManager.get_hero_tracker(h_name)

	if hero_name_lbl:
		hero_name_lbl.text = h_name
	if hero_level_lbl:
		hero_level_lbl.text = "Lv. %d (HP: %d)" % [lvl, max_hp]
	if hero_xp_bar:
		hero_xp_bar.value = tracker.get_progress_ratio() * 100.0


func _on_currencies_updated(coins: int, gems: int) -> void:
	_update_currencies(coins, gems)


func _on_hero_leveled_up(_hero_id: String, _old_lvl: int, _new_lvl: int, _new_hp: int) -> void:
	_update_hero()


func _format_number(val: int) -> String:
	var s = str(val)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res
