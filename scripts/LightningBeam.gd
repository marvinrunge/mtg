extends MeshInstance3D
class_name LightningBeam

@export var segments: int = 15
@export var jaggedness: float = 0.5

var immediate_mesh: ImmediateMesh

func _ready() -> void:
	immediate_mesh = ImmediateMesh.new()
	mesh = immediate_mesh
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.6, 1.0)
	mat.emission_energy_multiplier = 8.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = mat

func draw_lightning(start_pos: Vector3, end_pos: Vector3) -> void:
	immediate_mesh.clear_surfaces()
	
	# Draw main beam and some sub-branches for a thicker look
	_draw_branch(start_pos, end_pos, jaggedness)
	_draw_branch(start_pos, end_pos, jaggedness * 0.5)

func _draw_branch(start_pos: Vector3, end_pos: Vector3, jitter: float) -> void:
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	var length: float = start_pos.distance_to(end_pos)
	var dir: Vector3 = (end_pos - start_pos).normalized()
	var step: float = length / float(segments)
	
	immediate_mesh.surface_add_vertex(to_local(start_pos))
	
	for i in range(1, segments):
		var base_pos: Vector3 = start_pos + dir * (step * i)
		var offset: Vector3 = Vector3(
			randf_range(-jitter, jitter),
			randf_range(-jitter, jitter),
			randf_range(-jitter, jitter)
		)
		
		# Smooth out the jitter at start and end points
		var fade: float = sin((float(i) / float(segments)) * PI)
		immediate_mesh.surface_add_vertex(to_local(base_pos + offset * fade))
		
	immediate_mesh.surface_add_vertex(to_local(end_pos))
	immediate_mesh.surface_end()
