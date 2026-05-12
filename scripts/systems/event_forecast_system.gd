class_name EventForecastSystem
extends Node

# 透视次数（运行时，不持久化到存档，每局游戏独立）
var _foresight_charges: int = 0

# 当前层已生成的外出事件缓存（用于显示标注）
var _cached_outgoing_events: Array[Dictionary] = []

# 添加透视次数（PVP失败、伙伴技能等调用）
func add_charges(amount: int) -> void:
	_foresight_charges += amount
	print("[EventForecast] 透视次数+%d，当前=%d" % [amount, _foresight_charges])

# 获取当前透视次数
func get_charges() -> int:
	return _foresight_charges

# 消耗1次（每层推进时调用）
func consume_charge() -> void:
	if _foresight_charges > 0:
		_foresight_charges -= 1
		print("[EventForecast] 消耗1次透视，剩余=%d" % _foresight_charges)

# 判断当前是否有透视效果
func is_active() -> bool:
	return _foresight_charges > 0

# 缓存外出事件（NodePoolSystem 生成选项时调用）
func cache_outgoing_events(events: Array[Dictionary]) -> void:
	_cached_outgoing_events.clear()
	for evt in events:
		_cached_outgoing_events.append({
			"node_id": evt.get("node_id", ""),
			"event_type": _resolve_event_type(evt),
		})

# 获取指定事件的类型标注（RunMain 渲染按钮时调用）
func get_event_tag(node_id: String) -> Dictionary:
	if _foresight_charges <= 0:
		return {"text": "", "color": Color.WHITE}
	
	for evt in _cached_outgoing_events:
		if evt["node_id"] == node_id:
			match evt["event_type"]:
				"reward":
					return {"text": "[奖励]", "color": Color(0, 1, 0)}      # 绿色
				"penalty":
					return {"text": "[惩罚]", "color": Color(1, 0, 0)}      # 红色
				"elite":
					return {"text": "[精英]", "color": Color(0.5, 0, 1)}    # 紫色
				_:
					return {"text": "", "color": Color.WHITE}
	
	return {"text": "", "color": Color.WHITE}

# 内部：解析事件类型（从事件配置或 pool_type 判断）
func _resolve_event_type(event_data: Dictionary) -> String:
	# 优先使用预生成的 pool_type
	var pool_type: String = event_data.get("pool_type", "")
	if not pool_type.is_empty():
		return pool_type
	
	# fallback：按事件池概率判断
	return "unknown"
