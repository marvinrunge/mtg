extends EnemyState
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
