extends PlayerState
class_name PlayerAttackState

func enter() -> void:
	super.enter()
	player.punch_cooldown = 0.8
	player.rpc("trigger_anim", "attack")
		
func physics_update(delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0, player.speed)
	player.velocity.z = move_toward(player.velocity.z, 0, player.speed)
	
	if is_instance_valid(player.anim_state):
		if player.anim_state.get_current_node() == player.current_animation:
			if player.anim_state.get_current_play_position() >= player.anim_state.get_current_length() - 0.1:
				state_machine.change_state("idle")
