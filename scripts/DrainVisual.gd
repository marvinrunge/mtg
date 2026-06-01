extends Node3D

var duration: float = 2.35
var hit_path: NodePath
var particles: CPUParticles3D

func setup(start_pos: Vector3, end_pos: Vector3, dur: float, path: NodePath) -> void:
	global_position = end_pos
	duration = dur
	hit_path = path
	
	_create_visuals()

func _create_visuals() -> void:
	particles = CPUParticles3D.new()
	particles.cast_shadow = 0
	particles.local_coords = false
	add_child(particles)
	
	particles.amount = 80
	particles.lifetime = 0.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.1
	particles.gravity = Vector3.ZERO
	particles.spread = 0.06
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 5.0
	
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.05
	p_mesh.height = 0.1
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.01, 0.0, 0.02)
	mat.emission_enabled = true
	mat.emission = Color(0.02, 0.0, 0.04)
	mat.emission_energy_multiplier = 0.5
	p_mesh.material = mat
	particles.mesh = p_mesh
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1, 0.0))
	particles.scale_amount_curve = curve
	
	particles.emitting = true
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(_on_timeout)
	
	# Register to clear out visual on timeout
	if not hit_path.is_empty():
		var player = get_tree().get_first_node_in_group("player") # Hacky, maybe parent handles this? We will fix this in Player.gd
		pass

func _physics_process(delta: float) -> void:
	# Assume parent sets direction. We actually need to track the hit node!
	if not hit_path.is_empty():
		var node = get_node_or_null(hit_path)
		if is_instance_valid(node):
			global_position = node.global_position + Vector3(0, 1.0, 0)
			# Needs a reference to the player to pull towards them.
			# Let's just find the player who spawned us.
			# Since we are added to root, we can pass player in setup.
			pass

func set_pull_target(target_pos: Vector3) -> void:
	if is_instance_valid(particles):
		var pull_dir = (target_pos - global_position).normalized()
		particles.direction = pull_dir
		particles.initial_velocity_min = global_position.distance_to(target_pos) * 2.0
		particles.initial_velocity_max = global_position.distance_to(target_pos) * 2.5

func _on_timeout():
	if is_instance_valid(particles):
		particles.emitting = false
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(queue_free)
