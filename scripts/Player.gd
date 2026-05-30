extends CharacterBody3D

const FIREBALL_SCRIPT = preload("res://scripts/Fireball.gd")

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
var current_model: Node3D = null
var current_anim_player: AnimationPlayer = null
var right_hand_attachment: BoneAttachment3D = null
var left_hand_attachment: BoneAttachment3D = null
var chest_attachment: BoneAttachment3D = null
var magic_essence_particles: CPUParticles3D = null
var magic_essence_sphere: MeshInstance3D = null
var magic_essence_light: OmniLight3D = null
var current_animation = ""
var anim_debug_label: Label3D
var active_drain_visuals: Array = []

var current_spell: int = 0
var spells: Array = ["shock", "fireball", "unsummon", "giant_growth", "heal", "drain_life"]

var health: float = 100.0
var max_health: float = 100.0
var damage_multiplier: float = 1.0

var mana: float = 100.0
var max_mana: float = 100.0
var mana_regen: float = 3.0

var footstep_player: AudioStreamPlayer3D
var charge_audio_player: AudioStreamPlayer3D
var punch_cooldown: float = 0.0
var jump_delay_timer: float = 0.0
var pending_jump_force: float = 0.0

var spell_costs = {
	"shock": 5.0,
	"fireball": 30.0,
	"unsummon": 15.0,
	"drain_life": 40.0,
	"giant_growth": 20.0,
	"heal": 30.0
}

var is_charging_fireball: bool = false
var charged_mana: float = 0.0
var is_giant_growth_active: bool = false
var magic_pulse_tween: Tween

var cooldown_timers = {
	"shock": 1.0,
	"fireball": 1.0,
	"unsummon": 1.0,
	"drain_life": 1.0,
	"giant_growth": 1.0,
	"heal": 1.0
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
	"CopperMyr": "CopperMyr.fbx",
	"Elf": "Elf.fbx",
	"Goblin": "Goblin.fbx",
	"GoldMyr": "GoldMyr.fbx",
	"Krenko": "Krenko.fbx",
	"LodestoneMyr": "LodestoneMyr.fbx",
	"MyrEnforcer": "MyrEnforcer.fbx",
	"SilverMyr": "SilverMyr.fbx"
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
	
	anim_debug_label = Label3D.new()
	anim_debug_label.position = Vector3(0, 2.5, 0)
	anim_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	anim_debug_label.pixel_size = 0.005
	anim_debug_label.modulate = Color(1, 1, 0) # yellow
	add_child(anim_debug_label)

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
		magic_essence_sphere = MeshInstance3D.new()
		magic_essence_sphere.top_level = true
		magic_essence_sphere.cast_shadow = 0
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.06
		sphere_mesh.height = 0.12
		var sphere_mat = StandardMaterial3D.new()
		sphere_mat.albedo_color = Color(1.0, 1.0, 1.0)
		sphere_mat.emission_enabled = true
		sphere_mat.emission = Color(1.0, 1.0, 1.0)
		sphere_mat.emission_energy_multiplier = 5.0
		sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sphere_mesh.material = sphere_mat
		magic_essence_sphere.mesh = sphere_mesh
		magic_essence_sphere.global_position = _get_hands_midpoint()
		right_hand_attachment.add_child(magic_essence_sphere)

		magic_essence_particles = CPUParticles3D.new()
		magic_essence_particles.cast_shadow = 0
		magic_essence_particles.amount = 120
		magic_essence_particles.lifetime = 0.8
		magic_essence_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		magic_essence_particles.emission_sphere_radius = 0.08
		magic_essence_particles.direction = Vector3(0, 1, 0)
		magic_essence_particles.spread = 180.0
		magic_essence_particles.initial_velocity_min = 0.05
		magic_essence_particles.initial_velocity_max = 0.2
		magic_essence_particles.gravity = Vector3(0, 0.05, 0)
		magic_essence_particles.scale_amount_min = 0.2
		magic_essence_particles.scale_amount_max = 1.8
		var p_mesh = SphereMesh.new()
		p_mesh.radius = 0.002
		p_mesh.height = 0.004
		var p_mat = StandardMaterial3D.new()
		p_mat.vertex_color_use_as_albedo = true
		p_mat.emission_enabled = true
		p_mat.emission = Color(1.0, 1.0, 1.0)
		p_mat.emission_energy_multiplier = 3.0
		p_mesh.material = p_mat
		magic_essence_particles.mesh = p_mesh
		magic_essence_sphere.add_child(magic_essence_particles)
		
		magic_essence_light = OmniLight3D.new()
		magic_essence_light.omni_range = 1.0
		magic_essence_light.light_energy = 1.0
		magic_essence_sphere.add_child(magic_essence_light)
		
		# Heat distortion / Refraction effect
		var heat_distortion = MeshInstance3D.new()
		heat_distortion.cast_shadow = 0
		var heat_mesh = SphereMesh.new()
		heat_mesh.radius = 0.12 # Larger than the base sphere
		heat_mesh.height = 0.24
		var heat_mat = ShaderMaterial.new()
		var shader = Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	// Calculate mask so distortion fades out smoothly at the edges of the heat sphere
	float edge = 1.0 - dot(NORMAL, VIEW);
	float mask = smoothstep(1.0, 0.0, edge);
	
	// Complex sine wave for heat shimmer
	float wobble = sin(TIME * 8.0 + UV.y * 20.0) * cos(TIME * 5.0 + UV.x * 20.0);
	
	// Very subtle distortion
	vec2 uv = SCREEN_UV + (wobble * 0.001 * mask);
	
	ALBEDO = texture(screen_texture, uv).rgb;
}
"""
		heat_mat.shader = shader
		heat_mesh.material = heat_mat
		heat_distortion.mesh = heat_mesh
		# Ensure the heat distortion renders before the glowing particles so it doesn't hide them!
		heat_distortion.sorting_offset = -10.0
		magic_essence_sphere.add_child(heat_distortion)
		
		_update_spell_ui()
		
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
										anim.track_set_key_value(i, key_idx, val)
										
						lib.add_animation(a_name, anim)
				a_inst.queue_free()
				
	if current_anim_player.has_animation_library("actions"):
		current_anim_player.remove_animation_library("actions")
	current_anim_player.add_animation_library("actions", lib)
	
	play_anim("idle1")

func play_anim(anim_name: String):
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
		var blend = 0.2
		var speed_mult = 1.0
		
		if anim_name.begins_with("attack") or anim_name == "cast_fireball" or anim_name == "cast_zap":
			blend = 0.2
			speed_mult = 2.0
			
		current_anim_player.play("actions/" + anim_name, blend, speed_mult)
		current_animation = anim_name

func _input(event):
	if not is_multiplayer_authority():
		return
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed and not event.is_echo():
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().root.get_node("Main").toggle_menu(true)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().root.get_node("Main").toggle_menu(false)
		get_viewport().set_input_as_handled()

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
			if is_giant_growth_active:
				return
			if spells[current_spell] == "fireball":
				if event.pressed:
					var base_cost = 10.0
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
				
				if spells[current_spell] == "shock":
					rpc("fire_shock", target_pos, hit_path)
				elif spells[current_spell] == "unsummon":
					rpc("fire_unsummon", target_pos, hit_path)
				elif spells[current_spell] == "drain_life":
					rpc("fire_drain_life", target_pos, hit_path)
				elif spells[current_spell] == "giant_growth":
					rpc("cast_giant_growth")
				elif spells[current_spell] == "heal":
					rpc("cast_heal")
			
	if event is InputEventKey and event.physical_keycode == KEY_F and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rpc("trigger_anim", "pickup")
			
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
	shapecast.add_exception(self )
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
			
	return {"target": spell_target, "hit_path": hit_path}

func _get_hands_midpoint() -> Vector3:
	# Center point between both hand bones, pushed forward
	if is_instance_valid(right_hand_attachment) and is_instance_valid(left_hand_attachment):
		var left_pos = left_hand_attachment.global_position
		var right_pos = right_hand_attachment.global_position
		var mid = (right_pos + left_pos) / 2.0
		
		# Direction from right to left hand
		var hand_dir = (left_pos - right_pos).normalized()
		var char_forward = - visuals.global_transform.basis.z.normalized()
		
		# Project character's forward direction onto the plane perpendicular to the hands
		# This guarantees the offset is strictly equidistant from both hands
		var projected_forward = (char_forward - char_forward.project(hand_dir)).normalized()
		
		return mid + projected_forward * 0.25
	return global_position + Vector3(0, 1.2, 0)

func _get_spell_origin() -> Vector3:
	if is_instance_valid(magic_essence_sphere):
		return magic_essence_sphere.global_position
	return _get_hands_midpoint()

func _process(delta: float) -> void:
	# Update drain visuals to stream from target to player's hand
	for i in range(active_drain_visuals.size() - 1, -1, -1):
		var v = active_drain_visuals[i]
		if not is_instance_valid(v.particles) or not v.particles.emitting:
			active_drain_visuals.remove_at(i)
			continue
			
		var target = v.target_pos
		if not v.hit_path.is_empty():
			var n = get_node_or_null(v.hit_path)
			if is_instance_valid(n):
				target = n.global_position + Vector3(0, 1.0, 0)
				
		var hand = _get_spell_origin()
		v.particles.global_position = target
		
		var dist = target.distance_to(hand)
		v.particles.direction = (hand - target).normalized()
		v.particles.initial_velocity_min = dist / v.particles.lifetime
		v.particles.initial_velocity_max = dist / v.particles.lifetime

	if is_instance_valid(magic_essence_sphere) and is_instance_valid(right_hand_attachment):
		var target_pos: Vector3 = _get_hands_midpoint()
		if magic_essence_sphere.global_position.distance_squared_to(target_pos) > 4.0:
			magic_essence_sphere.global_position = target_pos
		else:
			magic_essence_sphere.global_position = magic_essence_sphere.global_position.lerp(target_pos, 15.0 * delta)

func _physics_process(delta):
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
		var drain_rate = 22.5
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
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		
	# Add gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	var is_running = Input.is_key_pressed(KEY_SHIFT)
	var current_speed = run_speed if is_running else speed
	
	# Movement vectors (forward/back and left/right)
	var forward_dir = Input.get_axis("move_forward", "move_back")
	var strafe_dir = Input.get_axis("move_left", "move_right") # A is negative, D is positive
	var direction = (transform.basis * Vector3(strafe_dir, 0, forward_dir)).normalized()
	
	var is_acting = (current_animation.begins_with("attack") or current_animation == "pickup" or current_animation.begins_with("cast_")) and current_anim_player and current_anim_player.is_playing() and current_anim_player.current_animation == "actions/" + current_animation
	
	if is_acting:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	elif direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		var is_jumping_windup = jump_delay_timer > 0
		if is_on_floor() and not is_jumping_windup:
			var anim_to_play = "idle"
			if is_running:
				if forward_dir < 0: anim_to_play = "run_forward"
				elif forward_dir > 0: anim_to_play = "run_back"
				elif strafe_dir < 0: anim_to_play = "run_left"
				elif strafe_dir > 0: anim_to_play = "run_right"
			else:
				if forward_dir < 0: anim_to_play = "walk_forward"
				elif forward_dir > 0: anim_to_play = "walk_back"
				elif strafe_dir < 0: anim_to_play = "walk_left"
				elif strafe_dir > 0: anim_to_play = "walk_right"
				
			if anim_to_play != "idle":
				play_anim(anim_to_play)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		var is_jumping_windup = jump_delay_timer > 0
		if is_on_floor() and not is_jumping_windup:
			var target_idle = "idle3" if is_charging_fireball else "idle1"
			if current_animation != target_idle:
				play_anim(target_idle)
			
	if jump_delay_timer > 0:
		jump_delay_timer -= delta
		if jump_delay_timer <= 0:
			velocity.y = pending_jump_force
			
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor() and not is_acting and jump_delay_timer <= 0 and current_animation != "jump" and current_animation != "jump_running":
		jump_delay_timer = 0.75
		if is_running or Vector2(velocity.x, velocity.z).length() > 0.1:
			play_anim("jump_running")
			pending_jump_force = 5.0
		else:
			play_anim("jump")
			pending_jump_force = 2.5
		
	var was_in_air = not is_on_floor()
	
	if not is_on_floor():
		if velocity.y < 0 and current_anim_player.current_animation.begins_with("actions/jump"):
			# To simulate a falling state without a dedicated animation, we can let the jump animation 
			# reach its final frame naturally (since it's now set to LOOP_NONE).
			pass
			
		if current_animation != "jump" and current_animation != "jump_running":
			if is_running or Vector2(velocity.x, velocity.z).length() > 0.1:
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
		
		var sphere = SphereShape3D.new()
		sphere.radius = 1.0
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis(), from + forward * 1.5)
		query.collision_mask = 4
		query.exclude = [ self.get_rid()]
		
		var results = space_state.intersect_shape(query)
		var hit_collider = null
		if results.size() > 0:
			hit_collider = results[0].collider
			
		if hit_collider and hit_collider.has_method("take_damage"):
			play_sound("res://sounds/punch" + str(randi() % 4 + 1) + ".wav")
			if multiplayer.is_server():
				hit_collider.take_damage(25.0 * damage_multiplier, forward)
				if hit_collider.has_method("gain_aggro"):
					hit_collider.gain_aggro(self )
		else:
			play_sound("res://sounds/punsh-miss.wav")

func start_magic_sphere_pulse():
	if is_instance_valid(magic_essence_sphere):
		if magic_pulse_tween: magic_pulse_tween.kill()
		magic_pulse_tween = create_tween().set_loops()
		magic_pulse_tween.tween_property(magic_essence_sphere, "scale", Vector3(4.5, 4.5, 4.5), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		magic_pulse_tween.tween_property(magic_essence_sphere, "scale", Vector3(3.5, 3.5, 3.5), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_magic_sphere_pulse():
	if is_instance_valid(magic_essence_sphere):
		if magic_pulse_tween: magic_pulse_tween.kill()
		magic_pulse_tween = create_tween()
		magic_pulse_tween.tween_property(magic_essence_sphere, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

@rpc("any_peer", "call_local", "reliable")
func fire_shock(target_pos: Vector3, hit_path: NodePath = NodePath()):
	start_magic_sphere_pulse()
	play_anim("cast_drain_life")
	await get_tree().create_timer(1.0).timeout
	
	var end_time = Time.get_ticks_msec() + 2000
	var next_damage_time = Time.get_ticks_msec()
	var current_target_pos = target_pos
	var active_sounds = []
	
	while Time.get_ticks_msec() < end_time and is_inside_tree():
		var hit_node = null
		if not hit_path.is_empty():
			hit_node = get_node_or_null(hit_path)
			if is_instance_valid(hit_node) and hit_node.is_inside_tree():
				current_target_pos = hit_node.global_position + Vector3(0, 1.0, 0)
				
		var start_pos = _get_spell_origin()
		var random_offset = Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
		create_shock_visual(start_pos, current_target_pos + random_offset)
		
		if randf() < 0.4:
			var s = play_sound("res://sounds/shock-" + str(randi() % 3 + 1) + ".wav", -15.0)
			if s: active_sounds.append(s)
			
		if multiplayer.is_server() and is_instance_valid(hit_node) and hit_node.has_method("take_damage"):
			if Time.get_ticks_msec() >= next_damage_time:
				var dir = (current_target_pos - global_position).normalized()
				dir.y = 0.0
				if dir == Vector3.ZERO: dir = Vector3.FORWARD
				else: dir = dir.normalized()
				hit_node.take_damage(5.0 * damage_multiplier, dir * 0.1)
				if hit_node.has_method("apply_stun"):
					hit_node.rpc("apply_stun", 0.5)
				if hit_node.has_method("gain_aggro"):
					hit_node.gain_aggro(self)
				next_damage_time = Time.get_ticks_msec() + 400 # 5 ticks over 2 seconds (25 base damage)
				
		await get_tree().create_timer(randf_range(0.05, 0.15)).timeout

	stop_magic_sphere_pulse()

	for s in active_sounds:
		if is_instance_valid(s) and s.playing:
			var tween = create_tween()
			tween.tween_interval(0.5)
			tween.tween_property(s, "volume_db", -80.0, 0.5)
			tween.tween_callback(func():
				if is_instance_valid(s):
					s.stop()
					s.queue_free()
			)

@rpc("any_peer", "call_local", "reliable")
func start_charge_fireball():
	if charge_audio_player == null:
		charge_audio_player = AudioStreamPlayer3D.new()
		charge_audio_player.bus = "SFX"
		add_child(charge_audio_player)
	charge_audio_player.volume_db = -20.0
	charge_audio_player.stream = load("res://sounds/fireball-charging.wav")
	charge_audio_player.play()
	
@rpc("any_peer", "call_local", "unreliable")
func update_charge_visual(mana_amount: float):
	if is_instance_valid(magic_essence_sphere):
		var charge_ratio = (mana_amount - 10.0) / 90.0
		var s = 1.0 + charge_ratio * 3.0
		magic_essence_sphere.scale = Vector3.ONE * s
		
		if is_instance_valid(magic_essence_particles):
			magic_essence_particles.initial_velocity_min = 0.05 + charge_ratio * 1.5
			magic_essence_particles.initial_velocity_max = 0.2 + charge_ratio * 4.0
			magic_essence_particles.radial_accel_min = charge_ratio * 5.0
			magic_essence_particles.radial_accel_max = charge_ratio * 10.0
			magic_essence_particles.scale_amount_max = 1.8 + charge_ratio * 2.0

@rpc("any_peer", "call_local", "reliable")
func release_fireball(target_pos: Vector3, mana_amount: float):
	if charge_audio_player and charge_audio_player.playing:
		var audio_tween = create_tween()
		audio_tween.tween_property(charge_audio_player, "volume_db", -80.0, 1.0)
		audio_tween.tween_callback(func(): charge_audio_player.stop())
		
	play_anim("cast_fireball")
	
	if is_instance_valid(magic_essence_sphere):
		var tween = create_tween()
		tween.tween_property(magic_essence_sphere, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		if is_instance_valid(magic_essence_particles):
			magic_essence_particles.initial_velocity_min = 0.05
			magic_essence_particles.initial_velocity_max = 0.2
			magic_essence_particles.radial_accel_min = 0.0
			magic_essence_particles.radial_accel_max = 0.0
			magic_essence_particles.scale_amount_max = 1.8
			
	# Delay fireball spawn to match animation peak
	await get_tree().create_timer(0.3).timeout
		
	var start_pos = _get_spell_origin()
	create_fireball(start_pos, target_pos, mana_amount)
	
	# Delay fireball sound to 0.5s
	await get_tree().create_timer(0.2).timeout
	play_sound("res://sounds/fireball.wav", -10.0)

func create_fireball(start_pos: Vector3, target_pos: Vector3, mana_amount: float = 10.0):
	var area = Area3D.new()
	area.collision_mask = 5
	area.collision_layer = 0
	area.set_script(FIREBALL_SCRIPT)
	area.set("direction", (target_pos - start_pos).normalized())
	area.set("damage", mana_amount * damage_multiplier)
	
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
	
	# Shimmer Effect
	var heat_inst = MeshInstance3D.new()
	var heat_mesh = SphereMesh.new()
	heat_mesh.radius = 0.65
	heat_mesh.height = 1.3
	var heat_mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	float edge = 1.0 - dot(NORMAL, VIEW);
	float mask = smoothstep(1.0, 0.0, edge);
	float wobble = sin(TIME * 8.0 + UV.y * 20.0) * cos(TIME * 5.0 + UV.x * 20.0);
	vec2 uv = SCREEN_UV + (wobble * 0.001 * mask);
	ALBEDO = texture(screen_texture, uv).rgb;
}
"""
	heat_mat.shader = shader
	heat_mesh.material = heat_mat
	heat_inst.mesh = heat_mesh
	heat_inst.sorting_offset = -10.0
	area.add_child(heat_inst)
	
	# Calculate visual scale based on mana amount (10 -> 1.0x, 100 -> 4.0x)
	var charge_mult = 1.0 + clamp((mana_amount - 10.0) / 90.0, 0.0, 1.0) * 3.0
	
	# Scale visuals by charge_mult smoothly
	shape.scale = Vector3.ONE * min(charge_mult, 3.0) # Clamp collision scaling to prevent floor scraping
	var start_scale = Vector3(0.01, 0.01, 0.01)
	mesh_inst.scale = start_scale
	outer_inst.scale = start_scale
	heat_inst.scale = start_scale
	light.omni_range = 0.0
	light.light_energy = 0.0
	
	area.position = start_pos
	get_tree().root.add_child(area)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3.ONE * charge_mult, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(outer_inst, "scale", Vector3.ONE * charge_mult, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(heat_inst, "scale", Vector3.ONE * charge_mult, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(light, "omni_range", 10.0 * charge_mult, 0.2)
	tween.tween_property(light, "light_energy", 5.0 * charge_mult, 0.2)
	
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

func create_shock_visual(start_pos: Vector3, end_pos: Vector3):
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
	mat.albedo_color = Color(1.0, 0.6, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
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
	mat_aura.albedo_color = Color(1.0, 0.2, 0.2, 0.3)
	mat_aura.emission_enabled = true
	mat_aura.emission = Color(1.0, 0.1, 0.1)
	mat_aura.emission_energy_multiplier = 4.0
	mat_aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_aura.material_override = mat_aura
	container.add_child(beam_aura)
	
	# Particle Mesh (reused for muzzle and impact)
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.015
	p_mesh.height = 0.03
	p_mesh.radial_segments = 8
	p_mesh.rings = 4
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.5))
	curve.add_point(Vector2(1, 0.0))
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1), Color(1.0, 0.2, 0.2), Color(1.0, 0.0, 0.0, 0.0)])
	
	var p_mat = StandardMaterial3D.new()
	p_mat.vertex_color_use_as_albedo = true
	p_mat.albedo_color = Color(1, 1, 1)
	p_mat.emission_enabled = true
	p_mat.emission = Color(1.0, 0.2, 0.2)
	p_mat.emission_energy_multiplier = 10.0
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Muzzle Flash
	var muzzle = CPUParticles3D.new()
	muzzle.amount = 150
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
	light.light_color = Color(1.0, 0.2, 0.2)
	light.light_energy = 8.0
	light.omni_range = 5.0
	light.position.z = - distance
	container.add_child(light)
	
	# Impact Sparkles
	var sparkles = CPUParticles3D.new()
	sparkles.amount = 250
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

func _update_spell_ui():
	if spell_label:
		var s_name = spells[current_spell].capitalize()
		var cost = spell_costs.get(spells[current_spell], 0.0)
		spell_label.text = s_name + " (Mana: " + str(cost) + ")"
		
	if right_hand_attachment and is_instance_valid(magic_essence_particles):
		magic_essence_particles.initial_velocity_min = 0.05
		magic_essence_particles.initial_velocity_max = 0.2
		magic_essence_particles.radial_accel_min = 0.0
		magic_essence_particles.radial_accel_max = 0.0
		magic_essence_particles.scale_amount_max = 1.8
		
		if is_instance_valid(magic_essence_sphere):
			magic_essence_sphere.scale = Vector3.ONE
			
		var spell = spells[current_spell]
		var color = Color(1, 1, 1)
		if spell == "shock": color = Color(1.0, 0.1, 0.1)
		elif spell == "fireball": color = Color(1.0, 0.4, 0.1)
		elif spell == "unsummon": color = Color(0.3, 0.6, 1.0)
		elif spell == "drain_life": color = Color(0.1, 0.0, 0.15)
		elif spell == "giant_growth": color = Color(0.2, 0.9, 0.2)
		elif spell == "heal": color = Color(1.0, 0.95, 0.7)
		
		var grad = Gradient.new()
		if spell == "drain_life":
			grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			grad.colors = PackedColorArray([Color(0.01, 0.0, 0.02), color, Color(color.r, color.g, color.b, 0.0)])
			magic_essence_particles.color_ramp = grad
			magic_essence_particles.color = color
			
			if magic_essence_particles.mesh and magic_essence_particles.mesh.material:
				magic_essence_particles.mesh.material.emission = color
			if magic_essence_sphere and magic_essence_sphere.mesh and magic_essence_sphere.mesh.material:
				magic_essence_sphere.mesh.material.albedo_color = Color.BLACK
				magic_essence_sphere.mesh.material.emission = Color.BLACK
		else:
			grad.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
			grad.colors = PackedColorArray([Color.WHITE, color, Color(color.r, color.g, color.b, 0.0)])
			magic_essence_particles.color_ramp = grad
			magic_essence_particles.color = Color.WHITE
			
			if magic_essence_particles.mesh and magic_essence_particles.mesh.material:
				magic_essence_particles.mesh.material.emission = Color.WHITE
			if magic_essence_sphere and magic_essence_sphere.mesh and magic_essence_sphere.mesh.material:
				magic_essence_sphere.mesh.material.albedo_color = color
				magic_essence_sphere.mesh.material.emission = color
				
		if magic_essence_light:
			magic_essence_light.light_color = color

func add_mana(amount: float):
	if is_multiplayer_authority():
		mana = min(mana + amount, max_mana)
		if mana_bar: mana_bar.value = mana

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
	var is_acting = (current_animation.begins_with("attack") or current_animation == "pickup" or current_animation.begins_with("cast_") or current_animation.begins_with("standing")) and current_anim_player and current_anim_player.is_playing() and current_anim_player.current_animation == "actions/" + current_animation
	
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
			var target_idle = "idle3" if is_charging_fireball else "idle1"
			if current_animation != target_idle:
				play_anim(target_idle)

# --- NEW SPELLS ---

@rpc("any_peer", "call_local", "reliable")
func fire_unsummon(target_pos: Vector3, hit_path: NodePath = NodePath()):
	start_magic_sphere_pulse()
	play_anim("standing 1h magic attack 02")
	await get_tree().create_timer(0.5).timeout
	play_sound("res://sounds/unsummon.wav", 5.0) # Play the unsummon sound effect
	if multiplayer.is_server():
		var space_state = get_world_3d().direct_space_state
		var from = visuals.global_position + Vector3(0, 1.0, 0)
		var forward = -visuals.global_transform.basis.z.normalized()
		
		# Large spherecast in front of the player
		var shape = SphereShape3D.new()
		shape.radius = 3.5
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(), from + forward * 3.5)
		query.collision_mask = 4 # Enemies
		query.exclude = [self.get_rid()]
		
		var results = space_state.intersect_shape(query)
		for res in results:
			var hit_node = res.collider
			if hit_node and hit_node.has_method("take_damage"):
				var push_dir = -visuals.global_transform.basis.z.normalized()
				push_dir.y = 0.02 # Reduced vertical lift by 5x
				push_dir = push_dir.normalized()
				
				# knockback_dir is multiplied by 10.0 in Enemy.gd, so 12.0 results in a 120.0 velocity horizontal push
				hit_node.take_damage(0.0, push_dir * 12.0)
				if hit_node.has_method("gain_aggro"):
					hit_node.gain_aggro(self)
			
	var timer = get_tree().create_timer(0.15)
	timer.timeout.connect(func():
		var forward = -visuals.global_transform.basis.z.normalized()
		var end_pos = _get_spell_origin() + forward * 10.0
		create_unsummon_visual(_get_spell_origin(), end_pos)
		stop_magic_sphere_pulse()
	)

@rpc("any_peer", "call_local", "reliable")
func fire_drain_life(target_pos: Vector3, hit_path: NodePath = NodePath()):
	start_magic_sphere_pulse()
	play_anim("cast_drain_life")
	play_sound("res://sounds/lifedrain.wav")
	
	# Wait 1 second before first damage tick and visual stream
	await get_tree().create_timer(1.0).timeout
	
	create_drain_visual(_get_spell_origin(), target_pos, 1.5, hit_path)
	
	if multiplayer.is_server() and not hit_path.is_empty():
		var hit_node = get_node_or_null(hit_path)
		
		var max_damage = 30.0 * damage_multiplier
		var total_damage_dealt = 0.0
		var tick_damage = max_damage / 30.0 # 30 fast ticks to reach max damage
		
		# Deal continuous small damage until max is reached or animation ends
		while is_instance_valid(hit_node) and current_anim_player and current_anim_player.current_animation == "actions/cast_drain_life" and total_damage_dealt < max_damage:
			if hit_node.has_method("take_damage"):
				var dir = (hit_node.global_position - global_position).normalized()
				# Very low knockback since we are hitting them 30 times rapidly
				hit_node.take_damage(tick_damage, dir * 0.05)
				health = min(health + tick_damage, max_health)
				total_damage_dealt += tick_damage
				if hit_node.has_method("gain_aggro"):
					hit_node.gain_aggro(self )
			await get_tree().create_timer(0.05).timeout
	
	stop_magic_sphere_pulse()

@rpc("any_peer", "call_local", "reliable")
func cast_giant_growth():
	start_magic_sphere_pulse()
	play_anim("cast_giant_growth")
	await get_tree().create_timer(1.25).timeout
	
	play_sound("res://sounds/giant-growth.wav")
	
	# Grow bigger over 0.5s
	stop_magic_sphere_pulse()
	is_giant_growth_active = true
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self , "scale", Vector3(2.0, 2.0, 2.0), 0.5)
	if is_instance_valid(magic_essence_sphere) and magic_essence_sphere.mesh and magic_essence_sphere.mesh.material:
		tween.tween_property(magic_essence_sphere.mesh.material, "albedo_color:a", 0.0, 0.5)
		tween.tween_property(magic_essence_sphere.mesh.material, "emission_energy_multiplier", 0.0, 0.5)
	if is_instance_valid(magic_essence_light):
		tween.tween_property(magic_essence_light, "light_energy", 0.0, 0.5)
	if is_instance_valid(magic_essence_particles):
		magic_essence_particles.emitting = false
		
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
	is_giant_growth_active = false
	var tween2 = create_tween().set_parallel(true)
	tween2.tween_property(self , "scale", Vector3(1, 1, 1), 0.5)
	if is_instance_valid(magic_essence_sphere) and magic_essence_sphere.mesh and magic_essence_sphere.mesh.material:
		tween2.tween_property(magic_essence_sphere.mesh.material, "albedo_color:a", 1.0, 0.5)
		tween2.tween_property(magic_essence_sphere.mesh.material, "emission_energy_multiplier", 5.0, 0.5)
	if is_instance_valid(magic_essence_light):
		tween2.tween_property(magic_essence_light, "light_energy", 1.0, 0.5)
	if is_instance_valid(magic_essence_particles):
		magic_essence_particles.emitting = true
		
	damage_multiplier = 1.0
	max_health -= 50.0
	health = min(health, max_health)
	if current_anim_player:
		current_anim_player.speed_scale = 1.0

@rpc("any_peer", "call_local", "reliable")
func cast_heal():
	start_magic_sphere_pulse()
	play_anim("cast_heal")
	await get_tree().create_timer(0.5).timeout
	
	play_sound("res://sounds/heal1.wav")
	health = min(health + 50.0, max_health)
	
	if multiplayer.is_server():
		var base = get_tree().root.get_node_or_null("Main/BaseCristal")
		if base and "health" in base and "max_health" in base:
			base.health = min(base.health + 50.0, base.max_health)
			
	create_heal_visual(global_position)
	stop_magic_sphere_pulse()

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float, knockback_dir: Vector3 = Vector3.ZERO):
	if is_multiplayer_authority():
		health = max(0, health - amount)
		if health_bar: health_bar.value = health
		
		if health <= 0:
			die()

func die():
	position = Vector3(0, 50, 0)
	health = max_health
	if health_bar: health_bar.value = health


# --- VISUAL EFFECTS ---

func create_unsummon_visual(start_pos: Vector3, end_pos: Vector3):
	var container = Node3D.new()
	get_tree().root.add_child(container)
	container.global_position = start_pos
	var up = Vector3.UP
	if abs((end_pos - start_pos).normalized().y) > 0.99: up = Vector3.RIGHT
	container.look_at(end_pos, up)
	
	# 1. Wind Streaks
	var wind_streaks = CPUParticles3D.new()
	wind_streaks.amount = 60
	wind_streaks.lifetime = 0.4
	wind_streaks.explosiveness = 0.8
	wind_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	wind_streaks.emission_sphere_radius = 1.0
	wind_streaks.direction = Vector3(0, 0, -1)
	wind_streaks.spread = 15.0
	wind_streaks.initial_velocity_min = 25.0
	wind_streaks.initial_velocity_max = 35.0
	wind_streaks.particle_flag_align_y = true # Aligns the long mesh with velocity
	
	var streak_mesh = BoxMesh.new()
	streak_mesh.size = Vector3(0.05, 1.0, 0.05) # Stretched along Y axis
	
	var streak_mat = StandardMaterial3D.new()
	streak_mat.albedo_color = Color(0.8, 0.9, 1.0, 0.3)
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_mat.emission_enabled = true
	streak_mat.emission = Color(0.5, 0.8, 1.0)
	streak_mat.emission_energy_multiplier = 1.0
	streak_mesh.material = streak_mat
	wind_streaks.mesh = streak_mesh
	
	var streak_curve = Curve.new()
	streak_curve.add_point(Vector2(0, 0.2))
	streak_curve.add_point(Vector2(0.2, 1.0))
	streak_curve.add_point(Vector2(1, 0.0))
	wind_streaks.scale_amount_curve = streak_curve
	
	container.add_child(wind_streaks)
	wind_streaks.emitting = true
	
	# 2. Expanding Shockwave Ring
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 16
	ring.mesh = torus
	ring.rotation.x = PI / 2.0 # Face forward relative to container
	
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.8, 0.9, 1.0, 0.6)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.6, 0.9, 1.0)
	ring_mat.emission_energy_multiplier = 2.0
	ring.material_override = ring_mat
	container.add_child(ring)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(5.0, 5.0, 5.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD)
	
	# 3. Ground Dust Kick-up
	var dust = CPUParticles3D.new()
	dust.amount = 40
	dust.lifetime = 0.8
	dust.explosiveness = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.5, 0.1, 0.5)
	dust.position.y = -1.0 # Down near feet
	dust.direction = Vector3(0, 0, -1)
	dust.spread = 20.0
	dust.initial_velocity_min = 10.0
	dust.initial_velocity_max = 20.0
	dust.damping_min = 15.0
	dust.damping_max = 25.0
	
	var dust_mesh = SphereMesh.new()
	dust_mesh.radius = 0.3
	dust_mesh.height = 0.6
	dust_mesh.radial_segments = 8
	dust_mesh.rings = 4
	var dust_mat = StandardMaterial3D.new()
	dust_mat.albedo_color = Color(0.6, 0.5, 0.4, 0.4) # Dust color
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mesh.material = dust_mat
	dust.mesh = dust_mesh
	
	var dust_curve = Curve.new()
	dust_curve.add_point(Vector2(0, 0.5))
	dust_curve.add_point(Vector2(0.3, 1.0))
	dust_curve.add_point(Vector2(1, 0.0))
	dust.scale_amount_curve = dust_curve
	
	container.add_child(dust)
	dust.emitting = true
	
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): if is_instance_valid(container): container.queue_free())

func create_drain_visual(start_pos: Vector3, end_pos: Vector3, duration: float = 2.35, hit_path: NodePath = NodePath()):
	var particles = CPUParticles3D.new()
	particles.cast_shadow = 0
	particles.local_coords = false
	get_tree().root.add_child(particles)
	particles.global_position = end_pos
	
	particles.amount = 80
	particles.lifetime = 0.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.1
	particles.gravity = Vector3.ZERO
	particles.spread = 0.06
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 5.0
	
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.05
	p_mesh.height = 0.1
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.01, 0.0, 0.02)
	mat.emission_enabled = true
	mat.emission = Color(0.02, 0.0, 0.04)
	mat.emission_energy_multiplier = 0.5
	p_mesh.material = mat
	particles.mesh = p_mesh
	
	# Shimmer Effect on target
	var heat_inst = MeshInstance3D.new()
	var heat_mesh = SphereMesh.new()
	heat_mesh.radius = 0.8
	heat_mesh.height = 1.6
	var heat_mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	float edge = 1.0 - dot(NORMAL, VIEW);
	float mask = smoothstep(1.0, 0.0, edge);
	float wobble = sin(TIME * 8.0 + UV.y * 20.0) * cos(TIME * 5.0 + UV.x * 20.0);
	vec2 uv = SCREEN_UV + (wobble * 0.005 * mask);
	ALBEDO = texture(screen_texture, uv).rgb;
}
"""
	heat_mat.shader = shader
	heat_mesh.material = heat_mat
	heat_inst.mesh = heat_mesh
	heat_inst.sorting_offset = -10.0
	particles.add_child(heat_inst)
	
	active_drain_visuals.append({
		"particles": particles,
		"hit_path": hit_path,
		"target_pos": end_pos
	})
	
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.emitting = false
			var die_timer = get_tree().create_timer(1.0)
			die_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())
	)

func create_growth_visual(pos: Vector3):
	var particles = CPUParticles3D.new()
	particles.amount = 120
	particles.lifetime = 1.5
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 2.0
	particles.gravity = Vector3(0, 5, 0)
	particles.cast_shadow = 0 # Disable shadows for glowing effect
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 2.0
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1, 0.0))
	particles.scale_amount_curve = curve
	
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
	
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.emitting = false
			await get_tree().create_timer(2.0).timeout
			if is_instance_valid(particles):
				particles.queue_free()
	)

func create_heal_visual(pos: Vector3):
	var container = Node3D.new()
	get_tree().root.add_child(container)
	container.global_position = pos
	
	# Particles
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
	
	# Smooth fade out for particles (shrink to 0)
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(0.7, 1.0))
	curve.add_point(Vector2(1, 0.0))
	particles.scale_amount_curve = curve
	
	container.add_child(particles)
	particles.emitting = true
	
	# Holy Light Beam
	var beam = SpotLight3D.new()
	beam.spot_angle = 15.0
	beam.spot_range = 15.0
	beam.light_color = Color(1.0, 0.95, 0.6)
	beam.light_energy = 0.0 # Start invisible
	beam.position = Vector3(0, 8, 0)
	beam.rotation_degrees.x = -90 # Point straight down
	container.add_child(beam)
	
	# Tween beam fade in/out
	var tween = create_tween()
	tween.tween_property(beam, "light_energy", 15.0, 0.2)
	tween.tween_property(beam, "light_energy", 0.0, 0.8).set_delay(0.5)
	
	# Smoothly stop particles instead of deleting instantly
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.emitting = false
			var timer2 = get_tree().create_timer(1.0)
			timer2.timeout.connect(func(): if is_instance_valid(container): container.queue_free())
	)
