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
# online only: the local pick is sent, the opponent's is still missing
var waiting = false

@onready var title_label = $Box/TitleLabel
@onready var confirm_button = $Box/ConfirmButton
@onready var wheel = $Wheel
@onready var cover = $CoverLayer/Cover
@onready var cover_label = $CoverLayer/Cover/CenterContainer/CoverBox/CoverLabel
@onready var ready_button = $CoverLayer/Cover/CenterContainer/CoverBox/ReadyButton
# every action button shares this group
@onready var action_group = $Box/ActionRow/Move.button_group


func _ready():
	for button in action_group.get_buttons():
		button.tooltip_text = make_tooltip(str(button.name))

	confirm_button.pressed.connect(on_confirm_pressed)
	ready_button.pressed.connect(on_ready_pressed)
	wheel.direction_changed.connect(emit_preview)
	action_group.pressed.connect(on_action_pressed)
	Network.pick_received.connect(on_opponent_pick)


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
	if waiting or action_group.get_pressed_button() == null:
		return
	update_title()
	preview_changed.emit(current_player, selected_action(), wheel.get_direction_name())


# the title repeats the selection in words, the buttons only show icons
func update_title():
	var action = selected_action()
	var title = "Player " + str(current_player) + ": " + action
	if action != "Hold":
		title += " " + wheel.get_direction_name()
	elif running[current_player - 1] != "none":
		title += " keeps " + running[current_player - 1]
	title_label.text = title


# only the players who are free or can cancel are asked, the others keep playing their action
func begin_picks(need1, need2, action1, action2):
	needs = [need1, need2]
	running = [action1, action2]
	pick1 = {}
	pick2 = {}
	waiting = false
	confirm_button.disabled = false
	visible = true
	if Network.is_online():
		begin_online_picks()
	elif need1:
		start_player_turn(1)
	else:
		start_player_turn(2)


# every player picks on their own screen, so there is no cover
# a player who is not asked goes straight to waiting
func begin_online_picks():
	current_player = Network.my_player
	title_label.add_theme_color_override("font_color", Actions.PLAYER_COLORS[current_player - 1])
	cover.visible = false
	if needs[current_player - 1]:
		reset_selection(current_player)
	else:
		start_waiting()


func start_waiting():
	waiting = true
	confirm_button.disabled = true
	title_label.text = "Waiting for opponent..."
	preview_cleared.emit()
	try_finish_online()


func on_opponent_pick():
	if waiting:
		try_finish_online()


# done once the opponent's pick is in, or right away when the opponent is not asked
func try_finish_online():
	var opponent = 3 - Network.my_player
	if needs[opponent - 1]:
		if not Network.opponent_pick_ready:
			return
		var pick = Network.take_opponent_pick()
		if opponent == 1:
			pick1 = pick
		else:
			pick2 = pick
	finish_picks()


# the cover goes up first so nothing of the previous pick is visible
func start_player_turn(player_number):
	current_player = player_number
	var color = Actions.PLAYER_COLORS[player_number - 1]
	cover_label.add_theme_color_override("font_color", color)
	title_label.add_theme_color_override("font_color", color)
	cover_label.text = "Player " + str(player_number) + "'s turn\nOther player look away, then press Ready"
	cover.visible = true
	reset_selection(player_number)


func on_ready_pressed():
	cover.visible = false


# a CanvasLayer ignores the parent's visibility, so the cover is hidden here as well
func finish_picks():
	waiting = false
	visible = false
	cover.visible = false
	preview_cleared.emit()
	both_picked.emit(pick1, pick2)


func on_confirm_pressed():
	var pick = {}
	pick["action"] = selected_action()
	pick["wheel"] = wheel.get_direction_name()

	if Network.is_online():
		confirm_online(pick)
		return

	if current_player == 1:
		pick1 = pick
		if needs[1]:
			start_player_turn(2)
		else:
			finish_picks()
	else:
		pick2 = pick
		finish_picks()


func confirm_online(pick):
	Network.send_pick(pick)
	if Network.my_player == 1:
		pick1 = pick
	else:
		pick2 = pick
	start_waiting()
