extends PlayerState
class_name PlayerIdleState

func update(delta: float) -> void:
	var target_idle = "idle3" if (is_instance_valid(player.caster) and player.caster.is_charging_fireball) else "idle1"
	if player.current_animation != target_idle:
		player.play_anim(target_idle)

func physics_update(delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0, player.speed)
	player.velocity.z = move_toward(player.velocity.z, 0, player.speed)
	

	if Input.is_key_pressed(KEY_SPACE) and player.is_on_floor() and player.jump_delay_timer <= 0:
		state_machine.change_state("jump")
		return
		
	var forward_dir = Input.get_axis("move_forward", "move_back")
	var strafe_dir = Input.get_axis("move_left", "move_right")
	if forward_dir != 0 or strafe_dir != 0:
		if Input.is_key_pressed(KEY_SHIFT):
			state_machine.change_state("run")
		else:
			state_machine.change_state("walk")
