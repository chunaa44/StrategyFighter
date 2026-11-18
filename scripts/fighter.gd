extends Node2D

const START_HP = 100

var hp = START_HP
var grid_position = Vector2i(0, 1)
var facing = 1
var hitstun_ticks = 0
var stunned = false
var current_action = "none"
var action_tick = 0
var aim = Vector2i(0, 0)
var di = Vector2i(0, 0)
var queued_pick = {}

@onready var status_label = $StatusLabel


func set_color(new_color):
	$ColorRect.color = new_color


func reset(start_tile, start_facing):
	hp = START_HP
	grid_position = start_tile
	facing = start_facing
	hitstun_ticks = 0
	stunned = false
	aim = Vector2i(0, 0)
	di = Vector2i(0, 0)
	queued_pick = {}
	clear_action()
	update_label()


# ticks into the next turn before this fighter can start a new action
func ticks_until_free():
	var action_wait = 0
	if current_action != "none":
		action_wait = Actions.total_ticks(current_action) - action_tick
	return maxi(action_wait, hitstun_ticks)


# true when the fighter will be able to start an action on the next tick
func can_act_next_tick():
	return current_action == "none" and hitstun_ticks == 0


func start_tick():
	if hitstun_ticks > 0:
		stunned = true
		hitstun_ticks -= 1
	else:
		stunned = false


func is_free():
	return current_action == "none" and not stunned


func start_action(pick):
	current_action = pick["action"]
	action_tick = 0
	aim = Actions.direction_from_name(pick["wheel"])
	# waiting returns to the idle pose, so no direction is kept
	if current_action == "Wait":
		aim = Vector2i(0, 0)


func clear_action():
	current_action = "none"
	action_tick = 0


func in_active_frames():
	if current_action == "none":
		return false
	var data = Actions.DATA[current_action]
	var first = data["startup"]
	var last = data["startup"] + data["active"] - 1
	return action_tick >= first and action_tick <= last


func is_guarding():
	return current_action == "Block" and in_active_frames()


# dash and lunge share a label so the opponent cannot tell them apart, wait shows the idle pose
func update_label():
	if stunned or hitstun_ticks > 0:
		status_label.text = "Stunned"
	elif current_action == "none" or current_action == "Wait":
		status_label.text = ""
	else:
		var action_text = current_action
		if Actions.is_rush(current_action):
			action_text = "Rush"
		var direction_name = Actions.DIRECTION_NAMES[Actions.direction_index(aim)]
		status_label.text = action_text + "\n" + direction_name
