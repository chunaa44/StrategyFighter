extends Node

# damage, hitstun, knockback are used from day 4 on
# startup and recovery are in ticks, they are placeholders to tune later
const DATA = {
	"Move": {"damage": 0, "hitstun": 0, "knockback": 0, "startup": 0, "recovery": 0},
	"Attack": {"damage": 10, "hitstun": 2, "knockback": 1, "startup": 1, "recovery": 2},
	"Block": {"damage": 0, "hitstun": 0, "knockback": 0, "startup": 0, "recovery": 1},
	"Grab": {"damage": 12, "hitstun": 3, "knockback": 1, "startup": 2, "recovery": 3},
}
