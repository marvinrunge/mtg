extends Area3D
class_name HurtboxComponent

signal damage_received(amount: float, knockback_dir: Vector3)

@export var health_component: HealthComponent

func _ready() -> void:
	pass

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float, knockback_dir: Vector3 = Vector3.ZERO) -> void:
	if not is_multiplayer_authority():
		rpc_id(get_multiplayer_authority(), "take_damage", amount, knockback_dir)
		return
		
	damage_received.emit(amount, knockback_dir)
	
	if is_instance_valid(health_component):
		health_component.damage(amount)
