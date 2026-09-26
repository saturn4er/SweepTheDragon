class_name Rng
extends RefCounted
## Seeded random source so a board and a run can be reproduced.

var _r := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_r.seed = seed_value


func get_state() -> int:
	return _r.state


func set_state(state: int) -> void:
	_r.state = state


func randi_range(from: int, to: int) -> int:
	return _r.randi_range(from, to)


func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _r.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
