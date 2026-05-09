## res://scripts/models/runtime_training_log.gd
## 模块: RuntimeTrainingLog
## 职责: 锻炼记录日志数据模型
## 依赖: 无
## class_name: RuntimeTrainingLog

class_name RuntimeTrainingLog
extends RefCounted

var id: String = ""
var run_id: String = ""
var turn: int = 1
var attr_type: int = 1
var base_gain: int = 0
var mastery_bonus: int = 0
var partner_bonus: int = 0
var marginal_decrease_applied: bool = false
var final_gain: int = 0
var partner_support_list: Array = []
var created_at: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"run_id": run_id,
		"turn": turn,
		"attr_type": attr_type,
		"base_gain": base_gain,
		"mastery_bonus": mastery_bonus,
		"partner_bonus": partner_bonus,
		"marginal_decrease_applied": marginal_decrease_applied,
		"final_gain": final_gain,
		"partner_support_list": partner_support_list.duplicate(),
		"created_at": created_at,
	}


static func from_dict(data: Dictionary) -> RuntimeTrainingLog:
	var log := RuntimeTrainingLog.new()
	log.id = data.get("id", "")
	log.run_id = data.get("run_id", "")
	log.turn = data.get("turn", 1)
	log.attr_type = data.get("attr_type", 1)
	log.base_gain = data.get("base_gain", 0)
	log.mastery_bonus = data.get("mastery_bonus", 0)
	log.partner_bonus = data.get("partner_bonus", 0)
	log.marginal_decrease_applied = data.get("marginal_decrease_applied", false)
	log.final_gain = data.get("final_gain", 0)
	log.partner_support_list = data.get("partner_support_list", []).duplicate()
	log.created_at = data.get("created_at", 0)
	return log
