extends Label3D

var velocity = Vector3(0, 2.0, 0)
var gravity = 3.0
var lifetime = 1.0
var current_time = 0.0

func _ready():
	# Randomize initial horizontal velocity slightly
	velocity.x = randf_range(-1.0, 1.0)
	velocity.z = randf_range(-1.0, 1.0)
	
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pixel_size = 0.01
	font_size = 64
	outline_size = 12
	outline_render_priority = 0
	render_priority = 10
	no_depth_test = true

func _process(delta):
	current_time += delta
	if current_time >= lifetime:
		queue_free()
		return
		
	velocity.y -= gravity * delta
	position += velocity * delta
	
	# Fade out
	var alpha = 1.0 - (current_time / lifetime)
	modulate.a = alpha
