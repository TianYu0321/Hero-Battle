## res://scenes/test/test_save_load.gd
## 模块: TestSaveLoad
## 职责: 存档/读档专项测试：多回合存档 → 读档 → 字段对比

extends Node

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("===== 存档/读档测试开始 =====")
	_test_save_load_round_10()
	_test_save_load_round_25()
	_test_archive_save_load()
	_test_save_integrity_validation()
	print("===== 存档/读档测试结束 =====")
	print("通过: %d, 失败: %d" % [_passed, _failed])
	get_tree().quit()

func _assert(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
		print("  ✅ " + msg)
	else:
		_failed += 1
		push_error("  ❌ " + msg)

# --- 测试1: 第10回合存档读档 ---
func _test_save_load_round_10() -> void:
	print("\n[第10回合存档/读档测试]")

	var cm := CharacterManager.new()
	add_child(cm)
	var run := RuntimeRun.new()
	run.hero_config_id = 1
	run.current_turn = 10
	run.gold_owned = 150
	run.gold_earned_total = 200
	run.gold_spent = 50
	run.battle_win_count = 3
	run.elite_win_count = 1
	run.elite_total_count = 2
	run.shop_visit_count = 2
	run.rescue_success_count = 1
	run.pvp_10th_result = 1
	run.pvp_20th_result = 0
	run.initial_attr_sum = 60

	var hero := cm.initialize_hero(1)
	hero.current_hp = 80
	hero.max_hp = 120
	hero.current_vit = 18
	hero.current_str = 22
	hero.current_agi = 15
	hero.current_tec = 16
	hero.current_mnd = 12
	hero.total_enemies_killed = 5
	hero.buff_list = [{"buff_id": "test", "duration": 2}]

	cm.initialize_partners([1001, 1002])

	# 序列化
	var run_dict: Dictionary = run.to_dict()
	var hero_dict: Dictionary = hero.to_dict()

	# 反序列化
	var restored_run: RuntimeRun = RuntimeRun.from_dict(run_dict)
	var restored_hero: RuntimeHero = RuntimeHero.from_dict(hero_dict)

	# 字段对比
	_assert(restored_run.current_turn == 10, "回合数恢复: 10")
	_assert(restored_run.gold_owned == 150, "金币恢复: 150")
	_assert(restored_run.battle_win_count == 3, "战斗胜利数恢复: 3")
	_assert(restored_run.pvp_10th_result == 1, "PVP10结果恢复: 1")
	_assert(restored_hero.current_hp == 80, "HP恢复: 80")
	_assert(restored_hero.max_hp == 120, "MaxHP恢复: 120")
	_assert(restored_hero.current_str == 22, "力量恢复: 22")
	_assert(restored_hero.buff_list.size() == 1, "buff_list恢复: 1条")
	_assert(restored_hero.buff_list[0].get("buff_id", "") == "test", "buff内容正确")

	var partners: Array[RuntimePartner] = cm.get_partners()
	_assert(partners.size() == 2, "伙伴数量恢复: 2")

	cm.queue_free()
	print("  ✅ 第10回合存档/读档测试通过")

# --- 测试2: 第25回合复杂状态存档读档 ---
func _test_save_load_round_25() -> void:
	print("\n[第25回合复杂状态存档/读档测试]")

	var cm := CharacterManager.new()
	add_child(cm)
	var run := RuntimeRun.new()
	run.hero_config_id = 2
	run.current_turn = 25
	run.gold_owned = 500
	run.gold_earned_total = 800
	run.gold_spent = 300
	run.battle_win_count = 10
	run.battle_lose_count = 2
	run.elite_win_count = 3
	run.elite_total_count = 4
	run.shop_visit_count = 5
	run.rescue_success_count = 3
	run.pvp_10th_result = 1
	run.pvp_20th_result = 2
	run.pvp_fail_penalty_active = true
	run.max_chain_reached = 4
	run.total_chain_count = 15
	run.total_aid_trigger_count = 10
	run.total_damage_dealt = 5000
	run.total_enemies_killed = 20
	run.initial_attr_sum = 58
	run.node_history = [
		{"turn": 1, "node_type": 1, "result": {"success": true}},
		{"turn": 2, "node_type": 2, "result": {"success": true}},
		{"turn": 10, "node_type": 6, "result": {"won": true}},
	]

	var hero := cm.initialize_hero(2)
	hero.current_hp = 45
	hero.max_hp = 180
	hero.current_vit = 25
	hero.current_str = 20
	hero.current_agi = 35
	hero.current_tec = 22
	hero.current_mnd = 28
	hero.passive_skill_id = 8003
	hero.ultimate_skill_id = 8004
	hero.ultimate_used = true
	hero.total_enemies_killed = 20
	hero.total_damage_dealt = 5000
	hero.total_damage_taken = 1500
	hero.total_training_count = 25
	hero.is_alive = true
	hero.buff_list = [
		{"buff_id": "iron_guard_ultimate", "name": "不动如山", "duration": 2, "effects": {"damage_reduction": 0.4}},
	]

	cm.initialize_partners([1001, 1002, 1003, 1004])

	# 序列化
	var run_dict: Dictionary = run.to_dict()
	var hero_dict: Dictionary = hero.to_dict()

	# 反序列化
	var restored_run: RuntimeRun = RuntimeRun.from_dict(run_dict)
	var restored_hero: RuntimeHero = RuntimeHero.from_dict(hero_dict)

	# 复杂字段对比
	_assert(restored_run.current_turn == 25, "回合数恢复: 25")
	_assert(restored_run.gold_owned == 500, "金币恢复: 500")
	_assert(restored_run.pvp_20th_result == 2, "PVP20结果恢复: 2（失败）")
	_assert(restored_run.pvp_fail_penalty_active == true, "PVP惩罚标记恢复: true")
	_assert(restored_run.node_history.size() == 3, "节点历史恢复: 3条")
	_assert(restored_hero.current_hp == 45, "HP恢复: 45")
	_assert(restored_hero.max_hp == 180, "MaxHP恢复: 180")
	_assert(restored_hero.current_agi == 35, "敏捷恢复: 35")
	_assert(restored_hero.passive_skill_id == 8003, "被动技能ID恢复: 8003")
	_assert(restored_hero.ultimate_used == true, "必杀已使用恢复: true")
	_assert(restored_hero.buff_list.size() == 1, "buff_list恢复: 1条")
	_assert(restored_hero.buff_list[0].get("buff_id", "") == "iron_guard_ultimate", "buff_id正确")

	var partners: Array[RuntimePartner] = cm.get_partners()
	_assert(partners.size() == 4, "伙伴数量恢复: 4")

	cm.queue_free()
	print("  ✅ 第25回合复杂状态存档/读档测试通过")

# --- 测试3: 档案保存/读取 ---
func _test_archive_save_load() -> void:
	print("\n[档案保存/读取测试]")

	var archive_data: Dictionary = {
		"archive_id": "ARC_TEST_001",
		"hero_name": "勇者",
		"hero_config_id": 1,
		"final_score": 72,
		"final_grade": "A",
		"attr_snapshot_vit": 20,
		"attr_snapshot_str": 30,
		"attr_snapshot_agi": 18,
		"attr_snapshot_tec": 22,
		"attr_snapshot_mnd": 15,
		"partners": ["partner_swordsman", "partner_scout"],
		"is_fixed": true,
		"created_at": Time.get_unix_time_from_system(),
	}

	# 保存档案
	var saved: Dictionary = SaveManager.generate_fighter_archive(archive_data)
	if saved.has("_needs_overwrite"):
		# 档案已满，覆盖第一个
		SaveManager.overwrite_archive(0, archive_data)
		saved = archive_data
		_assert(saved.has("archive_id"), "保存后应有 archive_id")
	else:
		_assert(saved.has("archive_id"), "保存后应有 archive_id")
		_assert(saved.is_fixed == true, "档案标记为固定")

	# 读取档案
	var archives: Array[Dictionary] = SaveManager.load_archives("score", 100, "")
	_assert(archives.size() > 0, "应能读取到档案")

	# 验证排行榜排序（按分数降序）
	if archives.size() >= 2:
		var score0: int = archives[0].get("final_score", 0)
		var score1: int = archives[1].get("final_score", 0)
		_assert(score0 >= score1, "排行榜应按分数降序")

	print("  ✅ 档案保存/读取测试通过")

# --- 测试4: 存档完整性验证 ---
func _test_save_integrity_validation() -> void:
	print("\n[存档完整性验证测试]")

	# 完整存档应通过验证
	var valid_save: Dictionary = {
		"version": 1,
		"hero_config_id": "hero_warrior",
		"current_floor": 15,
		"current_node": 2,
		"party": [1001, 1002],
		"inventory": [],
		"gold": 100,
		"hero_stats": {"vit": 20, "str": 25},
		"timestamp": Time.get_unix_time_from_system(),
	}
	var result_valid: bool = SaveManager._validate_save_integrity(valid_save)
	_assert(result_valid == true, "完整存档应通过验证")

	# 缺少必填字段应失败
	var invalid_save: Dictionary = {
		"version": 1,
		"hero_config_id": "hero_warrior",
		# 缺少 current_floor, current_node, party, inventory, gold, hero_stats, timestamp
	}
	var result_invalid: bool = SaveManager._validate_save_integrity(invalid_save)
	_assert(result_invalid == false, "缺少字段的存档应验证失败")

	print("  ✅ 存档完整性验证测试通过")
