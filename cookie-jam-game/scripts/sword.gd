extends Marker2D

@export var swing_duration = 0.16
@export var recovery_duration = 0.05
@export var swing_arc_degrees = 125.0
@export var maximum_swing_arc = 200.0
@export var weapon_tip_distance = 90.0
@export var trail_width = 14.0
@export var trail_lifetime = 0.14
@export var weapon_angle_offset_degrees = 90.0

var attacking = false
var recovering = false
var swing_progress = 0.0
var recovery_timer = 0.0
var attack_direction = 0.0
var swing_direction = 1.0
var original_scale = Vector2.ONE
var trail
var trail_points = []
var trail_ages = []
var hit_enemies = {}
var weapon_areas = []
var weapon_shapes = []
var last_swing_angle = 0.0
var weapon_tip_local = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	visible = false
	original_scale = scale
	weapon_tip_local = _find_weapon_tip()
	weapon_areas = find_children("*", "Area2D", true, false)
	for area in weapon_areas:
		for shape in area.find_children("*", "CollisionShape2D", true, false):
			weapon_shapes.append(shape)
	trail = Line2D.new()
	trail.width = trail_width
	trail.default_color = Color(1.0, 0.9, 0.5, 0.95)
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.antialiased = true
	trail.top_level = true
	trail.z_as_relative = false
	trail.z_index = 100
	trail.position = Vector2.ZERO
	get_parent().add_child.call_deferred(trail)


func _exit_tree() -> void:
	if is_instance_valid(trail) and !trail.is_queued_for_deletion():
		trail.queue_free()


func _physics_process(delta: float) -> void:
	_update_trail(delta)
	if !Global.gameplay_started or Global.player_health <= 0.0:
		attacking = false
		recovering = false
		visible = false
		return
	if attacking:
		_update_attack(delta)
		return
	if recovering:
		recovery_timer -= delta
		if recovery_timer <= 0.0:
			recovering = false
	if !recovering:
		_start_attack()


func _start_attack() -> void:
	attacking = true
	swing_progress = 0.0
	visible = true
	attack_direction = global_position.angle_to_point(get_global_mouse_position())
	swing_direction *= -1.0
	hit_enemies.clear()
	trail_points.clear()
	trail_ages.clear()
	_rebuild_trail()
	var arc = min(swing_arc_degrees + Global.swing_arc_bonus, maximum_swing_arc)
	last_swing_angle = attack_direction - deg_to_rad(arc) * 0.5 * swing_direction
	global_rotation = last_swing_angle + deg_to_rad(weapon_angle_offset_degrees)
	scale = original_scale * min(Global.sword_size_multiplier, Global.sword_size_max)
	_add_trail_point(last_swing_angle)
	_damage_overlaps()


func _update_attack(delta: float) -> void:
	var duration = max(swing_duration / max(Global.attack_speed_multiplier, 0.1), 0.045)
	swing_progress = min(swing_progress + delta / duration, 1.0)
	var arc = min(swing_arc_degrees + Global.swing_arc_bonus, maximum_swing_arc)
	var half_arc = deg_to_rad(arc) * 0.5
	var start_angle = attack_direction - half_arc * swing_direction
	var end_angle = attack_direction + half_arc * swing_direction
	var swing_angle = lerp(start_angle, end_angle, _ease_out_quart(swing_progress))
	var punch = sin(swing_progress * PI)
	var size_multiplier = min(Global.sword_size_multiplier, Global.sword_size_max)
	scale = original_scale * size_multiplier * Vector2(1.0 + punch * 0.05, 1.0 + punch * 0.10)
	var samples = maxi(int(ceil(abs(swing_angle - last_swing_angle) / deg_to_rad(7.0))), 1)
	var previous_angle = last_swing_angle
	for i in range(1, samples + 1):
		var sample_angle = lerp(previous_angle, swing_angle, float(i) / float(samples))
		global_rotation = sample_angle + deg_to_rad(weapon_angle_offset_degrees)
		_damage_overlaps()
		_add_trail_point(sample_angle)
	last_swing_angle = swing_angle
	if swing_progress >= 1.0:
		_finish_attack()


func try_hit_enemy(enemy: Node2D) -> void:
	
	if !attacking or !Global.gameplay_started or !is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	if !enemy.is_in_group("enemy") or !enemy.has_method("take_damage"):
		return
	var enemy_id = enemy.get_instance_id()
	if hit_enemies.has(enemy_id):
		return
	hit_enemies[enemy_id] = true
	var critical = randf() < Global.sword_crit_chance
	var amount = Global.weapon_damage * (Global.sword_crit_multiplier if critical else 1.0)
	enemy.take_damage(amount, global_position, Global.sword_knockback_multiplier, critical)


func _damage_overlaps() -> void:
	var space = get_world_2d().direct_space_state
	for shape in weapon_shapes:
		if !is_instance_valid(shape) or shape.disabled or shape.shape == null:
			continue
		var query = PhysicsShapeQueryParameters2D.new()
		query.shape = shape.shape
		query.transform = shape.global_transform
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.collision_mask = 0xFFFFFFFF
		for result in space.intersect_shape(query, 256):
			_hit_collider(result["collider"])
	if weapon_shapes.is_empty():
		for area in weapon_areas:
			if !is_instance_valid(area) or !area.monitoring:
				continue
			for body in area.get_overlapping_bodies():
				_hit_collider(body)
			for other_area in area.get_overlapping_areas():
				_hit_collider(other_area)


func _hit_collider(collider: Object) -> void:
	if !(collider is Node):
		return
	var candidate = collider
	while is_instance_valid(candidate):
		if candidate is Node2D and candidate.is_in_group("enemy"):
			try_hit_enemy(candidate)
			return
		candidate = candidate.get_parent()


func _finish_attack() -> void:
	attacking = false
	recovering = true
	recovery_timer = max(recovery_duration / max(Global.attack_speed_multiplier, 0.1), 0.015)
	visible = false
	scale = original_scale * min(Global.sword_size_multiplier, Global.sword_size_max)


func _find_weapon_tip() -> Vector2:
	var blade_direction = Vector2.from_angle(-deg_to_rad(weapon_angle_offset_degrees))
	var best_tip = blade_direction * weapon_tip_distance
	var best_distance = -INF
	var visuals = find_children("*", "Sprite2D", true, false)
	visuals.append_array(find_children("*", "AnimatedSprite2D", true, false))
	for visual in visuals:
		var rect = Rect2()
		if visual is Sprite2D:
			if visual.texture == null:
				continue
			rect = visual.get_rect()
		elif visual is AnimatedSprite2D:
			if visual.sprite_frames == null or !visual.sprite_frames.has_animation(visual.animation):
				continue
			var frame_count = visual.sprite_frames.get_frame_count(visual.animation)
			if frame_count <= 0:
				continue
			var texture = visual.sprite_frames.get_frame_texture(visual.animation, clampi(visual.frame, 0, frame_count - 1))
			if texture == null:
				continue
			var frame_size = texture.get_size()
			rect = Rect2(visual.offset - (frame_size * 0.5 if visual.centered else Vector2.ZERO), frame_size)
		var corners = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		var local_transform = global_transform.affine_inverse() * visual.global_transform
		var outer_points = []
		var outer_distance = -INF
		for corner in corners:
			var point = local_transform * corner
			var distance = point.dot(blade_direction)
			if distance > outer_distance + 0.01:
				outer_distance = distance
				outer_points = [point]
			elif abs(distance - outer_distance) <= 0.01:
				outer_points.append(point)
		if outer_distance > best_distance:
			best_distance = outer_distance
			best_tip = Vector2.ZERO
			for point in outer_points:
				best_tip += point
			best_tip /= float(outer_points.size())
	return best_tip


func _add_trail_point(_swing_angle: float) -> void:
	if !is_instance_valid(trail):
		return
	trail_points.append(to_global(weapon_tip_local))
	trail_ages.append(0.0)
	if trail_points.size() > 64:
		trail_points.pop_front()
		trail_ages.pop_front()
	_rebuild_trail()


func _update_trail(delta: float) -> void:
	for i in range(trail_ages.size() - 1, -1, -1):
		trail_ages[i] += delta
		if trail_ages[i] >= max(trail_lifetime, 0.01):
			trail_ages.remove_at(i)
			trail_points.remove_at(i)
	_rebuild_trail()


func _rebuild_trail() -> void:
	if !is_instance_valid(trail):
		return
	trail.clear_points()
	if trail_points.size() < 2:
		return
	for point in trail_points:
		trail.add_point(trail.to_local(point))
	var fade = clamp(1.0 - trail_ages[-1] / max(trail_lifetime, 0.01), 0.0, 1.0)
	trail.modulate.a = fade
	trail.width = max(trail_width * fade, 2.0)


func _ease_out_quart(value: float) -> float:
	return 1.0 - pow(1.0 - value, 4.0)
