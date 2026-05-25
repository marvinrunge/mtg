extends SceneTree

func _init():
	var run_scene = load("res://meshes/characters/Goblin1/running.fbx")
	if run_scene:
		var r_root = run_scene.instantiate()
		var r_ap = r_root.get_node_or_null("AnimationPlayer")
		if r_ap and r_ap.has_animation("mixamo_com"):
			var anim = r_ap.get_animation("mixamo_com")
			for i in range(anim.get_track_count()):
				print("Track ", i, ": ", anim.track_get_path(i))
	quit()
