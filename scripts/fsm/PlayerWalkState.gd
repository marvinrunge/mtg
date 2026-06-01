extends PlayerState
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
		

	if Input.is_key_pressed(KEY_SPACE) and player.is_on_floor() and player.jump_delay_timer <= 0:
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
