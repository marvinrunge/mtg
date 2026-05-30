extends SceneTree
func _init():
	var scene = load("res://scenes/Main.tscn")
	if scene:
		print("SCENE LOADED SUCCESSFULLY")
	else:
		print("FAILED TO LOAD SCENE")
	quit()
