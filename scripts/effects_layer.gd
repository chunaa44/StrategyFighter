extends Node2D

const ATTACK_COLOR = Color(1.0, 0.25, 0.2)
const GRAB_COLOR = Color(1.0, 0.65, 0.1)
const GUARD_COLOR = Color(0.3, 0.8, 1.0)
const IMPACT_COLOR = Color(1.0, 1.0, 1.0)
const DASH_COLOR = Color(0.75, 0.85, 1.0)

const TEXT_TIME = 0.6
const TEXT_RISE = 30.0
const TEXT_WIDTH = 100.0
const TEXT_SIZE = 22

const GUARD_INSET = 5.0
const GUARD_WIDTH = 6.0

# marks live for one tick, texts fade out on their own timer
var marks = []
var texts = []
var main


func setup(main_node):
	main = main_node


func clear():
	marks.clear()
	texts.clear()


func clear_tick():
	marks.clear()


func _process(delta):
	var i = texts.size() - 1
	while i >= 0:
		texts[i]["age"] += delta
		if texts[i]["age"] >= TEXT_TIME:
			texts.remove_at(i)
		i -= 1
	queue_redraw()


func tile_rect(tile):
	return Rect2(main.tile_to_pixel(tile), Vector2(main.TILE_SIZE, main.TILE_SIZE))


func tile_center(tile):
	return main.tile_to_pixel(tile) + Vector2(main.TILE_SIZE, main.TILE_SIZE) / 2.0


func action_color(action_name):
	if action_name == "Grab":
		return GRAB_COLOR
	return ATTACK_COLOR


# tiles a strike or grab covers, limited to the board
func reach_tiles(fighter):
	var tiles = []
	var reach = Actions.DATA[fighter.current_action]["range"]
	for step in range(1, reach + 1):
		var tile = fighter.grid_position + fighter.aim * step
		if main.is_inside_board(tile):
			tiles.append(tile)
	return tiles


func add_tiles(tiles, color):
	marks.append({"kind": "tiles", "tiles": tiles, "color": color})


func add_guard_mark(tile, aim, color):
	marks.append({"kind": "guard", "tile": tile, "aim": aim, "color": color})


func add_text(tile, text, color, offset = Vector2(0.0, 0.0)):
	var pos = tile_center(tile) + Vector2(-TEXT_WIDTH / 2.0, -10.0) + offset
	texts.append({"pos": pos, "text": text, "color": color, "age": 0.0})


# called every tick for each fighter, only draws while the block is active
func show_guard(fighter):
	if fighter.is_guarding():
		add_guard_mark(fighter.grid_position, fighter.aim, GUARD_COLOR)


# the tiles a dash or lunge travelled over on its active tick
func show_slide(from_tile, to_tile, action_name):
	if from_tile == to_tile:
		return
	var color = DASH_COLOR
	if action_name == "Lunge":
		color = ATTACK_COLOR
	add_tiles(Actions.path_tiles(from_tile, to_tile), color)


# two slides that touched the same tile and cancelled each other
func show_clash(tile1, tile2):
	add_text(tile1, "Clash", IMPACT_COLOR)
	add_text(tile2, "Clash", IMPACT_COLOR)


# called every tick for each attacker, before hits clear any action
func show_result(attacker, defender, action_name, result):
	if result == "none":
		return

	var reach = reach_tiles(attacker)
	var color = action_color(action_name)

	# the covered tiles always use the action colour, the result only adds extras
	add_tiles(reach, color)

	if result == "beaten":
		add_text(attacker.grid_position, "Beaten", color)
	elif result == "blocked":
		add_guard_mark(defender.grid_position, defender.aim, IMPACT_COLOR)
		add_text(defender.grid_position, "Blocked", GUARD_COLOR)
	elif result == "hit":
		add_tiles([defender.grid_position], IMPACT_COLOR)
		add_text(defender.grid_position, "-" + str(Actions.DATA[action_name]["damage"]), color)


func _draw():
	if main == null:
		return

	for mark in marks:
		if mark["kind"] == "tiles":
			draw_tiles(mark["tiles"], mark["color"])
		else:
			draw_guard_sides(mark["tile"], mark["aim"], mark["color"])

	for text in texts:
		draw_floating_text(text)


func draw_tiles(tiles, color):
	var fill = Color(color, 0.4)
	for tile in tiles:
		var rect = tile_rect(tile)
		draw_rect(rect, fill, true)
		draw_rect(rect.grow(-3), color, false, 3.0)


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


func draw_floating_text(text):
	var fade = 1.0 - text["age"] / TEXT_TIME
	var pos = text["pos"] + Vector2(0.0, -TEXT_RISE * text["age"] / TEXT_TIME)
	var font = ThemeDB.fallback_font
	draw_string_outline(font, pos, text["text"], HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, TEXT_SIZE, 4, Color(0, 0, 0, fade))
	draw_string(font, pos, text["text"], HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, TEXT_SIZE, Color(text["color"], fade))
