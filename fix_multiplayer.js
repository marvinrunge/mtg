const fs = require('fs');

function setupFireball() {
    let content = fs.readFileSync('scripts/Fireball.gd', 'utf8');

    // Make physics authoritative
    const physOld = `func _physics_process(delta: float) -> void:
	position += direction * speed * delta`;
    const physNew = `func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	position += direction * speed * delta`;
    content = content.replace(physOld, physNew);

    // Make body_entered authoritative
    const bodyOld = `func _on_body_entered(body: Node3D) -> void:
	if has_exploded: return`;
    const bodyNew = `func _on_body_entered(body: Node3D) -> void:
	if not is_multiplayer_authority() or has_exploded: return`;
    content = content.replace(bodyOld, bodyNew);

    // Setup MultiplayerSynchronizer in _ready
    const readyOld = `func _ready() -> void:
	body_entered.connect(_on_body_entered)`;
    const readyNew = `func _ready() -> void:
	var sync = MultiplayerSynchronizer.new()
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.add_property(NodePath(".:has_exploded"))
	sync.replication_config = config
	add_child(sync)
	
	body_entered.connect(_on_body_entered)`;
    content = content.replace(readyOld, readyNew);

    fs.writeFileSync('scripts/Fireball.gd', content);
    console.log("Fireball updated");
}

function setupEnemy() {
    let content = fs.readFileSync('scripts/Enemy.gd', 'utf8');

    // Setup MultiplayerSynchronizer in _ready
    const readyOld = `func _ready():
	_setup_materials()`;
    const readyNew = `func _ready():
	var sync = MultiplayerSynchronizer.new()
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.add_property(NodePath(".:rotation"))
	config.add_property(NodePath(".:health"))
	config.add_property(NodePath(".:current_animation"))
	sync.replication_config = config
	add_child(sync)
	
	_setup_materials()`;
    if (!content.includes('MultiplayerSynchronizer.new()')) {
        content = content.replace(readyOld, readyNew);
    }
    
    // Physics process authority
    const physOld = `func _physics_process(delta):
	if is_dead: return`;
    const physNew = `func _physics_process(delta):
	if is_dead or not is_multiplayer_authority(): return`;
    content = content.replace(physOld, physNew);

    fs.writeFileSync('scripts/Enemy.gd', content);
    console.log("Enemy updated");
}

function setupPlayerCaster() {
    let content = fs.readFileSync('scripts/PlayerCaster.gd', 'utf8');
    
    const releaseOld = `@rpc("any_peer", "call_local", "reliable")
func release_fireball(target_pos: Vector3, mana_amount: float):
	if controller.charge_audio_player and controller.charge_audio_player.playing:
		var audio_tween = create_tween()
		audio_tween.tween_property(controller.charge_audio_player, "volume_db", -80.0, 1.0)
		audio_tween.tween_callback(func(): controller.charge_audio_player.stop())
		
	controller.play_anim("cast_fireball")
	if controller.get("state_machine") and is_instance_valid(controller.state_machine): controller.state_machine.change_state("cast")
	
	if is_instance_valid(controller.magic_essence_sphere):
		var tween = create_tween()
		tween.tween_property(controller.magic_essence_sphere, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		if is_instance_valid(controller.magic_essence_particles):
			controller.magic_essence_particles.initial_velocity_min = 0.05
			controller.magic_essence_particles.initial_velocity_max = 0.2
			controller.magic_essence_particles.radial_accel_min = 0.0
			controller.magic_essence_particles.radial_accel_max = 0.0
			controller.magic_essence_particles.scale_amount_max = 1.8
			
	# Delay fireball spawn to match animation peak
	await controller.get_tree().create_timer(0.3).timeout
		
	var start_pos = _get_spell_origin()
	create_fireball(start_pos, target_pos, mana_amount)
	
	# Delay fireball sound to 0.5s
	await controller.get_tree().create_timer(0.2).timeout
	controller.play_sound("res://sounds/fireball.wav", -10.0)`;

    const releaseNew = `@rpc("any_peer", "call_local", "reliable")
func release_fireball(target_pos: Vector3, mana_amount: float):
	if controller.charge_audio_player and controller.charge_audio_player.playing:
		var audio_tween = create_tween()
		audio_tween.tween_property(controller.charge_audio_player, "volume_db", -80.0, 1.0)
		audio_tween.tween_callback(func(): controller.charge_audio_player.stop())
		
	controller.play_anim("cast_fireball")
	if controller.get("state_machine") and is_instance_valid(controller.state_machine): controller.state_machine.change_state("cast")
	
	if is_instance_valid(controller.magic_essence_sphere):
		var tween = create_tween()
		tween.tween_property(controller.magic_essence_sphere, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		if is_instance_valid(controller.magic_essence_particles):
			controller.magic_essence_particles.initial_velocity_min = 0.05
			controller.magic_essence_particles.initial_velocity_max = 0.2
			controller.magic_essence_particles.radial_accel_min = 0.0
			controller.magic_essence_particles.radial_accel_max = 0.0
			controller.magic_essence_particles.scale_amount_max = 1.8
			
	# Delay fireball spawn to match animation peak
	await controller.get_tree().create_timer(0.3).timeout
		
	var start_pos = _get_spell_origin()
	if controller.multiplayer.is_server():
		create_fireball(start_pos, target_pos, mana_amount)
	
	# Delay fireball sound to 0.5s
	await controller.get_tree().create_timer(0.2).timeout
	controller.play_sound("res://sounds/fireball.wav", -10.0)`;

    content = content.replace(releaseOld, releaseNew);

    const createOld = `func create_fireball(start_pos: Vector3, target_pos: Vector3, mana_amount: float = 10.0):
	var fireball = FIREBALL_SCENE.instantiate()
	fireball.direction = (target_pos - start_pos).normalized()
	fireball.damage = mana_amount * controller.damage_multiplier
	fireball.charge_mult = 1.0 + clamp((mana_amount - 10.0) / 90.0, 0.0, 1.0) * 3.0
	fireball.position = start_pos
	
	controller.get_tree().root.add_child(fireball)`;

    const createNew = `func create_fireball(start_pos: Vector3, target_pos: Vector3, mana_amount: float = 10.0):
	if not controller.multiplayer.is_server(): return
	var fireball = FIREBALL_SCENE.instantiate()
	fireball.direction = (target_pos - start_pos).normalized()
	fireball.damage = mana_amount * controller.damage_multiplier
	fireball.charge_mult = 1.0 + clamp((mana_amount - 10.0) / 90.0, 0.0, 1.0) * 3.0
	fireball.position = start_pos
	
	var main = controller.get_tree().root.get_node_or_null("Main")
	if main:
		var container = main.get_node_or_null("ProjectilesContainer")
		if not container:
			container = Node3D.new()
			container.name = "ProjectilesContainer"
			main.add_child(container)
			var spawner = MultiplayerSpawner.new()
			spawner.name = "ProjectilesSpawner"
			spawner.spawn_path = container.get_path()
			spawner.add_spawnable_scene("res://scenes/Fireball.tscn")
			main.add_child(spawner)
		container.add_child(fireball, true)
	else:
		controller.get_tree().root.add_child(fireball, true)`;
		
    content = content.replace(createOld, createNew);

    fs.writeFileSync('scripts/PlayerCaster.gd', content);
    console.log("PlayerCaster updated");
}

function setupMain() {
    let content = fs.readFileSync('scripts/Main.gd', 'utf8');

    // Add spawner creation logic for dynamic spawners if not present
    const readyOld = `	$MultiplayerSpawner.add_spawnable_scene("res://scenes/Player.tscn")`;
    const readyNew = `	$MultiplayerSpawner.add_spawnable_scene("res://scenes/Player.tscn")
	
	# Setup Projectiles Spawner dynamically
	var proj_container = Node3D.new()
	proj_container.name = "ProjectilesContainer"
	add_child(proj_container)
	var proj_spawner = MultiplayerSpawner.new()
	proj_spawner.name = "ProjectilesSpawner"
	proj_spawner.spawn_path = proj_container.get_path()
	proj_spawner.add_spawnable_scene("res://scenes/Fireball.tscn")
	add_child(proj_spawner)`;
    if (!content.includes('ProjectilesContainer')) {
        content = content.replace(readyOld, readyNew);
    }
	
	// Enemy spawn logic already uses EnemiesContainer which has a spawner in Main.tscn
    fs.writeFileSync('scripts/Main.gd', content);
    console.log("Main updated");
}

function setupPlayer() {
    let content = fs.readFileSync('scripts/PlayerController.gd', 'utf8');

    // Setup MultiplayerSynchronizer in _ready
    const readyOld = `func _ready() -> void:
	if is_multiplayer_authority():`;
    const readyNew = `func _ready() -> void:
	var sync = MultiplayerSynchronizer.new()
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.add_property(NodePath(".:rotation"))
	config.add_property(NodePath(".:health"))
	sync.replication_config = config
	add_child(sync)

	if is_multiplayer_authority():`;
    if (!content.includes('MultiplayerSynchronizer.new()')) {
        content = content.replace(readyOld, readyNew);
    }

    fs.writeFileSync('scripts/PlayerController.gd', content);
    console.log("PlayerController updated");
}

setupFireball();
setupEnemy();
setupPlayerCaster();
setupMain();
setupPlayer();
