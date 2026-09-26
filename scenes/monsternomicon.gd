class_name Monsternomicon
extends Node2D
## The book overlay: hints, toggles and live monster counts on page 0, stamps and credits on page 1.

signal page_flipped
signal close_requested

const VERSION := "v0.1.0"
const PANEL_POS := Vector2(4, 5)
const PANEL_SIZE := Vector2(381, 289)
const PLATINO_TAPS := 5

var page := 0
var _pages: Array[Node2D] = []
var _count_labels := {}
var _level_labels := {}
var _sound_label: Label
var _music_label: Label
var _sound_rect: Rect2
var _music_rect: Rect2
var _flap_next_rect: Rect2
var _flap_prev_rect: Rect2
var _version_rect: Rect2
var _version_taps := 0
var _platino: Sprite2D
var _stamp_sprites: Array[Sprite2D] = []
var _game: Game


func _ready() -> void:
	visible = false
	position = PANEL_POS
	add_child(UiKit.sprite(SpriteDb.ui("book_panel"), Vector2.ZERO, false))
	_build_page0()
	_build_page1()
	_show_page(0)


func _left_center_x() -> float:
	return PANEL_SIZE.x * 0.25


func _right_center_x() -> float:
	return PANEL_SIZE.x * 0.75


func _build_page0() -> void:
	var pg := Node2D.new()
	add_child(pg)
	_pages.append(pg)
	var title := UiKit.label("Monsternomicon", 14, UiKit.COL_BOOK)
	UiKit.place(title, Vector2(_left_center_x(), 26), 180, 14)
	pg.add_child(title)

	var touch := DisplayServer.is_touchscreen_available()
	var hints := [
		"* slay the dragon",
		"* dying is safe",
		"* click jorge to level",
		"* hold a tile to mark" if touch else "* right click to mark",
		"* numbers add up the",
		"  monster levels near",
	]
	var y := 50.0
	for h in hints:
		var l := UiKit.label(h, 12, UiKit.COL_BOOK_SOFT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiKit.place(l, Vector2(_left_center_x() + 2, y), 176, 12)
		pg.add_child(l)
		y += 16

	var note1 := UiKit.label("observe monster", 12, UiKit.COL_BOOK)
	UiKit.place(note1, Vector2(_left_center_x(), 200), 180, 12)
	pg.add_child(note1)
	var note2 := UiKit.label("patterns when dead", 12, UiKit.COL_BOOK)
	UiKit.place(note2, Vector2(_left_center_x(), 213), 180, 12)
	pg.add_child(note2)

	_sound_rect = Rect2(12, 248, 84, 20)
	_music_rect = Rect2(104, 248, 84, 20)
	_sound_label = _toggle_label(pg, _sound_rect)
	_music_label = _toggle_label(pg, _music_rect)

	var col := 0
	var row := 0
	for kind in Catalog.BOOK_ORDER:
		var cx := _right_center_x() - 60 + col * 92
		var cy := 36 + row * 23
		pg.add_child(UiKit.sprite(SpriteDb.ui("menu_button"), Vector2(cx, cy)))
		var name := TileView._monster_sprite_for_kind(kind)
		var icon := UiKit.sprite(SpriteDb.sprite(name), Vector2(cx, cy))
		icon.flip_h = SpriteDb.flip_h(name)
		pg.add_child(icon)
		var lvl := UiKit.label("", 12, UiKit.COL_ORANGE, 2)
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UiKit.place(lvl, Vector2(cx - 33, cy), 30, 12)
		pg.add_child(lvl)
		_level_labels[kind] = lvl
		var cnt := UiKit.label("", 12, UiKit.COL_BOOK)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiKit.place(cnt, Vector2(cx + 38, cy), 40, 12)
		pg.add_child(cnt)
		_count_labels[kind] = cnt
		row += 1
		if row == 10:
			row = 0
			col += 1

	var ver := UiKit.label(VERSION, 12, UiKit.COL_BOOK_SOFT)
	_version_rect = Rect2(PANEL_SIZE.x * 0.5 + 8, PANEL_SIZE.y - 26, 60, 18)
	UiKit.place(ver, _version_rect.get_center(), 60, 12)
	pg.add_child(ver)
	_platino = UiKit.sprite(SpriteDb.sprite("platino"), _version_rect.get_center() + Vector2(40, 0))
	_platino.visible = false
	pg.add_child(_platino)

	_flap_next_rect = Rect2(PANEL_SIZE.x - 28, PANEL_SIZE.y - 28, 24, 24)
	pg.add_child(UiKit.sprite(SpriteDb.ui("flap_next"), _flap_next_rect.position, false))


func _toggle_label(pg: Node2D, r: Rect2) -> Label:
	var bg := UiKit.sprite(SpriteDb.ui("px"), r.position, false)
	bg.scale = r.size / 4.0
	bg.modulate = Color("c9b58c")
	pg.add_child(bg)
	var l := UiKit.label("", 12, UiKit.COL_BOOK)
	UiKit.place(l, r.get_center(), r.size.x, 12)
	pg.add_child(l)
	return l


func _build_page1() -> void:
	var pg := Node2D.new()
	add_child(pg)
	_pages.append(pg)
	var title := UiKit.label("** stamps **", 14, UiKit.COL_BOOK)
	UiKit.place(title, Vector2(_left_center_x(), 30), 180, 14)
	pg.add_child(title)
	var y := 66.0
	for i in Stamps.ALL.size():
		var s := UiKit.sprite(SpriteDb.ui("stamp_%d_locked" % i), Vector2(32, y))
		pg.add_child(s)
		_stamp_sprites.append(s)
		var desc: Array = Stamps.DESCRIPTIONS[Stamps.ALL[i]]
		var l1 := UiKit.label(desc[0], 12, UiKit.COL_BOOK)
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiKit.place(l1, Vector2(120, y - 7), 134, 12)
		pg.add_child(l1)
		var l2 := UiKit.label(desc[1], 12, UiKit.COL_BOOK)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiKit.place(l2, Vector2(120, y + 7), 134, 12)
		pg.add_child(l2)
		y += 46

	var credits := [
		"a dragonsweeper clone",
		"",
		"inspired by",
		"dragonsweeper by",
		"daniel benmergui",
		"and mamono sweeper",
		"",
		"art: kenney (cc0)",
		"tiny dungeon",
		"dawnlike by",
		"dragondeplatino",
		"palette: dawnbringer",
		"(cc-by 4.0)",
		"",
		"fonts, sounds: kenney",
		"ambience: opengameart",
		"",
		"made with godot",
	]
	var cy := 34.0
	for line in credits:
		var l := UiKit.label(line, 12, UiKit.COL_BOOK_SOFT)
		UiKit.place(l, Vector2(_right_center_x(), cy), 186, 12)
		pg.add_child(l)
		cy += 14

	_flap_prev_rect = Rect2(4, PANEL_SIZE.y - 28, 24, 24)
	pg.add_child(UiKit.sprite(SpriteDb.ui("flap_prev"), _flap_prev_rect.position, false))


func _show_page(i: int) -> void:
	page = i
	for k in _pages.size():
		_pages[k].visible = k == i


func open_book(game: Game) -> void:
	_game = game
	_show_page(0)
	refresh()
	visible = true


func close_book() -> void:
	visible = false


func refresh() -> void:
	if _game == null:
		return
	for kind in Catalog.BOOK_ORDER:
		var count := _game.book_count(kind)
		var label: Label = _count_labels[kind]
		label.text = "x?" if kind == Kind.GAZER else "x%d" % count
		var lvl: Label = _level_labels[kind]
		var level := _game.book_level(kind)
		lvl.text = str(level) if (Catalog.is_monster(kind) and (level > 0 or kind == Kind.MINE)) else ""
	_sound_label.text = "sound: %s" % ("on" if Settings.sound_on else "off")
	_music_label.text = "music: %s" % ("on" if Settings.music_on else "off")
	for i in _stamp_sprites.size():
		var owned := Settings.has_stamp(Stamps.ALL[i])
		_stamp_sprites[i].texture = SpriteDb.ui("stamp_%d%s" % [i, "" if owned else "_locked"])


## Handles a click at a position local to this node. Returns true when something happened.
func click(local: Vector2) -> bool:
	if not visible:
		return false
	if page == 0:
		if _sound_rect.has_point(local):
			Settings.set_sound(not Settings.sound_on)
			if Settings.sound_on:
				Audio.play("spell")
			refresh()
			return true
		if _music_rect.has_point(local):
			Settings.set_music(not Settings.music_on)
			refresh()
			return true
		if _flap_next_rect.has_point(local):
			_show_page(1)
			Audio.play("pageflip")
			page_flipped.emit()
			return true
		if _version_rect.has_point(local):
			_version_taps += 1
			if _version_taps >= PLATINO_TAPS:
				_platino.visible = true
			return true
	else:
		if _flap_prev_rect.has_point(local):
			_show_page(0)
			Audio.play("pageflip")
			page_flipped.emit()
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var local := to_local(event.position)
		if Rect2(Vector2.ZERO, PANEL_SIZE).has_point(local):
			if event.button_index == MOUSE_BUTTON_LEFT:
				click(local)
		else:
			close_requested.emit()
		get_viewport().set_input_as_handled()
