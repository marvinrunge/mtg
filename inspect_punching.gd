extends SceneTree

func _init():
	var scene = load("res://meshes/characters/CopperMyr/Punching.fbx")
	if scene:
		var inst = scene.instantiate()
		var player = inst.get_node_or_null("AnimationPlayer")
		if player:
			print("Animations in Punching.fbx:")
			for anim in player.get_animation_list():
				print(" - ", anim)
		else:
			print("No AnimationPlayer found in Punching.fbx")
	else:
		print("Failed to load Punching.fbx")
	quit()
