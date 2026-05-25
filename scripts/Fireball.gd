extends Area3D

var speed: float = 20.0
var damage: float = 40.0
var direction: Vector3 = Vector3.FORWARD
var multiplayer_id: int = 1

func _ready():
	body_entered.connect(_on_body_entered)
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if multiplayer.is_server():
		if body.has_method("take_damage"):
			body.take_damage(damage, direction)
			# Aggro the enemy to the fireball's owner
			if body.has_method("gain_aggro"):
				var owner_player = get_tree().root.get_node_or_null("Main/PlayersContainer/" + str(multiplayer_id))
				if owner_player:
					body.gain_aggro(owner_player)

	# Visual explosion
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.visible = false
		
	var light = get_node_or_null("OmniLight3D")
	if light:
		light.visible = false
		
	var particles = get_node_or_null("CPUParticles3D")
	if particles:
		particles.emitting = false
		
	# Shockwave Sphere
	var shockwave = MeshInstance3D.new()
	var sw_mesh = SphereMesh.new()
	sw_mesh.radius = 1.0
	sw_mesh.height = 2.0
	shockwave.mesh = sw_mesh
	var sw_mat = StandardMaterial3D.new()
	sw_mat.albedo_color = Color(1.0, 0.6, 0.0, 0.8)
	sw_mat.emission_enabled = true
	sw_mat.emission = Color(1.0, 0.4, 0.0)
	sw_mat.emission_energy_multiplier = 4.0
	sw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shockwave.material_override = sw_mat
	add_child(shockwave)
	
	# Explosion Particles
	var exp_particles = CPUParticles3D.new()
	exp_particles.amount = 80
	exp_particles.lifetime = 0.6
	exp_particles.explosiveness = 0.95
	exp_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	exp_particles.emission_sphere_radius = 0.5
	exp_particles.spread = 180.0
	exp_particles.initial_velocity_min = 8.0
	exp_particles.initial_velocity_max = 14.0
	exp_particles.damping_min = 10.0
	exp_particles.damping_max = 15.0
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 2.0))
	curve.add_point(Vector2(1, 0.0))
	exp_particles.scale_amount_curve = curve
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.1, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1), Color(1, 0.8, 0.2), Color(0.8, 0.2, 0), Color(0.2, 0.1, 0.1, 0)])
	exp_particles.color_ramp = grad
	
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.15
	p_mesh.height = 0.3
	p_mesh.radial_segments = 8
	p_mesh.rings = 4
	var p_mat = StandardMaterial3D.new()
	p_mat.vertex_color_use_as_albedo = true
	p_mat.albedo_color = Color(1, 1, 1)
	p_mat.emission_enabled = true
	p_mat.emission = Color(1, 0.5, 0)
	p_mat.emission_energy_multiplier = 4.0
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mesh.material = p_mat
	exp_particles.mesh = p_mesh
	add_child(exp_particles)
	exp_particles.emitting = true
	
	# Light Burst
	if light:
		light.visible = true
		light.light_energy = 15.0
		light.omni_range = 15.0
		var tween = create_tween().set_parallel(true)
		tween.tween_property(light, "light_energy", 0.0, 0.4)
		tween.tween_property(shockwave, "scale", Vector3(4, 4, 4), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sw_mat, "albedo_color:a", 0.0, 0.3)
		tween.tween_property(sw_mat, "emission_energy_multiplier", 0.0, 0.3)
	
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	
	await get_tree().create_timer(1.0).timeout
	queue_free()
