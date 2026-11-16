# LanLobbyModal.gd
# Card Wars styled LAN Multiplayer Lobby modal providing UDP Auto-Discovery, Hosting, Direct IP Connect, and Handshake.
class_name LanLobbyModal
extends Control

const LanDiscoveryClass = preload("res://src/systems/network_multiplayer/LanDiscovery.gd")
const NetworkSessionManagerClass = preload("res://src/systems/network_multiplayer/NetworkSessionManager.gd")
const TurnActionProtocolClass = preload("res://src/systems/network_multiplayer/TurnActionProtocol.gd")
const UIStyle = preload("res://src/ui/CardWarsUIStyle.gd")

const SFX_SELECT := preload("res://assets/audio/sfx/UI_Select.wav")
const SFX_BACK := preload("res://assets/audio/sfx/UI_Back.wav")

# Sub-nodes
var discovery: LanDiscoveryClass
var session: NetworkSessionManagerClass
var protocol: TurnActionProtocolClass

@onready var dark_overlay: ColorRect = get_node_or_null("DarkOverlay")
@onready var panel_root: Control = get_node_or_null("LanCanvas/PanelRoot")
@onready var close_x_btn: TextureButton = get_node_or_null("LanCanvas/PanelRoot/CloseBtn")
@onready var close_footer_btn: Button = %CloseFooterBtn

@onready var host_tab_btn: TextureButton = get_node_or_null("LanCanvas/PanelRoot/TabsBar/HostTabBtn")
@onready var host_tab_scale: Control = get_node_or_null("LanCanvas/PanelRoot/TabsBar/HostTabBtn/ScaleRoot")
@onready var join_tab_btn: TextureButton = get_node_or_null("LanCanvas/PanelRoot/TabsBar/JoinTabBtn")
@onready var join_tab_scale: Control = get_node_or_null("LanCanvas/PanelRoot/TabsBar/JoinTabBtn/ScaleRoot")

@onready var host_page: Control = get_node_or_null("LanCanvas/PanelRoot/ContentFrame/HostPage")
@onready var join_page: Control = get_node_or_null("LanCanvas/PanelRoot/ContentFrame/JoinPage")

# UI Controls - Host Tab
@onready var host_name_edit: LineEdit = %RoomNameEdit
@onready var host_hero_option: OptionButton = %HostHeroOption
@onready var host_deck_option: OptionButton = %HostDeckOption
@onready var host_port_edit: LineEdit = %HostPortEdit
@onready var host_start_btn: Button = %HostStartBtn
@onready var host_status_label: Label = %HostStatusLabel

# UI Controls - Join Tab
@onready var scan_btn: Button = %ScanBtn
@onready var server_list: ItemList = %ServerList
@onready var join_hero_option: OptionButton = %JoinHeroOption
@onready var join_deck_option: OptionButton = %JoinDeckOption
@onready var direct_ip_edit: LineEdit = %DirectIpEdit
@onready var direct_port_edit: LineEdit = %DirectPortEdit
@onready var direct_connect_btn: Button = %DirectConnectBtn
@onready var join_status_label: Label = %JoinStatusLabel

var available_heroes: Array[String] = []
const HERO_DISPLAY_NAMES := {
	"Finn": "Finn",
	"Jake": "Jake",
	"Fiona": "Fionna",
	"Fionna": "Fionna",
	"Marceline": "Marceline",
	"PrincessBubblegum": "Princess Bubblegum",
	"IceKing": "Ice King",
	"EarlOfLemongrab": "Earl of Lemongrab",
	"BMO": "BMO",
	"FlamePrincess": "Flame Princess",
}
const SCAN_BURST_SECONDS := 1.8

var available_decks: Array[Dictionary] = []
var _is_hosting: bool = false
var _is_scanning: bool = false
var _scan_elapsed: float = 0.0
var _last_scan_step: int = -1
var _handshake_sent: bool = false
var _remote_handshake_received: bool = false
var _active_tab: int = 0

var _host_green_sb: StyleBox = null
var _stop_red_sb: StyleBox = null


func _ready() -> void:
	visible = false
	set_process(false)
	_setup_network_nodes()
	_apply_card_wars_styling()
	_connect_ui_events()
	_select_tab(0, false)


func _setup_network_nodes() -> void:
	discovery = LanDiscoveryClass.new()
	session = NetworkSessionManagerClass.new()
	protocol = TurnActionProtocolClass.new()

	add_child(discovery)
	add_child(session)
	add_child(protocol)

	discovery.server_discovered.connect(_on_server_discovered)
	discovery.server_expired.connect(_on_server_expired)

	session.session_created.connect(_on_session_created)
	session.peer_connected.connect(_on_peer_connected)
	session.peer_disconnected.connect(_on_peer_disconnected)
	session.connected_to_host.connect(_on_connected_to_host)
	session.connection_failed.connect(_on_connection_failed)
	session.host_disconnected.connect(_on_host_disconnected)

	protocol.handshake_received.connect(_on_handshake_received)


func _apply_card_wars_styling() -> void:
	var arrow_tex := UIStyle.build_resized_texture(UIStyle.TEX_ARROW, Vector2i(32, 32), true)
	var blue_tex := UIStyle.build_resized_texture(UIStyle.TEX_BTN_BLUE, Vector2i(68, 72))
	var blue_sb := UIStyle.make_compact_button_sb(blue_tex, Color.WHITE)
	var blue_hover_sb := UIStyle.make_compact_button_sb(blue_tex, Color(1.14, 1.14, 1.14, 1.0))
	var popup_frame_sb := UIStyle.make_popup_frame_sb()
	var popup_hover_sb := UIStyle.make_popup_hover_sb()

	for ob in [host_hero_option, host_deck_option, join_hero_option, join_deck_option]:
		UIStyle.style_option_button(ob, blue_sb, blue_hover_sb, arrow_tex, popup_frame_sb, popup_hover_sb)

	if scan_btn:
		var blue_pressed_sb := UIStyle.make_compact_button_sb(blue_tex, Color(0.76, 0.76, 0.76, 1.0))
		var blue_disabled_sb := UIStyle.make_compact_button_sb(blue_tex, Color(0.65, 0.72, 0.78, 0.90))
		scan_btn.add_theme_stylebox_override("normal", blue_sb)
		scan_btn.add_theme_stylebox_override("hover", blue_hover_sb)
		scan_btn.add_theme_stylebox_override("pressed", blue_pressed_sb)
		scan_btn.add_theme_stylebox_override("focus", blue_hover_sb)
		scan_btn.add_theme_stylebox_override("disabled", blue_disabled_sb)
		scan_btn.add_theme_color_override("font_disabled_color", Color(1.0, 0.96, 0.82, 0.95))

	for le in [host_name_edit, host_port_edit, direct_ip_edit, direct_port_edit]:
		UIStyle.style_line_edit(le)

	UIStyle.style_item_list(server_list, popup_hover_sb)

	if host_start_btn:
		_host_green_sb = host_start_btn.get_theme_stylebox("normal")
	if close_footer_btn:
		_stop_red_sb = close_footer_btn.get_theme_stylebox("normal")


func _connect_ui_events() -> void:
	if host_tab_btn:
		host_tab_btn.pressed.connect(func(): _select_tab(0, true))
	if join_tab_btn:
		join_tab_btn.pressed.connect(func(): _select_tab(1, true))
	if host_start_btn:
		host_start_btn.pressed.connect(_on_host_start_pressed)
	if scan_btn:
		scan_btn.pressed.connect(func():
			_play_sfx(SFX_SELECT)
			_on_scan_pressed()
		)
	if direct_connect_btn:
		direct_connect_btn.pressed.connect(_on_direct_connect_pressed)
	if close_x_btn:
		close_x_btn.pressed.connect(func():
			_play_sfx(SFX_BACK)
			close_modal()
		)
	if close_footer_btn:
		close_footer_btn.pressed.connect(func():
			_play_sfx(SFX_BACK)
			close_modal()
		)
	for btn in [scan_btn, host_start_btn, direct_connect_btn, close_footer_btn, close_x_btn]:
		_wire_button_reaction(btn)
	if server_list:
		server_list.item_selected.connect(_on_server_selected)


func _wire_button_reaction(btn: BaseButton) -> void:
	if not btn:
		return
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


func open_modal() -> void:
	_populate_heroes()
	_populate_decks()
	_reset_state()
	_select_tab(0, false)
	visible = true

	if dark_overlay:
		dark_overlay.color.a = 0.0
		create_tween().tween_property(dark_overlay, "color:a", 0.58, 0.22)
	if panel_root:
		panel_root.scale = Vector2(0.05, 0.05)
		panel_root.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(panel_root, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel_root, "modulate:a", 1.0, 0.2)

	# Auto scan LAN in background so hosts appear right away on Join tab
	_on_scan_pressed()


func close_modal() -> void:
	_reset_state()
	visible = false


func _select_tab(tab_idx: int, play_sfx: bool = true) -> void:
	if _active_tab == tab_idx and play_sfx:
		return
	if play_sfx:
		_play_sfx(SFX_SELECT)
	_active_tab = tab_idx
	if host_page:
		host_page.visible = (tab_idx == 0)
	if join_page:
		join_page.visible = (tab_idx == 1)
	if host_start_btn:
		host_start_btn.visible = (tab_idx == 0)
	if direct_connect_btn:
		direct_connect_btn.visible = (tab_idx == 1)

	var tabs: Array = [host_tab_scale, join_tab_scale]
	for i in range(tabs.size()):
		var sr := tabs[i] as Control
		if sr == null:
			continue
		var selected := (i == tab_idx)
		sr.scale = Vector2(1.06, 1.06) if selected else Vector2(0.95, 0.95)
		sr.modulate = Color.WHITE if selected else Color(0.76, 0.76, 0.76, 1.0)


func _reset_state() -> void:
	_is_hosting = false
	_is_scanning = false
	_scan_elapsed = 0.0
	_last_scan_step = -1
	set_process(false)
	_handshake_sent = false
	_remote_handshake_received = false
	if discovery:
		discovery.stop()
	if session:
		session.close_session()

	if scan_btn:
		scan_btn.text = "Scan LAN"
		scan_btn.disabled = false
	if host_start_btn:
		host_start_btn.text = "Host Match"
		host_start_btn.disabled = false
		_apply_host_button_style(false)
	if direct_connect_btn:
		direct_connect_btn.disabled = false
	if host_status_label:
		host_status_label.text = "Set room details and click Host Match."
	if join_status_label:
		join_status_label.text = "Scan for local games or enter direct IP."
	if server_list:
		server_list.clear()


func _apply_host_button_style(is_stopping: bool) -> void:
	if not host_start_btn:
		return
	var sb: StyleBox = _stop_red_sb if is_stopping else _host_green_sb
	if sb:
		for st in ["normal", "hover", "pressed", "focus"]:
			host_start_btn.add_theme_stylebox_override(st, sb)


func _populate_heroes() -> void:
	available_heroes.clear()
	host_hero_option.clear()
	join_hero_option.clear()

	var leaders: Array = GameManager.unlocked_leaders.duplicate()
	if leaders.is_empty():
		leaders = ["Leader_Jake"]

	var seen_chars: Dictionary = {}
	for raw_lid in leaders:
		var lid := GameManager._normalize_hero_id(str(raw_lid))
		var ldata := Database.get_leader(lid)
		var char_id := str(ldata.get("character_id", lid.replace("Leader_", ""))) if not ldata.is_empty() else lid.replace("Leader_", "")
		if char_id.is_empty() or seen_chars.has(char_id):
			continue
		seen_chars[char_id] = true

		var display_name := str(ldata.get("name", HERO_DISPLAY_NAMES.get(char_id, char_id))) if not ldata.is_empty() else str(HERO_DISPLAY_NAMES.get(char_id, char_id))
		available_heroes.append(char_id)
		host_hero_option.add_item(display_name)
		join_hero_option.add_item(display_name)

	if available_heroes.is_empty():
		available_heroes.append("Jake")
		host_hero_option.add_item("Jake")
		join_hero_option.add_item("Jake")

	host_hero_option.selected = 0
	join_hero_option.selected = 0


func _to_string_array(arr: Variant) -> Array[String]:
	var out: Array[String] = []
	if arr is Array:
		for item in arr:
			var s := str(item)
			if s != "":
				out.append(s)
	return out


func _populate_decks() -> void:
	available_decks.clear()
	host_deck_option.clear()
	join_deck_option.clear()

	GameManager.ensure_decks_initialized()
	var active_slot := clampi(GameManager.battle_deck_index, 0, maxi(0, GameManager.decks.size() - 1))
	var selected_idx := 0

	for slot_idx in range(GameManager.decks.size()):
		var slot: Dictionary = GameManager.get_deck_slot(slot_idx)
		var cards := _to_string_array(slot.get("cards", []))
		if cards.is_empty():
			continue

		var lands := _to_string_array(slot.get("landscapes", []))
		while lands.size() < 4:
			lands.append("Corn")
		lands = lands.slice(0, 4)

		var deck_name := str(slot.get("name", "Deck %d" % (slot_idx + 1))).strip_edges()
		if deck_name.is_empty():
			deck_name = "Deck %d" % (slot_idx + 1)

		var leader_id := str(slot.get("leader", "Leader_Jake"))
		var hero_id := GameManager.get_leader_character_id(leader_id)

		if slot_idx == active_slot:
			selected_idx = available_decks.size()

		available_decks.append({
			"slot_index": slot_idx,
			"name": deck_name,
			"hero": hero_id,
			"cards": cards,
			"landscapes": lands,
		})

	if available_decks.is_empty():
		var fallback_cards := _to_string_array(GameManager.player_deck)
		var fallback_lands := _to_string_array(GameManager.player_landscapes)
		while fallback_lands.size() < 4:
			fallback_lands.append("Corn")
		available_decks.append({
			"slot_index": 0,
			"name": GameManager.active_deck_name if GameManager.active_deck_name != "" else "Deck 1",
			"hero": GameManager.player_hero_name if GameManager.player_hero_name != "" else "Jake",
			"cards": fallback_cards,
			"landscapes": fallback_lands.slice(0, 4),
		})

	for d in available_decks:
		var label_text := "%s (%d)" % [str(d["name"]), (d["cards"] as Array).size()]
		host_deck_option.add_item(label_text)
		join_deck_option.add_item(label_text)

	host_deck_option.selected = selected_idx
	join_deck_option.selected = selected_idx

	var active_hero := str(available_decks[selected_idx].get("hero", ""))
	var hero_idx := available_heroes.find(active_hero)
	if hero_idx != -1:
		host_hero_option.selected = hero_idx
		join_hero_option.selected = hero_idx


func _on_host_start_pressed() -> void:
	_play_sfx(SFX_SELECT)
	if _is_hosting:
		_reset_state()
		return

	var port = int(host_port_edit.text)
	var room_name = host_name_edit.text.strip_edges()
	if room_name.is_empty():
		room_name = "Card Wars LAN"

	var hero_id = available_heroes[host_hero_option.selected]
	var err = session.host_session(port, 1)
	if err == OK:
		_is_hosting = true
		host_start_btn.text = "Stop Hosting"
		_apply_host_button_style(true)
		host_status_label.text = "Hosting on port %d! Broadcasting UDP beacon (47777)..." % port
		discovery.start_broadcasting(room_name, port, {"hero": hero_id})
	else:
		host_status_label.text = "Error hosting on port %d: %d" % [port, err]


func _process(delta: float) -> void:
	if not _is_scanning:
		set_process(false)
		return
	_scan_elapsed += delta
	var step := int(_scan_elapsed / 0.35) % 3
	if step != _last_scan_step:
		_last_scan_step = step
		var dots := ".".repeat(step + 1)
		if scan_btn:
			scan_btn.text = "Scanning%s" % dots
		if join_status_label:
			join_status_label.text = "Scanning LAN on UDP 47777%s" % dots
	if _scan_elapsed >= SCAN_BURST_SECONDS:
		_finish_scan_burst()


func _finish_scan_burst() -> void:
	_is_scanning = false
	set_process(false)
	if scan_btn:
		scan_btn.disabled = false
		scan_btn.text = "Scan LAN"
	if not _has_real_servers():
		_set_scan_placeholder("No LAN matches found. Click Scan LAN or use Direct IP.")
		if join_status_label:
			join_status_label.text = "No LAN matches found on UDP 47777."


func _has_real_servers() -> bool:
	if not server_list:
		return false
	for i in range(server_list.item_count):
		if server_list.get_item_metadata(i) is Dictionary:
			return true
	return false


func _remove_placeholder_items() -> void:
	if not server_list:
		return
	for i in range(server_list.item_count - 1, -1, -1):
		if not (server_list.get_item_metadata(i) is Dictionary):
			server_list.remove_item(i)


func _set_scan_placeholder(msg: String) -> void:
	if not server_list:
		return
	server_list.clear()
	var idx := server_list.add_item(msg)
	server_list.set_item_selectable(idx, false)
	server_list.set_item_custom_fg_color(idx, Color(0.82, 0.86, 0.92, 0.78))


func _on_scan_pressed() -> void:
	_is_scanning = false
	set_process(false)
	var err = discovery.start_listening()
	if err != OK:
		if scan_btn:
			scan_btn.disabled = false
			scan_btn.text = "Scan LAN"
		_set_scan_placeholder("Could not listen on UDP 47777 (error %d). Use Direct IP." % err)
		if join_status_label:
			join_status_label.text = "Failed to listen on UDP 47777 (error %d)." % err
		return

	_is_scanning = true
	_scan_elapsed = 0.0
	_last_scan_step = 0
	set_process(true)
	if scan_btn:
		scan_btn.disabled = true
		scan_btn.text = "Scanning."
	_set_scan_placeholder("Searching local network on UDP 47777...")
	if join_status_label:
		join_status_label.text = "Scanning LAN on UDP 47777."


func _on_server_selected(index: int) -> void:
	_play_sfx(SFX_SELECT)
	var metadata = server_list.get_item_metadata(index)
	if metadata is Dictionary:
		direct_ip_edit.text = str(metadata.get("ip", "127.0.0.1"))
		direct_port_edit.text = str(metadata.get("game_port", 8910))


func _on_direct_connect_pressed() -> void:
	_play_sfx(SFX_SELECT)
	var ip = direct_ip_edit.text.strip_edges()
	var port = int(direct_port_edit.text)
	if ip.is_empty():
		join_status_label.text = "Please enter a valid IP."
		return

	discovery.stop()
	join_status_label.text = "Connecting to %s:%d..." % [ip, port]
	direct_connect_btn.disabled = true

	var err = session.join_session(ip, port)
	if err != OK:
		join_status_label.text = "Failed to initiate connection: %d" % err
		direct_connect_btn.disabled = false


# --- Network Events ---

func _on_session_created(port: int) -> void:
	host_status_label.text = "Game created on port %d. Waiting for opponent..." % port


func _on_peer_connected(_id: int) -> void:
	host_status_label.text = "Opponent joined! Exchanging deck & hero data..."
	_send_local_handshake(true)


func _on_connected_to_host() -> void:
	join_status_label.text = "Connected to host! Exchanging deck & hero data..."
	_send_local_handshake(false)


func _send_local_handshake(is_host: bool) -> void:
	var hero_id = available_heroes[host_hero_option.selected] if is_host else available_heroes[join_hero_option.selected]
	var deck_info = available_decks[host_deck_option.selected] if is_host else available_decks[join_deck_option.selected]

	_handshake_sent = true
	protocol.send_handshake({
		"player_name": host_name_edit.text if is_host else "Opponent",
		"hero": hero_id,
		"deck": deck_info.cards,
		"landscapes": deck_info.landscapes
	})


func _on_handshake_received(sender_id: int, data: Dictionary) -> void:
	if sender_id == session.get_local_peer_id():
		return

	_remote_handshake_received = true

	var is_host = session.is_host()
	var local_hero = available_heroes[host_hero_option.selected] if is_host else available_heroes[join_hero_option.selected]
	var local_deck = available_decks[host_deck_option.selected] if is_host else available_decks[join_deck_option.selected]
	var typed_cards := _to_string_array(local_deck.get("cards", []))
	var typed_lands := _to_string_array(local_deck.get("landscapes", []))

	discovery.get_parent().remove_child(discovery)
	session.get_parent().remove_child(session)
	protocol.get_parent().remove_child(protocol)

	GameManager.add_child(discovery)
	GameManager.add_child(session)
	GameManager.add_child(protocol)

	GameManager.setup_network_match(
		is_host,
		local_hero,
		typed_cards,
		typed_lands,
		session,
		protocol,
		discovery
	)
	GameManager.apply_remote_handshake(data)

	visible = false
	GameManager.start_battle()


func _on_server_discovered(ip: String, port: int, info: Dictionary) -> void:
	_remove_placeholder_items()
	_is_scanning = false
	set_process(false)
	if scan_btn:
		scan_btn.disabled = false
		scan_btn.text = "Scan LAN"
	var label = "%s - %s (%s:%d)" % [info.get("server_name", "Card Wars"), info.get("extra_info", {}).get("hero", "Hero"), ip, port]
	for i in range(server_list.item_count):
		var meta = server_list.get_item_metadata(i)
		if meta is Dictionary and meta.get("ip") == ip:
			server_list.set_item_text(i, label)
			return
	var idx = server_list.add_item(label)
	server_list.set_item_metadata(idx, info)
	join_status_label.text = "Discovered %d LAN match(es)." % server_list.item_count


func _on_server_expired(ip: String) -> void:
	for i in range(server_list.item_count):
		var meta = server_list.get_item_metadata(i)
		if meta is Dictionary and meta.get("ip") == ip:
			server_list.remove_item(i)
			break
	if not _has_real_servers() and not _is_scanning:
		_set_scan_placeholder("No active LAN matches. Click Scan LAN to refresh.")
		if join_status_label:
			join_status_label.text = "No LAN matches found on UDP 47777."


func _on_connection_failed() -> void:
	join_status_label.text = "Connection failed. Please check IP and port."
	direct_connect_btn.disabled = false


func _on_host_disconnected() -> void:
	join_status_label.text = "Host closed the session."
	direct_connect_btn.disabled = false


func _on_peer_disconnected(_id: int) -> void:
	if _is_hosting:
		host_status_label.text = "Opponent disconnected."


func show_panel_preview(mode: String) -> void:
	if mode == "lan_join":
		_select_tab(1, false)
	elif mode == "lan_popup":
		_select_tab(0, false)
		if host_hero_option:
			host_hero_option.call_deferred("show_popup")
	else:
		_select_tab(0, false)


func _play_sfx(stream: AudioStream) -> void:
	if Audio and stream:
		Audio.play_sfx(stream)
