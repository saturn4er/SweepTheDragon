extends GutTest


func test_xp_table_clamps_at_last_entry() -> void:
	assert_eq(Player.xp_to_next(1), 4)
	assert_eq(Player.xp_to_next(5), 9)
	assert_eq(Player.xp_to_next(14), 25)
	assert_eq(Player.xp_to_next(40), 25)


func test_starts_with_six_hearts_and_no_xp() -> void:
	var p := Player.new()
	assert_eq(p.max_hp, 6)
	assert_eq(p.hp, 6)
	assert_eq(p.level, 1)
	assert_false(p.can_level_up())


func test_level_up_refills_and_alternates_half_and_full_hearts() -> void:
	var p := Player.new()
	p.hp = 2
	p.grant_xp(4)
	assert_true(p.can_level_up())
	assert_false(p.level_up(), "level 2 is a half heart")
	assert_eq(p.level, 2)
	assert_eq(p.max_hp, 6)
	assert_eq(p.hp, 6)
	assert_eq(p.xp, 0)
	p.grant_xp(5)
	assert_true(p.level_up(), "level 3 adds a heart")
	assert_eq(p.max_hp, 7)
	assert_eq(p.hp, 7)


func test_hearts_cap_at_nineteen() -> void:
	var p := Player.new()
	for _i in 60:
		p.grant_xp(Player.xp_to_next(p.level))
		p.level_up()
	assert_eq(p.max_hp, Player.MAX_HP)
	assert_eq(p.hp, Player.MAX_HP)


func test_score_tracks_all_xp_ever_gained() -> void:
	var p := Player.new()
	p.grant_xp(4)
	p.level_up()
	p.grant_xp(3)
	assert_eq(p.xp, 3)
	assert_eq(p.score, 7)


func test_cannot_level_when_dead() -> void:
	var p := Player.new()
	p.grant_xp(10)
	p.hp = 0
	assert_false(p.can_level_up())
