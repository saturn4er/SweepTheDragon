extends GutTest

var b: Board


func before_each() -> void:
	b = Board.new()


func test_has_130_tiles_in_row_major_order() -> void:
	assert_eq(b.tiles.size(), 130)
	assert_eq(b.at(3, 2).pos, Vector2i(3, 2))
	assert_eq(b.tiles[2 * Board.W + 3], b.at(3, 2))


func test_neighbors8_respects_bounds() -> void:
	assert_eq(b.neighbors8(Vector2i(5, 5)).size(), 8)
	assert_eq(b.neighbors8(Vector2i(0, 0)).size(), 3)
	assert_eq(b.neighbors8(Vector2i(12, 0)).size(), 3)
	assert_eq(b.neighbors8(Vector2i(0, 4)).size(), 5)


func test_neighbors4_is_orthogonal_only() -> void:
	var n := b.neighbors4(Vector2i(5, 5))
	assert_eq(n.size(), 4)
	for t in n:
		assert_eq(Board.dist(t.pos, Vector2i(5, 5)), 1.0)


func test_orb_radius_is_a_plus_shaped_5x5() -> void:
	var area := b.within(Vector2i(6, 4), 2.1)
	assert_eq(area.size(), 12, "8 neighbours plus 4 tiles two steps away orthogonally")
	assert_true(area.has(b.at(8, 4)))
	assert_false(area.has(b.at(8, 5)))


func test_within_inclusive_two_matches_gazer_range() -> void:
	assert_eq(b.within_inclusive(Vector2i(6, 4), 2.0).size(), 12)
	assert_eq(b.within(Vector2i(6, 4), 2.0).size(), 8)


func test_attack_number_sums_levels_including_defeated_uncollected() -> void:
	b.at(5, 5).become(Kind.RAT)
	b.at(6, 6).become(Kind.SLIME)
	b.at(6, 6).defeated = true
	b.at(7, 6).become(Kind.MINE)
	assert_eq(b.attack_number(Vector2i(6, 5)), 1 + 5 + 100)
	assert_eq(b.attack_number(Vector2i(0, 0)), 0)


func test_gazer_masks_within_two() -> void:
	b.at(6, 4).become(Kind.GAZER)
	assert_true(b.gazer_near(Vector2i(8, 4)))
	assert_false(b.gazer_near(Vector2i(8, 5)))
	b.at(6, 4).defeated = true
	assert_false(b.gazer_near(Vector2i(8, 4)))


func test_edge_helpers() -> void:
	assert_true(b.is_edge(Vector2i(0, 5)))
	assert_true(b.is_corner(Vector2i(12, 9)))
	assert_false(b.is_corner(Vector2i(0, 5)))
	assert_true(b.is_close_to_edge(Vector2i(1, 5)))
	assert_true(b.is_close_to_edge(Vector2i(11, 5)))
	assert_false(b.is_close_to_edge(Vector2i(2, 2)))


func test_swap_moves_tiles_and_updates_positions() -> void:
	var a := b.at(1, 1)
	var c := b.at(4, 4)
	a.become(Kind.RAT)
	b.swap(a, c)
	assert_eq(a.pos, Vector2i(4, 4))
	assert_eq(b.at(4, 4), a)
	assert_eq(b.at(1, 1), c)
	assert_eq(b.at(4, 4).kind, Kind.RAT)


func test_become_resets_state_but_keeps_pos_and_fixed() -> void:
	var t := b.at(2, 2)
	t.fixed = true
	t.revealed = true
	t.mark = 5
	t.become(Kind.CHEST)
	assert_eq(t.pos, Vector2i(2, 2))
	assert_true(t.fixed)
	assert_false(t.revealed)
	assert_eq(t.mark, 0)
	assert_eq(t.contains, Kind.TREASURE)
	assert_eq(t.contains_xp, 5)
	t.become(Kind.WALL)
	assert_eq(t.contains_xp, 1)
	t.become(Kind.MIMIC)
	assert_true(t.mimicking)
	assert_eq(t.level, 11)
	t.become(Kind.GNOME)
	assert_eq(t.level, 0)
	assert_eq(t.xp, 9)
	assert_true(t.is_monster)
