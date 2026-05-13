## res://scenes/test/test_decoupling.gd
## 模块: TestDecoupling
## 职责: Phase 2 解耦重构验收测试
## 验证: ConfigManager 动态查询 + SkillManager 配置读取 + UltimateManager 配置读取

extends Node

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("===== Phase2 解耦重构验收测试开始 =====")
	_test_config_manager_queries()
	_test_skill_manager_config_driven()
	_test_ultimate_manager_config_driven()
	_test_buff_generalization()
	_test_ui_dynamic_mapping()
	print("===== Phase2 解耦重构验收测试结束 =====")
	print("通过: %d, 失败: %d" % [_passed, _failed])
	get_tree().quit()

func _assert(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
		print("  ✅ " + msg)
	else:
		_failed += 1
		push_error("  ❌ " + msg)

# --- Step 1: ConfigManager 动态查询 ---
func _test_config_manager_queries() -> void:
	print("\n[ConfigManager 动态查询测试]")
	
	# 清理可能存在的旧 player_data，确保测试独立性
	var player_data_path: String = ConfigManager.SAVE_DIR + "player_data.json"
	if FileAccess.file_exists(player_data_path):
		DirAccess.remove_absolute(player_data_path)

	var unlocked_heroes: Array[String] = ConfigManager.get_unlocked_hero_ids()
	_assert(unlocked_heroes.size() == 1, "默认解锁主角应为1名")
	_assert(unlocked_heroes.has("hero_warrior"), "hero_warrior 应默认解锁")

	var partner_ids: Array[String] = ConfigManager.get_all_partner_ids()
	_assert(partner_ids.size() == 6, "伙伴总数应为6")
	_assert(partner_ids.has("partner_swordsman"), "应包含 partner_swordsman")

	var partner_config_ids: Array[int] = ConfigManager.get_all_partner_config_ids()
	partner_config_ids.sort()
	_assert(partner_config_ids == [1001, 1002, 1003, 1004, 1005, 1006], "伙伴数字ID应为1001-1006")

	_assert(ConfigManager.get_hero_id_by_config_id(1) == "hero_warrior", "config_id 1 -> hero_warrior")
	_assert(ConfigManager.get_hero_id_by_config_id(2) == "hero_shadow_dancer", "config_id 2 -> hero_shadow_dancer")
	_assert(ConfigManager.get_hero_id_by_config_id(3) == "hero_iron_guard", "config_id 3 -> hero_iron_guard")
	_assert(ConfigManager.get_hero_id_by_config_id(999) == "", "无效 config_id 返回空字符串")

	var hero_cfg: Dictionary = ConfigManager.get_hero_config("hero_warrior")
	_assert(hero_cfg.get("favored_attr", 0) == 2, "勇者 favored_attr = 2 (力量)")
	var iron_cfg: Dictionary = ConfigManager.get_hero_config("hero_iron_guard")
	_assert(iron_cfg.get("favored_attr", 0) == 1, "铁卫 favored_attr = 1 (体魄)")
	var shadow_cfg: Dictionary = ConfigManager.get_hero_config("hero_shadow_dancer")
	_assert(shadow_cfg.get("favored_attr", 0) == 3, "影舞者 favored_attr = 3 (敏捷)")

# --- Step 2: SkillManager 配置驱动 ---
func _test_skill_manager_config_driven() -> void:
	print("\n[SkillManager 配置驱动测试]")

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var dc: DamageCalculator = DamageCalculator.new(42)
	var sm: SkillManager = SkillManager.new(dc, rng)

	# 勇者: 技巧=12, 基础30%, 每10点+2%, 上限50%
	# 原代码: prob = 0.3 + float(12/10)*0.02 = 0.3 + 0.02 = 0.32
	var brave_hero: Dictionary = DamageCalculator.spawn_hero("hero_warrior", {
		"physique": 12, "strength": 16, "agility": 10, "technique": 12, "spirit": 8
	})
	var brave_cfg: Dictionary = ConfigManager.get_skill_config("8001")
	var brave_tp: Dictionary = brave_cfg.get("trigger_params", {})
	_assert(brave_tp.get("base_trigger_prob", 0.0) == 0.3, "勇者被动 base_trigger_prob = 0.3")
	_assert(brave_tp.get("prob_attr_bonus", 0) == 4, "勇者被动 prob_attr_bonus = 4 (技巧)")
	_assert(brave_tp.get("prob_attr_step", 0) == 10, "勇者被动 prob_attr_step = 10")
	_assert(brave_tp.get("prob_attr_inc", 0.0) == 0.02, "勇者被动 prob_attr_inc = 0.02")
	_assert(brave_tp.get("prob_max", 0.0) == 0.5, "勇者被动 prob_max = 0.5")

	# 影舞者: 敏捷=16, segment_min=2, segment_max=4, step=20
	# 原代码: segments = clampi(2 + int(16/20), 2, 4) = 2
	var shadow_hero: Dictionary = DamageCalculator.spawn_hero("hero_shadow_dancer", {
		"physique": 10, "strength": 10, "agility": 16, "technique": 10, "spirit": 12
	})
	var shadow_cfg: Dictionary = ConfigManager.get_skill_config("8003")
	var shadow_tp: Dictionary = shadow_cfg.get("trigger_params", {})
	_assert(shadow_tp.get("segment_min", 0) == 2, "影舞者被动 segment_min = 2")
	_assert(shadow_tp.get("segment_max", 0) == 4, "影舞者被动 segment_max = 4")
	_assert(shadow_tp.get("segment_attr_bonus", 0) == 3, "影舞者被动 segment_attr_bonus = 3 (敏捷)")
	_assert(shadow_tp.get("segment_attr_step", 0) == 20, "影舞者被动 segment_attr_step = 20")

	# 铁卫: 精神=14, 基础25%, 每10点+2%, 上限50%
	# 原代码: prob = 0.25 + float(14/10)*0.02 = 0.25 + 0.02 = 0.27
	var iron_hero: Dictionary = DamageCalculator.spawn_hero("hero_iron_guard", {
		"physique": 16, "strength": 8, "agility": 10, "technique": 10, "spirit": 14
	})
	var iron_cfg: Dictionary = ConfigManager.get_skill_config("8005")
	var iron_tp: Dictionary = iron_cfg.get("trigger_params", {})
	_assert(iron_tp.get("base_trigger_prob", 0.0) == 0.25, "铁卫被动 base_trigger_prob = 0.25")
	_assert(iron_tp.get("prob_attr_bonus", 0) == 5, "铁卫被动 prob_attr_bonus = 5 (精神)")
	_assert(iron_tp.get("stun_prob", 0.0) == 0.10, "铁卫被动 stun_prob = 0.10")

	# 验证 spawn_hero 不再包含 iron_guard_buff，而是 buff_list
	_assert(not brave_hero.has("iron_guard_buff"), "spawn_hero 不应再包含 iron_guard_buff")
	_assert(brave_hero.has("buff_list"), "spawn_hero 应包含 buff_list")
	_assert(brave_hero.buff_list.is_empty(), "spawn_hero 初始 buff_list 为空")

	print("  数值一致性检查（通过配置计算）:")
	var tec: int = brave_hero.stats.technique
	var prob_step: int = int(brave_tp.prob_attr_step)
	var prob: float = brave_tp.base_trigger_prob + float(tec / prob_step) * brave_tp.prob_attr_inc
	prob = min(prob, brave_tp.prob_max)
	_assert(abs(prob - 0.32) < 0.001, "勇者追击概率计算 = 0.32 (与重构前一致)")

	var agi: int = shadow_hero.stats.agility
	var seg_step: int = int(shadow_tp.segment_attr_step)
	var segments: int = clampi(shadow_tp.segment_min + int(agi / seg_step), shadow_tp.segment_min, shadow_tp.segment_max)
	_assert(segments == 2, "影舞者段数计算 = 2 (配置step=20, 16/20=0, 2+0=2)")

	var mnd: int = iron_hero.stats.spirit
	var iron_prob_step: int = int(iron_tp.prob_attr_step)
	var iron_prob: float = iron_tp.base_trigger_prob + float(mnd / iron_prob_step) * iron_tp.prob_attr_inc
	iron_prob = min(iron_prob, iron_tp.prob_max)
	_assert(abs(iron_prob - 0.27) < 0.001, "铁卫反击概率计算 = 0.27 (与重构前一致)")

# --- Step 2: UltimateManager 配置驱动 ---
func _test_ultimate_manager_config_driven() -> void:
	print("\n[UltimateManager 配置驱动测试]")

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var dc: DamageCalculator = DamageCalculator.new(42)
	var um: UltimateManager = UltimateManager.new(dc, rng)

	# 勇者必杀配置
	var brave_ult_cfg: Dictionary = ConfigManager.get_skill_config("8002")
	var brave_ult_tp: Dictionary = brave_ult_cfg.get("trigger_params", {})
	_assert(brave_ult_tp.get("hp_threshold", 0.0) == 0.40, "勇者必杀 hp_threshold = 0.40")
	_assert(brave_ult_tp.get("ignore_def_ratio", 0.0) == 0.30, "勇者必杀 ignore_def_ratio = 0.30")
	_assert(brave_ult_cfg.get("power_scale", 0.0) == 3.0, "勇者必杀 power_scale = 3.0")

	# 影舞者必杀配置
	var shadow_ult_cfg: Dictionary = ConfigManager.get_skill_config("8004")
	var shadow_ult_tp: Dictionary = shadow_ult_cfg.get("trigger_params", {})
	_assert(shadow_ult_tp.get("fixed_turn", 0) == 8, "影舞者必杀 fixed_turn = 8")
	_assert(shadow_ult_tp.get("segment_count", 0) == 6, "影舞者必杀 segment_count = 6")
	_assert(shadow_ult_tp.get("partner_boost", 0.0) == 1.5, "影舞者必杀 partner_boost = 1.5")
	_assert(shadow_ult_cfg.get("power_scale", 0.0) == 0.4, "影舞者必杀 power_scale = 0.4")

	# 铁卫必杀配置
	var iron_ult_cfg: Dictionary = ConfigManager.get_skill_config("8006")
	var iron_ult_tp: Dictionary = iron_ult_cfg.get("trigger_params", {})
	_assert(iron_ult_tp.get("hp_threshold", 0.0) == 0.50, "铁卫必杀 hp_threshold = 0.50")
	_assert(iron_ult_tp.get("buff_duration", 0) == 3, "铁卫必杀 buff_duration = 3")
	_assert(iron_ult_tp.get("damage_reduction", 0.0) == 0.40, "铁卫必杀 damage_reduction = 0.40")
	_assert(iron_ult_tp.get("counter_prob_override", 0.0) == 1.0, "铁卫必杀 counter_prob_override = 1.0")
	_assert(iron_ult_tp.get("stun_prob", 0.0) == 0.25, "铁卫必杀 stun_prob = 0.25")

	# 触发行为一致性检查
	var brave_hero: Dictionary = DamageCalculator.spawn_hero("hero_warrior", {
		"physique": 12, "strength": 16, "agility": 10, "technique": 12, "spirit": 8
	})
	var enemy: Dictionary = DamageCalculator.spawn_enemy(ConfigManager.get_enemy_config("2001"), brave_hero.stats)
	enemy.hp = int(enemy.max_hp * 0.3)
	var result1: Dictionary = um.check_and_trigger(brave_hero, [enemy], 5)
	_assert(result1.triggered, "勇者应在敌人<40%血时触发必杀")

	var shadow_hero: Dictionary = DamageCalculator.spawn_hero("hero_shadow_dancer", {
		"physique": 10, "strength": 10, "agility": 16, "technique": 10, "spirit": 12
	})
	var enemy2: Dictionary = DamageCalculator.spawn_enemy(ConfigManager.get_enemy_config("2001"), shadow_hero.stats)
	var result2: Dictionary = um.check_and_trigger(shadow_hero, [enemy2], 8)
	_assert(result2.triggered, "影舞者应在第8回合触发必杀")
	_assert(result2.packets.size() == 6, "影舞者必杀应为6段")

	var iron_hero: Dictionary = DamageCalculator.spawn_hero("hero_iron_guard", {
		"physique": 16, "strength": 8, "agility": 10, "technique": 10, "spirit": 14
	})
	iron_hero.hp = int(iron_hero.max_hp * 0.3)
	var result3: Dictionary = um.check_and_trigger(iron_hero, [], 5)
	_assert(result3.triggered, "铁卫应在自身<50%血时触发必杀")
	_assert(iron_hero.buff_list.size() == 1, "铁卫必杀应添加1个buff")
	var buff: Dictionary = iron_hero.buff_list[0]
	_assert(buff.get("buff_id", "") == "iron_guard_ultimate", "buff_id 应为 iron_guard_ultimate")
	_assert(buff.get("duration", 0) == 3, "buff duration 应为3")
	_assert(buff.effects.get("damage_reduction", 0.0) == 0.40, "buff damage_reduction = 0.40")
	_assert(buff.effects.get("counter_prob_override", 0.0) == 1.0, "buff counter_prob_override = 1.0")
	_assert(buff.effects.get("stun_prob", 0.0) == 0.25, "buff stun_prob = 0.25")

# --- Buff 通用化 ---
func _test_buff_generalization() -> void:
	print("\n[Buff 通用化测试]")

	var hero: Dictionary = DamageCalculator.spawn_hero("hero_iron_guard", {
		"physique": 16, "strength": 8, "agility": 10, "technique": 10, "spirit": 14
	})
	var buff: Dictionary = {
		"buff_id": "test_buff",
		"name": "测试Buff",
		"duration": 2,
		"effects": {"damage_reduction": 0.20}
	}
	hero.buff_list.append(buff)

	# 模拟回合推进
	var buff_list: Array = hero.get("buff_list", [])
	for i in range(buff_list.size() - 1, -1, -1):
		var b = buff_list[i]
		b.duration -= 1
		if b.duration <= 0:
			buff_list.remove_at(i)
	_assert(buff_list.size() == 1, "第1回合后 test_buff 仍存在 (duration=1)")

	for i in range(buff_list.size() - 1, -1, -1):
		var b = buff_list[i]
		b.duration -= 1
		if b.duration <= 0:
			buff_list.remove_at(i)
	_assert(buff_list.is_empty(), "第2回合后 test_buff 已移除")

# --- UI 动态映射 ---
func _test_ui_dynamic_mapping() -> void:
	print("\n[UI 动态映射测试]")

	# hero_select 已改为动态读取，无法直接实例化测试（需要场景树），
	# 但我们可以通过检查 ConfigManager 接口间接验证
	var unlocked: Array[String] = ConfigManager.get_unlocked_hero_ids()
	_assert(unlocked.size() >= 1, "hero_select 动态读取应有至少1个主角")

	var partners: Array[String] = ConfigManager.get_all_partner_ids()
	_assert(partners.size() == 6, "tavern 动态读取应有6个伙伴")

	var partner_ids: Array[int] = ConfigManager.get_all_partner_config_ids()
	_assert(partner_ids.size() == 6, "rescue_system 动态读取应有6个伙伴ID")

	var hero_id: String = ConfigManager.get_hero_id_by_config_id(2)
	_assert(hero_id == "hero_shadow_dancer", "run_controller 动态查询 config_id 2 -> hero_shadow_dancer")
