class_name BattlePlaybackRecorder
extends Node

var _events: Array[Dictionary] = []
var _is_recording: bool = false

func start_recording() -> void:
	_events.clear()
	_is_recording = true

func stop_recording() -> void:
	_is_recording = false
	print("[PlaybackRecorder] 记录完成: %d个事件" % _events.size())

func record_event(event_type: String, data: Dictionary) -> void:
	if not _is_recording:
		return
	_events.append({"type": event_type, "data": data})

func get_events() -> Array[Dictionary]:
	return _events.duplicate()

func get_events_by_turn() -> Dictionary:
	var result: Dictionary = {}
	for evt in _events:
		var turn: int = evt["data"].get("turn", 0)
		if not result.has(turn):
			result[turn] = []
		result[turn].append(evt)
	return result
