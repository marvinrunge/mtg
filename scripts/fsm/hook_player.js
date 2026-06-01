const fs = require('fs');

let content = fs.readFileSync('scripts/PlayerController.gd', 'utf8');

const readyInjection = `
	_apply_player_details()
	
	# FSM Setup
	state_machine = StateMachine.new()
	state_machine.name = "StateMachine"
	add_child(state_machine)
	
	var states = {
		"idle": PlayerIdleState.new(),
		"walk": PlayerWalkState.new(),
		"run": PlayerRunState.new(),
		"jump": PlayerJumpState.new(),
		"attack": PlayerAttackState.new(),
		"cast": PlayerCastState.new()
	}
	for s_name in states:
		states[s_name].name = s_name
		state_machine.add_child(states[s_name])
		
	state_machine.init(self, "idle")
`;

content = content.replace('\t_apply_player_details()', readyInjection);

if (!content.includes('var state_machine: StateMachine')) {
    content = content.replace('var input: PlayerInput', 'var input: PlayerInput\nvar state_machine: StateMachine');
}

const physicsProcessOld = `	# Add gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	var is_running = false
	if is_instance_valid(input): is_running = Input.is_key_pressed(KEY_SHIFT)
	var current_speed = run_speed if is_running else speed
	
	# Movement vectors (forward/back and left/right)
	var forward_dir = Input.get_axis("move_forward", "move_back")
	var strafe_dir = Input.get_axis("move_left", "move_right") # A is negative, D is positive
	var direction = (transform.basis * Vector3(strafe_dir, 0, forward_dir)).normalized()
	
	var is_acting = false
	var is_act_anim = current_animation.begins_with("attack") or current_animation == "pickup" or current_animation.begins_with("cast_") or current_animation.begins_with("standing")
	if is_act_anim and is_instance_valid(anim_state):
		if anim_state.get_current_node() == current_animation:
			if anim_state.get_current_play_position() < anim_state.get_current_length() - 0.1:
				is_acting = true
		else:
			is_acting = true
	
	if is_acting:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	elif direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		if current_anim_player: current_anim_player.speed_scale = current_speed / speed
		
		var is_jumping_windup = jump_delay_timer > 0
		if is_on_floor() and not is_jumping_windup:
			var anim_to_play = "idle"
			if is_running:
				if forward_dir < 0: anim_to_play = "run_forward"
				elif forward_dir > 0: anim_to_play = "run_back"
				elif strafe_dir < 0: anim_to_play = "run_left"
				elif strafe_dir > 0: anim_to_play = "run_right"
			else:
				if forward_dir < 0: anim_to_play = "walk_forward"
				elif forward_dir > 0: anim_to_play = "walk_back"
				elif strafe_dir < 0: anim_to_play = "walk_left"
				elif strafe_dir > 0: anim_to_play = "walk_right"
				
			if anim_to_play != "idle":
				play_anim(anim_to_play)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		var is_jumping_windup = jump_delay_timer > 0
		if is_on_floor() and not is_jumping_windup:
			var target_idle = "idle3" if (is_instance_valid(caster) and caster.is_charging_fireball) else "idle1"
			if current_animation != target_idle:
				play_anim(target_idle)
	
	var was_in_air = not is_on_floor()`;

const physicsProcessNew = `	# Add gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	if is_instance_valid(state_machine):
		state_machine.physics_update(delta)
	
	var was_in_air = not is_on_floor()`;

content = content.replace(physicsProcessOld, physicsProcessNew);

// Also remove the old `Input.is_action_just_pressed("attack")` in _process or _physics_process?
// It was in _process:
const processOld = `func _process(delta):
	if is_multiplayer_authority() and is_instance_valid(input):
		if Input.is_action_just_pressed("attack") and punch_cooldown <= 0:
			punch_cooldown = 0.5
			if current_animation != "attack1":
				_perform_punch()
				
		if Input.is_action_just_pressed("jump") and is_on_floor() and jump_delay_timer <= 0:
			var is_acting = (current_animation.begins_with("attack") or current_animation == "pickup" or current_animation.begins_with("cast_")) and is_instance_valid(anim_state) and anim_state.get_current_node() == current_animation
			if not is_acting:
				jump_delay_timer = 0.1
				play_anim("jump")`;

const processNew = `func _process(delta):
	if is_multiplayer_authority() and is_instance_valid(state_machine):
		state_machine.update(delta)`;

content = content.replace(processOld, processNew);

fs.writeFileSync('scripts/PlayerController.gd', content);
console.log("PlayerController FSM hooked up.");
