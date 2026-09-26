extends SceneTree
## Draws the game's own 16x16 item and monster icons into assets/sprites/icons.
## Run: Godot --headless --path . -s tools/gen_icons.gd

const OUT := "res://assets/sprites/icons/"

const PAL := {
	".": Color(0, 0, 0, 0),
	"o": Color("0e1015"),   # outline
	"b": Color("2b2f3a"),   # bomb body
	"h": Color("5c6472"),   # bomb highlight
	"g": Color("4a4f5a"),   # dead bomb body
	"f": Color("8a5a2b"),   # fuse
	"y": Color("ffd23f"),   # spark yellow
	"r": Color("ff6a1a"),   # spark orange
	"k": Color("f7b733"),   # crown gold
	"K": Color("b8791a"),   # crown shadow
	"j": Color("ff3b3b"),   # crown jewel
	"w": Color("f2f2f2"),   # eye white
	"p": Color("ffb0c8"),   # pink
	"B": Color("8a5a3b"),   # rat brown
	"L": Color("a8744f"),   # rat light brown
	"d": Color("4a2e1a"),   # rat dark
	"t": Color("c98a9a"),   # tail
	"R": Color("b89a6a"),   # scroll roll
	"P": Color("e8d9b0"),   # scroll paper
	"S": Color("cdb98a"),   # scroll paper shade
	"G": Color("4aa36a"),   # slime green
	"E": Color("8ee0a8"),   # slime light
	"a": Color("3a7bd5"),   # orb blue
	"A": Color("a8d8ff"),   # orb light
	"x": Color("d93a3a"),   # red slash
	"m": Color("1a1a1f"),   # mouth / crack
}

const MINE := [
	"..........yry...",
	"...........y....",
	"..........f.....",
	".........f......",
	"......oooo......",
	"....oobbbboo....",
	"...obbhhbbbbo...",
	"..obbhbbbbbbbo..",
	"..obbhbbbbbbbo..",
	"..obbbbbbbbbbo..",
	"..obbbbbbbbbbo..",
	"..obbbbbbbbbbo..",
	"...obbbbbbbbo...",
	"....oobbbboo....",
	"......oooo......",
	"................",
]

const MINE_DEAD := [
	"................",
	"................",
	"..........f.....",
	".........f......",
	"......oooo......",
	"....oogggmoo....",
	"...oggggmgggo...",
	"..oggggmgggggo..",
	"..oggggmgggggo..",
	"..ogggmggggggo..",
	"..oggmgggggggo..",
	"..ogggmggggggo..",
	"...ogggmggggo...",
	"....ooggggoo....",
	"......oooo......",
	"................",
]

const MINE_KING := [
	"..k...k...k.....",
	"..kk.kkk.kk.....",
	"..kkkkjkkkk...y.",
	"..KKKKKKKKK..ry.",
	"....oooooo..f...",
	"...obbbbbbof....",
	"..obhbbbbbbbo...",
	".obhbbwwbbwwbo..",
	".obbbbwobbwobo..",
	".obbbbbbbbbbbo..",
	".obbbbmmmmbbbo..",
	".obbbbbbbbbbbo..",
	"..obbbbbbbbbo...",
	"...obbbbbbbo....",
	"....oooooo......",
	"................",
]

const RAT_KING := [
	"................",
	"....k.k.k.......",
	"....kkjkk.......",
	"...oKKKKKoo.....",
	"..oBBBBBBBBBo...",
	".oBwBBBBBBBBBBo.",
	"pBBBBBBBBBBBBBBo",
	".oBBLLLLLLLBBBot",
	"..oBLLLLLLBBBoot",
	"...oBBBBBBBBoo.t",
	"....odd..ddo..t.",
	".............t..",
	"................",
	"................",
	"................",
	"................",
]

const SCROLL := [
	"................",
	"..RRRRRRRRRRRR..",
	".RRRRRRRRRRRRRR.",
	"..PPPPPPPPPPPP..",
	"..PPPPPPPPPPPP..",
	"..PPPPPPPPPPPP..",
	"..PPPPPPPPPPPP..",
	"..PPPPPPPPPPPP..",
	"..PPPPPPPPPPPP..",
	"..PPPPPPPPPPPP..",
	"..PPPPPPPPPPPP..",
	"..SSSSSSSSSSSS..",
	".RRRRRRRRRRRRRR.",
	"..RRRRRRRRRRRR..",
	"................",
	"................",
]

## Glyphs are 8x6 and drawn at (4, 4) over the paper. '.' keeps the paper.
const GLYPH_RATS := [
	"........",
	"..BBBB..",
	".BwBBBBt",
	"pBBBBBB.",
	".BBBBBB.",
	"..d..d..",
]
const GLYPH_SLIMES := [
	"........",
	"...GG...",
	"..GEGG..",
	".GGGGGG.",
	".GGGGGG.",
	"..GGGG..",
]
const GLYPH_DISARM := [
	".....x..",
	"..ooox..",
	".obbxbo.",
	".obxbbo.",
	".oxbbbo.",
	"..xoo...",
]
const GLYPH_ORB := [
	"........",
	"..aaaa..",
	".aAAaaa.",
	".aAaaaa.",
	".aaaaaa.",
	"..aaaa..",
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_paint(MINE), "mine")
	_save(_paint(MINE_DEAD), "mine_dead")
	_save(_paint(MINE_KING), "mine_king")
	_save(_paint(RAT_KING), "rat_king")
	_save(_scroll(GLYPH_RATS), "scroll_rats")
	_save(_scroll(GLYPH_SLIMES), "scroll_slimes")
	_save(_scroll(GLYPH_DISARM), "scroll_disarm")
	_save(_scroll(GLYPH_ORB), "scroll_orb")
	print("icons generated")
	quit()


func _paint(mask: Array) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in mask.size():
		var row: String = mask[y]
		for x in row.length():
			var c: Color = PAL.get(row[x], Color.MAGENTA)
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	return img


func _scroll(glyph: Array) -> Image:
	var img := _paint(SCROLL)
	for y in glyph.size():
		var row: String = glyph[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			img.set_pixel(4 + x, 4 + y, PAL[ch])
	return img


func _save(img: Image, name: String) -> void:
	if img.save_png(OUT + name + ".png") != OK:
		push_error("failed to save " + name)
