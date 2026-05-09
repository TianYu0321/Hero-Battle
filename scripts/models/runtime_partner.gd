## res://scripts/models/runtime_partner.gd
## 模块: RuntimePartner
## 职责: 伙伴运行时状态数据模型
## 依赖: 无
## class_name: RuntimePartner

class_name RuntimePartner
extends RefCounted

var id: String = ""
var run_id: String = ""
var partner_config_id: int = 0
var position: int = 1
var recruit_turn: int = 0
var current_level: int = 1
var current_hp: int = 0
var favored_attr: int = 0
var aid_trigger_count: int = 0
var chain_trigger_count: int = 0
var buff_list: Array = []
var is_active: bool = true
var created_at: int = 0
var updated_at: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"run_id": run_id,
		"partner_config_id": partner_config_id,
		"position": position,
		"recruit_turn": recruit_turn,
		"current_level": current_level,
		"current_hp": current_hp,
		"favored_attr": favored_attr,
		"aid_trigger_count": aid_trigger_count,
		"chain_trigger_count": chain_trigger_count,
		"buff_list": buff_list.duplicate(),
		"is_active": is_active,
		"created_at": created_at,
		"updated_at": updated_at,
	}


static func from_dict(data: Dictionary) -> RuntimePartner:
	var partner := RuntimePartner.new()
	partner.id = data.get("id", "")
	partner.run_id = data.get("run_id", "")
	partner.partner_config_id = data.get("partner_config_id", 0)
	partner.position = data.get("position", 1)
	partner.recruit_turn = data.get("recruit_turn", 0)
	partner.current_level = data.get("current_level", 1)
	partner.current_hp = data.get("current_hp", 0)
	partner.favored_attr = data.get("favored_attr", 0)
						partner.aid_trigger_count = data.get("aid_trigger_count", 0)
	partner.chain_trigger_count = data.get("chain_trigger_count", 0)
	partner.buff_list = data.get("buff_list", []).duplicate()
	partner.is_active = data.get("is_active", true)
	partner.created_at = data.get("created_at", 0)
	partner.updated_at = data.get("updated_at", 0)
	return partner
