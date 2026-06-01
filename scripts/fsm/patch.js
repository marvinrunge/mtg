const fs = require('fs');

let content = fs.readFileSync('scripts/PlayerController.gd', 'utf8');

const readyOld = '\t_apply_player_details()';
const readyNew = `\t_apply_player_details()
	
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
			
		state_machine.init(self, "idle")`;

content = content.replace(readyOld, readyNew);

if (!content.includes('var state_machine: StateMachine')) {
    content = content.replace('var input: PlayerInput', 'var input: PlayerInput\nvar state_machine: StateMachine');
}

const physicsStart = content.indexOf('\tvar is_running = false');
const physicsEnd = content.indexOf('\tvar was_in_air = not is_on_floor()');

if (physicsStart !== -1 && physicsEnd !== -1) {
    const oldChunk = content.slice(physicsStart, physicsEnd);
    const newChunk = '\tif is_instance_valid(state_machine):\n\t\tstate_machine.physics_update(delta)\n\t\t\n';
    content = content.replace(oldChunk, newChunk);
    console.log("Replaced physics process chunk.");
} else {
    console.log("Could not find physics process chunk boundaries.");
}

const processOld = `func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_sync_remote_animations(delta)`;

const processNew = `func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_sync_remote_animations(delta)
	
	if is_instance_valid(state_machine):
		state_machine.update(delta)`;

if (!content.includes('state_machine.update(delta)')) {
    content = content.replace(processOld, processNew);
}

fs.writeFileSync('scripts/PlayerController.gd', content, 'utf8');
console.log("Done");
