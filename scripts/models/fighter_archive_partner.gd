## res://scripts/models/fighter_archive_partner.gd
## 模块: FighterArchivePartner
## 职责: 档案伙伴快照数据模型
## 依赖: 无
## class_name: FighterArchivePartner

class_name FighterArchivePartner
extends RefCounted

var id: String = ""
var archive_id: String = ""
var partner_config_id: int = 0
var partner_name: String = ""
var position: int = 1
var final_level: int = 1
var final_vit: int = 0
var final_str: int = 0
var final_agi: int = 0
var final_tec: int = 0
var final_mnd: int = 0
var aid_trigger_count: int = 0
var chain_trigger_count: int = 0
var sort_order: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"archive_id": archive_id,
		"partner_config_id": partner_config_id,
		"partner_name": partner_name,
		"position": position,
		"final_level": final_level,
		"final_vit": final_vit,
		"final_str": final_str,
		"final_agi": final_agi,
		"final_tec": final_tec,
		"final_mnd": final_mnd,
		"aid_trigger_count": aid_trigger_count,
		"chain_trigger_count": chain_trigger_count,
		"sort_order": sort_order,
	}


static func from_dict(data: Dictionary) -> FighterArchivePartner:
	var p := FighterArchivePartner.new()
	p.id = data.get("id", "")
	p.archive_id = data.get("archive_id", "")
	p.partner_config_id = data.get("partner_config_id", 0)
	p.partner_name = data.get("partner_name", "")
	p.position = data.get("position", 1)
	p.final_level = data.get("final_level", 1)
	p.final_vit = data.get("final_vit", 0)
	p.final_str = data.get("final_str", 0)
	p.final_agi = data.get("final_agi", 0)
	p.final_tec = data.get("final_tec", 0)
	p.final_mnd = data.get("final_mnd", 0)
	p.aid_trigger_count = data.get("aid_trigger_count", 0)
	p.chain_trigger_count = data.get("chain_trigger_count", 0)
	p.sort_order = data.get("sort_order", 0)
	return p


static func from_runtime_partner(partner: RuntimePartner) -> FighterArchivePartner:
	var p := FighterArchivePartner.new()
	p.partner_config_id = partner.partner_config_id
	p.position = partner.position
	p.final_level = partner.current_level
	p.final_vit = partner.current_vit
	p.final_str = partner.current_str
	p.final_agi = partner.current_agi
	p.final_tec = partner.current_tec
	p.final_mnd = partner.current_mnd
	p.aid_trigger_count = partner.aid_trigger_count
	p.chain_trigger_count = partner.chain_trigger_count
	return p
