extends Node2D


func _ready() -> void:
	if Global.respawning:
		Global.respawning = false

		get_tree().paused = false
		$CanvasLayer.visible = false

		get_tree().call_group("xp_hud", "show")
		return

	get_tree().paused = true

	$CanvasLayer.visible = true

	$CanvasLayer/AnimatedSprite2D.play("default")

	call_deferred("_hide_xp_hud")


func _hide_xp_hud() -> void:
	get_tree().call_group("xp_hud", "hide")


func _process(delta: float) -> void:
	if (
		Global.player_health <= 0.0 or
		Global.king_health <= 0.0
	):
		_respawn()


func _respawn() -> void:
	Global.reset_run_progress()

	Global.respawning = true

	get_tree().paused = false

	get_tree().reload_current_scene()


func _on_animated_sprite_2d_animation_finished() -> void:
	get_tree().paused = false

	$CanvasLayer.visible = false

	get_tree().call_group("xp_hud", "show")
