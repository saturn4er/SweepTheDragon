class_name Player
extends RefCounted
## Jorge's hearts, experience and level.

const MAX_HP := 19
const START_MAX_HP := 6
## XP needed to leave each level, indexed by level. Clamped at the last entry.
const XP_TABLE: Array[int] = [0, 4, 5, 7, 9, 9, 10, 12, 12, 12, 15, 18, 21, 21, 25]

var max_hp := START_MAX_HP
var hp := START_MAX_HP
var xp := 0
var level := 1
var score := 0


static func xp_to_next(for_level: int) -> int:
	return XP_TABLE[mini(for_level, XP_TABLE.size() - 1)]


## Even levels only fill half a heart; odd levels add a full one.
static func is_half_heart_level(for_level: int) -> bool:
	return for_level % 2 == 0


func can_level_up() -> bool:
	return hp > 0 and xp >= xp_to_next(level)


func grant_xp(amount: int) -> void:
	xp += amount
	score += amount


## Spends xp, raises the level and refills hearts. Returns true when a full heart was added.
func level_up() -> bool:
	xp -= xp_to_next(level)
	level += 1
	var gained_full_heart := false
	if max_hp < MAX_HP and not is_half_heart_level(level):
		max_hp += 1
		gained_full_heart = true
	hp = max_hp
	return gained_full_heart
