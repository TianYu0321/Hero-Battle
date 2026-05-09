## res://scripts/core/test_battle_engine.gd
## 模块: TestBattleEngine
## 职责: 战斗引擎测试场景控制器
## 依赖: BattleEngine, DamageCalculator, PartnerAssist
## 被依赖: 无

class_name TestBattleEngine
extends Control

@onready var _log_label: RichTextLabel = %LogLabel
@onready var _btn_brave: Button = %BtnBrave
@onready var _btn_shadow: Button = %BtnShadow
@onready var _btn_iron: Button = %BtnIron
@onready var _enemy_option: OptionButton = %EnemyOption

var _selected_hero_id: String = ""
var _battle_engine: BattleEngine

func _ready() -> void:
	_btn_brave.pressed.connect(_start_test.bind("hero_warrior"))
	_btn_shadow.pressed.connect(_start_test.bind("hero_shadow_dancer"))
	_btn_iron.pressed.connect(_start_test.bind("hero_iron_guard"))

	# 填充敌人选项
	_enemy_option.add_item("重甲守卫 (2001)", 0)
	_enemy_option.set_item_metadata(0, "2001")
	_enemy_option.add_item("暗影刺客 (2002)", 1)
	_enemy_option.set_item_metadata(1, "2002")
	_enemy_option.add_item("元素法师 (2003)", 2)
	_enemy_option.set_item_metadata(2, "2003")
	_enemy_option.add_item("狂战士 (2004)", 3)
	_enemy_option.set_item_metadata(3, "2004")
	_enemy_option.add_item("混沌领主 (2005)", 4)
	_enemy_option.set_item_metadata(4, "2005")

	# 连接战斗信号到日志
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.battle_turn_started.connect(_on_turn_started)
	EventBus.action_executed.connect(_on_action_executed)
	EventBus.unit_damaged.connect(_on_unit_damaged)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.partner_assist_triggered.connect(_on_assist)
	EventBus.chain_triggered.connect(_on_chain)
	EventBus.ultimate_triggered.connect(_on_ultimate)

func _start_test(hero_id: String) -> void:
	_selected_hero_id = hero_id
	_log_label.clear()
	_log("===== 开始测试: %s =====" % hero_id)

	var enemy_id: String = str(_enemy_option.get_item_metadata(_enemy_option.selected))
	var battle_config: Dictionary = _build_battle_config(hero_id, enemy_id)

	_battle_engine = BattleEngine.new()
	add_child(_battle_engine)
	var result: Dictionary = await _battle_engine.execute_battle(battle_config)
	_log("===== 战斗结束 =====")
	_log("胜者: %s" % result.winner)
	_log("回合数: %d" % result.turns_elapsed)
	_log("总伤害: %d" % result.total_damage_dealt)
	_log("连锁统计: %s" % str(result.chain_stats))
	_log("必杀技触发: %s" % str(result.ultimate_triggered))
	_battle_engine.queue_free()
	_battle_engine = null

func _build_battle_config(hero_id: String, enemy_id: String) -> Dictionary:
	# 主角属性
	var hero_cfg: Dictionary = ConfigManager.get_hero_config(hero_id)
	var hero_stats: Dictionary = {
		"physique": hero_cfg.get("base_physique", 10),
		"strength": hero_cfg.get("base_strength", 10),
		"agility": hero_cfg.get("base_agility", 10),
		"technique": hero_cfg.get("base_technique", 10),
		"spirit": hero_cfg.get("base_spirit", 10),
	}
	var hero: Dictionary = DamageCalculator.spawn_hero(hero_id, hero_stats)

	# 敌人
	var enemy_cfg: Dictionary = ConfigManager.get_enemy_config(enemy_id)
	var enemy: Dictionary = DamageCalculator.spawn_enemy(enemy_cfg, hero_stats)

	# 伙伴（默认6人全带Lv1）
	var partners: Array = []
	var partner_ids: Array[String] = ["partner_swordsman", "partner_scout", "partner_shieldguard", "partner_pharmacist", "partner_sorcerer", "partner_hunter"]
	for pid in partner_ids:
		var pcfg: Dictionary = ConfigManager.get_partner_config(pid)
		var pstats: Dictionary = {
			"physique": pcfg.get("base_physique", 10),
			"strength": pcfg.get("base_strength", 10),
			"agility": pcfg.get("base_agility", 10),
			"technique": pcfg.get("base_technique", 10),
			"spirit": pcfg.get("base_spirit", 10),
		}
		partners.append(PartnerAssist.make_partner_battle_unit(pid, pcfg.get("partner_name", pid), pstats))

	return {
		"hero": hero,
		"enemies": [enemy],
		"partners": partners,
		"battle_seed": randi(),
		"playback_mode": "standard",
	}

func _log(msg: String) -> void:
	_log_label.append_text(msg + "\n")
	print(msg)

func _on_battle_started(_allies, _enemies, _config) -> void:
	_log("[战斗开始]")

func _on_battle_ended(result: Dictionary) -> void:
	_log("[战斗结束] 胜者: %s" % result.winner)

func _on_turn_started(turn: int, _effects, _mode) -> void:
	_log("[回合 %d 开始]" % turn)

func _on_action_executed(data: Dictionary) -> void:
	var summary: Dictionary = data.result_summary
	if summary.get("is_miss", false):
		_log("  %s 攻击 %s → 闪避！" % [data.actor_name, data.target_name])
	else:
		_log("  %s 攻击 %s → %d 伤害%s" % [data.actor_name, data.target_name, summary.value, " (暴击!)" if summary.is_crit else ""])

func _on_unit_damaged(_unit_id, amount, current_hp, _max_hp, _dtype, _is_crit, is_miss, _attacker_id) -> void:
	if is_miss:
		return
	pass

func _on_unit_died(unit_id, unit_name, _unit_type, _killer_id) -> void:
	_log("  ☠️ %s 阵亡！" % unit_name)

func _on_assist(partner_id, partner_name, _trigger_type, _result, _count) -> void:
	_log("  [援助] %s 触发" % partner_name)

func _on_chain(chain_count, partner_id, partner_name, damage, _multiplier, _total) -> void:
	_log("  [CHAIN x%d] %s 造成 %d 伤害" % [chain_count, partner_name, damage])

func _on_ultimate(hero_class, hero_name, turn, _condition, ultimate_name) -> void:
	_log("  [必杀技] %s 在第%d回合触发！" % [hero_name, turn])
