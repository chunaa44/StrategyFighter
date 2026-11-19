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
# action each player is in the middle of, "none" when free
var running = ["none", "none"]

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

	make_row(box, ["Move", "Dash", "Jab", "Lunge", "Block", "Grab", "Hold"], action_group)

	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.pressed.connect(on_confirm_pressed)
	box.add_child(confirm_button)

	wheel = DirectionWheel.new()
	wheel.position = WHEEL_POSITION
	wheel.direction_changed.connect(emit_preview)
	add_child(wheel)

	action_group.pressed.connect(on_action_pressed)


func make_row(parent, options, group):
	var row = HBoxContainer.new()
	parent.add_child(row)

	for option in options:
		row.add_child(make_action_button(option, group))


# the icon is the whole button, the name and stats show when hovering
# a missing icon file leaves the name as text so the button is not blank
func make_action_button(option, group):
	var button = Button.new()
	button.set_meta("action", option)
	button.tooltip_text = make_tooltip(option)
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var icon_file = ICON_PATH % option.to_lower()
	if ResourceLoader.exists(icon_file):
		button.icon = load(icon_file)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.expand_icon = false
	else:
		button.text = option
	return button


func make_tooltip(option):
	var data = Actions.DATA[option]
	var text = option + "\n"
	text += "Startup " + str(data["startup"]) + "  Active " + str(data["active"]) + "  Recovery " + str(data["recovery"]) + "\n"
	text += "Damage " + str(data["damage"]) + "  Hitstun " + str(data["hitstun"])
	return text


func selected_action():
	return action_group.get_pressed_button().get_meta("action")


func select_action(action_name):
	for button in action_group.get_buttons():
		if button.get_meta("action") == action_name:
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


func start_player_turn(player_number):
	current_player = player_number
	var title = "Player " + str(player_number) + ": choose, then press Confirm"
	var action_name = running[player_number - 1]
	if action_name != "none":
		title += "   (Hold keeps " + action_name + ")"
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
