extends Marker2D

@export var swing_duration = 0.16
@export var recovery_duration = 0.05
@export var swing_arc_degrees = 125.0
@export var weapon_tip_distance = 90.0
@export var trail_width = 14.0
@export var trail_lifetime = 0.14
@export var weapon_angle_offset_degrees = 90.0

var attacking = false
var recovering = false

var swing_progress = 0.0
var recovery_timer = 0.0

var attack_direction = 0.0
var swing_direction = 1.0

var original_scale = Vector2.ONE

var trail
var trail_points = []
var trail_ages = []


func _ready() -> void:
	visible = false
	original_scale = scale

	trail = Line2D.new()
	trail.width = trail_width
	trail.default_color = Color(1.0, 0.9, 0.5, 0.95)
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.z_as_relative = false
	trail.z_index = 100

	get_parent().add_child(trail)


func _process(delta: float) -> void:
	_update_trail(delta)

	if attacking:
		_update_attack(delta)
		return

	if recovering:
		recovery_timer -= delta

		if recovery_timer <= 0.0:
			recovering = false

	if Input.is_action_pressed("attack") and !recovering:
		_start_attack()


func _start_attack() -> void:
	attacking = true
	swing_progress = 0.0
	visible = true

	attack_direction = global_position.angle_to_point(get_global_mouse_position())

	swing_direction *= -1.0

	trail_points.clear()
	trail_ages.clear()
	trail.clear_points()


func _update_attack(delta: float) -> void:
	swing_progress += delta / swing_duration

	var t = clamp(swing_progress, 0.0, 1.0)

	var half_arc = deg_to_rad(swing_arc_degrees) * 0.5

	var start_angle = attack_direction - half_arc * swing_direction
	var end_angle = attack_direction + half_arc * swing_direction

	var eased = _ease_out_quart(t)

	var swing_angle = lerp_angle(
		start_angle,
		end_angle,
		eased
	)

	rotation = swing_angle + deg_to_rad(weapon_angle_offset_degrees)

	var punch = sin(t * PI)

	scale = original_scale * Vector2(
		1.0 + punch * 0.05,
		1.0 + punch * 0.10
	)

	_add_trail_point(swing_angle)

	if t >= 1.0:
		_finish_attack()


func _finish_attack() -> void:
	attacking = false
	recovering = true
	recovery_timer = recovery_duration

	visible = false
	scale = original_scale


func _add_trail_point(swing_angle: float) -> void:
	if !is_instance_valid(trail):
		return

	var tip_global = global_position + Vector2.from_angle(swing_angle) * weapon_tip_distance

	var trail_position = trail.to_local(tip_global)

	trail_points.append(trail_position)
	trail_ages.append(0.0)

	if trail_points.size() > 24:
		trail_points.pop_front()
		trail_ages.pop_front()

	_rebuild_trail()


func _update_trail(delta: float) -> void:
	if !is_instance_valid(trail):
		return

	for i in range(trail_ages.size() - 1, -1, -1):
		trail_ages[i] += delta

		if trail_ages[i] >= trail_lifetime:
			trail_ages.remove_at(i)
			trail_points.remove_at(i)

	_rebuild_trail()


func _rebuild_trail() -> void:
	if !is_instance_valid(trail):
		return

	trail.clear_points()

	if trail_points.size() < 2:
		return

	for point in trail_points:
		trail.add_point(point)

	var fade = 1.0

	if trail_ages.size() > 0:
		fade = 1.0 - trail_ages[0] / trail_lifetime

	trail.modulate.a = clamp(fade, 0.0, 1.0)
	trail.width = max(trail_width * fade, 2.0)


func _ease_out_quart(value: float) -> float:
	return 1.0 - pow(1.0 - value, 4.0)
