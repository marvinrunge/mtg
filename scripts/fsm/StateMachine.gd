extends Node
class_name StateMachine

var current_state: State
var states: Dictionary = {}
var parent: Node

func _ready() -> void:
	# Disable processing by default. It's better to manually tick from the parent
	# so we can control exactly when (e.g. only if authority)
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)

func init(_parent: Node, initial_state_name: String) -> void:
	parent = _parent
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_machine = self
			child.parent = parent
	
	if states.has(initial_state_name.to_lower()):
		change_state(initial_state_name.to_lower())

func update(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func handle_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func change_state(new_state_name: String) -> void:
	var state_name = new_state_name.to_lower()
	if not states.has(state_name):
		push_error("State not found: ", state_name)
		return
		
	if current_state:
		current_state.exit()
		
	current_state = states[state_name]
	current_state.enter()
