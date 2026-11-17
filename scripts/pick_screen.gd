extends Control

signal both_picked(pick1, pick2)

var current_player = 1
var pick1 = {}
var pick2 = {}
var needs = [true, true]
var notes = ["", ""]

var action_group = ButtonGroup.new()
var wheel_group = ButtonGroup.new()
var di_group = ButtonGroup.new()

var title_label
var confirm_button


func _ready():
	position = Vector2(100, 380)

	var box = VBoxContainer.new()
	add_child(box)

	title_label = Label.new()
	box.add_child(title_label)

	make_row(box, "Action:", ["Move", "Attack", "Block", "Grab", "Wait"], action_group)
	make_row(box, "Wheel:", Actions.DIRECTION_NAMES, wheel_group)
	make_row(box, "DI:", ["None"] + Actions.DIRECTION_NAMES, di_group)

	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.pressed.connect(on_confirm_pressed)
	box.add_child(confirm_button)


func make_row(parent, row_name, options, group):
	var row = HBoxContainer.new()
	parent.add_child(row)

	var label = Label.new()
	label.text = row_name
	label.custom_minimum_size = Vector2(80, 0)
	row.add_child(label)

	for option in options:
		var button = Button.new()
		button.text = option
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(80, 0)
		row.add_child(button)


func reset_selection():
	action_group.get_buttons()[0].button_pressed = true
	wheel_group.get_buttons()[0].button_pressed = true
	di_group.get_buttons()[0].button_pressed = true


# only the players who need to choose are asked, the others keep their queued pick
func begin_picks(need1, need2, note1, note2):
	needs = [need1, need2]
	notes = [note1, note2]
	pick1 = {}
	pick2 = {}
	visible = true
	if need1:
		start_player_turn(1)
	else:
		start_player_turn(2)


func start_player_turn(player_number):
	current_player = player_number
	var title = "Player " + str(player_number) + ": choose, then press Confirm"
	var note = notes[player_number - 1]
	if note != "":
		title += "   (" + note + ")"
	title_label.text = title
	reset_selection()


func finish_picks():
	visible = false
	both_picked.emit(pick1, pick2)


func on_confirm_pressed():
	var pick = {}
	pick["action"] = action_group.get_pressed_button().text
	pick["wheel"] = wheel_group.get_pressed_button().text
	pick["di"] = di_group.get_pressed_button().text

	if current_player == 1:
		pick1 = pick
		if needs[1]:
			start_player_turn(2)
		else:
			finish_picks()
	else:
		pick2 = pick
		finish_picks()
