class_name BattlePlaybackRecorder
extends Node

var _events: Array[Dictionary] = []
var _is_recording: bool = false
var _current_turn: int = 0

func start_recording() -> void:
	_events.clear()
	_is_recording = true
	_current_turn = 0

func stop_recording() -> void:
	_is_recording = false
	print("[PlaybackRecorder] 记录完成: %d个事件, %d个回合" % [_events.size(), get_events_by_turn().keys().size()])

func record_event(event_type: String, data: Dictionary) -> void:
	if not _is_recording:
		return
	
	# 自动跟踪当前回合
	if event_type == "turn_started":
		_current_turn = data.get("turn", 0)
	
	# 为所有事件补充 turn 字段（如果没有）
	var event_data = data.duplicate()
	if not event_data.has("turn"):
		event_data["turn"] = _current_turn
	
	_events.append({"type": event_type, "data": event_data})

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
