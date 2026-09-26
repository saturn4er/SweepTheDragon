class_name Game
extends RefCounted
## One run of the dungeon. Owns the board and the player and resolves every press into events.

enum Status { GENERATING, PLAYING, DEAD, WON }

const ORB_RADIUS := 2.1

var board: Board
var player: Player
var rng: Rng
var seed_value := 0
var status := Status.GENERATING
var mines_disarmed := false
var dragon_defeated := false
var killed_rats := 0
var last_pressed: Tile = null
var stamps_this_run: Array[String] = []
var wall_locations: Array[Vector2i] = []
var chest_locations: Array[Vector2i] = []
var start_msec := 0
var end_msec := 0


func _init(new_seed: int = 0) -> void:
	seed_value = new_seed if new_seed != 0 else randi()
	rng = Rng.new(seed_value)
	board = Board.new()
	player = Player.new()


## Fills the board. Kept separate from _init so the caller can draw a frame first.
func generate() -> void:
	Generator.generate(board, rng)
	for t in board.tiles:
		if t.kind == Kind.WALL:
			wall_locations.append(t.pos)
		elif t.kind == Kind.CHEST:
			chest_locations.append(t.pos)
	status = Status.PLAYING
	start_msec = Time.get_ticks_msec()


func is_playing() -> bool:
	return status == Status.PLAYING


func elapsed_msec() -> int:
	var end := end_msec if end_msec > 0 else Time.get_ticks_msec()
	return end - start_msec


func press(p: Vector2i) -> Array[GameEvent]:
	var ev: Array[GameEvent] = []
	if status != Status.PLAYING:
		return ev
	var t := board.at_pos(p)
	var old_hp := player.hp
	var old_xp := player.xp

	if t.kind == Kind.GNOME:
		_gnome_dodges(t, ev)

	match t.kind:
		Kind.CROWN:
			_win(ev)
		Kind.SPELL_REVEAL_SLIMES:
			if t.revealed:
				_cast_reveal(t, [Kind.SLIME, Kind.BIG_SLIME], ev)
		Kind.SPELL_REVEAL_RATS:
			if t.revealed:
				_cast_reveal(t, [Kind.RAT], ev)
		Kind.SPELL_DISARM:
			if t.revealed:
				_cast_disarm(t, ev)
		Kind.SPELL_ORB:
			if t.revealed:
				_cast_orb_scroll(t, ev)
		Kind.TREASURE:
			if t.revealed:
				_collect(t, ev)
		Kind.WALL:
			if t.revealed:
				_hit_wall(t, ev)
		Kind.CHEST:
			if t.revealed:
				_open_chest(t, ev)
		Kind.ORB:
			if t.revealed:
				_use_orb(t, ev)
		Kind.MEDIKIT:
			if t.revealed:
				_use_medikit(t, ev)
		_:
			if t.is_monster:
				_monster_pressed(t, ev)

	if not t.revealed:
		t.revealed = true
		ev.append(GameEvent.make(GameEvent.Type.REVEALED, t.pos).with_flag(true))

	last_pressed = t
	_aftermath(old_hp, old_xp, ev)
	return ev


func set_mark(p: Vector2i, mark: int) -> Array[GameEvent]:
	var ev: Array[GameEvent] = []
	var t := board.at_pos(p)
	if t.revealed:
		return ev
	t.mark = 0 if mark == t.mark else mark
	ev.append(GameEvent.make(GameEvent.Type.MARK_SET, p).with_amount(t.mark))
	return ev


func can_level_up() -> bool:
	return status == Status.PLAYING and player.can_level_up()


func level_up() -> Array[GameEvent]:
	var ev: Array[GameEvent] = []
	if not can_level_up():
		return ev
	var old_hp := player.hp
	var heart_index := player.max_hp
	var full := player.level_up()
	ev.append(GameEvent.make(GameEvent.Type.LEVEL_UP)
		.with_amount(player.level).with_flag(full).with_target(Vector2i(heart_index, 0)))
	ev.append(GameEvent.make(GameEvent.Type.HP_CHANGED)
		.with_amount(old_hp).with_target(Vector2i(player.hp, 0)))
	return ev


## Tapping Jorge levels up when possible, otherwise he just reacts.
func hero_pressed() -> Array[GameEvent]:
	if can_level_up():
		return level_up()
	var ev: Array[GameEvent] = []
	if status == Status.PLAYING:
		ev.append(GameEvent.make(GameEvent.Type.HERO_TAPPED).with_flag(player.hp == 1))
	return ev


func death_message() -> String:
	if last_pressed == null:
		return ""
	if last_pressed.role == "romeo":
		return "mauled by romeo"
	if last_pressed.role == "juliet":
		return "mauled by juliet"
	return Catalog.death_message(last_pressed.kind)


## Count shown in the monsternomicon for a book entry. Scroll rows count their carriers.
func book_count(kind: int) -> int:
	var n := 0
	for t in board.tiles:
		if t.kind == kind:
			n += 1
		elif kind == Kind.MEDIKIT and (t.contains == Kind.MEDIKIT or t.kind == Kind.GIANT):
			n += 1
		elif kind == Kind.SPELL_DISARM and t.kind == Kind.MINE_KING:
			n += 1
		elif kind == Kind.SPELL_REVEAL_RATS and t.kind == Kind.RAT_KING:
			n += 1
		elif kind == Kind.SPELL_REVEAL_SLIMES and t.kind == Kind.WIZARD:
			n += 1
	return n


## Level shown in the book. Disarmed mines report zero.
func book_level(kind: int) -> int:
	if kind == Kind.MINE and mines_disarmed:
		return 0
	return Catalog.level(kind)


func _gnome_dodges(t: Tile, ev: Array[GameEvent]) -> void:
	var target := gnome_jump_target()
	if target == null:
		return
	var keep_mark := target.mark
	target.become(Kind.GNOME)
	target.mark = keep_mark
	t.become(Kind.EMPTY)
	ev.append(GameEvent.make(GameEvent.Type.GNOME_JUMPED, t.pos).with_target(target.pos))


## The hidden empty tile closest to any medikit, or null when there is none.
func gnome_jump_target() -> Tile:
	var best: Tile = null
	var best_d := INF
	var medikits := board.all_of(Kind.MEDIKIT)
	for c in board.tiles:
		if not c.is_empty() or c.revealed:
			continue
		for m in medikits:
			var d := Board.dist(m.pos, c.pos)
			if d < best_d:
				best_d = d
				best = c
	return best


func _monster_pressed(t: Tile, ev: Array[GameEvent]) -> void:
	if t.mimicking and not t.revealed:
		return
	if not t.defeated:
		t.mimicking = false
		player.hp -= t.level
		if player.hp > 0:
			t.defeated = true
		if t.kind == Kind.RAT:
			killed_rats += 1
		ev.append(GameEvent.make(GameEvent.Type.ATTACKED, t.pos)
			.with_kind(t.kind).with_amount(t.level).with_flag(t.defeated))
		match t.kind:
			Kind.DRAGON:
				if t.defeated:
					dragon_defeated = true
					ev.append(GameEvent.make(GameEvent.Type.DRAGON_DEFEATED, t.pos))
			Kind.MINE:
				ev.append(GameEvent.make(GameEvent.Type.MINE_EXPLODED, t.pos))
			Kind.GAZER:
				if t.defeated:
					for n in board.within_inclusive(t.pos, 2.0):
						if n.is_empty() and n.revealed:
							ev.append(GameEvent.make(GameEvent.Type.NUMBER_CHANGED, n.pos))
	elif player.hp > 0 and t.revealed:
		_collect(t, ev)


func _collect(t: Tile, ev: Array[GameEvent]) -> void:
	var gained := t.xp
	var kind := t.kind
	player.grant_xp(gained)
	t.become(Catalog.drop_for(kind))
	t.revealed = true
	ev.append(GameEvent.make(GameEvent.Type.COLLECTED, t.pos).with_kind(kind).with_amount(gained))


func _cast_reveal(t: Tile, kinds: Array, ev: Array[GameEvent]) -> void:
	var found := false
	for a in board.tiles:
		if kinds.has(a.kind):
			found = true
			if not a.revealed:
				a.revealed = true
				ev.append(GameEvent.make(GameEvent.Type.REVEALED, a.pos))
	var kind := t.kind
	_consume(t)
	ev.append(GameEvent.make(GameEvent.Type.SPELL_CAST, t.pos).with_kind(kind).with_flag(found))


func _cast_disarm(t: Tile, ev: Array[GameEvent]) -> void:
	var mines: Array[Tile] = []
	for a in board.all_of(Kind.MINE):
		if not a.defeated:
			mines.append(a)
	for m in mines:
		m.defeated = true
		m.level = 0
		if m.revealed:
			ev.append(GameEvent.make(GameEvent.Type.MINE_DISARMED_AT, m.pos))
		for n in board.neighbors8(m.pos):
			if n.is_empty() and n.revealed:
				ev.append(GameEvent.make(GameEvent.Type.NUMBER_CHANGED, n.pos))
	_consume(t)
	if not mines.is_empty():
		mines_disarmed = true
	ev.append(GameEvent.make(GameEvent.Type.SPELL_CAST, t.pos)
		.with_kind(Kind.SPELL_DISARM).with_flag(not mines.is_empty()))
	ev.append(GameEvent.make(GameEvent.Type.MINES_DISARMED).with_amount(mines.size()))


## Reveals a 3x3 area around a random hidden tile, preferring one that touches a hidden mine.
func _cast_orb_scroll(t: Tile, ev: Array[GameEvent]) -> void:
	var candidates: Array[Tile] = []
	for a in board.tiles:
		if not a.revealed:
			candidates.append(a)
	rng.shuffle(candidates)
	var pick: Tile = null
	for a in candidates:
		for m in board.within(a.pos, 1.5):
			if m.kind == Kind.MINE and not m.revealed:
				pick = a
				break
	if pick == null and not candidates.is_empty():
		pick = candidates[0]
	if pick != null:
		var area: Array[Tile] = [pick]
		area.append_array(board.within(pick.pos, 1.5))
		for b in area:
			if not b.revealed:
				b.revealed = true
				ev.append(GameEvent.make(GameEvent.Type.REVEALED, b.pos))
	_consume(t)
	ev.append(GameEvent.make(GameEvent.Type.SPELL_CAST, t.pos)
		.with_kind(Kind.SPELL_ORB).with_flag(pick != null))


func _hit_wall(t: Tile, ev: Array[GameEvent]) -> void:
	if player.hp == 1:
		ev.append(GameEvent.make(GameEvent.Type.REFUSED, t.pos))
		return
	player.hp -= 1
	t.wall_hp -= 1
	if t.wall_hp == 0:
		var inside := t.contains
		var inside_xp := t.contains_xp
		t.become(inside if inside != Kind.NONE else Kind.EMPTY, inside_xp)
		t.revealed = true
		ev.append(GameEvent.make(GameEvent.Type.WALL_DOWN, t.pos))
	else:
		ev.append(GameEvent.make(GameEvent.Type.WALL_HIT, t.pos).with_amount(t.wall_hp))


func _open_chest(t: Tile, ev: Array[GameEvent]) -> void:
	t.become(t.contains, t.contains_xp)
	t.revealed = true
	ev.append(GameEvent.make(GameEvent.Type.CHEST_OPENED, t.pos))


func _use_orb(t: Tile, ev: Array[GameEvent]) -> void:
	var origin := t.pos
	_consume(t)
	var newly := 0
	for a in board.within(origin, ORB_RADIUS):
		if not a.revealed:
			a.revealed = true
			newly += 1
			ev.append(GameEvent.make(GameEvent.Type.REVEALED, a.pos))
	ev.append(GameEvent.make(GameEvent.Type.ORB_USED, origin).with_flag(newly > 0))


func _use_medikit(t: Tile, ev: Array[GameEvent]) -> void:
	if player.hp < player.max_hp:
		player.hp = player.max_hp
		ev.append(GameEvent.make(GameEvent.Type.HEALED, t.pos))
	else:
		ev.append(GameEvent.make(GameEvent.Type.REFUSED, t.pos))
	_consume(t)


func _consume(t: Tile) -> void:
	t.become(Kind.EMPTY)
	t.revealed = true


func _win(ev: Array[GameEvent]) -> void:
	end_msec = Time.get_ticks_msec()
	status = Status.WON
	stamps_this_run = Stamps.earned(board, killed_rats)
	ev.append(GameEvent.make(GameEvent.Type.WON))


func _aftermath(old_hp: int, old_xp: int, ev: Array[GameEvent]) -> void:
	if player.hp <= 0:
		player.hp = 0
		if old_hp > 0:
			status = Status.DEAD
			for t in board.tiles:
				if t.kind == Kind.MIMIC:
					t.mimicking = false
			ev.append(GameEvent.make(GameEvent.Type.DIED).with_kind(last_pressed.kind))
	elif old_hp > 1 and player.hp == 1 and not player.can_level_up():
		ev.append(GameEvent.make(GameEvent.Type.ALARM))
	if player.hp != old_hp:
		ev.append(GameEvent.make(GameEvent.Type.HP_CHANGED)
			.with_amount(old_hp).with_target(Vector2i(player.hp, 0)))
	if player.xp != old_xp:
		ev.append(GameEvent.make(GameEvent.Type.XP_CHANGED)
			.with_amount(old_xp).with_target(Vector2i(player.xp, 0)))
	if old_xp < player.xp and player.can_level_up():
		ev.append(GameEvent.make(GameEvent.Type.CAN_LEVEL_UP))
