extends Node2D

const ASSASSIN_SCENE = preload("res://scenes/assasin.tscn")

@export var minimum_spawn_distance = 650.0
@export var maximum_spawn_distance = 1100.0

@export var max_spawn_attempts = 50

@export var starting_spawn_interval = 1.25
@export var minimum_spawn_interval = 0.55

@export var spawn_interval_step = 0.07
@export var spawn_interval_step_time = 45.0

@export var wave_size_step_time = 90.0
@export var maximum_wave_size = 5

@export var starting_enemy_cap = 35
@export var enemy_cap_step = 8
@export var enemy_cap_step_time = 45.0
@export var maximum_enemy_cap = 160

var spawn_timer
var spawn_cells = []

var spawning_started = false


func _ready() -> void:
	add_to_group(
		"enemy_spawner_controller"
	)

	spawn_cells = (
		$TileMapLayer.get_used_cells()
	)

	spawn_timer = Timer.new()

	spawn_timer.one_shot = false
	spawn_timer.autostart = false

	spawn_timer.wait_time = (
		starting_spawn_interval
	)

	spawn_timer.timeout.connect(
		_spawn_wave
	)

	add_child(
		spawn_timer
	)


func start_spawning() -> void:
	if spawning_started:
		return

	if !Global.gameplay_started:
		return

	spawning_started = true

	spawn_timer.wait_time = (
		_get_spawn_interval()
	)

	spawn_timer.start()


func stop_spawning() -> void:
	spawning_started = false

	if is_instance_valid(
		spawn_timer
	):
		spawn_timer.stop()


func _spawn_wave() -> void:
	if !Global.gameplay_started:
		return

	if get_tree().paused:
		return

	var enemy_count = get_tree().get_nodes_in_group(
		"enemy"
	).size()

	var max_enemies = (
		_get_max_enemies()
	)

	if enemy_count >= max_enemies:
		return

	var amount = (
		_get_spawn_amount()
	)

	for i in range(amount):
		enemy_count = get_tree().get_nodes_in_group(
			"enemy"
		).size()

		if enemy_count >= max_enemies:
			break

		_spawn_enemy()

	spawn_timer.wait_time = (
		_get_spawn_interval()
	)


func _get_spawn_interval() -> float:
	var steps = int(
		Global.run_time /
		spawn_interval_step_time
	)

	var current_interval = (
		starting_spawn_interval -
		float(steps) *
		spawn_interval_step
	)

	return max(
		current_interval,
		minimum_spawn_interval
	)


func _get_spawn_amount() -> int:
	var amount = (
		1 +
		int(
			Global.run_time /
			wave_size_step_time
		)
	)

	return min(
		amount,
		maximum_wave_size
	)


func _get_max_enemies() -> int:
	var steps = int(
		Global.run_time /
		enemy_cap_step_time
	)

	var enemy_cap = (
		starting_enemy_cap +
		steps *
		enemy_cap_step
	)

	return min(
		enemy_cap,
		maximum_enemy_cap
	)


func _spawn_enemy() -> void:
	if !Global.gameplay_started:
		return

	if get_tree().paused:
		return

	var spawn_position = (
		_find_spawn_position()
	)

	if spawn_position == null:
		return

	var enemy = (
		ASSASSIN_SCENE.instantiate()
	)

	enemy.enemy_level = (
		Global.roll_enemy_level()
	)

	get_parent().add_child(
		enemy
	)

	enemy.global_position = (
		spawn_position
	)


func _find_spawn_position():
	if spawn_cells.is_empty():
		return null

	if !is_instance_valid(
		Global.player_node
	):
		return null

	var best_position = null
	var best_distance = -1.0

	for i in range(
		max_spawn_attempts
	):
		var cell = (
			spawn_cells.pick_random()
		)

		var position = $TileMapLayer.to_global(
			$TileMapLayer.map_to_local(
				cell
			)
		)

		var distance = position.distance_to(
			Global.player_node.global_position
		)

		if (
			distance >= minimum_spawn_distance
			and
			distance <= maximum_spawn_distance
		):
			return position

		if distance > best_distance:
			best_distance = distance
			best_position = position

	return best_position
