extends Node2D

var hp = 100
var grid_position = Vector2i(0, 1)
var facing = 1
var hitstun_ticks = 0
var stunned = false
var current_action = "none"
var action_tick = 0
var aim = Vector2i(0, 0)
var di = Vector2i(0, 0)
var queued_pick = {}


func set_color(new_color):
	$ColorRect.color = new_color


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
