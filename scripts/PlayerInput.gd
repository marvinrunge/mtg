extends Node
class_name PlayerInput

@onready var controller: CharacterBody3D = get_parent()

func _input(event):
	if not controller.is_multiplayer_authority(): return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	
	if event is InputEventMouseMotion:
		controller.rotate_y(-event.relative.x * controller.mouse_sensitivity)
		controller.spring_arm.rotate_x(-event.relative.y * controller.mouse_sensitivity)
		controller.spring_arm.rotation.x = clamp(controller.spring_arm.rotation.x, -PI/2, PI/4)

func _unhandled_input(event):
	if not controller.is_multiplayer_authority(): return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			controller.get_viewport().set_input_as_handled()
		elif event.pressed and controller.punch_cooldown <= 0:
			var is_acting = controller.has_method("is_acting") and controller.is_acting()
			if not is_acting:
				if is_instance_valid(controller.state_machine):
					controller.state_machine.change_state("attack")
			
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if is_instance_valid(controller.caster): controller.caster.scroll_spell(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if is_instance_valid(controller.caster): controller.caster.scroll_spell(-1)
			
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		var is_acting = controller.has_method("is_acting") and controller.is_acting()
		if event.pressed:
			if not is_acting and controller.is_on_floor():
				if is_instance_valid(controller.caster): controller.caster.try_start_cast()
		else:
			if is_instance_valid(controller.caster): controller.caster.try_release_cast()
