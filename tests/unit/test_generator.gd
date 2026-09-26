extends GutTest


func _generate(seed_value: int) -> Board:
	var b := Board.new()
	Generator.generate(b, Rng.new(seed_value))
	return b


func test_boards_satisfy_every_invariant_over_many_seeds() -> void:
	for s in range(1, 31):
		var b := _generate(s)
		var fails := Generator.check_invariants(b)
		assert_eq(fails, [], "seed %d: %s" % [s, fails])


func test_same_seed_gives_same_board() -> void:
	var a := _generate(42)
	var b := _generate(42)
	for i in a.tiles.size():
		assert_eq(a.tiles[i].kind, b.tiles[i].kind)
		assert_eq(a.tiles[i].role, b.tiles[i].role)


func test_different_seeds_differ() -> void:
	var a := _generate(1)
	var b := _generate(2)
	var same := 0
	for i in a.tiles.size():
		if a.tiles[i].kind == b.tiles[i].kind:
			same += 1
	assert_lt(same, a.tiles.size())


func test_starting_orb_is_revealed_and_nothing_else_but_dragon() -> void:
	var b := _generate(7)
	var revealed: Array[int] = []
	for t in b.tiles:
		if t.revealed:
			revealed.append(t.kind)
	revealed.sort()
	var expected: Array[int] = [Kind.DRAGON, Kind.ORB]
	expected.sort()
	assert_eq(revealed, expected)


func test_walls_have_three_hp_and_minotaurs_know_their_chest() -> void:
	var b := _generate(3)
	for t in b.tiles:
		if t.kind == Kind.WALL:
			assert_eq(t.wall_hp, 3)
			assert_eq(t.contains, Kind.TREASURE)
			assert_eq(t.contains_xp, 1)
		elif t.kind == Kind.MINOTAUR:
			assert_ne(t.minotaur_chest, Vector2i(-1, -1))
			assert_eq(b.at_pos(t.minotaur_chest).kind, Kind.CHEST)


func test_two_chests_hold_medikits_and_three_hold_treasure() -> void:
	var b := _generate(5)
	var medikits := 0
	var treasure := 0
	for t in b.all_of(Kind.CHEST):
		if t.contains == Kind.MEDIKIT:
			medikits += 1
		elif t.contains == Kind.TREASURE and t.contains_xp == 5:
			treasure += 1
	assert_eq(medikits, 2)
	assert_eq(treasure, 3)


func test_incremental_delta_matches_full_happiness() -> void:
	var b := _generate(11)
	var g := Generator.new()
	g.board = b
	g.rng = Rng.new(99)
	g._index_kinds()
	var rng := Rng.new(5)
	for _i in 200:
		var a := b.tiles[rng.randi_range(0, b.tiles.size() - 1)]
		var c := b.tiles[rng.randi_range(0, b.tiles.size() - 1)]
		if a == c:
			continue
		var before := Generator.happiness(b)
		var delta := g._swap_delta(a, c)
		b.swap(a, c)
		var after := Generator.happiness(b)
		b.swap(a, c)
		assert_eq(delta, after - before, "swap %s<->%s (%d, %d)" % [a.pos, c.pos, a.kind, c.kind])


func test_generation_is_fast_enough() -> void:
	var start := Time.get_ticks_msec()
	_generate(123)
	var ms := Time.get_ticks_msec() - start
	gut.p("generation took %d ms" % ms)
	assert_lt(ms, 1500)
