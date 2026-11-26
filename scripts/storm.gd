extends Node2D

# each stage starts on its tick: tiles outside the centred safe area turn into storm
# damage is taken on every tick that ends on a storm tile
const STAGES = [
	{"tick": 0, "size": Vector2i(9, 5), "damage": 0},
	{"tick": 16, "size": Vector2i(7, 3), "damage": 2},
	{"tick": 28, "size": Vector2i(5, 3), "damage": 3},
	{"tick": 40, "size": Vector2i(3, 3), "damage": 5},
	{"tick": 54, "size": Vector2i(1, 1), "damage": 8},
]

# same red and strength as an attacked tile
const STORM_COLOR = Color(1.0, 0.25, 0.2)
const STORM_FILL = 0.3

# ticks played since the match began
var match_tick = 0

@onready var board = $"../Board"


func reset():
	match_tick = 0
	queue_redraw()


func advance():
	match_tick += 1
	queue_redraw()


func stage_index():
	var index = 0
	for i in range(STAGES.size()):
		if match_tick >= STAGES[i]["tick"]:
			index = i
	return index


func is_final_stage():
	return stage_index() == STAGES.size() - 1


# only valid before the final stage
func ticks_until_close():
	return STAGES[stage_index() + 1]["tick"] - match_tick


func current_damage():
	return STAGES[stage_index()]["damage"]


# safe area of a stage in tile coordinates
func safe_rect(index):
	var size = STAGES[index]["size"]
	var start = (Vector2i(board.WIDTH, board.HEIGHT) - size) / 2
	return Rect2i(start, size)


func damage_at(tile):
	if safe_rect(stage_index()).has_point(tile):
		return 0
	return current_damage()


func _draw():
	var safe = safe_rect(stage_index())
	for x in range(board.WIDTH):
		for y in range(board.HEIGHT):
			var tile = Vector2i(x, y)
			if not safe.has_point(tile):
				var tile_size = Vector2(board.TILE_SIZE, board.TILE_SIZE)
				draw_rect(Rect2(board.tile_to_pixel(tile), tile_size), Color(STORM_COLOR, STORM_FILL), true)
