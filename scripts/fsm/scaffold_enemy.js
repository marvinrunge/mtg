const fs = require('fs');
const fsmDir = 'scripts/fsm';

const enemyStateContent = `extends State
class_name EnemyState

var enemy: Enemy

func enter() -> void:
	enemy = parent as Enemy
`;
fs.writeFileSync(`${fsmDir}/EnemyState.gd`, enemyStateContent);

const enemyIdleContent = `extends EnemyState
class_name EnemyIdleState

func physics_update(delta: float) -> void:
	if enemy.is_dead:
		state_machine.change_state("death")
		return
	
	if enemy.stun_timer > 0:
		state_machine.change_state("stunned")
		return
		
	if enemy.current_animation != "idle":
		if is_instance_valid(enemy.anim_state):
			enemy.anim_state.travel("idle")
		enemy.current_animation = "idle"
		
	# Move to chase if we have an aggro target or need to move
	if enemy.aggro_target and is_instance_valid(enemy.aggro_target):
		state_machine.change_state("chase")
	elif not enemy.has_reached_base:
		state_machine.change_state("chase")
`;
fs.writeFileSync(`${fsmDir}/EnemyIdleState.gd`, enemyIdleContent);

const enemyChaseContent = `extends EnemyState
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
`;
fs.writeFileSync(`${fsmDir}/EnemyChaseState.gd`, enemyChaseContent);

const enemyAttackContent = `extends EnemyState
class_name EnemyAttackState

func physics_update(delta: float) -> void:
	if enemy.is_dead:
		state_machine.change_state("death")
		return
		
	if enemy.stun_timer > 0:
		state_machine.change_state("stunned")
		return
		
	enemy.velocity.x = move_toward(enemy.velocity.x, 0, enemy.speed)
	enemy.velocity.z = move_toward(enemy.velocity.z, 0, enemy.speed)
	
	if is_instance_valid(enemy.anim_state):
		if enemy.anim_state.get_current_node() == "attack":
			if enemy.anim_state.get_current_play_position() >= enemy.anim_state.get_current_length() - 0.1:
				state_machine.change_state("idle")
		elif enemy.anim_state.get_current_node() != "attack" and enemy.current_animation == "attack":
			# Still waiting for transition to start or it finished unexpectedly
			pass
`;
fs.writeFileSync(`${fsmDir}/EnemyAttackState.gd`, enemyAttackContent);

const enemyStunnedContent = `extends EnemyState
class_name EnemyStunnedState

func physics_update(delta: float) -> void:
	if enemy.is_dead:
		state_machine.change_state("death")
		return
		
	enemy.velocity.x = move_toward(enemy.velocity.x, 0, enemy.speed)
	enemy.velocity.z = move_toward(enemy.velocity.z, 0, enemy.speed)
	
	if enemy.stun_timer <= 0:
		state_machine.change_state("idle")
`;
fs.writeFileSync(`${fsmDir}/EnemyStunnedState.gd`, enemyStunnedContent);

const enemyDeathContent = `extends EnemyState
class_name EnemyDeathState

func enter() -> void:
	super.enter()
	enemy.velocity = Vector3.ZERO

func physics_update(delta: float) -> void:
	enemy.velocity.x = move_toward(enemy.velocity.x, 0, enemy.speed)
	enemy.velocity.z = move_toward(enemy.velocity.z, 0, enemy.speed)
`;
fs.writeFileSync(`${fsmDir}/EnemyDeathState.gd`, enemyDeathContent);

console.log("Enemy states generated.");

let enemyScript = fs.readFileSync('scripts/Enemy.gd', 'utf8');
const readyOld = '\tnav_agent = $NavigationAgent3D';
const readyNew = `\tnav_agent = $NavigationAgent3D
	
	if not has_node("StateMachine"):
		var sm = StateMachine.new()
		sm.name = "StateMachine"
		add_child(sm)
		
		var states = {
			"idle": preload("res://scripts/fsm/EnemyIdleState.gd").new(),
			"chase": preload("res://scripts/fsm/EnemyChaseState.gd").new(),
			"attack": preload("res://scripts/fsm/EnemyAttackState.gd").new(),
			"stunned": preload("res://scripts/fsm/EnemyStunnedState.gd").new(),
			"death": preload("res://scripts/fsm/EnemyDeathState.gd").new()
		}
		for s in states:
			states[s].name = s
			sm.add_child(states[s])
			
		sm.init(self, "idle")`;
enemyScript = enemyScript.replace(readyOld, readyNew);

const oldPhysics = `	# Add gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	if stun_timer > 0:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
		if knockback_velocity.length() > 0.1:
			velocity += knockback_velocity
			
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, delta * 5.0)
		move_and_slide()
		return
		
	if attack_cooldown > 0:
		attack_cooldown -= delta
		
	var target_pos = Vector3.ZERO
	var targeting_player = false
	
	if not is_instance_valid(aggro_target):
		# Look for players
		var closest = null
		var min_dist = 9999.0
		for player in get_tree().get_nodes_in_group("players"):
			if is_instance_valid(player):
				var dist = global_position.distance_to(player.global_position)
				if dist < aggro_range and dist < min_dist:
					min_dist = dist
					closest = player
		aggro_target = closest

	if is_instance_valid(aggro_target):
		target_pos = aggro_target.global_position
		targeting_player = true
	else:
		# Move to base
		var base = get_tree().root.get_node_or_null("Main/BaseCristal")
		if base:
			target_pos = base.global_position
		else:
			target_pos = global_position

	nav_agent.target_position = target_pos
	
	var current_dist = global_position.distance_to(target_pos)
	var current_attack_range = attack_range * $Visuals.scale.x
	
	if current_dist <= current_attack_range:
		has_reached_base = not targeting_player
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
		if attack_cooldown <= 0:
			attack_cooldown = ATTACK_INTERVAL
			_perform_attack(targeting_player)
			
		# Handle idle animation if not attacking
		if animation_player and current_animation != "attack" and animation_player.has_animation("idle"):
			if current_animation != "idle":
				if is_instance_valid(anim_state): anim_state.travel("idle")
				current_animation = "idle"
			
		return
	else:
		has_reached_base = false
		attack_cooldown -= delta
	
	var next_path_position = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_path_position)
	dir.y = 0
	
	# Separation force
	var separation = Vector3.ZERO
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != self and is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < 1.2:
				separation += global_position.direction_to(enemy.global_position) * -1.0 * (1.2 - dist)
	
	dir += separation
	
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
	else:
		dir = Vector3.ZERO
		
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	
	# Play walking animation
	var is_attacking = current_animation == "attack" and is_instance_valid(anim_state) and (anim_state.get_current_node() != "attack" or anim_state.get_current_play_position() < anim_state.get_current_length() - 0.1)
	if animation_player and not is_attacking:
		_play_move_anim()
	
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		
	knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, delta * 5.0)
	
	move_and_slide()`;

const newPhysics = `	# Add gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	if stun_timer > 0:
		stun_timer -= delta
		
	if attack_cooldown > 0:
		attack_cooldown -= delta

	var sm = get_node_or_null("StateMachine")
	if is_instance_valid(sm):
		sm.physics_update(delta)
		
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		
	knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, delta * 5.0)
	move_and_slide()`;

if (!enemyScript.includes('sm.physics_update(delta)')) {
    enemyScript = enemyScript.replace(oldPhysics, newPhysics);
    fs.writeFileSync('scripts/Enemy.gd', enemyScript, 'utf8');
    console.log("Enemy FSM hooked up.");
}
