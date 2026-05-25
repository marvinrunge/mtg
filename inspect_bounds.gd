extends SceneTree

func _init():
	var scene = load("res://meshes/Forest/Meshy_AI_Eine_große_schwebend_0519230353_texture.fbx")
	if scene:
		var ground = scene.instantiate()
		ground.scale = Vector3(5000, 5000, 5000)
		# We must add it to the root to calculate global transform
		root.add_child(ground)
		
		var max_y = -9999999.0
		var min_y = 9999999.0
		
		# A recursive function to find meshes
		var nodes = [ground]
		while nodes.size() > 0:
			var node = nodes.pop_back()
			if node is MeshInstance3D and node.mesh:
				var aabb = node.get_aabb()
				var global_trans = node.global_transform
				
				# Check all 8 corners of the AABB
				for i in range(8):
					var corner = aabb.get_endpoint(i)
					var global_corner = global_trans * corner
					if global_corner.y > max_y: max_y = global_corner.y
					if global_corner.y < min_y: min_y = global_corner.y
			nodes.append_array(node.get_children())
			
		print("Global Min Y: ", min_y)
		print("Global Max Y: ", max_y)
	quit()
