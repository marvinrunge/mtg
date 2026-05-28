extends CharacterBody3D

const WALK_SCENE = preload("res://meshes/characters/shared/walking.fbx")
const RUN_SCENE = preload("res://meshes/characters/shared/running.fbx")
const IDLE_SCENE = preload("res://meshes/characters/shared/idle1.fbx")
const DEATH_SCENE = preload("res://meshes/characters/shared/hard landing.fbx")
const ATTACK_SCENE = preload("res://meshes/characters/shared/Punching (1).fbx")

const MANA_CRYSTAL_SCRIPT = preload("res://scripts/ManaCrystal.gd")
const DAMAGE_NUMBER_SCRIPT = preload("res://scripts/DamageNumber.gd")

@export var base_speed: float = 3.0
@export var base_damage: float = 5.0
@export var base_health: float = 50.0

var speed: float
var damage: float
var health: float

var base_pos: Vector3 = Vector3(0, 1.45, 0)
var is_dead: bool = false
var has_reached_base: bool = false

var knockback_velocity: Vector3 = Vector3.ZERO
var original_material: Material = null
var flash_timer: Timer = null

var attack_cooldown: float = 0.0
const ATTACK_INTERVAL: float = 1.0

var nav_agent: NavigationAgent3D

var enemy_type: String = "goblin"
var boss_bar: ProgressBar

# --- Aggro System ---
var aggro_target: CharacterBody3D = null
var aggro_range: float = 20.0
var attack_range: float = 1.5
var leash_range: float = 40.0
var aggro_timer: float = 0.0
const AGGRO_CHECK_INTERVAL: float = 0.5

@onready var animation_player = $Visuals/Goblin/AnimationPlayer

func _ready():
	health = base_health
	speed = base_speed
	damage = base_damage
	
	# Increase physics safe margin and floor limits to avoid getting stuck on noisy trimesh terrain
	safe_margin = 0.05
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 0.5
	
	setup_animations()
	
	flash_timer = Timer.new()
	flash_timer.wait_time = 0.1
	flash_timer.one_shot = true
	flash_timer.timeout.connect(_on_flash_timeout)
	add_child(flash_timer)
	
	_play_move_anim()
		
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 3.0
	add_child(nav_agent)

func _play_move_anim() -> void:
	if not animation_player: return
	if speed > 4.0 and animation_player.has_animation("running"):
		animation_player.play("running")
	elif animation_player.has_animation("walking"):
		animation_player.play("walking")
	elif animation_player.has_animation("running"):
		animation_player.play("running")

func setup_animations():
	if not animation_player: return
	
	var anim_library = animation_player.get_animation_library("")
	if not anim_library:
		anim_library = AnimationLibrary.new()
		animation_player.add_animation_library("", anim_library)
	
	# Walking
	if WALK_SCENE:
		var w_root = WALK_SCENE.instantiate()
		var w_ap = w_root.get_node_or_null("AnimationPlayer")
		if w_ap and w_ap.has_animation("mixamo_com"):
			var anim = w_ap.get_animation("mixamo_com").duplicate()
			anim.loop_mode = Animation.LOOP_LINEAR
			_make_animation_stationary(anim)
			anim_library.add_animation("walking", anim)
		w_root.queue_free()
	
	# Running
	if RUN_SCENE:
		var r_root = RUN_SCENE.instantiate()
		var r_ap = r_root.get_node_or_null("AnimationPlayer")
		if r_ap and r_ap.has_animation("mixamo_com"):
			var anim = r_ap.get_animation("mixamo_com").duplicate()
			anim.loop_mode = Animation.LOOP_LINEAR
			_make_animation_stationary(anim)
			anim_library.add_animation("running", anim)
		r_root.queue_free()
	
	# Idle
	if IDLE_SCENE:
		var i_root = IDLE_SCENE.instantiate()
		var i_ap = i_root.get_node_or_null("AnimationPlayer")
		if i_ap and i_ap.has_animation("mixamo_com"):
			var anim = i_ap.get_animation("mixamo_com").duplicate()
			anim.loop_mode = Animation.LOOP_LINEAR
			anim_library.add_animation("idle", anim)
		i_root.queue_free()
			
	# Death
	if DEATH_SCENE:
		var d_root = DEATH_SCENE.instantiate()
		var d_ap = d_root.get_node_or_null("AnimationPlayer")
		if d_ap and d_ap.has_animation("mixamo_com"):
			var anim = d_ap.get_animation("mixamo_com").duplicate()
			anim.loop_mode = Animation.LOOP_NONE
			anim_library.add_animation("death", anim)
		d_root.queue_free()

	# Attack
	if ATTACK_SCENE:
		var a_root = ATTACK_SCENE.instantiate()
		var a_ap = a_root.get_node_or_null("AnimationPlayer")
		if a_ap and a_ap.has_animation("mixamo_com"):
			var anim = a_ap.get_animation("mixamo_com").duplicate()
			anim.loop_mode = Animation.LOOP_NONE
			_make_animation_stationary(anim)
			anim_library.add_animation("attack", anim)
		a_root.queue_free()

func _make_animation_stationary(anim: Animation):
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
					anim.track_set_key_value(i, key_idx, val)

@rpc("call_local", "authority", "reliable")
func sync_stats(type: String, max_hp: float, dmg: float, spd: float, scale_factor: float = 1.0):
	enemy_type = type
	base_health = max_hp
	health = max_hp
	damage = dmg
	speed = spd
	
	$Visuals.scale = Vector3(scale_factor, scale_factor, scale_factor)
	$Visuals.position.y = 0.0
	$CollisionShape3D.scale = Vector3(scale_factor, scale_factor, scale_factor)
	$CollisionShape3D.position.y = 0.5 * scale_factor
	
	if type == "boss":
		setup_boss_ui()
	
	# Update animation based on new speed
	_play_move_anim()

func setup_boss_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var label = Label.new()
	label.text = "COLOSSAL GOBLIN KING"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.position.y = 10
	canvas.add_child(label)
	
	boss_bar = ProgressBar.new()
	boss_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_bar.position = Vector2(200, 50)
	boss_bar.size = Vector2(get_tree().root.get_viewport().get_visible_rect().size.x - 400, 30)
	boss_bar.max_value = health
	boss_bar.value = health
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.6, 0.1, 0.6)
	boss_bar.add_theme_stylebox_override("fill", sb)
	canvas.add_child(boss_bar)

func init_stats(multiplier: float, type: String = "goblin"):
	var max_hp = 50.0
	var spd = 3.0
	var dmg = 5.0
	var scale_factor = 1.0
	
	match type:
		"tank":
			max_hp = 150.0
			spd = 1.5
			scale_factor = 2.0 * multiplier
		"swarmer":
			max_hp = 20.0
			spd = 6.0
			scale_factor = 0.4 * multiplier
		"boss":
			max_hp = 1000.0
			spd = 1.0
			scale_factor = 4.0 * multiplier
		"goblin", _:
			max_hp = 50.0
			spd = 3.0
			scale_factor = clamp(1.0 * multiplier, 1.0, 2.0)

	max_hp *= multiplier
	dmg *= multiplier
	spd *= (1.0 + (multiplier - 1.0) * 0.1)
	
	scale_factor = min(scale_factor, 4.0)
	
	rpc("sync_stats", type, max_hp, dmg, spd, scale_factor)

func _physics_process(delta):
	if not multiplayer.is_server() or is_dead:
		return
	
	# --- Ground snapping: stronger gravity to prevent floating ---
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0
	
	if has_reached_base:
		move_and_slide()
		return
	
	# --- Aggro check ---
	aggro_timer += delta
	if aggro_timer >= AGGRO_CHECK_INTERVAL:
		aggro_timer = 0.0
		_update_aggro()
	
	# Determine nav target
	var nav_target: Vector3 = base_pos
	var targeting_player = false
	if aggro_target and is_instance_valid(aggro_target):
		nav_target = aggro_target.global_position
		targeting_player = true
	
	nav_agent.target_position = nav_target
	
	# Check if we reached our target
	var is_at_target = false
	if nav_agent.is_navigation_finished():
		is_at_target = true
	elif targeting_player and global_position.distance_to(nav_target) <= attack_range:
		is_at_target = true
		
	if is_at_target:
		velocity.x = 0.0
		velocity.z = 0.0
		
		if knockback_velocity.length() > 0.1:
			velocity += knockback_velocity
			knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, 10.0 * delta)
			
		move_and_slide()
		
		# Rotate towards target
		var look_target = nav_target
		look_target.y = global_position.y
		if global_position.distance_to(look_target) > 0.1:
			var target_transform = transform.looking_at(look_target, Vector3.UP)
			transform = transform.interpolate_with(target_transform, 10.0 * delta)
			
		attack_cooldown -= delta
		if attack_cooldown <= 0.0:
			attack_cooldown = ATTACK_INTERVAL
			_perform_attack(targeting_player)
			
		return
	else:
		attack_cooldown = 0.0
		has_reached_base = false
	
	var next_path_position = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_path_position)
	dir.y = 0
	
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
	else:
		dir = Vector3.ZERO
		
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, 10.0 * delta)
		
	# Auto-step / hop over small obstacles like the base crystal pedestal
	if is_on_floor() and is_on_wall() and (next_path_position.y - global_position.y) > 0.05:
		velocity.y = 4.0
		
	move_and_slide()
	
	# Smooth rotation towards movement direction
	if dir.length_squared() > 0.001:
		var look_target = global_position + dir
		if global_position.distance_to(look_target) > 0.1:
			var current_transform = transform
			var target_transform = current_transform.looking_at(look_target, Vector3.UP)
			transform = current_transform.interpolate_with(target_transform, 5.0 * delta)

func _update_aggro() -> void:
	# If current target is dead or too far, drop aggro
	if aggro_target:
		if not is_instance_valid(aggro_target):
			aggro_target = null
		elif global_position.distance_to(aggro_target.global_position) > leash_range:
			aggro_target = null
	
	# Look for nearby players
	var players_container = get_tree().root.get_node_or_null("Main/PlayersContainer")
	if not players_container: return
	
	var closest_player: CharacterBody3D = null
	var closest_dist: float = aggro_range
	
	for player in players_container.get_children():
		if not player is CharacterBody3D: continue
		var dist: float = global_position.distance_to(player.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_player = player
	
	if closest_player:
		aggro_target = closest_player

func gain_aggro(attacker: Node) -> void:
	# Called when this enemy is attacked by a player - immediately aggro them
	if attacker is CharacterBody3D and is_instance_valid(attacker):
		aggro_target = attacker

func _perform_attack(targeting_player: bool):
	if not multiplayer.is_server() or is_dead: return
	
	rpc("play_attack_anim_and_sound", targeting_player)
	
	if targeting_player and aggro_target and is_instance_valid(aggro_target):
		if aggro_target.has_method("take_damage"):
			var push_dir = global_position.direction_to(aggro_target.global_position)
			aggro_target.take_damage(damage, push_dir)
	else:
		# Attack base
		var base = get_tree().root.get_node_or_null("Main/BaseCristal")
		if base and base.has_method("take_damage"):
			base.take_damage(damage)
		elif base and "health" in base:
			base.health = max(base.health - damage, 0.0)

@rpc("call_local", "any_peer", "reliable")
func play_attack_anim_and_sound(targeting_player: bool):
	if animation_player:
		if animation_player.has_animation("attack"):
			animation_player.play("attack", -1, 1.5)
		else:
			animation_player.play("idle", -1, 1.5)
			
	var punch_sound = "res://sounds/punch" + str(randi() % 4 + 1) + ".wav"
	var audio = AudioStreamPlayer3D.new()
	audio.stream = load(punch_sound)
	audio.bus = "SFX"
	audio.max_distance = 40.0
	add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
	
	if not targeting_player and randf() > 0.5:
		var audio2 = AudioStreamPlayer3D.new()
		audio2.stream = load("res://sounds/cristal.wav")
		audio2.bus = "SFX"
		audio2.max_distance = 40.0
		add_child(audio2)
		audio2.play()
		audio2.finished.connect(audio2.queue_free)

func take_damage(amount, knockback_dir: Vector3 = Vector3.ZERO):
	if not multiplayer.is_server() or is_dead: return
	health -= amount
	
	if enemy_type not in ["tank", "boss"]:
		knockback_velocity = knockback_dir * 10.0
	rpc("hit_reaction", amount, health)
	
	if health <= 0:
		die()

func die():
	is_dead = true
	$CollisionShape3D.set_deferred("disabled", true)
	rpc("play_death_anim")
	
	if boss_bar and boss_bar.get_parent():
		boss_bar.get_parent().queue_free()
		
	call_deferred("drop_mana_crystal")
	
	if animation_player and animation_player.has_animation("death"):
		await get_tree().create_timer(1.5).timeout
		queue_free()
	else:
		queue_free()

func drop_mana_crystal():
	var crystal = Area3D.new()
	crystal.set_script(MANA_CRYSTAL_SCRIPT)
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		main.add_child(crystal)
		crystal.global_position = global_position + Vector3(0, 0.5, 0)

@rpc("call_local", "authority", "reliable")
func play_death_anim():
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")

@rpc("call_local", "any_peer", "reliable")
func hit_reaction(amount: float, current_health: float = -1):
	if is_dead: return
	
	if boss_bar and current_health != -1:
		boss_bar.value = current_health
	
	# Damage Number
	var label = DAMAGE_NUMBER_SCRIPT.new()
	label.text = str(round(amount))
	label.modulate = Color(1, 0.2, 0.2) if amount >= 20 else Color(1, 1, 1)
	get_tree().root.add_child(label)
	label.global_position = global_position + Vector3(0, 1.5, 0)
	
	# Flash red
	var mesh_inst = _find_mesh_instance($Visuals)
	if mesh_inst and mesh_inst.mesh:
		var mat = mesh_inst.get_active_material(0)
		if mat:
			if not original_material:
				original_material = mat
			var flash_mat = mat.duplicate()
			flash_mat.albedo_color = Color(1.0, 0.0, 0.0)
			flash_mat.emission_enabled = true
			flash_mat.emission = Color(1.0, 0.0, 0.0)
			mesh_inst.material_override = flash_mat
			flash_timer.start()

func _on_flash_timeout():
	if original_material:
		var mesh_inst = _find_mesh_instance($Visuals)
		if mesh_inst:
			mesh_inst.material_override = null

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var res = _find_mesh_instance(child)
		if res: return res
	return null
