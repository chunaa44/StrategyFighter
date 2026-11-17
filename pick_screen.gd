extends Control

signal both_picked(pick1, pick2)

var current_player = 1
var pick1 = {}
var pick2 = {}

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

	make_row(box, "Action:", ["Move", "Attack", "Block", "Grab"], action_group)
	make_row(box, "Wheel:", Actions.DIRECTION_NAMES, wheel_group)
	make_row(box, "DI:", ["None"] + Actions.DIRECTION_NAMES, di_group)

	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.pressed.connect(on_confirm_pressed)
	box.add_child(confirm_button)

	start_player_turn(1)


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


func start_player_turn(player_number):
	current_player = player_number
	title_label.text = "Player " + str(player_number) + ": choose, then press Confirm"
	reset_selection()


func on_confirm_pressed():
	var pick = {}
	pick["action"] = action_group.get_pressed_button().text
	pick["wheel"] = wheel_group.get_pressed_button().text
	pick["di"] = di_group.get_pressed_button().text

	if current_player == 1:
		pick1 = pick
		start_player_turn(2)
	else:
		pick2 = pick
		both_picked.emit(pick1, pick2)
		start_player_turn(1)
