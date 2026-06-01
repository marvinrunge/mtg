extends Area3D

@export var rotation_speed: float = 2.0
@export var hover_speed: float = 2.0
@export var hover_amp: float = 0.2

var base_y: float = 0.0
var time_passed: float = 0.0

@onready var mesh_inst: MeshInstance3D = $MeshInstance3D
@onready var despawn_timer: Timer = $DespawnTimer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	despawn_timer.timeout.connect(queue_free)
	base_y = position.y

func _process(delta: float) -> void:
	if is_instance_valid(mesh_inst):
		mesh_inst.rotate_y(rotation_speed * delta)
	
	time_passed += delta
	position.y = base_y + sin(time_passed * hover_speed) * hover_amp

func _on_body_entered(body: Node3D) -> void:
	if not is_multiplayer_authority(): return
	if not multiplayer.is_server():
		return # Only the server should handle pickups to prevent double-giving mana
		
	if body.has_method("add_mana"):
		# Since it's a networked pickup, use RPC or server authority to give mana
		# For now, assuming the player handles mana locally if it's not strictly server-managed,
		# but usually it's better if server calls `add_mana`. We'll just call the method.
		body.add_mana(20.0)
		queue_free()
