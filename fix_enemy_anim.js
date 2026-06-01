const fs = require('fs');

function processEnemy() {
    let content = fs.readFileSync('scripts/Enemy.gd', 'utf8');

    // Make animation stationary fix
    const mkAnimOld = `func _make_animation_stationary(anim: Animation):
	for i in range(anim.get_track_count()):
		var path = str(anim.track_get_path(i))
		# TYPE_POSITION_3D is 1 in Godot 4
		if "mixamorig_Hips" in path and anim.track_get_type(i) == 1:
			var start_val = anim.track_get_key_value(i, 0) if anim.track_get_key_count(i) > 0 else Vector3.ZERO
			for key_idx in range(anim.track_get_key_count(i)):
				var val = anim.track_get_key_value(i, key_idx)
				if val is Vector3:
					val.x = start_val.x
					val.z = start_val.z
					anim.track_set_key_value(i, key_idx, val)`;
    const mkAnimNew = `func _make_animation_stationary(anim: Animation):
	for i in range(anim.get_track_count()):
		var path = str(anim.track_get_path(i))
		if "mixamorig_Hips" in path and anim.track_get_type(i) == 1:
			root_motion_track_path = NodePath(path)
			if anim.track_get_key_count(i) > 0:
				var first_val = anim.track_get_key_value(i, 0)
				if first_val is Vector3:
					$Visuals.position.y = first_val.y`;
    if (content.includes(mkAnimOld)) {
        content = content.replace(mkAnimOld, mkAnimNew);
    } else {
        console.log("mkAnimOld not found!");
    }

    // Animation tree setup
    const treeOld = `		a_root.queue_free()

func _make_animation_stationary`;
    const treeNew = `		a_root.queue_free()
		
	if animation_player:
		if is_instance_valid(anim_tree):
			anim_tree.queue_free()
		anim_tree = AnimationTree.new()
		anim_tree.anim_player = animation_player.get_path()
		var state_machine = AnimationNodeStateMachine.new()
		
		for a_name in ["idle", "running", "death", "attack", "walking"]:
			var node = AnimationNodeAnimation.new()
			node.animation = "enemy_actions/" + a_name
			state_machine.add_node(a_name, node)
			for t_name in ["idle", "running", "death", "attack", "walking"]:
				if a_name != t_name:
					var trans = AnimationNodeStateMachineTransition.new()
					trans.xfade_time = 0.15
					state_machine.add_transition(a_name, t_name, trans)
			
		anim_tree.tree_root = state_machine
		if not root_motion_track_path.is_empty():
			anim_tree.root_motion_track = root_motion_track_path
		anim_tree.active = true
		add_child(anim_tree)
		anim_state = anim_tree.get("parameters/playback")
		if is_instance_valid(anim_state): anim_state.start("idle")

func _make_animation_stationary`;
    if (!content.includes('anim_tree = AnimationTree.new()') && content.includes(treeOld)) {
        content = content.replace(treeOld, treeNew);
    }

    // Other edits
    const idlePlayOld = `		if animation_player and animation_player.current_animation != "attack" and animation_player.has_animation("idle"):
			if animation_player.current_animation != "idle":
				animation_player.play("idle")`;
    const idlePlayNew = `		if animation_player and (anim_state.get_current_node() if is_instance_valid(anim_state) else "") != "attack" and animation_player.has_animation("idle"):
			if (anim_state.get_current_node() if is_instance_valid(anim_state) else "") != "idle":
				if is_instance_valid(anim_state): anim_state.travel("idle")`;
    if (content.includes(idlePlayOld)) content = content.replace(idlePlayOld, idlePlayNew);

    const playMoveOld = `	if animation_player and animation_player.current_animation != "attack":
		_play_move_anim()`;
    const playMoveNew = `	if animation_player and (anim_state.get_current_node() if is_instance_valid(anim_state) else "") != "attack":
		_play_move_anim()`;
    if (content.includes(playMoveOld)) content = content.replace(playMoveOld, playMoveNew);

    const physVelEnemyOld = `	velocity.x = dir.x * speed
	velocity.z = dir.z * speed`;
    const physVelEnemyNew = `	if is_instance_valid(anim_tree) and anim_state.get_current_node() == "running":
		var root_pos = anim_tree.get_root_motion_position()
		var global_root = transform.basis * root_pos
		velocity.x = (global_root.x / delta) * $Visuals.scale.x
		velocity.z = (global_root.z / delta) * $Visuals.scale.x
		if animation_player: animation_player.speed_scale = speed / 3.0
	else:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if animation_player: animation_player.speed_scale = 1.0`;
    if (content.includes(physVelEnemyOld)) content = content.replace(physVelEnemyOld, physVelEnemyNew);

    const playMoveAnimOld = `func _play_move_anim() -> void:
	if not animation_player: return
	if speed > 4.0 and animation_player.has_animation("running"):
		animation_player.play("running")
	elif animation_player.has_animation("walking"):
		animation_player.play("walking")
	elif animation_player.has_animation("running"):
		animation_player.play("running")`;
    const playMoveAnimNew = `func _play_move_anim() -> void:
	if not is_instance_valid(anim_state): return
	anim_state.travel("running")`;
    if (content.includes(playMoveAnimOld)) content = content.replace(playMoveAnimOld, playMoveAnimNew);

    const performAttackOld = `	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack", -1, 1.5)`;
    const performAttackNew = `	if is_instance_valid(anim_state):
		if animation_player: animation_player.speed_scale = 1.5
		anim_state.travel("attack")`;
    if (content.includes(performAttackOld)) content = content.replace(performAttackOld, performAttackNew);
    
    const applyStunOld = `	if animation_player:
		animation_player.play("idle")`;
    const applyStunNew = `	if is_instance_valid(anim_state):
		anim_state.travel("idle")`;
    if (content.includes(applyStunOld)) content = content.replace(applyStunOld, applyStunNew);

    const playDeathOld = `func play_death_anim():
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")`;
    const playDeathNew = `func play_death_anim():
	if is_instance_valid(anim_state):
		anim_state.travel("death")`;
    if (content.includes(playDeathOld)) content = content.replace(playDeathOld, playDeathNew);

    fs.writeFileSync('scripts/Enemy.gd', content);
    console.log("Enemy.gd processed completely");
}

processEnemy();
