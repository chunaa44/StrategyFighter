extends Node2D

var hp = 100
var grid_position = Vector2i(0, 1)
var facing = 1
var hitstun_ticks = 0
var current_action = "none"
var wheel_index = 0
var di_index = 0

func set_color(new_color):
	$ColorRect.color = new_color
