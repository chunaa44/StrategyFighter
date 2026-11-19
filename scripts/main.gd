extends Node2D

const BOARD_WIDTH = 9
const BOARD_HEIGHT = 5
const TILE_SIZE = 80
const BOARD_OFFSET = Vector2(100, 50)
const TICK_DELAY = 0.25
const MAX_EVENTS = 4
const START_TILE_1 = Vector2i(1, 2)
const START_TILE_2 = Vector2i(7, 2)

@onready var fighter1 = $Fighter1
@onready var fighter2 = $Fighter2
@onready var effects = $Effects
@onready var hp_label = $HpLabel
@onready var message_label = $MessageLabel
@onready var restart_button = $RestartButton

var event_log = PackedStringArray()
var wait_text = ""


func _ready():
	fighter1.set_color(Color.CORNFLOWER_BLUE)
	fighter2.set_color(Color.INDIAN_RED)

	effects.setup(self)

	restart_button.pressed.connect(on_restart_pressed)
	$PickScreen.both_picked.connect(on_both_picked)
	$PickScreen.preview_changed.connect(on_preview_changed)
	$PickScreen.preview_cleared.connect(effects.clear_preview)

	reset_match()
	ask_for_picks()


func reset_match():
	fighter1.reset(START_TILE_1, 1)
	fighter2.reset(START_TILE_2, -1)
	effects.clear()
	event_log.clear()
	wait_text = ""
	update_message()
	restart_button.visible = false
	refresh_view()


func on_restart_pressed():
	reset_match()
	ask_for_picks()


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


func refresh_view():
	update_fighter_positions()
	update_hp_label()
	fighter1.update_label()
	fighter2.update_label()


func update_hp_label():
	hp_label.text = "P1 HP: " + str(fighter1.hp) + "     P2 HP: " + str(fighter2.hp)


func add_event(text):
	event_log.append(text)
	if event_log.size() > MAX_EVENTS:
		event_log.remove_at(0)
	update_message()


func update_message():
	var text = " | ".join(event_log)
	if wait_text != "":
		if text != "":
			text += "   ||   "
		text += wait_text
	message_label.text = text


func wait_note(fighter):
	var wait = fighter.ticks_until_free()
	if wait == 0:
		return ""
	if wait == 1:
		return "acts after 1 tick"
	return "acts after " + str(wait) + " ticks"


func update_wait_text():
	wait_text = ""
	var note1 = wait_note(fighter1)
	var note2 = wait_note(fighter2)
	if note1 != "":
		wait_text = "P1 " + note1
	if note2 != "":
		if wait_text != "":
			wait_text += "   |   "
		wait_text += "P2 " + note2
	update_message()


func _draw():
	for x in range(BOARD_WIDTH):
		for y in range(BOARD_HEIGHT):
			var tile_position = tile_to_pixel(Vector2i(x, y))
			var tile_rect = Rect2(tile_position, Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(tile_rect, Color(0.2, 0.2, 0.2), true)
			draw_rect(tile_rect, Color.WHITE, false, 2.0)


# a fighter that already has a pick waiting is not asked again
func ask_for_picks():
	var need1 = fighter1.queued_pick.is_empty()
	var need2 = fighter2.queued_pick.is_empty()
	$PickScreen.begin_picks(need1, need2, wait_note(fighter1), wait_note(fighter2))


# only the player currently choosing gets a preview
# the opponent is assumed to stay put, their pending slide would give away dash versus lunge
func on_preview_changed(player_number, action_name, direction_name):
	var fighter = fighter1
	var other = fighter2
	if player_number == 2:
		fighter = fighter2
		other = fighter1
	var start = projected_tile(fighter, other)
	effects.show_preview(fighter, other, action_name, Actions.direction_from_name(direction_name), start)


# where a fighter stands once its current action has played out, which is where a queued pick begins
func projected_tile(fighter, other):
	var tile = fighter.grid_position
	if fighter.current_action == "none":
		return tile

	var data = Actions.DATA[fighter.current_action]
	if data["slide"] == 0:
		return tile

	var first = data["startup"]
	var last = data["startup"] + data["active"] - 1
	for tick in range(fighter.action_tick, Actions.total_ticks(fighter.current_action)):
		if tick >= first and tick <= last:
			tile = slide_end(tile, fighter.aim, data["slide"], other.grid_position)
	return tile


# a decision is needed as soon as someone can act and has nothing queued
func needs_decision():
	if fighter1.queued_pick.is_empty() and fighter1.can_act_next_tick():
		return true
	if fighter2.queued_pick.is_empty() and fighter2.can_act_next_tick():
		return true
	return false


func on_both_picked(pick1, pick2):
	if not pick1.is_empty():
		fighter1.queued_pick = pick1
	if not pick2.is_empty():
		fighter2.queued_pick = pick2

	wait_text = ""
	update_message()
	run_until_decision()


func run_until_decision():
	while true:
		resolve_tick()
		refresh_view()
		await get_tree().create_timer(TICK_DELAY).timeout
		effects.clear_tick()
		if fighter1.hp <= 0 or fighter2.hp <= 0:
			break
		if needs_decision():
			break

	if fighter1.hp <= 0 and fighter2.hp <= 0:
		end_match("Double KO")
	elif fighter1.hp <= 0:
		end_match("P2 wins")
	elif fighter2.hp <= 0:
		end_match("P1 wins")
	else:
		update_wait_text()
		ask_for_picks()


func end_match(text):
	add_event(text)
	restart_button.visible = true


func resolve_tick():
	fighter1.start_tick()
	fighter2.start_tick()

	begin_action(fighter1)
	begin_action(fighter2)

	fighter1.mark_phase()
	fighter2.mark_phase()

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


# where a fighter ends up if it slides this tick
func move_target(fighter, other):
	var tile = fighter.grid_position
	if fighter.current_action == "none":
		return tile
	var slide = Actions.DATA[fighter.current_action]["slide"]
	if slide == 0 or not fighter.in_active_frames():
		return tile
	return slide_end(tile, fighter.aim, slide, other.grid_position)


# two slides that touch the same tile cancel each other
func paths_clash(start1, target1, start2, target2):
	if target1 == start1 or target2 == start2:
		return false

	var path2 = Actions.path_tiles(start2, target2)
	for tile in Actions.path_tiles(start1, target1):
		if path2.has(tile):
			return true
	return false


func show_slide(fighter, start_tile):
	if not Actions.is_rush(fighter.current_action):
		return
	if not fighter.in_active_frames():
		return
	effects.show_slide(start_tile, fighter.grid_position, fighter.current_action)


func resolve_moves():
	var start1 = fighter1.grid_position
	var start2 = fighter2.grid_position
	var target1 = move_target(fighter1, fighter2)
	var target2 = move_target(fighter2, fighter1)

	if paths_clash(start1, target1, start2, target2):
		effects.show_clash(start1, start2)
		target1 = start1
		target2 = start2

	settle_positions(target1, target2)

	show_slide(fighter1, start1)
	show_slide(fighter2, start2)


# applies the position rules shared by all movement
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
	var action = attacker.current_action
	if not Actions.is_strike(action) and action != "Grab":
		return "none"
	if not attacker.in_active_frames():
		return "none"
	if not is_in_reach(attacker, defender):
		return "whiff"

	# only strikes can be blocked, grabs go through
	if Actions.is_strike(action) and defender.is_guarding():
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


func report_result(player_name, action_name, result):
	if result == "none":
		return
	add_event(player_name + " " + action_name + " " + result)


func resolve_hits():
	# both results are worked out before anything changes so hits are simultaneous
	var action1 = fighter1.current_action
	var action2 = fighter2.current_action
	var result1 = get_attack_result(fighter1, fighter2)
	var result2 = get_attack_result(fighter2, fighter1)

	# when a strike and a grab land on the same tick the strike wins
	if result1 == "hit" and result2 == "hit":
		if Actions.is_strike(action1) and action2 == "Grab":
			result2 = "beaten"
		elif action1 == "Grab" and Actions.is_strike(action2):
			result1 = "beaten"

	report_result("P1", action1, result1)
	report_result("P2", action2, result2)

	# effects read positions and actions before hits clear them
	effects.show_guard(fighter1)
	effects.show_guard(fighter2)
	effects.show_result(fighter1, fighter2, action1, result1)
	effects.show_result(fighter2, fighter1, action2, result2)

	if result1 == "hit":
		apply_hit(fighter2, action1)
	if result2 == "hit":
		apply_hit(fighter1, action2)
