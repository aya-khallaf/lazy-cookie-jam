extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().paused = true
	$CanvasLayer/AnimatedSprite2D.play("default")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.player_health <= 0 or Global.king_health <= 0:
		Global.player_health = 100
		Global.king_health = 100
		get_tree().reload_current_scene()


func _on_animated_sprite_2d_animation_finished() -> void:
	get_tree().paused = false
	$CanvasLayer.visible=false
