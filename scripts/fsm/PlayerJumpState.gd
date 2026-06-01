extends PlayerState
class_name PlayerJumpState

func enter() -> void:
	super.enter()
	player.jump_delay_timer = 0.75
	var is_running = Input.is_key_pressed(KEY_SHIFT)
	
	if is_running or Vector2(player.velocity.x, player.velocity.z).length() > 0.1:
		player.play_anim("jump_running")
		player.pending_jump_force = 5.0
	else:
		player.play_anim("jump")
		player.pending_jump_force = 2.5

func physics_update(delta: float) -> void:
	if player.jump_delay_timer > 0:
		player.jump_delay_timer -= delta
		if player.jump_delay_timer <= 0:
			player.velocity.y = player.pending_jump_force
			player.pending_jump_force = 0.0
			return # Wait for next frame so is_on_floor updates

	if player.jump_delay_timer <= 0 and player.is_on_floor() and player.velocity.y <= 0:
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
