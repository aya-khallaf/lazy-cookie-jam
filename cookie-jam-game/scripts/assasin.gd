extends CharacterBody2D

@export var speed := 160.0
var touching_player := false
var touching_king := false
var can_attack := true
var knockback := false
var health := 100
var max_health := 100

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func _physics_process(delta: float) -> void:
	if health <= 0:
		if Global.king_health<Global.king_max_health:
			Global.king_health+=1
		if Global.player_health<Global.player_max_health:
			Global.player_health+=1
		queue_free()
	$ProgressBar.value = health
	$ProgressBar.max_value = max_health
	if knockback:
		velocity = -(global_position.direction_to(Global.player_node.global_position) * speed)
	else:
		var target = _get_closest_target()
		
		if touching_king and can_attack:
			Global.king_health -= 20
			can_attack = false
			$hit_timer.start()
		if touching_player and can_attack:
			Global.player_health -= 20
			can_attack = false
			$hit_timer.start()
			
		if is_instance_valid(target):
			velocity = global_position.direction_to(target.global_position) * speed

	move_and_slide()


func _get_closest_target() -> Node2D:
	var king = Global.king_node
	var player = Global.player_node
	var king_distance := global_position.distance_squared_to(king.global_position)
	var player_distance := global_position.distance_squared_to(player.global_position)

	if king_distance < player_distance:
		return king

	return player

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
	if area.is_in_group("weapon"):
		$knockback_timer.start()
		knockback = true
		health -= 20


func _on_knockback_timer_timeout() -> void:
	knockback = false
