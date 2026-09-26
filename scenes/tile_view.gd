class_name TileView
extends Node2D
## Draws one board tile from a Tile and the surrounding context.

const SIZE := 30
const CENTER := Vector2(15, 15)

var bg: Sprite2D
var decal: Sprite2D
var icon: Sprite2D
var number: Label
var level_badge: Label
var xp_star: Sprite2D
var xp_badge: Label
var mark_icon: Sprite2D
var mark_label: Label
var startled: Label

var variant := 0
var _hover := false


func _ready() -> void:
	bg = UiKit.sprite(SpriteDb.ui("tile_hidden_0"), Vector2.ZERO, false)
	add_child(bg)
	decal = UiKit.sprite(null, CENTER)
	add_child(decal)
	icon = UiKit.sprite(null, CENTER)
	add_child(icon)
	number = UiKit.label("", 16, UiKit.COL_TEXT, 2)
	UiKit.place(number, CENTER + Vector2(0, 0), 30, 16)
	add_child(number)
	level_badge = UiKit.label("", 12, UiKit.COL_ORANGE, 2)
	UiKit.place(level_badge, Vector2(16, 22), 30, 12)
	add_child(level_badge)
	xp_star = UiKit.sprite(SpriteDb.ui("xp_star"), Vector2(11, 22))
	add_child(xp_star)
	xp_badge = UiKit.label("", 12, UiKit.COL_YELLOW, 2)
	UiKit.place(xp_badge, Vector2(19, 22), 20, 12)
	add_child(xp_badge)
	mark_icon = UiKit.sprite(null, CENTER)
	add_child(mark_icon)
	mark_label = UiKit.label("", 16, UiKit.COL_YELLOW, 2)
	UiKit.place(mark_label, CENTER, 30, 16)
	add_child(mark_label)
	startled = UiKit.label("!", 12, UiKit.COL_YELLOW, 2)
	UiKit.place(startled, Vector2(23, 6), 12, 12)
	add_child(startled)


## ctx keys: show_all (bool), killer (Tile or null), walls/chests (Array[Vector2i]), frame (0/1),
## board (Board), rat_king (Tile or null)
func render(t: Tile, ctx: Dictionary) -> void:
	var board: Board = ctx.board
	var show_all: bool = ctx.show_all
	var frame: int = ctx.frame
	var revealed := t.revealed or show_all

	var style := 0
	if t.is_empty() and t.revealed:
		style = 1
	if show_all:
		style = 1
	if style == 0 and t.xp > 0 and t.revealed and (not t.is_monster or t.defeated):
		style = 2
	if show_all and ctx.killer == t:
		style = 0
	match style:
		0:
			bg.texture = SpriteDb.ui("tile_hidden_%d" % variant)
		1:
			bg.texture = SpriteDb.ui("tile_floor")
		2:
			bg.texture = SpriteDb.ui("tile_loot")
	if (t.kind == Kind.DRAGON or t.kind == Kind.CROWN) and revealed:
		bg.texture = SpriteDb.ui("tile_lair")

	decal.visible = false
	icon.visible = false
	icon.modulate = Color.WHITE
	icon.flip_h = false
	icon.rotation = 0.0
	icon.scale = Vector2.ONE
	number.visible = false
	level_badge.visible = false
	xp_star.visible = false
	xp_badge.visible = false
	startled.visible = false

	if revealed:
		if t.is_empty():
			if ctx.walls.has(t.pos):
				decal.texture = SpriteDb.ui("floor_rubble")
				decal.visible = true
			elif ctx.chests.has(t.pos):
				decal.texture = SpriteDb.ui("floor_chest_mark")
				decal.visible = true
			if board.gazer_near(t.pos):
				number.text = "?"
				number.visible = true
			else:
				var n := board.attack_number(t.pos)
				if n > 0:
					number.text = str(n)
					number.label_settings.font_size = 12 if n >= 100 else 16
					number.visible = true
		elif t.is_monster:
			_render_monster(t, ctx, frame)
		elif t.kind == Kind.CROWN:
			icon.texture = SpriteDb.sprite("crown")
			icon.position = CENTER + Vector2(0, -2 - (1 if frame == 1 else 0))
			icon.visible = true
		elif t.kind == Kind.TREASURE:
			icon.texture = SpriteDb.sprite(_treasure_sprite(t.xp))
			icon.position = CENTER + Vector2(0, -4)
			icon.visible = true
			_show_xp(t.xp)
		else:
			icon.texture = SpriteDb.sprite(_item_sprite(t))
			icon.position = CENTER
			icon.visible = true

	var show_mark := t.mark > 0 and not t.revealed and not show_all
	mark_icon.visible = false
	mark_label.visible = false
	if show_mark:
		_render_mark(t.mark)


func _render_monster(t: Tile, ctx: Dictionary, frame: int) -> void:
	var name := _monster_sprite(t)
	icon.texture = SpriteDb.sprite(name, frame)
	icon.flip_h = SpriteDb.flip_h(name)
	icon.position = CENTER + Vector2(0, -5)
	icon.visible = true
	if t.mimicking and not ctx.get("xray", false):
		icon.texture = SpriteDb.sprite("chest")
		icon.position = CENTER
		icon.flip_h = false
	elif t.kind == Kind.GNOME and not t.defeated:
		icon.position = CENTER
	_face(t, ctx)
	if t.defeated:
		if t.kind == Kind.MINE:
			icon.texture = SpriteDb.sprite("mine_dead")
			icon.position = CENTER
		elif t.kind == Kind.DRAGON_EGG:
			icon.modulate = Color(0.6, 0.6, 0.6)
			icon.rotation = 0.35
		else:
			icon.modulate = Color(0.55, 0.55, 0.6)
			icon.rotation = PI * 0.5
			icon.position = CENTER + Vector2(0, -2)
		if t.xp > 0:
			_show_xp(t.xp)
	elif t.kind == Kind.MINE and ctx.killer == t and ctx.show_all:
		icon.texture = SpriteDb.sprite("mine_dead")
		icon.position = CENTER
	elif t.kind == Kind.GNOME:
		pass
	elif not t.mimicking or ctx.get("xray", false):
		level_badge.text = str(t.level)
		level_badge.visible = true


## Horizontal screen coordinate of a cell; the board is transposed in portrait.
static func _sx(p: Vector2i, ctx: Dictionary) -> int:
	return p.y if ctx.get("portrait", false) else p.x


func _face(t: Tile, ctx: Dictionary) -> void:
	var board: Board = ctx.board
	match t.kind:
		Kind.MINOTAUR:
			if t.minotaur_chest.x >= 0:
				var chest := board.at_pos(t.minotaur_chest)
				var flip := _sx(t.minotaur_chest, ctx) < _sx(t.pos, ctx)
				icon.flip_h = flip != SpriteDb.flip_h("minotaur")
				if chest.kind != Kind.CHEST and not t.defeated:
					startled.visible = true
					icon.flip_h = not icon.flip_h
		Kind.GARGOYLE:
			for g in board.within_inclusive(t.pos, 1.0):
				if g.kind == Kind.GARGOYLE and g.role == t.role:
					if _sx(g.pos, ctx) != _sx(t.pos, ctx):
						icon.flip_h = (_sx(g.pos, ctx) < _sx(t.pos, ctx)) != SpriteDb.flip_h("gargoyle")
		Kind.RAT:
			var king: Tile = ctx.rat_king
			if king != null and _sx(king.pos, ctx) != _sx(t.pos, ctx):
				icon.flip_h = (_sx(king.pos, ctx) < _sx(t.pos, ctx)) != SpriteDb.flip_h("rat")
		Kind.GIANT:
			if t.role == "juliet":
				icon.flip_h = not icon.flip_h


func _show_xp(xp: int) -> void:
	xp_star.visible = true
	xp_badge.text = str(xp)
	xp_badge.visible = true
	var wide := xp >= 10
	xp_star.position = Vector2(8 if wide else 11, 22)
	UiKit.place(xp_badge, Vector2(19, 22), 20, 12)


func _render_mark(mark: int) -> void:
	match mark:
		13:
			mark_icon.texture = SpriteDb.ui("mark_mine")
			mark_icon.visible = true
		14:
			mark_icon.texture = SpriteDb.ui("mark_question")
			mark_icon.visible = true
		15:
			mark_icon.texture = SpriteDb.ui("mark_loot")
			mark_icon.visible = true
		_:
			mark_label.text = str(mark)
			mark_label.visible = true


static func _monster_sprite(t: Tile) -> String:
	if t.kind == Kind.GIANT:
		return "giant_romeo" if t.role == "romeo" else "giant_juliet"
	return _monster_sprite_for_kind(t.kind)


## Sprite name for a kind as shown in the book, where there is no tile to consult.
static func _monster_sprite_for_kind(kind: int) -> String:
	match kind:
		Kind.GIANT:
			return "giant_romeo"
		Kind.GUARD:
			return "guardian"
		Kind.SPELL_ORB:
			return "scroll_orb" if SpriteDb.has("scroll_orb") else "scroll_disarm"
		Kind.SPELL_DISARM:
			return "scroll_disarm"
		Kind.SPELL_REVEAL_RATS:
			return "scroll_rats"
		Kind.SPELL_REVEAL_SLIMES:
			return "scroll_slimes"
	return Catalog.display_name(kind).replace(" ", "_")


static func _item_sprite(t: Tile) -> String:
	match t.kind:
		Kind.WALL:
			return "wall" if t.wall_hp >= t.wall_max_hp else "wall_cracked"
		Kind.SPELL_ORB:
			return "scroll_orb" if SpriteDb.has("scroll_orb") else "scroll_disarm"
		Kind.SPELL_REVEAL_RATS:
			return "scroll_rats"
		Kind.SPELL_REVEAL_SLIMES:
			return "scroll_slimes"
		Kind.SPELL_DISARM:
			return "scroll_disarm"
	return Catalog.display_name(t.kind).replace(" ", "_")


static func _treasure_sprite(xp: int) -> String:
	if xp >= 5:
		return "treasure_5"
	if xp >= 3:
		return "treasure_3"
	return "treasure_1"
