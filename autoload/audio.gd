extends Node
## Plays named sound events with random variants, and one looping music track.

const SFX_DIR := "res://assets/audio/sfx/"
const INDEX := SFX_DIR + "index.json"
const MUSIC := "res://assets/audio/music/theme.ogg"
const VOICES := 8

var _variants := {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _music_wanted := false


func _ready() -> void:
	for _i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	if ResourceLoader.exists(MUSIC):
		_music.stream = load(MUSIC)
		if _music.stream is AudioStreamOggVorbis:
			_music.stream.loop = true
	_load_index()
	Settings.changed.connect(_apply_music_setting)


func _load_index() -> void:
	if not FileAccess.file_exists(INDEX):
		return
	var text := FileAccess.get_file_as_string(INDEX)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for event in parsed:
		var streams: Array[AudioStream] = []
		for file in parsed[event]:
			var path := SFX_DIR + str(file)
			if ResourceLoader.exists(path):
				streams.append(load(path))
		if not streams.is_empty():
			_variants[event] = streams


## Plays one random variant of the event. Unknown events are ignored so the game never breaks
## because a sound is missing.
func play(event: String, volume_db := -6.0) -> void:
	if not Settings.sound_on or not _variants.has(event):
		return
	var streams: Array = _variants[event]
	var p := _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = streams[randi() % streams.size()]
	p.volume_db = volume_db
	p.play()


func start_music() -> void:
	_music_wanted = true
	_apply_music_setting()


func stop_music() -> void:
	_music_wanted = false
	_music.stop()


func _apply_music_setting() -> void:
	if _music.stream == null:
		return
	if _music_wanted and Settings.music_on:
		if not _music.playing:
			_music.volume_db = -8.0
			_music.play()
	else:
		_music.stop()
