extends SceneTree

func _init():
	var scene = load("res://meshes/Forest/Meshy_AI_Eine_große_schwebend_0519230353_texture.fbx")
	if scene:
		var ground = scene.instantiate()
		print("Default Scale: ", ground.scale)
	quit()
