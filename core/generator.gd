class_name Generator
extends RefCounted
## Builds a dungeon the way the original does: actors are added in layers, and each layer is
## nudged into place by a hill-climbing "happiness" score before being frozen.

const PASSES := 4
const ORB_RADIUS := 2.1
const WALL_HP := 3
const ORB_FORBIDDEN: Array[int] = [
	Kind.DRAGON, Kind.GAZER, Kind.CHEST, Kind.SPELL_ORB, Kind.RAT_KING,
	Kind.MINE, Kind.DRAGON_EGG, Kind.BIG_SLIME, Kind.MIMIC,
]

## Kinds whose happiness term reads the positions of other kinds. A swap can only change the
## terms of the two swapped tiles and of tiles whose kind references one of the swapped kinds.
const REFERENCES := {
	Kind.DRAGON_EGG: [Kind.DRAGON],
	Kind.GNOME: [Kind.MEDIKIT],
	Kind.GIANT: [Kind.GIANT],
	Kind.BIG_SLIME: [Kind.WIZARD],
	Kind.MINOTAUR: [Kind.CHEST, Kind.MINOTAUR],
	Kind.GARGOYLE: [Kind.GARGOYLE],
	Kind.ORB: [
		Kind.DRAGON, Kind.GAZER, Kind.CHEST, Kind.SPELL_ORB, Kind.RAT_KING, Kind.MINE,
		Kind.DRAGON_EGG, Kind.BIG_SLIME, Kind.MIMIC, Kind.MEDIKIT, Kind.WALL,
	],
	Kind.MEDIKIT: [Kind.MEDIKIT],
	Kind.CHEST: [Kind.CHEST],
	Kind.WALL: [Kind.WALL],
}

## How far a referring kind looks when scoring itself. A swap farther away than this from a
## referrer cannot change its term. Minotaurs look at chests within 2 and at other minotaurs
## within 2 of those chests, so they see up to 4. Giants look at each other anywhere.
const DEP_RADIUS := {
	Kind.DRAGON_EGG: 1.5,
	Kind.GNOME: 1.5,
	Kind.GIANT: 1000.0,
	Kind.BIG_SLIME: 1.5,
	Kind.MINOTAUR: 4.0,
	Kind.GARGOYLE: 1.0,
	Kind.ORB: 2.1,
	Kind.MEDIKIT: 3.5,
	Kind.CHEST: 3.0,
	Kind.WALL: 1.5,
}

## Kinds that have a happiness term of their own.
const HAS_TERM: Array[int] = [
	Kind.DRAGON_EGG, Kind.GNOME, Kind.GUARD, Kind.GIANT, Kind.BIG_SLIME, Kind.WIZARD,
	Kind.MINE_KING, Kind.DRAGON, Kind.MINOTAUR, Kind.GARGOYLE, Kind.ORB, Kind.MEDIKIT,
	Kind.CHEST, Kind.WALL,
]

var board: Board
var rng: Rng
## Tile iteration order. Reshuffled every pass, which also randomises where later layers start.
var _order: Array[Tile] = []
var _layer: Array[Tile] = []
var _referenced_by := {}
var _by_kind := {}


static func generate(target: Board, random: Rng) -> void:
	var g := Generator.new()
	g.board = target
	g.rng = random
	g.run()


func _init() -> void:
	for referrer in REFERENCES:
		for referenced in REFERENCES[referrer]:
			if not _referenced_by.has(referenced):
				_referenced_by[referenced] = []
			_referenced_by[referenced].append(referrer)


func run() -> void:
	_order = board.tiles.duplicate()

	_begin_layer()
	_add(Kind.DRAGON)
	_add(Kind.WIZARD)
	_end_layer()

	_begin_layer()
	_add_n(5, Kind.BIG_SLIME)
	_end_layer()

	_begin_layer()
	_add(Kind.MINE_KING)
	_end_layer()

	_begin_layer()
	_add(Kind.GIANT).role = "romeo"
	_add(Kind.GIANT).role = "juliet"
	_end_layer()

	_begin_layer()
	_add(Kind.RAT_KING)
	_add_n(6, Kind.WALL)
	_add_n(5, Kind.MINOTAUR)
	for i in 4:
		_add(Kind.GUARD).role = "guard%d" % (i + 1)
	for i in 4:
		for _j in 2:
			_add(Kind.GARGOYLE).role = "gargoyle%d" % (i + 1)
	_add_n(2, Kind.GAZER)
	_add_n(9, Kind.MINE)
	_add_n(5, Kind.MEDIKIT)
	_add_n(3, Kind.CHEST)
	for _i in 2:
		var chest := _add(Kind.CHEST)
		chest.contains = Kind.MEDIKIT
		chest.contains_xp = 0
	var orb := _add(Kind.ORB)
	orb.revealed = true
	orb.role = "orb_with_healing"
	_add(Kind.DRAGON_EGG)
	_end_layer()

	_begin_layer()
	_add_n(13, Kind.RAT)
	_add_n(12, Kind.BAT)
	_add_n(10, Kind.SKELETON)
	_add_n(8, Kind.SLIME)
	_add(Kind.MIMIC)
	_add(Kind.GNOME)
	_add(Kind.SPELL_ORB)
	_end_layer()

	_finalize()


func _begin_layer() -> void:
	_layer = []


func _add(kind: int) -> Tile:
	var t := Tile.new()
	t.become(kind)
	_layer.append(t)
	return t


func _add_n(n: int, kind: int) -> void:
	for _i in n:
		_add(kind)


func _end_layer() -> void:
	var placed: Array[Tile] = []
	for proto in _layer:
		var target: Tile = null
		for t in _order:
			if t.is_empty():
				target = t
				break
		if target == null:
			continue
		target.copy_from(proto)
		placed.append(target)

	_index_kinds()
	for _k in PASSES:
		rng.shuffle(_order)
		for a in placed:
			var best := _best_swap(a)
			if best != null:
				board.swap(a, best)

	for a in placed:
		a.fixed = true


func _index_kinds() -> void:
	_by_kind = {}
	for t in board.tiles:
		if t.is_empty():
			continue
		if not _by_kind.has(t.kind):
			_by_kind[t.kind] = []
		_by_kind[t.kind].append(t)


## Candidate with the highest non-negative happiness change; ties go to the last candidate.
func _best_swap(a: Tile) -> Tile:
	var best: Tile = null
	var best_delta := 0
	var inert := not HAS_TERM.has(a.kind) and not _referenced_by.has(a.kind)
	for b in _order:
		if b.fixed or b == a:
			continue
		var d := 0 if inert else _swap_delta(a, b)
		if d >= best_delta:
			best_delta = d
			best = b
	return best


func _swap_delta(a: Tile, b: Tile) -> int:
	var affected := _affected_by(a, b)
	var before := 0
	for t in affected:
		before += term(t)
	board.swap(a, b)
	var after := 0
	for t in affected:
		after += term(t)
	board.swap(a, b)
	return after - before


func _affected_by(a: Tile, b: Tile) -> Array[Tile]:
	var out: Array[Tile] = [a, b]
	for kind in [a.kind, b.kind]:
		for referrer in _referenced_by.get(kind, []):
			var reach: float = DEP_RADIUS[referrer] + 0.01
			for t in _by_kind.get(referrer, []):
				if t == a or t == b or out.has(t):
					continue
				if Board.dist(t.pos, a.pos) <= reach or Board.dist(t.pos, b.pos) <= reach:
					out.append(t)
	return out


## Full board score. Used by tests and as the reference the incremental deltas must match.
static func happiness(b: Board) -> int:
	var g := Generator.new()
	g.board = b
	var total := 0
	for t in b.tiles:
		total += g.term(t)
	return total


func term(t: Tile) -> int:
	match t.kind:
		Kind.DRAGON_EGG:
			return 9000 if _close_to(t, Kind.DRAGON, 1.5) else 0
		Kind.GNOME:
			return 10000 if _close_to(t, Kind.MEDIKIT, 1.5) else 0
		Kind.GUARD:
			return 2500 if guard_in_quadrant(t) else 0
		Kind.GIANT:
			return _giant_term(t)
		Kind.BIG_SLIME:
			return 1000 if _close_to(t, Kind.WIZARD, 1.5) else 0
		Kind.WIZARD:
			return 10000 if (board.is_edge(t.pos) and not board.is_corner(t.pos)) else 0
		Kind.MINE_KING:
			return 10000 if board.is_corner(t.pos) else 0
		Kind.DRAGON:
			return 10000 if t.pos == Board.CENTER else 0
		Kind.MINOTAUR:
			return 10000 if minotaur_has_own_chest(t) else 0
		Kind.GARGOYLE:
			return 1000 if gargoyle_twin(t) != null else 0
		Kind.ORB:
			return _orb_term(t)
		Kind.MEDIKIT:
			return -1000 * _count_kind_within(t, Kind.MEDIKIT, 3.5)
		Kind.CHEST:
			return -1000 * _count_kind_within(t, Kind.CHEST, 3.0)
		Kind.WALL:
			return _wall_term(t)
	return 0


func _giant_term(t: Tile) -> int:
	var other: Tile = null
	for g in board.tiles:
		if g.kind == Kind.GIANT and g != t:
			other = g
	if other == null:
		return 0
	var ret := 0
	if (t.role == "romeo" and t.pos.x <= 5) or (t.role == "juliet" and t.pos.x >= 7):
		ret += 1000
	var cx := Board.CENTER.x
	if other.pos.y == t.pos.y and absi(t.pos.x - cx) == absi(other.pos.x - cx):
		ret += 10000
	return ret


func _orb_term(t: Tile) -> int:
	var ret := 0
	if board.is_close_to_edge(t.pos):
		ret -= 10000
	var forbidden := 0
	var medikits := 0
	var walls := 0
	var tiles := board.tiles
	for i in board.ring(t.pos, ORB_RADIUS, false):
		var b := tiles[i]
		if ORB_FORBIDDEN.has(b.kind):
			forbidden += 1
		if b.kind == Kind.MEDIKIT:
			medikits += 1
		elif b.kind == Kind.WALL:
			walls += 1
	ret -= forbidden * 2000
	if walls > 2:
		ret -= (walls - 2) * 2000
	if medikits == 1 and walls > 0:
		ret += 2000
	return ret


func _wall_term(t: Tile) -> int:
	var close := 0
	var far := 0
	var on_edge := 1 if board.is_edge(t.pos) else 0
	var tiles := board.tiles
	for i in board.ring(t.pos, 1.5, false):
		var b := tiles[i]
		if b.kind != Kind.WALL:
			continue
		if absi(t.pos.x - b.pos.x) + absi(t.pos.y - b.pos.y) == 1:
			close += 1
			if board.is_edge(b.pos):
				on_edge += 1
		else:
			far += 1
	return 2000 if (close == 1 and far == 0 and on_edge < 2) else 0


func _close_to(t: Tile, kind: int, radius: float) -> bool:
	var tiles := board.tiles
	for i in board.ring(t.pos, radius, false):
		if tiles[i].kind == kind:
			return true
	return false


func _count_kind_within(t: Tile, kind: int, radius: float) -> int:
	var n := 0
	var tiles := board.tiles
	for i in board.ring(t.pos, radius, false):
		if tiles[i].kind == kind:
			n += 1
	return n


func guard_in_quadrant(t: Tile) -> bool:
	var p := t.pos
	match t.role:
		"guard1":
			return p.x < 6 and p.y < 4
		"guard2":
			return p.x > 6 and p.y < 4
		"guard3":
			return p.x > 6 and p.y > 4
		"guard4":
			return p.x < 6 and p.y > 4
	return false


## Exactly one chest within distance 2 in another column, with no other minotaur near that chest.
func minotaur_has_own_chest(t: Tile) -> bool:
	var chests := 0
	var crowded := false
	var tiles := board.tiles
	for i in board.ring(t.pos, 2.0, false):
		var c := tiles[i]
		if c.kind != Kind.CHEST or c.pos.x == t.pos.x:
			continue
		chests += 1
		for j in board.ring(c.pos, 2.0, false):
			var m := tiles[j]
			if m.kind == Kind.MINOTAUR and m != t:
				crowded = true
				break
	return chests == 1 and not crowded


func gargoyle_twin(t: Tile) -> Tile:
	var tiles := board.tiles
	for i in board.ring(t.pos, 1.0, true):
		var g := tiles[i]
		if g.kind == Kind.GARGOYLE and g.role == t.role:
			return g
	return null


func _finalize() -> void:
	for t in board.tiles:
		match t.kind:
			Kind.MINOTAUR:
				for c in board.within(t.pos, 1.5):
					if c.kind == Kind.CHEST:
						t.minotaur_chest = c.pos
			Kind.DRAGON:
				t.revealed = true
			Kind.WALL:
				t.wall_hp = WALL_HP
				t.wall_max_hp = WALL_HP


## The original's own sanity checks plus the expected roster. Returns a list of failures.
static func check_invariants(b: Board) -> Array[String]:
	var fails: Array[String] = []
	var g := Generator.new()
	g.board = b
	var expected := {
		Kind.DRAGON: 1, Kind.WIZARD: 1, Kind.BIG_SLIME: 5, Kind.MINE_KING: 1, Kind.GIANT: 2,
		Kind.RAT_KING: 1, Kind.WALL: 6, Kind.MINOTAUR: 5, Kind.GUARD: 4, Kind.GARGOYLE: 8,
		Kind.GAZER: 2, Kind.MINE: 9, Kind.MEDIKIT: 5, Kind.CHEST: 5, Kind.ORB: 1,
		Kind.DRAGON_EGG: 1, Kind.RAT: 13, Kind.BAT: 12, Kind.SKELETON: 10, Kind.SLIME: 8,
		Kind.MIMIC: 1, Kind.GNOME: 1, Kind.SPELL_ORB: 1,
	}
	for kind in expected:
		var n := b.count_of(kind)
		if n != expected[kind]:
			fails.append("%s count %d != %d" % [Catalog.display_name(kind), n, expected[kind]])
	for t in b.tiles:
		match t.kind:
			Kind.BIG_SLIME:
				if not g._close_to(t, Kind.WIZARD, 1.5):
					fails.append("misplaced big slime at %s" % t.pos)
			Kind.GARGOYLE:
				if g.gargoyle_twin(t) == null:
					fails.append("gargoyle without twin at %s" % t.pos)
			Kind.GUARD:
				if not g.guard_in_quadrant(t):
					fails.append("%s outside quadrant at %s" % [t.role, t.pos])
			Kind.MINE_KING:
				if not b.is_corner(t.pos):
					fails.append("mine king not in corner at %s" % t.pos)
			Kind.GIANT:
				var other: Tile = null
				for o in b.all_of(Kind.GIANT):
					if o != t:
						other = o
				if other == null:
					continue
				if (t.role == "romeo" and t.pos.x > 5) or (t.role == "juliet" and t.pos.x < 7):
					fails.append("%s on wrong side at %s" % [t.role, t.pos])
				if other.pos.y != t.pos.y or absi(t.pos.x - 6) != absi(other.pos.x - 6):
					fails.append("giants not mirrored: %s %s" % [t.pos, other.pos])
			Kind.MINOTAUR:
				var chests := 0
				for c in b.within(t.pos, 1.5):
					if c.kind == Kind.CHEST:
						chests += 1
				if chests != 1:
					fails.append("minotaur at %s has %d chests" % [t.pos, chests])
			Kind.DRAGON:
				if t.pos != Board.CENTER:
					fails.append("dragon at %s" % t.pos)
				if not t.revealed:
					fails.append("dragon hidden")
			Kind.WIZARD:
				if not (b.is_edge(t.pos) and not b.is_corner(t.pos)):
					fails.append("wizard at %s" % t.pos)
			Kind.DRAGON_EGG:
				if not g._close_to(t, Kind.DRAGON, 1.5):
					fails.append("egg away from dragon at %s" % t.pos)
	return fails
