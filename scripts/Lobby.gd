extends Control

@onready var name_input = $Panel/VBoxContainer/NameInput
@onready var ip_input = $Panel/VBoxContainer/NetworkHBox/JoinPanel/VBoxContainer/IPInput
@onready var port_input = $Panel/VBoxContainer/NetworkHBox/JoinPanel/VBoxContainer/PortInput
@onready var host_port_input = $Panel/VBoxContainer/NetworkHBox/HostPanel/VBoxContainer/PortInput
@onready var status_label = $Panel/VBoxContainer/StatusLabel
@onready var character_option_btn = $Panel/VBoxContainer/CharacterOptionButton

const CHARACTERS = [
	"CopperMyr",
	"Elf",
	"Goblin",
	"GoldMyr",
	"Krenko",
	"LodestoneMyr",
	"MyrEnforcer",
	"MyrScavenger",
	"SilverMyr"
]

func _ready():
	GameManager.connection_failed.connect(_on_connection_failed)
	GameManager.server_disconnected.connect(_on_server_disconnected)
	
	for char_name in CHARACTERS:
		character_option_btn.add_item(char_name)

func _on_host_button_pressed():
	var p_name = name_input.text.strip_edges()
	if p_name == "":
		p_name = "Player_" + str(randi_range(100, 999))
		name_input.text = p_name
		
	var port = int(host_port_input.text)
	if port <= 0:
		port = GameManager.DEFAULT_PORT
		
	status_label.text = "Hosting game..."
	status_label.modulate = Color.GREEN
	
	var selected_char = CHARACTERS[character_option_btn.selected]
	
	var err = GameManager.host_game(
		port, 
		p_name, 
		selected_char
	)
	if err != OK:
		status_label.text = "Host failed: Error code " + str(err)
		status_label.modulate = Color.RED

func _on_join_button_pressed():
	var p_name = name_input.text.strip_edges()
	if p_name == "":
		p_name = "Player_" + str(randi_range(100, 999))
		name_input.text = p_name
		
	var ip = ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
		ip_input.text = ip
		
	var port = int(port_input.text)
	if port <= 0:
		port = GameManager.DEFAULT_PORT
		
	status_label.text = "Connecting to " + ip + ":" + str(port) + "..."
	status_label.modulate = Color.YELLOW
	
	var selected_char = CHARACTERS[character_option_btn.selected]
	
	var err = GameManager.join_game(
		ip, 
		port, 
		p_name, 
		selected_char
	)
	if err != OK:
		status_label.text = "Join failed: Error code " + str(err)
		status_label.modulate = Color.RED

func _on_connection_failed():
	status_label.text = "Connection failed. Please check IP/Port."
	status_label.modulate = Color.RED

func _on_server_disconnected():
	status_label.text = "Disconnected from server."
	status_label.modulate = Color.RED

