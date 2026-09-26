class_name Fixture
## Helpers to build hand-made boards for rule tests.


static func empty_game(seed_value := 1) -> Game:
	var g := Game.new(seed_value)
	g.status = Game.Status.PLAYING
	return g


static func place(g: Game, x: int, y: int, kind: int, revealed := false, treasure_xp := 0) -> Tile:
	var t := g.board.at(x, y)
	t.become(kind, treasure_xp)
	t.revealed = revealed
	return t


static func reveal_all(g: Game) -> void:
	for t in g.board.tiles:
		t.revealed = true


static func find(events: Array[GameEvent], type: GameEvent.Type) -> GameEvent:
	for e in events:
		if e.type == type:
			return e
	return null


static func count(events: Array[GameEvent], type: GameEvent.Type) -> int:
	var n := 0
	for e in events:
		if e.type == type:
			n += 1
	return n
