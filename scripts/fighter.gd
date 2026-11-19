extends Node2D

const START_HP = 100

# colour each phase pulses towards and how fast, steady team colour otherwise
const PULSE_STRENGTH = 0.85
const PULSES = {
	"active": {"color": Color(1.0, 0.85, 0.2), "speed": 18.0},
	"recovery": {"color": Color(0.15, 0.15, 0.2), "speed": 6.0},
	"stunned": {"color": Color(1.0, 1.0, 1.0), "speed": 24.0},
}

var hp = START_HP
var grid_position = Vector2i(0, 1)
var facing = 1
var hitstun_ticks = 0
var stunned = false
var current_action = "none"
var action_tick = 0
var aim = Vector2i(0, 0)
var queued_pick = {}

var body_color = Color.WHITE
var tick_phase = "idle"
var shown_phase = "idle"
var pulse_time = 0.0

@onready var status_label = $StatusLabel
@onready var body = $ColorRect


func set_color(new_color):
	body_color = new_color
	body.color = new_color


func reset(start_tile, start_facing):
	hp = START_HP
	grid_position = start_tile
	facing = start_facing
	hitstun_ticks = 0
	stunned = false
	aim = Vector2i(0, 0)
	queued_pick = {}
	tick_phase = "idle"
	clear_action()
	update_label()


func _process(delta):
	var phase = display_phase()
	if phase != shown_phase:
		shown_phase = phase
		pulse_time = 0.0
	pulse_time += delta

	if not PULSES.has(phase):
		body.color = body_color
		return

	var style = PULSES[phase]
	var amount = PULSE_STRENGTH * (0.5 + 0.5 * cos(pulse_time * style["speed"]))
	body.color = body_color.lerp(style["color"], amount)


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


func is_hurt():
	return stunned or hitstun_ticks > 0


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


# phase of the tick being resolved, called once the tick's action has started
# so the colour lines up with the attack marks drawn for that same tick
func mark_phase():
	if stunned:
		tick_phase = "stunned"
	elif current_action == "none" or current_action == "Wait":
		tick_phase = "idle"
	elif in_active_frames():
		tick_phase = "active"
	elif action_tick < Actions.DATA[current_action]["startup"]:
		tick_phase = "startup"
	else:
		tick_phase = "recovery"


# a fighter that was just hit shows as stunned right away
func display_phase():
	if is_hurt():
		return "stunned"
	return tick_phase


# dash and lunge share a label so the opponent cannot tell them apart, wait shows the idle pose
func update_label():
	if is_hurt() or current_action == "none" or current_action == "Wait":
		status_label.text = ""
	else:
		var action_text = current_action
		if Actions.is_rush(current_action):
			action_text = "Rush"
		var direction_name = Actions.DIRECTION_NAMES[Actions.direction_index(aim)]
		status_label.text = action_text + "\n" + direction_name
