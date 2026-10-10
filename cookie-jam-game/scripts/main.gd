extends Node2D

var death_screen
var death_title
var death_stats
var pause_screen
var dead = false
var intro_finished = false
var manually_paused = false
var restarting = false
var completed = false
var ending_story
var replay_button
const STAGE_2 = preload("uid://u0ohrqd0cakc")

func _ready() -> void:
	next_stage()
	Global.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("stage_end_controller")
	for child in get_children():
		if child.process_mode == Node.PROCESS_MODE_INHERIT:
			child.process_mode = Node.PROCESS_MODE_PAUSABLE
	Global.gameplay_started = false
	get_tree().paused = true
	_create_death_screen()
	_create_pause_screen()
	$CanvasLayer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().call_group("enemy_spawner_controller", "stop_spawning")
	get_tree().call_group("xp_hud", "hide")
	get_tree().call_group("king_camera_controller", "set_king_camera_allowed", false)
	var intro = $CanvasLayer/AnimatedSprite2D
	if !intro.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		intro.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	if Global.respawning:
		Global.respawning = false
		$CanvasLayer.visible = false
		call_deferred("_start_gameplay")
		return
	$CanvasLayer.visible = true
	intro.play("default")
	var hint = Label.new()
	hint.text = "ENTER or SPACE to skip cutscene"
	hint.z_index = 101
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	$CanvasLayer.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -45.0
	hint.offset_bottom = -15.0


func _unhandled_key_input(event: InputEvent) -> void:
	if !(event is InputEventKey) or !event.pressed or event.echo or dead or completed or restarting:
		return
	var key = event.keycode if event.keycode != 0 else event.physical_keycode
	if !intro_finished and (key == KEY_ENTER or key == KEY_SPACE):
		$CanvasLayer/AnimatedSprite2D.stop()
		$CanvasLayer.visible = false
		_start_gameplay()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE and Global.gameplay_started and Global.pending_level_ups <= 0:
		_set_manual_pause(!manually_paused)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if dead or completed or !Global.gameplay_started:
		return
	if Global.king_health <= 0.0:
		_show_death_screen("THE KING HAS FALLEN")
	elif Global.player_health <= 0.0:
		_show_death_screen("YOU DIED")


func _start_gameplay() -> void:
	if dead or completed or restarting or Global.gameplay_started:
		return
	intro_finished = true
	Global.gameplay_started = true
	get_tree().paused = false
	get_tree().call_group("xp_hud", "show")
	get_tree().call_group("king_camera_controller", "set_king_camera_allowed", true)
	get_tree().call_group("enemy_spawner_controller", "start_spawning")


func _create_death_screen() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 500
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	death_screen = ColorRect.new()
	death_screen.color = Color(0.04, 0.0, 0.0, 0.94)
	death_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(death_screen)
	death_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center = CenterContainer.new()
	death_screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)
	death_title = Label.new()
	death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_title.add_theme_font_size_override("font_size", 38)
	death_title.add_theme_color_override("font_color", Color(1.0, 0.65, 0.4))
	box.add_child(death_title)
	ending_story = Label.new()
	ending_story.custom_minimum_size.x = min(620.0, max(get_viewport_rect().size.x - 40.0, 240.0))
	ending_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_story.add_theme_font_size_override("font_size", 22)
	ending_story.visible = false
	box.add_child(ending_story)
	death_stats = Label.new()
	death_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_stats.add_theme_font_size_override("font_size", 22)
	box.add_child(death_stats)
	replay_button = Button.new()
	replay_button.text = "TRY AGAIN"
	replay_button.custom_minimum_size = Vector2(320.0, 65.0)
	replay_button.add_theme_font_size_override("font_size", 24)
	replay_button.pressed.connect(_respawn)
	box.add_child(replay_button)
	death_screen.visible = false


func _create_pause_screen() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 150
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	pause_screen = ColorRect.new()
	pause_screen.color = Color(0.02, 0.025, 0.05, 0.82)
	layer.add_child(pause_screen)
	pause_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center = CenterContainer.new()
	pause_screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	var controls = Label.new()
	controls.text = "Aim with the mouse. Your sword attacks automatically.\nSpace: dodge    Escape: pause\nTouch the king to wake him. Collect hearts to heal.\nDefeat Grunkk and pick up his key to escape."
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 18)
	box.add_child(controls)
	var resume_button = Button.new()
	resume_button.text = "RESUME"
	resume_button.custom_minimum_size = Vector2(350.0, 60.0)
	resume_button.pressed.connect(_set_manual_pause.bind(false))
	box.add_child(resume_button)
	var restart_button = Button.new()
	restart_button.text = "RESTART"
	restart_button.custom_minimum_size = Vector2(350.0, 50.0)
	restart_button.pressed.connect(_respawn)
	box.add_child(restart_button)
	pause_screen.visible = false


func _set_manual_pause(value: bool) -> void:
	if dead or completed or restarting or !Global.gameplay_started or Global.pending_level_ups > 0:
		return
	manually_paused = value
	pause_screen.visible = value
	get_tree().paused = value
	get_tree().call_group("king_camera_controller", "set_king_camera_allowed", !value)


func _show_death_screen(title: String) -> void:
	if dead or completed:
		return
	dead = true
	Global.gameplay_started = false
	manually_paused = false
	pause_screen.visible = false
	get_tree().call_group("enemy_spawner_controller", "stop_spawning")
	get_tree().call_group("xp_hud", "hide")
	get_tree().call_group("king_camera_controller", "set_king_camera_allowed", false)
	if is_instance_valid(Global.player_node) and Global.player_node.has_method("close_gameplay_ui"):
		Global.player_node.close_gameplay_ui()
	ending_story.visible = false
	death_title.text = title
	var seconds = int(Global.run_time)
	death_stats.text = "LEVEL %d\nKILLS: %d\nSURVIVED: %02d:%02d" % [Global.level, Global.kills, seconds / 60, seconds % 60]
	death_screen.visible = true
	get_tree().paused = true
	
func stage_3():
	print("stage 3 test")
	
func _next_stage1() -> void:
	Global.run_time = 0.0
	Global.player_node.position = Vector2(112, 287)
	Global.king_node.position = Vector2(483, 241)
	Global.kills = 0
	var old_map = get_node_or_null("KingsBedroom")
	if is_instance_valid(old_map):
		old_map.queue_free()

	var new_tilemap = STAGE_2.instantiate()
	new_tilemap.name = "StageTwoMap"
	new_tilemap.z_index = -100
	add_child(new_tilemap)

	death_screen.visible = false
	completed = false
	manually_paused = false
	intro_finished = true

	Global.gameplay_started = true
	get_tree().paused = false

	get_tree().call_group("xp_hud", "show")
	get_tree().call_group("enemy_spawner_controller", "start_spawning")
	get_tree().call_group("king_camera_controller", "set_king_camera_allowed", true)
		
func next_stage() -> void:
	Global.run_time = 0.0
	Global.player_node.position = Vector2(112, 287)
	Global.king_node.position = Vector2(483, 241)
	Global.kills = 0
	var old_map = get_node_or_null("KingsBedroom")
	if is_instance_valid(old_map):
		old_map.queue_free()

	var new_tilemap = STAGE_2.instantiate()
	new_tilemap.name = "StageTwoMap"
	new_tilemap.z_index = -100
	add_child(new_tilemap)

	Global.gameplay_started = true
	get_tree().paused = false

	get_tree().call_group("xp_hud", "show")
	get_tree().call_group("enemy_spawner_controller", "start_spawning")
	get_tree().call_group("king_camera_controller", "set_king_camera_allowed", true)

func complete_stage_one() -> void:
	if completed or dead or restarting or !Global.gameplay_started or Global.player_health <= 0.0 or Global.king_health <= 0.0:
		return
	completed = true
	Global.gameplay_started = false
	manually_paused = false
	pause_screen.visible = false
	get_tree().call_group("enemy_spawner_controller", "stop_spawning")
	get_tree().call_group("xp_hud", "hide")
	get_tree().call_group("king_camera_controller", "set_king_camera_allowed", false)
	if is_instance_valid(Global.player_node) and Global.player_node.has_method("close_gameplay_ui"):
		Global.player_node.close_gameplay_ui()
	death_screen.color = Color(0.025, 0.04, 0.07, 0.97)
	death_title.text = "STAGE ONE COMPLETE"
	death_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	ending_story.text = "With Grunkk defeated, you take the castle key.\n\nYou wake the king and lead him through the gates before more assassins arrive.\n\nThe castle is behind you. The Goblin Duke's hunt is far from over."
	ending_story.visible = true
	var seconds = int(Global.run_time)
	death_stats.text = "TIME %02d:%02d    KILLS %d    LEVEL %d" % [seconds / 60, seconds % 60, Global.kills, Global.level]
	var respawn_callable = Callable(self, "_respawn")
	var next_stage_callable = Callable(self, "_next_stage1")

	if replay_button.pressed.is_connected(respawn_callable):
		replay_button.pressed.disconnect(respawn_callable)

	replay_button.text = "EXIT CASTLE - STAGE 2"

	if !replay_button.pressed.is_connected(next_stage_callable):
		replay_button.pressed.connect(next_stage_callable)

	death_screen.visible = true
	get_tree().paused = true


func _respawn() -> void:
	if restarting:
		return
	restarting = true
	Global.reset_run_progress()
	Global.respawning = true
	death_screen.visible = false
	pause_screen.visible = false
	call_deferred("_reload_run")


func _reload_run() -> void:
	get_tree().paused = false
	var result = get_tree().reload_current_scene()
	if result != OK:
		restarting = false
		dead = true
		death_title.text = "RESTART FAILED"
		death_stats.text = "The current scene could not be reloaded."
		death_screen.visible = true
		get_tree().paused = true


func _on_animated_sprite_2d_animation_finished() -> void:
	if dead or completed or intro_finished:
		return
	$CanvasLayer.visible = false
	_start_gameplay()
