const fs = require('fs');

function processPlayerController() {
    let content = fs.readFileSync('scripts/PlayerController.gd', 'utf8');

    // 1. Add variables
    if (!content.includes('var anim_tree: AnimationTree')) {
        content = content.replace('var current_anim_player: AnimationPlayer = null', 'var current_anim_player: AnimationPlayer = null\nvar anim_tree: AnimationTree = null\nvar anim_state: AnimationNodeStateMachinePlayback = null\nvar root_motion_track_path: NodePath\n');
    }

    // 2. Remove stripping, add root motion track path extraction
    const stripOld = `						# Process root motion securely and dynamically extract walk/run speeds
						for i in range(anim.get_track_count()):
							if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
								var track_path = String(anim.track_get_path(i))
								# Only alter the main root/hips bone, leaving other bones (like hands/IK) completely intact
								if not (track_path.contains("mixamorig_Hips") or track_path.contains("Root")):
									continue
									
								var base_y = null
								var base_x = null
								var base_z = null
								var first_val = null
								var last_val = null
								if anim.track_get_key_count(i) > 0:
									first_val = anim.track_get_key_value(i, 0)
									last_val = anim.track_get_key_value(i, anim.track_get_key_count(i) - 1)
									if first_val is Vector3:
										base_y = first_val.y
										base_x = first_val.x
										base_z = first_val.z
								
								# Dynamically extract intended movement speed from the forward animations
								if a_name == "walk_forward" and first_val is Vector3 and last_val is Vector3:
									var dist = Vector2(first_val.x, first_val.z).distance_to(Vector2(last_val.x, last_val.z))
									if dist > 0.1 and anim.length > 0: speed = (dist / anim.length) * 1.25
								elif a_name == "run_forward" and first_val is Vector3 and last_val is Vector3:
									var dist = Vector2(first_val.x, first_val.z).distance_to(Vector2(last_val.x, last_val.z))
									if dist > 0.1 and anim.length > 0: run_speed = (dist / anim.length) * 1.25
								
								# Stop sinking (Y) ONLY on attacks, but remove horizontal drift (X, Z) for ALL animations
								var lock_y = a_name.begins_with("attack")
								for key_idx in range(anim.track_get_key_count(i)):
									var val = anim.track_get_key_value(i, key_idx)
									if val is Vector3:
										if base_x != null: val.x = base_x
										if base_z != null: val.z = base_z
										if lock_y and base_y != null: val.y = base_y
										anim.track_set_key_value(i, key_idx, val)`;
										
    const stripNew = `						# Process root motion securely and dynamically extract walk/run speeds
						for i in range(anim.get_track_count()):
							if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
								var track_path = String(anim.track_get_path(i))
								if track_path.contains("mixamorig_Hips") or track_path.contains("Root"):
									root_motion_track_path = NodePath(track_path)
									
								var base_y = null
								var base_x = null
								var base_z = null
								var first_val = null
								var last_val = null
								if anim.track_get_key_count(i) > 0:
									first_val = anim.track_get_key_value(i, 0)
									last_val = anim.track_get_key_value(i, anim.track_get_key_count(i) - 1)
									if first_val is Vector3:
										base_y = first_val.y
										base_x = first_val.x
										base_z = first_val.z
								
								if a_name == "walk_forward" and first_val is Vector3 and last_val is Vector3:
									var dist = Vector2(first_val.x, first_val.z).distance_to(Vector2(last_val.x, last_val.z))
									if dist > 0.1 and anim.length > 0: speed = (dist / anim.length) * 1.25
								elif a_name == "run_forward" and first_val is Vector3 and last_val is Vector3:
									var dist = Vector2(first_val.x, first_val.z).distance_to(Vector2(last_val.x, last_val.z))
									if dist > 0.1 and anim.length > 0: run_speed = (dist / anim.length) * 1.25`;
    content = content.replace(stripOld, stripNew);

    // 3. Build AnimationTree
    const treeOld = `	if current_anim_player.has_animation_library("actions"):
		current_anim_player.remove_animation_library("actions")
	current_anim_player.add_animation_library("actions", lib)`;
    const treeNew = `	if current_anim_player.has_animation_library("actions"):
		current_anim_player.remove_animation_library("actions")
	current_anim_player.add_animation_library("actions", lib)
	
	if is_instance_valid(anim_tree):
		anim_tree.queue_free()
		
	anim_tree = AnimationTree.new()
	anim_tree.anim_player = current_anim_player.get_path()
	var state_machine = AnimationNodeStateMachine.new()
	
	for a_name in anim_names:
		var node = AnimationNodeAnimation.new()
		node.animation = "actions/" + a_name
		state_machine.add_node(a_name, node)
		for t_name in anim_names:
			if a_name != t_name:
				var trans = AnimationNodeStateMachineTransition.new()
				trans.xfade_time = 0.15
				state_machine.add_transition(a_name, t_name, trans)
		
	anim_tree.tree_root = state_machine
	if not root_motion_track_path.is_empty():
		anim_tree.root_motion_track = root_motion_track_path
	anim_tree.active = true
	current_model.add_child(anim_tree)
	anim_state = anim_tree.get("parameters/playback")
	
	if is_instance_valid(anim_state): anim_state.start("idle1")`;
    if (!content.includes('anim_tree = AnimationTree.new()')) {
        content = content.replace(treeOld, treeNew);
    }

    // 4. Update play_anim
    const playAnimOld = `func play_anim(anim_name: String):
	if not current_anim_player or not current_anim_player.has_animation("actions/" + anim_name):
		return
		
	# Do not allow any other animations to interrupt while in the air
	if is_multiplayer_authority() and not is_on_floor() and anim_name != "jump":
		return
		
	var protected_anims = ["attack", "attack1", "attack2", "attack3", "pickup", "cast_fireball", "cast_zap", "cast_unsummon", "cast_drain_life", "cast_giant_growth", "cast_heal", "standing 1h magic attack 02"]
	
	if current_animation in protected_anims and anim_name not in protected_anims:
		if current_anim_player.is_playing() and current_anim_player.current_animation == "actions/" + current_animation:
			return
			
	var should_play = (current_animation != anim_name) or (not current_anim_player.is_playing() and anim_name != "jump")
	
	if should_play:
		current_anim_player.play("actions/" + anim_name, 0.15)
		current_animation = anim_name`;
    const playAnimNew = `func play_anim(anim_name: String):
	if not current_anim_player or not current_anim_player.has_animation("actions/" + anim_name):
		return
		
	if is_multiplayer_authority() and not is_on_floor() and anim_name != "jump":
		return
		
	var protected_anims = ["attack", "attack1", "attack2", "attack3", "pickup", "cast_fireball", "cast_zap", "cast_unsummon", "cast_drain_life", "cast_giant_growth", "cast_heal", "standing 1h magic attack 02"]
	
	if current_animation in protected_anims and anim_name not in protected_anims:
		if is_instance_valid(anim_state) and anim_state.get_current_node() == current_animation:
			return
			
	var should_play = (current_animation != anim_name) or (not is_instance_valid(anim_state) or anim_state.get_current_node() != anim_name and anim_name != "jump")
	
	if should_play:
		if is_instance_valid(anim_state):
			anim_state.travel(anim_name)
		current_animation = anim_name`;
    content = content.replace(playAnimOld, playAnimNew);

    // 5. Update _physics_process velocity
    const physVelOld = `	var is_acting = (current_animation.begins_with("attack") or current_animation == "pickup" or current_animation.begins_with("cast_") or current_animation.begins_with("standing")) and current_anim_player and current_anim_player.is_playing() and current_anim_player.current_animation == "actions/" + current_animation
	
	if is_acting:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	elif direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed`;
    const physVelNew = `	var is_acting = (current_animation.begins_with("attack") or current_animation == "pickup" or current_animation.begins_with("cast_") or current_animation.begins_with("standing")) and is_instance_valid(anim_state) and anim_state.get_current_node() == current_animation
	
	if is_acting:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	elif direction != Vector3.ZERO:
		if is_instance_valid(anim_tree):
			var root_pos = anim_tree.get_root_motion_position()
			var global_root = transform.basis * root_pos
			velocity.x = (global_root.x / delta)
			velocity.z = (global_root.z / delta)
			if current_anim_player: current_anim_player.speed_scale = current_speed / speed
		else:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed`;
    content = content.replace(physVelOld, physVelNew);

    fs.writeFileSync('scripts/PlayerController.gd', content);
    console.log("PlayerController.gd processed securely");
}

function processEnemy() {
    let content = fs.readFileSync('scripts/Enemy.gd', 'utf8');

    if (!content.includes('var anim_tree: AnimationTree')) {
        content = content.replace('@onready var animation_player = $Visuals/Goblin/AnimationPlayer', '@onready var animation_player = $Visuals/Goblin/AnimationPlayer\nvar anim_tree: AnimationTree\nvar anim_state: AnimationNodeStateMachinePlayback\nvar root_motion_track_path: NodePath\n');
    }

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
			root_motion_track_path = NodePath(path)`;
    content = content.replace(mkAnimOld, mkAnimNew);

    const treeOld = `		a_root.queue_free()

func _make_animation_stationary`;
    const treeNew = `		a_root.queue_free()
		
	if animation_player:
		if is_instance_valid(anim_tree):
			anim_tree.queue_free()
		anim_tree = AnimationTree.new()
		anim_tree.anim_player = animation_player.get_path()
		var state_machine = AnimationNodeStateMachine.new()
		
		for a_name in ["idle", "running", "death", "attack"]:
			var node = AnimationNodeAnimation.new()
			node.animation = "enemy_actions/" + a_name
			state_machine.add_node(a_name, node)
			for t_name in ["idle", "running", "death", "attack"]:
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
    if (!content.includes('anim_tree = AnimationTree.new()')) {
        content = content.replace(treeOld, treeNew);
    }

    const idlePlayOld = `		if animation_player and animation_player.current_animation != "attack" and animation_player.has_animation("idle"):
			if animation_player.current_animation != "idle":
				animation_player.play("idle")`;
    const idlePlayNew = `		if animation_player and (anim_state.get_current_node() if is_instance_valid(anim_state) else "") != "attack" and animation_player.has_animation("idle"):
			if (anim_state.get_current_node() if is_instance_valid(anim_state) else "") != "idle":
				if is_instance_valid(anim_state): anim_state.travel("idle")`;
    content = content.replace(idlePlayOld, idlePlayNew);

    const playMoveOld = `	if animation_player and animation_player.current_animation != "attack":
		_play_move_anim()`;
    const playMoveNew = `	if animation_player and (anim_state.get_current_node() if is_instance_valid(anim_state) else "") != "attack":
		_play_move_anim()`;
    content = content.replace(playMoveOld, playMoveNew);

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
    content = content.replace(physVelEnemyOld, physVelEnemyNew);

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
    content = content.replace(playMoveAnimOld, playMoveAnimNew);

    const performAttackOld = `	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack", -1, 1.5)`;
    const performAttackNew = `	if is_instance_valid(anim_state):
		if animation_player: animation_player.speed_scale = 1.5
		anim_state.travel("attack")`;
    content = content.replace(performAttackOld, performAttackNew);
    
    const applyStunOld = `	if animation_player:
		animation_player.play("idle")`;
    const applyStunNew = `	if is_instance_valid(anim_state):
		anim_state.travel("idle")`;
    content = content.replace(applyStunOld, applyStunNew);

    const playDeathOld = `func play_death_anim():
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")`;
    const playDeathNew = `func play_death_anim():
	if is_instance_valid(anim_state):
		anim_state.travel("death")`;
    content = content.replace(playDeathOld, playDeathNew);

    fs.writeFileSync('scripts/Enemy.gd', content);
    console.log("Enemy.gd processed securely");
}

processPlayerController();
processEnemy();
