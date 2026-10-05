extends Node2D

const HEART_TEXTURE = preload("res://assets/heart.svg")

var attraction_distance = 250.0
var attraction_speed = 800.0

var pickup_distance = 45.0
var lifetime = 30.0


func _ready() -> void:
	add_to_group("heart_pickup")

	z_index = 20

	var sprite = Sprite2D.new()

	sprite.texture = HEART_TEXTURE

	add_child(sprite)


func _process(delta: float) -> void:
	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()
		return

	if !is_instance_valid(Global.player_node):
		return

	var player_position = (
		Global.player_node.global_position
	)

	var distance = global_position.distance_to(
		player_position
	)

	if distance <= pickup_distance:
		_collect()
		return

	if distance <= attraction_distance:
		global_position = global_position.move_toward(
			player_position,
			attraction_speed * delta
		)

		distance = global_position.distance_to(
			player_position
		)

		if distance <= pickup_distance:
			_collect()


func _collect() -> void:
	Global.heal_king(
		Global.heart_heal_amount
	)

	queue_free()
