extends Node3D
class_name IslandGenerator

@export_enum("Plains", "Island", "Swamp", "Mountain", "Forest") var mana_type: String = "Plains"
@export var radius: float = 50.0 # 100m diameter
@export var max_thickness: float = 20.0
@export var subdivisions: int = 40

func _ready():
	generate_island()

func generate_island():
	# 1. Create Top Mesh (Terrain)
	var top_mesh = generate_radial_mesh(true)
	var top_instance = MeshInstance3D.new()
	top_instance.mesh = top_mesh
	top_instance.name = "TopTerrain"
	add_child(top_instance)
	
	# Apply terrain material
	var top_material = get_terrain_material()
	top_instance.set_surface_override_material(0, top_material)
	
	# 2. Create Bottom Mesh (Rugged Rock)
	var bottom_mesh = generate_radial_mesh(false)
	var bottom_instance = MeshInstance3D.new()
	bottom_instance.mesh = bottom_mesh
	bottom_instance.name = "BottomRock"
	add_child(bottom_instance)
	
	# Apply rock material
	var bottom_material = get_rock_material()
	bottom_instance.set_surface_override_material(0, bottom_material)
	
	# 3. Create Collision Shape for players to walk on
	var static_body = StaticBody3D.new()
	static_body.name = "StaticBody"
	add_child(static_body)
	
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	# Create simplified collision representation or use the top mesh triangles
	var shape = top_mesh.create_trimesh_shape()
	collision_shape.shape = shape
	static_body.add_child(collision_shape)

func generate_radial_mesh(is_top: bool) -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var rings = subdivisions
	var radial_segments = subdivisions * 2
	
	# Configure heightmap noise generator
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.02
	if is_top:
		noise.seed = hash(mana_type)
	else:
		noise.seed = hash(mana_type) + 1234
	
	# Center vertex
	var center_y = 0.0
	if is_top:
		center_y = noise.get_noise_2d(0, 0) * 4.0
		# Apply mountain height offset at the center
		if mana_type == "Mountain":
			center_y += 18.0
	else:
		center_y = -max_thickness + noise.get_noise_2d(0, 0) * 4.0
	
	st.set_uv(Vector2(0.5, 0.5))
	st.set_normal(Vector3.UP if is_top else Vector3.DOWN)
	st.add_vertex(Vector3(0, center_y, 0))
	
	var ring_vertex_indices = []
	ring_vertex_indices.append([0])
	
	var vertex_counter = 1
	
	for r in range(1, rings + 1):
		var radius_pct = float(r) / rings
		var current_radius = radius_pct * radius
		var current_ring_indices = []
		
		for s in range(radial_segments):
			var angle = float(s) * 2.0 * PI / radial_segments
			var x = cos(angle) * current_radius
			var z = sin(angle) * current_radius
			
			var y = 0.0
			var n_val = noise.get_noise_2d(x, z)
			
			if is_top:
				# Taper to exact edge coordinate (y=0) using cosine curve
				var edge_falloff = cos(radius_pct * PI * 0.5)
				y = n_val * 4.0 * edge_falloff
				y += get_mana_terrain_mod(x, z, radius_pct)
			else:
				# Taper bottom to a central pointer rock tip
				var cone_taper = 1.0 - radius_pct
				var edge_falloff = cos(radius_pct * PI * 0.5)
				# Subtract absolute noise value so bottom rock is strictly negative and never clips up
				y = -max_thickness * cone_taper - abs(n_val) * 6.0 * edge_falloff
				# Align perfectly with the top edge
				if r == rings:
					y = 0.0
			
			var uv = Vector2(x / (radius * 2.0) + 0.5, z / (radius * 2.0) + 0.5)
			st.set_uv(uv)
			st.set_normal(Vector3.UP if is_top else Vector3.DOWN)
			st.add_vertex(Vector3(x, y, z))
			current_ring_indices.append(vertex_counter)
			vertex_counter += 1
			
		ring_vertex_indices.append(current_ring_indices)
		
	# Draw Center to Ring 1 triangles
	for s in range(radial_segments):
		var next_s = (s + 1) % radial_segments
		var v_center = 0
		var v1 = ring_vertex_indices[1][s]
		var v2 = ring_vertex_indices[1][next_s]
		
		if is_top:
			st.add_index(v_center)
			st.add_index(v1)
			st.add_index(v2)
		else:
			st.add_index(v_center)
			st.add_index(v2)
			st.add_index(v1)
			
	# Draw concentric ring transition faces
	for r in range(1, rings):
		for s in range(radial_segments):
			var next_s = (s + 1) % radial_segments
			
			var v1 = ring_vertex_indices[r][s]
			var v2 = ring_vertex_indices[r][next_s]
			var v3 = ring_vertex_indices[r+1][s]
			var v4 = ring_vertex_indices[r+1][next_s]
			
			if is_top:
				st.add_index(v1)
				st.add_index(v4)
				st.add_index(v2)
				
				st.add_index(v1)
				st.add_index(v3)
				st.add_index(v4)
			else:
				st.add_index(v1)
				st.add_index(v2)
				st.add_index(v4)
				
				st.add_index(v1)
				st.add_index(v4)
				st.add_index(v3)
				
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

func get_mana_terrain_mod(x: float, z: float, radius_pct: float) -> float:
	var edge_falloff = cos(radius_pct * PI * 0.5)
	match mana_type:
		"Mountain":
			# Volcanic core peak in the center
			var center_peak = 18.0 * exp(-pow(radius_pct / 0.4, 2.0))
			# Crater depression at the summit
			var crater = 4.0 * exp(-pow(radius_pct / 0.1, 2.0))
			return (center_peak - crater) * edge_falloff
		"Swamp":
			# Sunken bog center
			var bog_dip = -4.0 * (1.0 - radius_pct)
			return bog_dip * edge_falloff
		"Forest":
			# Heavy rolling terrain ridges
			var forest_ridges = sin(x * 0.15) * cos(z * 0.15) * 3.5
			return forest_ridges * edge_falloff
		"Island":
			# Sandy outer shelf ring, slightly depressed lagoon
			var reef = sin(radius_pct * PI * 1.8) * 2.0
			return reef * edge_falloff
		"Plains":
			# Flat plateau with tiny rolling meadows
			return sin(x * 0.05) * 0.8 * edge_falloff
	return 0.0

func get_terrain_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.9
	mat.metallic = 0.0
	
	# Set colors depending on mana type
	match mana_type:
		"Plains":
			mat.albedo_color = Color(0.85, 0.78, 0.48) # Golden plains grass
		"Island":
			mat.albedo_color = Color(0.3, 0.65, 0.8) # Sandy island turquoise
		"Swamp":
			mat.albedo_color = Color(0.12, 0.18, 0.14) # Dark mossy mud
		"Mountain":
			mat.albedo_color = Color(0.32, 0.24, 0.21) # Volcanic rust rock
		"Forest":
			mat.albedo_color = Color(0.1, 0.45, 0.15) # Lush green grass
			
	# Generate procedural noise bump normal map
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	
	var norm_tex = NoiseTexture2D.new()
	norm_tex.noise = noise
	norm_tex.as_normal_map = true
	norm_tex.bump_strength = 3.0
	
	mat.normal_enabled = true
	mat.normal_texture = norm_tex
	return mat

func get_rock_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.2) # Dark basalt
	mat.roughness = 0.8
	mat.metallic = 0.1
	
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	
	var norm_tex = NoiseTexture2D.new()
	norm_tex.noise = noise
	norm_tex.as_normal_map = true
	norm_tex.bump_strength = 6.0
	
	mat.normal_enabled = true
	mat.normal_texture = norm_tex
	return mat
