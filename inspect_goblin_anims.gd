extends SceneTree

func _init():
	var scene = load("res://meshes/characters/Goblin1/Meshy_AI_Rope_Bound_Goblin_0523095536_texture.fbx")
	if scene:
		var root_node = scene.instantiate()
		var anim_player = root_node.get_node_or_null("AnimationPlayer")
		if anim_player:
			print("Animations in base FBX:")
			for anim in anim_player.get_animation_list():
				print("- ", anim)
		else:
			print("No AnimationPlayer found in base FBX.")
			
		var run_scene = load("res://meshes/characters/Goblin1/running.fbx")
		if run_scene:
			var r_root = run_scene.instantiate()
			var r_anim_player = r_root.get_node_or_null("AnimationPlayer")
			if r_anim_player:
				print("Animations in running.fbx:")
				for anim in r_anim_player.get_animation_list():
					print("- ", anim)
	quit()
