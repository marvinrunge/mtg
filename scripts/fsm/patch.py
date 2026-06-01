import re

with open('scripts/PlayerController.gd', 'r', encoding='utf8') as f:
    content = f.read()

# Hook up ready
ready_old = '\t_apply_player_details()'
ready_new = '''\t_apply_player_details()
	
	if not has_node("StateMachine"):
		state_machine = StateMachine.new()
		state_machine.name = "StateMachine"
		add_child(state_machine)
		
		var states = {
			"idle": preload("res://scripts/fsm/PlayerIdleState.gd").new(),
			"walk": preload("res://scripts/fsm/PlayerWalkState.gd").new(),
			"run": preload("res://scripts/fsm/PlayerRunState.gd").new(),
			"jump": preload("res://scripts/fsm/PlayerJumpState.gd").new(),
			"attack": preload("res://scripts/fsm/PlayerAttackState.gd").new(),
			"cast": preload("res://scripts/fsm/PlayerCastState.gd").new()
		}
		for s_name in states:
			states[s_name].name = s_name
			state_machine.add_child(states[s_name])
			
		state_machine.init(self, "idle")'''

content = content.replace(ready_old, ready_new)

if 'var state_machine: StateMachine' not in content:
    content = content.replace('var input: PlayerInput', 'var input: PlayerInput\nvar state_machine: StateMachine')

# Remove the old physics process chunk
physics_start = content.find('\tvar is_running = false')
physics_end = content.find('\tvar was_in_air = not is_on_floor()')

if physics_start != -1 and physics_end != -1:
    old_chunk = content[physics_start:physics_end]
    new_chunk = '\tif is_instance_valid(state_machine):\n\t\tstate_machine.physics_update(delta)\n\t\t\n'
    content = content.replace(old_chunk, new_chunk)
    print("Replaced physics process chunk.")
else:
    print("Could not find physics process chunk boundaries.")

# The process function handles input for jumping and attacking
process_old = '''func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_sync_remote_animations(delta)'''

process_new = '''func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_sync_remote_animations(delta)
	
	if is_instance_valid(state_machine):
		state_machine.update(delta)'''

if 'state_machine.update(delta)' not in content:
    content = content.replace(process_old, process_new)

with open('scripts/PlayerController.gd', 'w', encoding='utf8') as f:
    f.write(content)
print("Done")
