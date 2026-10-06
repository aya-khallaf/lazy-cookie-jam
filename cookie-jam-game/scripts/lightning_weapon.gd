extends Node2D

var lifetime = 0.18
var maximum_lifetime = 0.18

var fired = false


func fire() -> void:
	if fired:
		return

	fired = true

	var enemies = get_tree().get_nodes_in_group(
		"enemy"
	)

	if enemies.is_empty():
		queue_free()
		return

	var already_hit = {}

	var current_position = global_position

	for i in range(
		Global.lightning_chains
	):
		var target = _find_nearest_enemy(
			current_position,
			enemies,
			already_hit
		)

		if !is_instance_valid(
			target
		):
			break

		var target_id = (
			target.get_instance_id()
		)

		already_hit[target_id] = true

		_create_bolt(
			current_position,
			target.global_position
		)

		if target.has_method(
			"take_damage"
		):
			target.take_damage(
				Global.lightning_damage,
				current_position
			)

		current_position = (
			target.global_position
		)

	if already_hit.is_empty():
		queue_free()


func _process(delta: float) -> void:
	lifetime -= delta

	modulate.a = clamp(
		lifetime /
		maximum_lifetime,
		0.0,
		1.0
	)

	if lifetime <= 0.0:
		queue_free()


func _find_nearest_enemy(
	from_position: Vector2,
	enemies: Array,
	already_hit: Dictionary
):
	var nearest_enemy = null
	var nearest_distance = INF

	for enemy in enemies:
		if !is_instance_valid(
			enemy
		):
			continue

		var enemy_id = (
			enemy.get_instance_id()
		)

		if already_hit.has(
			enemy_id
		):
			continue

		var distance = from_position.distance_to(
			enemy.global_position
		)

		if distance > Global.lightning_range:
			continue

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	return nearest_enemy


func _create_bolt(
	start_global: Vector2,
	end_global: Vector2
) -> void:

	var bolt = Line2D.new()

	bolt.width = 5.0

	bolt.default_color = Color(
		0.55,
		0.85,
		1.0,
		1.0
	)

	bolt.begin_cap_mode = (
		Line2D.LINE_CAP_ROUND
	)

	bolt.end_cap_mode = (
		Line2D.LINE_CAP_ROUND
	)

	bolt.joint_mode = (
		Line2D.LINE_JOINT_ROUND
	)

	add_child(
		bolt
	)

	var start = to_local(
		start_global
	)

	var end = to_local(
		end_global
	)

	var direction = (
		end -
		start
	)

	var perpendicular = Vector2(
		-direction.y,
		direction.x
	).normalized()

	var segments = 8

	for i in range(
		segments + 1
	):
		var progress = (
			float(i) /
			float(segments)
		)

		var point = start.lerp(
			end,
			progress
		)

		if (
			i != 0
			and
			i != segments
		):
			point += (
				perpendicular *
				randf_range(
					-15.0,
					15.0
				)
			)

		bolt.add_point(
			point
		)

	var core = Line2D.new()

	core.width = 2.0

	core.default_color = Color(
		0.9,
		0.97,
		1.0,
		1.0
	)

	core.begin_cap_mode = (
		Line2D.LINE_CAP_ROUND
	)

	core.end_cap_mode = (
		Line2D.LINE_CAP_ROUND
	)

	core.joint_mode = (
		Line2D.LINE_JOINT_ROUND
	)

	add_child(
		core
	)

	for point in bolt.points:
		core.add_point(
			point
		)
