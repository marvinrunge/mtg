extends Node
class_name HealthComponent

signal health_changed(new_health: float, max_health: float)
signal health_depleted
signal max_health_changed(new_max: float)

@export var max_health: float = 100.0 : set = set_max_health
@onready var health: float = max_health

func _ready() -> void:
	health = max_health
	# Delay first emit slightly so listeners have time to connect if instantiated via code
	call_deferred("_emit_initial")

func _emit_initial() -> void:
	health_changed.emit(health, max_health)

func set_max_health(value: float) -> void:
	max_health = max(1.0, value)
	health = min(health, max_health)
	max_health_changed.emit(max_health)
	health_changed.emit(health, max_health)

func damage(amount: float) -> void:
	if health <= 0:
		return
	
	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)
	
	if health <= 0:
		health_depleted.emit()

func heal(amount: float) -> void:
	if health <= 0:
		return
		
	health = min(health + amount, max_health)
	health_changed.emit(health, max_health)

func full_heal() -> void:
	health = max_health
	health_changed.emit(health, max_health)
