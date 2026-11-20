extends Control

signal both_picked(pick1, pick2)
signal preview_changed(player_number, action_name, direction_name)
signal preview_cleared

var current_player = 1
var pick1 = {}
var pick2 = {}
var needs = [true, true]
# action each player is in the middle of, "none" when free
var running = ["none", "none"]

@onready var title_label = $Box/TitleLabel
@onready var confirm_button = $Box/ConfirmButton
@onready var wheel = $Wheel
# every action button shares this group
@onready var action_group = $Box/ActionRow/Move.button_group


func _ready():
	for button in action_group.get_buttons():
		button.tooltip_text = make_tooltip(str(button.name))

	confirm_button.pressed.connect(on_confirm_pressed)
	wheel.direction_changed.connect(emit_preview)
	action_group.pressed.connect(on_action_pressed)


func make_tooltip(option):
	var data = Actions.DATA[option]
	var text = option + "\n"
	text += "Startup " + str(data["startup"]) + "  Active " + str(data["active"]) + "  Recovery " + str(data["recovery"]) + "\n"
	text += "Damage " + str(data["damage"]) + "  Hitstun " + str(data["hitstun"])
	return text


# the button's node name is the action name
func selected_action():
	return str(action_group.get_pressed_button().name)


func select_action(action_name):
	for button in action_group.get_buttons():
		if str(button.name) == action_name:
			button.button_pressed = true


# a fighter in the middle of an action starts on Hold, so confirming keeps the action
func reset_selection(player_number):
	if running[player_number - 1] == "none":
		select_action("Move")
	else:
		select_action("Hold")
	wheel.select(0)
	emit_preview()


func on_action_pressed(_button):
	emit_preview()


# the board shows a ghost of whatever is currently selected for the player choosing
func emit_preview():
	if action_group.get_pressed_button() == null:
		return
	preview_changed.emit(current_player, selected_action(), wheel.get_direction_name())


# only the players who are free or can cancel are asked, the others keep playing their action
func begin_picks(need1, need2, action1, action2):
	needs = [need1, need2]
	running = [action1, action2]
	pick1 = {}
	pick2 = {}
	visible = true
	if need1:
		start_player_turn(1)
	else:
		start_player_turn(2)


# the title never names the running action, the other player sits at the same screen
func start_player_turn(player_number):
	current_player = player_number
	var title = "Player " + str(player_number)
	if running[player_number - 1] != "none":
		title += "   Hold keeps current action"
	title_label.text = title
	reset_selection(player_number)


func finish_picks():
	visible = false
	preview_cleared.emit()
	both_picked.emit(pick1, pick2)


func on_confirm_pressed():
	var pick = {}
	pick["action"] = selected_action()
	pick["wheel"] = wheel.get_direction_name()

	if current_player == 1:
		pick1 = pick
		if needs[1]:
			start_player_turn(2)
		else:
			finish_picks()
	else:
		pick2 = pick
		finish_picks()
