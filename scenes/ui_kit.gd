class_name UiKit
## Fonts, colours and small node factories shared by every scene.

const FONT_PATH := "res://assets/fonts/kenney_mini.ttf"
const FONT_ALT_PATH := "res://assets/fonts/kenney_pixel.ttf"

const COL_TEXT := Color("ffffff")
const COL_DIM := Color("b9bec6")
const COL_ORANGE := Color("ffb700")
const COL_YELLOW := Color("f7e26b")
const COL_GOLD := Color("f7b733")
const COL_RED := Color("ff0d31")
const COL_OUTLINE := Color("0d1014")
const COL_BOOK := Color("2a1806")
const COL_BOOK_SOFT := Color("4a2e10")
const COL_BG := Color("293333")

static var _font: Font
static var _font_alt: Font


static func font() -> Font:
	if _font == null:
		_font = _load_pixel_font(FONT_PATH)
	return _font


static func font_alt() -> Font:
	if _font_alt == null:
		_font_alt = _load_pixel_font(FONT_ALT_PATH)
	return _font_alt


static func _load_pixel_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f: FontFile = load(path)
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		return f
	return ThemeDB.fallback_font


static func settings(size: int, color: Color, outline := 0, outline_color := COL_OUTLINE) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = font()
	s.font_size = size
	s.font_color = color
	s.outline_size = outline
	s.outline_color = outline_color
	return s


## A label whose rect is centred on (or anchored at) a point, for pixel-precise placement.
static func label(text: String, size: int, color: Color, outline := 0) -> Label:
	var l := Label.new()
	l.label_settings = settings(size, color, outline)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func place(l: Label, center: Vector2, w := 40.0, h := 12.0) -> void:
	l.size = Vector2(w, h)
	l.position = center - Vector2(w, h) * 0.5


static func sprite(tex: Texture2D, pos: Vector2, centered := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = centered
	s.position = pos
	return s
