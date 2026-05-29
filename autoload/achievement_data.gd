## achievement_data.gd — Autoload (纯数据)
extends Node

## class_name: AchievementData

enum Category { ADVENTURE, BATTLE, COLLECTION, ACCUMULATION, SPECIAL }
enum ConditionType { REACH_FLOOR, WIN_BATTLE, NO_DAMAGE, UNLOCK_PARTNER, GOLD_TOTAL, RUN_COUNT, KILL_COUNT, EQUIP_ITEM, HEAL_AMOUNT, DAMAGE_DEALT, CRITICAL_COUNT, TURN_CLEAR, SCORE_GRADE, ELITE_KILL, MAX_HP_REACH }

const ACHIEVEMENTS: Dictionary = {
	## ===== 冒险类 =====
	"first_step": {
		"id": "first_step",
		"name": "踏上旅途",
		"description": "开始你的第一次冒险",
		"category": Category.ADVENTURE,
		"condition_type": ConditionType.RUN_COUNT,
		"target_value": 1,
		"icon": "",
		"reward_gold": 100,
		"hidden": false,
	},
	"reach_floor_5": {
		"id": "reach_floor_5",
		"name": "深入地下",
		"description": "到达第5层",
		"category": Category.ADVENTURE,
		"condition_type": ConditionType.REACH_FLOOR,
		"target_value": 5,
		"icon": "",
		"reward_gold": 200,
		"hidden": false,
	},
	"reach_floor_10": {
		"id": "reach_floor_10",
		"name": "深渊探险家",
		"description": "到达第10层",
		"category": Category.ADVENTURE,
		"condition_type": ConditionType.REACH_FLOOR,
		"target_value": 10,
		"icon": "",
		"reward_gold": 500,
		"hidden": false,
	},
	"first_clear": {
		"id": "first_clear",
		"name": "初出茅庐",
		"description": "首次通关冒险",
		"category": Category.ADVENTURE,
		"condition_type": ConditionType.REACH_FLOOR,
		"target_value": 30,
		"icon": "",
		"reward_gold": 1000,
		"hidden": false,
	},
	"speed_runner_25": {
		"id": "speed_runner_25",
		"name": "速通者",
		"description": "25回合内通关",
		"category": Category.ADVENTURE,
		"condition_type": ConditionType.TURN_CLEAR,
		"target_value": 25,
		"icon": "",
		"reward_gold": 500,
		"hidden": false,
	},
	"speed_runner_20": {
		"id": "speed_runner_20",
		"name": "极速者",
		"description": "20回合内通关",
		"category": Category.ADVENTURE,
		"condition_type": ConditionType.TURN_CLEAR,
		"target_value": 20,
		"icon": "",
		"reward_gold": 1000,
		"hidden": false,
	},
	"s_grade": {
		"id": "s_grade",
		"name": "完美评价",
		"description": "获得S评价（90分以上）",
		"category": Category.ADVENTURE,
		"condition_type": ConditionType.SCORE_GRADE,
		"target_value": 90,
		"icon": "",
		"reward_gold": 800,
		"hidden": false,
	},

	## ===== 战斗类 =====
	"first_victory": {
		"id": "first_victory",
		"name": "首战告捷",
		"description": "赢得第一场战斗",
		"category": Category.BATTLE,
		"condition_type": ConditionType.WIN_BATTLE,
		"target_value": 1,
		"icon": "",
		"reward_gold": 100,
		"hidden": false,
	},
	"slayer_10": {
		"id": "slayer_10",
		"name": "怪物猎人",
		"description": "累计击败10个敌人",
		"category": Category.BATTLE,
		"condition_type": ConditionType.KILL_COUNT,
		"target_value": 10,
		"icon": "",
		"reward_gold": 300,
		"hidden": false,
	},
	"slayer_50": {
		"id": "slayer_50",
		"name": "清道夫",
		"description": "累计击败50个敌人",
		"category": Category.BATTLE,
		"condition_type": ConditionType.KILL_COUNT,
		"target_value": 50,
		"icon": "",
		"reward_gold": 1000,
		"hidden": false,
	},
	"critical_master": {
		"id": "critical_master",
		"name": "致命一击",
		"description": "累计打出20次暴击",
		"category": Category.BATTLE,
		"condition_type": ConditionType.CRITICAL_COUNT,
		"target_value": 20,
		"icon": "",
		"reward_gold": 500,
		"hidden": false,
	},
	"no_damage_clear": {
		"id": "no_damage_clear",
		"name": "毫发无伤",
		"description": "无伤通关一场战斗",
		"category": Category.BATTLE,
		"condition_type": ConditionType.NO_DAMAGE,
		"target_value": 1,
		"icon": "",
		"reward_gold": 500,
		"hidden": false,
	},
	"elite_killer": {
		"id": "elite_killer",
		"name": "精英猎手",
		"description": "累计击败10个精英敌人",
		"category": Category.BATTLE,
		"condition_type": ConditionType.ELITE_KILL,
		"target_value": 10,
		"icon": "",
		"reward_gold": 800,
		"hidden": false,
	},
	"max_hp_300": {
		"id": "max_hp_300",
		"name": "钢铁之躯",
		"description": "单局最大生命值达到300",
		"category": Category.BATTLE,
		"condition_type": ConditionType.MAX_HP_REACH,
		"target_value": 300,
		"icon": "",
		"reward_gold": 500,
		"hidden": false,
	},

	## ===== 收集类 =====
	"first_partner": {
		"id": "first_partner",
		"name": "结伴同行",
		"description": "解锁第一个伙伴",
		"category": Category.COLLECTION,
		"condition_type": ConditionType.UNLOCK_PARTNER,
		"target_value": 1,
		"icon": "",
		"reward_gold": 200,
		"hidden": false,
	},
	"full_party": {
		"id": "full_party",
		"name": "众志成城",
		"description": "队伍达到满员（3个伙伴）",
		"category": Category.COLLECTION,
		"condition_type": ConditionType.UNLOCK_PARTNER,
		"target_value": 3,
		"icon": "",
		"reward_gold": 500,
		"hidden": false,
	},

	## ===== 累计类 =====
	"gold_hoarder": {
		"id": "gold_hoarder",
		"name": "守财奴",
		"description": "累计获得10000金币",
		"category": Category.ACCUMULATION,
		"condition_type": ConditionType.GOLD_TOTAL,
		"target_value": 10000,
		"icon": "",
		"reward_gold": 0,
		"hidden": false,
	},
	"veteran": {
		"id": "veteran",
		"name": "老兵",
		"description": "进行50场冒险",
		"category": Category.ACCUMULATION,
		"condition_type": ConditionType.RUN_COUNT,
		"target_value": 50,
		"icon": "",
		"reward_gold": 2000,
		"hidden": false,
	},
	"healer": {
		"id": "healer",
		"name": "妙手回春",
		"description": "累计恢复5000点生命值",
		"category": Category.ACCUMULATION,
		"condition_type": ConditionType.HEAL_AMOUNT,
		"target_value": 5000,
		"icon": "",
		"reward_gold": 300,
		"hidden": false,
	},

	## ===== 特殊类（隐藏）=====
	"lone_wolf": {
		"id": "lone_wolf",
		"name": "孤狼",
		"description": "不携带任何伙伴通关",
		"category": Category.SPECIAL,
		"condition_type": ConditionType.REACH_FLOOR,
		"target_value": 30,
		"icon": "",
		"reward_gold": 2000,
		"hidden": true,
	},
	"silent_kill": {
		"id": "silent_kill",
		"name": "无声击杀",
		"description": "累计击败100个敌人后解锁隐藏伙伴【刺客】",
		"category": Category.SPECIAL,
		"condition_type": ConditionType.KILL_COUNT,
		"target_value": 100,
		"icon": "",
		"reward_gold": 0,
		"reward_partner": "partner_assassin",
		"hidden": true,
	},
}


static func get_all_achievements() -> Dictionary:
	return ACHIEVEMENTS.duplicate()

static func get_achievement(id: String) -> Dictionary:
	return ACHIEVEMENTS.get(id, {})

static func get_achievements_by_category(category: Category) -> Dictionary:
	var result := {}
	for id in ACHIEVEMENTS.keys():
		var data: Dictionary = ACHIEVEMENTS[id]
		if data.get("category", -1) == category:
			result[id] = data
	return result

static func get_unlockable_achievements(include_hidden: bool = false) -> Dictionary:
	var result := {}
	for id in ACHIEVEMENTS.keys():
		var data: Dictionary = ACHIEVEMENTS[id]
		if not data.get("hidden", false) or include_hidden:
			result[id] = data
	return result

static func get_category_name(category: Category) -> String:
	match category:
		Category.ADVENTURE: return "冒险"
		Category.BATTLE: return "战斗"
		Category.COLLECTION: return "收集"
		Category.ACCUMULATION: return "累计"
		Category.SPECIAL: return "特殊"
		_: return "其他"
