extends Area3D
class_name HitboxComponent

@export var damage: float = 10.0
@export var knockback_force: float = 0.0
@export var single_hit: bool = true
@export var owner_node: Node = null

var _hit_targets: Array = []

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _on_area_entered(area: Area3D) -> void:
	if area is HurtboxComponent:
		if single_hit and _hit_targets.has(area):
			return
		
		_hit_targets.append(area)
		
		var push_dir = (area.global_position - global_position).normalized()
		area.take_damage(damage, push_dir * knockback_force)
		
		var body = area.get_parent()
		if is_instance_valid(body) and body.has_method("gain_aggro"):
			if is_instance_valid(owner_node):
				body.gain_aggro(owner_node)

func _on_body_entered(body: Node3D) -> void:
	if single_hit and _hit_targets.has(body):
		return
		
	if body.has_method("take_damage"):
		_hit_targets.append(body)
		
		var push_dir = (body.global_position - global_position).normalized()
		body.take_damage(damage, push_dir * knockback_force)
		
		if body.has_method("gain_aggro") and is_instance_valid(owner_node):
			body.gain_aggro(owner_node)

func reset_hits() -> void:
	_hit_targets.clear()
