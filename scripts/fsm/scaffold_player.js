const fs = require('fs');

const fsmDir = 'scripts/fsm';

const playerStateContent = `extends State
class_name PlayerState

var player

func enter() -> void:
	player = parent
`;
fs.writeFileSync(`${fsmDir}/PlayerState.gd`, playerStateContent);

const playerIdleStateContent = `extends PlayerState
class_name PlayerIdleState

func update(delta: float) -> void:
	var target_idle = "idle3" if (is_instance_valid(player.caster) and player.caster.is_charging_fireball) else "idle1"
	if player.current_animation != target_idle:
		player.play_anim(target_idle)

func physics_update(delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0, player.speed)
	player.velocity.z = move_toward(player.velocity.z, 0, player.speed)
	
	if Input.is_action_just_pressed("attack") and player.punch_cooldown <= 0:
		state_machine.change_state("attack")
		return
		
	if Input.is_action_just_pressed("jump") and player.is_on_floor() and player.jump_delay_timer <= 0:
		state_machine.change_state("jump")
		return
		
	var forward_dir = Input.get_axis("move_forward", "move_back")
	var strafe_dir = Input.get_axis("move_left", "move_right")
	if forward_dir != 0 or strafe_dir != 0:
		if Input.is_key_pressed(KEY_SHIFT):
			state_machine.change_state("run")
		else:
			state_machine.change_state("walk")
`;
fs.writeFileSync(`${fsmDir}/PlayerIdleState.gd`, playerIdleStateContent);

const playerWalkStateContent = `extends PlayerState
class_name PlayerWalkState

func physics_update(delta: float) -> void:
	var forward_dir = Input.get_axis("move_forward", "move_back")
	var strafe_dir = Input.get_axis("move_left", "move_right")
	
	if forward_dir == 0 and strafe_dir == 0:
		state_machine.change_state("idle")
		return
		
	if Input.is_key_pressed(KEY_SHIFT):
		state_machine.change_state("run")
		return
		
	if Input.is_action_just_pressed("attack") and player.punch_cooldown <= 0:
		state_machine.change_state("attack")
		return
		
	if Input.is_action_just_pressed("jump") and player.is_on_floor() and player.jump_delay_timer <= 0:
		state_machine.change_state("jump")
		return
		
	var direction = (player.transform.basis * Vector3(strafe_dir, 0, forward_dir)).normalized()
	player.velocity.x = direction.x * player.speed
	player.velocity.z = direction.z * player.speed
	if player.current_anim_player: player.current_anim_player.speed_scale = 1.0
	
	if player.is_on_floor():
		var anim_to_play = "walk_forward"
		if forward_dir < 0: anim_to_play = "walk_forward"
		elif forward_dir > 0: anim_to_play = "walk_back"
		elif strafe_dir < 0: anim_to_play = "walk_left"
		elif strafe_dir > 0: anim_to_play = "walk_right"
		player.play_anim(anim_to_play)
`;
fs.writeFileSync(`${fsmDir}/PlayerWalkState.gd`, playerWalkStateContent);

const playerRunStateContent = `extends PlayerState
class_name PlayerRunState

func physics_update(delta: float) -> void:
	var forward_dir = Input.get_axis("move_forward", "move_back")
	var strafe_dir = Input.get_axis("move_left", "move_right")
	
	if forward_dir == 0 and strafe_dir == 0:
		state_machine.change_state("idle")
		return
		
	if not Input.is_key_pressed(KEY_SHIFT):
		state_machine.change_state("walk")
		return
		
	if Input.is_action_just_pressed("attack") and player.punch_cooldown <= 0:
		state_machine.change_state("attack")
		return
		
	if Input.is_action_just_pressed("jump") and player.is_on_floor() and player.jump_delay_timer <= 0:
		state_machine.change_state("jump")
		return
		
	var direction = (player.transform.basis * Vector3(strafe_dir, 0, forward_dir)).normalized()
	player.velocity.x = direction.x * player.run_speed
	player.velocity.z = direction.z * player.run_speed
	if player.current_anim_player: player.current_anim_player.speed_scale = player.run_speed / player.speed
	
	if player.is_on_floor():
		var anim_to_play = "run_forward"
		if forward_dir < 0: anim_to_play = "run_forward"
		elif forward_dir > 0: anim_to_play = "run_back"
		elif strafe_dir < 0: anim_to_play = "run_left"
		elif strafe_dir > 0: anim_to_play = "run_right"
		player.play_anim(anim_to_play)
`;
fs.writeFileSync(`${fsmDir}/PlayerRunState.gd`, playerRunStateContent);

const playerJumpStateContent = `extends PlayerState
class_name PlayerJumpState

func enter() -> void:
	super.enter()
	player.jump_delay_timer = 0.1
	player.play_anim("jump")

func physics_update(delta: float) -> void:
	if player.jump_delay_timer <= 0 and player.is_on_floor():
		state_machine.change_state("idle")
		return
		
	# Allow mid-air movement
	var forward_dir = Input.get_axis("move_forward", "move_back")
	var strafe_dir = Input.get_axis("move_left", "move_right")
	var is_running = Input.is_key_pressed(KEY_SHIFT)
	var current_speed = player.run_speed if is_running else player.speed
	var direction = (player.transform.basis * Vector3(strafe_dir, 0, forward_dir)).normalized()
	
	if direction != Vector3.ZERO:
		player.velocity.x = direction.x * current_speed
		player.velocity.z = direction.z * current_speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, current_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, current_speed)
`;
fs.writeFileSync(`${fsmDir}/PlayerJumpState.gd`, playerJumpStateContent);

const playerAttackStateContent = `extends PlayerState
class_name PlayerAttackState

func enter() -> void:
	super.enter()
	player.punch_cooldown = 0.5
	if player.current_animation != "attack1":
		player._perform_punch() # wait, _perform_punch already plays "attack1"
	else:
		# Already playing, shouldn't happen unless double called
		pass
		
func physics_update(delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0, player.speed)
	player.velocity.z = move_toward(player.velocity.z, 0, player.speed)
	
	if is_instance_valid(player.anim_state):
		if player.anim_state.get_current_node() == player.current_animation:
			if player.anim_state.get_current_play_position() >= player.anim_state.get_current_length() - 0.1:
				state_machine.change_state("idle")
`;
fs.writeFileSync(`${fsmDir}/PlayerAttackState.gd`, playerAttackStateContent);

const playerCastStateContent = `extends PlayerState
class_name PlayerCastState

var is_done = false

func enter() -> void:
	super.enter()
	is_done = false
		
func physics_update(delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0, player.speed)
	player.velocity.z = move_toward(player.velocity.z, 0, player.speed)
	
	if is_instance_valid(player.anim_state):
		if player.anim_state.get_current_node() == player.current_animation:
			if player.anim_state.get_current_play_position() >= player.anim_state.get_current_length() - 0.1:
				state_machine.change_state("idle")
		else:
			# Not transitioned yet or transitioned out
			pass
`;
fs.writeFileSync(`${fsmDir}/PlayerCastState.gd`, playerCastStateContent);

console.log("Player States generated.");
