## res://scripts/autoload/hit_pause.gd
## 模块: HitPause
## 职责: 受击停顿/帧冻结（Engine.time_scale短暂降至0）
## 参考: Sparkle Lite hit-pause
## 依赖: 无
## 被依赖: FeedbackManager, 战斗场景

extends Node

signal pause_started(duration: float)
signal pause_ended()

var _is_paused: bool = false
var _original_time_scale: float = 1.0

func trigger(duration_ms: float) -> void:
	if _is_paused:
		return
	
	_is_paused = true
	_original_time_scale = Engine.time_scale
	
	Engine.time_scale = 0.0
	pause_started.emit(duration_ms)
	
	var timer := get_tree().create_timer(duration_ms / 1000.0, true, false, true)
	await timer.timeout
	
	Engine.time_scale = _original_time_scale
	_is_paused = false
	pause_ended.emit()

func trigger_with_decay(duration_ms: float, decay_ms: float) -> void:
	if _is_paused:
		return
	
	_is_paused = true
	_original_time_scale = Engine.time_scale
	Engine.time_scale = 0.0
	pause_started.emit(duration_ms)
	
	await get_tree().create_timer(duration_ms / 1000.0, true, false, true).timeout
	
	var steps := 5
	for i in range(steps):
		Engine.time_scale = float(i + 1) / float(steps)
		await get_tree().create_timer(decay_ms / 1000.0 / steps, true, false, true).timeout
	
	Engine.time_scale = 1.0
	_is_paused = false
	pause_ended.emit()
