## 运行时逻辑验证脚本（附加到场景节点使用）
## 用法: godot --headless res://tools/validate_run_logic.tscn

extends Node


func _ready():
	var rc := preload("res://scripts/systems/run_controller.gd").new()
	rc.name = "RunController"
	add_child(rc)

	# ------------------------------------------------------------------
	# 1. 新局种子与 RNG 注入
	# ------------------------------------------------------------------
	rc.start_new_run(1, [1001, 1002])
	assert(rc._run != null, "Run 对象未初始化")
	assert(rc._run.run_seed != 0, "新局 run_seed 不能为 0")
	assert(rc._run_rng != null and rc._run_rng.seed == rc._run.run_seed,
		"Run RNG 种子与 run_seed 不一致")
	print("[Validate] PASS: 新局种子与 RNG 注入")

	# ------------------------------------------------------------------
	# 2. 伙伴上限 7
	# ------------------------------------------------------------------
	var cm := rc._character_manager
	# 初始已有 2 名伙伴，再添加直到上限
	var extra_ids := [1003, 1004, 1005, 1006, 1001]
	for pid in extra_ids:
		cm.add_partner(pid, 0, 1)
	assert(cm.get_partners().size() == 7, "伙伴上限应为 7，实际 %d" % cm.get_partners().size())
	var overflow := cm.add_partner(1002, 0, 1)
	assert(overflow == null, "超过 7 人后 add_partner 应返回 null")
	print("[Validate] PASS: 伙伴上限 7")

	# ------------------------------------------------------------------
	# 3. 商店：同时存在主角升级与伙伴升级，购买与涨价
	# ------------------------------------------------------------------
	rc._run.gold_owned = 9999
	var items := rc.get_current_shop_items()
	assert(items.size() > 0, "商店不应为空")
	var has_hero := false
	var has_partner := false
	for item in items:
		var itype: String = item.get("item_type", "")
		if itype == "hero_attr":
			has_hero = true
		elif itype == "partner_upgrade":
			has_partner = true
	assert(has_hero and has_partner, "商店应同时包含主角升级与伙伴升级")

	# 购买一个主角属性升级
	var hero_item: Dictionary = {}
	for item in items:
		if item.get("item_type", "") == "hero_attr":
			hero_item = item.duplicate()
			break
	assert(not hero_item.is_empty(), "未找到主角升级商品")
	var attr_code: int = hero_item.get("target_attr", 0)
	var old_attr: int = _get_attr(rc._hero, attr_code)
	var old_gold: int = rc._run.gold_owned
	var buy1 := rc.purchase_shop_item(hero_item)
	assert(buy1.get("success", false), "主角升级购买应成功: %s" % buy1.get("error", ""))
	assert(rc._run.gold_owned == old_gold - hero_item.get("price", 0),
		"购买后金币扣除不正确")
	assert(_get_attr(rc._hero, attr_code) > old_attr, "购买后属性未提升")

	# 再次购买同一商品，价格应上涨
	var items2 := rc.get_current_shop_items()
	var hero_item2: Dictionary = {}
	for item in items2:
		if item.get("item_id", "") == hero_item.get("item_id", ""):
			hero_item2 = item.duplicate()
			break
	assert(not hero_item2.is_empty() and hero_item2.get("price", 0) > hero_item.get("price", 0),
		"重复购买主角升级未涨价")
	var buy2 := rc.purchase_shop_item(hero_item2)
	assert(buy2.get("success", false), "第二次购买主角升级应成功")

	# 购买一个伙伴升级
	var partner_item: Dictionary = {}
	for item in rc.get_current_shop_items():
		if item.get("item_type", "") == "partner_upgrade":
			partner_item = item.duplicate()
			break
	if not partner_item.is_empty():
		var target_id: int = int(partner_item.get("target_id", "0"))
		var partner_before: int = _get_partner_level(cm, target_id)
		var buy3 := rc.purchase_shop_item(partner_item)
		assert(buy3.get("success", false), "伙伴升级购买应成功")
		assert(_get_partner_level(cm, target_id) > partner_before, "伙伴升级后等级未提升")
	print("[Validate] PASS: 商店生成、购买与涨价")

	# ------------------------------------------------------------------
	# 4. 外出事件读取 event_config，三种大类均能正常解析/生效
	# ------------------------------------------------------------------
	var nr := rc._node_resolver
	var base_context := {"hero": rc._hero, "run": rc._run, "turn": 5, "partners": cm.get_partners()}

	# reward 类
	var reward_res := nr.resolve({"node_type": NodePoolSystem.NodeType.OUTING, "pool_type": "reward"}, base_context.duplicate())
	assert(reward_res.get("description", "").length() > 0, "reward 类外出事件描述为空")
	var reward_effect: Dictionary = reward_res.get("choices", [{}])[0].get("effect", {})
	_apply_and_check_outing(rc, reward_effect)

	# penalty 类
	var penalty_res := nr.resolve({"node_type": NodePoolSystem.NodeType.OUTING, "pool_type": "penalty"}, base_context.duplicate())
	assert(penalty_res.get("description", "").length() > 0, "penalty 类外出事件描述为空")
	var penalty_effect: Dictionary = penalty_res.get("choices", [{}])[0].get("effect", {})
	_apply_and_check_outing(rc, penalty_effect)

	# elite 类
	var elite_res := nr.resolve({"node_type": NodePoolSystem.NodeType.OUTING, "pool_type": "elite"}, base_context.duplicate())
	assert(elite_res.get("is_elite", false), "elite 类外出事件 is_elite 应为 true")
	assert(elite_res.get("requires_battle", false), "elite 类外出事件应需要战斗")
	print("[Validate] PASS: 外出事件配置解析与效果应用")

	# ------------------------------------------------------------------
	# 5. 精英战 3 选 1 奖励：去重、3 个
	# ------------------------------------------------------------------
	var es := rc.get_node_or_null("EliteBattleSystem")
	assert(es != null, "场景中缺少 EliteBattleSystem")
	var rewards: Array = es.generate_elite_rewards(2, 10, rc._run_rng)
	assert(rewards.size() == 3, "精英奖励应为 3 个，实际 %d" % rewards.size())
	var used_keys: Array[String] = []
	for r in rewards:
		var key := _reward_key(r)
		assert(not (key in used_keys), "精英奖励存在重复: %s" % key)
		used_keys.append(key)
	print("[Validate] PASS: 精英奖励 3 选 1 去重")

	# ------------------------------------------------------------------
	# 6. 终局 Boss 从配置池随机抽取
	# ------------------------------------------------------------------
	assert(rc._boss_pool != null, "Boss 池未初始化")
	var boss := rc._boss_pool.select_random_boss()
	var boss_id: int = boss.get("enemy_config_id", 0)
	assert(boss_id >= 2001 and boss_id <= 2005, "终局 Boss ID 不在配置池范围内: %d" % boss_id)
	print("[Validate] PASS: 终局 Boss 从配置池抽取 (id=%d)" % boss_id)

	# ------------------------------------------------------------------
	# 7. 战斗引擎集成：Buff 带入、一次性伤害减免消耗
	# ------------------------------------------------------------------
	# 给主角加一个战斗 Buff 并准备一次性伤害减免
	rc._character_manager.apply_hero_buff({
		"buff_name": "战意高涨",
		"buff_effect": 3,
		"effect_value": 0.4,
		"duration": 5,
	})
	rc._run.damage_reduction_next_battle = 0.3
	var battle_result := rc._run_battle_engine(2001)
	assert(battle_result.has("winner"), "战斗结果缺少 winner")
	assert(rc._run.damage_reduction_next_battle == 0.0, "一次性伤害减免应在战斗后清零")
	print("[Validate] PASS: 战斗 Buff 与伤害减免集成")

	# ------------------------------------------------------------------
	# 8. 新局开始时商店购买次数重置
	# ------------------------------------------------------------------
	rc.start_new_run(1, [1001])
	var shop_system := rc.get_node_or_null("ShopSystem")
	assert(shop_system != null and shop_system._shop_purchase_counts.is_empty(),
		"新局开始时商店购买次数未重置")
	print("[Validate] PASS: 新局商店购买次数重置")

	# ------------------------------------------------------------------
	# 9. 战斗胜利计数不重复累加
	# ------------------------------------------------------------------
	rc.start_new_run(1, [1001])
	# 提升属性保证稳赢
	rc._hero.current_vit = 999
	rc._hero.current_str = 999
	rc._hero.current_agi = 999
	rc._hero.current_tec = 999
	rc._hero.current_mnd = 999
	rc._hero.max_hp = 9999
	rc._hero.current_hp = 9999
	var win_before: int = rc._run.battle_win_count
	rc._run_battle_engine(2001)
	# _run_battle_engine 本身不增加计数，计数由 _finish_node_execution 在 requires_battle 结果时增加
	# 这里直接模拟一次 finish_node_execution 调用，验证只 +1
	var fake_result := {"success": true, "requires_battle": true, "is_elite": false,
		"enemy_config_id": 2001, "battle_result": {"winner": "player"}}
	rc._finish_node_execution(fake_result)
	assert(rc._run.battle_win_count == win_before + 1,
		"战斗胜利计数异常: before=%d after=%d" % [win_before, rc._run.battle_win_count])
	print("[Validate] PASS: 战斗胜利计数只增加一次")

	print("\n=== 所有运行时逻辑验证通过 ===")
	get_tree().quit()


func _get_attr(hero, attr_code: int) -> int:
	match attr_code:
		1: return hero.current_vit
		2: return hero.current_str
		3: return hero.current_agi
		4: return hero.current_tec
		5: return hero.current_mnd
	return 0


func _get_partner_level(cm, instance_id: int) -> int:
	for p in cm.get_partners():
		if p.instance_id == instance_id:
			return p.current_level
	return 0


func _apply_and_check_outing(rc, effect: Dictionary) -> void:
	if effect.is_empty():
		return
	var msg := {"message": ""}
	var before_gold: int = rc._run.gold_owned
	var before_hp: int = rc._hero.current_hp
	rc._apply_outing_effect(effect, msg)
	# 只要 effect 非空，就应产生某种可观察变化或至少不报错
	if effect.has("gold"):
		assert(rc._run.gold_owned != before_gold or effect.get("gold", 0) == 0,
			"金币类外出事件效果未生效")
	elif effect.has("damage_ratio"):
		assert(rc._hero.current_hp < before_hp or effect.get("damage_ratio", 0.0) == 0.0,
			"伤害类外出事件效果未生效")
	elif effect.has("steal_gold_ratio"):
		assert(rc._run.gold_owned <= before_gold,
			"偷金币类外出事件效果未生效")


func _reward_key(reward: Dictionary) -> String:
	var rtype: String = reward.get("type", "")
	var effect: Dictionary = reward.get("effect", {})
	match rtype:
		"target_partner_level_up": return "target_partner"
		"random_partner_level_up_2": return "random_partner"
		"gold": return "gold"
		"attr_or_mastery":
			if effect.has("attr_code"):
				return "attr_%d" % effect.get("attr_code", 0)
			if effect.has("mastery_attr"):
				return "mastery_%d" % effect.get("mastery_attr", 0)
			return "attr_or_mastery"
		"buff": return "buff_%s" % effect.get("buff_name", "")
	return rtype
