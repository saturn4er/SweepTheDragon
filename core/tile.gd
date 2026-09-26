class_name Tile
extends RefCounted
## One cell of the board. Holds what is there and what the player knows about it.

var pos: Vector2i
var kind: int = Kind.EMPTY
var level := 0
var xp := 0
var is_monster := false
var revealed := false
var defeated := false
var mark := 0
var wall_hp := 0
var wall_max_hp := 0
## Kind produced when a chest is opened or a wall is broken.
var contains: int = Kind.NONE
var contains_xp := 0
var role := ""
var mimicking := false
var minotaur_chest := Vector2i(-1, -1)
## Set by the generator once a layer is optimised; fixed tiles never move again.
var fixed := false


func _init(p := Vector2i.ZERO) -> void:
	pos = p


func is_empty() -> bool:
	return kind == Kind.EMPTY


func reset() -> void:
	var keep_pos := pos
	var keep_fixed := fixed
	var fresh := Tile.new()
	copy_from(fresh)
	pos = keep_pos
	fixed = keep_fixed


func copy_from(o: Tile) -> void:
	kind = o.kind
	level = o.level
	xp = o.xp
	is_monster = o.is_monster
	revealed = o.revealed
	defeated = o.defeated
	mark = o.mark
	wall_hp = o.wall_hp
	wall_max_hp = o.wall_max_hp
	contains = o.contains
	contains_xp = o.contains_xp
	role = o.role
	mimicking = o.mimicking
	minotaur_chest = o.minotaur_chest


## Turns the tile into a fresh instance of `new_kind`, clearing player knowledge about it.
func become(new_kind: int, treasure_xp := 0) -> void:
	reset()
	kind = new_kind
	is_monster = Catalog.is_monster(new_kind)
	level = Catalog.level(new_kind)
	xp = Catalog.xp(new_kind)
	match new_kind:
		Kind.TREASURE:
			xp = treasure_xp
		Kind.CHEST:
			contains = Kind.TREASURE
			contains_xp = 5
		Kind.WALL:
			contains = Kind.TREASURE
			contains_xp = 1
		Kind.MIMIC:
			mimicking = true
