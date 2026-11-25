extends Node2D

const START_HP = 100

const STUNNED_COLOR = Color(1.0, 1.0, 1.0)
const RECOVERY_DARKEN = 0.6
const STUN_PULSE_SPEED = 10.0

var hp = START_HP
var grid_position = Vector2i(0, 1)
var hitstun_ticks = 0
var stunned = false
var current_action = "none"
var action_tick = 0
var aim = Vector2i(0, 0)

var body_color = Color.WHITE
var pulse_time = 0.0

@onready var body = $ColorRect


func _process(delta):
	if not is_hurt():
		pulse_time = 0.0
		return
	pulse_time += delta
	var amount = 0.5 + 0.5 * cos(pulse_time * STUN_PULSE_SPEED)
	body.color = body_color.lerp(STUNNED_COLOR, amount)


func set_color(new_color):
	body_color = new_color
	body.color = new_color


func reset(start_tile):
	hp = START_HP
	grid_position = start_tile
	hitstun_ticks = 0
	stunned = false
	aim = Vector2i(0, 0)
	clear_action()
	update_color()


# ticks before this fighter can start a new action, 0 when it is already free
func ticks_until_free():
	var action_wait = 0
	if current_action != "none":
		action_wait = Actions.total_ticks(current_action) - action_tick
	return maxi(action_wait, hitstun_ticks)


# dash and lunge look the same until they become active, so their length stays secret
func is_disguised():
	return Actions.is_rush(current_action) and action_tick < Actions.DATA[current_action]["startup"]


# nothing going on and not stunned, a new action has to be chosen
func can_act_next_tick():
	return current_action == "none" and hitstun_ticks == 0


# still inside the cancel window of the current action
func can_cancel():
	if current_action == "none" or hitstun_ticks > 0:
		return false
	return action_tick < Actions.DATA[current_action]["cancel"]


# the fighter is asked for a pick before the next tick
func can_decide():
	return can_act_next_tick() or can_cancel()


func start_tick():
	if hitstun_ticks > 0:
		stunned = true
		hitstun_ticks -= 1
	else:
		stunned = false


func is_hurt():
	return stunned or hitstun_ticks > 0


func start_action(pick):
	current_action = pick["action"]
	action_tick = 0
	aim = Actions.direction_from_name(pick["wheel"])
	# holding returns to the idle pose, so no direction is kept
	if current_action == "Hold":
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


# the action is past its active frames and only has to finish
func in_recovery():
	if current_action == "none" or current_action == "Hold":
		return false
	var data = Actions.DATA[current_action]
	return action_tick >= data["startup"] + data["active"]


# stunned colour is animated in _process, darker while recovering, team colour otherwise
func update_color():
	if is_hurt():
		body.color = STUNNED_COLOR
	elif in_recovery():
		body.color = body_color.darkened(RECOVERY_DARKEN)
	else:
		body.color = body_color
