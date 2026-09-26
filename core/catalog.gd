class_name Catalog
## Static definitions for every tile kind: combat stats, names, death messages and book layout.

const MINE_LEVEL := 100

## A kind is a monster when it has a "level" entry. xp defaults to level.
const DEFS := {
	Kind.EMPTY: {"name": "empty"},
	Kind.DRAGON: {"name": "dragon", "level": 13, "death": "torched by the dragon"},
	Kind.WIZARD: {"name": "wizard", "level": 1, "death": "zapped by the wizard"},
	Kind.BIG_SLIME: {"name": "big slime", "level": 8, "death": "liquefied by a slime"},
	Kind.MINE_KING: {"name": "mine king", "level": 10, "death": "crushed by the mine king"},
	Kind.GIANT: {"name": "giant", "level": 9, "death": "mauled by giant"},
	Kind.RAT_KING: {"name": "rat king", "level": 5, "death": "killed by the rat king"},
	Kind.WALL: {"name": "wall"},
	Kind.MINOTAUR: {"name": "minotaur", "level": 6, "death": "trampled by a minotaur"},
	Kind.GUARD: {"name": "guardian", "level": 7, "death": "killed by a guardian"},
	Kind.GARGOYLE: {"name": "gargoyle", "level": 4, "death": "petrified by a gargoyle"},
	Kind.GAZER: {"name": "gazer", "level": 5, "death": "lobotomized by a gazer"},
	Kind.MINE: {"name": "mine", "level": MINE_LEVEL, "xp": 3, "death": "exploded by a mine"},
	Kind.MEDIKIT: {"name": "medikit"},
	Kind.CHEST: {"name": "chest"},
	Kind.ORB: {"name": "orb"},
	Kind.DRAGON_EGG: {"name": "dragon egg", "level": 0, "xp": 3, "death": "this should never happen"},
	Kind.RAT: {"name": "rat", "level": 1, "death": "killed by a rat"},
	Kind.BAT: {"name": "bat", "level": 2, "death": "killed by a bat"},
	Kind.SKELETON: {"name": "skeleton", "level": 3, "death": "slain by a skeleton"},
	Kind.SLIME: {"name": "slime", "level": 5, "death": "consumed by a slime"},
	Kind.MIMIC: {"name": "mimic", "level": 11, "death": "eaten by the mimic"},
	Kind.GNOME: {"name": "gnome", "level": 0, "xp": 9, "death": "this should never happen"},
	Kind.SPELL_ORB: {"name": "orb scroll"},
	Kind.TREASURE: {"name": "treasure"},
	Kind.SPELL_REVEAL_RATS: {"name": "rat scroll"},
	Kind.SPELL_REVEAL_SLIMES: {"name": "slime scroll"},
	Kind.SPELL_DISARM: {"name": "disarm scroll"},
	Kind.CROWN: {"name": "crown"},
}

## What a defeated monster turns into once its xp is collected.
const DROPS := {
	Kind.DRAGON: Kind.CROWN,
	Kind.RAT_KING: Kind.SPELL_REVEAL_RATS,
	Kind.WIZARD: Kind.SPELL_REVEAL_SLIMES,
	Kind.GIANT: Kind.MEDIKIT,
	Kind.MINE_KING: Kind.SPELL_DISARM,
}

## Rows of the monsternomicon, top to bottom, first column then second.
const BOOK_ORDER: Array[int] = [
	Kind.RAT, Kind.BAT, Kind.SKELETON, Kind.GARGOYLE, Kind.SLIME,
	Kind.MINOTAUR, Kind.GUARD, Kind.BIG_SLIME, Kind.GIANT, Kind.MINE_KING,
	Kind.RAT_KING, Kind.GAZER, Kind.WIZARD, Kind.MIMIC, Kind.MINE,
	Kind.CHEST, Kind.GNOME, Kind.MEDIKIT, Kind.SPELL_ORB, Kind.SPELL_DISARM,
]


static func is_monster(kind: int) -> bool:
	return DEFS.get(kind, {}).has("level")


static func level(kind: int) -> int:
	return DEFS.get(kind, {}).get("level", 0)


static func xp(kind: int) -> int:
	var def: Dictionary = DEFS.get(kind, {})
	return def.get("xp", def.get("level", 0))


static func display_name(kind: int) -> String:
	return DEFS.get(kind, {}).get("name", "none")


static func death_message(kind: int) -> String:
	return DEFS.get(kind, {}).get("death", "killed by something")


static func drop_for(kind: int) -> int:
	return DROPS.get(kind, Kind.EMPTY)
