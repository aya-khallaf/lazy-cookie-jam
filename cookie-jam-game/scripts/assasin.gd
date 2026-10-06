extends CharacterBody2D

const XP_ORB_SCRIPT = preload("res://scripts/xp_orb.gd")
const HEART_SCRIPT = preload("res://scripts/heart.gd")

@export var enemy_level = 1

@export var base_speed = 125.0
@export var base_damage = 12.0
@export var base_health = 100.0
@export var base_xp_drop = 5.0

@export var health_multiplier_per_level = 1.10
@export var damage_multiplier_per_level = 1.055
@export var speed_multiplier_per_level = 1.0125
@export var xp_multiplier_per_level = 1.09

@export var maximum_speed = 190.0

@export var heart_drop_chance = 0.06

@export var knockback_speed = 450.0
@export var knockback_deceleration = 1400.0

@export var show_level_label = true

var speed = 125.0
var damage = 12.0

var max_health = 100.0
var health = 100.0

var xp_drop = 5.0

var touching_player = false
var touching_king = false

var can_attack = true

var knockback = false
var knockback_velocity = Vector2.ZERO

var dead = false

var level_label


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	add_to_group("enemy")

	_apply_level_stats()

	if show_level_label:
		_create_level_label()


func _apply_level_stats() -> void:
	enemy_level = max(
		enemy_level,
		1
	)

	var levels_above_one = (
		enemy_level - 1
	)

	max_health = (
		base_health *
		pow(
			health_multiplier_per_level,
			levels_above_one
		)
	)

	damage = (
		base_damage *
		pow(
			damage_multiplier_per_level,
			levels_above_one
		)
	)

	speed = (
		base_speed *
		pow(
			speed_multiplier_per_level,
			levels_above_one
		)
	)

	speed = min(
		speed,
		maximum_speed
	)

	xp_drop = (
		base_xp_drop *
		pow(
			xp_multiplier_per_level,
			levels_above_one
		)
	)

	max_health = round(max_health)
	damage = round(damage)
	speed = round(speed)
	xp_drop = round(xp_drop)

	health = max_health


func _create_level_label() -> void:
	level_label = Label.new()

	level_label.text = (
		"Lv. %d" %
		enemy_level
	)

	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	level_label.add_theme_font_size_override(
		"font_size",
		12
	)

	$ProgressBar.add_child(level_label)

	level_label.set_anchors_preset(
		Control.PRESET_TOP_WIDE
	)

	level_label.offset_left = 0.0
	level_label.offset_right = 0.0
	level_label.offset_top = -22.0
	level_label.offset_bottom = -2.0


func _physics_process(delta: float) -> void:
	if dead:
		return

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

	velocity = (
		global_position.direction_to(
			target.global_position
		) *
		speed
	)


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


func take_damage(
	amount: float,
	source_position: Vector2,
	extra_knockback: float = 1.0
) -> void:

	if dead:
		return

	if health <= 0.0:
		return

	health -= amount

	var knockback_resistance = clamp(
		1.0 -
		float(enemy_level - 1) *
		0.015,
		0.65,
		1.0
	)

	knockback_velocity = (
		source_position.direction_to(
			global_position
		) *
		knockback_speed *
		knockback_resistance *
		extra_knockback
	)

	knockback = true

	$knockback_timer.start()

	if health <= 0.0:
		_die()


func _die() -> void:
	if dead:
		return

	dead = true

	Global.kills += 1

	_drop_xp()

	var final_heart_chance = clamp(
		heart_drop_chance +
		Global.heart_drop_chance_bonus,
		0.0,
		0.35
	)

	if randf() <= final_heart_chance:
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
	if dead:
		return

	if !area.is_in_group("weapon"):
		return

	var hit_damage = Global.weapon_damage

	if randf() <= Global.sword_crit_chance:
		hit_damage *= Global.sword_crit_multiplier

	take_damage(
		hit_damage,
		area.global_position,
		Global.sword_knockback_multiplier
	)


func _on_knockback_timer_timeout() -> void:
	knockback = false
