extends CharacterBody3D

const FIREBALL_SCENE = preload("res://scenes/Fireball.tscn")

var sound_cache: Dictionary = {
	"res://sounds/fireball.wav": preload("res://sounds/fireball.wav"),
	"res://sounds/shock-1.wav": preload("res://sounds/shock-1.wav"),
	"res://sounds/shock-2.wav": preload("res://sounds/shock-2.wav"),
	"res://sounds/shock-3.wav": preload("res://sounds/shock-3.wav"),
	"res://sounds/punch1.wav": preload("res://sounds/punch1.wav"),
	"res://sounds/punch2.wav": preload("res://sounds/punch2.wav"),
	"res://sounds/punch3.wav": preload("res://sounds/punch3.wav"),
	"res://sounds/punch4.wav": preload("res://sounds/punch4.wav"),
	"res://sounds/punsh-miss.wav": preload("res://sounds/punsh-miss.wav"),
	"res://sounds/lifedrain.wav": preload("res://sounds/lifedrain.wav"),
	"res://sounds/giant-growth.wav": preload("res://sounds/giant-growth.wav"),
	"res://sounds/running-footsteps-stone.wav": preload("res://sounds/running-footsteps-stone.wav"),
	"res://sounds/walking-footsteps-stone.wav": preload("res://sounds/walking-footsteps-stone.wav")
}

@export var speed = 2.5
@export var run_speed = 8.0

# Synced properties
@export var player_id: int = 0
@export var player_name: String = "Player"
@export var player_character: String = "SilverMyr"

@onready var spring_arm = $SpringArm3D
@onready var camera = $SpringArm3D/Camera3D
@onready var visuals = $Visuals
@onready var name_label = $NameLabel3D

var mouse_sensitivity = 0.003
@onready var current_model: Node3D = null
var current_anim_player: AnimationPlayer = null
var anim_tree: AnimationTree
var anim_state: AnimationNodeStateMachinePlayback
var root_motion_track_path: NodePath

var right_hand_attachment: BoneAttachment3D = null
var left_hand_attachment: BoneAttachment3D = null
var chest_attachment: BoneAttachment3D = null
var magic_essence_particles: CPUParticles3D = null
var magic_essence_sphere: MeshInstance3D = null
var magic_essence_light: OmniLight3D = null
var current_animation = ""
var anim_debug_label: Label3D
var active_drain_visuals: Array = []

var health_component: HealthComponent
var damage_multiplier: float = 1.0

var footstep_player: AudioStreamPlayer3D
var charge_audio_player: AudioStreamPlayer3D
var punch_cooldown: float = 0.0
var jump_delay_timer: float = 0.0
var pending_jump_force: float = 0.0

var magic_pulse_tween: Tween

var caster: PlayerCaster
var input: PlayerInput
var state_machine: StateMachine

const PLAYER_HUD_SCENE = preload("res://scenes/PlayerHUD.tscn")
const MAGIC_ESSENCE_SCENE = preload("res://scenes/MagicEssence.tscn")
var player_hud: PlayerHUD

var last_position: Vector3
var last_rotation_y: float
var remote_velocity: Vector3 = Vector3.ZERO
var remote_turn_speed: float = 0.0

const CHAR_MODELS = {
	"CopperMyr": "CopperMyr.fbx",
	"Elf": "Elf.fbx",
	"Goblin": "Goblin.fbx",
	"GoldMyr": "GoldMyr.fbx",
	"Krenko": "Krenko.fbx",
	"LodestoneMyr": "LodestoneMyr.fbx",
	"MyrEnforcer": "MyrEnforcer.fbx",
	"SilverMyr": "SilverMyr.fbx"
}

func _enter_tree() -> void:
	var id = name.to_int()
	if id > 0:
		player_id = id
		set_multiplayer_authority(id)

@rpc("authority", "call_local", "reliable")
func setup_spawn_transform(spawn_pos: Vector3, spawn_rot: Basis) -> void:
	position = spawn_pos
	transform.basis = spawn_rot

func _ready() -> void:
	health_component = HealthComponent.new()
	health_component.max_health = 100.0
	health_component.health_changed.connect(_on_health_changed)
	health_component.health_depleted.connect(die)
	add_child(health_component)
	
	var hurtbox = HurtboxComponent.new()
	hurtbox.health_component = health_component
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	var col = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	hurtbox.add_child(col)
	add_child(hurtbox)
	
	caster = PlayerCaster.new()
	caster.name = "Caster"
	add_child(caster)
	
	input = PlayerInput.new()
	input.name = "Input"
	add_child(input)
	
	if is_multiplayer_authority():
		# Calculate spawn position locally to prevent MultiplayerSynchronizer race conditions
		var main = get_tree().root.get_node_or_null("Main")
		if main:
			var container = main.get_node_or_null("PlayersContainer")
			if container:
				var my_index = container.get_children().find(self)
				if my_index == -1: my_index = container.get_child_count()
				
				var spawn_pos = Vector3.ZERO
				var markers = main.get_node_or_null("SpawnPoints")
				if markers and markers.get_child_count() > 0:
					var m_idx = my_index % markers.get_child_count()
					spawn_pos = markers.get_child(m_idx).global_position
				else:
					var m_idx = my_index % main.SPAWN_POINTS.size()
					spawn_pos = main.SPAWN_POINTS[m_idx]
				
				position = spawn_pos
				
				var target_island = main.ISLAND_POSITIONS[my_index % main.ISLAND_POSITIONS.size()]
				var dir = (target_island - spawn_pos)
				dir.y = 0
				if dir != Vector3.ZERO:
					transform.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
					
		camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		name_label.visible = false
		_create_player_ui()
	else:
		name_label.visible = true
		if has_node("CrosshairLayer"):
			$CrosshairLayer.visible = false
	
	# Cleanup plasma nodes
	if visuals.has_node("PlasmaMesh"): visuals.get_node("PlasmaMesh").queue_free()
	if visuals.has_node("OmniLight3D"): visuals.get_node("OmniLight3D").queue_free()
	if visuals.has_node("Particles"): visuals.get_node("Particles").queue_free()
	
	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.bus = "SFX"
	footstep_player.volume_db = -80.0
	add_child(footstep_player)
	# Force loop playback just in case import settings don't have loop enabled
	footstep_player.finished.connect(footstep_player.play)
	if visuals.has_node("Particles"): visuals.get_node("Particles").queue_free()
	

	_apply_player_details()
	
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
			
		state_machine.init(self, "idle")
	
	# FSM Setup
	state_machine = StateMachine.new()
	state_machine.name = "StateMachine"
	add_child(state_machine)
	
	var states = {
		"idle": PlayerIdleState.new(),
		"walk": PlayerWalkState.new(),
		"run": PlayerRunState.new(),
		"jump": PlayerJumpState.new(),
		"attack": PlayerAttackState.new(),
		"cast": PlayerCastState.new()
	}
	for s_name in states:
		states[s_name].name = s_name
		state_machine.add_child(states[s_name])
		
	state_machine.init(self, "idle")

	
	anim_debug_label = Label3D.new()
	anim_debug_label.position = Vector3(0, 2.5, 0)
	anim_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	anim_debug_label.pixel_size = 0.005
	anim_debug_label.modulate = Color(1, 1, 0) # yellow
	add_child(anim_debug_label)

func _apply_player_details() -> void:
	if GameManager.players.has(player_id):
		var details = GameManager.players[player_id]
		player_name = details.get("name", "Player")
		player_character = details.get("character", "SilverMyr")
	
	name_label.text = player_name
	_load_character_model()

func _load_character_model() -> void:
	if current_model:
		current_model.queue_free()
		
	var model_file = CHAR_MODELS.get(player_character, CHAR_MODELS["SilverMyr"])
	var scene = load("res://meshes/characters/" + player_character + "/" + model_file)
	if not scene:
		return
		
	current_model = scene.instantiate()
	visuals.add_child(current_model)
	
	# Scale if needed, some FBX models are huge. Mixamo models are usually fine (scale 0.01 inside but node is 1)
	current_model.scale = Vector3(1, 1, 1)
	# Slight lift to prevent feet from clipping into the floor
	current_model.position.y = 0.05
	# Mixamo models face +Z by default, Godot forward is -Z
	current_model.rotation.y = PI
	
	current_anim_player = current_model.get_node_or_null("AnimationPlayer")
	if not current_anim_player:
		return
		
	# Find Skeleton3D and attach bone
	var skeleton = _find_skeleton(current_model)
	if skeleton:
		right_hand_attachment = BoneAttachment3D.new()
		right_hand_attachment.bone_name = "mixamorig_RightHand"
		skeleton.add_child(right_hand_attachment)
		
		left_hand_attachment = BoneAttachment3D.new()
		left_hand_attachment.bone_name = "mixamorig_LeftHand"
		skeleton.add_child(left_hand_attachment)
		
		chest_attachment = BoneAttachment3D.new()
		chest_attachment.bone_name = "mixamorig_Spine2"
		skeleton.add_child(chest_attachment)
		
		# Create magic essence floating between both hands
		magic_essence_sphere = MAGIC_ESSENCE_SCENE.instantiate()
		right_hand_attachment.add_child(magic_essence_sphere)
		if is_instance_valid(caster): magic_essence_sphere.global_position = caster._get_hands_midpoint()
		
		magic_essence_particles = magic_essence_sphere.get_node("CPUParticles3D")
		magic_essence_light = magic_essence_sphere.get_node("OmniLight3D")
		
		if is_instance_valid(caster): caster._update_spell_ui()
		
	var anim_names = {
		"idle1": "idle1.fbx",
		"idle2": "idle2.fbx",
		"idle3": "idle3.fbx",
		"walk_forward": "walk_forward.fbx",
		"walk_back": "walk_back.fbx",
		"walk_left": "walk_left.fbx",
		"walk_right": "walk_right.fbx",
		"run_forward": "run_forward.fbx",
		"run_back": "run_back.fbx",
		"run_left": "run_left.fbx",
		"run_right": "run_right.fbx",
		"jump": "jump.fbx",
		"jump_running": "jump_running.fbx",
		"pickup": "pickup.fbx",
		"attack1": "attack1.fbx",
		"attack2": "attack2.fbx",
		"attack3": "attack3.fbx",
		"cast_fireball": "cast_fireball.fbx",
		"cast_zap": "cast_zap.fbx",
		"cast_unsummon": "cast_unsummon.fbx",
		"cast_drain_life": "cast_drain_life.fbx",
		"cast_giant_growth": "cast_giant_growth.fbx",
		"cast_heal": "cast_heal.fbx",
		"standing 1h magic attack 02": "standing_1h_magic_attack_02.fbx"
	}
	
	var lib = AnimationLibrary.new()
	for a_name in anim_names:
		var path = "res://player_animations/" + anim_names[a_name]
			
		if ResourceLoader.exists(path):
			var a_scene = load(path)
			if a_scene:
				var a_inst = a_scene.instantiate()
				var a_player = a_inst.get_node_or_null("AnimationPlayer")
				if a_player:
					var target_anim = "mixamo_com"
					if not a_player.has_animation(target_anim):
						for n in a_player.get_animation_list():
							if n != "RESET":
								target_anim = n
								break
					
					if a_player.has_animation(target_anim):
						var anim = a_player.get_animation(target_anim).duplicate()
						var no_loop_anims = ["jump", "jump_running", "pickup", "cast_fireball", "cast_zap", "cast_unsummon", "cast_drain_life", "cast_giant_growth", "cast_heal", "standing 1h magic attack 02"]
						var is_attack = a_name.begins_with("attack")
						if a_name in no_loop_anims or is_attack:
							anim.loop_mode = Animation.LOOP_NONE
						else:
							anim.loop_mode = Animation.LOOP_LINEAR
						
						# Process root motion securely and dynamically extract walk/run speeds
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
										anim.track_set_key_value(i, key_idx, val)
						lib.add_animation(a_name, anim)
				a_inst.queue_free()
				
	if current_anim_player.has_animation_library("actions"):
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
		
	# Add universal transitions for blending
	for a_name in anim_names:
		for t_name in anim_names:
			if a_name != t_name:
				var trans = AnimationNodeStateMachineTransition.new()
				trans.xfade_time = 0.15
				state_machine.add_transition(a_name, t_name, trans)
		
	anim_tree.tree_root = state_machine
	anim_tree.active = true
	current_model.add_child(anim_tree)
	anim_state = anim_tree.get("parameters/playback")
	
	play_anim("idle1")

func play_anim(anim_name: String) -> void:
	if not current_anim_player or not current_anim_player.has_animation("actions/" + anim_name):
		return
		
	if is_multiplayer_authority() and not is_on_floor() and anim_name != "jump":
		return
		

	var should_play = (current_animation != anim_name) or (not is_instance_valid(anim_state) or anim_state.get_current_node() != anim_name and anim_name != "jump")
	
	if should_play:
		if is_instance_valid(anim_state):
			anim_state.travel(anim_name)
		current_animation = anim_name

func is_acting() -> bool:
	if is_instance_valid(state_machine) and is_instance_valid(state_machine.current_state):
		var s_name = state_machine.current_state.name.to_lower()
		return s_name == "attack" or s_name == "cast"
	return false

func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_sync_remote_animations(delta)
	
	if is_instance_valid(state_machine):
		state_machine.update(delta)

func _physics_process(delta: float) -> void:
	# Sync player character dynamically if changed (late joiners etc)
	if not current_model or name_label.text != player_name:
		_apply_player_details()
		
	if anim_debug_label:
		anim_debug_label.text = "Anim: " + current_animation
		
	if not is_multiplayer_authority():
		_sync_remote_animations(delta)
		return
		
	# Update cooldowns
	if punch_cooldown > 0:
		punch_cooldown -= delta
		
	# Add gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	if is_instance_valid(state_machine):
		state_machine.physics_update(delta)
		
	var was_in_air = not is_on_floor()
	
	if not is_on_floor():
		if velocity.y < 0 and current_animation == "jump":
			# To simulate a falling state without a dedicated animation, we can let the jump animation 
			# reach its final frame naturally (since it's now set to LOOP_NONE).
			pass
			
		if current_animation != "jump" and current_animation != "jump_running":
			if Input.is_key_pressed(KEY_SHIFT) or Vector2(velocity.x, velocity.z).length() > 0.1:
				play_anim("jump_running")
			else:
				play_anim("jump")
	
	move_and_slide()

	var smooth_speed = remote_velocity.length()
	if is_multiplayer_authority():
		smooth_speed = Vector2(velocity.x, velocity.z).length()
		
	if smooth_speed > 0.5 and is_on_floor():
		var target_stream = sound_cache["res://sounds/running-footsteps-stone.wav"] if smooth_speed > 5.0 else sound_cache["res://sounds/walking-footsteps-stone.wav"]
		if footstep_player.stream != target_stream:
			footstep_player.stream = target_stream
			footstep_player.play()
		# Fade in to -10 db
		footstep_player.volume_db = move_toward(footstep_player.volume_db, -10.0, 80.0 * delta)
	else:
		# Fade out quickly when stopped or in air
		footstep_player.volume_db = move_toward(footstep_player.volume_db, -80.0, 160.0 * delta)
		if footstep_player.volume_db <= -79.0 and footstep_player.playing:
			footstep_player.stop()

func _sync_remote_animations(delta: float) -> void:
	var movement = position - last_position
	movement.y = 0
	
	if movement.length_squared() > 0.0001:
		remote_velocity = movement / delta
	else:
		remote_velocity = remote_velocity.lerp(Vector3.ZERO, 15.0 * delta)
		
	var turn_diff = wrapf(rotation.y - last_rotation_y, -PI, PI)
	if abs(turn_diff) > 0.001:
		remote_turn_speed = turn_diff / delta
	else:
		remote_turn_speed = lerp(remote_turn_speed, 0.0, 15.0 * delta)
	
	last_position = position
	last_rotation_y = rotation.y
	
	var smooth_speed = remote_velocity.length()
	var is_acting = false
	var is_act_anim = current_animation.begins_with("attack") or current_animation == "pickup" or current_animation.begins_with("cast_") or current_animation.begins_with("standing")
	if is_act_anim and is_instance_valid(anim_state):
		if anim_state.get_current_node() == current_animation:
			if anim_state.get_current_play_position() < anim_state.get_current_length() - 0.1:
				is_acting = true
		else:
			is_acting = true
	
	if is_acting:
		return
		
	if smooth_speed > 0.5:
		if smooth_speed > 5.0:
			play_anim("run")
		else:
			play_anim("walk")
	else:
		if remote_turn_speed > 0.5:
			play_anim("turn_left")
		elif remote_turn_speed < -0.5:
			play_anim("turn_right")
		else:
			var target_idle = "idle3" if (is_instance_valid(caster) and caster.is_charging_fireball) else "idle1"
			if current_animation != target_idle:
				play_anim(target_idle)

@rpc("any_peer", "call_local", "reliable")
func trigger_anim(anim_name: String) -> void:
	var actual_anim = anim_name
	if anim_name == "attack":
		actual_anim = "attack" + str(randi() % 3 + 1)
	play_anim(actual_anim)
	
	if anim_name == "attack":
		var forward = - visuals.global_transform.basis.z.normalized()
		var punch_pos = global_position + Vector3(0, 0.9, 0) + forward * 1.5
		
		# Delay to match animation impact frame
		await get_tree().create_timer(0.4).timeout
		if not is_instance_valid(self): return
		
		var space_state = get_world_3d().direct_space_state
		var sphere = SphereShape3D.new()
		sphere.radius = 1.0
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis(), punch_pos)
		query.collision_mask = 4
		query.exclude = [self.get_rid()]
		
		var results = space_state.intersect_shape(query)
		var hit_collider = null
		if results.size() > 0:
			hit_collider = results[0].collider
			
		if hit_collider and hit_collider.has_method("take_damage"):
			play_sound("res://sounds/punch" + str(randi() % 4 + 1) + ".wav")
			if multiplayer.is_server():
				hit_collider.take_damage(25.0 * damage_multiplier, forward)
				if hit_collider.has_method("gain_aggro"):
					hit_collider.gain_aggro(self)
		else:
			play_sound("res://sounds/punsh-miss.wav")

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found = _find_skeleton(child)
		if found:
			return found
	return null

func _create_player_ui() -> void:
	player_hud = PLAYER_HUD_SCENE.instantiate()
	add_child(player_hud)
	if is_instance_valid(caster): caster._update_spell_ui()

func play_sound(path: String, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var audio = AudioStreamPlayer3D.new()
	if not sound_cache.has(path):
		sound_cache[path] = load(path)
	audio.stream = sound_cache[path]
	if audio.stream:
		audio.volume_db = volume_db
		audio.bus = "SFX"
		add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
		return audio
	else:
		audio.queue_free()
	return null

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float, knockback_dir: Vector3 = Vector3.ZERO) -> void:
	if is_multiplayer_authority():
		health_component.damage(amount)

func die() -> void:
	position = Vector3(0, 50, 0)
	health_component.full_heal()

func _on_health_changed(new_health: float, new_max: float) -> void:
	if is_instance_valid(player_hud):
		player_hud.update_health(new_health, new_max)
