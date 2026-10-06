extends Node2D

var death_screen
var death_title
var death_stats

var dead = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	Global.gameplay_started = false

	get_tree().paused = true

	_create_death_screen()

	$CanvasLayer.process_mode = Node.PROCESS_MODE_ALWAYS

	get_tree().call_group(
		"enemy_spawner_controller",
		"stop_spawning"
	)

	get_tree().call_group(
		"xp_hud",
		"hide"
	)

	get_tree().call_group(
		"king_camera_controller",
		"set_king_camera_allowed",
		false
	)

	if Global.respawning:
		Global.respawning = false

		$CanvasLayer.visible = false

		get_tree().paused = false

		call_deferred("_start_gameplay")

		return

	$CanvasLayer.visible = true

	$CanvasLayer/AnimatedSprite2D.play(
		"default"
	)


func _process(delta: float) -> void:
	if dead:
		return

	if !Global.gameplay_started:
		return

	if Global.king_health <= 0.0:
		_show_death_screen(
			"THE KING HAS FALLEN"
		)

	elif Global.player_health <= 0.0:
		_show_death_screen(
			"YOU DIED"
		)


func _start_gameplay() -> void:
	Global.gameplay_started = true

	get_tree().paused = false

	get_tree().call_group(
		"xp_hud",
		"show"
	)

	get_tree().call_group(
		"king_camera_controller",
		"set_king_camera_allowed",
		true
	)

	get_tree().call_group(
		"enemy_spawner_controller",
		"start_spawning"
	)


func _create_death_screen() -> void:
	var layer = CanvasLayer.new()

	layer.layer = 500
	layer.process_mode = Node.PROCESS_MODE_ALWAYS

	add_child(layer)


	death_screen = ColorRect.new()

	death_screen.color = Color(
		0.04,
		0.0,
		0.0,
		0.94
	)

	death_screen.process_mode = Node.PROCESS_MODE_ALWAYS

	layer.add_child(death_screen)

	death_screen.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


	var center = VBoxContainer.new()

	center.process_mode = Node.PROCESS_MODE_ALWAYS

	death_screen.add_child(center)

	center.set_anchors_preset(
		Control.PRESET_CENTER
	)

	center.offset_left = -300.0
	center.offset_right = 300.0

	center.offset_top = -180.0
	center.offset_bottom = 180.0

	center.add_theme_constant_override(
		"separation",
		25
	)


	death_title = Label.new()

	death_title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	death_title.add_theme_font_size_override(
		"font_size",
		42
	)

	center.add_child(death_title)


	death_stats = Label.new()

	death_stats.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	death_stats.add_theme_font_size_override(
		"font_size",
		22
	)

	center.add_child(death_stats)


	var respawn_button = Button.new()

	respawn_button.text = "RESPAWN"

	respawn_button.custom_minimum_size = Vector2(
		300.0,
		70.0
	)

	respawn_button.add_theme_font_size_override(
		"font_size",
		26
	)

	respawn_button.process_mode = Node.PROCESS_MODE_ALWAYS

	respawn_button.pressed.connect(
		_respawn
	)

	center.add_child(respawn_button)

	death_screen.visible = false


func _show_death_screen(title: String) -> void:
	if dead:
		return

	dead = true

	Global.gameplay_started = false

	get_tree().call_group(
		"enemy_spawner_controller",
		"stop_spawning"
	)

	get_tree().call_group(
		"xp_hud",
		"hide"
	)

	get_tree().call_group(
		"king_camera_controller",
		"set_king_camera_allowed",
		false
	)

	death_title.text = title

	death_stats.text = (
		"LEVEL %d\nKILLS: %d\nSURVIVED: %d SECONDS" %
		[
			Global.level,
			Global.kills,
			int(Global.run_time)
		]
	)

	death_screen.visible = true

	get_tree().paused = true


func _respawn() -> void:
	Global.reset_run_progress()

	Global.respawning = true

	dead = false

	death_screen.visible = false

	get_tree().paused = false

	get_tree().reload_current_scene()


func _on_animated_sprite_2d_animation_finished() -> void:
	if dead:
		return

	$CanvasLayer.visible = false

	_start_gameplay()
