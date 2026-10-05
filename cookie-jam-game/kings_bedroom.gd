extends Node2D

const ASSASSIN_SCENE = preload("res://scenes/assasin.tscn")

@export var spawn_interval = 1

var spawn_timer: Timer


func _ready() -> void:

	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_spawn_enemy)
	add_child(spawn_timer)


func _spawn_enemy() -> void:
	var used_cells = $TileMapLayer.get_used_cells()

	if used_cells.is_empty():
		return

	var cell = used_cells.pick_random()

	var spawn_global_position = $TileMapLayer.to_global(
		$TileMapLayer.map_to_local(cell)
	)

	var enemy = ASSASSIN_SCENE.instantiate()
	var parent_node = get_parent()

	parent_node.add_child(enemy)
	enemy.global_position = spawn_global_position


func _process(delta: float) -> void:
	pass
