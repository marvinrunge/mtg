extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/Player.tscn")
const ENEMY_SCENE = preload("res://scenes/Enemy.tscn")

var music_cache: Dictionary = {
	"res://sounds/soundtrack-main.mp3": preload("res://sounds/soundtrack-main.mp3"),
	"res://sounds/soundtrack-white.mp3": preload("res://sounds/soundtrack-white.mp3"),
	"res://sounds/soundtrack-mountain.mp3": preload("res://sounds/soundtrack-mountain.mp3"),
	"res://sounds/soundtrack-forest.mp3": preload("res://sounds/soundtrack-forest.mp3")
}

@onready var players_container = $PlayersContainer
@onready var player_list_label = $HUD/MarginContainer/VBoxContainer/PlayerList
@onready var leave_button = $HUD/MarginContainer/VBoxContainer/LeaveButton
@onready var controls_label = $HUD/MarginContainer/VBoxContainer/ControlsLabel
@onready var wave_label = $HUD/MarginContainer/VBoxContainer/WaveLabel
@onready var enemies_container = $EnemiesContainer

var esc_menu_container: Control
var esc_main_menu: VBoxContainer
var audio_settings_menu: VBoxContainer
var controls_menu: VBoxContainer
var player_info_panel: PanelContainer
var player_info_rt: RichTextLabel
var ping_timer: float = 0.0

var current_wave = 0
var wave_active = false
var enemies_to_spawn = 0
var enemies_spawned = 0
var enemies_alive = 0
var wave_timer = 0.0
var total_game_time = 0.0

var nav_region: NavigationRegion3D

var music_player_1: AudioStreamPlayer
var music_player_2: AudioStreamPlayer
var active_music_player: int = 1
var current_track: String = ""

const ISLAND_POSITIONS = [
	Vector3(100, 0, 0),
	Vector3(30.9, 0, 95.11),
	Vector3(-80.9, 0, 58.78),
	Vector3(-80.9, 0, -58.87),
	Vector3(30.9, 0, -95.11)
]

const SPAWN_POINTS = [
	Vector3(0, 50.0, 0),
	Vector3(-6.0, 50.0, -6.0),
	Vector3(6.0, 50.0, -6.0),
	Vector3(-6.0, 50.0, 6.0),
	Vector3(6.0, 50.0, 6.0)
]

func _ready():
	setup_world()
	GameManager.player_list_changed.connect(update_player_list_hud)
	
	_setup_audio_buses()
	_setup_new_ui()
	update_player_list_hud()
	
	music_player_1 = AudioStreamPlayer.new()
	music_player_2 = AudioStreamPlayer.new()
	music_player_1.bus = "Music"
	music_player_2.bus = "Music"
	add_child(music_player_1)
	add_child(music_player_2)
	music_player_1.volume_db = -80.0
	music_player_2.volume_db = -80.0
	
	leave_button.pressed.connect(_on_leave_button_pressed)
	
	var wind_player = AudioStreamPlayer.new()
	wind_player.stream = load("res://sounds/wind.wav")
	wind_player.bus = "Environment"
	add_child(wind_player)
	wind_player.play()
	wind_player.finished.connect(wind_player.play)
	
	var cristal_player = AudioStreamPlayer3D.new()
	cristal_player.stream = load("res://sounds/cristal.wav")
	cristal_player.bus = "Environment"
	cristal_player.position = Vector3(0, 0, 0)
	cristal_player.max_distance = 60.0
	add_child(cristal_player)
	cristal_player.play()
	cristal_player.finished.connect(cristal_player.play)
	
	$MultiplayerSpawner.add_spawnable_scene("res://scenes/Player.tscn")
	
	# Server instantiates player scenes; client nodes are spawned by MultiplayerSpawner
	if multiplayer.is_server():
		for id in GameManager.players.keys():
			add_player(id)
		
		# Start the first wave
		await get_tree().create_timer(3.0).timeout
		start_wave()

func _process(delta):
	_update_local_music()
	
	ping_timer += delta
	if ping_timer >= 1.0:
		ping_timer = 0.0
		update_player_list_hud()
		
	if player_info_panel:
		player_info_panel.visible = Input.is_key_pressed(KEY_TAB)
	
	if not multiplayer.is_server():
		return
		
	total_game_time += delta
		
	if wave_active:
		if enemies_spawned < enemies_to_spawn:
			wave_timer -= delta
			if wave_timer <= 0:
				spawn_enemy()
				# Scale down the spawn delay dynamically based on time (min 1.5s)
				wave_timer = max(1.5, 4.0 - (total_game_time / 120.0) * 0.5)
		elif enemies_alive <= 0:
			end_wave()

func start_wave():
	if not multiplayer.is_server(): return
	current_wave += 1
	wave_active = true
	# Cap the max enemies per wave to 30
	if current_wave % 5 == 0:
		enemies_to_spawn = 1 + current_wave
	elif current_wave == 1:
		enemies_to_spawn = max(1, GameManager.players.size())
	else:
		enemies_to_spawn = min(20, 3 + current_wave)
	enemies_spawned = 0
	enemies_alive = enemies_to_spawn
	wave_timer = max(0.5, 3.0 - (total_game_time / 120.0) * 0.5)
	
	rpc("announce_wave", current_wave)

func end_wave():
	wave_active = false
	# Wait 10 seconds before next wave
	await get_tree().create_timer(10.0).timeout
	start_wave()

@rpc("call_local", "authority", "reliable")
func announce_wave(wave: int):
	if wave_label:
		wave_label.text = "Wave " + str(wave) + " Incoming!"
		wave_label.modulate = Color(1, 1, 1, 1)
		
		var tween = create_tween()
		tween.tween_interval(3.0)
		tween.tween_callback(func(): wave_label.text = "Wave " + str(wave) + " Active")

func spawn_enemy():
	var enemy = ENEMY_SCENE.instantiate()
	
	var type = "goblin"
	if current_wave % 5 == 0 and enemies_spawned == 0:
		type = "boss"
	elif current_wave > 1:
		var r = randf()
		if r < 0.2:
			type = "tank"
		elif r < 0.4:
			type = "swarmer"
			
	var island_index = (current_wave - 1) % ISLAND_POSITIONS.size()
	var base_pos = ISLAND_POSITIONS[island_index]
	
	var offset = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * (randf() * 5.0)
	enemy.position = base_pos + offset
	# Ensure they don't spawn below the terrain, bump them up slightly
	enemy.position.y = max(enemy.position.y, 2.0)
	
	enemy.tree_exited.connect(func(): enemies_alive -= 1)
	
	enemies_container.add_child(enemy, true)
	enemies_spawned += 1
	
	# Delay init_stats slightly so clients have time to instantiate the node for RPC
	var multiplier = 1.0 + (total_game_time / 300.0)
	get_tree().create_timer(0.1).timeout.connect(func(): 
		if is_instance_valid(enemy): 
			enemy.init_stats(multiplier, type)
	)

func setup_world():
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion"
	var nav_mesh = NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.cell_size = 0.5
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)
	
	# Add colored lights above each island
	var island_colors = [
		Color(1.0, 1.0, 0.8), # White
		Color(0.2, 0.5, 1.0), # Blue
		Color(0.6, 0.2, 0.8), # Black
		Color(1.0, 0.3, 0.2), # Red
		Color(0.2, 0.8, 0.2)  # Green
	]
	for i in range(ISLAND_POSITIONS.size()):
		var light = OmniLight3D.new()
		light.light_color = island_colors[i]
		light.light_energy = 0.7
		light.omni_range = 100.0
		light.position = ISLAND_POSITIONS[i] + Vector3(0, 30, 0)
		add_child(light)
	
	var children = get_children().duplicate()
	for child in children:
		if child.name in ["NavigationRegion", "PlayersContainer", "EnemiesContainer", "EnemySpawner", "HUD", "MultiplayerSpawner", "DirectionalLight3D", "WorldEnvironment"]:
			continue
			
		_add_collisions_recursive(child)
		remove_child(child)
		nav_region.add_child(child)
		print("Generated collisions and added to NavRegion: ", child.name)
		
	nav_region.bake_navigation_mesh(false)

func _add_collisions_recursive(node: Node):
	if node is MeshInstance3D and node.mesh:
		node.create_trimesh_collision()
		
	for child in node.get_children():
		_add_collisions_recursive(child)


func add_player(id: int):
	if not multiplayer.is_server():
		return
		
	if players_container.has_node(str(id)):
		return
		
	var player = player_scene.instantiate()
	player.name = str(id)
	
	# Determine spawn position based on child count
	var spawn_index = players_container.get_child_count() % SPAWN_POINTS.size()
	player.position = SPAWN_POINTS[spawn_index]
	
	players_container.add_child(player)
	print("Spawned player ", id, " at ", player.position)

func remove_player(id: int):
	if not multiplayer.is_server():
		return
		
	if players_container.has_node(str(id)):
		var player = players_container.get_node(str(id))
		player.queue_free()
		print("Removed player ", id)

func update_player_list_hud():
	if not player_info_rt: return
	var text = "[center][b]Players (" + str(GameManager.players.size()) + "/5)[/b][/center]\n\n"
	text += "[table=3]"
	text += "[cell][b]Name[/b]      [/cell][cell][b]Character[/b]      [/cell][cell][b]Ping[/b][/cell]"
	
	for id in GameManager.players:
		var details = GameManager.players[id]
		var name_str = details.get("name", "Player")
		var char_str = details.get("character", "Unknown")
		var ping_str = "---"
		
		if id == multiplayer.get_unique_id():
			name_str += " (You)"
			if not multiplayer.is_server():
				if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
					var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
					var enet_peer = peer.get_peer(1)
					if enet_peer:
						ping_str = str(enet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) + " ms"
			else:
				ping_str = "0 ms"
		
		text += "[cell]" + name_str + "      [/cell][cell]" + char_str + "      [/cell][cell]" + ping_str + "[/cell]"
	
	text += "[/table]"
	player_info_rt.text = text

func _on_leave_button_pressed():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.leave_game()

func toggle_menu(show: bool):
	if esc_menu_container:
		esc_menu_container.visible = show
		if show:
			esc_main_menu.show()
			audio_settings_menu.hide()
			controls_menu.hide()

func _setup_audio_buses():
	for bus_name in ["Music", "SFX", "Environment"]:
		var idx = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			AudioServer.add_bus()
			idx = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)

func _setup_new_ui():
	# Hide old UI elements
	if player_list_label: player_list_label.hide()
	if controls_label: controls_label.hide()
	if leave_button: leave_button.hide()
	
	var hud = $HUD
	
	# Player Info Panel (Tab)
	var tab_center_container = CenterContainer.new()
	tab_center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab_center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tab_center_container)
	
	player_info_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	player_info_panel.add_theme_stylebox_override("panel", style)
	
	player_info_panel.hide()
	tab_center_container.add_child(player_info_panel)
	
	player_info_rt = RichTextLabel.new()
	player_info_rt.bbcode_enabled = true
	player_info_rt.fit_content = true
	player_info_rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	player_info_rt.custom_minimum_size = Vector2(400, 0)
	player_info_panel.add_child(player_info_rt)
	
	# Esc Menu
	esc_menu_container = ColorRect.new()
	esc_menu_container.color = Color(0, 0, 0, 0.5)
	esc_menu_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	esc_menu_container.hide()
	hud.add_child(esc_menu_container)
	
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	esc_menu_container.add_child(center_container)
	
	var menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", style)
	center_container.add_child(menu_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	menu_panel.add_child(margin)
	
	# Main Menu
	esc_main_menu = VBoxContainer.new()
	esc_main_menu.add_theme_constant_override("separation", 15)
	margin.add_child(esc_main_menu)
	
	var title = Label.new()
	title.text = "Pause Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	esc_main_menu.add_child(title)
	
	var btn_audio = Button.new()
	btn_audio.text = "Audio Settings"
	btn_audio.custom_minimum_size = Vector2(200, 40)
	esc_main_menu.add_child(btn_audio)
	btn_audio.pressed.connect(func():
		esc_main_menu.hide()
		audio_settings_menu.show()
	)
	
	var btn_controls = Button.new()
	btn_controls.text = "Controls"
	btn_controls.custom_minimum_size = Vector2(200, 40)
	esc_main_menu.add_child(btn_controls)
	btn_controls.pressed.connect(func():
		esc_main_menu.hide()
		controls_menu.show()
	)
	
	var btn_leave = Button.new()
	btn_leave.text = "Leave Session"
	btn_leave.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	btn_leave.custom_minimum_size = Vector2(200, 40)
	esc_main_menu.add_child(btn_leave)
	btn_leave.pressed.connect(_on_leave_button_pressed)
	
	var btn_resume = Button.new()
	btn_resume.text = "Resume"
	btn_resume.custom_minimum_size = Vector2(200, 40)
	esc_main_menu.add_child(btn_resume)
	btn_resume.pressed.connect(func():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		toggle_menu(false)
	)
	
	# Audio Settings Menu
	audio_settings_menu = VBoxContainer.new()
	audio_settings_menu.add_theme_constant_override("separation", 15)
	audio_settings_menu.hide()
	margin.add_child(audio_settings_menu)
	
	var audio_title = Label.new()
	audio_title.text = "Audio Settings"
	audio_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	audio_title.add_theme_font_size_override("font_size", 24)
	audio_settings_menu.add_child(audio_title)
	
	var sliders = [
		{"name": "Master", "bus": "Master"},
		{"name": "Music", "bus": "Music"},
		{"name": "SFX", "bus": "SFX"},
		{"name": "Environment", "bus": "Environment"}
	]
	
	for s in sliders:
		var hbox = HBoxContainer.new()
		audio_settings_menu.add_child(hbox)
		
		var lbl = Label.new()
		lbl.text = s["name"]
		lbl.custom_minimum_size = Vector2(150, 0)
		hbox.add_child(lbl)
		
		var slider = HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = 0.001
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(s["bus"])))
		slider.custom_minimum_size = Vector2(150, 0)
		hbox.add_child(slider)
		
		slider.value_changed.connect(func(val):
			var db = linear_to_db(val)
			if val <= 0.001: db = -80.0
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(s["bus"]), db)
		)
		
	var btn_audio_back = Button.new()
	btn_audio_back.text = "Back"
	btn_audio_back.custom_minimum_size = Vector2(200, 40)
	audio_settings_menu.add_child(btn_audio_back)
	btn_audio_back.pressed.connect(func():
		audio_settings_menu.hide()
		esc_main_menu.show()
	)
	
	# Controls Menu
	controls_menu = VBoxContainer.new()
	controls_menu.add_theme_constant_override("separation", 15)
	controls_menu.hide()
	margin.add_child(controls_menu)
	
	var controls_title = Label.new()
	controls_title.text = "Controls"
	controls_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_title.add_theme_font_size_override("font_size", 24)
	controls_menu.add_child(controls_title)
	
	var ctrl_center = CenterContainer.new()
	controls_menu.add_child(ctrl_center)
	
	var ctrl_text = RichTextLabel.new()
	ctrl_text.bbcode_enabled = true
	ctrl_text.fit_content = true
	ctrl_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	var table_str = "[table=2]"
	table_str += "[cell][b][WASD] / [Arrows]  [/b][/cell][cell]Move[/cell]"
	table_str += "[cell][b][Space]  [/b][/cell][cell]Jump[/cell]"
	table_str += "[cell][b][Mouse]  [/b][/cell][cell]Rotate Camera[/cell]"
	table_str += "[cell][b][Esc]  [/b][/cell][cell]Toggle Menu[/cell]"
	table_str += "[cell][b]Left-Click  [/b][/cell][cell]Attack[/cell]"
	table_str += "[cell][b]Right-Click  [/b][/cell][cell]Cast Spell[/cell]"
	table_str += "[cell][b][Scroll]  [/b][/cell][cell]Switch Spell[/cell]"
	table_str += "[cell][b][F]  [/b][/cell][cell]Interact[/cell]"
	table_str += "[/table]"
	ctrl_text.text = table_str
	ctrl_center.add_child(ctrl_text)
	
	var btn_controls_back = Button.new()
	btn_controls_back.text = "Back"
	btn_controls_back.custom_minimum_size = Vector2(200, 40)
	controls_menu.add_child(btn_controls_back)
	btn_controls_back.pressed.connect(func():
		controls_menu.hide()
		esc_main_menu.show()
	)

func spawn_wall(pos: Vector3, player_rot_y: float):
	var wall = StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(4.0, 3.0, 1.0)
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.3, 0.2)
	mesh_inst.material_override = mat
	wall.add_child(mesh_inst)
	
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	
	nav_region.add_child(wall)
	wall.global_position = pos
	wall.global_position.y = 1.5
	wall.rotation.y = player_rot_y
	
	# Rebake navmesh to route around wall
	nav_region.bake_navigation_mesh(false)

func _update_local_music():
	var local_id = multiplayer.get_unique_id()
	if not players_container.has_node(str(local_id)): return
	var player = players_container.get_node(str(local_id))
	var pos = player.global_position
	
	var closest_idx = -1
	var min_dist = pos.distance_to(Vector3.ZERO) # Center defaults to main
	
	for i in range(ISLAND_POSITIONS.size()):
		var d = pos.distance_to(ISLAND_POSITIONS[i])
		if d < min_dist:
			min_dist = d
			closest_idx = i
			
	var target_track = "res://sounds/soundtrack-main.mp3"
	if closest_idx == 0: target_track = "res://sounds/soundtrack-white.mp3"
	elif closest_idx == 3: target_track = "res://sounds/soundtrack-mountain.mp3"
	elif closest_idx == 4: target_track = "res://sounds/soundtrack-forest.mp3"
	# Blue and Black also default to main as requested/implied by available tracks
	
	play_music(target_track)

func play_music(track_path: String):
	if current_track == track_path: return
	current_track = track_path
	
	var stream = music_cache.get(track_path, null)
	if not stream: return
	if stream is AudioStreamMP3:
		stream.loop = true
	
	var fade_time = 3.0
	var next_player = music_player_1 if active_music_player == 2 else music_player_2
	var prev_player = music_player_2 if active_music_player == 2 else music_player_1
	
	next_player.stream = stream
	next_player.play()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(next_player, "volume_db", -5.0, fade_time)
	tween.tween_property(prev_player, "volume_db", -80.0, fade_time)
	tween.tween_callback(func(): prev_player.stop()).set_delay(fade_time)
	
	active_music_player = 1 if active_music_player == 2 else 2
