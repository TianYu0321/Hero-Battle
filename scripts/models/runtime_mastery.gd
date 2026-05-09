## res://scripts/models/runtime_mastery.gd
## 模块: RuntimeMastery
## 职责: 属性熟练度运行时状态数据模型
## 依赖: 无
## class_name: RuntimeMastery

class_name RuntimeMastery
extends RefCounted

var id: String = ""
var run_id: String = ""
var attr_type: int = 1
var stage: int = 1
var training_count: int = 0
var training_bonus: int = 0
var is_marginal_decrease: bool = false
var created_at: int = 0
var updated_at: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"run_id": run_id,
		"attr_type": attr_type,
		"stage": stage,
		"training_count": training_count,
		"training_bonus": training_bonus,
		"is_marginal_decrease": is_marginal_decrease,
		"created_at": created_at,
		"updated_at": updated_at,
	}


static func from_dict(data: Dictionary) -> RuntimeMastery:
	var mastery := RuntimeMastery.new()
	mastery.id = data.get("id", "")
	mastery.run_id = data.get("run_id", "")
	mastery.attr_type = data.get("attr_type", 1)
	mastery.stage = data.get("stage", 1)
	mastery.training_count = data.get("training_count", 0)
	mastery.training_bonus = data.get("training_bonus", 0)
	mastery.is_marginal_decrease = data.get("is_marginal_decrease", false)
	mastery.created_at = data.get("created_at", 0)
	mastery.updated_at = data.get("updated_at", 0)
	return mastery
