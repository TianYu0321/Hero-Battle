## res://scripts/systems/shop_system.gd
## 模块: ShopSystem
## 职责: 商店系统：生成商品列表、处理购买、价格递增
## 依赖: CharacterManager, ConfigManager
## class_name: ShopSystem

class_name ShopSystem
extends Node

var _character_manager: CharacterManager = null
var _shop_purchase_counts: Dictionary = {}  # {shop_item_id: purchase_count}


func initialize(cm: CharacterManager) -> void:
	_character_manager = cm


func generate_shop_inventory(turn: int, current_gold: int) -> Array[Dictionary]:
	var inventory: Array[Dictionary] = []
	var hero: RuntimeHero = _character_manager.get_hero()
	var partners: Array[RuntimePartner] = _character_manager.get_partners()

	# 主角升级选项（5属性各一个）
	for attr in range(1, 6):
		var item_id: String = "hero_attr_%d" % attr
		var base_cost: int = _get_item_base_cost(item_id)
		var cost: int = _calculate_current_cost(item_id, base_cost)
		inventory.append({
			"item_id": item_id,
			"item_type": "hero_upgrade",
			"name": _attr_name(attr) + "强化",
			"price": cost,
			"effect_desc": "主角%s+3" % _attr_name(attr),
			"can_afford": current_gold >= cost,
			"target_id": "hero",
			"target_attr": attr,
		})

	# 伙伴升级选项（最多显示3个活跃伙伴）
	var shown: int = 0
	for p in partners:
		if not p.is_active or shown >= 3:
			continue
		var item_id: String = "partner_%d" % p.partner_config_id
		var base_cost: int = _get_item_base_cost(item_id)
		var cost: int = _calculate_current_cost(item_id, base_cost)
		var config: Dictionary = ConfigManager.get_partner_config(str(p.partner_config_id))
		var p_name: String = config.get("name", "伙伴")
		var max_level_reached: bool = p.current_level >= 3
		inventory.append({
			"item_id": item_id,
			"item_type": "partner_upgrade",
			"name": p_name + "升级",
			"price": cost if not max_level_reached else 999999,
			"effect_desc": "等级%d→%d" % [p.current_level, mini(3, p.current_level + 1)] if not max_level_reached else "已达最高等级",
			"can_afford": current_gold >= cost and not max_level_reached,
			"target_id": str(p.partner_config_id),
			"target_attr": 0,
		})
		shown += 1

	return inventory


func process_purchase(item_data: Dictionary, current_gold: int) -> Dictionary:
	var result := {
		"success": false,
		"new_gold": current_gold,
		"applied_effects": [],
		"error": null,
	}
	var price: int = item_data.get("price", 0)
	if current_gold < price:
		result["error"] = "金币不足"
		return result

	var item_type: String = item_data.get("item_type", "")
	match item_type:
		"hero_upgrade":
			var attr: int = item_data.get("target_attr", 0)
			if attr >= 1 and attr <= 5:
				_character_manager.modify_hero_stats({attr: 3})
				result["applied_effects"].append({"type": "hero_attr", "attr": attr, "delta": 3})
		"partner_upgrade":
			var target_id: String = item_data.get("target_id", "")
			var pid: int = int(target_id) if target_id.is_valid_int() else 0
			if _character_manager.upgrade_partner(pid):
				result["applied_effects"].append({"type": "partner_level", "partner_id": pid, "delta": 1})
			else:
				result["error"] = "升级失败（已达最高等级或伙伴不存在）"
				return result
		_:
			result["error"] = "未知商品类型"
			return result

	# 记录购买次数用于价格递增
	var item_id: String = item_data.get("item_id", "")
	_shop_purchase_counts[item_id] = _shop_purchase_counts.get(item_id, 0) + 1

	result["success"] = true
	result["new_gold"] = current_gold - price
	return result


func reset() -> void:
	_shop_purchase_counts.clear()


# --- 私有方法 ---

func _get_item_base_cost(item_id: String) -> int:
	# 从配置表读取基础价格，简化为默认值
	if item_id.begins_with("hero_attr_"):
		return 20
	elif item_id.begins_with("partner_"):
		return 30
	return 20


func _calculate_current_cost(item_id: String, base_cost: int) -> int:
	var count: int = _shop_purchase_counts.get(item_id, 0)
	# 线性递增：每次购买+10
	return base_cost + count * 10


func _attr_name(attr_type: int) -> String:
	match attr_type:
		1: return "体魄"
		2: return "力量"
		3: return "敏捷"
		4: return "技巧"
		5: return "精神"
		_: return "未知"
