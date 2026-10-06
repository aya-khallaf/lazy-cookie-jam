extends Node2D

var duration = 0.42
var elapsed = 0.0

var max_radius = 170.0
var damage = 30.0

var ring
var hit_enemies = {}


func _ready() -> void:
	z_index = 15

	max_radius = (
		Global.shockwave_radius
	)

	damage = (
		Global.shockwave_damage
	)

	ring = Line2D.new()

	ring.width = 7.0

	ring.default_color = Color(
		1.0,
		0.85,
		0.25,
		0.9
	)

	ring.begin_cap_mode = (
		Line2D.LINE_CAP_ROUND
	)

	ring.end_cap_mode = (
		Line2D.LINE_CAP_ROUND
	)

	ring.joint_mode = (
		Line2D.LINE_JOINT_ROUND
	)

	add_child(
		ring
	)


func _process(delta: float) -> void:
	elapsed += delta

	var progress = clamp(
		elapsed / duration,
		0.0,
		1.0
	)

	var current_radius = lerp(
		10.0,
		max_radius,
		progress
	)

	_update_ring(
		current_radius
	)

	_damage_enemies(
		current_radius
	)

	ring.modulate.a = (
		1.0 -
		progress
	)

	ring.width = (
		7.0 +
		progress *
		8.0
	)

	if progress >= 1.0:
		queue_free()


func _update_ring(radius: float) -> void:
	ring.clear_points()

	var segments = 48

	for i in range(
		segments + 1
	):
		var angle = (
			TAU *
			float(i) /
			float(segments)
		)

		ring.add_point(
			Vector2.from_angle(
				angle
			) *
			radius
		)


func _damage_enemies(radius: float) -> void:
	var enemies = get_tree().get_nodes_in_group(
		"enemy"
	)

	for enemy in enemies:
		if !is_instance_valid(
			enemy
		):
			continue

		var enemy_id = (
			enemy.get_instance_id()
		)

		if hit_enemies.has(
			enemy_id
		):
			continue

		var distance = global_position.distance_to(
			enemy.global_position
		)

		if distance > radius:
			continue

		hit_enemies[enemy_id] = true

		if enemy.has_method(
			"take_damage"
		):
			enemy.take_damage(
				damage,
				global_position
			)
