extends CharacterBody2D

const XP_ORB_SCRIPT = preload("res://scripts/xp_orb.gd")
const HEART_SCRIPT = preload("res://scripts/heart.gd")

@export var speed = 160.0
@export var damage = 20.0

@export var max_health = 100.0

@export var xp_drop = 5.0

@export var heart_drop_chance = 0.08

@export var knockback_speed = 450.0
@export var knockback_deceleration = 1400.0

var health = 100.0

var touching_player = false
var touching_king = false

var can_attack = true

var knockback = false
var knockback_velocity = Vector2.ZERO


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	add_to_group("enemy")

	max_health *= Global.enemy_health_multiplier
	health = max_health

	speed *= Global.enemy_speed_multiplier
	damage *= Global.enemy_damage_multiplier


func _physics_process(delta: float) -> void:
	if health <= 0.0:
		_die()
		return

	$ProgressBar.value = health
	$ProgressBar.max_value = max_health

	if knockback:
		velocity = knockback_velocity

		knockback_velocity = knockback_velocity.move_toward(
			Vector2.ZERO,
			knockback_deceleration * delta
		)

	else:
		_handle_attack()
		_chase_target()

	move_and_slide()


func _handle_attack() -> void:
	if !can_attack:
		return

	if touching_king:
		if Global.damage_king(damage):
			can_attack = false
			$hit_timer.start()

			return

	if touching_player:
		if Global.damage_player(damage):
			can_attack = false
			$hit_timer.start()


func _chase_target() -> void:
	var target = _get_closest_target()

	if !is_instance_valid(target):
		velocity = Vector2.ZERO
		return

	velocity = global_position.direction_to(
		target.global_position
	) * speed


func _get_closest_target():
	var king = Global.king_node
	var player = Global.player_node

	var king_valid = is_instance_valid(king)
	var player_valid = is_instance_valid(player)

	if !king_valid and !player_valid:
		return null

	if !king_valid:
		return player

	if !player_valid:
		return king

	var king_distance = global_position.distance_squared_to(
		king.global_position
	)

	var player_distance = global_position.distance_squared_to(
		player.global_position
	)

	if king_distance < player_distance:
		return king

	return player


func _die() -> void:
	Global.kills += 1

	_drop_xp()

	if randf() <= heart_drop_chance:
		_drop_heart()

	queue_free()


func _drop_xp() -> void:
	var orb = XP_ORB_SCRIPT.new()

	get_parent().add_child(orb)

	orb.global_position = global_position
	orb.xp_value = xp_drop


func _drop_heart() -> void:
	var heart = HEART_SCRIPT.new()

	get_parent().add_child(heart)

	heart.global_position = global_position


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == Global.player_node:
		touching_player = true

	elif body == Global.king_node:
		touching_king = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == Global.player_node:
		touching_player = false

	elif body == Global.king_node:
		touching_king = false


func _on_hit_timer_timeout() -> void:
	can_attack = true


func _on_area_2d_area_entered(area: Area2D) -> void:
	if !area.is_in_group("weapon"):
		return

	if health <= 0.0:
		return

	var damage_dealt = min(
		Global.weapon_damage,
		health
	)

	health -= Global.weapon_damage

	if Global.lifesteal > 0.0:
		Global.heal_player(
			damage_dealt * Global.lifesteal
		)

	knockback_velocity = area.global_position.direction_to(
		global_position
	) * knockback_speed

	knockback = true

	$knockback_timer.start()


func _on_knockback_timer_timeout() -> void:
	knockback = false
