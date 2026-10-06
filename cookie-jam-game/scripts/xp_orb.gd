extends Node2D

const ORB_TEXTURE = preload("res://assets/orb.svg")

@export var blue_orb_chance = 0.015

var xp_value = 5.0

var attraction_distance = 200.0
var attraction_speed = 550.0

var pickup_distance = 28.0
var lifetime = 35.0

var collected = false
var is_blue = false

var sprite


func _ready() -> void:
	add_to_group("xp_orb")

	z_index = 20

	sprite = Sprite2D.new()
	sprite.texture = ORB_TEXTURE

	add_child(sprite)

	if randf() <= blue_orb_chance:
		_make_blue()


func _make_blue() -> void:
	is_blue = true

	sprite.modulate = Color(
		0.15,
		0.55,
		1.0,
		1.0
	)

	sprite.scale = Vector2(
		1.25,
		1.25
	)


func _process(delta: float) -> void:
	if collected:
		return

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

	var current_attraction_distance = (
		attraction_distance *
		Global.pickup_range_multiplier
	)

	if distance <= current_attraction_distance:
		global_position = global_position.move_toward(
			player_position,
			attraction_speed * delta
		)

		distance = global_position.distance_to(
			player_position
		)

	if distance <= pickup_distance:
		collect()


func collect() -> void:
	if collected:
		return

	collected = true

	if is_blue:
		_collect_all_xp()
		return

	Global.add_xp(
		xp_value
	)

	queue_free()


func _collect_all_xp() -> void:
	var total_xp = xp_value

	var orbs = get_tree().get_nodes_in_group(
		"xp_orb"
	)

	for orb in orbs:
		if orb == self:
			continue

		if !is_instance_valid(orb):
			continue

		if orb.collected:
			continue

		orb.collected = true

		total_xp += orb.xp_value

		orb.queue_free()

	Global.add_xp(
		total_xp
	)

	queue_free()
