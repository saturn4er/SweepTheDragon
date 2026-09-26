extends GutTest


func test_empty_board_earns_clear_and_pacifist() -> void:
	var b := Board.new()
	var s := Stamps.earned(b, 0)
	assert_has(s, Stamps.CLEAR)
	assert_has(s, Stamps.PACIFIST)
	assert_eq(s.size(), 2)


func test_crown_and_dragon_do_not_block_clear() -> void:
	var b := Board.new()
	b.at(6, 4).become(Kind.CROWN)
	b.at(0, 0).become(Kind.DRAGON)
	assert_has(Stamps.earned(b, 3), Stamps.CLEAR)
	assert_does_not_have(Stamps.earned(b, 3), Stamps.PACIFIST)


func test_leftover_item_blocks_clear() -> void:
	var b := Board.new()
	b.at(0, 0).become(Kind.MEDIKIT)
	assert_does_not_have(Stamps.earned(b, 0), Stamps.CLEAR)


func test_lovers_needs_both_giants_undefeated() -> void:
	var b := Board.new()
	b.at(0, 0).become(Kind.GIANT)
	b.at(1, 0).become(Kind.GIANT)
	assert_has(Stamps.earned(b, 0), Stamps.LOVERS)
	b.at(1, 0).defeated = true
	assert_does_not_have(Stamps.earned(b, 0), Stamps.LOVERS)
