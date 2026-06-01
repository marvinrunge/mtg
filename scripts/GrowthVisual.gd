extends Node3D

func setup(pos: Vector3) -> void:
	global_position = pos
	_create_visuals()

func _create_visuals() -> void:
	var particles = CPUParticles3D.new()
	particles.amount = 120
	particles.lifetime = 1.5
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 2.0
	particles.gravity = Vector3(0, 5, 0)
	particles.cast_shadow = 0 # Disable shadows for glowing effect
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 2.0
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1, 0.0))
	particles.scale_amount_curve = curve
	
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.15
	p_mesh.height = 0.3
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.2, 1.0, 0.2)
	p_mat.emission_enabled = true
	p_mat.emission = Color(0.2, 1.0, 0.2)
	p_mat.emission_energy_multiplier = 3.0
	p_mesh.material = p_mat
	particles.mesh = p_mesh
	
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(particles):
		particles.emitting = false
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(self):
			queue_free()
