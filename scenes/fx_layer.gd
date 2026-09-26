class_name FxLayer
extends Node2D
## Short-lived visual effects over the board: flashes, bursts, rings and floating text.


## Maps a board cell to its on-screen top-left corner; the board view sets this.
var origin: Callable = func(p: Vector2i) -> Vector2: return Vector2(p) * TileView.SIZE


func tile_center(p: Vector2i) -> Vector2:
	return origin.call(p) + TileView.CENTER


## Full-tile colour flash that fades out.
func flash(p: Vector2i, color: Color, duration := 0.25) -> void:
	var s := UiKit.sprite(SpriteDb.ui("px"), origin.call(p), false)
	s.scale = Vector2(TileView.SIZE / 4.0, TileView.SIZE / 4.0)
	s.modulate = color
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "modulate:a", 0.0, duration)
	tw.tween_callback(s.queue_free)


## Small squares flying outward from the tile centre.
func burst(p: Vector2i, color: Color, count := 8, distance := 14.0, duration := 0.35) -> void:
	var c := tile_center(p)
	for i in count:
		var s := UiKit.sprite(SpriteDb.ui("px"), c)
		s.scale = Vector2(0.5, 0.5) if i % 2 == 0 else Vector2(0.75, 0.75)
		s.modulate = color
		add_child(s)
		var ang := TAU * i / count + randf() * 0.4
		var target := c + Vector2.from_angle(ang) * (distance * (0.7 + randf() * 0.6))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(s, "position", target, duration).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, duration).set_delay(duration * 0.4)
		tw.chain().tween_callback(s.queue_free)


## Expanding ring, used for reveals and disarms.
func ripple(p: Vector2i, color: Color, duration := 0.3) -> void:
	var s := UiKit.sprite(SpriteDb.ui("ring_1"), tile_center(p))
	s.modulate = color
	s.scale = Vector2(0.3, 0.3)
	add_child(s)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2(1.3, 1.3), duration)
	tw.tween_property(s, "modulate:a", 0.0, duration)
	tw.chain().tween_callback(s.queue_free)


## A sprite that pops up and drifts, e.g. the gnome leaving a tile.
func puff(p: Vector2i, tex: Texture2D, to: Vector2i) -> void:
	var s := UiKit.sprite(tex, tile_center(p) + Vector2(0, -5))
	add_child(s)
	var mid := (tile_center(p) + tile_center(to)) * 0.5 + Vector2(0, -24)
	var tw := create_tween()
	tw.tween_property(s, "position", mid, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position", tile_center(to) + Vector2(0, -5), 0.18).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)
	burst(p, Color(0.8, 0.8, 0.8), 6, 10.0, 0.3)


## Floating text such as damage or xp gained.
func float_text(p: Vector2i, text: String, color: Color) -> void:
	var l := UiKit.label(text, 12, color, 2)
	UiKit.place(l, tile_center(p) + Vector2(0, -6), 40, 12)
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 14, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)
