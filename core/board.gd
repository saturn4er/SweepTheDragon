class_name Board
extends RefCounted
## 13x10 grid of tiles with the distance queries the rules are written in terms of.
## All distances are Euclidean between tile centres, matching the original game.

const W := 13
const H := 10
const CENTER := Vector2i(6, 4)

var tiles: Array[Tile] = []


func _init() -> void:
	for y in H:
		for x in W:
			tiles.append(Tile.new(Vector2i(x, y)))


func at(x: int, y: int) -> Tile:
	return tiles[y * W + x]


func at_pos(p: Vector2i) -> Tile:
	return tiles[p.y * W + p.x]


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < W and p.y < H


static func dist(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a - b).length()


## Tiles other than p with distance strictly below radius.
func within(p: Vector2i, radius: float) -> Array[Tile]:
	return _tiles_at(ring(p, radius, false))


## Tiles other than p with distance at most radius.
func within_inclusive(p: Vector2i, radius: float) -> Array[Tile]:
	return _tiles_at(ring(p, radius, true))


## Indices of the tiles around p for a given radius, computed once per radius and shared by
## every board. Hot loops iterate these directly instead of allocating tile arrays.
static var _rings := {}


func ring(p: Vector2i, radius: float, inclusive: bool) -> PackedInt32Array:
	var key := int(round(radius * 100.0)) * 2 + (1 if inclusive else 0)
	if not _rings.has(key):
		_rings[key] = _build_rings(radius, inclusive)
	return _rings[key][p.y * W + p.x]


static func _build_rings(radius: float, inclusive: bool) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	var r := ceili(radius)
	for y in H:
		for x in W:
			var idx := PackedInt32Array()
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx == 0 and dy == 0:
						continue
					var qx := x + dx
					var qy := y + dy
					if qx < 0 or qy < 0 or qx >= W or qy >= H:
						continue
					var d := Vector2(dx, dy).length()
					if d < radius or (inclusive and d == radius):
						idx.append(qy * W + qx)
			out.append(idx)
	return out


func _tiles_at(indices: PackedInt32Array) -> Array[Tile]:
	var out: Array[Tile] = []
	for i in indices:
		out.append(tiles[i])
	return out


func neighbors8(p: Vector2i) -> Array[Tile]:
	return within(p, 2.0)


func neighbors4(p: Vector2i) -> Array[Tile]:
	return within_inclusive(p, 1.0)


## Sum of monster levels around p. Defeated monsters still count until collected.
func attack_number(p: Vector2i) -> int:
	var total := 0
	for t in neighbors8(p):
		if t.level > 0:
			total += t.level
	return total


## True when an undefeated gazer sits within distance 2, which hides the number at p.
func gazer_near(p: Vector2i) -> bool:
	for t in within_inclusive(p, 2.0):
		if t.kind == Kind.GAZER and not t.defeated:
			return true
	return false


func swap(a: Tile, b: Tile) -> void:
	var ia := a.pos.y * W + a.pos.x
	var ib := b.pos.y * W + b.pos.x
	tiles[ia] = b
	tiles[ib] = a
	var tmp := a.pos
	a.pos = b.pos
	b.pos = tmp


func all_of(kind: int) -> Array[Tile]:
	var out: Array[Tile] = []
	for t in tiles:
		if t.kind == kind:
			out.append(t)
	return out


func first_of(kind: int) -> Tile:
	for t in tiles:
		if t.kind == kind:
			return t
	return null


func count_of(kind: int) -> int:
	var n := 0
	for t in tiles:
		if t.kind == kind:
			n += 1
	return n


func is_edge(p: Vector2i) -> bool:
	return p.x == 0 or p.y == 0 or p.x == W - 1 or p.y == H - 1


func is_corner(p: Vector2i) -> bool:
	return (p.x == 0 or p.x == W - 1) and (p.y == 0 or p.y == H - 1)


func is_close_to_edge(p: Vector2i) -> bool:
	return p.x <= 1 or p.y <= 1 or p.x >= W - 2 or p.y >= H - 2
