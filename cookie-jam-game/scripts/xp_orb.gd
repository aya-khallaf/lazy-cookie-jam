extends Node2D

const ORB_TEXTURE = preload("res://assets/orb.svg")

var xp_value = 5.0

var attraction_distance = 200.0
var attraction_speed = 550.0

var pickup_distance = 28.0
var lifetime = 35.0


func _ready() -> void:
	add_to_group("xp_orb")

	z_index = 20

	var sprite = Sprite2D.new()

	sprite.texture = ORB_TEXTURE

	add_child(sprite)


func _process(delta: float) -> void:
	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()
		return

	if !is_instance_valid(Global.player_node):
		return

	var distance = global_position.distance_to(
		Global.player_node.global_position
	)

	var current_attraction_distance = (
		attraction_distance *
		Global.pickup_range_multiplier
	)

	if distance <= current_attraction_distance:
		global_position = global_position.move_toward(
			Global.player_node.global_position,
			attraction_speed * delta
		)

	if distance <= pickup_distance:
		Global.add_xp(xp_value)

		queue_free()
