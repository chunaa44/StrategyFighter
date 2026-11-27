extends Node2D

const TICK_DELAY = 0.6
# ticks where a strike or grab resolved last longer so the outcome can be read
const RESULT_DELAY = 1.1
const START_TILE_1 = Vector2i(1, 2)
const START_TILE_2 = Vector2i(7, 2)

@onready var board = $Board
@onready var storm = $Storm
@onready var fighter1 = $Fighter1
@onready var fighter2 = $Fighter2
@onready var effects = $Effects
@onready var hud = $Hud

# what happened on the current tick, in words
var tick_log = []
var clashed = false


func _ready():
	fighter1.set_color(Actions.PLAYER_COLORS[0])
	fighter2.set_color(Actions.PLAYER_COLORS[1])

	hud.restart_pressed.connect(on_restart_pressed)
	$PickScreen.both_picked.connect(on_both_picked)
	$PickScreen.preview_changed.connect(on_preview_changed)
	$PickScreen.preview_cleared.connect(effects.clear_preview)

	reset_match()
	ask_for_picks()


func reset_match():
	fighter1.reset(START_TILE_1)
	fighter2.reset(START_TILE_2)
	storm.reset()
	effects.clear()
	hud.clear_advantage()
	hud.clear_result()
	hud.clear_log()
	refresh_view()


func on_restart_pressed():
	reset_match()
	ask_for_picks()


func update_fighter_positions():
	fighter1.position = board.tile_to_pixel(fighter1.grid_position)
	fighter2.position = board.tile_to_pixel(fighter2.grid_position)


func refresh_view():
	update_fighter_positions()
	hud.refresh(fighter1, fighter2)
	hud.refresh_storm(storm)
	fighter1.update_color()
	fighter2.update_color()


# fighters that are free or inside a cancel window are asked, the others keep playing their action
func ask_for_picks():
	$PickScreen.begin_picks(fighter1.can_decide(), fighter2.can_decide(), fighter1.current_action, fighter2.current_action)


# only the player currently choosing gets a preview
# the opponent is assumed to stay put, their pending slide would give away dash versus lunge
func on_preview_changed(player_number, action_name, direction_name):
	hud.show_advantage(player_number, fighter1, fighter2)
	var fighter = fighter1
	var other = fighter2
	if player_number == 2:
		fighter = fighter2
		other = fighter1
	effects.show_preview(fighter, other, action_name, Actions.direction_from_name(direction_name))


# the game only stops when someone is free, a cancel window alone never stops it
func needs_decision():
	return fighter1.can_act_next_tick() or fighter2.can_act_next_tick()


func on_both_picked(pick1, pick2):
	hud.clear_advantage()
	apply_pick(fighter1, pick1)
	apply_pick(fighter2, pick2)
	run_until_decision()


# hold keeps whatever the fighter is doing, any other pick replaces it
func apply_pick(fighter, pick):
	if pick.is_empty():
		return
	if pick["action"] == "Hold" and fighter.current_action != "none":
		return
	fighter.start_action(pick)


func run_until_decision():
	while true:
		resolve_tick()
		refresh_view()
		var delay = TICK_DELAY
		if effects.result_shown:
			delay = RESULT_DELAY
		await get_tree().create_timer(delay).timeout
		effects.clear_tick()
		# the last tick of a match stays on screen as it was
		if fighter1.hp <= 0 or fighter2.hp <= 0:
			break
		end_tick()
		if needs_decision():
			break

	if fighter1.hp <= 0 and fighter2.hp <= 0:
		hud.show_result("Double KO", Color.WHITE)
	elif fighter1.hp <= 0:
		hud.show_result("P2 wins", Actions.PLAYER_COLORS[1])
	elif fighter2.hp <= 0:
		hud.show_result("P1 wins", Actions.PLAYER_COLORS[0])
	else:
		ask_for_picks()


func end_tick():
	fighter1.end_tick()
	fighter2.end_tick()
	refresh_view()


# the storm closes first, so moving out on the closing tick still avoids its damage
func resolve_tick():
	tick_log.clear()
	clashed = false
	effects.clear_damage()
	storm.advance()
	fighter1.start_tick()
	fighter2.start_tick()

	resolve_moves()
	resolve_hits()
	resolve_storm()

	advance_action(fighter1)
	advance_action(fighter2)

	# the label holds two lines, attack results come before a clash
	if clashed and tick_log.size() < 2:
		tick_log.push_front("Paths clashed")
	hud.show_log(tick_log)


func advance_action(fighter):
	if fighter.current_action == "none":
		return
	fighter.action_tick += 1


# where a fighter ends up if it slides this tick
func move_target(fighter, other):
	var tile = fighter.grid_position
	if fighter.current_action == "none":
		return tile
	var slide = Actions.DATA[fighter.current_action]["slide"]
	if slide == 0 or not fighter.in_active_frames():
		return tile
	return board.slide_end(tile, fighter.aim, slide, other.grid_position)


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
		clashed = true
		target1 = start1
		target2 = start2

	settle_positions(target1, target2)

	show_slide(fighter1, start1)
	show_slide(fighter2, start2)


# applies the position rules shared by all movement
func settle_positions(target1, target2):
	# cannot leave the board
	if not board.is_inside_board(target1):
		target1 = fighter1.grid_position
	if not board.is_inside_board(target2):
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


# returns the hp actually lost
func take_damage(victim, amount):
	var before = victim.hp
	victim.hp = maxi(victim.hp - amount, 0)
	return before - victim.hp


func apply_hit(victim, action_name):
	var data = Actions.DATA[action_name]

	var lost = take_damage(victim, data["damage"])
	effects.show_hit_damage(victim.grid_position, lost)
	victim.hitstun_ticks = data["hitstun"]
	victim.clear_action()


# one line for the result log, called before hits change hp or clear actions
func describe_result(attacker_title, defender_title, attacker, defender, result):
	var action = attacker.current_action
	var attack = attacker_title + " " + action

	if result == "whiff":
		return attack + " missed"
	if result == "beaten":
		return attack + " was beaten"
	if result == "blocked":
		return defender_title + " blocked " + attack

	var lost = mini(Actions.DATA[action]["damage"], defender.hp)
	if action == "Grab" and defender.is_guarding():
		return attack + " broke block -" + str(lost)
	return attack + " hit " + defender_title + " -" + str(lost)


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

	# effects read positions and actions before hits clear them
	effects.show_guard(fighter1)
	effects.show_guard(fighter2)
	effects.show_result(fighter1, fighter2, action1, result1)
	effects.show_result(fighter2, fighter1, action2, result2)

	if result1 != "none":
		tick_log.append(describe_result("P1", "P2", fighter1, fighter2, result1))
	if result2 != "none":
		tick_log.append(describe_result("P2", "P1", fighter2, fighter1, result2))

	if result1 == "hit":
		apply_hit(fighter2, action1)
	if result2 == "hit":
		apply_hit(fighter1, action2)


# storm damage ignores block and does not stun or interrupt
func resolve_storm():
	for fighter in [fighter1, fighter2]:
		var lost = take_damage(fighter, storm.damage_at(fighter.grid_position))
		if lost > 0:
			effects.show_storm_damage(fighter.grid_position, lost)
