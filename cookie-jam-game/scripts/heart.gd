extends Node2D

const HEART_TEXTURE = preload("res://assets/heart.svg")

var attraction_distance = 250.0
var attraction_speed = 800.0
var pickup_distance = 45.0
var lifetime = 30.0
var collected = false
var attracted = false
var elapsed = 0.0
var sprite
var previous_player_position = Vector2.ZERO
var tracking_player = null
var pickup_shape = CircleShape2D.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 100
	add_to_group("heart_pickup")
	z_index = 20
	sprite = Sprite2D.new()
	sprite.texture = HEART_TEXTURE
	add_child(sprite)


func _physics_process(delta: float) -> void:
	if collected or !Global.gameplay_started:
		return
	elapsed += delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	sprite.position.y = sin(elapsed * 4.0) * 4.0
	sprite.scale = Vector2.ONE * (1.0 + sin(elapsed * 5.0) * 0.06)
	sprite.modulate.a = 0.55 + sin(elapsed * 16.0) * 0.35 if lifetime < 4.0 else 1.0
	if !is_instance_valid(Global.player_node):
		return
	if Global.king_health <= 0.0 or Global.player_health <= 0.0:
		return
	var player_position = Global.player_node.global_position
	if tracking_player != Global.player_node:
		tracking_player = Global.player_node
		previous_player_position = player_position
	var touched = _player_touches_pickup(player_position)
	previous_player_position = player_position
	var distance = global_position.distance_to(player_position)
	if touched:
		_collect()
		return
	if distance <= attraction_distance * Global.pickup_range_multiplier:
		attracted = true
	if attracted:
		lifetime = max(lifetime, 3.0)
		var current_speed = attraction_speed
		if Global.player_node is CharacterBody2D:
			current_speed = max(current_speed, Global.player_node.velocity.length() + 200.0)
		global_position = global_position.move_toward(player_position, current_speed * delta)
		if _player_touches_pickup(player_position):
			_collect()


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


func _collect() -> void:
	if collected:
		return
	collected = true
	remove_from_group("heart_pickup")
	Global.heal_king(Global.heart_heal_amount)
	Global.heal_player(Global.heart_heal_amount * 0.5)
	queue_free()
