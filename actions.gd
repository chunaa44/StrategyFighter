extends Node

# ring order: neighbouring entries are neighbouring directions
const DIRECTION_NAMES = ["Up", "Up-Right", "Right", "Down-Right", "Down", "Down-Left", "Left", "Up-Left"]
const DIRECTION_VECTORS = [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
]

# range is in tiles, damage in hp, everything else in ticks
# total length of an action = startup + active + recovery
const DATA = {
	"Move": {"damage": 0, "hitstun": 0, "knockback": 0, "range": 1, "startup": 0, "active": 1, "recovery": 0},
	"Attack": {"damage": 10, "hitstun": 2, "knockback": 1, "range": 2, "startup": 1, "active": 1, "recovery": 2},
	"Block": {"damage": 0, "hitstun": 0, "knockback": 0, "range": 0, "startup": 0, "active": 3, "recovery": 1},
	"Grab": {"damage": 15, "hitstun": 3, "knockback": 1, "range": 1, "startup": 2, "active": 1, "recovery": 2},
}


func direction_from_name(direction_name):
	if direction_name == "None":
		return Vector2i(0, 0)
	var index = DIRECTION_NAMES.find(direction_name)
	return DIRECTION_VECTORS[index]


func direction_index(direction):
	return DIRECTION_VECTORS.find(direction)


func total_ticks(action_name):
	var data = DATA[action_name]
	return data["startup"] + data["active"] + data["recovery"]


# a block covers the direction it faces plus the two neighbours
func is_guarded(guard_direction, from_direction):
	var diff = absi(direction_index(guard_direction) - direction_index(from_direction))
	return diff == 0 or diff == 1 or diff == 7
