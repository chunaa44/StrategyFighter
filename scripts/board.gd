extends Node2D

const WIDTH = 9
const HEIGHT = 5
const TILE_SIZE = 96
const OFFSET = Vector2(208, 48)


func is_inside_board(tile):
	if tile.x < 0:
		return false
	if tile.x >= WIDTH:
		return false
	if tile.y < 0:
		return false
	if tile.y >= HEIGHT:
		return false
	return true


func tile_to_pixel(tile):
	var pixel_x = OFFSET.x + tile.x * TILE_SIZE
	var pixel_y = OFFSET.y + tile.y * TILE_SIZE
	return Vector2(pixel_x, pixel_y)


# where a slide from start along aim ends: it stops at the board edge
# and in front of the blocking tile
func slide_end(start, aim, slide, blocker):
	var tile = start
	for step in range(slide):
		var next_tile = tile + aim
		if not is_inside_board(next_tile):
			break
		if next_tile == blocker:
			break
		tile = next_tile
	return tile


func _draw():
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var tile_position = tile_to_pixel(Vector2i(x, y))
			var tile_rect = Rect2(tile_position, Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(tile_rect, Color(0.2, 0.2, 0.2), true)
			draw_rect(tile_rect, Color.WHITE, false, 2.0)
