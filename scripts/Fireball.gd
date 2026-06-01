extends Area3D

var speed: float = 20.0
var damage: float = 40.0
var direction: Vector3 = Vector3.FORWARD
var multiplayer_id: int = 1
var has_exploded: bool = false
var charge_mult: float = 1.0

var inner_core: MeshInstance3D
var outer_core: MeshInstance3D
var heat_shimmer: MeshInstance3D
var light: OmniLight3D
var collision_shape: CollisionShape3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	
	_create_visuals()

func _create_visuals() -> void:
	collision_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.15
	collision_shape.shape = sphere
	add_child(collision_shape)
	
	# Inner Core
	inner_core = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	inner_core.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.4)
	mat.emission_energy_multiplier = 8.0
	inner_core.material_override = mat
	add_child(inner_core)
	
	# Outer Core
	outer_core = MeshInstance3D.new()
	var outer_mesh = SphereMesh.new()
	outer_mesh.radius = 0.55
	outer_mesh.height = 1.1
	outer_core.mesh = outer_mesh
	var outer_mat = StandardMaterial3D.new()
	outer_mat.albedo_color = Color(1.0, 0.4, 0.0, 0.5)
	outer_mat.emission_enabled = true
	outer_mat.emission = Color(1.0, 0.2, 0.0)
	outer_mat.emission_energy_multiplier = 3.0
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_core.material_override = outer_mat
	add_child(outer_core)
	
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.0)
	add_child(light)
	
	# Heat Shimmer Effect
	heat_shimmer = MeshInstance3D.new()
	var heat_mesh = SphereMesh.new()
	heat_mesh.radius = 0.65
	heat_mesh.height = 1.3
	var heat_mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	float edge = 1.0 - dot(NORMAL, VIEW);
	float mask = smoothstep(1.0, 0.0, edge);
	float wobble = sin(TIME * 8.0 + UV.y * 20.0) * cos(TIME * 5.0 + UV.x * 20.0);
	vec2 uv = SCREEN_UV + (wobble * 0.001 * mask);
	ALBEDO = texture(screen_texture, uv).rgb;
}
"""
	heat_mat.shader = shader
	heat_mesh.material = heat_mat
	heat_shimmer.mesh = heat_mesh
	heat_shimmer.sorting_offset = -10.0
	add_child(heat_shimmer)
	
	# Trail Particles
	var particles = CPUParticles3D.new()
	particles.amount = 60
	particles.lifetime = 0.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.4
	particles.gravity = Vector3(0, 1.5, 0)
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 1.5
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.5))
	curve.add_point(Vector2(1, 0.0))
	particles.scale_amount_curve = curve
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.1, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 0.8), Color(1, 0.5, 0), Color(0.8, 0.1, 0), Color(0.2, 0.2, 0.2, 0)])
	particles.color_ramp = grad
	
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.15
	p_mesh.height = 0.3
	p_mesh.radial_segments = 8
	p_mesh.rings = 4
	var p_mat = StandardMaterial3D.new()
	p_mat.vertex_color_use_as_albedo = true
	p_mat.albedo_color = Color(1.0, 1.0, 1.0)
	p_mat.emission_enabled = true
	p_mat.emission = Color(1.0, 0.5, 0.0)
	p_mat.emission_energy_multiplier = 2.0
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mesh.material = p_mat
	particles.mesh = p_mesh
	add_child(particles)
	
	_animate_spawn()

func _animate_spawn() -> void:
	collision_shape.scale = Vector3.ONE * min(charge_mult, 3.0)
	var start_scale = Vector3(0.01, 0.01, 0.01)
	inner_core.scale = start_scale
	outer_core.scale = start_scale
	heat_shimmer.scale = start_scale
	light.omni_range = 0.0
	light.light_energy = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(inner_core, "scale", Vector3.ONE * charge_mult, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(outer_core, "scale", Vector3.ONE * charge_mult, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(heat_shimmer, "scale", Vector3.ONE * charge_mult, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(light, "omni_range", 10.0 * charge_mult, 0.2)
	tween.tween_property(light, "light_energy", 5.0 * charge_mult, 0.2)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if has_exploded: return
	has_exploded = true
	
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	
	# 1. Shrink Phase
	var mesh = get_node_or_null("MeshInstance3D")
	var meshes = []
	for child in get_children():
		if child is MeshInstance3D:
			meshes.append(child)
			
	var light = get_node_or_null("OmniLight3D")
	var trail = get_node_or_null("CPUParticles3D")
	
	if trail: trail.emitting = false
	
	var shrink_tween = create_tween().set_parallel(true)
	for m in meshes:
		shrink_tween.tween_property(m, "scale", Vector3(0.01, 0.01, 0.01), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if light: shrink_tween.tween_property(light, "omni_range", 1.0, 0.2)
	
	await shrink_tween.finished
	
	for m in meshes:
		m.visible = false
	
	# Calculate dynamic explosion radius based on damage (10 -> 2m, 100 -> 8m)
	var explosion_radius = 2.0 + clamp((damage - 10.0) / 90.0, 0.0, 1.0) * 6.0
	
	# 2. Damage Phase
	if multiplayer.is_server():
		var space_state = get_world_3d().direct_space_state
		var shape = SphereShape3D.new()
		shape.radius = explosion_radius
		var params = PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = global_transform
		params.collision_mask = 5 # World + Enemies
		
		var hits = space_state.intersect_shape(params)
		var hit_bodies = {}
		for hit in hits:
			var hit_body = hit.collider
			if hit_body and not hit_bodies.has(hit_body):
				hit_bodies[hit_body] = true
				if hit_body.has_method("take_damage"):
					var dist = global_position.distance_to(hit_body.global_position)
					var distance_factor = 1.0
					if dist > 1.5:
						distance_factor = clamp(1.0 - ((dist - 1.5) / max(0.1, explosion_radius - 1.5)), 0.1, 1.0)
					var damage_dealt = damage * distance_factor
					
					var dir = (hit_body.global_position - global_position).normalized()
					if dir == Vector3.ZERO: dir = Vector3.UP
					hit_body.take_damage(damage_dealt, dir)
					
					if hit_body.has_method("gain_aggro"):
						var owner_player = get_tree().root.get_node_or_null("Main/PlayersContainer/" + str(multiplayer_id))
						if owner_player:
							hit_body.gain_aggro(owner_player)
	
	# 3. Explosion Phase
	var shockwave = MeshInstance3D.new()
	var sw_mesh = SphereMesh.new()
	sw_mesh.radius = 0.5
	sw_mesh.height = 1.0
	shockwave.mesh = sw_mesh
	var sw_mat = StandardMaterial3D.new()
	sw_mat.albedo_color = Color(1.0, 0.6, 0.0, 0.8)
	sw_mat.emission_enabled = true
	sw_mat.emission = Color(1.0, 0.4, 0.0)
	sw_mat.emission_energy_multiplier = 4.0
	sw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shockwave.material_override = sw_mat
	add_child(shockwave)
	
	var exp_particles = CPUParticles3D.new()
	exp_particles.amount = int(40 + (explosion_radius * 10))
	exp_particles.lifetime = 0.6
	exp_particles.one_shot = true
	exp_particles.explosiveness = 0.95
	exp_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	exp_particles.emission_sphere_radius = explosion_radius * 0.25
	exp_particles.spread = 180.0
	exp_particles.initial_velocity_min = explosion_radius * 4.0
	exp_particles.initial_velocity_max = explosion_radius * 7.0
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
	
	var exp_sound = "res://sounds/fireball-exploding-small.wav"
	if damage >= 75.0:
		exp_sound = "res://sounds/fireball-exploding-big.wav"
	elif damage >= 40.0:
		exp_sound = "res://sounds/fireball-exploding-middle.wav"
		
	var audio = AudioStreamPlayer3D.new()
	audio.stream = load(exp_sound)
	audio.bus = "SFX"
	audio.max_distance = explosion_radius * 10.0
	
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		main.add_child(audio)
		audio.global_position = global_position
	else:
		add_child(audio)
		
	audio.play()
	audio.finished.connect(audio.queue_free)
	
	var target_scale = explosion_radius * 4.0
	var exp_tween = create_tween().set_parallel(true)
	
	if light:
		light.visible = true
		light.light_energy = 15.0
		light.omni_range = explosion_radius * 2.5
		exp_tween.tween_property(light, "light_energy", 0.0, 0.5)
		
	exp_tween.tween_property(shockwave, "scale", Vector3(target_scale, target_scale, target_scale), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	exp_tween.tween_property(sw_mat, "albedo_color:a", 0.0, 1.0)
	exp_tween.tween_property(sw_mat, "emission_energy_multiplier", 0.0, 1.0)
	
	await get_tree().create_timer(1.0).timeout
	queue_free()
