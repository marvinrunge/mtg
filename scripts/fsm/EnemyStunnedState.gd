extends EnemyState
class_name EnemyStunnedState

func physics_update(delta: float) -> void:
	if enemy.is_dead:
		state_machine.change_state("death")
		return
		
	enemy.velocity.x = move_toward(enemy.velocity.x, 0, enemy.speed)
	enemy.velocity.z = move_toward(enemy.velocity.z, 0, enemy.speed)
	
	if enemy.stun_timer <= 0:
		state_machine.change_state("idle")
