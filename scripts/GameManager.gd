extends Node

const DEFAULT_PORT = 9999
const MAX_PLAYERS = 5

# Local player settings chosen in the Lobby
var player_name: String = "Player"
var player_character: String = "SilverMyr"

# Player database (synced across all peers)
# peer_id (int) -> { name: String, character: String }
var players = {}

# Signals for UI updating
signal player_list_changed
signal connection_failed
signal connection_succeeded
signal server_disconnected

func _ready():
	setup_input_map()
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)

func setup_input_map():
	var inputs = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN]
	}
	
	for action in inputs:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in inputs[action]:
				var event = InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)


func _switch_to_main_scene_instantly():
	var main_scene = load("res://scenes/Main.tscn")
	var main_node = main_scene.instantiate()
	var root = get_tree().root
	var current = get_tree().current_scene
	if current:
		root.remove_child(current)
		current.queue_free()
	root.add_child(main_node)
	get_tree().current_scene = main_node

func host_game(port: int, p_name: String, p_character: String):
	player_name = p_name
	player_character = p_character
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		print("Failed to host server: ", error)
		return error
		
	multiplayer.multiplayer_peer = peer
	
	# Add host player to the database
	players[1] = {
		"name": player_name,
		"character": player_character
	}
	
	_switch_to_main_scene_instantly()
	
	player_list_changed.emit()
	print("Server hosted successfully on port ", port)
	return OK

func join_game(ip: String, port: int, p_name: String, p_character: String):
	player_name = p_name
	player_character = p_character
	
	_switch_to_main_scene_instantly()
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	if error != OK:
		print("Failed to start client: ", error)
		return error
		
	multiplayer.multiplayer_peer = peer
	
	print("Connecting to ", ip, ":", port, "...")
	return OK

func leave_game():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

# --- Network Callbacks ---

func _on_connection_failed():
	print("Connection failed!")
	leave_game()
	connection_failed.emit()

func _on_connected_to_server():
	print("Connected to server! Registering details...")
	
	var local_id = multiplayer.get_unique_id()
	rpc_id(1, "register_player", local_id, player_name, player_character)
	connection_succeeded.emit()

func _on_server_disconnected():
	print("Server disconnected.")
	leave_game()
	server_disconnected.emit()

func _on_peer_connected(id: int):
	print("Peer connected: ", id)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)
	if multiplayer.is_server():
		# Remove player from database
		if players.has(id):
			players.erase(id)
			# Broadcast update to all remaining clients
			rpc("update_player_list", players)
		
		# Let the Main scene handle deleting the spawned player node
		var main_node = get_tree().current_scene
		if main_node and main_node.has_method("remove_player"):
			main_node.remove_player(id)

# --- RPCs ---

@rpc("any_peer", "call_local", "reliable")
func register_player(id: int, p_name: String, p_character: String):
	if multiplayer.is_server():
		# Check if maximum players limit reached
		if players.size() >= MAX_PLAYERS:
			print("Server full. Rejecting client ", id)
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				multiplayer.multiplayer_peer.disconnect_peer(id)
			return
			
		players[id] = {
			"name": p_name,
			"character": p_character
		}
		
		# Send updated list to all clients
		rpc("update_player_list", players)
		
		# Tell the Main scene to spawn this player
		var main_node = get_tree().current_scene
		if main_node and main_node.has_method("add_player"):
			main_node.add_player(id)

@rpc("authority", "call_local", "reliable")
func update_player_list(new_players: Dictionary):
	players.clear()
	for key in new_players.keys():
		var id = int(key)
		players[id] = new_players[key]
	
	player_list_changed.emit()
	print("Player list updated: ", players)
