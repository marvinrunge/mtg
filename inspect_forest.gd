extends SceneTree

func _init():
	var scene = load("res://meshes/Forest/Meshy_AI_Eine_große_schwebend_0519230353_texture.fbx")
	if scene:
		print("Successfully loaded FBX!")
		var inst = scene.instantiate()
		print("Root Node: ", inst.name)
		for child in inst.get_children():
			print("Child: ", child.name, " Type: ", child.get_class())
			if child is MeshInstance3D:
				var aabb = child.get_aabb()
				print("AABB size: ", aabb.size)
	else:
		print("Failed to load FBX")
	quit()
