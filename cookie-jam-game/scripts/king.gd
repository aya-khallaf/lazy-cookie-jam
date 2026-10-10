extends CharacterBody2D

@export var speed = 80.0
@export var wander_speed = 35.0
@export var follow_distance = 45.0
@export var wander_distance = 120.0
@export var sleep_heal_per_second = 2.0
@export var sleep_walk_heal_per_second	 = 0.25

var distracted = true
var sleeping = false
var wander_target = Vector2.ZERO
var action_timer = 0.0
var player_in_wake_range = false
var ignored_player = null
var previous_health = 100.0
var time_since_damage = 10.0
var flash_timer = 0.0
var stuck_timer = 0.0
var status_time = 0.0
var original_modulate = Color.WHITE

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Global.king_node = self
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	previous_health = Global.king_health
	original_modulate = animated_sprite_2d.modulate
	_choose_distracted_action()


func _exit_tree() -> void:
	if Global.king_node == self:
		Global.king_node = null


func _physics_process(delta: float) -> void:
	$ProgressBar.max_value = Global.king_max_health
	$ProgressBar.value = Global.king_health
	if Global.king_health > Global.king_max_health:
		Global.king_health = Global.king_max_health
	if !Global.gameplay_started or Global.king_health <= 0.0:
		velocity = Vector2.ZERO
		return
	if is_instance_valid(Global.player_node) and ignored_player != Global.player_node:
		if Global.player_node is PhysicsBody2D:
			add_collision_exception_with(Global.player_node)
			Global.player_node.add_collision_exception_with(self)
		ignored_player = Global.player_node
	time_since_damage += delta
	status_time += delta
	if Global.king_health > previous_health:
		flash_timer = 0.0
	elif Global.king_health < previous_health:
		flash_timer = 0.16
		time_since_damage = 0.0

	previous_health = Global.king_health
	flash_timer = max(flash_timer - delta, 0.0)
	animated_sprite_2d.modulate = Color(1.0, 0.35, 0.3) if flash_timer > 0.0 else original_modulate
	if !distracted:
		sleeping = false
		_follow_player()
		animated_sprite_2d.play("awake walk")
	else:
		_handle_distracted(delta)
	var previous_position = global_position
	var trying_to_move = velocity.length_squared() > 1.0
	move_and_slide()
	if distracted and !sleeping and trying_to_move and global_position.distance_squared_to(previous_position) < 0.04:
		stuck_timer += delta
		if stuck_timer >= 0.5:
			_wander()
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
	queue_redraw()


func _follow_player() -> void:
	if !is_instance_valid(Global.player_node):
		velocity = Vector2.ZERO
		return
	var distance = global_position.distance_to(Global.player_node.global_position)
	var current_speed = min(speed * Global.king_speed_multiplier, max(distance - follow_distance, 0.0) * 6.0)
	velocity = global_position.direction_to(Global.player_node.global_position) * current_speed


func _handle_distracted(delta: float) -> void:
	action_timer -= delta
	if action_timer <= 0.0:
		_choose_distracted_action()
	if sleeping:
		if time_since_damage >= 1.0:
			Global.heal_king(sleep_heal_per_second * delta)
		animated_sprite_2d.play("sleep idle")
		velocity = Vector2.ZERO
		return
	if time_since_damage >= 1.0:
		Global.heal_king(sleep_walk_heal_per_second * delta)
	animated_sprite_2d.play("sleep walk")
	if global_position.distance_to(wander_target) > 10.0:
		velocity = global_position.direction_to(wander_target) * wander_speed * Global.king_speed_multiplier
	else:
		velocity = Vector2.ZERO


func wake_up(minimum_awake_time: float = 0.0) -> void:
	if Global.king_health <= 0.0:
		return
	distracted = false
	sleeping = false
	var awake_time = max(randf_range(2.0, 3.5), minimum_awake_time)
	$sleep_timer.wait_time = awake_time
	$sleep_timer.start()
	queue_redraw()


func _choose_distracted_action() -> void:
	if randf() < 0.5:
		_sleep()
	else:
		_wander()


func _sleep() -> void:
	sleeping = true
	velocity = Vector2.ZERO
	action_timer = randf_range(1.0, 2.0)


func _wander() -> void:
	sleeping = false
	wander_target = global_position + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * wander_distance
	action_timer = randf_range(2.0, 5.0)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == Global.player_node:
		player_in_wake_range = true
		wake_up()


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == Global.player_node:
		player_in_wake_range = false


func _on_sleep_timer_timeout() -> void:
	if player_in_wake_range:
		wake_up()
		return
	distracted = true
	_choose_distracted_action()


func _draw() -> void:
	if !Global.gameplay_started:
		return
	if sleeping:
		draw_string(ThemeDB.fallback_font, Vector2(12.0, -40.0 - sin(status_time * 2.0) * 4.0), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(0.6, 0.85, 1.0))
	elif distracted:
		draw_string(ThemeDB.fallback_font, Vector2(12.0, -40.0), "...", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.8, 0.85, 1.0))
