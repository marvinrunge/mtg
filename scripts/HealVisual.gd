extends Node3D

func setup(pos: Vector3) -> void:
	global_position = pos
	_create_visuals()

func _create_visuals() -> void:
	# Particles
	var particles = CPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.0
	particles.gravity = Vector3(0, 3, 0)
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.1
	p_mesh.height = 0.2
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(1.0, 0.9, 0.4)
	p_mat.emission_enabled = true
	p_mat.emission = Color(1.0, 0.8, 0.2)
	p_mat.emission_energy_multiplier = 5.0
	p_mesh.material = p_mat
	particles.mesh = p_mesh
	
	# Smooth fade out for particles (shrink to 0)
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(0.7, 1.0))
	curve.add_point(Vector2(1, 0.0))
	particles.scale_amount_curve = curve
	
	add_child(particles)
	particles.emitting = true
	
	# Holy Light Beam
	var beam = SpotLight3D.new()
	beam.spot_range = 15.0
	beam.spot_angle = 15.0
	beam.light_color = Color(1.0, 0.9, 0.5)
	beam.light_energy = 8.0
	beam.position.y = 8.0
	beam.rotation.x = - PI / 2.0 # Point down
	add_child(beam)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(beam, "light_energy", 0.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(queue_free)
