## res://scripts/systems/elite_battle_system.gd
## 模块: EliteBattleSystem
## 职责: 精英战胜利后生成 3 选 1 奖励（精英战实际战斗由 RunController._run_battle_engine 统一处理）
## 依赖: EventBus
## class_name: EliteBattleSystem

class_name EliteBattleSystem
extends Node

var _rng: RandomNumberGenerator = null

func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


func generate_elite_rewards(difficulty_tier: int, turn: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var use_rng: RandomNumberGenerator = rng if rng != null else _rng
	var pool: Array[Dictionary] = [
		{
			"type": "target_partner_level_up",
			"name": "指定伙伴升级",
			"description": "指定一名伙伴等级+1",
			"weight": 10,
			"effect": {"level_up": 1, "target": "player_choice"},
		},
		{
			"type": "random_partner_level_up_2",
			"name": "随机伙伴跃升",
			"description": "随机一名伙伴等级+2",
			"weight": 10,
			"effect": {"level_up": 2, "target": "random_partner"},
		},
		{
			"type": "gold",
			"name": "大量金币",
			"description": "",
			"weight": 20,
			"effect": {"gold_min": 80, "gold_max": 150},
		},
		{
			"type": "attr_or_mastery",
			"name": "巨额磨练",
			"description": "",
			"weight": 20,
			"effect": {"attr_or_mastery": true},
		},
	]

	# Buff 子池
	var buff_pool: Array[Dictionary] = [
		{
			"type": "buff",
			"name": "训练专注",
			"description": "训练熟练度+1/层，持续5层",
			"weight": 10,
			"effect": {"buff_name": "训练专注", "buff_effect": 4, "effect_value": 1, "duration": 5},
		},
		{
			"type": "buff",
			"name": "修炼加速",
			"description": "训练等级+1，持续5层",
			"weight": 10,
			"effect": {"buff_name": "修炼加速", "buff_effect": 5, "effect_value": 1, "duration": 5},
		},
		{
			"type": "buff",
			"name": "战意高涨",
			"description": "攻击/防御+40%，持续5层（PVP除外）",
			"weight": 10,
			"effect": {"buff_name": "战意高涨", "buff_effect": 3, "effect_value": 0.4, "duration": 5, "exclude_pvp": true},
		},
		{
			"type": "buff",
			"name": "生命回流",
			"description": "每回合恢复20%生命，持续5层",
			"weight": 10,
			"effect": {"buff_name": "生命回流", "buff_effect": 6, "effect_value": 0.2, "duration": 5},
		},
	]

	# 生成 3 个不重复的奖励（允许有限重试，避免池子枯竭时死循环）
	var rewards: Array[Dictionary] = []
	var attempts: int = 0
	var used_keys: Array[String] = []
	while rewards.size() < 3 and attempts < 30:
		attempts += 1
		var chosen: Dictionary = _draw_one_reward(pool, buff_pool, use_rng)
		_fill_reward_description(chosen, difficulty_tier, turn, use_rng)
		var key: String = _get_reward_key(chosen)
		if key in used_keys:
			continue
		used_keys.append(key)
		rewards.append(chosen)
	return rewards


func _draw_one_reward(pool: Array[Dictionary], buff_pool: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var roll: float = _rng_randf(rng) * 100.0
	var chosen: Dictionary
	if roll < 10:
		chosen = pool[0].duplicate(true)
	elif roll < 20:
		chosen = pool[1].duplicate(true)
	elif roll < 40:
		chosen = pool[2].duplicate(true)
	elif roll < 60:
		chosen = pool[3].duplicate(true)
	else:
		chosen = _pick_by_weight(buff_pool, rng).duplicate(true)
	return chosen


func _fill_reward_description(chosen: Dictionary, difficulty_tier: int, turn: int, rng: RandomNumberGenerator) -> void:
	var effect: Dictionary = chosen.get("effect", {})
	match chosen["type"]:
		"gold":
			if not effect.has("gold_amount"):
				var gold_min: int = effect.get("gold_min", 80)
				var gold_max: int = effect.get("gold_max", 150)
				var amount: int = gold_min + _rng_rand_int(rng) % (gold_max - gold_min + 1)
				amount += difficulty_tier * 10 + int(turn / 5) * 5
				effect["gold_amount"] = amount
				chosen["description"] = "获得 %d 金币" % amount
		"attr_or_mastery":
			if not effect.has("attr_code") and not effect.has("mastery_attr"):
				if _rng_rand_int(rng) % 2 == 0:
					var attr_code: int = 1 + _rng_rand_int(rng) % 5
					effect["attr_code"] = attr_code
					effect["attr_bonus"] = 3
					chosen["description"] = "主角 %s +3" % _attr_name(attr_code)
				else:
					var mastery_attr: int = 1 + _rng_rand_int(rng) % 5
					effect["mastery_attr"] = mastery_attr
					effect["mastery_bonus"] = 5
					chosen["description"] = "%s 训练熟练度 +5" % _attr_name(mastery_attr)


func _get_reward_key(reward: Dictionary) -> String:
	var rtype: String = reward.get("type", "")
	var effect: Dictionary = reward.get("effect", {})
	match rtype:
		"target_partner_level_up":
			return "target_partner"
		"random_partner_level_up_2":
			return "random_partner"
		"gold":
			return "gold"
		"attr_or_mastery":
			if effect.has("attr_code"):
				return "attr_%d" % effect.get("attr_code", 0)
			if effect.has("mastery_attr"):
				return "mastery_%d" % effect.get("mastery_attr", 0)
			return "attr_or_mastery"
		"buff":
			return "buff_%s" % effect.get("buff_name", "")
		_:
			return rtype


func _pick_by_weight(items: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total_weight: float = 0.0
	for item in items:
		total_weight += float(item.get("weight", 0))
	var roll: float = _rng_randf(rng) * total_weight
	var cumulative: float = 0.0
	for item in items:
		cumulative += float(item.get("weight", 0))
		if roll <= cumulative:
			return item
	return items[items.size() - 1]


func _rng_rand_int(rng: RandomNumberGenerator) -> int:
	if rng != null:
		return rng.randi()
	return randi()


func _rng_randf(rng: RandomNumberGenerator) -> float:
	if rng != null:
		return rng.randf()
	return randf()


func _attr_name(attr_type: int) -> String:
	match attr_type:
		1: return "体魄"
		2: return "力量"
		3: return "敏捷"
		4: return "技巧"
		5: return "精神"
		_: return "未知"
