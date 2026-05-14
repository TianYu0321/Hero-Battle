## res://scripts/data/shadow_data.gd
## 模块: ShadowData
## 职责: PVP异步镜像的影子数据结构
## 依赖: 无
## class_name: ShadowData

class_name ShadowData
extends RefCounted

var user_id: String = ""
var floor: int = 0
var hero_config: Dictionary = {}
var partner_configs: Array = []
var combat_style_tags: Array[String] = []
var win_rate: float = 0.0
var timestamp: int = 0

func to_dict() -> Dictionary:
	return {
		"user_id": user_id,
		"floor": floor,
		"hero_config": hero_config.duplicate(),
		"partner_configs": partner_configs.duplicate(),
		"combat_style_tags": combat_style_tags.duplicate(),
		"win_rate": win_rate,
		"timestamp": timestamp,
	}

static func from_dict(data: Dictionary) -> ShadowData:
	var shadow := ShadowData.new()
	shadow.user_id = data.get("user_id", "")
	shadow.floor = int(data.get("floor", 0))
	shadow.hero_config = data.get("hero_config", {}).duplicate()
	shadow.partner_configs = data.get("partner_configs", []).duplicate()
	var tags: Array = data.get("combat_style_tags", [])
	for tag in tags:
		if tag is String:
			shadow.combat_style_tags.append(tag)
	shadow.win_rate = float(data.get("win_rate", 0.0))
	shadow.timestamp = int(data.get("timestamp", 0))
	return shadow
