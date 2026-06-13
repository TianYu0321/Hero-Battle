class_name NodeResolver
extends Node

## NodeResolver — 节点解析器
## v3.0: 外出事件改为读取 event_config.json；支持注入 RNG 保证可复现

signal node_resolved(node_type: int, result_data: Dictionary)

var _rng: RandomNumberGenerator = null

func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


## 解析节点
## node_option: 节点选项数据
## context: {
##   hero: RuntimeHero,
##   run: RuntimeRun,
##   turn: int,
##   partners: Array[RuntimePartner]
## }
func resolve(node_option: Dictionary, context: Dictionary) -> Dictionary:
	var node_type: int = node_option.get("node_type", 0)
	var result: Dictionary = {"success": true, "rewards": []}

	match node_type:
		NodePoolSystem.NodeType.TRAINING:
			result = _resolve_training()
		NodePoolSystem.NodeType.BATTLE:
			result = _resolve_battle(context, node_option)
		NodePoolSystem.NodeType.REST:
			result = _resolve_rest(context)
		NodePoolSystem.NodeType.OUTING:
			context["node_option"] = node_option
			result = _resolve_outing(context)
		NodePoolSystem.NodeType.RESCUE:
			result = _resolve_rescue(node_option, context)
		NodePoolSystem.NodeType.SHOP:
			result = _resolve_shop()
		NodePoolSystem.NodeType.PVP_CHECK:
			result = _resolve_pvp()
		NodePoolSystem.NodeType.FINAL_BOSS:
			result = _resolve_final_boss()
		_:
			result = {"success": true, "rewards": []}

	node_resolved.emit(node_type, result)
	EventBus.node_resolved.emit(_get_node_type_name(node_type), result)
	return result


## v1 兼容接口：直接按节点类型解析
func resolve_node(_node_type: int, node_option: Dictionary, context: Dictionary) -> Dictionary:
	return resolve(node_option, context)


func _resolve_training() -> Dictionary:
	## 训练节点 — 返回需要UI选择属性的标记
	return {
		"success": true,
		"requires_ui_selection": true,
		"node_type": NodePoolSystem.NodeType.TRAINING,
		"rewards": {},
	}


func generate_enemy_for_floor(_floor: int) -> Dictionary:
	## 根据层数生成敌人信息（供UI预显示和简化战斗）
	var enemy_cfgs: Dictionary = ConfigManager.get_all_enemy_configs()
	var candidates: Array[Dictionary] = []
	for k in enemy_cfgs:
		var cfg: Dictionary = enemy_cfgs[k]
		if cfg.is_empty() or not cfg.has("id"):
			continue
		var min_turn: int = cfg.get("appear_turn_min", 0)
		var max_turn: int = cfg.get("appear_turn_max", 999)
		if _floor >= min_turn and _floor <= max_turn:
			candidates.append(cfg)

	if candidates.is_empty():
		## 默认敌人（层数越高越强）
		var base_hp: int = 30 + _floor * 5
		var base_atk: int = 5 + _floor * 2
		return {
			"name": "第%d层怪物" % _floor,
			"max_hp": base_hp,
			"current_hp": base_hp,
			"attack": base_atk,
			"gold_drop": 10 + _floor,
			"estimated_damage": maxi(1, int(base_atk * 0.5)),
			"enemy_config_id": 2001,
		}
	else:
		var cfg: Dictionary = candidates[_rng_rand_int() % candidates.size()]
		var base_hp: int = 50 + _floor * 3
		var base_atk: int = 5 + _floor * 2
		return {
			"name": cfg.get("name", "???"),
			"max_hp": base_hp,
			"current_hp": base_hp,
			"attack": base_atk,
			"gold_drop": cfg.get("reward_gold_min", 20),
			"estimated_damage": maxi(1, int(base_atk * 0.5)),
			"enemy_config_id": cfg.get("id", 2001),
		}


func _resolve_battle(context: Dictionary, node_option: Dictionary = {}) -> Dictionary:
	var turn: int = context.get("turn", 1)
	var hero = context.get("hero")

	## 优先使用预生成敌人配置，保证 preview 与实战一致
	var enemy: Dictionary = node_option.get("enemy_config", {})
	if enemy.is_empty():
		enemy = generate_enemy_for_floor(turn)
	EventBus.emit_signal("enemy_encountered", enemy)

	var result: Dictionary = {
		"success": true,
		"node_type": NodePoolSystem.NodeType.BATTLE,
		"requires_battle": true,
		"is_elite": false,
		"enemy_config_id": enemy.get("enemy_config_id", 2001),
		"enemy_data": enemy,
		"rewards": [],
		"logs": [],
	}

	if hero == null:
		push_error("[NodeResolver] BATTLE node requires hero in context")
		return result

	return result


func _resolve_rest(context: Dictionary) -> Dictionary:
	## 休息 — 恢复15%最大生命
	var hero: RuntimeHero = context.get("hero")
	if hero == null:
		push_error("[NodeResolver] REST node requires hero in context")
		return {"success": false, "rewards": []}
	var max_hp: int = hero.max_hp
	var heal: int = int(max_hp * 0.15)
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.REST,
		"rewards": [{"type": "hp_heal", "amount": heal}],
	}


func _resolve_outing(context: Dictionary) -> Dictionary:
	## 外出 — 触发 event_config.json 配置的事件池（4:3:3 比例）
	var hero = context.get("hero")
	var run = context.get("run")
	var turn: int = context.get("turn", 1)

	## 使用预生成的事件类型（事件透视一致性）
	var node_option: Dictionary = context.get("node_option", {})
	var preset_type: String = node_option.get("pool_type", "")

	var event_cfg: Dictionary = ConfigManager.get_event_config()
	var category_key: String = preset_type
	if category_key.is_empty():
		## 无预设时按 4:3:3 随机大类
		var roll: int = _rng_rand_int() % 10
		if roll < 4:
			category_key = "reward"
		elif roll < 7:
			category_key = "penalty"
		else:
			category_key = "elite"

	var category: Dictionary = event_cfg.get(category_key, {})
	var items: Array = category.get("items", [])

	## 精英战斗保持原有战斗逻辑
	if category_key == "elite":
		var enemy_id: int = 2001
		var precomputed_enemy: Dictionary = node_option.get("enemy_config", {})
		if not precomputed_enemy.is_empty():
			enemy_id = precomputed_enemy.get("enemy_config_id", 2001)
		else:
			enemy_id = _select_enemy_for_turn(turn)
		return {
			"success": true,
			"node_type": NodePoolSystem.NodeType.OUTING,
			"requires_battle": true,
			"is_elite": true,
			"enemy_config_id": enemy_id,
			"enemy_config": precomputed_enemy if not precomputed_enemy.is_empty() else null,
			"logs": ["遭遇精英怪物！"],
		}

	## 奖励/惩罚事件：按权重选具体事件
	var selected_event: Dictionary = _pick_event_by_weight(items)
	var title: String = selected_event.get("desc", "外出遭遇")
	var description: String = _build_event_description(selected_event)
	var effect: Dictionary = _build_event_effect(selected_event, hero)

	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.OUTING,
		"requires_ui_selection": true,
		"title": title,
		"description": description,
		"category": category_key,
		"event_type": selected_event.get("type", ""),
		"choices": [
			{"text": "接受", "effect": effect},
			{"text": "放弃", "effect": {}},
		],
		"logs": [],
	}


func _pick_event_by_weight(items: Array) -> Dictionary:
	if items.is_empty():
		return {}
	var total_weight: float = 0.0
	for item in items:
		total_weight += float(item.get("weight", 0))
	if total_weight <= 0:
		return items[0] if items.size() > 0 else {}
	var roll: float = _rng_randf() * total_weight
	var cumulative: float = 0.0
	for item in items:
		cumulative += float(item.get("weight", 0))
		if roll <= cumulative:
			return item
	return items[items.size() - 1]


func _build_event_description(event_data: Dictionary) -> String:
	var effect: String = event_data.get("effect", "")
	match effect:
		"gold":
			var value_range: Array = event_data.get("value_range", [30, 80])
			return "你发现了一处遗失的财宝箱，里面可能装有 %d~%d 金币。" % [value_range[0], value_range[1]]
		"level":
			return "一位路过的老兵愿意指点你的同伴，随机一名伙伴等级 +%d。" % event_data.get("value", 1)
		"heal_and_buff":
			var heal_ratio: float = event_data.get("heal_ratio", 0.4)
			var buff: Dictionary = event_data.get("buff", {})
			var bonus_percent: int = int(buff.get("effect_value", 0.4) * 100)
			var duration: int = buff.get("duration", 5)
			return "神圣的泉水让你精神一振：恢复 %d%% 生命，并获得攻防 +%d%% 的鼓舞（%d 层）。" % [int(heal_ratio * 100), bonus_percent, duration]
		"training":
			var training_level: int = event_data.get("value", 5)
			return "你发现了一块古老的训练石碑，可以进行一次 LV%d 级别的高级训练。" % training_level
		"damage":
			var damage_ratio: float = event_data.get("damage_ratio", 0.15)
			return "你触发了陷阱！将受到相当于最大生命 %d%% 的伤害。" % int(damage_ratio * 100)
		"debuff":
			return "你感到一阵不适：%s" % event_data.get("desc", "遭受减益效果")
		"steal_gold":
			var steal_ratio: float = event_data.get("value", 0.2)
			return "一个黑影掠过，你被偷走了 %d%% 的金币。" % int(steal_ratio * 100)
		_:
			return event_data.get("desc", "外出遭遇")


func _build_event_effect(event_data: Dictionary, _hero) -> Dictionary:
	var effect_type: String = event_data.get("effect", "")
	match effect_type:
		"gold":
			var value_range: Array = event_data.get("value_range", [30, 80])
			var amount: int = _rng_rand_int() % (value_range[1] - value_range[0] + 1) + value_range[0]
			return {"gold": amount}
		"level":
			return {"level": event_data.get("value", 1)}
		"heal_and_buff":
			return {
				"heal_ratio": event_data.get("heal_ratio", 0.4),
				"buff": event_data.get("buff", {}),
			}
		"training":
			return {"training_level": event_data.get("value", 5)}
		"damage":
			return {"damage_ratio": event_data.get("damage_ratio", 0.15)}
		"debuff":
			return {
				"debuff_type": event_data.get("debuff_type", ""),
				"duration": event_data.get("duration", 3),
				"value": event_data.get("value", 0.0),
			}
		"steal_gold":
			return {"steal_gold_ratio": event_data.get("value", 0.2)}
		_:
			return {}


func _resolve_rescue(node_option: Dictionary, context: Dictionary) -> Dictionary:
	## 救援 — 生成候选伙伴
	var result := {"success": true, "node_type": NodePoolSystem.NodeType.RESCUE, "requires_ui_selection": true, "rewards": [], "logs": []}
	var run = context.get("run")
	var candidates = node_option.get("candidates", [])

	if candidates.is_empty():
		## 后备：自己生成候选伙伴
		var all_partner_ids = ConfigManager.get_all_partner_config_ids()
		var available_ids = all_partner_ids.duplicate()
		_available_ids_shuffle(available_ids)
		for i in range(mini(3, available_ids.size())):
			var cfg = ConfigManager.get_partner_config(str(available_ids[i]))
			candidates.append({
				"partner_config_id": available_ids[i],
				"name": cfg.get("name", "未知伙伴"),
				"role": cfg.get("role", ""),
				"favored_attr": cfg.get("favored_attr", 1),
			})

	result["candidates"] = candidates
	if run != null:
		result["logs"].append("第%d层：发现遇险伙伴，请选择一名加入" % run.current_turn)
	return result


func _resolve_shop() -> Dictionary:
	## 商店 — 生成商品列表
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.SHOP,
		"requires_ui_selection": true,
		"rewards": {},
	}


func _resolve_pvp() -> Dictionary:
	## PVP检定 — 返回标记由调用方执行
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.PVP_CHECK,
		"rewards": {},
	}


func _resolve_final_boss() -> Dictionary:
	## 终局Boss战
	return {
		"success": true,
		"node_type": NodePoolSystem.NodeType.FINAL_BOSS,
		"rewards": {},
	}


func _get_node_type_name(node_type: int) -> String:
	match node_type:
		NodePoolSystem.NodeType.TRAINING: return "TRAINING"
		NodePoolSystem.NodeType.BATTLE: return "BATTLE"
		NodePoolSystem.NodeType.REST: return "REST"
		NodePoolSystem.NodeType.OUTING: return "OUTING"
		NodePoolSystem.NodeType.RESCUE: return "RESCUE"
		NodePoolSystem.NodeType.SHOP: return "SHOP"
		NodePoolSystem.NodeType.PVP_CHECK: return "PVP_CHECK"
		NodePoolSystem.NodeType.FINAL_BOSS: return "FINAL_BOSS"
		_: return "UNKNOWN"


func _select_enemy_for_turn(turn: int) -> int:
	## 根据层数选择合适的敌人配置ID
	var enemy_cfgs: Dictionary = ConfigManager.get_all_enemy_configs()
	var candidates: Array[int] = []
	for k in enemy_cfgs:
		var cfg: Dictionary = enemy_cfgs[k]
		if cfg.is_empty() or not cfg.has("id"):
			continue
		var min_turn: int = cfg.get("appear_turn_min", 0)
		var max_turn: int = cfg.get("appear_turn_max", 999)
		if turn >= min_turn and turn <= max_turn:
			candidates.append(cfg.get("id", 2001))
	if candidates.is_empty():
		return 2001  # 默认敌人
	return candidates[_rng_rand_int() % candidates.size()]


## 商店购买处理（由ShopSystem处理具体逻辑，这里只保留接口兼容）
func process_shop_purchase(_item_data: Dictionary, _run_data: RuntimeRun) -> Dictionary:
	push_warning("[NodeResolver] process_shop_purchase is deprecated, use ShopSystem directly")
	return {"success": false, "error": "deprecated"}


## 救援选择处理（由RescueSystem处理具体逻辑，这里只保留接口兼容）
func process_rescue_selection(_partner_config_id: int, _turn: int, _run_data: RuntimeRun) -> void:
	push_warning("[NodeResolver] process_rescue_selection is deprecated, use RescueSystem directly")


func _rng_rand_int() -> int:
	if _rng != null:
		return _rng.randi()
	return randi()


func _rng_randf() -> float:
	if _rng != null:
		return _rng.randf()
	return randf()


func _available_ids_shuffle(arr: Array) -> void:
	## 使用注入的 RNG 进行 Fisher-Yates 洗牌，保证可复现
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng_rand_int() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
