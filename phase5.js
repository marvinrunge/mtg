const fs = require('fs');

function addVoidReturn(content) {
    return content.replace(/func ([a-zA-Z0-9_]+)\((.*?)\)(?! \->):/g, 'func $1($2) -> void:');
}

function processEnemy() {
    let content = fs.readFileSync('scripts/Enemy.gd', 'utf8');
    
    // Node Ref (AnimationPlayer is hardcoded in Enemy.gd as $Visuals/Goblin/AnimationPlayer)
    content = content.replace(/@onready var animation_player = \$Visuals\/Goblin\/AnimationPlayer/g, '@onready var animation_player: AnimationPlayer = %AnimationPlayer');
    
    // Types
    content = content.replace(/func take_damage\(amount, knockback_dir: Vector3 = Vector3\.ZERO\)/g, 'func take_damage(amount: float, knockback_dir: Vector3 = Vector3.ZERO)');
    content = content.replace(/func _physics_process\(delta\)/g, 'func _physics_process(delta: float)');
    content = content.replace(/func sync_stats\(type: String, max_hp: float, dmg: float, spd: float, scale_factor: float = 1\.0\)/g, 'func sync_stats(type: String, max_hp: float, dmg: float, spd: float, scale_factor: float = 1.0) -> void');
    content = content.replace(/func init_stats\(multiplier: float, type: String = "goblin"\)/g, 'func init_stats(multiplier: float, type: String = "goblin") -> void');
    content = content.replace(/func hit_reaction\(amount: float, current_health: float = -1\)/g, 'func hit_reaction(amount: float, current_health: float = -1.0) -> void');
    
    content = addVoidReturn(content);
    
    fs.writeFileSync('scripts/Enemy.gd', content);
    console.log("Enemy.gd typed");
}

function processEnemyTscn() {
    let content = fs.readFileSync('scenes/Enemy.tscn', 'utf8');
    content = content.replace(/\[node name="AnimationPlayer" type="AnimationPlayer" parent="([^"]+)"\]/g, '[node name="AnimationPlayer" type="AnimationPlayer" parent="$1" unique_name_in_owner=true]');
    fs.writeFileSync('scenes/Enemy.tscn', content);
    console.log("Enemy.tscn updated with unique_name_in_owner");
}

function processPlayer() {
    let content = fs.readFileSync('scripts/PlayerController.gd', 'utf8');
    
    // Node Refs: Player dynamically loads its visuals, so we can't use % for them easily unless we modify the instantiated scene.
    // But we can type them!
    content = content.replace(/var current_model: Node3D/g, '@onready var current_model: Node3D'); // If it wasn't typed
    
    content = content.replace(/func _physics_process\(delta\)/g, 'func _physics_process(delta: float)');
    content = content.replace(/func _sync_remote_animations\(delta\)/g, 'func _sync_remote_animations(delta: float)');
    content = content.replace(/func take_damage\(amount: float, knockback_dir: Vector3 = Vector3\.ZERO\)/g, 'func take_damage(amount: float, knockback_dir: Vector3 = Vector3.ZERO) -> void');
    
    content = addVoidReturn(content);
    
    fs.writeFileSync('scripts/PlayerController.gd', content);
    console.log("PlayerController.gd typed");
}

function processPlayerCaster() {
    let content = fs.readFileSync('scripts/PlayerCaster.gd', 'utf8');
    content = content.replace(/func scroll_spell\(dir: int\)/g, 'func scroll_spell(dir: int) -> void');
    content = content.replace(/func try_start_cast\(\)/g, 'func try_start_cast() -> void');
    content = addVoidReturn(content);
    fs.writeFileSync('scripts/PlayerCaster.gd', content);
    console.log("PlayerCaster.gd typed");
}

function processFSM() {
    const states = ['PlayerIdleState.gd', 'PlayerWalkState.gd', 'PlayerRunState.gd', 'PlayerJumpState.gd', 'PlayerAttackState.gd', 'PlayerCastState.gd'];
    for (let state of states) {
        let path = 'scripts/fsm/' + state;
        if (fs.existsSync(path)) {
            let content = fs.readFileSync(path, 'utf8');
            content = addVoidReturn(content);
            fs.writeFileSync(path, content);
            console.log(state + " typed");
        }
    }
}

processEnemyTscn();
processEnemy();
processPlayer();
processPlayerCaster();
processFSM();
