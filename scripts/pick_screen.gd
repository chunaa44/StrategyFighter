extends Control

signal both_picked(pick1, pick2)
signal preview_changed(player_number, action_name, direction_name)
signal preview_cleared

const DirectionWheel = preload("res://scripts/direction_wheel.gd")

const BOX_POSITION = Vector2(100, 490)
const WHEEL_POSITION = Vector2(900, 120)
const TITLE_SIZE = 16

const ICON_PATH = "res://assets/icons/%s.png"
const BUTTON_SIZE = Vector2(88, 76)
const BUTTON_FONT_SIZE = 12

var current_player = 1
var pick1 = {}
var pick2 = {}
var needs = [true, true]
var notes = ["", ""]

var action_group = ButtonGroup.new()

var title_label
var confirm_button
var wheel


func _ready():
	var box = VBoxContainer.new()
	box.position = BOX_POSITION
	add_child(box)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", TITLE_SIZE)
	box.add_child(title_label)

	make_row(box, "Action:", ["Move", "Dash", "Jab", "Lunge", "Block", "Grab", "Wait"], action_group)

	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.pressed.connect(on_confirm_pressed)
	box.add_child(confirm_button)

	wheel = DirectionWheel.new()
	wheel.position = WHEEL_POSITION
	wheel.direction_changed.connect(emit_preview)
	add_child(wheel)

	action_group.pressed.connect(on_action_pressed)


func make_row(parent, row_name, options, group):
	var row = HBoxContainer.new()
	parent.add_child(row)

	var label = Label.new()
	label.text = row_name
	label.custom_minimum_size = Vector2(130, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	for option in options:
		row.add_child(make_action_button(option, group))


# icon sits above the name, a missing icon file leaves a text-only button
func make_action_button(option, group):
	var button = Button.new()
	button.text = option
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var icon_file = ICON_PATH % option.to_lower()
	if ResourceLoader.exists(icon_file):
		button.icon = load(icon_file)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = false
	return button


func reset_selection():
	action_group.get_buttons()[0].button_pressed = true
	wheel.select(0)
	emit_preview()


func on_action_pressed(_button):
	emit_preview()


# the board shows a ghost of whatever is currently selected for the player choosing
func emit_preview():
	var pressed_button = action_group.get_pressed_button()
	if pressed_button == null:
		return
	preview_changed.emit(current_player, pressed_button.text, wheel.get_direction_name())


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
	preview_cleared.emit()
	both_picked.emit(pick1, pick2)


func on_confirm_pressed():
	var pick = {}
	pick["action"] = action_group.get_pressed_button().text
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
