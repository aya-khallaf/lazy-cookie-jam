extends Node2D

const FIREBALL_TEXTURE = preload("res://assets/fireball.svg")

var direction = Vector2.RIGHT

var speed = 700.0
var damage = 40.0

var lifetime = 3.0
var hit_radius = 35.0

var hits_remaining = 1

var hit_enemies = {}


func _ready() -> void:
	z_index = 30

	speed = Global.fireball_speed
	damage = Global.fireball_damage

	hits_remaining = (
		1 +
		Global.fireball_pierce
	)

	var sprite = Sprite2D.new()

	sprite.texture = FIREBALL_TEXTURE

	sprite.modulate = Color(
		1.0,
		0.2,
		0.05,
		1.0
	)

	sprite.scale = (
		Vector2(
			0.4,
			0.4
		) *
		Global.fireball_size_multiplier
	)

	add_child(
		sprite
	)


func setup(
	target: Node2D,
	angle_offset: float = 0.0
) -> void:

	if !is_instance_valid(
		target
	):
		return

	direction = global_position.direction_to(
		target.global_position
	)

	direction = direction.rotated(
		angle_offset
	)

	direction = direction.normalized()


func _process(delta: float) -> void:
	global_position += (
		direction *
		speed *
		delta
	)

	rotation = direction.angle()

	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()
		return

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

		var current_hit_radius = (
			hit_radius *
			Global.fireball_size_multiplier
		)

		if distance <= current_hit_radius:
			hit_enemies[enemy_id] = true

			if enemy.has_method(
				"take_damage"
			):
				enemy.take_damage(
					damage,
					global_position
				)

			hits_remaining -= 1

			if hits_remaining <= 0:
				queue_free()

			return
