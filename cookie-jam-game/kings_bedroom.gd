extends Node2D

const ASSASSIN_SCENE = preload("res://scenes/assasin.tscn")
const KEY_TEXTURE = preload("res://assets/key.svg")

@export var minimum_spawn_distance = 650.0
@export var maximum_spawn_distance = 1100.0
@export var max_spawn_attempts = 50
@export var starting_spawn_interval = 1.25
@export var minimum_spawn_interval = 0.55
@export var spawn_interval_step = 0.07
@export var spawn_interval_step_time = 45.0
@export var wave_size_step_time = 90.0
@export var maximum_wave_size = 5
@export var starting_enemy_cap = 35
@export var enemy_cap_step = 8
@export var enemy_cap_step_time = 45.0
@export var maximum_enemy_cap = 160
@export var pressure_cycle_duration = 50.0
@export var breather_duration = 8.0
@export var boss_arrival_time = 180.0
@export var boss_reinforcement_cap = 10

var spawn_timer
var spawn_cells = []
var spawning_started = false
var boss_spawned = false
var boss_defeated = false
var key_collected = false
var boss_node = null
var key_node = null
var key_sprite
var key_age = 0.0
var previous_player_position = Vector2.ZERO
var tracking_player = null
var stage_hud
var objective_label
var boss_label
var boss_bar
var key_marker


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 120
	add_to_group("enemy_spawner_controller")
	spawn_cells = $TileMapLayer.get_used_cells()
	spawn_timer = Timer.new()
	spawn_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	spawn_timer.one_shot = true
	spawn_timer.autostart = false
	spawn_timer.wait_time = max(starting_spawn_interval, 0.1)
	spawn_timer.timeout.connect(_spawn_wave)
	add_child(spawn_timer)
	_create_stage_hud()


func start_spawning() -> void:
	if spawning_started or boss_spawned or boss_defeated or !Global.gameplay_started:
		return
	spawning_started = true
	spawn_cells = $TileMapLayer.get_used_cells()
	stage_hud.visible = true
	spawn_timer.start(_get_spawn_interval())


func stop_spawning() -> void:
	spawning_started = false
	if is_instance_valid(spawn_timer):
		spawn_timer.stop()


func _spawn_wave() -> void:
	if !spawning_started or boss_spawned or boss_defeated or !Global.gameplay_started:
		return
	if Global.run_time >= boss_arrival_time:
		_try_spawn_boss()
		if !boss_spawned:
			spawn_timer.start(1.0)
		return
	spawn_timer.start(_get_spawn_interval())
	if get_tree().paused or is_breather_active():
		return
	var enemy_count = get_tree().get_nodes_in_group("enemy").size()
	var available_slots = _get_max_enemies() - enemy_count
	for i in range(mini(_get_spawn_amount(), available_slots)):
		_spawn_enemy()


func is_breather_active() -> bool:
	if breather_duration <= 0.0 or pressure_cycle_duration <= breather_duration:
		return false
	return fmod(Global.run_time, pressure_cycle_duration) >= pressure_cycle_duration - breather_duration


func _get_spawn_interval() -> float:
	var steps = int(Global.run_time / max(spawn_interval_step_time, 1.0))
	var interval = max(starting_spawn_interval - float(steps) * spawn_interval_step, minimum_spawn_interval)
	if Global.run_time < 12.0:
		interval *= 1.15
	return max(interval, 0.1)


func _get_spawn_amount() -> int:
	var amount = 1 + int(Global.run_time / max(wave_size_step_time, 1.0))
	if Global.run_time >= 60.0 and pressure_cycle_duration > 0.0:
		var phase = fmod(Global.run_time, pressure_cycle_duration)
		if phase >= 25.0 and phase < 35.0:
			amount += 1
	return clampi(amount, 1, maxi(maximum_wave_size, 1))


func _get_max_enemies() -> int:
	var steps = int(Global.run_time / max(enemy_cap_step_time, 1.0))
	return clampi(starting_enemy_cap + steps * enemy_cap_step, 0, maxi(maximum_enemy_cap, 0))


func _spawn_enemy(animation_name: String = "") -> void:
	if !Global.gameplay_started or get_tree().paused or boss_defeated:
		return
	var spawn_position = _find_spawn_position()
	if spawn_position == null:
		return
	var enemy = ASSASSIN_SCENE.instantiate()
	enemy.enemy_level = Global.roll_enemy_level()
	enemy.enemy_animation = animation_name if !animation_name.is_empty() else _roll_enemy_animation()
	enemy.position = get_parent().to_local(spawn_position) if get_parent() is Node2D else spawn_position
	get_parent().add_child(enemy)


func _roll_enemy_animation() -> String:
	var pool = ["goblin assasin", "goblin assasin", "goblin assasin", "goblin assasin", "goblin assasin"]
	if Global.run_time >= 25.0:
		pool.append_array(["stabby", "stabby"])
	if Global.run_time >= 50.0:
		pool.append_array(["dart goblin", "dart goblin"])
	if Global.run_time >= 75.0:
		pool.append_array(["ork", "ork"])
	if Global.run_time >= 100.0:
		pool.append_array(["spear goblin", "spear goblin"])
	return str(pool.pick_random())


func _try_spawn_boss() -> void:
	if boss_spawned or boss_defeated or !Global.gameplay_started:
		return
	var spawn_position = _find_boss_spawn_position()
	if spawn_position == null:
		objective_label.text = "Grunkk is approaching. Keep protecting the king!"
		return
	boss_node = ASSASSIN_SCENE.instantiate()
	boss_node.enemy_animation = "grunkk"
	boss_node.enemy_level = Global.get_current_enemy_level()
	boss_node.position = get_parent().to_local(spawn_position) if get_parent() is Node2D else spawn_position
	boss_spawned = true
	get_parent().add_child(boss_node)
	stop_spawning()
	boss_label.visible = true
	boss_bar.visible = true


func _find_boss_spawn_position():
	var normal_position = _find_spawn_position()
	if normal_position != null:
		return normal_position
	if !is_instance_valid(Global.player_node):
		return null
	var best = null
	var best_distance = 200.0
	for cell in spawn_cells:
		var point = $TileMapLayer.to_global($TileMapLayer.map_to_local(cell))
		var distance = point.distance_to(Global.player_node.global_position)
		if is_instance_valid(Global.king_node):
			distance = min(distance, point.distance_to(Global.king_node.global_position))
		if distance > best_distance and is_walkable_position(point):
			best_distance = distance
			best = point
	return best


func spawn_boss_reinforcements(_boss_position: Vector2, amount: int) -> void:
	if !boss_spawned or boss_defeated or !Global.gameplay_started:
		return
	var current = get_tree().get_nodes_in_group("enemy").size() - 1
	for i in range(mini(amount, maxi(boss_reinforcement_cap - current, 0))):
		_spawn_enemy("stabby" if randf() < 0.35 else "goblin assasin")


func on_stage_boss_defeated(where: Vector2) -> void:
	if boss_defeated or !boss_spawned:
		return
	boss_defeated = true
	stop_spawning()
	boss_node = null
	boss_label.visible = false
	boss_bar.visible = false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.queue_free()
	get_tree().call_group("enemy_dart", "queue_free")
	_create_key(_find_key_position(where))


func _find_key_position(where: Vector2) -> Vector2:
	if is_walkable_position(where):
		return where
	var best = Global.player_node.global_position if is_instance_valid(Global.player_node) else where
	var best_distance = INF
	for cell in spawn_cells:
		var point = $TileMapLayer.to_global($TileMapLayer.map_to_local(cell))
		var distance = point.distance_squared_to(where)
		if distance < best_distance and is_walkable_position(point):
			best_distance = distance
			best = point
	return best


func _create_key(where: Vector2) -> void:
	key_node = Node2D.new()
	key_node.top_level = true
	key_node.process_mode = Node.PROCESS_MODE_PAUSABLE
	key_node.z_index = 40
	get_parent().add_child(key_node)
	key_node.global_position = where
	key_sprite = Sprite2D.new()
	key_sprite.texture = KEY_TEXTURE
	key_sprite.scale = Vector2.ONE * 52.0 / max(KEY_TEXTURE.get_size().x, KEY_TEXTURE.get_size().y)
	key_node.add_child(key_sprite)
	var label = Label.new()
	label.text = "CASTLE KEY"
	label.position = Vector2(-70.0, -48.0)
	label.size = Vector2(140.0, 25.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	key_node.add_child(label)
	key_age = 0.0
	tracking_player = null


func _physics_process(delta: float) -> void:
	if !Global.gameplay_started or Global.player_health <= 0.0 or Global.king_health <= 0.0:
		return
	_update_stage_hud()
	if spawning_started and !boss_spawned and Global.run_time >= boss_arrival_time:
		_try_spawn_boss()
	if !is_instance_valid(key_node) or key_collected or !is_instance_valid(Global.player_node):
		return
	key_age += delta
	key_sprite.position.y = sin(key_age * 4.0) * 5.0
	var player_position = Global.player_node.global_position
	if tracking_player != Global.player_node:
		tracking_player = Global.player_node
		previous_player_position = player_position
	var closest = Geometry2D.get_closest_point_to_segment(key_node.global_position, previous_player_position, player_position)
	previous_player_position = player_position
	if key_age < 0.5:
		return
	if closest.distance_to(key_node.global_position) <= 55.0 or _key_touches_player():
		_collect_key()
		return
	if key_node.global_position.distance_to(player_position) <= 280.0 * Global.pickup_range_multiplier:
		var attraction_speed = 850.0
		if Global.player_node is CharacterBody2D:
			attraction_speed = max(attraction_speed, Global.player_node.velocity.length() + 200.0)
		key_node.global_position = key_node.global_position.move_toward(player_position, attraction_speed * delta)
		if key_node.global_position.distance_to(player_position) <= 55.0 or _key_touches_player():
			_collect_key()


func _key_touches_player() -> bool:
	var player = Global.player_node
	if !(player is CollisionObject2D):
		return false
	var shape = CircleShape2D.new()
	shape.radius = 45.0
	for owner_id in player.get_shape_owners():
		if player.is_shape_owner_disabled(owner_id):
			continue
		var transform = player.global_transform * player.shape_owner_get_transform(owner_id)
		for i in range(player.shape_owner_get_shape_count(owner_id)):
			var body_shape = player.shape_owner_get_shape(owner_id, i)
			if body_shape != null and shape.collide(Transform2D(0.0, key_node.global_position), body_shape, transform):
				return true
	return false


func _collect_key() -> void:
	if key_collected or !boss_defeated or !Global.gameplay_started or Global.player_health <= 0.0 or Global.king_health <= 0.0:
		return
	key_collected = true
	if is_instance_valid(key_node):
		key_node.queue_free()
	key_marker.visible = false
	get_tree().call_group("stage_end_controller", "complete_stage_one")


func _create_stage_hud() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 92
	add_child(layer)
	stage_hud = Control.new()
	layer.add_child(stage_hud)
	stage_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_hud.add_to_group("xp_hud")
	var box = VBoxContainer.new()
	stage_hud.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = 90.0
	box.offset_left = 20.0
	box.offset_right = -20.0
	box.add_theme_constant_override("separation", 5)
	objective_label = Label.new()
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 17)
	objective_label.add_theme_color_override("font_outline_color", Color.BLACK)
	objective_label.add_theme_constant_override("outline_size", 4)
	box.add_child(objective_label)
	boss_label = Label.new()
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 20)
	boss_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))
	boss_label.add_theme_color_override("font_outline_color", Color.BLACK)
	boss_label.add_theme_constant_override("outline_size", 4)
	box.add_child(boss_label)
	var center = CenterContainer.new()
	box.add_child(center)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(min(500.0, max(get_viewport_rect().size.x - 40.0, 100.0)), 18.0)
	boss_bar.show_percentage = false
	center.add_child(boss_bar)
	key_marker = Label.new()
	key_marker.text = "KEY"
	key_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_marker.add_theme_font_size_override("font_size", 20)
	key_marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	key_marker.add_theme_color_override("font_outline_color", Color.BLACK)
	key_marker.add_theme_constant_override("outline_size", 4)
	stage_hud.add_child(key_marker)
	boss_label.visible = false
	boss_bar.visible = false
	key_marker.visible = false
	stage_hud.visible = Global.gameplay_started
	_update_stage_hud()


func _update_stage_hud() -> void:
	if boss_defeated:
		objective_label.text = "Grunkk defeated! Collect the castle key."
	elif is_instance_valid(boss_node):
		objective_label.text = "Defeat Grunkk and take his castle key."
		boss_label.text = "GRUNKK - THE DUKE'S HEADSMAN" + ("  |  ENRAGED" if boss_node.boss_enraged else "")
		boss_bar.max_value = boss_node.max_health
		boss_bar.value = boss_node.health
	else:
		var remaining = maxi(int(ceil(boss_arrival_time - Global.run_time)), 0)
		objective_label.text = ""
	key_marker.visible = false
	var tracked = key_node if is_instance_valid(key_node) and !key_collected else boss_node
	if is_instance_valid(tracked):
		key_marker.text = "KEY" if tracked == key_node else "GRUNKK"
		var screen_point = get_viewport().get_canvas_transform() * tracked.global_position
		var viewport_size = get_viewport_rect().size
		var bounds = Rect2(Vector2(35.0, 160.0), Vector2(max(viewport_size.x - 105.0, 1.0), max(viewport_size.y - 260.0, 1.0)))
		if !bounds.has_point(screen_point):
			key_marker.position = Vector2(clamp(screen_point.x, bounds.position.x, bounds.end.x), clamp(screen_point.y, bounds.position.y, bounds.end.y))
			key_marker.visible = true


func _find_spawn_position():
	if spawn_cells.is_empty() or !is_instance_valid(Global.player_node):
		return null
	var anchor = Global.player_node.global_position
	if is_instance_valid(Global.king_node) and randf() < 0.3:
		anchor = Global.king_node.global_position
	var first_index = randi_range(0, spawn_cells.size() - 1)
	for i in range(maxi(max_spawn_attempts, 1)):
		var cell = spawn_cells.pick_random()
		var candidate = $TileMapLayer.to_global($TileMapLayer.map_to_local(cell))
		if _is_safe_enemy_position(candidate, anchor, maximum_spawn_distance):
			return candidate
	for i in range(spawn_cells.size()):
		var cell = spawn_cells[(first_index + i) % spawn_cells.size()]
		var candidate = $TileMapLayer.to_global($TileMapLayer.map_to_local(cell))
		if _is_safe_enemy_position(candidate, anchor, maximum_spawn_distance * 1.5):
			return candidate
	return null


func _is_safe_enemy_position(candidate: Vector2, anchor: Vector2, maximum_distance: float) -> bool:
	var safe_distance = max(minimum_spawn_distance, 0.0)
	if candidate.distance_to(anchor) > max(maximum_distance, safe_distance):
		return false
	if candidate.distance_to(Global.player_node.global_position) < safe_distance:
		return false
	if is_instance_valid(Global.king_node):
		if candidate.distance_to(Global.king_node.global_position) < safe_distance:
			return false
	return is_walkable_position(candidate)


func is_walkable_position(world_position: Vector2) -> bool:
	var cell = $TileMapLayer.local_to_map($TileMapLayer.to_local(world_position))
	if $TileMapLayer.get_cell_source_id(cell) < 0:
		return false
	if !is_instance_valid(Global.player_node) or !(Global.player_node is CollisionObject2D):
		return true
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 16.0
	query.shape = shape
	query.transform = Transform2D(0.0, world_position)
	query.collision_mask = Global.player_node.collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excluded: Array[RID] = [Global.player_node.get_rid()]
	if is_instance_valid(Global.king_node) and Global.king_node is CollisionObject2D:
		excluded.append(Global.king_node.get_rid())
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is CollisionObject2D:
			excluded.append(enemy.get_rid())
	query.exclude = excluded
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
