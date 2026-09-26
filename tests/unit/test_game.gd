extends GutTest

var g: Game


func before_each() -> void:
	g = Fixture.empty_game()


func test_pressing_hidden_empty_only_reveals_it() -> void:
	var ev := g.press(Vector2i(2, 2))
	assert_true(g.board.at(2, 2).revealed)
	assert_eq(Fixture.count(ev, GameEvent.Type.REVEALED), 1)
	assert_true(Fixture.find(ev, GameEvent.Type.REVEALED).flag, "revealed by click")
	assert_eq(g.player.hp, 6)
	assert_false(g.board.at(2, 3).revealed, "no flood fill")


func test_hidden_monster_attacks_when_pressed_then_collects() -> void:
	Fixture.place(g, 1, 1, Kind.SKELETON)
	var ev := g.press(Vector2i(1, 1))
	var t := g.board.at(1, 1)
	assert_true(t.revealed)
	assert_true(t.defeated)
	assert_eq(g.player.hp, 3)
	var hit := Fixture.find(ev, GameEvent.Type.ATTACKED)
	assert_eq(hit.amount, 3)
	assert_true(hit.flag)
	assert_eq(g.board.attack_number(Vector2i(2, 2)), 3, "defeated monster still counts")
	ev = g.press(Vector2i(1, 1))
	assert_eq(g.player.xp, 3)
	assert_true(t.is_empty())
	assert_true(t.revealed)
	assert_not_null(Fixture.find(ev, GameEvent.Type.COLLECTED))
	assert_eq(g.board.attack_number(Vector2i(2, 2)), 0)


func test_lethal_monster_kills_and_unmasks_mimics() -> void:
	Fixture.place(g, 1, 1, Kind.GUARD)
	Fixture.place(g, 5, 5, Kind.MIMIC, true)
	var ev := g.press(Vector2i(1, 1))
	assert_eq(g.player.hp, 0)
	assert_eq(g.status, Game.Status.DEAD)
	assert_false(g.board.at(1, 1).defeated)
	assert_false(g.board.at(5, 5).mimicking)
	assert_eq(Fixture.find(ev, GameEvent.Type.DIED).kind, Kind.GUARD)
	assert_eq(g.death_message(), "killed by a guardian")
	assert_eq(g.press(Vector2i(2, 2)).size(), 0, "dead games ignore presses")


func test_mine_is_instant_death() -> void:
	Fixture.place(g, 1, 1, Kind.MINE)
	var ev := g.press(Vector2i(1, 1))
	assert_eq(g.status, Game.Status.DEAD)
	assert_not_null(Fixture.find(ev, GameEvent.Type.MINE_EXPLODED))
	assert_eq(g.death_message(), "exploded by a mine")


func test_giant_death_message_uses_role() -> void:
	Fixture.place(g, 1, 1, Kind.GIANT).role = "romeo"
	g.press(Vector2i(1, 1))
	assert_eq(g.death_message(), "mauled by romeo")


func test_mimic_reveals_as_chest_then_bites() -> void:
	Fixture.place(g, 1, 1, Kind.MIMIC)
	g.player.max_hp = 19
	g.player.hp = 19
	g.press(Vector2i(1, 1))
	var t := g.board.at(1, 1)
	assert_true(t.revealed)
	assert_true(t.mimicking)
	assert_eq(g.player.hp, 19, "first press is harmless")
	g.press(Vector2i(1, 1))
	assert_false(t.mimicking)
	assert_true(t.defeated)
	assert_eq(g.player.hp, 8)
	g.press(Vector2i(1, 1))
	assert_eq(g.player.xp, 11)


func test_gnome_dodges_to_hidden_tile_nearest_a_medikit() -> void:
	Fixture.place(g, 1, 1, Kind.GNOME)
	Fixture.place(g, 10, 8, Kind.MEDIKIT)
	Fixture.reveal_all(g)
	g.board.at(1, 1).revealed = false
	g.board.at(9, 8).revealed = false
	g.board.at(9, 8).mark = 7
	g.board.at(0, 0).revealed = false
	var ev := g.press(Vector2i(1, 1))
	var jump := Fixture.find(ev, GameEvent.Type.GNOME_JUMPED)
	assert_not_null(jump)
	assert_eq(jump.target, Vector2i(9, 8))
	assert_eq(g.board.at(9, 8).kind, Kind.GNOME)
	assert_eq(g.board.at(9, 8).mark, 7, "target keeps its mark")
	assert_false(g.board.at(9, 8).revealed)
	assert_true(g.board.at(1, 1).is_empty())
	assert_true(g.board.at(1, 1).revealed)
	assert_eq(g.player.hp, 6)


func test_cornered_gnome_is_caught_for_free_and_worth_nine() -> void:
	Fixture.place(g, 1, 1, Kind.GNOME)
	Fixture.reveal_all(g)
	g.board.at(1, 1).revealed = false
	var ev := g.press(Vector2i(1, 1))
	assert_null(Fixture.find(ev, GameEvent.Type.GNOME_JUMPED))
	var t := g.board.at(1, 1)
	assert_true(t.defeated)
	assert_eq(g.player.hp, 6)
	g.press(Vector2i(1, 1))
	assert_eq(g.player.xp, 9)


func test_wall_takes_three_hits_and_costs_a_heart_each() -> void:
	Fixture.place(g, 1, 1, Kind.WALL, true)
	var t := g.board.at(1, 1)
	t.wall_hp = 3
	t.wall_max_hp = 3
	var ev := g.press(Vector2i(1, 1))
	assert_eq(Fixture.find(ev, GameEvent.Type.WALL_HIT).amount, 2)
	assert_eq(g.player.hp, 5)
	g.press(Vector2i(1, 1))
	ev = g.press(Vector2i(1, 1))
	assert_not_null(Fixture.find(ev, GameEvent.Type.WALL_DOWN))
	assert_eq(g.player.hp, 3)
	assert_eq(t.kind, Kind.TREASURE)
	assert_eq(t.xp, 1)
	assert_true(t.revealed)
	g.press(Vector2i(1, 1))
	assert_eq(g.player.xp, 1)
	assert_true(t.is_empty())


func test_wall_refuses_a_hit_that_would_kill() -> void:
	Fixture.place(g, 1, 1, Kind.WALL, true)
	g.board.at(1, 1).wall_hp = 3
	g.player.hp = 1
	var ev := g.press(Vector2i(1, 1))
	assert_not_null(Fixture.find(ev, GameEvent.Type.REFUSED))
	assert_eq(g.player.hp, 1)
	assert_eq(g.board.at(1, 1).wall_hp, 3)


func test_hidden_wall_is_first_revealed_without_damage() -> void:
	Fixture.place(g, 1, 1, Kind.WALL)
	g.press(Vector2i(1, 1))
	assert_eq(g.player.hp, 6)
	assert_true(g.board.at(1, 1).revealed)


func test_chest_opens_into_treasure_or_medikit() -> void:
	Fixture.place(g, 1, 1, Kind.CHEST, true)
	var ev := g.press(Vector2i(1, 1))
	assert_not_null(Fixture.find(ev, GameEvent.Type.CHEST_OPENED))
	assert_eq(g.board.at(1, 1).kind, Kind.TREASURE)
	assert_eq(g.board.at(1, 1).xp, 5)
	assert_true(g.board.at(1, 1).revealed)
	var c := Fixture.place(g, 2, 2, Kind.CHEST, true)
	c.contains = Kind.MEDIKIT
	g.press(Vector2i(2, 2))
	assert_eq(g.board.at(2, 2).kind, Kind.MEDIKIT)


func test_medikit_heals_to_full_or_is_refused() -> void:
	Fixture.place(g, 1, 1, Kind.MEDIKIT, true)
	Fixture.place(g, 2, 2, Kind.MEDIKIT, true)
	var ev := g.press(Vector2i(1, 1))
	assert_not_null(Fixture.find(ev, GameEvent.Type.REFUSED))
	assert_true(g.board.at(1, 1).is_empty(), "wasted medikit is still consumed")
	g.player.hp = 2
	ev = g.press(Vector2i(2, 2))
	assert_not_null(Fixture.find(ev, GameEvent.Type.HEALED))
	assert_eq(g.player.hp, g.player.max_hp)


func test_orb_reveals_plus_shaped_area() -> void:
	Fixture.place(g, 6, 4, Kind.ORB, true)
	Fixture.place(g, 8, 4, Kind.RAT)
	var ev := g.press(Vector2i(6, 4))
	assert_eq(Fixture.count(ev, GameEvent.Type.REVEALED), 12)
	assert_true(g.board.at(8, 4).revealed)
	assert_false(g.board.at(8, 4).defeated, "orb does not fight")
	assert_false(g.board.at(8, 5).revealed)
	assert_true(g.board.at(6, 4).is_empty())
	assert_true(Fixture.find(ev, GameEvent.Type.ORB_USED).flag)
	assert_eq(g.player.hp, 6)


func test_disarm_scroll_neutralises_all_mines() -> void:
	Fixture.place(g, 1, 1, Kind.SPELL_DISARM, true)
	Fixture.place(g, 5, 5, Kind.MINE)
	Fixture.place(g, 7, 7, Kind.MINE, true)
	Fixture.place(g, 6, 6, Kind.EMPTY, true)
	var ev := g.press(Vector2i(1, 1))
	assert_true(g.mines_disarmed)
	assert_eq(Fixture.find(ev, GameEvent.Type.MINES_DISARMED).amount, 2)
	assert_eq(Fixture.count(ev, GameEvent.Type.MINE_DISARMED_AT), 1)
	for m in g.board.all_of(Kind.MINE):
		assert_true(m.defeated)
		assert_eq(m.level, 0)
	assert_eq(g.board.attack_number(Vector2i(6, 6)), 0)
	assert_true(Fixture.count(ev, GameEvent.Type.NUMBER_CHANGED) >= 1)
	g.press(Vector2i(5, 5))
	assert_eq(g.player.hp, 6, "disarmed mine is harmless")
	g.press(Vector2i(5, 5))
	assert_eq(g.player.xp, 3)
	assert_eq(g.book_level(Kind.MINE), 0)


func test_reveal_scrolls_show_their_monsters() -> void:
	Fixture.place(g, 1, 1, Kind.SPELL_REVEAL_RATS, true)
	Fixture.place(g, 2, 2, Kind.SPELL_REVEAL_SLIMES, true)
	Fixture.place(g, 5, 5, Kind.RAT)
	Fixture.place(g, 6, 6, Kind.SLIME)
	Fixture.place(g, 7, 7, Kind.BIG_SLIME)
	var ev := g.press(Vector2i(1, 1))
	assert_true(g.board.at(5, 5).revealed)
	assert_false(g.board.at(6, 6).revealed)
	assert_true(Fixture.find(ev, GameEvent.Type.SPELL_CAST).flag)
	assert_true(g.board.at(1, 1).is_empty())
	g.press(Vector2i(2, 2))
	assert_true(g.board.at(6, 6).revealed)
	assert_true(g.board.at(7, 7).revealed)
	assert_eq(g.player.hp, 6)


func test_reveal_scroll_with_nothing_to_show_reports_no_effect() -> void:
	Fixture.place(g, 1, 1, Kind.SPELL_REVEAL_RATS, true)
	var ev := g.press(Vector2i(1, 1))
	assert_false(Fixture.find(ev, GameEvent.Type.SPELL_CAST).flag)


func test_orb_scroll_reveals_3x3_touching_a_hidden_mine() -> void:
	Fixture.place(g, 1, 1, Kind.SPELL_ORB, true)
	Fixture.place(g, 8, 6, Kind.MINE)
	var ev := g.press(Vector2i(1, 1))
	assert_true(Fixture.find(ev, GameEvent.Type.SPELL_CAST).flag)
	var revealed_near_mine := false
	for t in g.board.within_inclusive(Vector2i(8, 6), 2.0):
		if t.revealed and Board.dist(t.pos, Vector2i(8, 6)) <= 1.5:
			revealed_near_mine = true
	assert_true(revealed_near_mine, "picked tile is adjacent to the mine")
	assert_eq(Fixture.count(ev, GameEvent.Type.REVEALED), 9)
	assert_true(g.board.at(1, 1).is_empty())


func test_collecting_kings_drops_scrolls_and_dragon_drops_crown() -> void:
	var drops := {
		Kind.RAT_KING: Kind.SPELL_REVEAL_RATS,
		Kind.WIZARD: Kind.SPELL_REVEAL_SLIMES,
		Kind.MINE_KING: Kind.SPELL_DISARM,
		Kind.GIANT: Kind.MEDIKIT,
		Kind.DRAGON: Kind.CROWN,
	}
	var x := 0
	for kind in drops:
		g.player.max_hp = 19
		g.player.hp = 19
		Fixture.place(g, x, 0, kind, true)
		g.press(Vector2i(x, 0))
		g.press(Vector2i(x, 0))
		assert_eq(g.board.at(x, 0).kind, drops[kind], Catalog.display_name(kind))
		assert_true(g.board.at(x, 0).revealed)
		x += 1


func test_taking_the_crown_wins_with_stamps() -> void:
	Fixture.place(g, 6, 4, Kind.CROWN, true)
	var ev := g.press(Vector2i(6, 4))
	assert_eq(g.status, Game.Status.WON)
	assert_not_null(Fixture.find(ev, GameEvent.Type.WON))
	assert_has(g.stamps_this_run, Stamps.CLEAR)
	assert_has(g.stamps_this_run, Stamps.PACIFIST)
	assert_does_not_have(g.stamps_this_run, Stamps.LOVERS)
	assert_does_not_have(g.stamps_this_run, Stamps.EGG)


func test_stamps_reflect_survivors_and_rat_kills() -> void:
	Fixture.place(g, 6, 4, Kind.CROWN, true)
	Fixture.place(g, 0, 0, Kind.GIANT).role = "romeo"
	Fixture.place(g, 12, 0, Kind.GIANT).role = "juliet"
	Fixture.place(g, 6, 3, Kind.DRAGON_EGG)
	Fixture.place(g, 1, 1, Kind.RAT)
	g.press(Vector2i(1, 1))
	g.press(Vector2i(1, 1))
	g.press(Vector2i(6, 4))
	assert_has(g.stamps_this_run, Stamps.LOVERS)
	assert_has(g.stamps_this_run, Stamps.EGG)
	assert_does_not_have(g.stamps_this_run, Stamps.PACIFIST)
	assert_does_not_have(g.stamps_this_run, Stamps.CLEAR)


func test_level_up_flow_and_hero_button() -> void:
	Fixture.place(g, 1, 1, Kind.GARGOYLE, true)
	var ev := g.press(Vector2i(1, 1))
	assert_eq(g.player.hp, 2)
	assert_null(Fixture.find(ev, GameEvent.Type.CAN_LEVEL_UP))
	ev = g.press(Vector2i(1, 1))
	assert_eq(g.player.xp, 4)
	assert_not_null(Fixture.find(ev, GameEvent.Type.CAN_LEVEL_UP))
	assert_true(g.can_level_up())
	ev = g.hero_pressed()
	var lvl := Fixture.find(ev, GameEvent.Type.LEVEL_UP)
	assert_not_null(lvl)
	assert_eq(lvl.amount, 2)
	assert_false(lvl.flag, "level 2 is a half heart")
	assert_eq(g.player.hp, 6)
	assert_eq(g.player.xp, 0)
	ev = g.hero_pressed()
	assert_not_null(Fixture.find(ev, GameEvent.Type.HERO_TAPPED))


func test_alarm_when_dropping_to_one_heart_without_level_available() -> void:
	Fixture.place(g, 1, 1, Kind.SLIME, true)
	var ev := g.press(Vector2i(1, 1))
	assert_eq(g.player.hp, 1)
	assert_not_null(Fixture.find(ev, GameEvent.Type.ALARM))


func test_no_alarm_when_a_level_up_is_ready() -> void:
	g.player.grant_xp(4)
	Fixture.place(g, 1, 1, Kind.SLIME, true)
	var ev := g.press(Vector2i(1, 1))
	assert_null(Fixture.find(ev, GameEvent.Type.ALARM))


func test_marks_toggle_and_ignore_revealed_tiles() -> void:
	g.set_mark(Vector2i(1, 1), 5)
	assert_eq(g.board.at(1, 1).mark, 5)
	g.set_mark(Vector2i(1, 1), 5)
	assert_eq(g.board.at(1, 1).mark, 0, "same mark again clears it")
	g.set_mark(Vector2i(1, 1), 13)
	g.set_mark(Vector2i(1, 1), 0)
	assert_eq(g.board.at(1, 1).mark, 0)
	Fixture.place(g, 2, 2, Kind.EMPTY, true)
	assert_eq(g.set_mark(Vector2i(2, 2), 3).size(), 0)
	assert_eq(g.board.at(2, 2).mark, 0)


func test_gazer_death_reports_number_changes_around_it() -> void:
	Fixture.place(g, 6, 4, Kind.GAZER, true)
	Fixture.place(g, 8, 4, Kind.EMPTY, true)
	Fixture.place(g, 7, 4, Kind.EMPTY, true)
	g.player.max_hp = 10
	g.player.hp = 10
	var ev := g.press(Vector2i(6, 4))
	assert_eq(Fixture.count(ev, GameEvent.Type.NUMBER_CHANGED), 2)


func test_book_counts_include_carriers() -> void:
	Fixture.place(g, 0, 0, Kind.MEDIKIT)
	Fixture.place(g, 1, 0, Kind.GIANT)
	var c := Fixture.place(g, 2, 0, Kind.CHEST)
	c.contains = Kind.MEDIKIT
	Fixture.place(g, 3, 0, Kind.CHEST)
	Fixture.place(g, 4, 0, Kind.MINE_KING)
	Fixture.place(g, 5, 0, Kind.MIMIC)
	assert_eq(g.book_count(Kind.MEDIKIT), 3)
	assert_eq(g.book_count(Kind.CHEST), 2)
	assert_eq(g.book_count(Kind.SPELL_DISARM), 1)
	assert_eq(g.book_count(Kind.MIMIC), 1)
	assert_eq(g.book_count(Kind.RAT), 0)


func test_full_generated_game_can_be_played_deterministically() -> void:
	var a := Game.new(2024)
	a.generate()
	var b := Game.new(2024)
	b.generate()
	assert_eq(a.status, Game.Status.PLAYING)
	assert_eq(a.board.at_pos(Board.CENTER).kind, Kind.DRAGON)
	assert_true(a.board.at_pos(Board.CENTER).revealed)
	assert_eq(a.wall_locations.size(), 6)
	assert_eq(a.chest_locations.size(), 5)
	var orb := a.board.first_of(Kind.ORB)
	a.press(orb.pos)
	b.press(b.board.first_of(Kind.ORB).pos)
	for i in a.board.tiles.size():
		assert_eq(a.board.tiles[i].revealed, b.board.tiles[i].revealed)
