extends Area3D

var rotation_speed = 2.0
var hover_speed = 2.0
var hover_amp = 0.2
var base_y = 0.0
var time_passed = 0.0

func _ready():
	collision_mask = 2 # Player mask
	collision_layer = 0
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = PrismMesh.new()
	mesh.size = Vector3(0.3, 0.5, 0.3)
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.4, 1.0)
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	
	var light = OmniLight3D.new()
	light.light_color = Color(0.2, 0.6, 1.0)
	light.light_energy = 2.0
	light.omni_range = 3.0
	add_child(light)
	
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	add_child(shape)
	
	body_entered.connect(_on_body_entered)
	base_y = position.y
	
	# Despawn after 15 seconds
	var timer = Timer.new()
	timer.wait_time = 15.0
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)

func _process(delta):
	rotate_y(rotation_speed * delta)
	time_passed += delta
	position.y = base_y + sin(time_passed * hover_speed) * hover_amp

func _on_body_entered(body):
	if body.has_method("add_mana"):
		body.add_mana(20.0)
		queue_free()
