const fs = require('fs');

function revertRootMotionPlayer() {
    let content = fs.readFileSync('scripts/PlayerController.gd', 'utf8');

    // 1. Restore stripping
    const stripOld = `						# Process root motion securely and dynamically extract walk/run speeds
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
										if a_name == "idle1" and track_path.contains("mixamorig_Hips"):
											current_model.position.y = base_y
								
								if a_name == "walk_forward" and first_val is Vector3 and last_val is Vector3:
									var dist = Vector2(first_val.x, first_val.z).distance_to(Vector2(last_val.x, last_val.z))
									if dist > 0.1 and anim.length > 0: speed = (dist / anim.length) * 1.25
								elif a_name == "run_forward" and first_val is Vector3 and last_val is Vector3:
									var dist = Vector2(first_val.x, first_val.z).distance_to(Vector2(last_val.x, last_val.z))
									if dist > 0.1 and anim.length > 0: run_speed = (dist / anim.length) * 1.25`;
    const stripNew = `						# Process root motion securely and dynamically extract walk/run speeds
						for i in range(anim.get_track_count()):
							if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
								var track_path = String(anim.track_get_path(i))
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
								
								if a_name == "walk_forward" and first_val is Vector3 and last_val is Vector3:
									var dist = Vector2(first_val.x, first_val.z).distance_to(Vector2(last_val.x, last_val.z))
									if dist > 0.1 and anim.length > 0: speed = (dist / anim.length) * 1.25
								elif a_name == "run_forward" and first_val is Vector3 and last_val is Vector3:
									var dist = Vector2(first_val.x, first_val.z).distance_to(Vector2(last_val.x, last_val.z))
									if dist > 0.1 and anim.length > 0: run_speed = (dist / anim.length) * 1.25
								
								var lock_y = a_name.begins_with("attack")
								for key_idx in range(anim.track_get_key_count(i)):
									var val = anim.track_get_key_value(i, key_idx)
									if val is Vector3:
										if base_x != null: val.x = base_x
										if base_z != null: val.z = base_z
										if lock_y and base_y != null: val.y = base_y
										anim.track_set_key_value(i, key_idx, val)`;
    content = content.replace(stripOld, stripNew);

    // 2. Remove root_motion_track from AnimationTree setup
    const treeOld = `	anim_tree.tree_root = state_machine
	if not root_motion_track_path.is_empty():
		anim_tree.root_motion_track = root_motion_track_path
	anim_tree.active = true`;
    const treeNew = `	anim_tree.tree_root = state_machine
	anim_tree.active = true`;
    content = content.replace(treeOld, treeNew);

    // 3. Restore simple velocity
    const physOld = `	elif direction != Vector3.ZERO:
		if is_instance_valid(anim_tree):
			var root_pos = anim_tree.get_root_motion_position()
			var local_motion = current_model.quaternion * root_pos
			var global_root = transform.basis * local_motion
			velocity.x = (global_root.x / delta)
			velocity.z = (global_root.z / delta)
			if current_anim_player: current_anim_player.speed_scale = current_speed / speed
		else:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed`;
    const physNew = `	elif direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		if current_anim_player: current_anim_player.speed_scale = current_speed / speed`;
    content = content.replace(physOld, physNew);
    
    // Fix current_model.position.y if it was left at 0.05
    content = content.replace('current_model.position.y = base_y', 'pass # Not needed anymore');

    fs.writeFileSync('scripts/PlayerController.gd', content);
    console.log("PlayerController.gd reverted to manual velocity + AnimTree StateMachine");
}

function revertRootMotionEnemy() {
    let content = fs.readFileSync('scripts/Enemy.gd', 'utf8');

    // 1. Restore _make_animation_stationary
    const mkAnimOld = `func _make_animation_stationary(anim: Animation):
	for i in range(anim.get_track_count()):
		var path = str(anim.track_get_path(i))
		if "mixamorig_Hips" in path and anim.track_get_type(i) == 1:
			root_motion_track_path = NodePath(path)
			var start_val = anim.track_get_key_value(i, 0) if anim.track_get_key_count(i) > 0 else Vector3.ZERO
			if start_val is Vector3:
				$Visuals.position.y = start_val.y`;
    const mkAnimNew = `func _make_animation_stationary(anim: Animation):
	for i in range(anim.get_track_count()):
		var path = str(anim.track_get_path(i))
		if "mixamorig_Hips" in path and anim.track_get_type(i) == 1:
			var start_val = anim.track_get_key_value(i, 0) if anim.track_get_key_count(i) > 0 else Vector3.ZERO
			for key_idx in range(anim.track_get_key_count(i)):
				var val = anim.track_get_key_value(i, key_idx)
				if val is Vector3:
					val.x = start_val.x
					val.z = start_val.z
					anim.track_set_key_value(i, key_idx, val)`;
    content = content.replace(mkAnimOld, mkAnimNew);

    // 2. Remove tree root motion track
    const treeOld = `		anim_tree.tree_root = state_machine
		if not root_motion_track_path.is_empty():
			anim_tree.root_motion_track = root_motion_track_path
		anim_tree.active = true`;
    const treeNew = `		anim_tree.tree_root = state_machine
		anim_tree.active = true`;
    content = content.replace(treeOld, treeNew);
    
    // 3. Remove root motion velocity computation
    const physOld = `	if is_instance_valid(anim_tree) and anim_state.get_current_node() == "running":
		var root_pos = anim_tree.get_root_motion_position()
		var local_motion = $Visuals/Goblin.quaternion * root_pos
		var global_root = transform.basis * local_motion
		velocity.x = (global_root.x / delta) * $Visuals.scale.x
		velocity.z = (global_root.z / delta) * $Visuals.scale.x
		if animation_player: animation_player.speed_scale = speed / 3.0
	else:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if animation_player: animation_player.speed_scale = 1.0`;
    const physNew = `	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_instance_valid(anim_state) and anim_state.get_current_node() == "running":
		if animation_player: animation_player.speed_scale = speed / 3.0
	else:
		if animation_player: animation_player.speed_scale = 1.0`;
    // Note: since my previous fix for Enemy.gd didn't match the regex, the physics logic is probably already manual! Let's check if it includes global_root
    if (content.includes('var root_pos = anim_tree.get_root_motion_position()')) {
        content = content.replace(physOld, physNew);
    }

    fs.writeFileSync('scripts/Enemy.gd', content);
    console.log("Enemy.gd reverted to manual velocity + AnimTree StateMachine");
}

revertRootMotionPlayer();
revertRootMotionEnemy();
