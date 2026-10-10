extends CharacterBody2D

const DART_TEXTURE = preload("res://assets/dart.svg")
const VOICE_LINES = [
	"THIS IS WHAT TRUE STRENGTH LOOKS LIKE!",
	"YOU HAVE GROWN WEAK AND LAZY, YOUR MAJESTY!",
	"EVEN YOUR BODYGUARD HAS INHERITED YOUR LAZINESS!",
	"GOBLIN SUPREMACY!",
	"I WILL SHOW YOU REAL POWER!",
	"THE GOBLIN EMPIRE WILL RISE!",
	"BOW BEFORE GOBTAR, THE GOBLIN DUKE!",
	"YOUR REIGN OF WEAKNESS ENDS TODAY!",
	"YOU CANNOT HIDE BEHIND YOUR BODYGUARD FOREVER!",
	"THE GOBLINS WILL RULE THIS REALM!",
	"IS THIS THE BEST YOUR MAJESTY CAN DO?",
	"YOU HAVE FORGOTTEN WHAT STRENGTH MEANS!",
	"THE AGE OF GOBLINS BEGINS NOW!",
	"YOUR KINGDOM WILL TREMBLE BEFORE ME!",
	"WITNESS THE MIGHT OF THE GOBLIN DUKE!"
]

@export var base_speed = 205.0
@export var base_damage = 38.0
@export var base_health = 6000.0
@export var knockback_speed = 22.0
@export var knockback_deceleration = 260.0
@export var dart_angle_offset_degrees = 0.0

var speed = 125.0
var damage = 18.0
var max_health = 1800.0
var health = 1800.0
var touching_player = false
var touching_king = false
var can_attack = true
var knockback = false
var knockback_velocity = Vector2.ZERO
var dead = false
var flash_timer = 0.0
var visual_color = Color.WHITE
var charge_cooldown = 0.6
var radial_shot_timer = 0.15
var radial_warning_timer = 0.0
var radial_warning_duration = 2.2
var radial_warning_angle = 0.0
var radial_aim_angle = 0.0
var aoe_timer = 1.1
var aoe_warning_timer = 0.0
var aoe_warning_duration = 2.4
var aoe_warning_point = Vector2.ZERO
var aoe_warning_radius = 235.0
var dash_speed = 1050.0
var charge_windup = 0.0
var charge_time = 0.0
var charge_direction = Vector2.RIGHT
var charge_distance = 300.0
var attack_kind = ""
var attack_duration = 1.0
var attack_origin = Vector2.ZERO
var attack_point = Vector2.ZERO
var attack_radius = 145.0
var recovery_time = 0.0
var attack_hit_ids = {}
var next_close_attack = "smash"
var second_phase = false
var boss_name_label: Label
var voice_line_label: Label
var voice_line_timer = 0.6
var voice_line_visible_timer = 0.0
var last_voice_line_index = -1
var health_bar

class Dart:
	extends Node2D

	var direction = Vector2.RIGHT
	var speed = 1000.0
	var damage = 20.0
	var lifetime = 4.0
	var remaining_distance = 650.0
	var texture
	var angle_offset = 0.0
	var wall_collision_mask = 1

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		process_physics_priority = 110
		top_level = true
		z_index = 35
		add_to_group("enemy_dart")

		var sprite = Sprite2D.new()
		sprite.texture = texture
		sprite.scale = Vector2.ONE * 52.0 / max(texture.get_size().x, texture.get_size().y)
		add_child(sprite)
		rotation = direction.angle() + angle_offset

	func _physics_process(delta: float) -> void:
		if !Global.gameplay_started:
			queue_free()
			return

		lifetime -= delta
		var start = global_position
		var travel = min(speed * delta, remaining_distance)
		var end = start + direction * travel

		if is_instance_valid(Global.player_node) and Global.player_health > 0.0:
			if _check_target(Global.player_node, start, end):
				Global.damage_player(damage)
				queue_free()
				return

		if is_instance_valid(Global.king_node) and Global.king_health > 0.0:
			if _check_target(Global.king_node, start, end):
				Global.damage_king(damage)
				queue_free()
				return

		var wall_query = PhysicsRayQueryParameters2D.create(start, end, wall_collision_mask)
		var wall = get_world_2d().direct_space_state.intersect_ray(wall_query)
		if !wall.is_empty():
			global_position = wall["position"]
			queue_free()
			return

		global_position = end
		remaining_distance -= travel
		if lifetime <= 0.0 or remaining_distance <= 0.0:
			queue_free()

	func _check_target(actor: Node2D, start: Vector2, end: Vector2) -> bool:
		if !is_instance_valid(actor):
			return false
		return _closest_point_on_segment(actor.global_position, start, end).distance_to(actor.global_position) <= 28.0

	func _closest_point_on_segment(point: Vector2, start: Vector2, end: Vector2) -> Vector2:
		var line = end - start
		var length_squared = line.length_squared()
		if length_squared <= 0.001:
			return start
		var t = clamp(line.dot(point - start) / length_squared, 0.0, 1.0)
		return start + line * t


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("enemy")

	speed = base_speed
	damage = base_damage
	max_health = max(base_health, 1.0)
	health = max_health
	charge_cooldown = 0.35
	radial_shot_timer = 0.1
	aoe_timer = 0.8

	if has_node("ProgressBar"):
		health_bar = $ProgressBar
		health_bar.max_value = max_health
		health_bar.value = health

	_create_boss_nameplate()
	_create_boss_voiceline()
	_position_boss_labels()


func _create_boss_nameplate() -> void:
	boss_name_label = Label.new()
	boss_name_label.name = "BossNameplate"
	boss_name_label.text = "GOBTAR THE GOBLIN DUKE"
	boss_name_label.position = Vector2(-180.0, -105.0)
	boss_name_label.size = Vector2(360.0, 30.0)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_name_label.add_theme_font_size_override("font_size", 19)
	boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
	boss_name_label.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02))
	boss_name_label.add_theme_constant_override("outline_size", 5)
	add_child(boss_name_label)


func _create_boss_voiceline() -> void:
	voice_line_label = Label.new()
	voice_line_label.name = "BossVoiceLine"
	voice_line_label.position = Vector2(-330.0, -215.0)
	voice_line_label.size = Vector2(660.0, 100.0)
	voice_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	voice_line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	voice_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	voice_line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	voice_line_label.add_theme_font_size_override("font_size", 29)
	voice_line_label.add_theme_color_override("font_color", Color(0.12, 1.0, 0.24))
	voice_line_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	voice_line_label.add_theme_constant_override("outline_size", 8)
	voice_line_label.visible = false
	add_child(voice_line_label)


func _position_boss_labels() -> void:
	var center_x = 0.0
	var name_y = -105.0
	if is_instance_valid(health_bar) and health_bar is Control:
		center_x = health_bar.position.x + health_bar.size.x * 0.5
		name_y = health_bar.position.y - 38.0
	if is_instance_valid(boss_name_label):
		boss_name_label.position = Vector2(center_x - boss_name_label.size.x * 0.5, name_y)
	if is_instance_valid(voice_line_label) and is_instance_valid(boss_name_label):
		voice_line_label.position = Vector2(center_x - voice_line_label.size.x * 0.5, boss_name_label.position.y - voice_line_label.size.y - 12.0)


func _update_boss_voicelines(delta: float) -> void:
	if !is_instance_valid(voice_line_label):
		return
	if voice_line_visible_timer > 0.0:
		voice_line_visible_timer = max(voice_line_visible_timer - delta, 0.0)
		if voice_line_visible_timer <= 0.0:
			voice_line_label.visible = false
	voice_line_timer -= delta
	if voice_line_timer <= 0.0:
		_show_boss_voiceline()


func _show_boss_voiceline() -> void:
	if !is_instance_valid(voice_line_label):
		return
	var line_index = randi_range(0, VOICE_LINES.size() - 1)
	if VOICE_LINES.size() > 1 and line_index == last_voice_line_index:
		line_index = (line_index + randi_range(1, VOICE_LINES.size() - 1)) % VOICE_LINES.size()
	last_voice_line_index = line_index
	voice_line_label.text = VOICE_LINES[line_index]
	voice_line_label.visible = true
	voice_line_label.modulate = Color.WHITE
	voice_line_visible_timer = 2.8 if second_phase else 2.5
	voice_line_timer = randf_range(1.5, 2.6) if second_phase else randf_range(2.2, 3.8)


func _physics_process(delta: float) -> void:
	if dead or !Global.gameplay_started:
		return
	if health <= 0.0:
		_die()
		return

	flash_timer = max(flash_timer - delta, 0.0)
	_update_boss_voicelines(delta)
	if has_node("Visual"):
		$Visual.modulate = Color(2.0, 2.0, 2.0) if flash_timer > 0.0 else visual_color

	if is_instance_valid(health_bar):
		health_bar.value = health

	if !second_phase and health <= max_health * 0.5:
		_enter_second_phase()

	charge_cooldown = max(charge_cooldown - delta, 0.0)
	recovery_time = max(recovery_time - delta, 0.0)

	if radial_warning_timer > 0.0:
		velocity = Vector2.ZERO
		radial_warning_timer = max(radial_warning_timer - delta, 0.0)
		if radial_warning_timer <= 0.0:
			_fire_radial_burst()
			radial_shot_timer = 0.72 if second_phase else 0.95
		move_and_slide()
		queue_redraw()
		return

	if aoe_warning_timer > 0.0:
		velocity = Vector2.ZERO
		aoe_warning_timer = max(aoe_warning_timer - delta, 0.0)
		if aoe_warning_timer <= 0.0:
			_perform_aoe_attack()
			aoe_timer = 1.4 if second_phase else 2.1
		move_and_slide()
		queue_redraw()
		return

	if charge_windup <= 0.0 and charge_time <= 0.0 and recovery_time <= 0.0 and !knockback:
		radial_shot_timer = max(radial_shot_timer - delta, 0.0)
		aoe_timer = max(aoe_timer - delta, 0.0)
		if radial_shot_timer <= 0.0:
			_begin_radial_warning()
			velocity = Vector2.ZERO
			move_and_slide()
			queue_redraw()
			return
		if aoe_timer <= 0.0:
			_begin_aoe_warning()
			if aoe_warning_timer > 0.0:
				velocity = Vector2.ZERO
				move_and_slide()
				queue_redraw()
				return
			aoe_timer = 0.5

	if knockback:
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
		charge_time = max(charge_time - delta, 0.0)
		velocity = charge_direction * (dash_speed * (1.35 if second_phase else 1.0))
		move_and_slide()
		_damage_charge(previous, global_position)
		if is_on_wall() or charge_time <= 0.0:
			charge_time = 0.0
			recovery_time = 0.25 if second_phase else 0.4
		queue_redraw()
		return
	elif recovery_time > 0.0:
		velocity = Vector2.ZERO
	else:
		_chase_target()

	move_and_slide()
	queue_redraw()


func _enter_second_phase() -> void:
	second_phase = true
	speed = base_speed * 1.55
	damage = base_damage * 1.5
	charge_cooldown = min(charge_cooldown, 0.15)
	radial_shot_timer = min(radial_shot_timer, 0.05)
	aoe_timer = min(aoe_timer, 0.25)
	if is_instance_valid(boss_name_label):
		boss_name_label.text = "GOBTAR THE GOBLIN DUKE - ENRAGED"
		boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.12))
	_show_boss_voiceline()


func _handle_attack() -> void:
	if !can_attack:
		return
	if touching_king and is_instance_valid(Global.king_node) and Global.king_health > 0.0:
		if Global.damage_king(damage):
			can_attack = false
			$hit_timer.start()
	elif touching_player and is_instance_valid(Global.player_node) and Global.player_health > 0.0:
		if Global.damage_player(damage):
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
		if distance <= 220.0:
			_begin_attack(next_close_attack, target, 0.95 if second_phase else 1.25, 245.0 if second_phase else 210.0)
			next_close_attack = "sweep" if next_close_attack == "smash" else "smash"
			return
		_begin_attack("charge", target, 0.85 if second_phase else 1.1, 0.0)
		return

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
	return king if global_position.distance_squared_to(king.global_position) < global_position.distance_squared_to(player.global_position) else player


func _fire_dart_in_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var dart = Dart.new()
	dart.texture = DART_TEXTURE
	dart.scale = Vector2(2.3, 2.3)
	dart.direction = direction.normalized()
	dart.damage = damage
	dart.angle_offset = deg_to_rad(dart_angle_offset_degrees) - PI / 2.0
	get_parent().add_child(dart)
	dart.global_position = global_position


func _fire_dart() -> void:
	var target = _get_closest_target()
	if is_instance_valid(target):
		_fire_dart_in_direction(global_position.direction_to(target.global_position))


func _begin_radial_warning() -> void:
	radial_warning_duration = 2.45 if second_phase else 3.0
	radial_warning_timer = radial_warning_duration
	aoe_timer = max(aoe_timer, 1.8 if second_phase else 2.4)
	radial_warning_angle = randf_range(0.0, TAU)
	var target = _get_closest_target()
	if is_instance_valid(target):
		radial_aim_angle = global_position.direction_to(target.global_position).angle()
	else:
		radial_aim_angle = 0.0
	queue_redraw()


func _fire_radial_burst() -> void:
	var dart_count = 24 if second_phase else 16
	for i in range(dart_count):
		var angle = radial_warning_angle + TAU * float(i) / float(dart_count)
		_fire_dart_in_direction(Vector2.from_angle(angle))
	var aimed_count = 5 if second_phase else 3
	for i in range(aimed_count):
		var spread = deg_to_rad(12.0) * (float(i) - float(aimed_count - 1) * 0.5)
		_fire_dart_in_direction(Vector2.from_angle(radial_aim_angle + spread))


func _begin_aoe_warning() -> void:
	var target = _get_closest_target()
	radial_shot_timer = max(radial_shot_timer, 0.8 if second_phase else 1.0)
	if !is_instance_valid(target):
		aoe_timer = 0.5
		return
	aoe_warning_point = target.global_position
	aoe_warning_radius = 285.0 if second_phase else 235.0
	aoe_warning_duration = 2.0 if second_phase else 2.5
	aoe_warning_timer = aoe_warning_duration
	queue_redraw()


func _perform_aoe_attack() -> void:
	var radius = aoe_warning_radius
	var damage_multiplier = 2.0 if second_phase else 1.65
	var circle = CircleShape2D.new()
	circle.radius = radius
	attack_hit_ids.clear()
	_damage_shape(circle, Transform2D(0.0, aoe_warning_point), damage * damage_multiplier)
	_show_impact(aoe_warning_point, radius)
	if second_phase:
		var second_circle = CircleShape2D.new()
		second_circle.radius = 185.0
		_damage_shape(second_circle, Transform2D(0.0, global_position), damage * 1.2)
		_show_impact(global_position, 185.0)


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
	charge_distance = min(global_position.distance_to(attack_point) + 70.0, 360.0 if second_phase else 320.0)
	attack_hit_ids.clear()
	charge_cooldown = 0.7 if second_phase else 1.0
	velocity = Vector2.ZERO


func _release_attack() -> void:
	match attack_kind:
		"charge":
			charge_time = charge_distance / (dash_speed * (1.35 if second_phase else 1.0))
		"dart":
			_fire_dart()
			recovery_time = 0.3 if second_phase else 0.45
		"smash":
			var circle = CircleShape2D.new()
			circle.radius = attack_radius
			_damage_shape(circle, Transform2D(0.0, attack_point), damage * (2.8 if second_phase else 2.2))
			_show_impact(attack_point, attack_radius)
			recovery_time = 0.5 if second_phase else 0.75
		"sweep":
			var shape = ConvexPolygonShape2D.new()
			var points = PackedVector2Array([Vector2.ZERO])
			for i in range(17):
				points.append(Vector2.from_angle(-deg_to_rad(70.0) + deg_to_rad(140.0) * float(i) / 16.0) * attack_radius)
			shape.points = points
			_damage_shape(shape, Transform2D(charge_direction.angle(), attack_origin), damage * (2.5 if second_phase else 2.0))
			_show_impact(attack_origin, attack_radius)
			recovery_time = 0.5 if second_phase else 0.8


func _damage_charge(start: Vector2, end: Vector2) -> void:
	var shape = RectangleShape2D.new()
	shape.size = Vector2(start.distance_to(end) + 48.0, 54.0 if second_phase else 42.0)
	_damage_shape(shape, Transform2D(charge_direction.angle(), (start + end) * 0.5), damage * (1.5 if second_phase else 1.25))


func _damage_shape(shape: Shape2D, shape_transform: Transform2D, amount: float) -> void:
	for actor in [Global.player_node, Global.king_node]:
		if !is_instance_valid(actor) or !(actor is CollisionObject2D) or attack_hit_ids.has(actor.get_instance_id()):
			continue
		var touching = false
		for owner_id in actor.get_shape_owners():
			if actor.is_shape_owner_disabled(owner_id):
				continue
			var actor_shape_transform = actor.global_transform * actor.shape_owner_get_transform(owner_id)
			for i in range(actor.shape_owner_get_shape_count(owner_id)):
				var body_shape = actor.shape_owner_get_shape(owner_id, i)
				if body_shape != null and shape.collide(shape_transform, body_shape, actor_shape_transform):
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
	ring.width = 8.0 if second_phase else 7.0
	ring.default_color = Color(1.0, 0.0, 0.0, 0.68)
	ring.z_index = 25
	for i in range(41):
		ring.add_point(Vector2.from_angle(TAU * float(i) / 40.0) * radius)
	get_parent().add_child(ring)
	ring.global_position = point
	var tween = ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 1.2, 0.32)
	tween.tween_property(ring, "modulate:a", 0.0, 0.32)
	tween.chain().tween_callback(ring.queue_free)


func take_damage(amount: float, source_position: Vector2, extra_knockback: float = 1.0, critical: bool = false) -> void:
	if dead or health <= 0.0 or amount <= 0.0:
		return
	health = max(health - amount, 0.0)
	flash_timer = 0.12
	charge_windup = 0.0
	charge_time = 0.0
	charge_cooldown = max(charge_cooldown, 0.7 if second_phase else 1.0)
	var direction = source_position.direction_to(global_position)
	if direction.is_zero_approx():
		direction = Vector2.UP
	knockback_velocity = direction * knockback_speed * (0.25 if second_phase else 0.35) * min(max(extra_knockback, 0.0), 1.0)
	knockback = knockback_velocity.length_squared() > 1.0
	if knockback and has_node("knockback_timer"):
		$knockback_timer.start()
	if health <= 0.0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemy")
	queue_free()


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
	var multiplier = Global.sword_crit_multiplier if critical else 1.0
	take_damage(Global.weapon_damage * multiplier, area.global_position, Global.sword_knockback_multiplier, critical)


func _on_knockback_timer_timeout() -> void:
	knockback = false
	knockback_velocity = Vector2.ZERO


func _draw_warning_line(start_point: Vector2, end_point: Vector2, width: float, alpha: float) -> void:
	var warning_color = Color(1.0, 0.0, 0.0, alpha)
	draw_line(start_point, end_point, warning_color, width, true)
	draw_circle(start_point, width * 0.5, warning_color)
	draw_circle(end_point, width * 0.5, warning_color)


func _draw() -> void:
	if dead:
		return

	if charge_windup > 0.0:
		var progress = 1.0 - charge_windup / max(attack_duration, 0.01)
		var alpha = 0.28 + progress * 0.20
		var fill = Color(1.0, 0.0, 0.0, alpha)
		var edge = Color(1.0, 0.0, 0.0, min(alpha + 0.28, 0.72))
		if attack_kind == "smash":
			var points = PackedVector2Array()
			for i in range(49):
				points.append(to_local(attack_point + Vector2.from_angle(TAU * float(i) / 48.0) * attack_radius))
			draw_colored_polygon(points, fill)
			draw_polyline(points, edge, 5.0, true)
		elif attack_kind == "sweep":
			var points = PackedVector2Array([to_local(attack_origin)])
			for i in range(25):
				points.append(to_local(attack_origin + charge_direction.rotated(-deg_to_rad(70.0) + deg_to_rad(140.0) * float(i) / 24.0) * attack_radius))
			points.append(to_local(attack_origin))
			draw_colored_polygon(points, fill)
			draw_polyline(points, edge, 5.0, true)
			if points.size() > 1:
				draw_circle(points[1], 2.5, edge)
				draw_circle(points[points.size() - 2], 2.5, edge)
		else:
			var length = 760.0 if attack_kind == "dart" else charge_distance
			var width = 56.0 if attack_kind == "charge" else 20.0
			var side = charge_direction.orthogonal() * width * 0.5
			var end = attack_origin + charge_direction * length
			var points = PackedVector2Array([to_local(attack_origin + side), to_local(end + side), to_local(end - side), to_local(attack_origin - side)])
			draw_colored_polygon(points, fill)
			draw_polyline(points, edge, 5.0, true)
			_draw_warning_line(to_local(attack_origin), to_local(end), 5.0, min(alpha + 0.2, 0.7))

	if radial_warning_timer > 0.0:
		var progress = 1.0 - radial_warning_timer / max(radial_warning_duration, 0.01)
		var alpha = 0.32 + progress * 0.20
		var dart_count = 24 if second_phase else 16
		for i in range(dart_count):
			var angle = radial_warning_angle + TAU * float(i) / float(dart_count)
			var direction = Vector2.from_angle(angle)
			_draw_warning_line(direction * 28.0, direction * 760.0, 4.5, alpha)
		var aimed_count = 5 if second_phase else 3
		for i in range(aimed_count):
			var spread = deg_to_rad(12.0) * (float(i) - float(aimed_count - 1) * 0.5)
			var direction = Vector2.from_angle(radial_aim_angle + spread)
			_draw_warning_line(direction * 25.0, direction * 760.0, 7.0, min(alpha + 0.16, 0.7))

	if aoe_warning_timer > 0.0:
		var progress = 1.0 - aoe_warning_timer / max(aoe_warning_duration, 0.01)
		var alpha = 0.22 + progress * 0.20
		var fill = Color(1.0, 0.0, 0.0, alpha)
		var edge = Color(1.0, 0.0, 0.0, min(alpha + 0.3, 0.72))
		var points = PackedVector2Array()
		for i in range(49):
			points.append(to_local(aoe_warning_point + Vector2.from_angle(TAU * float(i) / 48.0) * aoe_warning_radius))
		draw_colored_polygon(points, fill)
		draw_polyline(points, edge, 6.0, true)
		if second_phase:
			var self_points = PackedVector2Array()
			for i in range(49):
				self_points.append(Vector2.from_angle(TAU * float(i) / 48.0) * 185.0)
			draw_colored_polygon(self_points, Color(1.0, 0.0, 0.0, alpha * 0.8))
			draw_polyline(self_points, edge, 5.0, true)
