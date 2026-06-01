extends Node3D

var distance: float = 10.0

func setup(start_pos: Vector3, end_pos: Vector3) -> void:
	distance = start_pos.distance_to(end_pos)
	global_position = start_pos
	var up = Vector3.UP
	if abs((end_pos - start_pos).normalized().y) > 0.99: up = Vector3.RIGHT
	look_at(end_pos, up)
	
	_create_visuals()

func _create_visuals() -> void:
	# The Beam
	var beam = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = distance
	cyl.radial_segments = 8
	beam.mesh = cyl
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.z = - distance / 2.0
	beam.rotation.x = PI / 2.0
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	mat.emission_energy_multiplier = 15.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.8
	beam.material_override = mat
	add_child(beam)
	
	# Outer Beam Aura
	var beam_aura = MeshInstance3D.new()
	var cyl_aura = CylinderMesh.new()
	cyl_aura.top_radius = 0.15
	cyl_aura.bottom_radius = 0.15
	cyl_aura.height = distance
	cyl_aura.radial_segments = 8
	beam_aura.mesh = cyl_aura
	beam_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam_aura.position.z = - distance / 2.0
	beam_aura.rotation.x = PI / 2.0
	var mat_aura = StandardMaterial3D.new()
	mat_aura.albedo_color = Color(1.0, 0.2, 0.2, 0.3)
	mat_aura.emission_enabled = true
	mat_aura.emission = Color(1.0, 0.1, 0.1)
	mat_aura.emission_energy_multiplier = 4.0
	mat_aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_aura.material_override = mat_aura
	add_child(beam_aura)
	
	# Particle Mesh
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.015
	p_mesh.height = 0.03
	p_mesh.radial_segments = 8
	p_mesh.rings = 4
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.5))
	curve.add_point(Vector2(1, 0.0))
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1), Color(1.0, 0.2, 0.2), Color(1.0, 0.0, 0.0, 0.0)])
	
	var p_mat = StandardMaterial3D.new()
	p_mat.vertex_color_use_as_albedo = true
	p_mat.albedo_color = Color(1, 1, 1)
	p_mat.emission_enabled = true
	p_mat.emission = Color(1.0, 0.2, 0.2)
	p_mat.emission_energy_multiplier = 10.0
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Muzzle Flash
	var muzzle = CPUParticles3D.new()
	muzzle.amount = 150
	muzzle.lifetime = 0.3
	muzzle.explosiveness = 1.0
	muzzle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	muzzle.emission_sphere_radius = 0.1
	muzzle.spread = 180.0
	muzzle.initial_velocity_min = 4.0
	muzzle.initial_velocity_max = 8.0
	muzzle.damping_min = 15.0
	muzzle.damping_max = 20.0
	muzzle.scale_amount_curve = curve
	muzzle.color_ramp = grad
	muzzle.mesh = p_mesh
	muzzle.material_override = p_mat
	add_child(muzzle)
	muzzle.emitting = true
	
	# Impact Light
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.2, 0.2)
	light.light_energy = 8.0
	light.omni_range = 5.0
	light.position.z = - distance
	add_child(light)
	
	# Impact Sparkles
	var sparkles = CPUParticles3D.new()
	sparkles.amount = 250
	sparkles.lifetime = 0.5
	sparkles.explosiveness = 1.0
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 0.2
	sparkles.spread = 180.0
	sparkles.initial_velocity_min = 5.0
	sparkles.initial_velocity_max = 12.0
	sparkles.damping_min = 10.0
	sparkles.damping_max = 15.0
	sparkles.scale_amount_curve = curve
	sparkles.color_ramp = grad
	sparkles.mesh = p_mesh
	sparkles.material_override = p_mat
	sparkles.position.z = - distance
	add_child(sparkles)
	sparkles.emitting = true
	
	# Animation
	var tween = create_tween().set_parallel(true)
	tween.tween_property(beam, "scale:x", 0.0, 0.15)
	tween.tween_property(beam, "scale:z", 0.0, 0.15)
	tween.tween_property(beam_aura, "scale:x", 0.0, 0.2)
	tween.tween_property(beam_aura, "scale:z", 0.0, 0.2)
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(queue_free)
