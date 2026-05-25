extends CharacterBody3D

const FIREBALL_SCRIPT = preload("res://scripts/Fireball.gd")

var sound_cache: Dictionary = {
	"res://sounds/fireball.wav": preload("res://sounds/fireball.wav"),
	"res://sounds/lightning-bolt1.wav": preload("res://sounds/lightning-bolt1.wav"),
	"res://sounds/lightning-bolt2.wav": preload("res://sounds/lightning-bolt2.wav"),
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

@export var speed = 4.0
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
var current_model: Node3D = null
var current_anim_player: AnimationPlayer = null
var left_hand_attachment: BoneAttachment3D = null
var current_animation = ""

var current_spell: int = 0
var spells: Array = ["zap", "fireball", "unsummon", "giant_growth", "heal", "drain_life", "build_wall"]

var health: float = 100.0
var max_health: float = 100.0
var damage_multiplier: float = 1.0

var mana: float = 100.0
var max_mana: float = 100.0
var mana_regen: float = 3.0

var footstep_player: AudioStreamPlayer3D
var punch_cooldown: float = 0.0

var spell_costs = {
	"zap": 5.0,
	"fireball": 30.0,
	"unsummon": 15.0,
	"drain_life": 40.0,
	"giant_growth": 20.0,
	"heal": 30.0,
	"build_wall": 25.0
}

var is_charging_fireball: bool = false
var charged_mana: float = 0.0

var cooldown_timers = {
	"zap": 0.5,
	"fireball": 2.0,
	"unsummon": 3.0,
	"drain_life": 4.0,
	"giant_growth": 10.0,
	"heal": 15.0,
	"build_wall": 5.0
}
var current_cooldown: float = 0.0
var current_max_cooldown: float = 0.1

var health_bar: ProgressBar
var mana_bar: ProgressBar
var cooldown_ui: Control
var spell_label: Label
var vbox_left: VBoxContainer
var vbox_right: VBoxContainer

var last_position: Vector3
var last_rotation_y: float
var remote_velocity: Vector3 = Vector3.ZERO
var remote_turn_speed: float = 0.0

const CHAR_MODELS = {
	"CopperMyr": "Meshy_AI_Rusted_Halo_Automaton_0523095702_texture.fbx",
	"Elf": "Meshy_AI_Verdant_Elf_Warrior_0523074438_texture.fbx",
	"Goblin1": "Meshy_AI_Rope_Bound_Goblin_0523095536_texture.fbx",
	"GoldMyr": "Meshy_AI_this_creature_in_t_po_0525024518_texture_fbx.fbx",
	"Krenko": "Meshy_AI_Crowned_Goblin_Warlor_0523095625_texture.fbx",
	"LodestoneMyr": "Meshy_AI_Desert_Sentinel_0523104615_texture.fbx",
	"MyrEnforcer": "Meshy_AI_Azure_Sentinel_0523105005_texture.fbx",
	"MyrScavenger": "Meshy_AI_Scavenger_Droid_T_Pos_0523095723_texture.fbx",
	"SilverMyr": "Meshy_AI_Blue_Neon_Automaton_0523095643_texture.fbx"
}

func _enter_tree():
	var id = name.to_int()
	if id > 0:
		player_id = id
		set_multiplayer_authority(id)

func _ready():
	if is_multiplayer_authority():
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
	footstep_player.finished.connect(func(): footstep_player.play())
	if visuals.has_node("Particles"): visuals.get_node("Particles").queue_free()
	
	_apply_player_details()

func _apply_player_details():
	if GameManager.players.has(player_id):
		var details = GameManager.players[player_id]
		player_name = details.get("name", "Player")
		player_character = details.get("character", "SilverMyr")
	
	name_label.text = player_name
	_load_character_model()

func _load_character_model():
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
	# Mixamo models face +Z by default, Godot forward is -Z
	current_model.rotation.y = PI
	
	current_anim_player = current_model.get_node_or_null("AnimationPlayer")
	if not current_anim_player:
		return
		
	# Find Skeleton3D and attach bone
	var skeleton = _find_skeleton(current_model)
	if skeleton:
		left_hand_attachment = BoneAttachment3D.new()
		left_hand_attachment.bone_name = "mixamorig_LeftHand"
		skeleton.add_child(left_hand_attachment)
		
	var is_mutant = (player_character == "LodestoneMyr" or player_character == "MyrEnforcer")
	var anim_names = {
		"idle": "mutant idle.fbx" if is_mutant else "idle.fbx",
		"walk": "mutant walking.fbx" if is_mutant else "walking.fbx",
		"run": "mutant run.fbx" if is_mutant else "running.fbx",
		"jump": "mutant jumping.fbx" if is_mutant else "jumping up.fbx",
		"pickup": "mutant roaring.fbx" if is_mutant else "stand to cover.fbx",
		"turn_left": "mutant left turn 45.fbx" if is_mutant else "left turn.fbx",
		"turn_right": "mutant right turn 45.fbx" if is_mutant else "right turn.fbx"
	}
	
	anim_names["attack1"] = "res://meshes/characters/shared/Punching (1).fbx"
	anim_names["attack2"] = "res://meshes/characters/shared/Cross Punch.fbx"
	anim_names["attack3"] = "res://meshes/characters/shared/Hook Punch.fbx"
		
	anim_names["cast_fireball"] = "res://meshes/characters/shared/Fireball.fbx"
	anim_names["cast_zap"] = "res://meshes/characters/shared/Punching.fbx"
	
	var lib = AnimationLibrary.new()
	for a_name in anim_names:
		var path = anim_names[a_name]
		if not path.begins_with("res://"):
			path = "res://meshes/characters/" + player_character + "/" + path
			
		if ResourceLoader.exists(path):
			var a_scene = load(path)
			if a_scene:
				var a_inst = a_scene.instantiate()
				var a_player = a_inst.get_node_or_null("AnimationPlayer")
				if a_player and a_player.has_animation("mixamo_com"):
					var anim = a_player.get_animation("mixamo_com").duplicate()
					anim.loop_mode = Animation.LOOP_LINEAR if (a_name != "jump" and not a_name.begins_with("attack") and a_name != "pickup" and a_name != "cast_fireball" and a_name != "cast_zap") else Animation.LOOP_NONE
					
					# Remove horizontal root motion (X, Z) and stop sinking (Y) on attacks
					for i in range(anim.get_track_count()):
						if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
							var base_y = null
							if a_name.begins_with("attack") and anim.track_get_key_count(i) > 0:
								var first_val = anim.track_get_key_value(i, 0)
								if first_val is Vector3:
									base_y = first_val.y
							
							for key_idx in range(anim.track_get_key_count(i)):
								var val = anim.track_get_key_value(i, key_idx)
								if val is Vector3:
									val.x = 0
									val.z = 0
									if base_y != null:
										val.y = base_y
									anim.track_set_key_value(i, key_idx, val)
									
					lib.add_animation(a_name, anim)
				a_inst.queue_free()
				
	if current_anim_player.has_animation_library("actions"):
		current_anim_player.remove_animation_library("actions")
	current_anim_player.add_animation_library("actions", lib)
	
	play_anim("idle")

func play_anim(anim_name: String):
	if not current_anim_player or not current_anim_player.has_animation("actions/" + anim_name):
		return
		
	# Do not allow any other animations to interrupt while in the air
	if is_multiplayer_authority() and not is_on_floor() and anim_name != "jump":
		return
		
	var protected_anims = ["attack", "attack1", "attack2", "attack3", "pickup", "cast_fireball", "cast_zap"]
	
	if current_animation in protected_anims and anim_name not in protected_anims:
		if current_anim_player.is_playing() and current_anim_player.current_animation == "actions/" + current_animation:
			return
			
	var should_play = (current_animation != anim_name) or not current_anim_player.is_playing()
	
	if should_play:
		var blend = 0.2
		var speed_mult = 1.0
		
		if anim_name.begins_with("attack") or anim_name == "cast_fireball" or anim_name == "cast_zap":
			blend = 0.2
			speed_mult = 2.0
			
		current_anim_player.play("actions/" + anim_name, blend, speed_mult)
		current_animation = anim_name

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		elif event.pressed and punch_cooldown <= 0:
			rpc("trigger_anim", "attack")
			punch_cooldown = 0.8
			
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_spell = (current_spell + 1) % spells.size()
			_update_spell_ui()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_spell = (current_spell - 1 + spells.size()) % spells.size()
			_update_spell_ui()
			
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if spells[current_spell] == "fireball":
				if event.pressed:
					var base_cost = 20.0
					if current_cooldown <= 0 and mana >= base_cost:
						mana -= base_cost
						charged_mana = base_cost
						is_charging_fireball = true
						rpc("start_charge_fireball")
				elif is_charging_fireball:
					is_charging_fireball = false
					var info = _get_spell_target()
					rpc("release_fireball", info.target, charged_mana)
					current_max_cooldown = cooldown_timers["fireball"]
					current_cooldown = current_max_cooldown
			elif event.pressed:
				var cost = spell_costs.get(spells[current_spell], 0.0)
				if current_cooldown > 0 or mana < cost:
					return
					
				mana -= cost
				current_max_cooldown = cooldown_timers[spells[current_spell]]
				current_cooldown = current_max_cooldown
				
				var info = _get_spell_target()
				var target_pos = info.target
				var hit_path = info.hit_path
				
				if spells[current_spell] == "zap":
					rpc("fire_zap", target_pos, hit_path)
				elif spells[current_spell] == "unsummon":
					rpc("fire_unsummon", target_pos, hit_path)
				elif spells[current_spell] == "drain_life":
					rpc("fire_drain_life", target_pos, hit_path)
				elif spells[current_spell] == "giant_growth":
					rpc("cast_giant_growth")
				elif spells[current_spell] == "heal":
					rpc("cast_heal")
				elif spells[current_spell] == "build_wall":
					rpc("cast_build_wall", target_pos)
			
	if event is InputEventKey and event.physical_keycode == KEY_F and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rpc("trigger_anim", "pickup")
			
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().root.get_node("Main").toggle_menu(true)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().root.get_node("Main").toggle_menu(false)
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -deg_to_rad(65), deg_to_rad(45))

func _get_spell_target() -> Dictionary:
	var center = get_viewport().get_visible_rect().size / 2.0
	var from = camera.project_ray_origin(center)
	var to = from + camera.project_ray_normal(center) * 100.0
	
	var spell_target = to
	var hit_path = NodePath()
	
	var space_state = get_world_3d().direct_space_state
	var env_query = PhysicsRayQueryParameters3D.create(from, to, 1)
	env_query.exclude = [ self.get_rid()]
	var env_result = space_state.intersect_ray(env_query)
	var env_hit_pos = to
	if env_result:
		env_hit_pos = env_result.position
		
	var shapecast = ShapeCast3D.new()
	shapecast.shape = SphereShape3D.new()
	shapecast.shape.radius = 1.0
	shapecast.target_position = to - from
	shapecast.collision_mask = 4
	shapecast.add_exception(self)
	shapecast.top_level = true
	add_child(shapecast)
	shapecast.global_position = from
	shapecast.force_shapecast_update()
	
	var hit_enemy = false
	if shapecast.is_colliding():
		var enemy_hit_pos = shapecast.get_collision_point(0)
		if from.distance_to(enemy_hit_pos) <= from.distance_to(env_hit_pos):
			spell_target = enemy_hit_pos
			var collider = shapecast.get_collider(0)
			if collider is Node:
				hit_path = collider.get_path()
			hit_enemy = true
			
	shapecast.queue_free()
	
	if not hit_enemy and env_result:
		spell_target = env_hit_pos
		if env_result.collider is Node:
			hit_path = env_result.collider.get_path()
			
	return { "target": spell_target, "hit_path": hit_path }

func _physics_process(delta):
	# Sync player character dynamically if changed (late joiners etc)
	if not current_model or name_label.text != player_name:
		_apply_player_details()
		
	if not is_multiplayer_authority():
		_sync_remote_animations(delta)
		return
		
	# Update cooldowns
	if punch_cooldown > 0:
		punch_cooldown -= delta
	if current_cooldown > 0:
		current_cooldown -= delta
		if current_cooldown <= 0 and cooldown_ui:
			cooldown_ui.queue_redraw()
		elif cooldown_ui:
			cooldown_ui.queue_redraw()
			
	if is_instance_valid(vbox_left):
		var v_size = get_viewport().get_visible_rect().size
		vbox_left.position = Vector2(40, v_size.y - vbox_left.size.y - 40)
		vbox_right.position = Vector2(v_size.x - vbox_right.size.x - 40, v_size.y - vbox_right.size.y - 40)
		if cooldown_ui:
			cooldown_ui.position = v_size / 2.0
			
	if is_charging_fireball:
		var drain_rate = 50.0
		var drain_amount = drain_rate * delta
		if mana >= drain_amount and charged_mana + drain_amount <= 100.0:
			mana -= drain_amount
			charged_mana += drain_amount
			rpc("update_charge_visual", charged_mana)
		elif mana > 0 and charged_mana < 100.0:
			var remaining = min(mana, 100.0 - charged_mana)
			mana -= remaining
			charged_mana += remaining
			rpc("update_charge_visual", charged_mana)
	else:
		mana = min(mana + mana_regen * delta, max_mana)
	if mana_bar: mana_bar.value = mana
	if health_bar: health_bar.value = health
		
	# Add gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	var is_running = Input.is_key_pressed(KEY_SHIFT)
	var current_speed = run_speed if is_running else speed
	
	# Movement vectors (only forward/backwards)
	var forward_dir = Input.get_axis("move_forward", "move_back")
	var direction = (transform.basis * Vector3(0, 0, forward_dir)).normalized()
	
	# Keyboard turning
	var turn_dir = Input.get_axis("move_right", "move_left")
	if turn_dir != 0:
		rotate_y(turn_dir * 3.0 * delta)
	
	var is_acting = (current_animation.begins_with("attack") or current_animation == "pickup" or current_animation == "cast_fireball" or current_animation == "cast_zap") and current_anim_player and current_anim_player.is_playing() and current_anim_player.current_animation == "actions/" + current_animation
	
	if is_acting:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	elif direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		var target_look = visuals.global_position + direction
		# Project to XZ plane
		target_look.y = visuals.global_position.y
		visuals.look_at(target_look, Vector3.UP)
		visuals.rotation.x = 0
		visuals.rotation.z = 0
		
		if is_on_floor():
			play_anim("run" if is_running else "walk")
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		if is_on_floor():
			if turn_dir > 0:
				play_anim("turn_left")
			elif turn_dir < 0:
				play_anim("turn_right")
			else:
				play_anim("idle")
		
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = 5.0
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

@rpc("any_peer", "call_local", "reliable")
func trigger_anim(anim_name: String):
	var actual_anim = anim_name
	if anim_name == "attack":
		actual_anim = "attack" + str(randi() % 3 + 1)
	play_anim(actual_anim)
	
	if anim_name == "attack":
		var space_state = get_world_3d().direct_space_state
		var from = visuals.global_position + Vector3(0, 0.2, 0)
		# Assuming visuals face -Z
		var forward = - visuals.global_transform.basis.z.normalized()
		var to = from + forward * 3.0
		
		# Collision mask 4 is the enemy layer
		var query = PhysicsRayQueryParameters3D.create(from, to, 4)
		query.exclude = [ self.get_rid()]
		var result = space_state.intersect_ray(query)
		
		if result and result.collider and result.collider.has_method("take_damage"):
			play_sound("res://sounds/punch" + str(randi() % 4 + 1) + ".wav")
			if multiplayer.is_server():
				result.collider.take_damage(25.0, forward)
				if result.collider.has_method("gain_aggro"):
					result.collider.gain_aggro(self )
		else:
			play_sound("res://sounds/punsh-miss.wav")

@rpc("any_peer", "call_local", "reliable")
func fire_zap(target_pos: Vector3, hit_path: NodePath = NodePath()):
	play_anim("cast_zap")
	play_sound("res://sounds/lightning-bolt" + str(randi() % 2 + 1) + ".wav")
	
	if multiplayer.is_server() and not hit_path.is_empty():
		var hit_node = get_node_or_null(hit_path)
		if hit_node and hit_node.has_method("take_damage"):
			var dir = (target_pos - global_position).normalized()
			hit_node.take_damage(15.0 * damage_multiplier, dir)
			if hit_node.has_method("gain_aggro"):
				hit_node.gain_aggro(self )
	
	var timer = get_tree().create_timer(0.15)
	timer.timeout.connect(func():
		if left_hand_attachment:
			var start_pos = left_hand_attachment.global_position
			create_zap_visual(start_pos, target_pos)
	)

var charging_effect = null

@rpc("any_peer", "call_local", "reliable")
func start_charge_fireball():
	play_anim("cast_fireball")
	play_sound("res://sounds/fireball.wav")
	
	if left_hand_attachment:
		charging_effect = Node3D.new()
		left_hand_attachment.add_child(charging_effect)
		
		var mesh_inst = MeshInstance3D.new()
		var mesh = SphereMesh.new()
		mesh.radius = 0.25
		mesh.height = 0.5
		mesh_inst.mesh = mesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.8, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.9, 0.4)
		mat.emission_energy_multiplier = 5.0
		mesh_inst.material_override = mat
		charging_effect.add_child(mesh_inst)
		
		charging_effect.scale = Vector3.ONE * 0.2

@rpc("any_peer", "call_local", "unreliable")
func update_charge_visual(mana_amount: float):
	if is_instance_valid(charging_effect):
		var s = 0.2 + (mana_amount / 100.0) * 1.8
		charging_effect.scale = Vector3.ONE * s

@rpc("any_peer", "call_local", "reliable")
func release_fireball(target_pos: Vector3, mana_amount: float):
	if is_instance_valid(charging_effect):
		charging_effect.queue_free()
		
	if left_hand_attachment:
		var start_pos = left_hand_attachment.global_position
		var dmg_mult = mana_amount / 20.0
		create_fireball(start_pos, target_pos, dmg_mult)

func create_fireball(start_pos: Vector3, target_pos: Vector3, charge_mult: float = 1.0):
	var area = Area3D.new()
	area.collision_mask = 5
	area.collision_layer = 0
	area.set_script(FIREBALL_SCRIPT)
	area.set("direction", (target_pos - start_pos).normalized())
	area.set("damage", 40.0 * damage_multiplier * charge_mult)
	
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.15 # Reduced base radius
	shape.shape = sphere
	area.add_child(shape)
	
	# Inner Core
	var mesh_inst = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	mesh_inst.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.4)
	mat.emission_energy_multiplier = 8.0
	mesh_inst.material_override = mat
	area.add_child(mesh_inst)
	
	# Outer Core
	var outer_inst = MeshInstance3D.new()
	var outer_mesh = SphereMesh.new()
	outer_mesh.radius = 0.55
	outer_mesh.height = 1.1
	outer_inst.mesh = outer_mesh
	var outer_mat = StandardMaterial3D.new()
	outer_mat.albedo_color = Color(1.0, 0.4, 0.0, 0.5)
	outer_mat.emission_enabled = true
	outer_mat.emission = Color(1.0, 0.2, 0.0)
	outer_mat.emission_energy_multiplier = 3.0
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_inst.material_override = outer_mat
	area.add_child(outer_inst)
	
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.0)
	light.light_energy = 5.0
	light.omni_range = 10.0
	area.add_child(light)
	
	# Scale visuals by charge_mult
	shape.scale = Vector3.ONE * min(charge_mult, 3.0) # Clamp collision scaling to prevent floor scraping
	mesh_inst.scale = Vector3.ONE * charge_mult
	outer_inst.scale = Vector3.ONE * charge_mult
	light.omni_range = 10.0 * charge_mult
	light.light_energy = 5.0 * charge_mult
	
	var particles = CPUParticles3D.new()
	particles.amount = 60
	particles.lifetime = 0.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.4
	particles.gravity = Vector3(0, 1.5, 0)
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 1.5
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.5))
	curve.add_point(Vector2(1, 0.0))
	particles.scale_amount_curve = curve
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.1, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 0.8), Color(1, 0.5, 0), Color(0.8, 0.1, 0), Color(0.2, 0.2, 0.2, 0)])
	particles.color_ramp = grad
	
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.15
	p_mesh.height = 0.3
	p_mesh.radial_segments = 8
	p_mesh.rings = 4
	var p_mat = StandardMaterial3D.new()
	p_mat.vertex_color_use_as_albedo = true
	p_mat.albedo_color = Color(1.0, 1.0, 1.0)
	p_mat.emission_enabled = true
	p_mat.emission = Color(1.0, 0.5, 0.0)
	p_mat.emission_energy_multiplier = 2.0
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mesh.material = p_mat
	particles.mesh = p_mesh
	area.add_child(particles)
	
	get_tree().root.add_child(area)
	area.global_position = start_pos

func create_zap_visual(start_pos: Vector3, end_pos: Vector3):
	var distance = start_pos.distance_to(end_pos)
	
	# Create a container node to hold both the beam and the impact effects
	var container = Node3D.new()
	get_tree().root.add_child(container)
	container.global_position = start_pos
	
	# Use an arbitrary up vector to avoid gimbal lock if shooting straight up/down
	var up = Vector3.UP
	if (end_pos - start_pos).normalized().abs().y > 0.99:
		up = Vector3.RIGHT
	container.look_at(end_pos, up)
	
	# The Beam
	var beam = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = distance
	cyl.radial_segments = 8
	beam.mesh = cyl
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.z = - distance / 2.0
	beam.rotation.x = PI / 2.0
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 15.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.8
	beam.material_override = mat
	container.add_child(beam)
	
	# Outer Beam Aura
	var beam_aura = MeshInstance3D.new()
	var cyl_aura = CylinderMesh.new()
	cyl_aura.top_radius = 0.15
	cyl_aura.bottom_radius = 0.15
	cyl_aura.height = distance
	cyl_aura.radial_segments = 8
	beam_aura.mesh = cyl_aura
	beam_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam_aura.position.z = - distance / 2.0
	beam_aura.rotation.x = PI / 2.0
	var mat_aura = StandardMaterial3D.new()
	mat_aura.albedo_color = Color(0.2, 0.6, 1.0, 0.3)
	mat_aura.emission_enabled = true
	mat_aura.emission = Color(0.1, 0.4, 1.0)
	mat_aura.emission_energy_multiplier = 4.0
	mat_aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_aura.material_override = mat_aura
	container.add_child(beam_aura)
	
	# Particle Mesh (reused for muzzle and impact)
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.05
	p_mesh.height = 0.1
	p_mesh.radial_segments = 8
	p_mesh.rings = 4
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.5))
	curve.add_point(Vector2(1, 0.0))
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1), Color(0.2, 0.8, 1.0), Color(0.0, 0.2, 1.0, 0.0)])
	
	var p_mat = StandardMaterial3D.new()
	p_mat.vertex_color_use_as_albedo = true
	p_mat.albedo_color = Color(1, 1, 1)
	p_mat.emission_enabled = true
	p_mat.emission = Color(0.2, 0.8, 1.0)
	p_mat.emission_energy_multiplier = 10.0
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Muzzle Flash
	var muzzle = CPUParticles3D.new()
	muzzle.amount = 40
	muzzle.lifetime = 0.3
	muzzle.explosiveness = 1.0
	muzzle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	muzzle.emission_sphere_radius = 0.1
	muzzle.spread = 180.0
	muzzle.initial_velocity_min = 4.0
	muzzle.initial_velocity_max = 8.0
	muzzle.damping_min = 15.0
	muzzle.damping_max = 20.0
	muzzle.scale_amount_curve = curve
	muzzle.color_ramp = grad
	muzzle.mesh = p_mesh
	muzzle.material_override = p_mat
	container.add_child(muzzle)
	muzzle.emitting = true
	
	# Impact Light
	var light = OmniLight3D.new()
	light.light_color = Color(0.2, 0.8, 1.0)
	light.light_energy = 8.0
	light.omni_range = 5.0
	light.position.z = - distance
	container.add_child(light)
	
	# Impact Sparkles
	var sparkles = CPUParticles3D.new()
	sparkles.amount = 60
	sparkles.lifetime = 0.5
	sparkles.explosiveness = 1.0
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 0.2
	sparkles.spread = 180.0
	sparkles.initial_velocity_min = 5.0
	sparkles.initial_velocity_max = 12.0
	sparkles.damping_min = 10.0
	sparkles.damping_max = 15.0
	sparkles.scale_amount_curve = curve
	sparkles.color_ramp = grad
	sparkles.mesh = p_mesh
	sparkles.material_override = p_mat
	sparkles.position.z = - distance
	container.add_child(sparkles)
	sparkles.emitting = true
	
	# Animation
	var tween = container.create_tween().set_parallel(true)
	# Fade out beam
	tween.tween_property(beam, "scale:x", 0.0, 0.15)
	tween.tween_property(beam, "scale:z", 0.0, 0.15)
	tween.tween_property(beam_aura, "scale:x", 0.0, 0.2)
	tween.tween_property(beam_aura, "scale:z", 0.0, 0.2)
	# Fade out light
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	
	# Cleanup
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): if is_instance_valid(container): container.queue_free())

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found = _find_skeleton(child)
		if found:
			return found
	return null

func _create_player_ui():
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# Bottom Left - Health & Mana
	vbox_left = VBoxContainer.new()
	ui_layer.add_child(vbox_left)
	vbox_left.add_theme_constant_override("separation", 10)
	
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(300, 30)
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.show_percentage = false
	var sb_health = StyleBoxFlat.new()
	sb_health.bg_color = Color(0.8, 0.2, 0.2)
	health_bar.add_theme_stylebox_override("fill", sb_health)
	vbox_left.add_child(health_bar)
	
	mana_bar = ProgressBar.new()
	mana_bar.custom_minimum_size = Vector2(300, 30)
	mana_bar.max_value = max_mana
	mana_bar.value = mana
	mana_bar.show_percentage = false
	var sb_mana = StyleBoxFlat.new()
	sb_mana.bg_color = Color(0.2, 0.4, 0.9)
	mana_bar.add_theme_stylebox_override("fill", sb_mana)
	vbox_left.add_child(mana_bar)
	
	# Bottom Right - Spell & Cooldown
	vbox_right = VBoxContainer.new()
	ui_layer.add_child(vbox_right)
	vbox_right.add_theme_constant_override("separation", 10)
	
	spell_label = Label.new()
	spell_label.add_theme_font_size_override("font_size", 28)
	spell_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	spell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox_right.add_child(spell_label)
	
	cooldown_ui = Control.new()
	ui_layer.add_child(cooldown_ui)
	cooldown_ui.draw.connect(_on_cooldown_draw)
	
	_update_spell_ui()

func _on_cooldown_draw():
	if current_cooldown > 0:
		var center = Vector2.ZERO
		var radius = 25.0
		var angle_from = - PI / 2.0
		var progress = 1.0 - (current_cooldown / current_max_cooldown)
		var angle_to = angle_from + (PI * 2.0 * progress)
		
		cooldown_ui.draw_arc(center, radius, 0, PI * 2.0, 64, Color(1, 1, 1, 0.1), 4.0, true)
		cooldown_ui.draw_arc(center, radius, angle_from, angle_to, 64, Color(1, 1, 1, 0.4), 4.0, true)
	
	_update_spell_ui()

func _update_spell_ui():
	if spell_label:
		var s_name = spells[current_spell].capitalize()
		var cost = spell_costs.get(spells[current_spell], 0.0)
		spell_label.text = s_name + " (Mana: " + str(cost) + ")"

func add_mana(amount: float):
	if is_multiplayer_authority():
		mana = min(mana + amount, max_mana)
		if mana_bar: mana_bar.value = mana

func play_sound(path: String, volume_db: float = 0.0):
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

func _sync_remote_animations(delta):
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
	var is_acting = (current_animation.begins_with("attack") or current_animation == "pickup" or current_animation == "cast_fireball" or current_animation == "cast_zap") and current_anim_player and current_anim_player.is_playing() and current_anim_player.current_animation == "actions/" + current_animation
	
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
			play_anim("idle")

# --- NEW SPELLS ---

@rpc("any_peer", "call_local", "reliable")
func fire_unsummon(target_pos: Vector3, hit_path: NodePath = NodePath()):
	play_anim("attack")
	play_sound("res://sounds/punch1.wav")
	if multiplayer.is_server() and not hit_path.is_empty():
		var hit_node = get_node_or_null(hit_path)
		if hit_node and hit_node.has_method("take_damage"):
			var dir = (target_pos - global_position).normalized()
			# Huge knockback (dir * 5.0), low damage
			hit_node.take_damage(5.0 * damage_multiplier, dir * 5.0)
			if hit_node.has_method("gain_aggro"):
				hit_node.gain_aggro(self )
			
	var timer = get_tree().create_timer(0.15)
	timer.timeout.connect(func():
		if left_hand_attachment:
			create_unsummon_visual(left_hand_attachment.global_position, target_pos)
	)

@rpc("any_peer", "call_local", "reliable")
func fire_drain_life(target_pos: Vector3, hit_path: NodePath = NodePath()):
	play_anim("attack")
	play_sound("res://sounds/lifedrain.wav")
	if multiplayer.is_server() and not hit_path.is_empty():
		var hit_node = get_node_or_null(hit_path)
		if hit_node and hit_node.has_method("take_damage"):
			var dir = (target_pos - global_position).normalized()
			hit_node.take_damage(30.0 * damage_multiplier, dir)
			health = min(health + 30.0, max_health)
			if hit_node.has_method("gain_aggro"):
				hit_node.gain_aggro(self )
			
	var timer = get_tree().create_timer(0.15)
	timer.timeout.connect(func():
		if left_hand_attachment:
			create_drain_visual(left_hand_attachment.global_position, target_pos)
	)

@rpc("any_peer", "call_local", "reliable")
func cast_giant_growth():
	play_anim("pickup")
	play_sound("res://sounds/giant-growth.wav")
	
	# Grow bigger over 0.5s
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self , "scale", Vector3(2.0, 2.0, 2.0), 0.5)
	damage_multiplier = 3.0
	
	# Slow animations for heavy feel
	if current_anim_player:
		current_anim_player.speed_scale = 0.6
	
	# Boost health
	max_health += 50.0
	health = min(health + 50.0, max_health)
	
	create_growth_visual(global_position)
	
	# Lasts 15 seconds
	await get_tree().create_timer(15.0).timeout
	
	# Revert
	var tween2 = create_tween().set_parallel(true)
	tween2.tween_property(self , "scale", Vector3(1, 1, 1), 0.5)
	damage_multiplier = 1.0
	max_health -= 50.0
	health = min(health, max_health)
	if current_anim_player:
		current_anim_player.speed_scale = 1.0

@rpc("any_peer", "call_local", "reliable")
func cast_heal():
	play_anim("pickup")
	play_sound("res://sounds/heal1.wav")
	health = min(health + 50.0, max_health)
	
	if multiplayer.is_server():
		var base = get_tree().root.get_node_or_null("Main/BaseCristal")
		if base and "health" in base and "max_health" in base:
			base.health = min(base.health + 50.0, base.max_health)
			
	create_heal_visual(global_position)

@rpc("any_peer", "call_local", "reliable")
func cast_build_wall(target_pos: Vector3):
	play_anim("attack")
	if multiplayer.is_server():
		var main = get_tree().root.get_node_or_null("Main")
		if main and main.has_method("spawn_wall"):
			main.spawn_wall(target_pos, rotation.y)

# --- VISUAL EFFECTS ---

func create_unsummon_visual(start_pos: Vector3, end_pos: Vector3):
	var distance = start_pos.distance_to(end_pos)
	var container = Node3D.new()
	get_tree().root.add_child(container)
	container.global_position = start_pos
	var up = Vector3.UP
	if abs((end_pos - start_pos).normalized().y) > 0.99: up = Vector3.RIGHT
	container.look_at(end_pos, up)
	
	var splash = CPUParticles3D.new()
	splash.amount = 40
	splash.lifetime = 0.5
	splash.explosiveness = 0.9
	splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	splash.emission_sphere_radius = 0.5
	splash.spread = 180.0
	splash.initial_velocity_min = 8.0
	splash.initial_velocity_max = 12.0
	splash.damping_min = 5.0
	splash.damping_max = 10.0
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.2
	p_mesh.height = 0.4
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.1, 0.4, 1.0, 0.8)
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mesh.material = p_mat
	splash.mesh = p_mesh
	splash.position.z = - distance
	container.add_child(splash)
	splash.emitting = true
	
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): if is_instance_valid(container): container.queue_free())

func create_drain_visual(start_pos: Vector3, end_pos: Vector3):
	var distance = start_pos.distance_to(end_pos)
	var container = Node3D.new()
	get_tree().root.add_child(container)
	container.global_position = start_pos
	var up = Vector3.UP
	if abs((end_pos - start_pos).normalized().y) > 0.99: up = Vector3.RIGHT
	container.look_at(end_pos, up)
	
	var beam = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.1
	cyl.height = distance
	beam.mesh = cyl
	beam.position.z = - distance / 2.0
	beam.rotation.x = PI / 2.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.0, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.0, 0.6)
	mat.emission_energy_multiplier = 5.0
	beam.material_override = mat
	container.add_child(beam)
	
	var tween = container.create_tween()
	tween.tween_property(beam, "scale:x", 0.0, 0.2)
	tween.tween_property(beam, "scale:z", 0.0, 0.2)
	
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): if is_instance_valid(container): container.queue_free())

func create_growth_visual(pos: Vector3):
	var particles = CPUParticles3D.new()
	particles.amount = 50
	particles.lifetime = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.5
	particles.gravity = Vector3(0, 5, 0)
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.15
	p_mesh.height = 0.3
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.2, 1.0, 0.2)
	p_mat.emission_enabled = true
	p_mat.emission = Color(0.2, 1.0, 0.2)
	p_mat.emission_energy_multiplier = 3.0
	p_mesh.material = p_mat
	particles.mesh = p_mesh
	
	get_tree().root.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func create_heal_visual(pos: Vector3):
	var particles = CPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.0
	particles.gravity = Vector3(0, 3, 0)
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.1
	p_mesh.height = 0.2
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(1.0, 0.9, 0.4)
	p_mat.emission_enabled = true
	p_mat.emission = Color(1.0, 0.8, 0.2)
	p_mat.emission_energy_multiplier = 5.0
	p_mesh.material = p_mat
	particles.mesh = p_mesh
	
	get_tree().root.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())
