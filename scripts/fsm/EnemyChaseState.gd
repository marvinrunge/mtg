extends EnemyState
class_name EnemyChaseState

func physics_update(delta: float) -> void:
	if enemy.is_dead:
		state_machine.change_state("death")
		return
		
	if enemy.stun_timer > 0:
		state_machine.change_state("stunned")
		return
		
	# Chase logic
	if not is_instance_valid(enemy.aggro_target):
		var closest = null
		var min_dist = 9999.0
		for p in enemy.get_tree().get_nodes_in_group("players"):
			if is_instance_valid(p):
				var dist = enemy.global_position.distance_to(p.global_position)
				if dist < enemy.aggro_range and dist < min_dist:
					min_dist = dist
					closest = p
		enemy.aggro_target = closest

	var target_pos = Vector3.ZERO
	var targeting_player = false
	
	if is_instance_valid(enemy.aggro_target):
		target_pos = enemy.aggro_target.global_position
		targeting_player = true
	else:
		var base = enemy.get_tree().root.get_node_or_null("Main/BaseCristal")
		if base:
			target_pos = base.global_position
		else:
			target_pos = enemy.global_position

	enemy.nav_agent.target_position = target_pos
	var current_dist = enemy.global_position.distance_to(target_pos)
	var current_attack_range = enemy.attack_range * (enemy.get_node("Visuals").scale.x if enemy.has_node("Visuals") else 1.0)
	
	if current_dist <= current_attack_range:
		enemy.has_reached_base = not targeting_player
		if enemy.attack_cooldown <= 0:
			enemy.attack_cooldown = enemy.ATTACK_INTERVAL
			enemy._perform_attack(targeting_player)
			state_machine.change_state("attack")
		else:
			state_machine.change_state("idle")
		return
	else:
		enemy.has_reached_base = false
		
	# Move
	var next_path_position = enemy.nav_agent.get_next_path_position()
	var dir = enemy.global_position.direction_to(next_path_position)
	dir.y = 0
	
	var separation = Vector3.ZERO
	for other in enemy.get_tree().get_nodes_in_group("enemies"):
		if other != enemy and is_instance_valid(other):
			var dist = enemy.global_position.distance_to(other.global_position)
			if dist < 1.2:
				separation += enemy.global_position.direction_to(other.global_position) * -1.0 * (1.2 - dist)
	
	dir += separation
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
	else:
		dir = Vector3.ZERO
		
	enemy.velocity.x = dir.x * enemy.speed
	enemy.velocity.z = dir.z * enemy.speed
	
	if enemy.current_animation != "running":
		if is_instance_valid(enemy.anim_state):
			enemy.anim_state.travel("running")
		enemy.current_animation = "running"
