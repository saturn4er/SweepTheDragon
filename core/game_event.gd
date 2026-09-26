class_name GameEvent
extends RefCounted
## Something that happened during a turn. The presentation turns these into sounds and effects.

enum Type {
	REVEALED,          # pos; flag = revealed by pressing (click) rather than by an effect
	ATTACKED,          # pos, kind, amount = damage, flag = monster defeated
	COLLECTED,         # pos, kind, amount = xp
	HEALED,            # pos
	REFUSED,           # pos; the action was not allowed ("wrong" sound)
	WALL_HIT,          # pos, amount = hp left
	WALL_DOWN,         # pos
	CHEST_OPENED,      # pos
	GNOME_JUMPED,      # pos = from, target = to
	MINES_DISARMED,    # amount = mines affected
	MINE_DISARMED_AT,  # pos of a revealed mine that just went inert
	SPELL_CAST,        # kind of scroll, flag = it had an effect
	ORB_USED,          # pos, flag = it revealed something
	NUMBER_CHANGED,    # pos of a tile whose number just changed
	DRAGON_DEFEATED,   # pos
	MINE_EXPLODED,     # pos
	LEVEL_UP,          # amount = new level, flag = gained a full heart, target.x = heart index
	CAN_LEVEL_UP,
	ALARM,             # down to one heart with no level up available
	HP_CHANGED,        # amount = old hp, target.x = new hp
	XP_CHANGED,        # amount = old xp, target.x = new xp
	DIED,              # kind = killer
	WON,
	HERO_TAPPED,
	MARK_SET,          # pos, amount = mark
}

var type: Type
var pos := Vector2i(-1, -1)
var target := Vector2i(-1, -1)
var kind: int = Kind.NONE
var amount := 0
var flag := false


static func make(t: Type, p := Vector2i(-1, -1)) -> GameEvent:
	var e := GameEvent.new()
	e.type = t
	e.pos = p
	return e


func with_kind(k: int) -> GameEvent:
	kind = k
	return self


func with_amount(a: int) -> GameEvent:
	amount = a
	return self


func with_flag(f: bool) -> GameEvent:
	flag = f
	return self


func with_target(t: Vector2i) -> GameEvent:
	target = t
	return self
