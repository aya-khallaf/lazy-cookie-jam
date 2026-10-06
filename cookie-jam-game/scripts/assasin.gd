extends CharacterBody2D

const XP_ORB_SCRIPT = preload("res://scripts/xp_orb.gd")
const HEART_SCRIPT = preload("res://scripts/heart.gd")
const DART_TEXTURE = preload("res://assets/dart.svg")
const ANIMATIONS = ["goblin assasin", "stabby", "ork", "spear goblin", "dart goblin", "grunkk"]
const ENEMY_NAMES = ["Goblin Assassin", "Stabby", "Ork", "Spear Goblin", "Dart Goblin", "Grunkk"]

@export var enemy_level = 1
@export var base_speed = 125.0
@export var base_damage = 12.0
@export var base_health = 100.0
@export var base_xp_drop = 5.0
@export var health_multiplier_per_level = 1.10
@export var damage_multiplier_per_level = 1.055
@export var speed_multiplier_per_level = 1.0125
@export var xp_multiplier_per_level = 1.09
@export var maximum_speed = 190.0
@export var heart_drop_chance = 0.06
@export var knockback_speed = 450.0
@export var knockback_deceleration = 1400.0
@export var show_level_label = true
@export var enemy_role = -1
@export var enemy_animation = ""
@export var dart_angle_offset_degrees = 0.0

var speed = 125.0
var damage = 12.0
var max_health = 100.0
var health = 100.0
var xp_drop = 5.0
var touching_player = false
var touching_king = false
var can_attack = true
var knockback = false
var knockback_velocity = Vector2.ZERO
var dead = false
var level_label
var visual = null
var visual_color = Color.WHITE
var flash_timer = 0.0
var separation = Vector2.ZERO
var separation_timer = 0.0
var charge_cooldown = 2.0
var charge_windup = 0.0
var charge_time = 0.0
var charge_direction = Vector2.RIGHT
var charge_distance = 300.0
var attack_kind = ""
var attack_duration = 1.0
var attack_origin = Vector2.ZERO
var attack_point = Vector2.ZERO
var attack_radius = 140.0
var recovery_time = 0.0
var attack_hit_ids = {}
var boss_enraged = false
var reinforcement_timer = 12.0
var boss_attack_index = 0
var arrival_time = 0.45


class Dart:
	extends Node2D

	var direction = Vector2.RIGHT
	var speed = 470.0
	var damage = 12.0
	var lifetime = 4.0
	var remaining_distance = 650.0
	var texture
	var angle_offset = 0.0
	var excluded: Array[RID] = []
	var collision_mask = 1
	var hit_shape = CircleShape2D.new()
	var previous_targets = {}

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		process_physics_priority = 110
		top_level = true
		z_index = 35
		add_to_group("enemy_dart")
		hit_shape.radius = 7.0
		var sprite = Sprite2D.new()
		sprite.texture = texture
		if texture != null:
			sprite.scale = Vector2.ONE * 52.0 / max(texture.get_size().x, texture.get_size().y)
		add_child(sprite)
		rotation = direction.angle() + angle_offset
		for actor in [Global.player_node, Global.king_node]:
			if is_instance_valid(actor) and actor is CollisionObject2D:
				previous_targets[actor.get_instance_id()] = actor.global_position
				excluded.append(actor.get_rid())
				collision_mask |= actor.collision_mask
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy is CollisionObject2D:
				excluded.append(enemy.get_rid())

	func _physics_process(delta: float) -> void:
		if !Global.gameplay_started or Global.player_health <= 0.0 or Global.king_health <= 0.0:
			queue_free()
			return
		lifetime -= delta
		var start = global_position
		var travel = min(speed * delta, remaining_distance)
		remaining_distance -= travel
		var end = start + direction * travel
		var query = PhysicsRayQueryParameters2D.create(start, end, collision_mask, excluded)
		var wall = get_world_2d().direct_space_state.intersect_ray(query)
		var travel_fraction = 1.0
		if !wall.is_empty():
			travel_fraction = start.distance_to(wall["position"]) / max(start.distance_to(end), 0.001)
		var samples = maxi(int(ceil(start.distance_to(end) / 8.0)), 1)
		for i in range(samples + 1):
			var fraction = float(i) / float(samples)
			if fraction > travel_fraction:
				break
			var point = start.lerp(end, fraction)
			for actor in [Global.player_node, Global.king_node]:
				if !is_instance_valid(actor) or !(actor is CollisionObject2D):
					continue
				var previous = previous_targets.get(actor.get_instance_id(), actor.global_position)
				var motion_offset = previous.lerp(actor.global_position, fraction) - actor.global_position
				if _touches_actor(actor, point, motion_offset):
					if actor == Global.player_node:
						Global.damage_player(damage)
					else:
						Global.damage_king(damage)
					queue_free()
					return
		global_position = start.lerp(end, travel_fraction)
		for actor in [Global.player_node, Global.king_node]:
			if is_instance_valid(actor):
				previous_targets[actor.get_instance_id()] = actor.global_position
		if !wall.is_empty() or lifetime <= 0.0 or remaining_distance <= 0.0:
			queue_free()

	func _touches_actor(actor: CollisionObject2D, point: Vector2, motion_offset: Vector2) -> bool:
		for owner_id in actor.get_shape_owners():
			if actor.is_shape_owner_disabled(owner_id):
				continue
			var transform = actor.global_transform * actor.shape_owner_get_transform(owner_id)
			transform.origin += motion_offset
			for i in range(actor.shape_owner_get_shape_count(owner_id)):
				var shape = actor.shape_owner_get_shape(owner_id, i)
				if shape != null and hit_shape.collide(Transform2D(0.0, point), shape, transform):
					return true
		return false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("enemy")
	_choose_role()
	_apply_level_stats()
	separation_timer = randf_range(0.0, 0.18)
	charge_cooldown = randf_range(1.0, 2.5)
	for sprite in find_children("*", "AnimatedSprite2D", true, false):
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(ANIMATIONS[enemy_role]):
			visual = sprite
			visual.play(ANIMATIONS[enemy_role])
			break
	if !is_instance_valid(visual):
		push_error("Enemy AnimatedSprite2D is missing animation: " + ANIMATIONS[enemy_role])
	else:
		visual_color = visual.modulate
	if enemy_role == 5:
		add_to_group("stage_boss")
		charge_cooldown = 2.0
	if show_level_label or enemy_role == 5:
		_create_level_label()
	$ProgressBar.max_value = max_health
	$ProgressBar.value = health


func _choose_role() -> void:
	if ANIMATIONS.has(enemy_animation):
		enemy_role = ANIMATIONS.find(enemy_animation)
	elif enemy_role >= 0:
		enemy_role = clampi(enemy_role, 0, 5)
	else:
		enemy_role = 0
	enemy_animation = ANIMATIONS[enemy_role]


func _apply_level_stats() -> void:
	enemy_level = maxi(enemy_level, 1)
	var levels = enemy_level - 1
	max_health = base_health * pow(health_multiplier_per_level, levels)
	damage = base_damage * pow(damage_multiplier_per_level, levels)
	speed = min(base_speed * pow(speed_multiplier_per_level, levels), maximum_speed)
	xp_drop = base_xp_drop * pow(xp_multiplier_per_level, levels)
	match enemy_role:
		1:
			max_health *= 0.75
			damage *= 0.85
			speed *= 1.3
		2:
			max_health *= 2.0
			damage *= 1.35
			speed *= 0.7
			xp_drop *= 1.7
		3:
			max_health *= 1.15
			speed *= 0.95
			xp_drop *= 1.25
		4:
			max_health *= 0.85
			damage *= 0.85
			speed *= 0.8
			xp_drop *= 1.3
		5:
			max_health = max(max_health * 24.0, Global.weapon_damage * 55.0)
			damage *= 1.6
			speed *= 0.75
	max_health = max(round(max_health), 1.0)
	damage = max(round(damage), 1.0)
	speed = max(round(speed), 1.0)
	xp_drop = max(round(xp_drop), 1.0)
	health = max_health


func _create_level_label() -> void:
	level_label = Label.new()
	level_label.text = "%s | Lv. %d" % [ENEMY_NAMES[enemy_role], enemy_level]
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_outline_color", Color.BLACK)
	level_label.add_theme_constant_override("outline_size", 3)
	$ProgressBar.add_child(level_label)
	level_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_left = -90.0
	level_label.offset_right = 90.0
	level_label.offset_top = -24.0
	level_label.offset_bottom = -2.0


func _physics_process(delta: float) -> void:
	if dead or !Global.gameplay_started or Global.player_health <= 0.0 or Global.king_health <= 0.0:
		return
	if health <= 0.0:
		_die()
		return
	flash_timer = max(flash_timer - delta, 0.0)
	arrival_time = max(arrival_time - delta, 0.0)
	if is_instance_valid(visual):
		visual.modulate = Color(2.0, 2.0, 2.0) if flash_timer > 0.0 else visual_color
		visual.modulate.a *= clamp(1.0 - arrival_time / 0.45, 0.25, 1.0)
	$ProgressBar.value = health
	charge_cooldown = max(charge_cooldown - delta, 0.0)
	recovery_time = max(recovery_time - delta, 0.0)
	if enemy_role == 5:
		_update_boss_phase(delta)
	if arrival_time > 0.0:
		velocity = Vector2.ZERO
	elif knockback:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_deceleration * delta)
		if knockback_velocity.length_squared() < 25.0:
			knockback = false
	elif charge_windup > 0.0:
		velocity = Vector2.ZERO
		charge_windup = max(charge_windup - delta, 0.0)
		if charge_windup <= 0.0:
			_release_attack()
	elif charge_time > 0.0:
		var previous = global_position
		var charge_speed = 520.0 if enemy_role == 5 else 430.0
		charge_time = max(charge_time - delta, 0.0)
		velocity = charge_direction * charge_speed
		move_and_slide()
		_damage_charge(previous, global_position)
		if is_on_wall() or charge_time <= 0.0:
			charge_time = 0.0
			recovery_time = 0.75 if enemy_role == 5 else 0.35
		queue_redraw()
		return
	elif recovery_time > 0.0:
		velocity = Vector2.ZERO
	else:
		if enemy_role <= 1:
			_handle_attack()
		_chase_target()
		if charge_windup <= 0.0 and velocity.length_squared() > 1.0:
			_update_separation(delta)
			velocity = (velocity + separation * speed * 0.65).limit_length(speed)
	move_and_slide()
	queue_redraw()


func _update_separation(delta: float) -> void:
	separation_timer -= delta
	if separation_timer > 0.0:
		return
	separation_timer = 0.18
	separation = Vector2.ZERO
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self or !(enemy is Node2D) or !is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var offset = global_position - enemy.global_position
		var distance_squared = offset.length_squared()
		if distance_squared > 0.01 and distance_squared < 2304.0:
			var distance = sqrt(distance_squared)
			separation += offset / distance * (1.0 - distance / 48.0)
	separation = separation.limit_length(1.0)


func _handle_attack() -> void:
	if !can_attack:
		return
	var hit = false
	if touching_king:
		hit = Global.damage_king(damage)
	elif touching_player:
		hit = Global.damage_player(damage)
	if hit:
		can_attack = false
		$hit_timer.start()


func _chase_target() -> void:
	var target = _get_closest_target()
	if !is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	var distance = global_position.distance_to(target.global_position)
	var direction = global_position.direction_to(target.global_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	if charge_cooldown <= 0.0:
		if enemy_role == 2 and distance <= 190.0:
			_begin_attack("smash", target, 0.75, 135.0)
			return
		if enemy_role == 3 and distance >= 90.0 and distance <= 460.0:
			_begin_attack("charge", target, 0.7, 0.0)
			return
		if enemy_role == 4 and distance <= 650.0 and _has_clear_shot(target):
			_begin_attack("dart", target, 0.8, 0.0)
			return
		if enemy_role == 5 and distance <= 650.0:
			var attacks = ["sweep", "smash", "charge"]
			var kind = attacks[boss_attack_index % attacks.size()]
			if kind == "sweep" and distance > 330.0:
				kind = "charge"
			_begin_attack(kind, target, 0.8 if boss_enraged else 1.1, 190.0 if kind == "smash" else 260.0)
			boss_attack_index += 1
			return
	if enemy_role == 4:
		if distance < 220.0:
			velocity = -direction * speed
		elif distance > 430.0:
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO
	else:
		velocity = direction * speed


func _get_closest_target():
	var king = Global.king_node
	var player = Global.player_node
	var king_valid = is_instance_valid(king) and Global.king_health > 0.0
	var player_valid = is_instance_valid(player) and Global.player_health > 0.0
	if !king_valid:
		return player if player_valid else null
	if !player_valid:
		return king
	if enemy_role == 1:
		return king
	if enemy_role == 5:
		return player
	return king if global_position.distance_squared_to(king.global_position) < global_position.distance_squared_to(player.global_position) else player


func _has_clear_shot(target: Node2D) -> bool:
	var excluded: Array[RID] = []
	for actor in get_tree().get_nodes_in_group("enemy") + [Global.player_node, Global.king_node]:
		if is_instance_valid(actor) and actor is CollisionObject2D:
			excluded.append(actor.get_rid())
	var query = PhysicsRayQueryParameters2D.create(global_position, target.global_position, target.collision_mask if target is CollisionObject2D else 1, excluded)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _begin_attack(kind: String, target: Node2D, windup: float, radius: float) -> void:
	attack_kind = kind
	attack_duration = windup
	charge_windup = windup
	attack_origin = global_position
	attack_point = target.global_position
	charge_direction = global_position.direction_to(attack_point)
	if charge_direction.is_zero_approx():
		charge_direction = Vector2.RIGHT
	attack_radius = radius
	charge_distance = min(global_position.distance_to(attack_point) + 70.0, 450.0 if enemy_role == 5 else 320.0)
	attack_hit_ids.clear()
	charge_cooldown = 2.0 if enemy_role == 5 else 3.0
	velocity = Vector2.ZERO


func _release_attack() -> void:
	match attack_kind:
		"charge":
			charge_time = charge_distance / (520.0 if enemy_role == 5 else 430.0)
		"dart":
			_fire_dart()
			recovery_time = 0.4
		"smash":
			var circle = CircleShape2D.new()
			circle.radius = attack_radius
			_damage_shape(circle, Transform2D(0.0, attack_point), damage * 1.35)
			_show_impact(attack_point, attack_radius)
			recovery_time = 0.7
		"sweep":
			var shape = ConvexPolygonShape2D.new()
			var points = PackedVector2Array([Vector2.ZERO])
			for i in range(17):
				points.append(Vector2.from_angle(-deg_to_rad(70.0) + deg_to_rad(140.0) * float(i) / 16.0) * attack_radius)
			shape.points = points
			_damage_shape(shape, Transform2D(charge_direction.angle(), attack_origin), damage)
			_show_impact(attack_origin, attack_radius)
			recovery_time = 0.75


func _fire_dart() -> void:
	var dart = Dart.new()
	dart.texture = DART_TEXTURE
	dart.direction = charge_direction
	dart.damage = damage
	dart.angle_offset = deg_to_rad(dart_angle_offset_degrees)
	get_parent().add_child(dart)
	dart.global_position = global_position


func _damage_charge(start: Vector2, end: Vector2) -> void:
	var shape = RectangleShape2D.new()
	shape.size = Vector2(start.distance_to(end) + 40.0, 100.0 if enemy_role == 5 else 42.0)
	_damage_shape(shape, Transform2D(charge_direction.angle(), (start + end) * 0.5), damage * 1.25)


func _damage_shape(shape: Shape2D, shape_transform: Transform2D, amount: float) -> void:
	for actor in [Global.player_node, Global.king_node]:
		if !is_instance_valid(actor) or !(actor is CollisionObject2D) or attack_hit_ids.has(actor.get_instance_id()):
			continue
		var touching = false
		for owner_id in actor.get_shape_owners():
			if actor.is_shape_owner_disabled(owner_id):
				continue
			var transform = actor.global_transform * actor.shape_owner_get_transform(owner_id)
			for i in range(actor.shape_owner_get_shape_count(owner_id)):
				var body_shape = actor.shape_owner_get_shape(owner_id, i)
				if body_shape != null and shape.collide(shape_transform, body_shape, transform):
					touching = true
		if touching:
			attack_hit_ids[actor.get_instance_id()] = true
			if actor == Global.player_node:
				Global.damage_player(amount)
			else:
				Global.damage_king(amount)


func _show_impact(point: Vector2, radius: float) -> void:
	var ring = Line2D.new()
	ring.top_level = true
	ring.process_mode = Node.PROCESS_MODE_PAUSABLE
	ring.width = 7.0
	ring.default_color = Color(1.0, 0.65, 0.2, 0.9)
	ring.z_index = 25
	for i in range(33):
		ring.add_point(Vector2.from_angle(TAU * float(i) / 32.0) * radius)
	get_parent().add_child(ring)
	ring.global_position = point
	var tween = ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 1.15, 0.3)
	tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(ring.queue_free)


func _update_boss_phase(delta: float) -> void:
	if !boss_enraged and health <= max_health * 0.5:
		boss_enraged = true
		visual_color *= Color(1.0, 0.75, 0.65)
		get_tree().call_group("enemy_spawner_controller", "spawn_boss_reinforcements", global_position, 4)
	if boss_enraged:
		reinforcement_timer -= delta
		if reinforcement_timer <= 0.0:
			reinforcement_timer = 12.0
			get_tree().call_group("enemy_spawner_controller", "spawn_boss_reinforcements", global_position, 3)


func take_damage(amount: float, source_position: Vector2, extra_knockback: float = 1.0, critical: bool = false) -> void:
	if dead or health <= 0.0 or amount <= 0.0:
		return
	health = max(health - amount, 0.0)
	flash_timer = 0.1
	_show_damage_number(amount, critical)
	if enemy_role != 5:
		charge_windup = 0.0
		charge_time = 0.0
		charge_cooldown = max(charge_cooldown, 1.0)
		var resistance = clamp(1.0 - float(enemy_level - 1) * 0.015, 0.65, 1.0)
		if enemy_role == 2:
			resistance *= 0.6
		var direction = source_position.direction_to(global_position)
		if direction.is_zero_approx():
			direction = Vector2.UP
		knockback_velocity = direction * knockback_speed * resistance * max(extra_knockback, 0.0)
		knockback = knockback_velocity.length_squared() > 1.0
		if knockback:
			$knockback_timer.start()
	if health <= 0.0:
		_die()


func _show_damage_number(amount: float, critical: bool) -> void:
	if get_tree().get_nodes_in_group("combat_feedback").size() >= 70:
		return
	var number = Label.new()
	number.text = str(int(ceil(amount))) + ("!" if critical else "")
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.add_theme_font_size_override("font_size", 25 if critical else 17)
	number.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if critical else Color.WHITE)
	number.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	number.add_theme_constant_override("outline_size", 3)
	number.z_as_relative = false
	number.z_index = 110
	number.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_parent().add_child(number)
	number.add_to_group("combat_feedback")
	number.global_position = global_position + Vector2(randf_range(-14.0, 6.0), -38.0)
	var tween = number.create_tween().set_parallel(true)
	tween.tween_property(number, "position", number.position + Vector2(randf_range(-10.0, 10.0), -35.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "modulate:a", 0.0, 0.22).set_delay(0.23)
	tween.chain().tween_callback(number.queue_free)


func _die() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemy")
	Global.kills += 1
	if enemy_role == 5:
		remove_from_group("stage_boss")
		get_tree().call_group("enemy_spawner_controller", "on_stage_boss_defeated", global_position)
	else:
		_drop_xp()
		if randf() < clamp(heart_drop_chance + Global.heart_drop_chance_bonus, 0.0, 0.35):
			_drop_heart()
	queue_free()


func _drop_xp() -> void:
	var orb = XP_ORB_SCRIPT.new()
	orb.xp_value = xp_drop
	get_parent().add_child(orb)
	orb.global_position = global_position


func _drop_heart() -> void:
	var heart = HEART_SCRIPT.new()
	get_parent().add_child(heart)
	heart.global_position = global_position


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == Global.player_node:
		touching_player = true
	elif body == Global.king_node:
		touching_king = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == Global.player_node:
		touching_player = false
	elif body == Global.king_node:
		touching_king = false


func _on_hit_timer_timeout() -> void:
	can_attack = true


func _on_area_2d_area_entered(area: Area2D) -> void:
	if dead or !area.is_in_group("weapon"):
		return
	var weapon = area
	while is_instance_valid(weapon):
		if weapon.has_method("try_hit_enemy"):
			weapon.try_hit_enemy(self)
			return
		weapon = weapon.get_parent()
	var critical = randf() < Global.sword_crit_chance
	take_damage(Global.weapon_damage * (Global.sword_crit_multiplier if critical else 1.0), area.global_position, Global.sword_knockback_multiplier, critical)


func _on_knockback_timer_timeout() -> void:
	knockback = false
	knockback_velocity = Vector2.ZERO


func _draw() -> void:
	if charge_windup <= 0.0 or dead:
		return
	var alpha = 0.35 + (1.0 - charge_windup / max(attack_duration, 0.01)) * 0.4
	var fill = Color(1.0, 0.2, 0.05, alpha * 0.35)
	var edge = Color(1.0, 0.65, 0.2, alpha)
	if attack_kind == "smash":
		var points = PackedVector2Array()
		for i in range(49):
			points.append(to_local(attack_point + Vector2.from_angle(TAU * float(i) / 48.0) * attack_radius))
		draw_colored_polygon(points, fill)
		draw_polyline(points, edge, 3.0, true)
	elif attack_kind == "sweep":
		var points = PackedVector2Array([to_local(attack_origin)])
		for i in range(25):
			points.append(to_local(attack_origin + charge_direction.rotated(-deg_to_rad(70.0) + deg_to_rad(140.0) * float(i) / 24.0) * attack_radius))
		points.append(to_local(attack_origin))
		draw_colored_polygon(points, fill)
		draw_polyline(points, edge, 3.0, true)
	else:
		var length = 650.0 if attack_kind == "dart" else charge_distance
		var width = 100.0 if enemy_role == 5 else 42.0 if attack_kind == "charge" else 14.0
		var side = charge_direction.orthogonal() * width * 0.5
		var end = attack_origin + charge_direction * length
		var points = PackedVector2Array([to_local(attack_origin + side), to_local(end + side), to_local(end - side), to_local(attack_origin - side)])
		draw_colored_polygon(points, fill)
		draw_line(to_local(attack_origin), to_local(end), edge, 3.0, true)
