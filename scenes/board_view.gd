class_name BoardView
extends Node2D
## The 13x10 grid of TileViews plus pointer handling: click to press, right-click, shift-click or
## a long press to open the mark menu.

signal tile_pressed(pos: Vector2i)
signal mark_requested(pos: Vector2i)
signal hero_shortcut

const LONG_PRESS := 0.33
const ANIM_PERIOD := 0.45

var tiles: Array[TileView] = []
var fx: FxLayer
var menu: MarkMenu
var input_enabled := true

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
			tv.position = Vector2(x, y) * TileView.SIZE
			tv.variant = bag.pop_back()
			add_child(tv)
			tiles.append(tv)
	fx = FxLayer.new()
	add_child(fx)
	_ring = UiKit.sprite(SpriteDb.ui("ring_0"), Vector2.ZERO)
	_ring.visible = false
	add_child(_ring)
	menu = MarkMenu.new()
	add_child(menu)


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(Board.W, Board.H) * TileView.SIZE)


func render(game: Game) -> void:
	_board = game.board
	_ctx = {
		"board": game.board,
		"show_all": game.status == Game.Status.DEAD,
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


func tile_at(local: Vector2) -> Vector2i:
	var p := Vector2i(floori(local.x / TileView.SIZE), floori(local.y / TileView.SIZE))
	if p.x < 0 or p.y < 0 or p.x >= Board.W or p.y >= Board.H:
		return Vector2i(-1, -1)
	return p


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
			_ring.position = Vector2(p) * TileView.SIZE + TileView.CENTER
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
