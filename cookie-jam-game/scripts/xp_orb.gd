extends Node2D

const ORB_TEXTURE = preload("res://assets/orb.svg")

@export var blue_orb_chance = 0.015

var xp_value = 5.0
var attraction_distance = 200.0
var attraction_speed = 550.0
var pickup_distance = 28.0
var lifetime = 60.0
var collected = false
var is_blue = false
var attracted = false
var elapsed = 0.0
var sprite
var previous_player_position = Vector2.ZERO
var tracking_player = null
var pickup_shape = CircleShape2D.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 100
	add_to_group("xp_orb")
	z_index = 20
	elapsed = randf() * TAU
	sprite = Sprite2D.new()
	sprite.texture = ORB_TEXTURE
	add_child(sprite)
	if randf() < blue_orb_chance:
		_make_blue()


func _make_blue() -> void:
	is_blue = true
	sprite.modulate = Color(0.15, 0.55, 1.0)
	sprite.scale = Vector2.ONE * 1.25


func _physics_process(delta: float) -> void:
	if collected or !Global.gameplay_started:
		return
	lifetime -= delta
	elapsed += delta
	if lifetime <= 0.0:
		queue_free()
		return
	sprite.position.y = sin(elapsed * 4.0) * 3.0
	sprite.modulate.a = 0.55 + sin(elapsed * 16.0) * 0.35 if lifetime < 4.0 else 1.0
	if !is_instance_valid(Global.player_node) or Global.player_health <= 0.0:
		return
	var player_position = Global.player_node.global_position
	if tracking_player != Global.player_node:
		tracking_player = Global.player_node
		previous_player_position = player_position
	var touched = _player_touches_pickup(player_position)
	previous_player_position = player_position
	var distance = global_position.distance_to(player_position)
	if touched:
		collect()
		return
	if distance <= attraction_distance * Global.pickup_range_multiplier:
		attracted = true
	if attracted:
		lifetime = max(lifetime, 3.0)
		var current_speed = attraction_speed
		if Global.player_node is CharacterBody2D:
			current_speed = max(current_speed, Global.player_node.velocity.length() + 180.0)
		global_position = global_position.move_toward(player_position, current_speed * delta)
		if _player_touches_pickup(player_position):
			collect()
	queue_redraw()


func _player_touches_pickup(player_position: Vector2) -> bool:
	var closest = Geometry2D.get_closest_point_to_segment(global_position, previous_player_position, player_position)
	if closest.distance_squared_to(global_position) <= pickup_distance * pickup_distance:
		return true
	var player = Global.player_node
	if !(player is CollisionObject2D):
		return false
	pickup_shape.radius = max(pickup_distance, 1.0)
	var pickup_transform = Transform2D(0.0, global_position)
	for owner_id in player.get_shape_owners():
		if player.is_shape_owner_disabled(owner_id):
			continue
		var body_transform = player.global_transform * player.shape_owner_get_transform(owner_id)
		for index in range(player.shape_owner_get_shape_count(owner_id)):
			var body_shape = player.shape_owner_get_shape(owner_id, index)
			if body_shape != null and pickup_shape.collide(pickup_transform, body_shape, body_transform):
				return true
	return false


func collect() -> void:
	if collected or !Global.gameplay_started or Global.player_health <= 0.0 or Global.king_health <= 0.0:
		return
	collected = true
	remove_from_group("xp_orb")
	if is_blue:
		_collect_all_xp()
		return
	Global.add_xp(xp_value)
	queue_free()


func _collect_all_xp() -> void:
	var total_xp = xp_value
	for orb in get_tree().get_nodes_in_group("xp_orb"):
		if orb == self or !is_instance_valid(orb) or orb.is_queued_for_deletion() or orb.collected:
			continue
		orb.collected = true
		total_xp += orb.xp_value
		orb.remove_from_group("xp_orb")
		orb.queue_free()
	Global.add_xp(total_xp)
	queue_free()


func _draw() -> void:
	if is_blue:
		draw_arc(Vector2.ZERO, 18.0 + sin(elapsed * 4.0) * 2.0, 0.0, TAU, 24, Color(0.25, 0.65, 1.0, 0.65), 2.0, true)
