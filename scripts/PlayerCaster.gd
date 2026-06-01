extends Node
class_name PlayerCaster

@onready var controller: CharacterBody3D = get_parent()

const FIREBALL_SCENE = preload("res://scenes/Fireball.tscn")
const SHOCK_VISUAL_SCENE = preload("res://scenes/ShockVisual.tscn")
const UNSUMMON_VISUAL_SCENE = preload("res://scenes/UnsummonVisual.tscn")
const DRAIN_VISUAL_SCENE = preload("res://scenes/DrainVisual.tscn")
const GROWTH_VISUAL_SCENE = preload("res://scenes/GrowthVisual.tscn")
const HEAL_VISUAL_SCENE = preload("res://scenes/HealVisual.tscn")

var current_spell: int = 0
var spells: Array = ["shock", "fireball", "unsummon", "giant_growth", "heal", "drain_life"]
var spell_costs = {
	"shock": 15.0,
	"fireball": 10.0,
	"unsummon": 25.0,
	"giant_growth": 40.0,
	"heal": 35.0,
	"drain_life": 50.0
}
var cooldown_timers = {
	"shock": 1.5,
	"fireball": 2.0,
	"unsummon": 3.0,
	"giant_growth": 10.0,
	"heal": 8.0,
	"drain_life": 12.0
}
var current_cooldown: float = 0.0
var current_max_cooldown: float = 1.0

var mana: float = 100.0
var max_mana: float = 100.0
var mana_regen: float = 5.0
var is_charging_fireball: bool = false
var charged_mana: float = 0.0
var active_drain_visuals: Array = []
var is_giant_growth_active: bool = false

func _process(delta: float) -> void:
	if not controller.is_multiplayer_authority(): return
	
	if current_cooldown > 0:
		current_cooldown -= delta
		
	if is_charging_fireball:
		var drain_rate = 22.5
		var drain_amount = drain_rate * delta
		if mana >= drain_amount and charged_mana + drain_amount <= 100.0:
			mana -= drain_amount
			charged_mana += drain_amount
			self.rpc("update_charge_visual", charged_mana)
		elif mana > 0 and charged_mana < 100.0:
			var remaining = min(mana, 100.0 - charged_mana)
			mana -= remaining
			charged_mana += remaining
			self.rpc("update_charge_visual", charged_mana)
	elif current_cooldown <= 0:
		mana = min(mana + mana_regen * delta, max_mana)
		
	if is_instance_valid(controller.player_hud):
		controller.player_hud.update_mana(mana, max_mana)
		
	# Active drain visuals logic from Player.gd process
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
		v.particles.direction = (hand - target).normalized()
		var dist = target.distance_to(hand)
		v.particles.initial_velocity_min = dist * 2.0
		v.particles.initial_velocity_max = dist * 2.5
		
	if is_instance_valid(controller.magic_essence_sphere) and is_instance_valid(controller.right_hand_attachment):
		var target_pos: Vector3 = _get_hands_midpoint()
		if controller.magic_essence_sphere.global_position.distance_squared_to(target_pos) > 4.0:
			controller.magic_essence_sphere.global_position = target_pos
		else:
			controller.magic_essence_sphere.global_position = controller.magic_essence_sphere.global_position.lerp(target_pos, 15.0 * delta)


func scroll_spell(dir: int) -> void:
	current_spell = (current_spell + dir + spells.size()) % spells.size()
	_update_spell_ui()

func try_start_cast() -> void:
	if is_giant_growth_active: return
	if spells[current_spell] == "fireball":
		var base_cost = 10.0
		if current_cooldown <= 0 and mana >= base_cost:
			mana -= base_cost
			charged_mana = base_cost
			is_charging_fireball = true
			self.rpc("start_charge_fireball")
	else:
		var cost = spell_costs.get(spells[current_spell], 0.0)
		if current_cooldown > 0 or mana < cost: return
		
		mana -= cost
		current_max_cooldown = cooldown_timers[spells[current_spell]]
		current_cooldown = current_max_cooldown
		
		var info = _get_spell_target()
		var target_pos = info.target
		var hit_path = info.hit_path
		
		if spells[current_spell] == "shock": self.rpc("fire_shock", target_pos, hit_path)
		elif spells[current_spell] == "unsummon": self.rpc("fire_unsummon", target_pos, hit_path)
		elif spells[current_spell] == "drain_life": self.rpc("fire_drain_life", target_pos, hit_path)
		elif spells[current_spell] == "giant_growth": self.rpc("cast_giant_growth")
		elif spells[current_spell] == "heal": self.rpc("cast_heal")

func try_release_cast() -> void:
	if spells[current_spell] == "fireball" and is_charging_fireball:
		is_charging_fireball = false
		var info = _get_spell_target()
		self.rpc("release_fireball", info.target, charged_mana)
		current_max_cooldown = cooldown_timers["fireball"]
		current_cooldown = current_max_cooldown

func _get_spell_target() -> Dictionary:
	var center = controller.get_viewport().get_visible_rect().size / 2.0
	var from = controller.camera.project_ray_origin(center)
	var to = from + controller.camera.project_ray_normal(center) * 100.0
	
	var spell_target = to
	var hit_path = NodePath()
	
	var space_state = controller.get_world_3d().direct_space_state
	var env_query = PhysicsRayQueryParameters3D.create(from, to, 1)
	env_query.exclude = [controller.get_rid()]
	var env_result = space_state.intersect_ray(env_query)
	var env_hit_pos = to
	if env_result:
		env_hit_pos = env_result.position
		
	var shapecast = ShapeCast3D.new()
	shapecast.shape = SphereShape3D.new()
	shapecast.shape.radius = 1.0
	shapecast.target_position = to - from
	shapecast.collision_mask = 4
	shapecast.add_exception(controller)
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
	if is_instance_valid(controller.right_hand_attachment) and is_instance_valid(controller.left_hand_attachment):
		if not controller.right_hand_attachment.is_inside_tree() or not controller.left_hand_attachment.is_inside_tree():
			return controller.global_position + Vector3(0, 1.2, 0)
			
		var left_pos = controller.left_hand_attachment.global_position
		var right_pos = controller.right_hand_attachment.global_position
		var mid = (right_pos + left_pos) / 2.0
		
		# Direction from right to left hand
		var hand_dir = (left_pos - right_pos).normalized()
		var char_forward = - controller.visuals.global_transform.basis.z.normalized()
		
		# Project character's forward direction onto the plane perpendicular to the hands
		# This guarantees the offset is strictly equidistant from both hands
		var projected_forward = (char_forward - char_forward.project(hand_dir)).normalized()
		
		return mid + projected_forward * 0.25
	return controller.global_position + Vector3(0, 1.2, 0)

func _get_spell_origin() -> Vector3:
	if is_instance_valid(controller.magic_essence_sphere):
		return controller.magic_essence_sphere.global_position
	return _get_hands_midpoint()

func start_magic_sphere_pulse() -> void:
	if is_instance_valid(controller.magic_essence_sphere):
		if controller.magic_pulse_tween: controller.magic_pulse_tween.kill()
		controller.magic_pulse_tween = create_tween().set_loops()
		controller.magic_pulse_tween.tween_property(controller.magic_essence_sphere, "scale", Vector3(4.5, 4.5, 4.5), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		controller.magic_pulse_tween.tween_property(controller.magic_essence_sphere, "scale", Vector3(3.5, 3.5, 3.5), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_magic_sphere_pulse() -> void:
	if is_instance_valid(controller.magic_essence_sphere):
		if controller.magic_pulse_tween: controller.magic_pulse_tween.kill()
		controller.magic_pulse_tween = create_tween()
		controller.magic_pulse_tween.tween_property(controller.magic_essence_sphere, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

@rpc("any_peer", "call_local", "reliable")
func fire_shock(target_pos: Vector3, hit_path: NodePath = NodePath()) -> void:
	start_magic_sphere_pulse()
	controller.play_anim("cast_drain_life")
	if controller.get("state_machine") and is_instance_valid(controller.state_machine): controller.state_machine.change_state("cast")
	await controller.get_tree().create_timer(1.0).timeout
	
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
			var s = controller.play_sound("res://sounds/shock-" + str(randi() % 3 + 1) + ".wav", -15.0)
			if s: active_sounds.append(s)
			
		if controller.multiplayer.is_server() and is_instance_valid(hit_node) and hit_node.has_method("take_damage"):
			if Time.get_ticks_msec() >= next_damage_time:
				var dir = (current_target_pos - controller.global_position).normalized()
				dir.y = 0.0
				if dir == Vector3.ZERO: dir = Vector3.FORWARD
				else: dir = dir.normalized()
				hit_node.take_damage(5.0 * controller.damage_multiplier, dir * 0.1)
				if hit_node.has_method("apply_stun"):
					hit_node.rpc("apply_stun", 0.5)
				if hit_node.has_method("gain_aggro"):
					hit_node.gain_aggro(controller)
				next_damage_time = Time.get_ticks_msec() + 400 # 5 ticks over 2 seconds (25 base damage)
				
		await controller.get_tree().create_timer(randf_range(0.05, 0.15)).timeout

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
func start_charge_fireball() -> void:
	if controller.charge_audio_player == null:
		controller.charge_audio_player = AudioStreamPlayer3D.new()
		controller.charge_audio_player.bus = "SFX"
		controller.add_child(controller.charge_audio_player)
	controller.charge_audio_player.volume_db = -20.0
	controller.charge_audio_player.stream = load("res://sounds/fireball-charging.wav")
	controller.charge_audio_player.play()
	
@rpc("any_peer", "call_local", "unreliable")
func update_charge_visual(mana_amount: float) -> void:
	if is_instance_valid(controller.magic_essence_sphere):
		var charge_ratio = (mana_amount - 10.0) / 90.0
		var s = 1.0 + charge_ratio * 3.0
		controller.magic_essence_sphere.scale = Vector3.ONE * s
		
		if is_instance_valid(controller.magic_essence_particles):
			controller.magic_essence_particles.initial_velocity_min = 0.05 + charge_ratio * 1.5
			controller.magic_essence_particles.initial_velocity_max = 0.2 + charge_ratio * 4.0
			controller.magic_essence_particles.radial_accel_min = charge_ratio * 5.0
			controller.magic_essence_particles.radial_accel_max = charge_ratio * 10.0
			controller.magic_essence_particles.scale_amount_max = 1.8 + charge_ratio * 2.0

@rpc("any_peer", "call_local", "reliable")
func release_fireball(target_pos: Vector3, mana_amount: float) -> void:
	if controller.charge_audio_player and controller.charge_audio_player.playing:
		var audio_tween = create_tween()
		audio_tween.tween_property(controller.charge_audio_player, "volume_db", -80.0, 1.0)
		audio_tween.tween_callback(func(): controller.charge_audio_player.stop())
		
	controller.play_anim("cast_fireball")
	if controller.get("state_machine") and is_instance_valid(controller.state_machine): controller.state_machine.change_state("cast")
	
	if is_instance_valid(controller.magic_essence_sphere):
		var tween = create_tween()
		tween.tween_property(controller.magic_essence_sphere, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		if is_instance_valid(controller.magic_essence_particles):
			controller.magic_essence_particles.initial_velocity_min = 0.05
			controller.magic_essence_particles.initial_velocity_max = 0.2
			controller.magic_essence_particles.radial_accel_min = 0.0
			controller.magic_essence_particles.radial_accel_max = 0.0
			controller.magic_essence_particles.scale_amount_max = 1.8
			
	# Delay fireball spawn to match animation peak
	await controller.get_tree().create_timer(0.3).timeout
		
	var start_pos = _get_spell_origin()
	if controller.multiplayer.is_server():
		create_fireball(start_pos, target_pos, mana_amount)
	
	# Delay fireball sound to 0.5s
	await controller.get_tree().create_timer(0.2).timeout
	controller.play_sound("res://sounds/fireball.wav", -10.0)

func create_fireball(start_pos: Vector3, target_pos: Vector3, mana_amount: float = 10.0) -> void:
	if not controller.multiplayer.is_server(): return
	var fireball = FIREBALL_SCENE.instantiate()
	fireball.direction = (target_pos - start_pos).normalized()
	fireball.damage = mana_amount * controller.damage_multiplier
	fireball.charge_mult = 1.0 + clamp((mana_amount - 10.0) / 90.0, 0.0, 1.0) * 3.0
	fireball.position = start_pos
	
	var main = controller.get_tree().root.get_node_or_null("Main")
	if main:
		var container = main.get_node_or_null("ProjectilesContainer")
		if not container:
			container = Node3D.new()
			container.name = "ProjectilesContainer"
			main.add_child(container)
			var spawner = MultiplayerSpawner.new()
			spawner.name = "ProjectilesSpawner"
			spawner.spawn_path = container.get_path()
			spawner.add_spawnable_scene("res://scenes/Fireball.tscn")
			main.add_child(spawner)
		container.add_child(fireball, true)
	else:
		controller.get_tree().root.add_child(fireball, true)

func create_shock_visual(start_pos: Vector3, end_pos: Vector3) -> void:
	var visual = SHOCK_VISUAL_SCENE.instantiate()
	controller.get_tree().root.add_child(visual)
	visual.setup(start_pos, end_pos)

func _update_spell_ui() -> void:
	if is_instance_valid(controller.player_hud):
		var cost = spell_costs.get(spells[current_spell], 0.0)
		controller.player_hud.update_spell(spells[current_spell], cost)
		
	if controller.right_hand_attachment and is_instance_valid(controller.magic_essence_particles):
		controller.magic_essence_particles.initial_velocity_min = 0.05
		controller.magic_essence_particles.initial_velocity_max = 0.2
		controller.magic_essence_particles.radial_accel_min = 0.0
		controller.magic_essence_particles.radial_accel_max = 0.0
		controller.magic_essence_particles.scale_amount_max = 1.8
		
		if is_instance_valid(controller.magic_essence_sphere):
			controller.magic_essence_sphere.scale = Vector3.ONE
			
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
			controller.magic_essence_particles.color_ramp = grad
			controller.magic_essence_particles.color = color
			
			if controller.magic_essence_particles.mesh and controller.magic_essence_particles.mesh.material:
				controller.magic_essence_particles.mesh.material.emission = color
			if controller.magic_essence_sphere and controller.magic_essence_sphere.mesh and controller.magic_essence_sphere.mesh.material:
				controller.magic_essence_sphere.mesh.material.albedo_color = Color.BLACK
				controller.magic_essence_sphere.mesh.material.emission = Color.BLACK
		else:
			grad.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
			grad.colors = PackedColorArray([Color.WHITE, color, Color(color.r, color.g, color.b, 0.0)])
			controller.magic_essence_particles.color_ramp = grad
			controller.magic_essence_particles.color = Color.WHITE
			
			if controller.magic_essence_particles.mesh and controller.magic_essence_particles.mesh.material:
				controller.magic_essence_particles.mesh.material.emission = Color.WHITE
			if controller.magic_essence_sphere and controller.magic_essence_sphere.mesh and controller.magic_essence_sphere.mesh.material:
				controller.magic_essence_sphere.mesh.material.albedo_color = color
				controller.magic_essence_sphere.mesh.material.emission = color
				
		if controller.magic_essence_light:
			controller.magic_essence_light.light_color = color

func add_mana(amount: float) -> void:
	if controller.is_multiplayer_authority():
		mana = min(mana + amount, max_mana)
		if is_instance_valid(controller.player_hud):
			controller.player_hud.update_mana(mana, max_mana)

@rpc("any_peer", "call_local", "reliable")
func fire_unsummon(target_pos: Vector3, hit_path: NodePath = NodePath()) -> void:
	start_magic_sphere_pulse()
	controller.play_anim("standing 1h magic attack 02")
	if controller.get("state_machine") and is_instance_valid(controller.state_machine): controller.state_machine.change_state("cast")
	await controller.get_tree().create_timer(0.5).timeout
	controller.play_sound("res://sounds/unsummon.wav", 5.0) # Play the unsummon sound effect
	if controller.multiplayer.is_server():
		var space_state = controller.get_world_3d().direct_space_state
		var from = controller.visuals.global_position + Vector3(0, 1.0, 0)
		var forward = -controller.visuals.global_transform.basis.z.normalized()
		
		# Large spherecast in front of the player
		var shape = SphereShape3D.new()
		shape.radius = 3.5
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(), from + forward * 3.5)
		query.collision_mask = 4 # Enemies
		query.exclude = [controller.get_rid()]
		
		var results = space_state.intersect_shape(query)
		for res in results:
			var hit_node = res.collider
			if hit_node and hit_node.has_method("take_damage"):
				var push_dir = -controller.visuals.global_transform.basis.z.normalized()
				push_dir.y = 0.02 # Reduced vertical lift by 5x
				push_dir = push_dir.normalized()
				
				# knockback_dir is multiplied by 10.0 in Enemy.gd, so 12.0 results in a 120.0 velocity horizontal push
				hit_node.take_damage(0.0, push_dir * 12.0)
				if hit_node.has_method("gain_aggro"):
					hit_node.gain_aggro(controller)
			
	await controller.get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self) or not is_instance_valid(controller): return
	var forward = -controller.visuals.global_transform.basis.z.normalized()
	var end_pos = _get_spell_origin() + forward * 10.0
	create_unsummon_visual(_get_spell_origin(), end_pos)
	stop_magic_sphere_pulse()

@rpc("any_peer", "call_local", "reliable")
func fire_drain_life(target_pos: Vector3, hit_path: NodePath = NodePath()) -> void:
	start_magic_sphere_pulse()
	controller.play_anim("cast_drain_life")
	if controller.get("state_machine") and is_instance_valid(controller.state_machine): controller.state_machine.change_state("cast")
	controller.play_sound("res://sounds/lifedrain.wav")
	
	# Wait 1 second before first damage tick and visual stream
	await controller.get_tree().create_timer(1.0).timeout
	
	create_drain_visual(_get_spell_origin(), target_pos, 1.5, hit_path)
	
	if controller.multiplayer.is_server() and not hit_path.is_empty():
		var hit_node = get_node_or_null(hit_path)
		
		var max_damage = 30.0 * controller.damage_multiplier
		var total_damage_dealt = 0.0
		var tick_damage = max_damage / 30.0 # 30 fast ticks to reach max damage
		
		# Deal continuous small damage until max is reached or animation ends
		while is_instance_valid(hit_node) and controller.current_animation == "cast_drain_life" and total_damage_dealt < max_damage:
			if hit_node.has_method("take_damage"):
				var dir = (hit_node.global_position - controller.global_position).normalized()
				# Very low knockback since we are hitting them 30 times rapidly
				hit_node.take_damage(tick_damage, dir * 0.05)
				controller.health_component.heal(tick_damage)
				total_damage_dealt += tick_damage
				if hit_node.has_method("gain_aggro"):
					hit_node.gain_aggro(controller)
			await controller.get_tree().create_timer(0.05).timeout
	
	stop_magic_sphere_pulse()

@rpc("any_peer", "call_local", "reliable")
func cast_giant_growth() -> void:
	start_magic_sphere_pulse()
	controller.play_anim("cast_giant_growth")
	if controller.get("state_machine") and is_instance_valid(controller.state_machine): controller.state_machine.change_state("cast")
	await controller.get_tree().create_timer(1.25).timeout
	
	controller.play_sound("res://sounds/giant-growth.wav")
	
	# Grow bigger over 0.5s
	stop_magic_sphere_pulse()
	is_giant_growth_active = true
	var tween = create_tween().set_parallel(true)
	tween.tween_property(controller, "scale", Vector3(2.0, 2.0, 2.0), 0.5)
	if is_instance_valid(controller.magic_essence_sphere) and controller.magic_essence_sphere.mesh and controller.magic_essence_sphere.mesh.material:
		tween.tween_property(controller.magic_essence_sphere.mesh.material, "albedo_color:a", 0.0, 0.5)
		tween.tween_property(controller.magic_essence_sphere.mesh.material, "emission_energy_multiplier", 0.0, 0.5)
	if is_instance_valid(controller.magic_essence_light):
		tween.tween_property(controller.magic_essence_light, "light_energy", 0.0, 0.5)
	if is_instance_valid(controller.magic_essence_particles):
		controller.magic_essence_particles.emitting = false
		
	controller.damage_multiplier = 3.0
	
	# Slow animations for heavy feel
	if controller.current_anim_player:
		controller.current_anim_player.speed_scale = 0.6
	
	# Boost health
	controller.health_component.set_max_health(controller.health_component.max_health + 50.0)
	controller.health_component.heal(50.0)
	
	create_growth_visual(controller.global_position)
	
	# Lasts 15 seconds
	await controller.get_tree().create_timer(15.0).timeout
	
	# Revert
	is_giant_growth_active = false
	var tween2 = create_tween().set_parallel(true)
	tween2.tween_property(controller, "scale", Vector3(1, 1, 1), 0.5)
	if is_instance_valid(controller.magic_essence_sphere) and controller.magic_essence_sphere.mesh and controller.magic_essence_sphere.mesh.material:
		tween2.tween_property(controller.magic_essence_sphere.mesh.material, "albedo_color:a", 1.0, 0.5)
		tween2.tween_property(controller.magic_essence_sphere.mesh.material, "emission_energy_multiplier", 5.0, 0.5)
	if is_instance_valid(controller.magic_essence_light):
		tween2.tween_property(controller.magic_essence_light, "light_energy", 1.0, 0.5)
	if is_instance_valid(controller.magic_essence_particles):
		controller.magic_essence_particles.emitting = true
		
	controller.damage_multiplier = 1.0
	controller.health_component.set_max_health(controller.health_component.max_health - 50.0)
	if controller.current_anim_player:
		controller.current_anim_player.speed_scale = 1.0

@rpc("any_peer", "call_local", "reliable")
func cast_heal() -> void:
	start_magic_sphere_pulse()
	controller.play_anim("cast_heal")
	if controller.get("state_machine") and is_instance_valid(controller.state_machine): controller.state_machine.change_state("cast")
	await controller.get_tree().create_timer(0.5).timeout
	
	controller.play_sound("res://sounds/heal1.wav")
	controller.health_component.heal(50.0)
	
	if controller.multiplayer.is_server():
		var base = controller.get_tree().root.get_node_or_null("Main/BaseCristal")
		if base and "health" in base and "max_health" in base:
			base.health = min(base.health + 50.0, base.max_health)
			
	create_heal_visual(controller.global_position)
	stop_magic_sphere_pulse()

func create_unsummon_visual(start_pos: Vector3, end_pos: Vector3) -> void:
	var visual = UNSUMMON_VISUAL_SCENE.instantiate()
	controller.get_tree().root.add_child(visual)
	visual.global_position = start_pos
	var up = Vector3.UP
	if abs((end_pos - start_pos).normalized().y) > 0.99: up = Vector3.RIGHT
	visual.look_at(end_pos, up)

func create_drain_visual(start_pos: Vector3, end_pos: Vector3, duration: float = 2.35, hit_path: NodePath = NodePath()) -> void:
	var visual = DRAIN_VISUAL_SCENE.instantiate()
	controller.get_tree().root.add_child(visual)
	visual.setup(start_pos, end_pos, duration, hit_path)
	active_drain_visuals.append({
		"particles": visual.particles,
		"hit_path": hit_path,
		"target_pos": end_pos
	})

func create_growth_visual(pos: Vector3) -> void:
	var visual = GROWTH_VISUAL_SCENE.instantiate()
	controller.get_tree().root.add_child(visual)
	visual.setup(pos)

func create_heal_visual(pos: Vector3) -> void:
	var visual = HEAL_VISUAL_SCENE.instantiate()
	controller.get_tree().root.add_child(visual)
	visual.setup(pos)
