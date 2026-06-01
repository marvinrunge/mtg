const fs = require('fs');

function setupMain() {
    let content = fs.readFileSync('scripts/Main.gd', 'utf8');

    // Add spawner creation logic for pickups
    const readyOld = `	proj_spawner.add_spawnable_scene("res://scenes/Fireball.tscn")
	add_child(proj_spawner)`;
    const readyNew = `	proj_spawner.add_spawnable_scene("res://scenes/Fireball.tscn")
	add_child(proj_spawner)
	
	# Setup Pickups Spawner dynamically
	var pickup_container = Node3D.new()
	pickup_container.name = "PickupsContainer"
	add_child(pickup_container)
	var pickup_spawner = MultiplayerSpawner.new()
	pickup_spawner.name = "PickupsSpawner"
	pickup_spawner.spawn_path = pickup_container.get_path()
	pickup_spawner.add_spawnable_scene("res://scenes/ManaCrystal.tscn")
	add_child(pickup_spawner)`;
    if (!content.includes('PickupsContainer')) {
        content = content.replace(readyOld, readyNew);
    }
    fs.writeFileSync('scripts/Main.gd', content);
    console.log("Main updated for Pickups");
}

function setupEnemy() {
    let content = fs.readFileSync('scripts/Enemy.gd', 'utf8');

    const dropOld = `func drop_mana_crystal():
	var crystal = MANA_CRYSTAL_SCENE.instantiate()
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		main.add_child(crystal)
		crystal.global_position = global_position + Vector3(0, 0.5, 0)`;

    const dropNew = `func drop_mana_crystal():
	if not is_multiplayer_authority(): return
	var crystal = MANA_CRYSTAL_SCENE.instantiate()
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var container = main.get_node_or_null("PickupsContainer")
		if container:
			container.add_child(crystal, true)
		else:
			main.add_child(crystal, true)
		crystal.global_position = global_position + Vector3(0, 0.5, 0)`;

    content = content.replace(dropOld, dropNew);

    fs.writeFileSync('scripts/Enemy.gd', content);
    console.log("Enemy updated for Pickups");
}

function setupManaCrystal() {
    let content = fs.readFileSync('scripts/ManaCrystal.gd', 'utf8');

    const readyOld = `func _ready():
	# Animation setup`;
    const readyNew = `func _ready():
	var sync = MultiplayerSynchronizer.new()
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	sync.replication_config = config
	add_child(sync)
	
	# Animation setup`;
    if (!content.includes('MultiplayerSynchronizer.new()')) {
        content = content.replace(readyOld, readyNew);
    }
    
    // Check if it has a body_entered connection to make it authoritative
    const bodyOld = `func _on_body_entered(body: Node3D) -> void:`;
    const bodyNew = `func _on_body_entered(body: Node3D) -> void:
	if not is_multiplayer_authority(): return`;
    if (content.includes('_on_body_entered')) {
        content = content.replace(bodyOld, bodyNew);
    }

    fs.writeFileSync('scripts/ManaCrystal.gd', content);
    console.log("ManaCrystal updated");
}

setupMain();
setupEnemy();
setupManaCrystal();
