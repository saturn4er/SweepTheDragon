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
		elif a.begins_with("--click=") or a.begins_with("--rclick=") or a.begins_with("--hold=") or a.begins_with("--key="):
			steps.append(a.trim_prefix("--"))
		elif a.begins_with("--wait="):
			wait = float(a.trim_prefix("--wait="))
		elif a.begins_with("--window="):
			var wh := a.trim_prefix("--window=").split("x")
			get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	if shot == "":
		return
	while main._restarting:
		await get_tree().process_frame
	if seed_value != 0:
		await main.new_game(seed_value)
	for _i in 4:
		await get_tree().process_frame
	for s in steps:
		if s.begins_with("click=") or s.begins_with("rclick=") or s.begins_with("hold="):
			var kind := s.get_slice("=", 0)
			var xy := s.get_slice("=", 1).split(",")
			await _pointer(kind, Vector2(float(xy[0]), float(xy[1])))
			continue
		if s.begins_with("key="):
			await _key(s.get_slice("=", 1))
			continue
		match s:
			"hero":
				main._on_hero_pressed()
			"book":
				main._toggle_book()
			"page":
				main.book._show_page(1)
			"xray":
				main.xray = not main.xray
				main.render()
			"undo":
				main._undo()
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
	print("state hp=%d/%d xp=%d level=%d status=%d" % [main.game.player.hp, main.game.player.max_hp, main.game.player.xp, main.game.player.level, main.game.status])
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot)
	print("saved ", shot, " ", img.get_size())
	get_tree().quit()


## Synthesises a pointer press and release at logical (390x340) coordinates.
func _pointer(kind: String, logical: Vector2) -> void:
	var pos := logical * Vector2(get_window().size) / Vector2(390, 340)
	var button := MOUSE_BUTTON_RIGHT if kind == "rclick" else MOUSE_BUTTON_LEFT
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	Input.parse_input_event(motion)
	await get_tree().process_frame
	var down := InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	if kind == "hold":
		await get_tree().create_timer(0.5).timeout
	else:
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


func _key(name: String) -> void:
	var code := OS.find_keycode_from_string(name)
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
