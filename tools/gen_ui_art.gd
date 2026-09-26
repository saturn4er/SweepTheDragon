extends SceneTree
## Generates the game's own pixel art (tiles, hearts, gems, marks, panels) into assets/sprites/ui.
## Run: Godot --headless --path . -s tools/gen_ui_art.gd

const OUT := "res://assets/sprites/ui/"

const C_OUTLINE := Color("1a1f26")
const C_TILE := Color("5f7080")
const C_TILE_HI := Color("8fa0b0")
const C_TILE_LO := Color("33404d")
const C_FLOOR := Color("262c33")
const C_FLOOR_HI := Color("30383f")
const C_FLOOR_LO := Color("1b2026")
const C_LOOT := Color("34302a")
const C_LOOT_HI := Color("453e33")
const C_RED := Color("e03c3c")
const C_RED_HI := Color("ff8a8a")
const C_RED_LO := Color("8a1c1c")
const C_DARK := Color("2c2c34")
const C_GEM := Color("3cd6a0")
const C_GEM_HI := Color("a8ffe0")
const C_GEM_LO := Color("1f7a5c")
const C_YELLOW := Color("f7e26b")
const C_GOLD := Color("f7b733")
const C_WHITE := Color("f2f2f2")
const C_PARCH := Color("e0cfa8")
const C_PARCH_LO := Color("c9b58c")
const C_PARCH_LINE := Color("8b6b45")
const C_PARCH_EDGE := Color("6b4a2b")
const C_HUD := Color("1d232b")
const C_HUD_HI := Color("3a4653")
const C_HUD_LO := Color("0f1216")
const C_BTN := Color("2b333d")
const C_BTN_HI := Color("6d7d8d")

const HEART := [
	".XXX...XXX.",
	"XXXXX.XXXXX",
	"XXXXXXXXXXX",
	"XXXXXXXXXXX",
	"XXXXXXXXXXX",
	".XXXXXXXXX.",
	"..XXXXXXX..",
	"...XXXXX...",
	"....XXX....",
	".....X.....",
]
const GEM := [
	"...XX...",
	"..XXXX..",
	".XXXXXX.",
	"XXXXXXXX",
	".XXXXXX.",
	"..XXXX..",
	"...XX...",
]
const QUESTION := [
	".XXXX.",
	"XX..XX",
	"....XX",
	"...XX.",
	"..XX..",
	"..XX..",
	"......",
	"..XX..",
	"..XX..",
]
const STAR := [
	"....X....",
	"....X....",
	"...XXX...",
	"XXXXXXXXX",
	".XXXXXXX.",
	"..XXXXX..",
	".XXX.XXX.",
	"XX.....XX",
]
const CHECK := [
	"..........XX",
	".........XXX",
	"........XXX.",
	".......XXX..",
	"XX....XXX...",
	"XXX..XXX....",
	".XXXXXX.....",
	"..XXXX......",
	"...XX.......",
]
const EGG := [
	"...XXXX...",
	"..XXXXXX..",
	".XXXXXXXX.",
	".XXXXXXXX.",
	"XXXXXXXXXX",
	"XXXXXXXXXX",
	"XXXXXXXXXX",
	"XXXXXXXXXX",
	".XXXXXXXX.",
	".XXXXXXXX.",
	"..XXXXXX..",
	"...XXXX...",
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_tiles()
	_hearts()
	_gems()
	_marks()
	_buttons()
	_panels()
	_stamps()
	_misc()
	print("ui art generated")
	quit()


func _new(w: int, h: int, fill := Color(0, 0, 0, 0)) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return img


func _save(img: Image, name: String) -> void:
	var err := img.save_png(OUT + name + ".png")
	if err != OK:
		push_error("failed to save %s: %s" % [name, err])


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


func _paint(img: Image, mask: Array, ox: int, oy: int, c: Color) -> void:
	for y in mask.size():
		var row: String = mask[y]
		for x in row.length():
			if row[x] == "X":
				img.set_pixel(ox + x, oy + y, c)


func _outline(img: Image, mask: Array, ox: int, oy: int, c: Color) -> void:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		_paint(img, mask, ox + d.x, oy + d.y, c)


func _frame(img: Image, w: int, h: int, c: Color, thickness := 1) -> void:
	_rect(img, 0, 0, w, thickness, c)
	_rect(img, 0, h - thickness, w, thickness, c)
	_rect(img, 0, 0, thickness, h, c)
	_rect(img, w - thickness, 0, thickness, h, c)


func _circle(img: Image, cx: float, cy: float, r: float, c: Color, inner := -1.0) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d <= r and d >= inner:
				img.set_pixel(x, y, c)


func _tiles() -> void:
	var seed_state := 12345
	for n in 16:
		var img := _new(30, 30, C_OUTLINE)
		_rect(img, 1, 1, 28, 28, C_TILE)
		_rect(img, 1, 1, 28, 2, C_TILE_HI)
		_rect(img, 1, 1, 2, 28, C_TILE_HI)
		_rect(img, 1, 27, 28, 2, C_TILE_LO)
		_rect(img, 27, 1, 2, 28, C_TILE_LO)
		img.set_pixel(1, 28, C_TILE)
		img.set_pixel(28, 1, C_TILE)
		for _s in 7:
			seed_state = (seed_state * 1103515245 + 12345) % 2147483648
			var sx := 4 + (seed_state >> 8) % 22
			seed_state = (seed_state * 1103515245 + 12345) % 2147483648
			var sy := 4 + (seed_state >> 8) % 22
			var shade := C_TILE.darkened(0.12) if (seed_state >> 4) % 2 == 0 else C_TILE.lightened(0.10)
			img.set_pixel(sx, sy, shade)
			if n % 3 == 0 and _s == 0:
				img.set_pixel(sx + 1, sy, C_TILE.darkened(0.2))
				img.set_pixel(sx + 1, sy + 1, C_TILE.darkened(0.2))
				img.set_pixel(sx + 2, sy + 1, C_TILE.darkened(0.15))
		_save(img, "tile_hidden_%d" % n)

	var floor_img := _new(30, 30, C_OUTLINE)
	_rect(floor_img, 1, 1, 28, 28, C_FLOOR)
	_rect(floor_img, 1, 1, 28, 1, C_FLOOR_LO)
	_rect(floor_img, 1, 1, 1, 28, C_FLOOR_LO)
	_rect(floor_img, 1, 28, 28, 1, C_FLOOR_HI)
	_rect(floor_img, 28, 1, 1, 28, C_FLOOR_HI)
	_save(floor_img, "tile_floor")

	var loot := _new(30, 30, C_OUTLINE)
	_rect(loot, 1, 1, 28, 28, C_LOOT)
	_rect(loot, 1, 1, 28, 1, C_FLOOR_LO)
	_rect(loot, 1, 1, 1, 28, C_FLOOR_LO)
	_rect(loot, 1, 28, 28, 1, C_LOOT_HI)
	_rect(loot, 28, 1, 1, 28, C_LOOT_HI)
	_save(loot, "tile_loot")

	var dragon := _new(30, 30, C_OUTLINE)
	_rect(dragon, 1, 1, 28, 28, Color("3a2222"))
	_rect(dragon, 1, 1, 28, 1, Color("2a1616"))
	_rect(dragon, 1, 1, 1, 28, Color("2a1616"))
	_rect(dragon, 1, 28, 28, 1, Color("55302f"))
	_rect(dragon, 28, 1, 1, 28, Color("55302f"))
	_save(dragon, "tile_lair")

	var sel := _new(30, 30)
	_frame(sel, 30, 30, C_YELLOW, 2)
	_save(sel, "tile_select")

	for i in 2:
		var ring := _new(30, 30)
		_circle(ring, 15, 15, 12.5 if i == 0 else 13.5, C_WHITE, 10.5 if i == 0 else 10.5)
		_save(ring, "ring_%d" % i)

	var rubble := _new(16, 16)
	for p in [[3, 11], [4, 11], [5, 12], [9, 10], [10, 10], [11, 11], [12, 12], [7, 13], [8, 13], [6, 9]]:
		rubble.set_pixel(p[0], p[1], C_TILE_LO)
	for p in [[4, 12], [10, 11], [8, 12]]:
		rubble.set_pixel(p[0], p[1], C_TILE)
	_save(rubble, "floor_rubble")

	var mat := _new(16, 16)
	_rect(mat, 3, 10, 10, 4, Color("4a3a24"))
	_rect(mat, 4, 11, 8, 2, Color("5c4a2e"))
	_save(mat, "floor_chest_mark")


func _hearts() -> void:
	var full := _new(16, 16)
	_outline(full, HEART, 2, 3, C_RED_LO)
	_paint(full, HEART, 2, 3, C_RED)
	full.set_pixel(4, 4, C_RED_HI)
	full.set_pixel(5, 4, C_RED_HI)
	full.set_pixel(3, 5, C_RED_HI)
	_save(full, "heart_full")

	var empty := _new(16, 16)
	_outline(empty, HEART, 2, 3, Color("15161a"))
	_paint(empty, HEART, 2, 3, C_DARK)
	_save(empty, "heart_empty")

	var half := _new(16, 16)
	_outline(half, HEART, 2, 3, Color("15161a"))
	_paint(half, HEART, 2, 3, C_DARK)
	for y in HEART.size():
		for x in 5:
			if HEART[y][x] == "X":
				half.set_pixel(2 + x, 3 + y, C_RED)
	half.set_pixel(4, 4, C_RED_HI)
	_save(half, "heart_half")

	var blank := _new(16, 16)
	_paint(blank, HEART, 2, 3, Color(0.1, 0.1, 0.12, 0.35))
	_save(blank, "heart_blank")


func _gems() -> void:
	var full := _new(8, 8)
	_paint(full, GEM, 0, 0, C_GEM)
	full.set_pixel(3, 1, C_GEM_HI)
	full.set_pixel(2, 2, C_GEM_HI)
	full.set_pixel(4, 5, C_GEM_LO)
	full.set_pixel(5, 4, C_GEM_LO)
	_save(full, "xp_full")

	var empty := _new(8, 8)
	_paint(empty, GEM, 0, 0, Color("1f2429"))
	for y in GEM.size():
		for x in 8:
			if GEM[y][x] == "X" and (x == 0 or x == 7 or y == 0 or y == 6 or GEM[y][maxi(x - 1, 0)] != "X" or GEM[y][mini(x + 1, 7)] != "X"):
				empty.set_pixel(x, y, Color("3a434d"))
	_save(empty, "xp_empty")

	var plus := _new(8, 8)
	_rect(plus, 3, 1, 2, 6, C_GOLD)
	_rect(plus, 1, 3, 6, 2, C_GOLD)
	_save(plus, "xp_excess")


func _marks() -> void:
	var mine := _new(16, 16)
	_circle(mine, 8, 9, 5.2, Color("15161a"))
	_circle(mine, 8, 9, 4.2, Color("2f3238"))
	mine.set_pixel(6, 7, Color("6a6f78"))
	mine.set_pixel(7, 7, Color("6a6f78"))
	mine.set_pixel(6, 8, Color("6a6f78"))
	_rect(mine, 9, 3, 1, 3, Color("6a5030"))
	_rect(mine, 10, 2, 1, 2, Color("6a5030"))
	mine.set_pixel(11, 1, C_GOLD)
	mine.set_pixel(11, 2, C_RED)
	_save(mine, "mark_mine")

	var q := _new(16, 16)
	_outline(q, QUESTION, 5, 3, Color("15161a"))
	_paint(q, QUESTION, 5, 3, C_YELLOW)
	_save(q, "mark_question")

	var loot := _new(16, 16)
	_outline(loot, STAR, 3, 4, Color("15161a"))
	_paint(loot, STAR, 3, 4, C_GOLD)
	_save(loot, "mark_loot")

	var clear := _new(16, 16)
	for i in 9:
		for d in [[0, 0], [1, 0], [0, 1]]:
			var x: int = 4 + i + d[0]
			var y: int = 4 + i + d[1]
			if x < 13 and y < 13:
				clear.set_pixel(x, y, C_RED)
				clear.set_pixel(16 - x, y, C_RED)
	_save(clear, "mark_clear")

	var star := _new(8, 8)
	_paint(star, [
		"...X....",
		"..XXX...",
		"XXXXXXX.",
		".XXXXX..",
		"..XXX...",
		".XX.XX..",
	], 0, 1, C_YELLOW)
	_save(star, "xp_star")


func _buttons() -> void:
	var menu := _new(24, 24, C_OUTLINE)
	_rect(menu, 1, 1, 22, 22, C_BTN)
	_rect(menu, 1, 1, 22, 1, C_BTN_HI)
	_rect(menu, 1, 1, 1, 22, C_BTN_HI)
	_rect(menu, 1, 22, 22, 1, C_HUD_LO)
	_rect(menu, 22, 1, 1, 22, C_HUD_LO)
	_save(menu, "menu_button")

	var menu_hi := _new(24, 24, C_OUTLINE)
	_rect(menu_hi, 1, 1, 22, 22, Color("3d4a58"))
	_frame(menu_hi, 24, 24, C_YELLOW, 1)
	_save(menu_hi, "menu_button_hover")

	for on in [false, true]:
		var btn := _new(30, 29)
		var border := C_GOLD if on else Color("4a5866")
		var fill := Color("4a3a12") if on else C_BTN
		_rect(btn, 1, 0, 28, 29, border)
		_rect(btn, 0, 1, 30, 27, border)
		_rect(btn, 2, 1, 26, 27, fill)
		_rect(btn, 1, 2, 28, 25, fill)
		if on:
			_rect(btn, 2, 1, 26, 1, Color("ffe08a"))
		_save(btn, "hero_button_on" if on else "hero_button_off")

	var round := _new(32, 32)
	_circle(round, 16, 16, 15.5, C_OUTLINE)
	_circle(round, 16, 16, 14.5, C_PARCH)
	_circle(round, 16, 16, 13.5, C_PARCH_LO, 12.5)
	_save(round, "book_button")


func _panels() -> void:
	var hud := _new(390, 41, C_HUD)
	_rect(hud, 0, 0, 390, 1, C_HUD_HI)
	_rect(hud, 0, 1, 390, 1, C_HUD_LO)
	_rect(hud, 0, 40, 390, 1, C_HUD_LO)
	for x in range(0, 390, 6):
		hud.set_pixel(x, 39, Color("232a33"))
	_save(hud, "hud_panel")

	var book := _new(381, 289)
	_rect(book, 2, 2, 377, 285, C_PARCH_EDGE)
	_rect(book, 4, 4, 373, 281, C_PARCH)
	for i in 3:
		_rect(book, 6 + i, 6 + i, 369 - 2 * i, 1, C_PARCH_LO if i == 0 else C_PARCH)
	_rect(book, 188, 4, 5, 281, C_PARCH_LO)
	_rect(book, 190, 4, 1, 281, C_PARCH_LINE)
	for x in range(0, 379):
		var shade := C_PARCH_LO.lerp(C_PARCH, 0.4)
		if (x + 0) % 2 == 0:
			book.set_pixel(x, 285, shade)
	for c in [[0, 0], [380, 0], [0, 288], [380, 288], [1, 0], [0, 1], [379, 0], [380, 1], [0, 287], [1, 288], [380, 287], [379, 288]]:
		book.set_pixel(c[0], c[1], Color(0, 0, 0, 0))
	_save(book, "book_panel")

	for flip in [false, true]:
		var flap := _new(24, 24)
		for y in 24:
			for x in 24:
				var fx := x if not flip else 23 - x
				if fx + y >= 23 and y >= 4:
					var c := C_PARCH_LO if fx + y > 26 else C_PARCH_EDGE
					if fx + y >= 40:
						c = C_PARCH_EDGE.darkened(0.2)
					flap.set_pixel(x, y, c)
		_save(flap, "flap_prev" if flip else "flap_next")

	var scan := _new(390, 340)
	for y in range(0, 340, 2):
		_rect(scan, 0, y, 390, 1, Color(0, 0, 0, 0.10))
	_save(scan, "scanlines")

	var winbg := _new(390, 340, Color("06070a"))
	for i in 60:
		var x := (i * 97 + 13) % 390
		var y := (i * 61 + 7) % 200
		winbg.set_pixel(x, y, Color("3a3f4a") if i % 3 else Color("6a707c"))
	_save(winbg, "win_bg")


func _stamps() -> void:
	var glyph_colors := [Color("d94a5a"), Color("4aa36a"), Color("e0b040"), Color("5a8fd9")]
	for locked in [false, true]:
		for i in 4:
			var img := _new(30, 30)
			var ink: Color = glyph_colors[i] if not locked else Color("7a7a80")
			var paper: Color = Color("f3e6c5") if not locked else Color("3a3a40")
			_circle(img, 15, 15, 14.5, ink.darkened(0.45))
			_circle(img, 15, 15, 13.2, paper)
			_circle(img, 15, 15, 12.0, ink, 11.0)
			match i:
				0:
					_paint(img, HEART, 4, 9, ink)
					_paint(img, HEART, 15, 9, ink)
				1:
					_paint(img, CHECK, 9, 10, ink)
				2:
					_paint(img, EGG, 10, 9, ink)
					img.set_pixel(13, 13, paper)
					img.set_pixel(17, 16, paper)
				3:
					_circle(img, 15, 15, 8.0, ink, 6.5)
					_rect(img, 14, 8, 2, 14, ink)
					for d in 6:
						img.set_pixel(14 - d, 16 + d, ink)
						img.set_pixel(15 + d, 16 + d, ink)
			_save(img, "stamp_%d%s" % [i, "_locked" if locked else ""])


func _misc() -> void:
	var dot := _new(4, 4, C_WHITE)
	_save(dot, "px")
	var shadow := _new(16, 6)
	_circle(shadow, 8, 3, 7.5, Color(0, 0, 0, 0.35))
	_save(shadow, "shadow")
