class_name WinScreen
extends Node2D
## Shown after taking the crown: the slain dragon, a verse, score, time and stamps.

signal dismissed

const VERSE_DEFAULT: Array[String] = [
	"The lair falls silent, the fire burns low,",
	"Jorge counts his scars by the ember glow.",
	"No cheer reaches him through the stone,",
	"the hunt is over, and he is alone.",
]
const VERSE_CLEARED: Array[String] = [
	"Nothing stirs in halls he has bled dry,",
	"the last echo fades beneath the sky.",
	"Jorge lowers his blade and asks the dust:",
	"am I so different from those I crushed?",
]

var _lines: Array[Label] = []
var _stamps: Node2D
var _dragon: Sprite2D
var _hero: Sprite2D
var _score: Label
var _time: Label
var _hint: Label
var _clock := 0.0


func _ready() -> void:
	visible = false
	add_child(UiKit.sprite(SpriteDb.ui("win_bg"), Vector2.ZERO, false))
	var ground := UiKit.sprite(SpriteDb.ui("px"), Vector2(0, 150), false)
	ground.scale = Vector2(390 / 4.0, 3.0 / 4.0)
	ground.modulate = Color("3a2f2a")
	add_child(ground)
	_dragon = UiKit.sprite(SpriteDb.sprite("dragon"), Vector2(215, 112))
	_dragon.scale = Vector2(6, 6)
	_dragon.rotation = PI * 0.5
	_dragon.modulate = Color(0.55, 0.45, 0.45)
	add_child(_dragon)
	_hero = UiKit.sprite(SpriteDb.sprite("hero"), Vector2(120, 126))
	_hero.scale = Vector2(3, 3)
	add_child(_hero)
	for i in 4:
		var l := UiKit.label("", 12, UiKit.COL_DIM)
		UiKit.place(l, Vector2(195, 178 + i * 16), 380, 12)
		add_child(l)
		_lines.append(l)
	_score = UiKit.label("", 16, UiKit.COL_TEXT)
	UiKit.place(_score, Vector2(195, 254), 380, 16)
	add_child(_score)
	_time = UiKit.label("", 16, UiKit.COL_TEXT)
	UiKit.place(_time, Vector2(195, 270), 380, 16)
	add_child(_time)
	_stamps = Node2D.new()
	add_child(_stamps)
	_hint = UiKit.label("tap to hunt again", 16, UiKit.COL_DIM)
	UiKit.place(_hint, Vector2(195, 328), 200, 16)
	add_child(_hint)


func show_result(game: Game, cleared_before: bool, max_score: int) -> void:
	var verse := VERSE_CLEARED if (cleared_before or game.stamps_this_run.has(Stamps.CLEAR)) else VERSE_DEFAULT
	for i in 4:
		_lines[i].text = verse[i]
	_score.text = "score: %d  (max: %d)" % [game.player.score, max_score]
	var secs := game.elapsed_msec() / 1000
	_time.text = "time %d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]
	for c in _stamps.get_children():
		c.queue_free()
	var n := game.stamps_this_run.size()
	var x := 195.0 - (n * 30 + (n - 1) * 5) * 0.5 + 15
	for id in game.stamps_this_run:
		var idx := Stamps.ALL.find(id)
		_stamps.add_child(UiKit.sprite(SpriteDb.ui("stamp_%d" % idx), Vector2(x, 300)))
		x += 35
	visible = true
	_clock = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_hint.modulate.a = 0.5 + 0.5 * sin(_clock * 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and _clock > 0.6:
		dismissed.emit()
		get_viewport().set_input_as_handled()
