extends Node2D

const ASSASSIN_SCENE = preload("res://scenes/assasin.tscn")

@export var spawn_interval = 1.8
@export var minimum_spawn_interval = 0.5

@export var minimum_spawn_distance = 650.0
@export var maximum_spawn_distance = 1100.0

@export var max_enemies = 300
@export var max_spawn_attempts = 50

var spawn_timer: Timer
var spawn_cells = []


func _ready() -> void:
	spawn_cells = $TileMapLayer.get_used_cells()

	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval

	spawn_timer.timeout.connect(_spawn_wave)

	add_child(spawn_timer)

	spawn_timer.start()


func _spawn_wave() -> void:
	if spawn_cells.is_empty():
		return

	if get_tree().get_nodes_in_group("enemy").size() >= max_enemies:
		return

	var amount = 1 + int(Global.run_time / 45.0)

	amount = min(amount, 6)

	for i in range(amount):
		if get_tree().get_nodes_in_group("enemy").size() >= max_enemies:
			break

		_spawn_enemy()

	spawn_timer.wait_time = max(
		spawn_interval / (1.0 + Global.run_time / 90.0),
		minimum_spawn_interval
	)


func _spawn_enemy() -> void:
	var spawn_position = _find_spawn_position()

	if spawn_position == null:
		return

	var enemy = ASSASSIN_SCENE.instantiate()

	get_parent().add_child(enemy)

	enemy.global_position = spawn_position


func _find_spawn_position():
	if spawn_cells.is_empty():
		return null

	if !is_instance_valid(Global.player_node):
		var random_cell = spawn_cells.pick_random()

		return $TileMapLayer.to_global(
			$TileMapLayer.map_to_local(random_cell)
		)

	var best_position = null
	var best_distance = -1.0

	for i in range(max_spawn_attempts):
		var cell = spawn_cells.pick_random()

		var position = $TileMapLayer.to_global(
			$TileMapLayer.map_to_local(cell)
		)

		var distance = position.distance_to(
			Global.player_node.global_position
		)

		if distance >= minimum_spawn_distance and distance <= maximum_spawn_distance:
			return position

		if distance > best_distance:
			best_distance = distance
			best_position = position

	return best_position
