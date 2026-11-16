extends Node2D

const BOARD_WIDTH = 7
const BOARD_HEIGHT = 3
const TILE_SIZE = 100
const BOARD_OFFSET = Vector2(100, 50)
const TICKS_PER_TURN = 4
const TICK_DELAY = 0.25

@onready var fighter1 = $Fighter1
@onready var fighter2 = $Fighter2


func _ready():
	fighter1.grid_position = Vector2i(0, 1)
	fighter1.facing = 1
	fighter1.set_color(Color.CORNFLOWER_BLUE)

	fighter2.grid_position = Vector2i(6, 1)
	fighter2.facing = -1
	fighter2.set_color(Color.INDIAN_RED)

	update_fighter_positions()
	
	$PickScreen.both_picked.connect(on_both_picked)


func is_inside_board(tile):
	if tile.x < 0:
		return false
	if tile.x >= BOARD_WIDTH:
		return false
	if tile.y < 0:
		return false
	if tile.y >= BOARD_HEIGHT:
		return false
	return true


func tile_to_pixel(tile):
	var pixel_x = BOARD_OFFSET.x + tile.x * TILE_SIZE
	var pixel_y = BOARD_OFFSET.y + tile.y * TILE_SIZE
	return Vector2(pixel_x, pixel_y)


func update_fighter_positions():
	fighter1.position = tile_to_pixel(fighter1.grid_position)
	fighter2.position = tile_to_pixel(fighter2.grid_position)


func try_move(fighter, direction):
	var new_tile = fighter.grid_position + direction
	if is_inside_board(new_tile):
		fighter.grid_position = new_tile
		update_fighter_positions()


func _draw():
	for x in range(BOARD_WIDTH):
		for y in range(BOARD_HEIGHT):
			var tile_position = tile_to_pixel(Vector2i(x, y))
			var tile_rect = Rect2(tile_position, Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(tile_rect, Color(0.2, 0.2, 0.2), true)
			draw_rect(tile_rect, Color.WHITE, false, 2.0)


# Temporary test controls, we will delete these when the pick screen exists
func _input(event):
	if event.is_action_pressed("ui_right"):
		try_move(fighter1, Vector2i(1, 0))
	if event.is_action_pressed("ui_left"):
		try_move(fighter1, Vector2i(-1, 0))
	if event.is_action_pressed("ui_up"):
		try_move(fighter1, Vector2i(0, -1))
	if event.is_action_pressed("ui_down"):
		try_move(fighter1, Vector2i(0, 1))
		
func direction_from_name(direction_name):
	if direction_name == "Up":
		return Vector2i(0, -1)
	elif direction_name == "Down":
		return Vector2i(0, 1)
	elif direction_name == "Left":
		return Vector2i(-1, 0)
	else:
		return Vector2i(1, 0)


func on_both_picked(pick1, pick2):
	print("Player 1 picked: ", pick1)
	print("Player 2 picked: ", pick2)
	run_turn(pick1, pick2)


func run_turn(pick1, pick2):
	$PickScreen.visible = false

	for tick in range(TICKS_PER_TURN):
		resolve_tick(tick, pick1, pick2)
		update_fighter_positions()
		await get_tree().create_timer(TICK_DELAY).timeout

	$PickScreen.visible = true


func resolve_tick(tick, pick1, pick2):
	var target1 = fighter1.grid_position
	var target2 = fighter2.grid_position

	# Move happens on the first tick of the turn
	if tick == 0:
		if pick1["action"] == "Move":
			target1 = fighter1.grid_position + direction_from_name(pick1["wheel"])
		if pick2["action"] == "Move":
			target2 = fighter2.grid_position + direction_from_name(pick2["wheel"])

	# Rule 1: you cannot leave the board
	if not is_inside_board(target1):
		target1 = fighter1.grid_position
	if not is_inside_board(target2):
		target2 = fighter2.grid_position

	# Rule 2: both fighters entering the same tile means both stay put
	if target1 == target2:
		target1 = fighter1.grid_position
		target2 = fighter2.grid_position

	# Rule 3: swapping places is not allowed, both stay put
	if target1 == fighter2.grid_position and target2 == fighter1.grid_position:
		target1 = fighter1.grid_position
		target2 = fighter2.grid_position

	fighter1.grid_position = target1
	fighter2.grid_position = target2
