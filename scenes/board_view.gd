class_name BoardView
extends Node2D
## The 13x10 grid of TileViews plus pointer handling: click to press, right-click, shift-click or
## a long press to open the mark menu. In portrait the grid is drawn transposed (10 wide, 13 tall).

signal tile_pressed(pos: Vector2i)
signal mark_requested(pos: Vector2i)

const LONG_PRESS := 0.33
const ANIM_PERIOD := 0.45

var tiles: Array[TileView] = []
var fx: FxLayer
var menu: MarkMenu
var input_enabled := true
var portrait := false

var _pressed_pos := Vector2i(-1, -1)
var _press_time := 0.0
var _holding := false
var _ring: Sprite2D
var _frame := 0
var _anim_clock := 0.0
var _ctx := {}
var _board: Board


func _ready() -> void:
	var bag: Array[int] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in Board.H:
		for x in Board.W:
			if bag.is_empty():
				bag.assign(range(16))
				for i in range(bag.size() - 1, 0, -1):
					var j := rng.randi_range(0, i)
					var tmp := bag[i]
					bag[i] = bag[j]
					bag[j] = tmp
			var tv := TileView.new()
			tv.variant = bag.pop_back()
			add_child(tv)
			tiles.append(tv)
	fx = FxLayer.new()
	fx.origin = tile_origin
	add_child(fx)
	_ring = UiKit.sprite(SpriteDb.ui("ring_0"), Vector2.ZERO)
	_ring.visible = false
	add_child(_ring)
	menu = MarkMenu.new()
	add_child(menu)
	_place_tiles()


func set_portrait(p: bool) -> void:
	if portrait == p:
		return
	portrait = p
	_place_tiles()
	menu.visible = false
	cancel_press()


func _place_tiles() -> void:
	for y in Board.H:
		for x in Board.W:
			tiles[y * Board.W + x].position = tile_origin(Vector2i(x, y))


## Top-left corner of a board cell on screen.
func tile_origin(p: Vector2i) -> Vector2:
	var d := Vector2(p.y, p.x) if portrait else Vector2(p)
	return d * TileView.SIZE


func tile_rect(p: Vector2i) -> Rect2:
	return Rect2(tile_origin(p), Vector2(TileView.SIZE, TileView.SIZE))


func bounds() -> Rect2:
	var cells := Vector2(Board.H, Board.W) if portrait else Vector2(Board.W, Board.H)
	return Rect2(Vector2.ZERO, cells * TileView.SIZE)


func tile_at(local: Vector2) -> Vector2i:
	var c := Vector2i(floori(local.x / TileView.SIZE), floori(local.y / TileView.SIZE))
	var p := Vector2i(c.y, c.x) if portrait else c
	if p.x < 0 or p.y < 0 or p.x >= Board.W or p.y >= Board.H:
		return Vector2i(-1, -1)
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	return p


func render(game: Game, xray := false) -> void:
	_board = game.board
	_ctx = {
		"board": game.board,
		"show_all": game.status == Game.Status.DEAD or xray,
		"xray": xray,
		"portrait": portrait,
		"killer": game.last_pressed if game.status == Game.Status.DEAD else null,
		"walls": game.wall_locations,
		"chests": game.chest_locations,
		"frame": _frame,
		"rat_king": game.board.first_of(Kind.RAT_KING),
	}
	for i in tiles.size():
		tiles[i].render(game.board.tiles[i], _ctx)


func _process(delta: float) -> void:
	_anim_clock += delta
	if _anim_clock >= ANIM_PERIOD:
		_anim_clock -= ANIM_PERIOD
		_frame = 1 - _frame
		if _board != null:
			_ctx["frame"] = _frame
			for i in tiles.size():
				var t := _board.tiles[i]
				if (t.revealed or _ctx.show_all) and (t.is_monster or t.kind == Kind.CROWN):
					tiles[i].render(t, _ctx)
	if _holding:
		_press_time += delta
		var k := clampf(_press_time / LONG_PRESS, 0.0, 1.0)
		_ring.visible = _press_time > 0.1
		_ring.texture = SpriteDb.ui("ring_1" if int(k * 4) % 2 == 1 else "ring_0")
		if _press_time >= LONG_PRESS:
			_holding = false
			_ring.visible = false
			if _board != null and not _board.at_pos(_pressed_pos).revealed:
				mark_requested.emit(_pressed_pos)
			_pressed_pos = Vector2i(-1, -1)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion:
		menu.hover(to_local(event.position))
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	var local := to_local(mb.position)
	if menu.is_open():
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			menu.click(local)
			get_viewport().set_input_as_handled()
		return
	var p := tile_at(local)
	var wants_mark := mb.button_index == MOUSE_BUTTON_RIGHT or (mb.button_index == MOUSE_BUTTON_LEFT and mb.shift_pressed)
	if mb.pressed:
		if p.x < 0:
			return
		if wants_mark:
			if _board != null and not _board.at_pos(p).revealed:
				mark_requested.emit(p)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_pressed_pos = p
			_press_time = 0.0
			_holding = true
			_ring.position = tile_origin(p) + TileView.CENTER
			get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_LEFT and _holding:
		_holding = false
		_ring.visible = false
		if p == _pressed_pos and p.x >= 0:
			tile_pressed.emit(p)
		_pressed_pos = Vector2i(-1, -1)
		get_viewport().set_input_as_handled()


func cancel_press() -> void:
	_holding = false
	_ring.visible = false
	_pressed_pos = Vector2i(-1, -1)
