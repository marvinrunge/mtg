extends SceneTree

func _init():
	var scene = load("res://meshes/characters/Goblin1/Meshy_AI_Rope_Bound_Goblin_0523095536_texture.fbx")
	if scene:
		var ground = scene.instantiate()
		root.add_child(ground)
		
		var max_y = -9999999.0
		var min_y = 9999999.0
		
		var nodes = [ground]
		while nodes.size() > 0:
			var node = nodes.pop_back()
			if node is MeshInstance3D and node.mesh:
				var aabb = node.get_aabb()
				var global_trans = node.global_transform
				for i in range(8):
					var corner = aabb.get_endpoint(i)
					var global_corner = global_trans * corner
					if global_corner.y > max_y: max_y = global_corner.y
					if global_corner.y < min_y: min_y = global_corner.y
			nodes.append_array(node.get_children())
			
		print("Goblin Global Min Y: ", min_y)
		print("Goblin Global Max Y: ", max_y)
	else:
		print("Could not load scene")
	quit()
