extends Node2D

signal restart_pressed

# opacity of a result that is more than one tick old
const OLD_LOG_ALPHA = 0.45

@onready var p1_hp_label = $P1HpLabel
@onready var p2_hp_label = $P2HpLabel
@onready var p1_status_label = $P1StatusLabel
@onready var p2_status_label = $P2StatusLabel
@onready var advantage_label = $AdvantageLabel
@onready var result_label = $ResultLabel
@onready var restart_button = $RestartButton
@onready var storm_label = $StormLabel
@onready var last_result_label = $LastResultLabel


func _ready():
	var color1 = Actions.PLAYER_COLORS[0]
	var color2 = Actions.PLAYER_COLORS[1]
	p1_hp_label.add_theme_color_override("font_color", color1)
	p2_hp_label.add_theme_color_override("font_color", color2)
	p1_status_label.add_theme_color_override("font_color", color1)
	p2_status_label.add_theme_color_override("font_color", color2)
	restart_button.pressed.connect(on_restart_button_pressed)


func on_restart_button_pressed():
	restart_pressed.emit()


func refresh(fighter1, fighter2):
	p1_hp_label.text = "P1 HP: " + str(fighter1.hp)
	p2_hp_label.text = "P2 HP: " + str(fighter2.hp)
	p1_status_label.text = status_text("P1", fighter1)
	p2_status_label.text = status_text("P2", fighter2)


func refresh_storm(storm):
	var text = "Final ring"
	if not storm.is_final_stage():
		text = "Ring closes in " + str(storm.ticks_until_close())
	storm_label.text = text


# a tick without news keeps the previous result, faded so it reads as old
func show_log(lines):
	if lines.is_empty():
		last_result_label.modulate.a = OLD_LOG_ALPHA
		return
	last_result_label.text = "\n".join(lines)
	last_result_label.modulate.a = 1.0


func clear_log():
	last_result_label.text = ""


# a disguised rush shows no numbers, the length would reveal which of the two it is
# between ticks the phase belongs to the tick that has not played yet and is marked as next
func status_text(title, fighter):
	var text = title + "\n"
	if fighter.hitstun_ticks > 0:
		return text + "Stunned " + str(fighter.hitstun_ticks)
	if fighter.stunned:
		return text + "Stunned"
	if fighter.current_action == "none":
		return text + "Free"

	if fighter.is_disguised():
		text += "Rush ?/?\n"
	else:
		text += fighter.current_action + " " + str(fighter.action_tick) + "/" + str(Actions.total_ticks(fighter.current_action)) + "\n"

	if not fighter.playing:
		text += "Next:\n"
	return text + fighter.phase_name()


# frame advantage from the point of view of the player choosing
# positive means that player can start the next action that many ticks before the opponent
# a disguised rush hides it, the length would reveal which of the two it is
func show_advantage(player_number, fighter1, fighter2):
	advantage_label.add_theme_color_override("font_color", Actions.PLAYER_COLORS[player_number - 1])
	if fighter1.is_disguised() or fighter2.is_disguised():
		advantage_label.text = "Frame advantage: ?"
		return

	var mine = fighter1
	var theirs = fighter2
	if player_number == 2:
		mine = fighter2
		theirs = fighter1

	var advantage = theirs.ticks_until_free() - mine.ticks_until_free()
	var advantage_text = str(advantage)
	if advantage > 0:
		advantage_text = "+" + advantage_text
	advantage_label.text = "Frame advantage: " + advantage_text


func clear_advantage():
	advantage_label.text = ""


func show_result(text, color):
	result_label.text = text
	result_label.add_theme_color_override("font_color", color)
	restart_button.visible = true


func clear_result():
	result_label.text = ""
	restart_button.visible = false
