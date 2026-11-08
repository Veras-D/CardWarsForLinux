# LanLobbyModal.gd
# LAN Multiplayer Lobby modal providing UDP Auto-Discovery, Hosting, Direct IP Connect, and Handshake.
class_name LanLobbyModal
extends Control

const LanDiscoveryClass = preload("res://src/systems/network_multiplayer/LanDiscovery.gd")
const NetworkSessionManagerClass = preload("res://src/systems/network_multiplayer/NetworkSessionManager.gd")
const TurnActionProtocolClass = preload("res://src/systems/network_multiplayer/TurnActionProtocol.gd")

# Sub-nodes
var discovery: LanDiscoveryClass
var session: NetworkSessionManagerClass
var protocol: TurnActionProtocolClass

# UI Controls - Host Tab
@onready var tab_container: TabContainer = $CenterContainer/Panel/VBox/TabContainer
@onready var host_name_edit: LineEdit = $CenterContainer/Panel/VBox/TabContainer/Host/HostVBox/RoomNameEdit
@onready var host_hero_option: OptionButton = $CenterContainer/Panel/VBox/TabContainer/Host/HostVBox/HostHeroOption
@onready var host_deck_option: OptionButton = $CenterContainer/Panel/VBox/TabContainer/Host/HostVBox/HostDeckOption
@onready var host_port_edit: LineEdit = $CenterContainer/Panel/VBox/TabContainer/Host/HostVBox/PortHBox/HostPortEdit
@onready var host_start_btn: Button = $CenterContainer/Panel/VBox/TabContainer/Host/HostVBox/HostStartBtn
@onready var host_status_label: Label = $CenterContainer/Panel/VBox/TabContainer/Host/HostVBox/HostStatusLabel

# UI Controls - Join Tab
@onready var scan_btn: Button = $CenterContainer/Panel/VBox/TabContainer/Join/JoinVBox/ScanBtn
@onready var server_list: ItemList = $CenterContainer/Panel/VBox/TabContainer/Join/JoinVBox/ServerList
@onready var join_hero_option: OptionButton = $CenterContainer/Panel/VBox/TabContainer/Join/JoinVBox/LoadoutGrid/JoinHeroOption
@onready var join_deck_option: OptionButton = $CenterContainer/Panel/VBox/TabContainer/Join/JoinVBox/LoadoutGrid/JoinDeckOption
@onready var direct_ip_edit: LineEdit = $CenterContainer/Panel/VBox/TabContainer/Join/JoinVBox/DirectHBox/DirectIpEdit
@onready var direct_port_edit: LineEdit = $CenterContainer/Panel/VBox/TabContainer/Join/JoinVBox/DirectHBox/DirectPortEdit
@onready var direct_connect_btn: Button = $CenterContainer/Panel/VBox/TabContainer/Join/JoinVBox/DirectConnectBtn
@onready var join_status_label: Label = $CenterContainer/Panel/VBox/TabContainer/Join/JoinVBox/JoinStatusLabel

# Bottom
@onready var close_btn: Button = $CenterContainer/Panel/VBox/CloseBtn

var available_heroes: Array[String] = ["Finn", "Jake", "Marceline", "PrincessBubblegum", "IceKing", "EarlOfLemongrab", "BMO", "FlamePrincess"]
var available_decks: Array[Dictionary] = []
var _is_hosting: bool = false
var _handshake_sent: bool = false
var _remote_handshake_received: bool = false


func _ready() -> void:
	visible = false
	_setup_network_nodes()
	_connect_ui_events()


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


func _connect_ui_events() -> void:
	if host_start_btn:
		host_start_btn.pressed.connect(_on_host_start_pressed)
	if scan_btn:
		scan_btn.pressed.connect(_on_scan_pressed)
	if direct_connect_btn:
		direct_connect_btn.pressed.connect(_on_direct_connect_pressed)
	if close_btn:
		close_btn.pressed.connect(close_modal)
	if server_list:
		server_list.item_selected.connect(_on_server_selected)


func open_modal() -> void:
	_populate_heroes()
	_populate_decks()
	_reset_state()
	visible = true
	# Auto scan LAN when opened
	_on_scan_pressed()


func close_modal() -> void:
	_reset_state()
	visible = false


func _reset_state() -> void:
	_is_hosting = false
	_handshake_sent = false
	_remote_handshake_received = false
	if discovery:
		discovery.stop()
	if session:
		session.close_session()

	if host_start_btn:
		host_start_btn.text = "📡 Host LAN Game"
		host_start_btn.disabled = false
	if host_status_label:
		host_status_label.text = "Set room details and click Host."
	if join_status_label:
		join_status_label.text = "Scan for local games or enter direct IP."
	if server_list:
		server_list.clear()


func _populate_heroes() -> void:
	host_hero_option.clear()
	join_hero_option.clear()
	for h in available_heroes:
		host_hero_option.add_item(h)
		join_hero_option.add_item(h)
	host_hero_option.selected = 0
	join_hero_option.selected = 1


func _populate_decks() -> void:
	available_decks.clear()
	host_deck_option.clear()
	join_deck_option.clear()

	available_decks.append({
		"name": "Finn Starter Deck",
		"cards": GameManager.player_deck.duplicate(),
		"landscapes": ["Plains", "Plains", "Cotton", "Plains"]
	})
	available_decks.append({
		"name": "Jake Corn Deck",
		"cards": GameManager.opponent_deck.duplicate(),
		"landscapes": ["Corn", "Corn", "Sand", "Corn"]
	})

	for d in available_decks:
		host_deck_option.add_item(d.name)
		join_deck_option.add_item(d.name)

	host_deck_option.selected = 0
	join_deck_option.selected = mini(1, available_decks.size() - 1)


func _on_host_start_pressed() -> void:
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
		host_start_btn.text = "🛑 Stop Hosting"
		host_status_label.text = "Hosting on port %d! Broadcasting UDP beacon (47777)..." % port
		discovery.start_broadcasting(room_name, port, {"hero": hero_id})
	else:
		host_status_label.text = "Error hosting on port %d: %d" % [port, err]


func _on_scan_pressed() -> void:
	server_list.clear()
	join_status_label.text = "Scanning LAN on UDP 47777..."
	var err = discovery.start_listening()
	if err != OK:
		join_status_label.text = "Failed to listen for LAN beacons: %d" % err


func _on_server_selected(index: int) -> void:
	var metadata = server_list.get_item_metadata(index)
	if metadata is Dictionary:
		direct_ip_edit.text = str(metadata.get("ip", "127.0.0.1"))
		direct_port_edit.text = str(metadata.get("game_port", 8910))


func _on_direct_connect_pressed() -> void:
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


func _on_peer_connected(id: int) -> void:
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
	# Avoid processing our own handshake
	if sender_id == session.get_local_peer_id():
		return

	_remote_handshake_received = true

	# Both peers ready: initialize GameManager and transition to battle
	var is_host = session.is_host()
	var local_hero = available_heroes[host_hero_option.selected] if is_host else available_heroes[join_hero_option.selected]
	var local_deck = available_decks[host_deck_option.selected] if is_host else available_decks[join_deck_option.selected]

	# Keep networking nodes alive across scene transition by reparenting to root or GameManager
	discovery.get_parent().remove_child(discovery)
	session.get_parent().remove_child(session)
	protocol.get_parent().remove_child(protocol)
	GameManager.add_child(discovery)
	GameManager.add_child(session)
	GameManager.add_child(protocol)

	GameManager.setup_network_match(
		is_host,
		local_hero,
		local_deck.cards,
		local_deck.landscapes,
		session,
		protocol,
		discovery
	)
	GameManager.apply_remote_handshake(data)

	visible = false
	GameManager.start_battle()


func _on_server_discovered(ip: String, port: int, info: Dictionary) -> void:
	var label = "%s — %s (%s:%d)" % [info.get("server_name", "Card Wars"), info.get("extra_info", {}).get("hero", "Hero"), ip, port]
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


func _on_connection_failed() -> void:
	join_status_label.text = "Connection failed. Please check IP and port."
	direct_connect_btn.disabled = false


func _on_host_disconnected() -> void:
	join_status_label.text = "Host closed the session."
	direct_connect_btn.disabled = false


func _on_peer_disconnected(id: int) -> void:
	if _is_hosting:
		host_status_label.text = "Opponent disconnected."
