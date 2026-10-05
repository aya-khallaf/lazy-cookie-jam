extends Node2D

func _ready() -> void:
	$TileMapLayer.scale = Vector2(1., 1.)
	$TileMapLayer2.scale = Vector2(1., 1.)
	$TileMapLayer3.scale = Vector2(1., 1.)

func _process(delta: float) -> void:
	pass
