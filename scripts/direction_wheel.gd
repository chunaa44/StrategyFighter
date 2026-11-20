extends Control

signal direction_changed

# the wheel is drawn on a small grid, one cell is a PIXEL x PIXEL square
const RADIUS = 12
const PIXEL = 6
const DEAD_ZONE = 2.5
const MARKER_DISTANCE = 8.0

const COLOR_RING = Color(0.85, 0.85, 0.9)
const COLOR_DISC = Color(0.12, 0.12, 0.16)
const COLOR_MARKER = Color(0.45, 0.47, 0.58)
const COLOR_SELECTED = Color(0.95, 0.75, 0.2)

var selected = 0


func _ready():
	var cells = RADIUS * 2 + 1
	custom_minimum_size = Vector2(cells * PIXEL, cells * PIXEL)
	size = custom_minimum_size


func select(index):
	selected = index
	queue_redraw()


func get_direction_name():
	return Actions.DIRECTION_NAMES[selected]


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var index = sector_at(event.position)
			if index != -1 and index != selected:
				selected = index
				queue_redraw()
				direction_changed.emit()


# -1 when the point is outside the wheel or on the dead centre
func sector_at(pixel_position):
	var middle = Vector2(RADIUS + 0.5, RADIUS + 0.5) * PIXEL
	var offset = (pixel_position - middle) / PIXEL
	var dist = offset.length()
	if dist > RADIUS + 0.5 or dist < DEAD_ZONE:
		return -1
	# sectors start at Up and go clockwise, same order as Actions.DIRECTION_NAMES
	var f = atan2(offset.x, -offset.y) / (PI / 4.0)
	return posmod(roundi(f), 8)


# grid cell of a direction marker, relative to the centre cell
func marker_cell(index):
	var direction = Vector2(Actions.DIRECTION_VECTORS[index]).normalized()
	return Vector2i((direction * MARKER_DISTANCE).round())


# cell is relative to the centre cell
func draw_cell(cell, color):
	var origin = (Vector2(RADIUS, RADIUS) + Vector2(cell)) * PIXEL
	draw_rect(Rect2(origin, Vector2(PIXEL, PIXEL)), color, true)


func draw_marker(cell, color):
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			draw_cell(cell + Vector2i(dx, dy), color)


func _draw():
	for cy in range(RADIUS * 2 + 1):
		for cx in range(RADIUS * 2 + 1):
			var cell = Vector2i(cx - RADIUS, cy - RADIUS)
			var dist = Vector2(cell).length()
			if dist > RADIUS + 0.5:
				continue
			if dist > RADIUS - 0.8:
				draw_cell(cell, COLOR_RING)
			else:
				draw_cell(cell, COLOR_DISC)

	# line from the centre to the selected marker
	var direction = Actions.DIRECTION_VECTORS[selected]
	var target = marker_cell(selected)
	var length = maxi(absi(target.x), absi(target.y))
	for step in range(0, length + 1):
		draw_cell(direction * step, COLOR_SELECTED)

	for i in range(8):
		if i != selected:
			draw_marker(marker_cell(i), COLOR_MARKER)
	draw_marker(target, COLOR_SELECTED)
