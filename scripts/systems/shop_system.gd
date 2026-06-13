## res://scripts/systems/shop_system.gd
## 模块: ShopSystem
## 职责: 商店系统：生成商品列表、处理购买、价格递增
## 依赖: CharacterManager, ConfigManager
## class_name: ShopSystem

class_name ShopSystem
extends Node

var _character_manager: CharacterManager = null
var _shop_purchase_counts: Dictionary = {}  # {shop_item_id: purchase_count}
var _rng: RandomNumberGenerator = null


func initialize(cm: CharacterManager) -> void:
	_character_manager = cm


func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


func generate_items(turn: int) -> Array[Dictionary]:
	return generate_shop_inventory(turn, 999999)


func generate_shop_inventory(turn: int, current_gold: int) -> Array[Dictionary]:
	var inventory: Array[Dictionary] = []
	var partners: Array[RuntimePartner] = _character_manager.get_partners()
	print("[ShopSystem] generate_shop_inventory 被调用: turn=%d, gold=%d, partners.count=%d" % [turn, current_gold, partners.size()])
	for p in partners:
		print("[ShopSystem] 伙伴: config_id=%d, instance_id=%d, is_active=%s, level=%d" % [p.partner_config_id, p.instance_id, str(p.is_active), p.current_level])

	# 1. 主角升级商品（从配置表读取）
	var shop_cfg: Dictionary = ConfigManager.get_shop_price_config()
	for item_id in shop_cfg:
		var cfg: Dictionary = shop_cfg[item_id]
		var item_type: String = cfg.get("item_type", "")
		if item_type == "partner_upgrade":
			continue
		var min_turn: int = cfg.get("min_turn_to_appear", 1)
		var max_turn: int = cfg.get("max_turn_to_appear", 30)
		if turn < min_turn or turn > max_turn:
			continue
		var stock_limit: int = cfg.get("stock_limit", 0)
		var bought: int = _shop_purchase_counts.get(item_id, 0)
		if stock_limit > 0 and bought >= stock_limit:
			continue
		inventory.append(_make_hero_upgrade_item(cfg, current_gold))

	# 2. 伙伴升级选项（为每个活跃伙伴动态生成）
	var seen_instance_ids: Array[int] = []
	for p in partners:
		if not p.is_active:
			print("[ShopSystem] 跳过伙伴 (is_active=false): config_id=%d" % p.partner_config_id)
			continue
		if p.instance_id in seen_instance_ids:
			print("[ShopSystem] 跳过伙伴 (instance_id 重复): config_id=%d, instance_id=%d" % [p.partner_config_id, p.instance_id])
			continue
		seen_instance_ids.append(p.instance_id)
		var item_id: String = "partner_%d_%d" % [p.partner_config_id, p.instance_id]
		var base_cost: int = _get_item_base_cost("partner_%d" % p.partner_config_id)
		var cost: int = _calculate_current_cost(item_id, base_cost)
		var config: Dictionary = ConfigManager.get_partner_config(str(p.partner_config_id))
		var p_name: String = config.get("name", "伙伴")
		var max_level_reached: bool = p.current_level >= 5
		var display_price: int = cost if not max_level_reached else 999999
		inventory.append({
			"item_id": item_id,
			"item_type": "partner_upgrade",
			"name": p_name + " Lv%d→%d" % [p.current_level, mini(5, p.current_level + 1)],
			"price": display_price,
			"current_level": p.current_level,
			"effect_desc": "等级%d→%d" % [p.current_level, mini(5, p.current_level + 1)] if not max_level_reached else "已达最高等级",
			"can_afford": current_gold >= display_price and not max_level_reached,
			"target_id": str(p.instance_id),
			"target_config_id": str(p.partner_config_id),
			"target_attr": 0,
		})
		print("[ShopSystem] 添加商店项: name=%s, item_id=%s" % [p_name + " Lv%d→%d" % [p.current_level, mini(5, p.current_level + 1)], item_id])

	print("[ShopSystem] 返回商店商品数: " + str(inventory.size()))
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
		"partner_upgrade":
			var target_id: String = item_data.get("target_id", "")
			var pid: int = int(target_id) if target_id.is_valid_int() else 0
			var target_config_id: int = int(item_data.get("target_config_id", "0"))
			if _character_manager.upgrade_partner_by_instance_id(pid):
				result["applied_effects"].append({"type": "partner_level", "instance_id": pid, "config_id": target_config_id, "delta": 1})
			else:
				result["error"] = "升级失败（已达最高等级或伙伴不存在）"
				return result
		"hero_attr":
			var attr_code: int = int(item_data.get("target_attr", 0))
			var attr_bonus: int = int(item_data.get("attr_bonus_value", 0))
			if attr_code < 1 or attr_code > 5 or attr_bonus <= 0:
				result["error"] = "无效的主角属性商品"
				return result
			_character_manager.modify_hero_stats({attr_code: attr_bonus})
			result["applied_effects"].append({"type": "hero_attr", "attr_code": attr_code, "delta": attr_bonus})
		"hero_all_attr":
			var all_bonus: int = int(item_data.get("attr_bonus_value", 0))
			if all_bonus <= 0:
				result["error"] = "无效的全属性商品"
				return result
			_character_manager.modify_hero_stats({1: all_bonus, 2: all_bonus, 3: all_bonus, 4: all_bonus, 5: all_bonus})
			result["applied_effects"].append({"type": "hero_all_attr", "delta": all_bonus})
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

func _make_hero_upgrade_item(cfg: Dictionary, current_gold: int) -> Dictionary:
	var item_id: String = str(cfg.get("id", ""))
	var item_type: String = cfg.get("item_type", "")
	var base_cost: int = cfg.get("cost_base", 20)
	var cost: int = _calculate_current_cost(item_id, base_cost)
	var name: String = cfg.get("name", "???")
	var desc: String = cfg.get("description", "")
	var attr_code: int = cfg.get("target_attr", 0)
	var attr_bonus: int = cfg.get("attr_bonus_value", 0)
	var can_afford: bool = current_gold >= cost
	return {
		"item_id": item_id,
		"item_type": item_type,
		"name": name,
		"price": cost,
		"effect_desc": desc,
		"can_afford": can_afford,
		"target_attr": attr_code,
		"attr_bonus_value": attr_bonus,
	}


func _get_item_base_cost(item_id: String) -> int:
	# 从配置表读取基础价格
	var shop_cfg: Dictionary = ConfigManager.get_shop_price_config()
	for k in shop_cfg:
		var item: Dictionary = shop_cfg[k]
		if str(item.get("id", "")) == item_id:
			return item.get("cost_base", 20)
	# Fallback：伙伴升级
	if item_id.begins_with("partner_"):
		return 30
	return 30


func _calculate_current_cost(item_id: String, base_cost: int) -> int:
	var count: int = _shop_purchase_counts.get(item_id, 0)
	# 从配置表读取递增步长，fallback 为 +10
	var step: int = 10
	var shop_cfg: Dictionary = ConfigManager.get_shop_price_config()
	var lookup_id: String = item_id
	# 伙伴升级项为动态 ID（partner_<config_id>_<instance_id>），按基础 ID 查步长
	if item_id.begins_with("partner_"):
		var parts: PackedStringArray = item_id.split("_")
		if parts.size() >= 3:
			lookup_id = "partner_%s" % parts[1]
	for k in shop_cfg:
		var item: Dictionary = shop_cfg[k]
		if str(item.get("id", "")) == lookup_id:
			step = item.get("cost_increase_per_buy", 10)
			break
	return base_cost + count * step
