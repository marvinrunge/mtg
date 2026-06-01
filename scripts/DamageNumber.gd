extends Label3D

@export var popup_height: float = 2.0
@export var lifetime: float = 1.0
@export var random_spread: float = 1.0

func _ready() -> void:
	# Defer the tween so the spawner has time to set our global_position first!
	call_deferred("_start_tween")

func _start_tween() -> void:
	# Randomize initial horizontal drift
	var random_offset = Vector3(
		randf_range(-random_spread, random_spread), 
		0, 
		randf_range(-random_spread, random_spread)
	)
	var target_pos = position + random_offset + Vector3(0, popup_height, 0)
	
	var tween = create_tween().set_parallel(true)
	# Float up and drift
	tween.tween_property(self, "position", target_pos, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, lifetime).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(queue_free)
