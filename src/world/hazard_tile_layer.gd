class_name HazardTileLayer
extends TileMapLayer
## Tile layer for hazard tiles such as spikes. At runtime it adds a Hazard area
## for every cell whose tile has hazard_damage > 0, sized by the tile's
## hazard_rect custom data (in tile pixels, from the tile's top-left).


func _ready() -> void:
	var half_tile := Vector2(tile_set.tile_size) * 0.5
	for cell in get_used_cells():
		var tile := get_cell_tile_data(cell)
		if tile == null:
			continue
		var damage: int = tile.get_custom_data("hazard_damage")
		if damage <= 0:
			continue
		var hurt_rect: Rect2 = tile.get_custom_data("hazard_rect")
		var hazard := Hazard.new()
		hazard.name = "Spike_%d_%d" % [cell.x, cell.y]
		hazard.position = map_to_local(cell) - half_tile + hurt_rect.position
		hazard.size = hurt_rect.size
		hazard.damage = damage
		hazard.pogoable = tile.get_custom_data("hazard_pogoable")
		add_child(hazard)
