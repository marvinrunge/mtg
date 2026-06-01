const fs = require('fs');

function fixPlayer() {
    let content = fs.readFileSync('scripts/PlayerController.gd', 'utf8');

    const actingOld1 = `	var is_acting = (current_animation.begins_with("attack") or current_animation == "pickup" or current_animation.begins_with("cast_")) and current_anim_player and is_instance_valid(anim_state) and anim_state.get_current_node() == current_animation`;
    const actingNew = `	var is_acting = false
	var is_act_anim = current_animation.begins_with("attack") or current_animation == "pickup" or current_animation.begins_with("cast_") or current_animation.begins_with("standing")
	if is_act_anim and is_instance_valid(anim_state):
		if anim_state.get_current_node() == current_animation:
			if anim_state.get_current_play_position() < anim_state.get_current_length() - 0.1:
				is_acting = true
		else:
			is_acting = true`;
    content = content.replace(actingOld1, actingNew);

    const actingOld2 = `	var is_acting = (current_animation.begins_with("attack") or current_animation == "pickup" or current_animation.begins_with("cast_") or current_animation.begins_with("standing")) and current_anim_player and is_instance_valid(anim_state) and anim_state.get_current_node() == current_animation`;
    content = content.replace(actingOld2, actingNew);

    fs.writeFileSync('scripts/PlayerController.gd', content);
    console.log("Player is_acting fixed");
}

function fixEnemy() {
    let content = fs.readFileSync('scripts/Enemy.gd', 'utf8');
    
    // Add current_animation tracking
    if (!content.includes('var current_animation: String = ""')) {
        content = content.replace('var anim_state: AnimationNodeStateMachinePlayback', 'var anim_state: AnimationNodeStateMachinePlayback\nvar current_animation: String = ""');
    }

    const enemyIdlePlayOld = `		if animation_player and (anim_state.get_current_node() if is_instance_valid(anim_state) else "") != "attack" and animation_player.has_animation("idle"):
			if (anim_state.get_current_node() if is_instance_valid(anim_state) else "") != "idle":
				if is_instance_valid(anim_state): anim_state.travel("idle")`;
    const enemyIdlePlayNew = `		if animation_player and current_animation != "attack" and animation_player.has_animation("idle"):
			if current_animation != "idle":
				if is_instance_valid(anim_state): anim_state.travel("idle")
				current_animation = "idle"`;
    content = content.replace(enemyIdlePlayOld, enemyIdlePlayNew);

    const enemyMovePlayOld = `	if animation_player and (anim_state.get_current_node() if is_instance_valid(anim_state) else "") != "attack":
		_play_move_anim()`;
    const enemyMovePlayNew = `	var is_attacking = current_animation == "attack" and is_instance_valid(anim_state) and (anim_state.get_current_node() != "attack" or anim_state.get_current_play_position() < anim_state.get_current_length() - 0.1)
	if animation_player and not is_attacking:
		_play_move_anim()`;
    content = content.replace(enemyMovePlayOld, enemyMovePlayNew);

    const enemyPlayMoveAnimOld = `func _play_move_anim() -> void:
	if not is_instance_valid(anim_state): return
	anim_state.travel("running")`;
    const enemyPlayMoveAnimNew = `func _play_move_anim() -> void:
	if not is_instance_valid(anim_state): return
	if current_animation != "running":
		anim_state.travel("running")
		current_animation = "running"`;
    content = content.replace(enemyPlayMoveAnimOld, enemyPlayMoveAnimNew);

    const enemyPerformAttackOld = `	if is_instance_valid(anim_state):
		if animation_player: animation_player.speed_scale = 1.5
		anim_state.travel("attack")`;
    const enemyPerformAttackNew = `	if is_instance_valid(anim_state):
		if animation_player: animation_player.speed_scale = 1.5
		anim_state.travel("attack")
		current_animation = "attack"`;
    content = content.replace(enemyPerformAttackOld, enemyPerformAttackNew);

    const enemyApplyStunOld = `	if is_instance_valid(anim_state):
		anim_state.travel("idle")`;
    const enemyApplyStunNew = `	if is_instance_valid(anim_state):
		anim_state.travel("idle")
		current_animation = "idle"`;
    content = content.replace(enemyApplyStunOld, enemyApplyStunNew);

    const enemyPlayDeathOld = `func play_death_anim():
	if is_instance_valid(anim_state):
		anim_state.travel("death")`;
    const enemyPlayDeathNew = `func play_death_anim():
	if is_instance_valid(anim_state):
		anim_state.travel("death")
		current_animation = "death"`;
    content = content.replace(enemyPlayDeathOld, enemyPlayDeathNew);

    fs.writeFileSync('scripts/Enemy.gd', content);
    console.log("Enemy current_animation fixed");
}

fixPlayer();
fixEnemy();
