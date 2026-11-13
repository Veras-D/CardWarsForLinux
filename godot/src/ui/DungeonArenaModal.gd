extends Control

@onready var close_btn: Button = $Panel/VBox/Header/CloseBtn
@onready var tab_dungeons_btn: Button = $Panel/VBox/TabBar/DungeonsTabBtn
@onready var tab_elfisto_btn: Button = $Panel/VBox/TabBar/ElFistoTabBtn

# Dungeons Tab elements
@onready var dungeons_container: Control = $Panel/VBox/ContentArea/DungeonsView
@onready var weekday_bar: HBoxContainer = $Panel/VBox/ContentArea/DungeonsView/WeekdayBar
@onready var dungeon_title: Label = $Panel/VBox/ContentArea/DungeonsView/DungeonInfo/Title
@onready var dungeon_desc: Label = $Panel/VBox/ContentArea/DungeonsView/DungeonInfo/Desc
@onready var stages_list: VBoxContainer = $Panel/VBox/ContentArea/DungeonsView/StagesScroll/StagesList

# El Fisto Tab elements
@onready var elfisto_container: Control = $Panel/VBox/ContentArea/ElFistoView
@onready var elfisto_status_label: Label = $Panel/VBox/ContentArea/ElFistoView/StatsPanel/VBox/StatusLabel
@onready var elfisto_hp_label: Label = $Panel/VBox/ContentArea/ElFistoView/StatsPanel/VBox/HpLabel
@onready var elfisto_record_label: Label = $Panel/VBox/ContentArea/ElFistoView/StatsPanel/VBox/RecordLabel
@onready var elfisto_action_btn: Button = $Panel/VBox/ContentArea/ElFistoView/ActionBtn
@onready var elfisto_ladder_list: VBoxContainer = $Panel/VBox/ContentArea/ElFistoView/LadderScroll/LadderList

var selected_weekday: int = 1 # 1=Mon, ..., 6=Sat, 0=Sun


func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(func(): visible = false)
	if tab_dungeons_btn:
		tab_dungeons_btn.pressed.connect(func(): show_tab(0))
	if tab_elfisto_btn:
		tab_elfisto_btn.pressed.connect(func(): show_tab(1))
	if elfisto_action_btn:
		elfisto_action_btn.pressed.connect(_on_elfisto_action_pressed)

	# Set default selected weekday to system weekday
	var dt = Time.get_date_dict_from_system()
	selected_weekday = int(dt.get("weekday", 1))

	_setup_weekday_bar()
	show_tab(0)
	refresh_views()


func show_tab(tab_index: int) -> void:
	if dungeons_container:
		dungeons_container.visible = (tab_index == 0)
	if elfisto_container:
		elfisto_container.visible = (tab_index == 1)

	if tab_dungeons_btn:
		tab_dungeons_btn.modulate = Color(1.0, 1.0, 1.0) if tab_index == 0 else Color(0.6, 0.6, 0.6)
	if tab_elfisto_btn:
		tab_elfisto_btn.modulate = Color(1.0, 1.0, 1.0) if tab_index == 1 else Color(0.6, 0.6, 0.6)

	refresh_views()


func _setup_weekday_bar() -> void:
	if weekday_bar == null:
		return
	for c in weekday_bar.get_children():
		weekday_bar.remove_child(c)
		c.queue_free()

	# Days order: Mon(1), Tue(2), Wed(3), Thu(4), Fri(5), Sat(6), Sun(0)
	var days = [
		{"name": "Mon", "val": 1},
		{"name": "Tue", "val": 2},
		{"name": "Wed", "val": 3},
		{"name": "Thu", "val": 4},
		{"name": "Fri", "val": 5},
		{"name": "Sat", "val": 6},
		{"name": "Sun", "val": 0}
	]

	var sys_day = Time.get_date_dict_from_system().get("weekday", 1)

	for d in days:
		var btn = Button.new()
		var dval = int(d["val"])
		var prefix = "★ " if dval == sys_day else ""
		btn.text = prefix + str(d["name"])
		btn.custom_minimum_size = Vector2(70, 32)
		btn.pressed.connect(func():
			selected_weekday = dval
			_update_weekday_buttons()
			_refresh_dungeons_tab()
		)
		weekday_bar.add_child(btn)

	_update_weekday_buttons()


func _update_weekday_buttons() -> void:
	if weekday_bar == null:
		return
	var days_order = [1, 2, 3, 4, 5, 6, 0]
	var children = weekday_bar.get_children()
	for i in range(min(children.size(), days_order.size())):
		var btn = children[i] as Button
		if btn:
			var is_sel = (days_order[i] == selected_weekday)
			btn.modulate = Color(1.0, 0.9, 0.3) if is_sel else Color(0.8, 0.8, 0.8)


func refresh_views() -> void:
	_refresh_dungeons_tab()
	_refresh_elfisto_tab()


func _refresh_dungeons_tab() -> void:
	if dungeons_container == null or not dungeons_container.visible:
		return

	var d_data = Database.get_dungeon_for_weekday(selected_weekday)
	if d_data.is_empty():
		return

	var d_name = str(d_data.get("dungeon", "Daily Dungeon"))
	if dungeon_title:
		dungeon_title.text = "🏛️ " + d_name.to_upper()
	if dungeon_desc:
		var raw_info = str(d_data.get("info", ""))
		dungeon_desc.text = tr(raw_info) if raw_info != "" else "Complete daily stages to earn bonus cards & materials."

	# Populate 5 stages
	if stages_list:
		for c in stages_list.get_children():
			stages_list.remove_child(c)
			c.queue_free()

		var stages = Database.get_dungeon_stages(d_name)
		for i in range(stages.size()):
			var s = stages[i]
			var qid = str(s.get("quest_id", ""))
			var h_cost = int(s.get("heart_cost", 5))
			var quest = Database.get_quest(qid)
			var is_unlocked = GameManager.is_dungeon_stage_unlocked(d_name, i)

			var hbox = HBoxContainer.new()
			hbox.custom_minimum_size = Vector2(0, 42)

			var lbl = Label.new()
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var opp_name = quest.get("opponent", "Opponent")
			lbl.text = "Stage %d: vs %s (Lv %d) • Cost: %d⚡" % [i + 1, opp_name, quest.get("leader_level", 1), h_cost]

			var play_btn = Button.new()
			play_btn.custom_minimum_size = Vector2(140, 36)
			if is_unlocked:
				play_btn.text = "⚔️ Battle"
				play_btn.pressed.connect(func(): _on_launch_dungeon_stage(d_name, i, qid))
			else:
				play_btn.text = "🔒 Locked"
				play_btn.disabled = true

			hbox.add_child(lbl)
			hbox.add_child(play_btn)
			stages_list.add_child(hbox)


func _on_launch_dungeon_stage(dungeon_name: String, stage_index: int, quest_id: String) -> void:
	visible = false
	GameManager.complete_dungeon_stage(dungeon_name, stage_index)
	GameManager.launch_quest_battle(quest_id)


func _refresh_elfisto_tab() -> void:
	if elfisto_container == null or not elfisto_container.visible:
		return

	var is_run = GameManager.elfisto_is_active_run
	var cur_round = GameManager.elfisto_current_round
	var hp_curr = GameManager.elfisto_hero_hp_current
	var hp_max = GameManager.player_hero_max_hp
	if hp_curr < 0:
		hp_curr = hp_max

	if elfisto_status_label:
		elfisto_status_label.text = "🥊 Status: %s (Round %d / 8)" % [
			("IN PROGRESS" if is_run else "READY TO ENTER"),
			cur_round
		]
	if elfisto_hp_label:
		elfisto_hp_label.text = "❤️ Survival HP: %d / %d" % [hp_curr, hp_max]
		elfisto_hp_label.modulate = Color(0.4, 1.0, 0.4) if hp_curr > (hp_max * 0.5) else Color(1.0, 0.3, 0.3)
	if elfisto_record_label:
		elfisto_record_label.text = "🏆 Highest Round: %d | 🔥 Win Streak: %d" % [
			GameManager.elfisto_highest_round,
			GameManager.elfisto_consecutive_wins
		]

	if elfisto_action_btn:
		if is_run:
			elfisto_action_btn.text = "⚔️ Fight Round %d" % cur_round
		else:
			elfisto_action_btn.text = "🥊 Enter El Fisto Arena (Round 1)"

	# Populate ladder list
	if elfisto_ladder_list:
		for c in elfisto_ladder_list.get_children():
			elfisto_ladder_list.remove_child(c)
			c.queue_free()

		var rounds = Database.get_elfisto_rounds()
		for r in rounds:
			var r_num = int(r.get("round", 1))
			var r_rew = str(r.get("reward_type", ""))
			var r_qty = int(r.get("reward_quantity", 1))
			var _qid = str(r.get("quest_id", ""))

			var hbox = HBoxContainer.new()
			hbox.custom_minimum_size = Vector2(0, 32)

			var is_current = (is_run and r_num == cur_round)
			var is_cleared = (r_num < cur_round)

			var mark = "👉 " if is_current else ("✓ " if is_cleared else "• ")
			var lbl = Label.new()
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.text = "%sRound %d: Reward: %s (x%d)" % [mark, r_num, r_rew.replace("Card Creature_GL_", "Card: "), r_qty]

			if is_current:
				lbl.modulate = Color(1.0, 0.9, 0.2)
			elif is_cleared:
				lbl.modulate = Color(0.5, 0.8, 0.5)
			else:
				lbl.modulate = Color(0.7, 0.7, 0.7)

			hbox.add_child(lbl)
			elfisto_ladder_list.add_child(hbox)


func _on_elfisto_action_pressed() -> void:
	if not GameManager.elfisto_is_active_run:
		GameManager.start_elfisto_run()

	var cur_round = GameManager.elfisto_current_round
	var r_data = Database.get_elfisto_round(cur_round)
	var qid = str(r_data.get("quest_id", "7001"))

	visible = false
	GameManager.launch_quest_battle(qid)


func open_modal() -> void:
	visible = true
	refresh_views()
