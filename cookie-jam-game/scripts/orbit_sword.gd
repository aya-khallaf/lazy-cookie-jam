extends Node2D

const SWORD_TEXTURE = preload("res://assets/sword.svg")

var orbit_index = 0
var orbit_count = 1

var orbit_angle = 0.0

var hit_radius = 42.0
var hit_delay = 0.45

var hit_cooldowns = {}


func _ready() -> void:
	z_index = 25

	var sprite = Sprite2D.new()

	sprite.texture = SWORD_TEXTURE

	sprite.scale = Vector2(
		0.8,
		0.8
	)

	add_child(sprite)


func _process(delta: float) -> void:
	_update_hit_cooldowns(delta)

	orbit_angle += (
		Global.orbit_sword_speed *
		delta
	)

	var spacing = (
		TAU /
		max(
			orbit_count,
			1
		)
	)

	var angle = (
		orbit_angle +
		spacing *
		orbit_index
	)

	position = (
		Vector2.from_angle(
			angle
		) *
		Global.orbit_sword_radius
	)

	rotation = (
		angle +
		PI / 2.0
	)

	_damage_enemies()


func _update_hit_cooldowns(delta: float) -> void:
	for enemy_id in hit_cooldowns.keys():
		hit_cooldowns[enemy_id] -= delta

		if hit_cooldowns[enemy_id] <= 0.0:
			hit_cooldowns.erase(
				enemy_id
			)


func _damage_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group(
		"enemy"
	)

	for enemy in enemies:
		if !is_instance_valid(enemy):
			continue

		var enemy_id = enemy.get_instance_id()

		if hit_cooldowns.has(
			enemy_id
		):
			continue

		var distance = global_position.distance_to(
			enemy.global_position
		)

		if distance > hit_radius:
			continue

		if enemy.has_method("take_damage"):
			enemy.take_damage(
				Global.orbit_sword_damage,
				global_position
			)

			hit_cooldowns[enemy_id] = hit_delay
