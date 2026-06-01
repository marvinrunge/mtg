extends EnemyState
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
