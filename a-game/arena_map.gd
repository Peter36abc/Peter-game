extends Node2D

@export var legacy_tile_map_path: NodePath


func _ready() -> void:
	var legacy_tile_map := get_node_or_null(legacy_tile_map_path) as TileMap
	if legacy_tile_map != null:
		legacy_tile_map.clear()
