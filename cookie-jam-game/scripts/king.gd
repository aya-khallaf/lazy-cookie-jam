extends CharacterBody2D

@export var speed := 80.0
@export var wander_speed := 35.0
@export var follow_distance := 45.0
@export var wander_distance := 120.0

var distracted := true
var sleeping := false

var wander_target := Vector2.ZERO
var action_timer := 0.0
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	Global.king_node = self
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_choose_distracted_action()


func _physics_process(delta: float) -> void:
	$ProgressBar.max_value = Global.king_max_health
	$ProgressBar.value = Global.king_health
	if !distracted:
		
		sleeping = false
		_follow_player()
		animated_sprite_2d.play("awake walk")
	else:
		_handle_distracted(delta)

	move_and_slide()


func _follow_player() -> void:
	if !is_instance_valid(Global.player_node):
		velocity = Vector2.ZERO
		return

	var direction := global_position.direction_to(Global.player_node.global_position)
	var distance := global_position.distance_to(Global.player_node.global_position)

	if distance > follow_distance:
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO


func _handle_distracted(delta: float) -> void:
	action_timer -= delta

	if action_timer <= 0.0:
		_choose_distracted_action()

	if sleeping:
		animated_sprite_2d.play("sleep idle")
		velocity = Vector2.ZERO
		return
		
	animated_sprite_2d.play("sleep walk")
	var distance := global_position.distance_to(wander_target)

	if distance > 10.0:
		var direction := global_position.direction_to(wander_target)
		velocity = direction * wander_speed
	else:
		velocity = Vector2.ZERO


func _choose_distracted_action() -> void:
	if randf() < 0.5:
		_sleep()
	else:
		_wander()


func _sleep() -> void:
	sleeping = true
	velocity = Vector2.ZERO
	action_timer = randf_range(2.0, 6.0)


func _wander() -> void:
	sleeping = false

	wander_target = global_position + Vector2(
		randf_range(-wander_distance, wander_distance),
		randf_range(-wander_distance, wander_distance)
	)

	action_timer = randf_range(2.0, 5.0)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == Global.player_node:
		distracted=false
		$sleep_timer.wait_time=randf_range(3.,15.)
		$sleep_timer.start()


func _on_area_2d_body_exited(body: Node2D) -> void:
	pass # Replace with function body.


func _on_sleep_timer_timeout() -> void:
	distracted=true
