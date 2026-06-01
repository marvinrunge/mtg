extends MeshInstance3D

func _ready():
	top_level = true
	cast_shadow = 0
	
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.06
	sphere_mesh.height = 0.12
	var sphere_mat = StandardMaterial3D.new()
	sphere_mat.albedo_color = Color(1.0, 1.0, 1.0)
	sphere_mat.emission_enabled = true
	sphere_mat.emission = Color(1.0, 1.0, 1.0)
	sphere_mat.emission_energy_multiplier = 5.0
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mesh.material = sphere_mat
	mesh = sphere_mesh
	
	var particles = CPUParticles3D.new()
	particles.name = "CPUParticles3D"
	particles.cast_shadow = 0
	particles.amount = 120
	particles.lifetime = 0.8
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.08
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 0.05
	particles.initial_velocity_max = 0.2
	particles.gravity = Vector3(0, 0.05, 0)
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 1.8
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.002
	p_mesh.height = 0.004
	var p_mat = StandardMaterial3D.new()
	p_mat.vertex_color_use_as_albedo = true
	p_mat.emission_enabled = true
	p_mat.emission = Color(1.0, 1.0, 1.0)
	p_mat.emission_energy_multiplier = 3.0
	p_mesh.material = p_mat
	particles.mesh = p_mesh
	add_child(particles)
	
	var light = OmniLight3D.new()
	light.name = "OmniLight3D"
	light.omni_range = 1.0
	light.light_energy = 1.0
	add_child(light)
	
	var heat_distortion = MeshInstance3D.new()
	heat_distortion.name = "HeatDistortion"
	heat_distortion.cast_shadow = 0
	var heat_mesh = SphereMesh.new()
	heat_mesh.radius = 0.12 # Larger than the base sphere
	heat_mesh.height = 0.24
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
	heat_distortion.mesh = heat_mesh
	heat_distortion.sorting_offset = -10.0
	add_child(heat_distortion)
