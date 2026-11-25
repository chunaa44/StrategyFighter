extends Node2D

const ATTACK_COLOR = Color(1.0, 0.25, 0.2)
const GRAB_COLOR = Color(1.0, 0.65, 0.1)
const BLUE_COLOR = Color(0.3, 0.8, 1.0)
const IMPACT_COLOR = Color(1.0, 1.0, 1.0)

const GUARD_INSET = 5.0
const GUARD_WIDTH = 6.0
const SPOT_INSET = 14.0

const PREVIEW_FILL = 0.18
const PREVIEW_LINE = 0.55
const PREVIEW_PULSE_SPEED = 6.0

# marks live for one tick
var marks = []
# the ghost of the pick being decided, kept apart from the combat marks
var preview = []
var preview_time = 0.0

@onready var board = $"../Board"


func clear():
	marks.clear()
	preview.clear()


func clear_tick():
	marks.clear()


func clear_preview():
	preview.clear()


func _process(delta):
	preview_time += delta
	queue_redraw()


func tile_rect(tile):
	return Rect2(board.tile_to_pixel(tile), Vector2(board.TILE_SIZE, board.TILE_SIZE))


func action_color(action_name):
	if action_name == "Grab":
		return GRAB_COLOR
	return ATTACK_COLOR


# tiles in a straight line from origin, limited to the board
func line_tiles(origin, aim, reach):
	var tiles = []
	for step in range(1, reach + 1):
		var tile = origin + aim * step
		if board.is_inside_board(tile):
			tiles.append(tile)
	return tiles


func add_tiles(tiles, color):
	marks.append({"kind": "tiles", "tiles": tiles, "color": color})


func add_guard_mark(tile, aim, color):
	marks.append({"kind": "guard", "tile": tile, "aim": aim, "color": color})


# called every tick for each fighter, only draws while the block is active
func show_guard(fighter):
	if fighter.is_guarding():
		add_guard_mark(fighter.grid_position, fighter.aim, BLUE_COLOR)


# the tiles a dash or lunge travelled over on its active tick
func show_slide(from_tile, to_tile, action_name):
	if from_tile == to_tile:
		return
	var color = BLUE_COLOR
	if action_name == "Lunge":
		color = ATTACK_COLOR
	add_tiles(Actions.path_tiles(from_tile, to_tile), color)


# two slides that touched the same tile and cancelled each other
func show_clash(tile1, tile2):
	add_tiles([tile1, tile2], IMPACT_COLOR)


# the tiles a strike or grab covered, a landed hit marks the victim, a block outlines the guard
# called before hits clear the action
func show_result(attacker, defender, action_name, result):
	if result == "none":
		return

	var reach = Actions.DATA[action_name]["range"]
	add_tiles(line_tiles(attacker.grid_position, attacker.aim, reach), action_color(action_name))

	if result == "hit":
		add_tiles([defender.grid_position], IMPACT_COLOR)
	elif result == "blocked":
		add_guard_mark(defender.grid_position, defender.aim, IMPACT_COLOR)


# ghost of a pick that has not been confirmed yet, drawn from where the fighter stands
# a rush looks the same whether it is a dash or a lunge, only the strike tile tells them apart
func show_preview(fighter, other, action_name, aim):
	preview.clear()
	var start = fighter.grid_position

	if action_name == "Hold":
		return

	if action_name == "Block":
		preview.append({"kind": "guard", "tile": start, "aim": aim, "color": BLUE_COLOR})
		return

	var data = Actions.DATA[action_name]
	var end = board.slide_end(start, aim, data["slide"], other.grid_position)

	if end != start:
		preview.append({"kind": "tiles", "tiles": Actions.path_tiles(start, end), "color": BLUE_COLOR})
		preview.append({"kind": "spot", "tile": end})

	if data["range"] > 0:
		preview.append({"kind": "tiles", "tiles": line_tiles(end, aim, data["range"]), "color": action_color(action_name)})


func _draw():
	draw_preview()

	for mark in marks:
		if mark["kind"] == "tiles":
			draw_tiles(mark["tiles"], mark["color"])
		else:
			draw_guard_sides(mark["tile"], mark["aim"], mark["color"])


# faint and pulsing so it never reads as something that is happening
func draw_preview():
	var pulse = 0.7 + 0.3 * sin(preview_time * PREVIEW_PULSE_SPEED)
	for mark in preview:
		if mark["kind"] == "tiles":
			draw_tiles(mark["tiles"], mark["color"], PREVIEW_FILL * pulse, PREVIEW_LINE * pulse)
		elif mark["kind"] == "guard":
			draw_guard_sides(mark["tile"], mark["aim"], Color(mark["color"], 0.8 * pulse))
		else:
			draw_spot(mark["tile"], 0.9 * pulse)


func draw_tiles(tiles, color, fill_alpha = 0.4, line_alpha = 1.0):
	var fill = Color(color, fill_alpha)
	var line = Color(color, line_alpha)
	for tile in tiles:
		var rect = tile_rect(tile)
		draw_rect(rect, fill, true)
		draw_rect(rect.grow(-3), line, false, 3.0)


# outline of where the fighter would stand
func draw_spot(tile, alpha):
	var rect = tile_rect(tile).grow(-SPOT_INSET)
	draw_rect(rect, Color(1.0, 1.0, 1.0, alpha), false, 2.0)


# the three guarded directions are drawn as one unbroken run along the tile border
func draw_guard_sides(tile, aim, color):
	var rect = tile_rect(tile).grow(-GUARD_INSET)
	var index = Actions.direction_index(aim)
	for offset in [-1, 0, 1]:
		var direction = Actions.DIRECTION_VECTORS[posmod(index + offset, 8)]
		draw_polyline(guard_points(rect, direction), color, GUARD_WIDTH)


# a side is the middle third of an edge, a corner is the two thirds that meet there
func guard_points(rect, direction):
	var left = rect.position.x
	var right = rect.end.x
	var top = rect.position.y
	var bottom = rect.end.y
	var arm = rect.size.x / 3.0

	if direction.x != 0 and direction.y != 0:
		var corner_x = left
		if direction.x > 0:
			corner_x = right
		var corner_y = top
		if direction.y > 0:
			corner_y = bottom
		return PackedVector2Array([
			Vector2(corner_x - direction.x * arm, corner_y),
			Vector2(corner_x, corner_y),
			Vector2(corner_x, corner_y - direction.y * arm),
		])

	if direction.y < 0:
		return PackedVector2Array([Vector2(left + arm, top), Vector2(right - arm, top)])
	if direction.y > 0:
		return PackedVector2Array([Vector2(left + arm, bottom), Vector2(right - arm, bottom)])
	if direction.x < 0:
		return PackedVector2Array([Vector2(left, top + arm), Vector2(left, bottom - arm)])
	return PackedVector2Array([Vector2(right, top + arm), Vector2(right, bottom - arm)])
