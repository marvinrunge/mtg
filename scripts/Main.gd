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

var settings_container: VBoxContainer

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
	update_player_list_hud()
	
	if controls_label: controls_label.hide()
	if leave_button: leave_button.hide()
	
	music_player_1 = AudioStreamPlayer.new()
	music_player_2 = AudioStreamPlayer.new()
	music_player_1.bus = "Music"
	music_player_2.bus = "Music"
	add_child(music_player_1)
	add_child(music_player_2)
	music_player_1.volume_db = -80.0
	music_player_2.volume_db = -80.0
	
	leave_button.pressed.connect(_on_leave_button_pressed)
	
	_setup_audio_buses()
	_setup_settings_ui()
	
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
	
	if not multiplayer.is_server():
		return
		
	total_game_time += delta
		
	if wave_active:
		if enemies_spawned < enemies_to_spawn:
			wave_timer -= delta
			if wave_timer <= 0:
				spawn_enemy()
				# Scale down the spawn delay dynamically based on time (min 1.0s)
				wave_timer = max(1.0, 3.0 - (total_game_time / 60.0) * 0.25)
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
		enemies_to_spawn = min(30, 5 + current_wave * 2)
	enemies_spawned = 0
	enemies_alive = enemies_to_spawn
	wave_timer = max(0.2, 2.0 - (total_game_time / 60.0) * 0.5)
	
	rpc("announce_wave", current_wave)

func end_wave():
	wave_active = false
	# Wait 5 seconds before next wave
	await get_tree().create_timer(5.0).timeout
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
	var multiplier = 1.0 + (total_game_time / 120.0)
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
	var text = "Players (" + str(GameManager.players.size()) + "/5):\n"
	for id in GameManager.players:
		var details = GameManager.players[id]
		var line = "• " + details.get("name", "Player") + " (" + details.get("character", "Unknown") + ")"
		if id == multiplayer.get_unique_id():
			line += " [You]"
		text += line + "\n"
	player_list_label.text = text

func _on_leave_button_pressed():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.leave_game()

func toggle_menu(show: bool):
	if controls_label: controls_label.visible = show
	if leave_button: leave_button.visible = show
	if settings_container: settings_container.visible = show

func _setup_audio_buses():
	for bus_name in ["Music", "SFX", "Environment"]:
		var idx = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			AudioServer.add_bus()
			idx = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)

func _setup_settings_ui():
	settings_container = VBoxContainer.new()
	var vbox = $HUD/MarginContainer/VBoxContainer
	vbox.add_child(settings_container)
	settings_container.hide()
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	settings_container.add_child(spacer)
	
	var title = Label.new()
	title.text = "Audio Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	settings_container.add_child(title)
	
	var sliders = [
		{"name": "Master", "bus": "Master"},
		{"name": "Music", "bus": "Music"},
		{"name": "SFX", "bus": "SFX"},
		{"name": "Environment", "bus": "Environment"}
	]
	
	for s in sliders:
		var hbox = HBoxContainer.new()
		settings_container.add_child(hbox)
		
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
		hbox.add_child(slider)
		
		slider.value_changed.connect(func(val):
			var db = linear_to_db(val)
			if val <= 0.001: db = -80.0
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(s["bus"]), db)
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
