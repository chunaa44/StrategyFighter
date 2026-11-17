extends Node2D

const BOARD_WIDTH = 7
const BOARD_HEIGHT = 3
const TILE_SIZE = 100
const BOARD_OFFSET = Vector2(100, 50)
const TICKS_PER_TURN = 4
const TICK_DELAY = 0.25

@onready var fighter1 = $Fighter1
@onready var fighter2 = $Fighter2

var hp_label
var message_label


func _ready():
	fighter1.grid_position = Vector2i(1, 1)
	fighter1.facing = 1
	fighter1.set_color(Color.CORNFLOWER_BLUE)

	fighter2.grid_position = Vector2i(5, 1)
	fighter2.facing = -1
	fighter2.set_color(Color.INDIAN_RED)

	hp_label = Label.new()
	hp_label.position = Vector2(100, 10)
	add_child(hp_label)

	message_label = Label.new()
	message_label.position = Vector2(100, 380)
	add_child(message_label)

	update_fighter_positions()
	update_hp_label()

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


func update_hp_label():
	hp_label.text = "P1 HP: " + str(fighter1.hp) + "     P2 HP: " + str(fighter2.hp)


func _draw():
	for x in range(BOARD_WIDTH):
		for y in range(BOARD_HEIGHT):
			var tile_position = tile_to_pixel(Vector2i(x, y))
			var tile_rect = Rect2(tile_position, Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(tile_rect, Color(0.2, 0.2, 0.2), true)
			draw_rect(tile_rect, Color.WHITE, false, 2.0)


func on_both_picked(pick1, pick2):
	run_turn(pick1, pick2)


func run_turn(pick1, pick2):
	$PickScreen.visible = false
	message_label.text = ""

	fighter1.queued_pick = pick1
	fighter2.queued_pick = pick2
	fighter1.di = Actions.direction_from_name(pick1["di"])
	fighter2.di = Actions.direction_from_name(pick2["di"])

	for tick in range(TICKS_PER_TURN):
		resolve_tick()
		update_fighter_positions()
		update_hp_label()
		await get_tree().create_timer(TICK_DELAY).timeout
		if fighter1.hp <= 0 or fighter2.hp <= 0:
			break

	if fighter1.hp <= 0 and fighter2.hp <= 0:
		message_label.text = "Double KO"
	elif fighter1.hp <= 0:
		message_label.text = "P2 wins"
	elif fighter2.hp <= 0:
		message_label.text = "P1 wins"
	else:
		$PickScreen.visible = true


func resolve_tick():
	fighter1.start_tick()
	fighter2.start_tick()

	begin_action(fighter1)
	begin_action(fighter2)

	resolve_moves()
	resolve_hits()

	advance_action(fighter1)
	advance_action(fighter2)
	update_facing()


# a fighter that is busy or stunned starts the picked action as soon as it is free
func begin_action(fighter):
	if not fighter.is_free():
		return
	if fighter.queued_pick.is_empty():
		return

	fighter.start_action(fighter.queued_pick)
	fighter.queued_pick = {}


func advance_action(fighter):
	if fighter.current_action == "none":
		return
	fighter.action_tick += 1
	if fighter.action_tick >= Actions.total_ticks(fighter.current_action):
		fighter.clear_action()


func update_facing():
	if fighter2.grid_position.x > fighter1.grid_position.x:
		fighter1.facing = 1
		fighter2.facing = -1
	elif fighter2.grid_position.x < fighter1.grid_position.x:
		fighter1.facing = -1
		fighter2.facing = 1


func resolve_moves():
	var target1 = fighter1.grid_position
	var target2 = fighter2.grid_position

	if fighter1.current_action == "Move" and fighter1.in_active_frames():
		target1 = fighter1.grid_position + fighter1.aim * Actions.DATA["Move"]["range"]
	if fighter2.current_action == "Move" and fighter2.in_active_frames():
		target2 = fighter2.grid_position + fighter2.aim * Actions.DATA["Move"]["range"]

	settle_positions(target1, target2)


# applies the position rules shared by moves, knockback and DI
func settle_positions(target1, target2):
	# cannot leave the board
	if not is_inside_board(target1):
		target1 = fighter1.grid_position
	if not is_inside_board(target2):
		target2 = fighter2.grid_position

	# both entering the same tile: both stay put
	if target1 == target2:
		target1 = fighter1.grid_position
		target2 = fighter2.grid_position

	# swapping places is not allowed: both stay put
	if target1 == fighter2.grid_position and target2 == fighter1.grid_position:
		target1 = fighter1.grid_position
		target2 = fighter2.grid_position

	fighter1.grid_position = target1
	fighter2.grid_position = target2


func is_in_reach(attacker, defender):
	var reach = Actions.DATA[attacker.current_action]["range"]
	for step in range(1, reach + 1):
		if attacker.grid_position + attacker.aim * step == defender.grid_position:
			return true
	return false


# returns "none", "whiff", "blocked" or "hit"
func get_attack_result(attacker, defender):
	if attacker.current_action != "Attack" and attacker.current_action != "Grab":
		return "none"
	if not attacker.in_active_frames():
		return "none"
	if not is_in_reach(attacker, defender):
		return "whiff"

	# only attacks can be blocked, grabs go through
	if attacker.current_action == "Attack" and defender.is_guarding():
		var from_direction = attacker.aim * -1
		if Actions.is_guarded(defender.aim, from_direction):
			return "blocked"

	return "hit"


func apply_hit(victim, action_name):
	var data = Actions.DATA[action_name]
	victim.hp -= data["damage"]
	if victim.hp < 0:
		victim.hp = 0
	victim.hitstun_ticks = data["hitstun"]
	victim.clear_action()


func resolve_hits():
	# both results are worked out before anything changes so hits are simultaneous
	var action1 = fighter1.current_action
	var action2 = fighter2.current_action
	var result1 = get_attack_result(fighter1, fighter2)
	var result2 = get_attack_result(fighter2, fighter1)

	# when an attack and a grab land on the same tick the attack wins
	if result1 == "hit" and result2 == "hit":
		if action1 == "Attack" and action2 == "Grab":
			result2 = "none"
		elif action1 == "Grab" and action2 == "Attack":
			result1 = "none"

	var target1 = fighter1.grid_position
	var target2 = fighter2.grid_position
	if result1 == "hit":
		target2 += fighter1.aim * Actions.DATA[action1]["knockback"]
	if result2 == "hit":
		target1 += fighter2.aim * Actions.DATA[action2]["knockback"]

	if result1 == "hit":
		apply_hit(fighter2, action1)
	if result2 == "hit":
		apply_hit(fighter1, action2)

	# knockback first, then DI from wherever the fighter landed
	settle_positions(target1, target2)

	target1 = fighter1.grid_position
	target2 = fighter2.grid_position
	if result2 == "hit":
		target1 += fighter1.di
	if result1 == "hit":
		target2 += fighter2.di
	settle_positions(target1, target2)
