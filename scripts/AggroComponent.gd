extends Area3D
class_name AggroComponent

signal target_acquired(target: Node3D)
signal target_lost()

@export var aggro_range: float = 20.0
@export var leash_range: float = 40.0

var aggro_target: Node3D = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Detect Players on layer 2
	
	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = aggro_range
	col.shape = sphere
	add_child(col)
	
	body_entered.connect(_on_body_entered)
	
func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		set_physics_process(false)
		return
		
	if aggro_target:
		if not is_instance_valid(aggro_target):
			_drop_target()
		else:
			var dist = global_position.distance_to(aggro_target.global_position)
			if dist > leash_range:
				_drop_target()

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server(): return
	
	# Only acquire if we don't have a target, or if the new one is more relevant (keeping it simple for now)
	if aggro_target == null and is_instance_valid(body) and body.name != "Enemy": # Just ensuring it's not another enemy if layers get mixed
		gain_aggro(body)

func gain_aggro(target: Node3D) -> void:
	if not multiplayer.is_server() or not is_instance_valid(target): return
	
	aggro_target = target
	target_acquired.emit(target)

func _drop_target() -> void:
	aggro_target = null
	target_lost.emit()
	
	# After dropping, check if there are other valid targets still inside the aggro range
	var bodies = get_overlapping_bodies()
	for b in bodies:
		if is_instance_valid(b) and b.name != "Enemy":
			gain_aggro(b)
			break
