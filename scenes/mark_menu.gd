class_name MarkMenu
extends Node2D
## 4x4 picker of marks for a hidden tile: 1..12, three icons and a clear button.

signal chosen(pos: Vector2i, mark: int)
signal closed

const BUTTON := 24
const MARKS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
const CLEAR := 16

var tile_pos := Vector2i(-1, -1)
var _buttons: Array[Node2D] = []
var _rects: Array[Rect2] = []
var _marks: Array[int] = []
var _select: Sprite2D
var _hovered := -1


func _ready() -> void:
	visible = false
	_select = UiKit.sprite(SpriteDb.ui("tile_select"), Vector2.ZERO, false)
	add_child(_select)


func is_open() -> bool:
	return visible


func open(p: Vector2i, current_mark: int, tile_rect: Rect2, bounds: Rect2) -> void:
	tile_pos = p
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_rects.clear()
	_marks.clear()
	_hovered = -1
	_select.position = tile_rect.position
	var total := Vector2(4 * BUTTON, 4 * BUTTON)
	var base := Vector2(tile_rect.end.x, tile_rect.position.y - total.y * 0.5 + BUTTON * 0.5)
	if base.x + total.x > bounds.end.x:
		base.x = tile_rect.position.x - total.x
	base.y = clampf(base.y, bounds.position.y, bounds.end.y - total.y)
	var col := 0
	var row := 0
	for m in MARKS:
		if m == CLEAR and current_mark == 0:
			continue
		var r := Rect2(base + Vector2(col * BUTTON, row * BUTTON), Vector2(BUTTON, BUTTON))
		var node := Node2D.new()
		node.position = r.position
		node.add_child(UiKit.sprite(SpriteDb.ui("menu_button"), Vector2.ZERO, false))
		var glyph := _glyph(m)
		node.add_child(glyph)
		add_child(node)
		_buttons.append(node)
		_rects.append(r)
		_marks.append(m)
		col += 1
		if col == 4:
			col = 0
			row += 1
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _glyph(m: int) -> Node:
	match m:
		13:
			return UiKit.sprite(SpriteDb.ui("mark_mine"), Vector2(BUTTON, BUTTON) * 0.5)
		14:
			return UiKit.sprite(SpriteDb.ui("mark_question"), Vector2(BUTTON, BUTTON) * 0.5)
		15:
			return UiKit.sprite(SpriteDb.ui("mark_loot"), Vector2(BUTTON, BUTTON) * 0.5)
		16:
			return UiKit.sprite(SpriteDb.ui("mark_clear"), Vector2(BUTTON, BUTTON) * 0.5)
	var l := UiKit.label(str(m), 16, UiKit.COL_YELLOW, 2)
	UiKit.place(l, Vector2(BUTTON, BUTTON) * 0.5, BUTTON, 16)
	return l


## Returns true when the click was consumed by the menu.
func click(local: Vector2) -> bool:
	if not visible:
		return false
	for i in _rects.size():
		if _rects[i].has_point(local):
			var m := _marks[i]
			chosen.emit(tile_pos, 0 if m == CLEAR else m)
			visible = false
			return true
	close()
	return true


func hover(local: Vector2) -> void:
	if not visible:
		return
	var h := -1
	for i in _rects.size():
		if _rects[i].has_point(local):
			h = i
	if h == _hovered:
		return
	_hovered = h
	for i in _buttons.size():
		var bg := _buttons[i].get_child(0) as Sprite2D
		bg.texture = SpriteDb.ui("menu_button_hover" if i == h else "menu_button")
