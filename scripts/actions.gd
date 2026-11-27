extends Node

# index 0 is player 1, kept away from the effect colours (red, orange, cyan, white, yellow)
const PLAYER_COLORS = [Color(0.35, 0.85, 0.4), Color(0.72, 0.45, 0.95)]

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

# damage in hp, slide and range in tiles, everything else in ticks
# slide: tiles travelled along the aim on the active tick, it stops next to the opponent
# range: how far the hit reaches from where the fighter stands after sliding
# reflect: hp the attacker loses when a strike is blocked, 0 for everything that cannot be blocked
# cancel: the fighter chooses again while fewer than this many ticks of the action have played
#   Hold keeps the action going, any other pick replaces it, 0 means no cancel window
# total length of an action = startup + active + recovery
# hit advantage = hitstun - recovery: positive means the attacker is free first
#   +2 or more guarantees a Jab follow-up, so Jab stays at +1 to keep it from chaining into itself
const DATA = {
	"Move": {"damage": 0, "hitstun": 0, "range": 0, "reflect": 0, "slide": 1, "startup": 0, "active": 1, "recovery": 1, "cancel": 0},
	"Dash": {"damage": 0, "hitstun": 0, "range": 0, "reflect": 0, "slide": 2, "startup": 2, "active": 1, "recovery": 1, "cancel": 2},
	"Jab": {"damage": 15, "hitstun": 2, "range": 2, "reflect": 8, "slide": 0, "startup": 1, "active": 1, "recovery": 1, "cancel": 0},
	"Lunge": {"damage": 40, "hitstun": 6, "range": 1, "reflect": 20, "slide": 3, "startup": 2, "active": 1, "recovery": 4, "cancel": 2},
	"Block": {"damage": 0, "hitstun": 0, "range": 0, "reflect": 0, "slide": 0, "startup": 1, "active": 2, "recovery": 1, "cancel": 0},
	"Grab": {"damage": 30, "hitstun": 5, "range": 1, "reflect": 0, "slide": 0, "startup": 2, "active": 1, "recovery": 3, "cancel": 2},
	"Hold": {"damage": 0, "hitstun": 0, "range": 0, "reflect": 0, "slide": 0, "startup": 0, "active": 2, "recovery": 0, "cancel": 0},
}


func direction_from_name(direction_name):
	var index = DIRECTION_NAMES.find(direction_name)
	return DIRECTION_VECTORS[index]


func direction_index(direction):
	return DIRECTION_VECTORS.find(direction)


func total_ticks(action_name):
	var data = DATA[action_name]
	return data["startup"] + data["active"] + data["recovery"]


# strikes can be blocked and beat a grab that lands on the same tick
func is_strike(action_name):
	return action_name == "Jab" or action_name == "Lunge"


# dash and lunge look the same until they become active
func is_rush(action_name):
	return action_name == "Dash" or action_name == "Lunge"


# a block covers the direction it faces plus the two neighbours
func is_guarded(guard_direction, from_direction):
	var diff = absi(direction_index(guard_direction) - direction_index(from_direction))
	return diff == 0 or diff == 1 or diff == 7


# every tile after start up to and including target, target lies on a straight line from start
func path_tiles(start, target):
	var tiles = []
	var delta = target - start
	var step = Vector2i(signi(delta.x), signi(delta.y))
	var count = maxi(absi(delta.x), absi(delta.y))
	for i in range(1, count + 1):
		tiles.append(start + step * i)
	return tiles
