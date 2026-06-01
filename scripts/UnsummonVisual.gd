extends Node3D

func _ready():
	# 1. Wind Streaks
	var wind_streaks = CPUParticles3D.new()
	wind_streaks.amount = 60
	wind_streaks.lifetime = 0.4
	wind_streaks.explosiveness = 0.8
	wind_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	wind_streaks.emission_sphere_radius = 1.0
	wind_streaks.direction = Vector3(0, 0, -1)
	wind_streaks.spread = 15.0
	wind_streaks.initial_velocity_min = 25.0
	wind_streaks.initial_velocity_max = 35.0
	wind_streaks.particle_flag_align_y = true # Aligns the long mesh with velocity
	
	var streak_mesh = BoxMesh.new()
	streak_mesh.size = Vector3(0.05, 1.0, 0.05) # Stretched along Y axis
	
	var streak_mat = StandardMaterial3D.new()
	streak_mat.albedo_color = Color(0.8, 0.9, 1.0, 0.3)
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_mat.emission_enabled = true
	streak_mat.emission = Color(0.5, 0.8, 1.0)
	streak_mat.emission_energy_multiplier = 1.0
	streak_mesh.material = streak_mat
	wind_streaks.mesh = streak_mesh
	
	var streak_curve = Curve.new()
	streak_curve.add_point(Vector2(0, 0.2))
	streak_curve.add_point(Vector2(0.2, 1.0))
	streak_curve.add_point(Vector2(1, 0.0))
	wind_streaks.scale_amount_curve = streak_curve
	
	add_child(wind_streaks)
	wind_streaks.emitting = true
	
	# 2. Expanding Shockwave Ring
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 16
	ring.mesh = torus
	ring.rotation.x = PI / 2.0 # Face forward relative to container
	
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.8, 0.9, 1.0, 0.6)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.6, 0.9, 1.0)
	ring_mat.emission_energy_multiplier = 2.0
	ring.material_override = ring_mat
	add_child(ring)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(5.0, 5.0, 5.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD)
	
	# 3. Ground Dust Kick-up
	var dust = CPUParticles3D.new()
	dust.amount = 40
	dust.lifetime = 0.8
	dust.explosiveness = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.5, 0.1, 0.5)
	dust.position.y = -1.0 # Down near feet
	dust.direction = Vector3(0, 0, -1)
	dust.spread = 20.0
	dust.initial_velocity_min = 10.0
	dust.initial_velocity_max = 20.0
	dust.damping_min = 15.0
	dust.damping_max = 25.0
	
	var dust_mesh = SphereMesh.new()
	dust_mesh.radius = 0.3
	dust_mesh.height = 0.6
	dust_mesh.radial_segments = 8
	dust_mesh.rings = 4
	var dust_mat = StandardMaterial3D.new()
	dust_mat.albedo_color = Color(0.6, 0.5, 0.4, 0.4) # Dust color
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mesh.material = dust_mat
	dust.mesh = dust_mesh
	
	var dust_curve = Curve.new()
	dust_curve.add_point(Vector2(0, 0.5))
	dust_curve.add_point(Vector2(0.3, 1.0))
	dust_curve.add_point(Vector2(1, 0.0))
	dust.scale_amount_curve = dust_curve
	
	add_child(dust)
	dust.emitting = true
	
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(queue_free)
