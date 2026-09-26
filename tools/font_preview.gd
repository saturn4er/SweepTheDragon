extends SceneTree
## Renders sample text in every candidate font at 2x so a readable one can be picked.
## Run: Godot --path . -s tools/font_preview.gd -- out.png

const FONTS := [
	"res://assets/fonts/kenney_pixel.ttf",
	"res://assets/fonts/kenney_mini.ttf",
	"res://assets/fonts/sds_8x8.ttf",
	"/private/tmp/claude-501/-Users-saturn4er-Dev-dragonsweeper/0ab5f6e9-7e48-4241-b31a-3bfef956f3d8/scratchpad/dl/kenney_fonts/Fonts/Kenney Future.ttf",
	"/private/tmp/claude-501/-Users-saturn4er-Dev-dragonsweeper/0ab5f6e9-7e48-4241-b31a-3bfef956f3d8/scratchpad/dl/kenney_fonts/Fonts/Kenney Future Narrow.ttf",
	"/private/tmp/claude-501/-Users-saturn4er-Dev-dragonsweeper/0ab5f6e9-7e48-4241-b31a-3bfef956f3d8/scratchpad/dl/kenney_fonts/Fonts/Kenney Blocks.ttf",
	"/private/tmp/claude-501/-Users-saturn4er-Dev-dragonsweeper/0ab5f6e9-7e48-4241-b31a-3bfef956f3d8/scratchpad/dl/kenney_fonts/Fonts/Kenney High.ttf",
	"/private/tmp/claude-501/-Users-saturn4er-Dev-dragonsweeper/0ab5f6e9-7e48-4241-b31a-3bfef956f3d8/scratchpad/dl/kenney_fonts/Fonts/Kenney Rocket.ttf",
	"/private/tmp/claude-501/-Users-saturn4er-Dev-dragonsweeper/0ab5f6e9-7e48-4241-b31a-3bfef956f3d8/scratchpad/dl/kenney_fonts/Fonts/Kenney Pixel Square.ttf",
	"default",
]


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "fonts.png"
	get_root().size = Vector2i(780, 680)
	var bg := ColorRect.new()
	bg.color = Color("293333")
	bg.size = Vector2(780, 680)
	get_root().add_child(bg)
	var paper := ColorRect.new()
	paper.color = Color("e0cfa8")
	paper.position = Vector2(400, 0)
	paper.size = Vector2(380, 680)
	get_root().add_child(paper)
	var y := 4.0
	for path in FONTS:
		var font: Font
		if path == "default":
			font = ThemeDB.fallback_font
		else:
			var ff := FontFile.new()
			ff.load_dynamic_font(path)
			ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			ff.hinting = TextServer.HINTING_NONE
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			font = ff
		var name: String = str(path).get_file().get_basename()
		for size in [16, 24, 32]:
			var l := Label.new()
			var s := LabelSettings.new()
			s.font = font
			s.font_size = size
			s.font_color = Color.WHITE
			s.outline_size = 3
			s.outline_color = Color("101418")
			l.label_settings = s
			l.text = "%s %d: Jorge 13 slain by a skeleton" % [name, size]
			l.position = Vector2(4, y)
			get_root().add_child(l)
			var l2 := Label.new()
			var s2 := s.duplicate()
			s2.font_color = Color("3a2208")
			s2.outline_size = 0
			l2.label_settings = s2
			l2.text = "%d * jorge must defeat the dragon x13" % size
			l2.position = Vector2(404, y)
			get_root().add_child(l2)
			y += size + 4
		y += 4
	await process_frame
	await process_frame
	await process_frame
	get_root().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
