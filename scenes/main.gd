extends Node2D
## Root scene: owns the Game, wires the views and turns events into sound and effects.

const LANDSCAPE := Vector2(390, 340)
const PORTRAIT := Vector2(300, 390 + 74)
const WIDE := Vector2(390 + Hud.SIDE_WIDTH, 300)
## Windows at least this wide relative to their height put the HUD beside the board.
const WIDE_ASPECT := 1.5

var game: Game
var world: Node2D
var board_view: BoardView
var hud: Hud
var book: Monsternomicon
var win: WinScreen
var generating: Label
var _shake_time := 0.0
var _restarting := false
## Debug x-ray: draws every tile as revealed without touching the game state.
var xray := false
var _xray_label: Label
var bg: ColorRect
var portrait := false
## The fixed layout (board plus HUD) and where it sits inside the canvas, which is sized to the
## window's aspect so nothing is letterboxed.
var layout_size := LANDSCAPE
var offset := Vector2.ZERO
var _laid_out_for := Vector2i.ZERO
const UNDO_DEPTH := 300
var _history: Array[Dictionary] = []


func _ready() -> void:
	bg = ColorRect.new()
	bg.color = UiKit.COL_BG
	bg.size = LANDSCAPE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	world = Node2D.new()
	add_child(world)
	board_view = BoardView.new()
	world.add_child(board_view)
	hud = Hud.new()
	world.add_child(hud)

	book = Monsternomicon.new()
	add_child(book)
	win = WinScreen.new()
	add_child(win)

	_xray_label = UiKit.label("x-ray", 12, UiKit.COL_RED, 2)
	_xray_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiKit.place(_xray_label, Vector2(196, 7), 388, 12)
	_xray_label.visible = false
	add_child(_xray_label)

	generating = UiKit.label("building dragon lair...", 16, UiKit.COL_TEXT)
	add_child(generating)

	get_window().size_changed.connect(_relayout)
	_relayout()

	board_view.tile_pressed.connect(_on_tile_pressed)
	board_view.mark_requested.connect(_on_mark_requested)
	board_view.menu.chosen.connect(_on_mark_chosen)
	board_view.menu.closed.connect(func() -> void: Audio.play("close_hover"))
	hud.hero_pressed.connect(_on_hero_pressed)
	hud.book_pressed.connect(_toggle_book)
	book.close_requested.connect(_toggle_book)
	win.dismissed.connect(_restart)

	new_game()
	if not OS.get_cmdline_user_args().is_empty() and ResourceLoader.exists("res://tools/dev_harness.gd"):
		add_child(load("res://tools/dev_harness.gd").new())


## Picks landscape or portrait from the window shape and sizes the canvas to the window's aspect.
func _relayout() -> void:
	var ws := Vector2(get_window().size)
	if ws.x <= 0 or ws.y <= 0:
		return
	_laid_out_for = Vector2i(ws)
	var aspect := ws.x / ws.y
	portrait = aspect < 1.0
	var hud_mode := Hud.Layout.BOTTOM
	layout_size = LANDSCAPE
	if portrait:
		layout_size = PORTRAIT
		hud_mode = Hud.Layout.PORTRAIT
	elif aspect >= WIDE_ASPECT:
		layout_size = WIDE
		hud_mode = Hud.Layout.SIDE
	# The stretch aspect is "expand": the window keeps this base size as a minimum and widens or
	# heightens the logical area to the window's aspect on its own. Setting the base only on a
	# layout change avoids a web viewport glitch when it changes on every resize.
	if get_window().content_scale_size != Vector2i(layout_size):
		get_window().content_scale_size = Vector2i(layout_size)
	var scale := minf(ws.x / layout_size.x, ws.y / layout_size.y)
	var logical := (ws / scale).ceil()
	offset = ((logical - layout_size) * 0.5).floor()
	bg.size = logical
	world.position = offset
	board_view.set_portrait(portrait)
	hud.set_layout(hud_mode)
	var board_area := Vector2(layout_size.x, layout_size.y - hud.height())
	if hud_mode == Hud.Layout.SIDE:
		hud.position = Vector2(layout_size.x - hud.size.x, 0)
		board_area = Vector2(layout_size.x - hud.size.x, layout_size.y)
	else:
		hud.position = Vector2(0, layout_size.y - hud.height())
	book.layout(offset, board_area)
	win.layout(Vector2.ZERO, logical)
	UiKit.place(generating, offset + layout_size * 0.5, 300, 16)
	UiKit.place(_xray_label, offset + Vector2(layout_size.x * 0.5, 7), layout_size.x - 4, 12)
	if game != null:
		render()


func new_game(seed_value := 0) -> void:
	if _restarting:
		return
	_restarting = true
	_history.clear()
	game = Game.new(seed_value)
	book.close_book()
	win.visible = false
	world.visible = false
	generating.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	game.generate()
	generating.visible = false
	world.visible = true
	board_view.input_enabled = true
	render()
	Audio.start_music()
	_restarting = false


func render() -> void:
	board_view.render(game, xray)
	_xray_label.visible = xray
	if xray:
		var f := game.clear_forecast()
		_xray_label.text = "x-ray  dmg %d  budget %d  meds %d  wasted %d" % [f.damage_left, f.budget, f.meds_left, f.wasted]
	hud.render(game)
	if book.visible:
		book.refresh()


func _restart() -> void:
	Audio.play("restart")
	new_game()


func _on_tile_pressed(p: Vector2i) -> void:
	if book.visible or not game.is_playing():
		return
	_remember()
	var ev := game.press(p)
	_apply(ev)
	render()


func _on_mark_requested(p: Vector2i) -> void:
	if book.visible or not game.is_playing():
		return
	board_view.menu.open(p, game.board.at_pos(p).mark, board_view.tile_rect(p), board_view.bounds())
	Audio.play("open_hover")


func _on_mark_chosen(p: Vector2i, mark: int) -> void:
	_apply(game.set_mark(p, mark))
	render()


func _on_hero_pressed() -> void:
	if book.visible:
		return
	if game.status == Game.Status.DEAD:
		_restart()
		return
	if game.can_level_up():
		_remember()
	var ev := game.hero_pressed()
	_apply(ev)
	render()
	if ev.is_empty() and game.is_playing():
		hud.play_tapped()
		Audio.play("jorge")


func _remember() -> void:
	_history.append(game.snapshot())
	if _history.size() > UNDO_DEPTH:
		_history.pop_front()


## Debug only: rewinds the last board press or level up, even out of a death or a win.
func _undo() -> void:
	if _history.is_empty():
		Audio.play("wrong")
		return
	game.restore(_history.pop_back())
	win.visible = false
	board_view.menu.visible = false
	board_view.input_enabled = not book.visible
	Audio.play("remove_mark")
	render()


func _toggle_book() -> void:
	if win.visible:
		return
	if book.visible:
		book.close_book()
		Audio.play("book_close")
	else:
		board_view.cancel_press()
		book.open_book(game)
		Settings.mark_nomicon_read()
		Audio.play("book")
	board_view.input_enabled = not book.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not win.visible:
		_restart()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cheat_reveal"):
		xray = not xray
		render()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("undo") and xray:
		_undo()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fullscreen"):
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# The browser build does not always signal growth after a shrink, so the size is polled too.
	if get_window().size != _laid_out_for:
		_relayout()
	if _shake_time > 0.0:
		_shake_time -= delta
		world.position = offset + Vector2(randf_range(-2, 2), randf_range(-1, 1))
		if _shake_time <= 0.0:
			world.position = offset


func shake(seconds: float) -> void:
	_shake_time = maxf(_shake_time, seconds)


func _apply(events: Array[GameEvent]) -> void:
	var fx := board_view.fx
	var reveal_sound := false
	for e in events:
		match e.type:
			GameEvent.Type.REVEALED:
				if e.flag:
					Audio.play("uncover")
				else:
					reveal_sound = true
					fx.flash(e.pos, Color(1, 1, 1, 0.6))
			GameEvent.Type.ATTACKED:
				_on_attacked(e)
			GameEvent.Type.COLLECTED:
				Audio.play("pick_xp")
				fx.float_text(e.pos, "+%d" % e.amount, UiKit.COL_YELLOW)
			GameEvent.Type.HEALED:
				Audio.play("heal")
				fx.burst(e.pos, Color("ff6b6b"), 10, 16.0)
			GameEvent.Type.REFUSED:
				Audio.play("wrong")
			GameEvent.Type.WALL_HIT:
				Audio.play("hit_wall")
				fx.burst(e.pos, Color("8fa0b0"), 5, 10.0)
				hud.play_stab()
			GameEvent.Type.WALL_DOWN:
				Audio.play("wall_down")
				fx.burst(e.pos, Color("8fa0b0"), 12, 18.0)
				hud.play_stab()
			GameEvent.Type.CHEST_OPENED:
				Audio.play("chest_open")
				fx.ripple(e.pos, UiKit.COL_GOLD)
			GameEvent.Type.GNOME_JUMPED:
				Audio.play("gnome_jump", 0.0)
				fx.puff(e.pos, SpriteDb.sprite("gnome"), e.target)
			GameEvent.Type.MINES_DISARMED:
				if e.amount > 0:
					Audio.play("earthquake")
					shake(1.0)
				else:
					Audio.play("wrong")
			GameEvent.Type.MINE_DISARMED_AT:
				fx.burst(e.pos, Color("ffaa33"), 10, 14.0)
			GameEvent.Type.SPELL_CAST:
				if e.kind == Kind.SPELL_DISARM:
					pass
				elif e.flag:
					Audio.play("reveal" if e.kind == Kind.SPELL_ORB else "spell")
				else:
					Audio.play("wrong")
			GameEvent.Type.ORB_USED:
				Audio.play("reveal" if e.flag else "wrong")
				fx.ripple(e.pos, Color("8ad8ff"), 0.4)
			GameEvent.Type.NUMBER_CHANGED:
				fx.flash(e.pos, Color(1, 1, 0.7, 0.5), 0.35)
			GameEvent.Type.DRAGON_DEFEATED:
				shake(0.8)
				fx.burst(e.pos, Color("ff4a3a"), 16, 26.0, 0.6)
			GameEvent.Type.MINE_EXPLODED:
				fx.burst(e.pos, Color("ffaa33"), 14, 22.0, 0.5)
				fx.flash(e.pos, Color(1, 0.8, 0.3, 0.9), 0.4)
			GameEvent.Type.LEVEL_UP:
				Audio.play("level_up")
				hud.play_level_up()
			GameEvent.Type.CAN_LEVEL_UP:
				Audio.play("can_level")
			GameEvent.Type.ALARM:
				Audio.play("alarm")
			GameEvent.Type.HP_CHANGED:
				hud.animate_hearts(e.amount, e.target.x)
			GameEvent.Type.XP_CHANGED:
				hud.animate_gems(e.amount, e.target.x)
			GameEvent.Type.DIED:
				Audio.play("lose")
				shake(0.7)
				board_view.menu.visible = false
			GameEvent.Type.WON:
				_on_won()
			GameEvent.Type.HERO_TAPPED:
				hud.play_tapped()
				Audio.play("jorge", 0.0)
			GameEvent.Type.MARK_SET:
				Audio.play("mark" if e.amount > 0 else "remove_mark")
	if reveal_sound:
		Audio.play("reveal")


func _on_attacked(e: GameEvent) -> void:
	var fx := board_view.fx
	if e.flag:
		hud.play_stab()
	match e.kind:
		Kind.DRAGON:
			Audio.play("dragon_dead")
		Kind.MINE:
			Audio.play("explode")
		Kind.GNOME:
			Audio.play("disappointed")
		Kind.DRAGON_EGG:
			Audio.play("crack_egg")
		Kind.RAT_KING, Kind.MINE_KING, Kind.WIZARD, Kind.GAZER, Kind.MIMIC, Kind.GIANT:
			Audio.play("fight_special")
			fx.burst(e.pos, Color("ffffff"), 10, 16.0)
		_:
			Audio.play("fight")
	if e.amount > 0:
		fx.flash(e.pos, Color(1, 0.2, 0.2, 0.55), 0.3)
		fx.float_text(e.pos, "-%d" % e.amount, UiKit.COL_RED)


func _on_won() -> void:
	Audio.play("win")
	var cleared_before := Settings.has_stamp(Stamps.CLEAR)
	Settings.add_stamps(game.stamps_this_run)
	board_view.input_enabled = false
	win.show_result(game, cleared_before, _max_score())


## Every xp on the board at the start: monsters, disarmed mines, and what chests and walls hold.
func _max_score() -> int:
	var total := 0
	var probe := Game.new(game.seed_value)
	probe.generate()
	for t in probe.board.tiles:
		total += t.xp
		if t.contains == Kind.TREASURE:
			total += t.contains_xp
	return total
