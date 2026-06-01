extends EnemyState
class_name EnemyDeathState

func enter() -> void:
	super.enter()
	enemy.velocity = Vector3.ZERO

func physics_update(delta: float) -> void:
	enemy.velocity.x = move_toward(enemy.velocity.x, 0, enemy.speed)
	enemy.velocity.z = move_toward(enemy.velocity.z, 0, enemy.speed)
