extends State
class_name EnemyState

var enemy: Enemy

func enter() -> void:
	enemy = parent as Enemy
