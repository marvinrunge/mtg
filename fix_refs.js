const fs = require('fs');

function setupEnemy() {
    let content = fs.readFileSync('scripts/Enemy.gd', 'utf8');

    const refOld = `@onready var animation_player: AnimationPlayer = %AnimationPlayer`;
    const refNew = `@export var animation_player: AnimationPlayer

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var res = _find_animation_player(child)
		if res: return res
	return null`;
    content = content.replace(refOld, refNew);
    
    const readyOld = `func _ready() -> void:
	var sync = MultiplayerSynchronizer.new()`;
    const readyNew = `func _ready() -> void:
	if not animation_player:
		animation_player = _find_animation_player(self)
		
	var sync = MultiplayerSynchronizer.new()`;
    content = content.replace(readyOld, readyNew);

    fs.writeFileSync('scripts/Enemy.gd', content);
    console.log("Enemy.gd references fixed");
}

function setupPlayer() {
    let content = fs.readFileSync('scripts/PlayerController.gd', 'utf8');
    
    // PlayerController dynamically loads the FBX and uses a_inst.get_node("AnimationPlayer")
    // Let's ensure current_anim_player is properly typed if it wasn't.
    // It's already typed because I did `@onready var current_anim_player: AnimationPlayer`
}

setupEnemy();
setupPlayer();
