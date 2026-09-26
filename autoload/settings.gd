extends Node
## Persistent player preferences and collected stamps, stored in user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

var sound_on := true
var music_on := true
var nomicon_read := false
var stamps: Array[String] = []

var _cfg := ConfigFile.new()


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	if _cfg.load(PATH) != OK:
		_cfg = ConfigFile.new()
	sound_on = _cfg.get_value("audio", "sound", true)
	music_on = _cfg.get_value("audio", "music", true)
	nomicon_read = _cfg.get_value("progress", "nomicon_read", false)
	stamps = []
	for s in _cfg.get_value("progress", "stamps", []):
		stamps.append(str(s))


func save_settings() -> void:
	_cfg.set_value("audio", "sound", sound_on)
	_cfg.set_value("audio", "music", music_on)
	_cfg.set_value("progress", "nomicon_read", nomicon_read)
	_cfg.set_value("progress", "stamps", stamps)
	_cfg.save(PATH)
	changed.emit()


func set_sound(on: bool) -> void:
	sound_on = on
	save_settings()


func set_music(on: bool) -> void:
	music_on = on
	save_settings()


func mark_nomicon_read() -> void:
	if nomicon_read:
		return
	nomicon_read = true
	save_settings()


func has_stamp(id: String) -> bool:
	return stamps.has(id)


func add_stamps(ids: Array[String]) -> void:
	var added := false
	for id in ids:
		if not stamps.has(id):
			stamps.append(id)
			added = true
	if added:
		save_settings()
