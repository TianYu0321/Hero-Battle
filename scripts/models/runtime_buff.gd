## res://scripts/models/runtime_buff.gd
## 模块: RuntimeBuff
## 职责: 临时Buff/Debuff数据模型
## 依赖: 无
## class_name: RuntimeBuff

class_name RuntimeBuff
extends RefCounted

var id: String = ""
var run_id: String = ""
var target_type: int = 1
var target_id: String = ""
var buff_name: String = ""
var buff_effect: int = 1
var effect_value: float = 0.0
var duration_total: int = 0
var duration_remaining: int = 0
var source: String = ""
var created_at: int = 0
var updated_at: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"run_id": run_id,
		"target_type": target_type,
		"target_id": target_id,
		"buff_name": buff_name,
		"buff_effect": buff_effect,
		"effect_value": effect_value,
		"duration_total": duration_total,
		"duration_remaining": duration_remaining,
		"source": source,
		"created_at": created_at,
		"updated_at": updated_at,
	}


static func from_dict(data: Dictionary) -> RuntimeBuff:
	var buff := RuntimeBuff.new()
	buff.id = data.get("id", "")
	buff.run_id = data.get("run_id", "")
	buff.target_type = data.get("target_type", 1)
	buff.target_id = data.get("target_id", "")
	buff.buff_name = data.get("buff_name", "")
	buff.buff_effect = data.get("buff_effect", 1)
	buff.effect_value = data.get("effect_value", 0.0)
	buff.duration_total = data.get("duration_total", 0)
	buff.duration_remaining = data.get("duration_remaining", 0)
	buff.source = data.get("source", "")
	buff.created_at = data.get("created_at", 0)
	buff.updated_at = data.get("updated_at", 0)
	return buff
