extends Control

# one wheel cell is drawn as a PIXEL x PIXEL square
const RADIUS = 14
const PIXEL = 6
const DEAD_ZONE = 3.5
const GAP = 0.7
const LABEL_HEIGHT = 28
const LABEL_SIZE = 18

const COLOR_RING = Color(0.85, 0.85, 0.9)
const COLOR_CENTER = Color(0.12, 0.12, 0.16)
const COLOR_SECTOR_A = Color(0.24, 0.26, 0.34)
const COLOR_SECTOR_B = Color(0.3, 0.32, 0.42)
const COLOR_HOVER = Color(0.45, 0.55, 0.8)
const COLOR_SELECTED = Color(0.95, 0.75, 0.2)
const COLOR_NEEDLE = Color(1.0, 1.0, 1.0)

var selected = 0
var hover = -1


func _ready():
	var cells = RADIUS * 2 + 1
	custom_minimum_size = Vector2(cells * PIXEL, cells * PIXEL + LABEL_HEIGHT)
	size = custom_minimum_size
	mouse_exited.connect(on_mouse_exited)


func select(index):
	selected = index
	queue_redraw()


func get_direction_name():
	return Actions.DIRECTION_NAMES[selected]


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pick_at(event.position)
	elif event is InputEventMouseMotion:
		hover = sector_at(event.position)
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			pick_at(event.position)
		queue_redraw()


func on_mouse_exited():
	hover = -1
	queue_redraw()


func pick_at(pixel_position):
	var index = sector_at(pixel_position)
	if index != -1:
		selected = index
		queue_redraw()


# -1 when the point is outside the wheel or on the dead centre
func sector_at(pixel_position):
	var middle = Vector2(RADIUS + 0.5, RADIUS + 0.5) * PIXEL
	var offset = (pixel_position - middle) / PIXEL
	var dist = offset.length()
	if dist > RADIUS + 0.5 or dist < DEAD_ZONE:
		return -1
	return sector_of_offset(offset)


# sectors start at Up and go clockwise, same order as Actions.DIRECTION_NAMES
func sector_of_offset(offset):
	var f = atan2(offset.x, -offset.y) / (PI / 4.0)
	return posmod(roundi(f), 8)


# cells on the line from the centre towards the selected direction
func needle_cells():
	var cells = {}
	var direction = Actions.DIRECTION_VECTORS[selected]
	for step in range(0, RADIUS):
		var cell = direction * step
		if Vector2(cell).length() > RADIUS - 1.5:
			break
		cells[cell] = true
	return cells


# null means the cell is left empty
func cell_color(offset, dist, needle):
	if dist > RADIUS - 0.5:
		return COLOR_RING
	if needle.has(Vector2i(offset)):
		return COLOR_NEEDLE
	if dist < DEAD_ZONE:
		return COLOR_CENTER

	var f = atan2(offset.x, -offset.y) / (PI / 4.0)
	var edge_distance = (0.5 - absf(f - roundf(f))) * (PI / 4.0) * dist
	if edge_distance < GAP:
		return null

	var index = posmod(roundi(f), 8)
	if index == selected:
		return COLOR_SELECTED
	if index == hover:
		return COLOR_HOVER
	if index % 2 == 0:
		return COLOR_SECTOR_A
	return COLOR_SECTOR_B


func _draw():
	var cells = RADIUS * 2 + 1
	var needle = needle_cells()

	for cy in range(cells):
		for cx in range(cells):
			var offset = Vector2(cx - RADIUS, cy - RADIUS)
			var dist = offset.length()
			if dist > RADIUS + 0.5:
				continue
			var color = cell_color(offset, dist, needle)
			if color == null:
				continue
			draw_rect(Rect2(Vector2(cx, cy) * PIXEL, Vector2(PIXEL, PIXEL)), color, true)

	var font = ThemeDB.fallback_font
	var label_position = Vector2(0, cells * PIXEL + LABEL_SIZE)
	draw_string(font, label_position, get_direction_name(), HORIZONTAL_ALIGNMENT_CENTER, cells * PIXEL, LABEL_SIZE, Color.WHITE)
