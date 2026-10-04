extends Node2D

func _ready() -> void:
	$TileMapLayer.scale = Vector2(7., 7.)
	$TileMapLayer2.scale = Vector2(7., 7.)
	$TileMapLayer3.scale = Vector2(7., 7.)

func _process(delta: float) -> void:
	pass
