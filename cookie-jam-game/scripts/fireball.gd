extends Node2D

const FIREBALL_TEXTURE = preload("res://assets/fireball.svg")

var direction = Vector2.RIGHT
var speed = 700.0
var damage = 40.0
var lifetime = 3.0
var hit_radius = 35.0
var hits_remaining = 1
var hit_enemies = {}
var streak_length = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 30
	speed = Global.fireball_speed
	damage = Global.fireball_damage
	hits_remaining = 1 + Global.fireball_pierce
	var sprite = Sprite2D.new()
	sprite.texture = FIREBALL_TEXTURE
	sprite.modulate = Color(1.0, 0.45, 0.15)
	sprite.scale = Vector2.ONE * 0.4 * Global.fireball_size_multiplier
	add_child(sprite)


func setup(target: Node2D, angle_offset: float = 0.0) -> void:
	if !is_instance_valid(target):
		return
	var target_position = target.global_position
	if target is CharacterBody2D:
		var lead_time = min(global_position.distance_to(target_position) / max(speed, 1.0), 0.3)
		target_position += target.velocity * lead_time
	direction = global_position.direction_to(target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	direction = direction.rotated(angle_offset).normalized()
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if !Global.gameplay_started:
		return
	var previous_position = global_position
	global_position += direction * speed * delta
	rotation = direction.angle()
	lifetime -= delta
	streak_length = min(streak_length + speed * delta, 90.0)
	var contacts = []
	var radius_squared = pow(hit_radius * Global.fireball_size_multiplier, 2.0)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if !(enemy is Node2D) or !is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if hit_enemies.has(enemy.get_instance_id()) or !enemy.has_method("take_damage"):
			continue
		var closest_point = Geometry2D.get_closest_point_to_segment(enemy.global_position, previous_position, global_position)
		if closest_point.distance_squared_to(enemy.global_position) <= radius_squared:
			contacts.append({"enemy": enemy, "distance": previous_position.distance_squared_to(closest_point)})
	contacts.sort_custom(func(a, b): return a["distance"] < b["distance"])
	for contact in contacts:
		var enemy = contact["enemy"]
		if !is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		hit_enemies[enemy.get_instance_id()] = true
		enemy.take_damage(damage, previous_position)
		hits_remaining -= 1
		if hits_remaining <= 0:
			queue_free()
			return
	if lifetime <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var size_multiplier = Global.fireball_size_multiplier
	draw_line(Vector2(-streak_length, 0.0), Vector2.ZERO, Color(1.0, 0.25, 0.04, 0.18), 18.0 * size_multiplier, true)
	draw_line(Vector2(-streak_length * 0.7, 0.0), Vector2.ZERO, Color(1.0, 0.6, 0.12, 0.45), 6.0 * size_multiplier, true)
