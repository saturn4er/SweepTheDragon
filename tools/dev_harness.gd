extends Node
## Drives the running game from command-line user args, for screenshots and smoke tests.
## Godot --path . -- --shot=out.png --seed=2024 --press=3,4 --press=hero --press=book --wait=0.5

var main: Node


func _ready() -> void:
	main = get_parent()
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := ""
	var seed_value := 0
	var steps: Array[String] = []
	var wait := 0.0
	for a in args:
		if a.begins_with("--shot="):
			shot = a.trim_prefix("--shot=")
		elif a.begins_with("--seed="):
			seed_value = int(a.trim_prefix("--seed="))
		elif a.begins_with("--press="):
			steps.append(a.trim_prefix("--press="))
		elif a.begins_with("--wait="):
			wait = float(a.trim_prefix("--wait="))
	if shot == "":
		return
	await get_tree().process_frame
	if seed_value != 0:
		await main.new_game(seed_value)
	for _i in 4:
		await get_tree().process_frame
	for s in steps:
		match s:
			"hero":
				main._on_hero_pressed()
			"book":
				main._toggle_book()
			"mark":
				main._on_mark_requested(Vector2i(4, 4))
			"win":
				main.game.board.at(6, 4).become(Kind.CROWN)
				main.game.board.at(6, 4).revealed = true
				main.render()
				main._on_tile_pressed(Vector2i(6, 4))
			_:
				var parts := s.split(",")
				main._on_tile_pressed(Vector2i(int(parts[0]), int(parts[1])))
		await get_tree().process_frame
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	for _i in 6:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot)
	print("saved ", shot, " ", img.get_size())
	get_tree().quit()
