class_name Hud
extends Node2D
## Bottom bar: Jorge, hearts, xp gems, the book button and the death message.

signal hero_pressed
signal book_pressed

const HEIGHT := 41
const HEARTS_X := 88
const HEART_STEP := 13
const HEART_GROUP_GAP := 4
const GEM_STEP := 8
const HERO_RECT := Rect2(52, 6, 30, 29)
const BOOK_RECT := Rect2(352, 4, 34, 34)

enum Mood { IDLE, EMPOWERED, LOW, DEAD }

var hero_bg: Sprite2D
var hero: Sprite2D
var hearts: Array[Sprite2D] = []
var gems: Array[Sprite2D] = []
var excess: Sprite2D
var book_bg: Sprite2D
var book_icon: Sprite2D
var death_label: Label
var restart_label: Label
var hero_button_enabled := false

var _mood := Mood.IDLE
var _mood_tween: Tween
var _temp_tween: Tween
var _spin := false
var _clock := 0.0
var _book_read := false


func _ready() -> void:
	add_child(UiKit.sprite(SpriteDb.ui("hud_panel"), Vector2.ZERO, false))
	var jorge := UiKit.label("Jorge", 16, UiKit.COL_TEXT)
	jorge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiKit.place(jorge, Vector2(26, 21), 48, 16)
	add_child(jorge)
	hero_bg = UiKit.sprite(SpriteDb.ui("hero_button_off"), HERO_RECT.position, false)
	add_child(hero_bg)
	hero = UiKit.sprite(SpriteDb.sprite("hero"), HERO_RECT.get_center() + Vector2(0, -1))
	hero.scale = Vector2(1.5, 1.5)
	add_child(hero)
	for i in Player.MAX_HP:
		var h := UiKit.sprite(SpriteDb.ui("heart_blank"), Vector2(HEARTS_X + _heart_offset(i - 1), 12))
		h.visible = i > 0
		add_child(h)
		hearts.append(h)
	for i in 25:
		var g := UiKit.sprite(SpriteDb.ui("xp_empty"), Vector2(HEARTS_X + _gem_offset(i, 25), 27 if i % 2 == 1 else 33))
		g.visible = false
		add_child(g)
		gems.append(g)
	excess = UiKit.sprite(SpriteDb.ui("xp_excess"), Vector2.ZERO)
	excess.visible = false
	add_child(excess)
	book_bg = UiKit.sprite(SpriteDb.ui("book_button"), BOOK_RECT.get_center())
	add_child(book_bg)
	book_icon = UiKit.sprite(SpriteDb.sprite("book"), BOOK_RECT.get_center())
	book_icon.scale = Vector2(1.5, 1.5)
	add_child(book_icon)
	death_label = UiKit.label("", 16, UiKit.COL_TEXT)
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiKit.place(death_label, Vector2(HEARTS_X + 100, 13), 200, 16)
	death_label.visible = false
	add_child(death_label)
	restart_label = UiKit.label("< restart", 16, UiKit.COL_ORANGE)
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiKit.place(restart_label, Vector2(HEARTS_X + 100, 29), 200, 16)
	restart_label.visible = false
	add_child(restart_label)


static func _heart_offset(k: int) -> float:
	return k * HEART_STEP + HEART_GROUP_GAP * floori(k / 5.0)


static func _gem_offset(i: int, total: int) -> float:
	var gaps := floori(i / 5.0) if total > 5 else 0
	return i * GEM_STEP + gaps * GEM_STEP


func render(game: Game) -> void:
	var p := game.player
	var playing := game.status == Game.Status.PLAYING
	hero_button_enabled = game.can_level_up() or game.status == Game.Status.DEAD
	hero_bg.texture = SpriteDb.ui("hero_button_on" if hero_button_enabled else "hero_button_off")
	_book_read = Settings.nomicon_read

	for i in hearts.size():
		var h := hearts[i]
		h.visible = i > 0 and playing
		if i < p.hp:
			h.texture = SpriteDb.ui("heart_full")
		elif i < p.max_hp:
			h.texture = SpriteDb.ui("heart_empty")
		elif i == p.max_hp and Player.is_half_heart_level(p.level) and p.max_hp < Player.MAX_HP:
			h.texture = SpriteDb.ui("heart_half")
		else:
			h.texture = SpriteDb.ui("heart_blank")

	var total := Player.xp_to_next(p.level)
	var shown := mini(p.xp, total)
	for i in gems.size():
		var g := gems[i]
		g.visible = playing and i < total
		g.position = Vector2(HEARTS_X + _gem_offset(i, total), 27 if i % 2 == 1 else 33)
		g.texture = SpriteDb.ui("xp_full" if i < shown else "xp_empty")
		if not _spin:
			g.rotation = 0.0
	excess.visible = playing and p.xp > total
	excess.position = Vector2(HEARTS_X + _gem_offset(total - 1, total) + 12, 30)
	_spin = playing and p.xp >= total

	death_label.visible = game.status == Game.Status.DEAD
	restart_label.visible = game.status == Game.Status.DEAD
	if game.status == Game.Status.DEAD:
		death_label.text = game.death_message()

	if game.status == Game.Status.DEAD:
		set_mood(Mood.DEAD)
	elif game.can_level_up():
		set_mood(Mood.EMPOWERED)
	elif p.hp == 1:
		set_mood(Mood.LOW)
	else:
		set_mood(Mood.IDLE)


func _process(delta: float) -> void:
	_clock += delta
	if _spin:
		for g in gems:
			if g.visible and g.texture == SpriteDb.ui("xp_full"):
				g.rotation = _clock * 6.0
	if not _book_read:
		book_icon.position.y = BOOK_RECT.get_center().y - absf(sin(_clock * 5.0)) * 4.0
	else:
		book_icon.position.y = BOOK_RECT.get_center().y


func set_mood(m: Mood) -> void:
	if m == _mood:
		return
	_mood = m
	if _mood_tween != null:
		_mood_tween.kill()
	hero.rotation = 0.0
	hero.modulate = Color.WHITE
	hero.texture = SpriteDb.sprite("hero")
	hero.position = HERO_RECT.get_center() + Vector2(0, -1)
	match m:
		Mood.EMPOWERED:
			hero.texture = SpriteDb.sprite("hero_alt")
			_mood_tween = create_tween().set_loops()
			_mood_tween.tween_property(hero, "modulate", Color(1.3, 1.2, 0.8), 0.35)
			_mood_tween.tween_property(hero, "modulate", Color.WHITE, 0.35)
		Mood.LOW:
			_mood_tween = create_tween().set_loops()
			_mood_tween.tween_property(hero, "modulate", Color(1.0, 0.55, 0.55), 0.5)
			_mood_tween.tween_property(hero, "modulate", Color.WHITE, 0.5)
		Mood.DEAD:
			hero.rotation = PI * 0.5
			hero.modulate = Color(0.6, 0.6, 0.65)


func play_stab() -> void:
	_temp(func(tw: Tween) -> void:
		tw.tween_property(hero, "position:x", HERO_RECT.get_center().x + 4, 0.06)
		tw.tween_property(hero, "position:x", HERO_RECT.get_center().x, 0.12))


func play_level_up() -> void:
	_temp(func(tw: Tween) -> void:
		tw.tween_property(hero, "scale", Vector2(2.1, 2.1), 0.15)
		tw.tween_property(hero, "scale", Vector2(1.5, 1.5), 0.25))
	for h in hearts:
		if h.visible:
			var t := create_tween()
			t.tween_property(h, "scale", Vector2(1.3, 1.3), 0.1)
			t.tween_property(h, "scale", Vector2.ONE, 0.2)


func play_tapped() -> void:
	_temp(func(tw: Tween) -> void:
		tw.tween_property(hero, "position:y", HERO_RECT.get_center().y - 6, 0.1)
		tw.tween_property(hero, "position:y", HERO_RECT.get_center().y - 1, 0.15))


func animate_hearts(old_hp: int, new_hp: int) -> void:
	var lo := mini(old_hp, new_hp)
	var hi := maxi(old_hp, new_hp)
	for i in range(lo, hi):
		if i <= 0 or i >= hearts.size():
			continue
		var h := hearts[i]
		var t := create_tween()
		if new_hp > old_hp:
			h.scale = Vector2(0.2, 0.2)
			t.tween_property(h, "scale", Vector2(1.25, 1.25), 0.12)
			t.tween_property(h, "scale", Vector2.ONE, 0.12)
		else:
			t.tween_property(h, "position:x", h.position.x + 2, 0.04)
			t.tween_property(h, "position:x", h.position.x - 2, 0.04)
			t.tween_property(h, "position:x", h.position.x, 0.04)


func animate_gems(old_xp: int, new_xp: int) -> void:
	for i in range(mini(old_xp, new_xp), maxi(old_xp, new_xp)):
		if i >= gems.size():
			break
		var g := gems[i]
		var t := create_tween()
		g.scale = Vector2(0.3, 0.3) if new_xp > old_xp else Vector2.ONE
		t.tween_property(g, "scale", Vector2(1.4, 1.4), 0.1)
		t.tween_property(g, "scale", Vector2.ONE, 0.15)


func _temp(build: Callable) -> void:
	if _temp_tween != null:
		_temp_tween.kill()
	hero.scale = Vector2(1.5, 1.5)
	hero.position = HERO_RECT.get_center() + Vector2(0, -1)
	_temp_tween = create_tween()
	build.call(_temp_tween)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var local := to_local(mb.position)
	if HERO_RECT.has_point(local):
		hero_pressed.emit()
		get_viewport().set_input_as_handled()
	elif BOOK_RECT.has_point(local):
		book_pressed.emit()
		get_viewport().set_input_as_handled()
