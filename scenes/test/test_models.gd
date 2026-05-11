## res://scenes/test/test_models.gd
## 模块: TestModels
## 职责: 任务2模型与配置测试场景
## 依赖: ModelsSerializer, 所有数据模型类

extends Control

@onready var _btn_run: Button = $Button
@onready var _label_result: Label = $LabelResult


func _ready() -> void:
	_btn_run.pressed.connect(_on_run_tests)
	_label_result.text = "点击按钮运行测试"
	# Headless 自动运行
	await get_tree().process_frame
	_on_run_tests()
	await get_tree().process_frame
	get_tree().quit()


func _on_run_tests() -> void:
	var logs: Array[String] = []
	logs.append("=== 任务2 配置+模型测试 ===")

	# 1. JSON配置加载测试
	logs.append("\n[1/4] JSON配置加载测试")
	var config_files: Array[String] = [
		"res://resources/configs/hero_configs.json",
		"res://resources/configs/partner_configs.json",
		"res://resources/configs/skill_configs.json",
		"res://resources/configs/partner_assist_configs.json",
		"res://resources/configs/partner_support_configs.json",
		"res://resources/configs/attribute_mastery_configs.json",
		"res://resources/configs/node_configs.json",
		"res://resources/configs/node_pool_configs.json",
		"res://resources/configs/enemy_configs.json",
		"res://resources/configs/battle_formula_configs.json",
		"res://resources/configs/shop_configs.json",
		"res://resources/configs/scoring_configs.json",
	]
	var config_ok := true
	for path in config_files:
		var dict: Dictionary = ModelsSerializer.load_json_file(path)
		if dict.is_empty():
			config_ok = false
			logs.append("  FAIL: %s" % path)
		else:
			var meta: Dictionary = dict.get("_meta", {})
			var entries: Dictionary = dict.get("entries", {})
			logs.append("  OK: %s (entries=%d)" % [path, entries.size()])
	if config_ok:
		logs.append("  => 全部JSON配置加载成功")
	else:
		logs.append("  => 部分JSON配置加载失败")

	# 2. 模型实例化测试
	logs.append("\n[2/4] 模型实例化测试")
	var models: Array[Object] = [
		RuntimeRun.new(),
		RuntimeHero.new(),
		RuntimePartner.new(),
		RuntimeMastery.new(),
		RuntimeBuff.new(),
		RuntimeTrainingLog.new(),
		RuntimeFinalBattle.new(),
		PlayerAccount.new(),
		FighterArchiveMain.new(),
		FighterArchivePartner.new(),
		FighterArchiveScore.new(),
		BattleMain.new(),
		BattleRound.new(),
		BattleAction.new(),
		BattleFinalResult.new(),
	]
	for m in models:
		logs.append("  OK: %s" % m.get_class())
	logs.append("  => 全部%d个模型实例化成功" % models.size())

	# 3. 序列化往返测试
	logs.append("\n[3/4] 序列化往返测试")
	var serializer := ModelsSerializer.new()
	var run := _create_test_run()
	var hero := _create_test_hero()
	var partner := _create_test_partner()
	var mastery := _create_test_mastery()

	var tests: Array[Dictionary] = [
		{"obj": run, "type": "RuntimeRun"},
		{"obj": hero, "type": "RuntimeHero"},
		{"obj": partner, "type": "RuntimePartner"},
		{"obj": mastery, "type": "RuntimeMastery"},
	]
	for t in tests:
		var ok: bool = serializer.roundtrip_test(t["obj"], t["type"])
		logs.append("  %s: %s" % [t["type"], "PASS" if ok else "FAIL"])

	# 4. FighterArchiveMain 聚合生成测试
	logs.append("\n[4/4] 档案聚合生成测试")
	var partners: Array = [partner]
	var archive := FighterArchiveMain.from_runtime(run, hero, partners)
	archive.hero_name = "勇者"
	archive.account_id = "test_account"
	var archive_dict: Dictionary = archive.to_dict()
	var archive_restored: FighterArchiveMain = FighterArchiveMain.from_dict(archive_dict)
	var archive_ok: bool = (archive_restored.run_id == run.run_id
		and archive_restored.hero_config_id == hero.hero_config_id
		and archive_restored.partner_count == partners.size())
	logs.append("  FighterArchiveMain.from_runtime: %s" % ("PASS" if archive_ok else "FAIL"))

	# 输出日志
	var output: String = "\n".join(logs)
	_label_result.text = output
	print(output)


func _create_test_run() -> RuntimeRun:
	var run := RuntimeRun.new()
	run.run_id = "run_test_001"
	run.run_status = 1
	run.player_account_id = "acc_001"
	run.hero_config_id = 1
	run.current_turn = 5
	run.gold_owned = 100
	run.battle_win_count = 3
	run.total_damage_dealt = 500
	run.training_count_per_attr = [2, 1, 0, 0, 0]
	return run


func _create_test_hero() -> RuntimeHero:
	var hero := RuntimeHero.new()
	hero.id = "hero_run_001"
	hero.run_id = "run_test_001"
	hero.hero_config_id = 1
	hero.max_hp = 200
	hero.current_hp = 180
	hero.current_vit = 15
	hero.current_str = 20
	hero.current_agi = 12
	hero.current_tec = 14
	hero.current_mnd = 10
	hero.passive_skill_id = 8001
	hero.ultimate_skill_id = 8002
	return hero


func _create_test_partner() -> RuntimePartner:
	var p := RuntimePartner.new()
	p.id = "partner_run_001"
	p.run_id = "run_test_001"
	p.partner_config_id = 1001
	p.position = 1
	p.current_level = 2
	p.current_hp = 100
	p.favored_attr = 2
	return p


func _create_test_mastery() -> RuntimeMastery:
	var m := RuntimeMastery.new()
	m.id = "mastery_run_001_vit"
	m.run_id = "run_test_001"
	m.attr_type = 1
	m.stage = 2
	m.training_count = 2
	m.training_bonus = 2
	return m
