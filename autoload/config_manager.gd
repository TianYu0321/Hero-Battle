## res://autoload/config_manager.gd
## 模块: ConfigManager
## 职责: 加载并缓存所有静态配置，提供类型化的数据查询接口
## 依赖: 无
## 被依赖: 所有功能层模块、UI层模块
## class_name: ConfigManager

extends Node

# --- 养成循环常量 ---
const MAX_ROUNDS: int = 30
const INITIAL_GOLD: int = 0
const MAX_PARTY_SIZE: int = 5

# --- 战斗常量 ---
const MAX_CHAIN_SEGMENTS: int = 4
const MAX_PARTNER_ASSISTS_PER_BATTLE: int = 2
const BASE_CRITICAL_MULTIPLIER: float = 1.5
const BATTLE_MAX_ROUNDS: int = 20

# --- 属性常量 ---
const MIN_STAT_VALUE: int = 0
const MAX_STAT_VALUE: int = 999

# --- 五属性编码 ---
const ATTR_PHYSIQUE: int = 1
const ATTR_STRENGTH: int = 2
const ATTR_AGILITY: int = 3
const ATTR_TECHNIQUE: int = 4
const ATTR_SPIRIT: int = 5

# --- 节点常量 ---
const NODE_OPTIONS_PER_ROUND: int = 3

# --- 存档常量 ---
const SAVE_SLOT_COUNT: int = 3
const SAVE_DIR: String = "user://saves/"
# 改为动态路径，支持账号隔离
func get_archive_file_path(user_id: String = "") -> String:
	if user_id.is_empty():
		user_id = "local_default"
	return "user://%s_archive.json" % user_id

# --- 全局枚举 ---
enum NodeType {
	TRAINING,
	BATTLE_NORMAL,
	BATTLE_ELITE,
	SHOP,
	RESCUE,
	PVP_CHECK,
	FINAL_BOSS,
}

enum BattleState {
	IDLE,
	STARTING,
	PLAYER_TURN,
	ENEMY_TURN,
	RESOLVING,
	ENDING,
	FINISHED,
}

enum EndingType {
	VICTORY,
	DEFEAT,
	ABANDON,
}

enum DamageType {
	PHYSICAL,
	MAGICAL,
	TRUE_DAMAGE,
}

enum StatusType {
	BUFF,
	DEBUFF,
}

enum PlaybackMode {
	FAST_FORWARD,
	STANDARD,
}

enum MasteryStage {
	NOVICE,
	FAMILIAR,
	PROFICIENT,
	EXPERT,
}

enum ScoreRank {
	S, A, B, C, D
}

# --- 配置缓存 ---
var _hero_configs: Dictionary = {}
var _partner_configs: Dictionary = {}
var _skill_configs: Dictionary = {}
var _enemy_configs: Dictionary = {}
var _shop_configs: Dictionary = {}
var _node_configs: Dictionary = {}
var _formula_configs: Dictionary = {}
var _scoring_configs: Dictionary = {}
var _partner_assist_configs: Dictionary = {}
var _partner_support_configs: Dictionary = {}
var _pvp_opponent_configs: Dictionary = {}
var _final_boss_configs: Dictionary = {}

# --- 数字ID → 字符串Key 映射（向后兼容） ---
const _HERO_ID_MAP: Dictionary = {
	"1": "hero_warrior",
	"2": "hero_shadow_dancer",
	"3": "hero_iron_guard",
}
const _PARTNER_ID_MAP: Dictionary = {
	"1001": "partner_swordsman",
	"1002": "partner_scout",
	"1003": "partner_shieldguard",
	"1004": "partner_pharmacist",
	"1005": "partner_sorcerer",
	"1006": "partner_hunter",
}

# --- 精灵图路径配置 ---
const HERO_SPRITE_PATHS: Dictionary = {
	1: "res://assets/characters/warrior/hero_frames.tres",
	2: "res://assets/characters/hero/shinobi/idle/shinobi_idle_01.png",
	3: "res://assets/characters/paladin/hero_frames.tres",
}

const ENEMY_SPRITE_PATHS: Dictionary = {
	2001: "res://assets/characters/enemies/enemy_2001_frames.tres",
	2002: "res://assets/characters/enemies/enemy_2002_frames.tres",
	2003: "res://assets/characters/enemies/enemy_2003_frames.tres",
	2004: "res://assets/characters/enemies/enemy_2004_frames.tres",
	2005: "res://assets/characters/enemies/enemy_2005_frames.tres",
}

const DEFAULT_HERO_SPRITE: String = "res://assets/characters/default_hero_frames.tres"
const DEFAULT_ENEMY_SPRITE: String = "res://assets/characters/enemies/default_enemy_frames.tres"

# --- 选人界面立绘路径配置 ---
const HERO_PORTRAIT_PATHS: Dictionary = {
	"hero_warrior": "res://assets/characters/hero/warrior.png",
	"hero_shadow_dancer": "res://assets/characters/hero/shinobi/idle/shinobi_idle_01.png",
	"hero_iron_guard": "res://assets/characters/hero/paladin.png",
}

## 获取英雄精灵图路径
static func get_hero_sprite_path(hero_config_id: int) -> String:
	return HERO_SPRITE_PATHS.get(hero_config_id, DEFAULT_HERO_SPRITE)

## 获取敌人精灵图路径
static func get_enemy_sprite_path(enemy_config_id: int) -> String:
	return ENEMY_SPRITE_PATHS.get(enemy_config_id, DEFAULT_ENEMY_SPRITE)

## 获取英雄选人界面立绘路径
static func get_hero_portrait_path(hero_id: String) -> String:
	return HERO_PORTRAIT_PATHS.get(hero_id, "")

## 获取伙伴头像路径
func get_partner_avatar_path(partner_id: String) -> String:
	var cfg := get_partner_config(partner_id)
	return cfg.get("avatar_path", "")

## 获取伙伴立绘/肖像路径（营救卡片大图）
func get_partner_portrait_path(partner_config_id: int) -> String:
	var cfg := get_partner_config(str(partner_config_id))
	var path: String = cfg.get("portrait_path", "")
	if path.is_empty():
		path = cfg.get("avatar_path", "")
	return path

## 获取伙伴卡片框路径（支持专用卡片 + 通用等级 fallback）
func get_partner_card_path(partner_id: String, level: int) -> String:
	level = clampi(level, 1, 5)
	## 映射数字ID到partner_id（如 "1001" → "partner_swordsman"）
	var mapped_id: String = _PARTNER_ID_MAP.get(partner_id, partner_id)
	## 先查专用卡片（后续美术在 partners/ 目录下补充）
	var dedicated: String = "res://assets/characters/card/partners/%s_lv%d.png" % [mapped_id, level]
	if FileAccess.file_exists(dedicated):
		return dedicated
	## fallback 到通用等级卡片
	return "res://assets/characters/card/LV%d.png" % level

## 获取稀有度颜色
static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"S": return Color("#E6C040")  ## 暗金
		"A": return Color("#5A8FD0")  ## 蓝
		"B": return Color("#4ECDC4")  ## 青
		_:   return Color("#888888")  ## 灰

## 获取精灵图动画帧配置
static func get_sprite_anim_config(_path: String) -> Dictionary:
	return {
		"hframes": 4,
		"vframes": 4,
		"animations": {
			"idle": [0, 1, 2, 3],
			"attack_1": [4, 5, 6, 7],
			"hurt": [8, 9, 10, 11],
			"dead": [12, 13, 14, 15],
		}
	}

# --- Fallback 数据 ---
const _FALLBACK_HERO_CONFIGS: Dictionary = {
	"hero_warrior": {
		"hero_id": "hero_warrior",
		"hero_name": "勇者",
		"class_desc": "力量型·一击必杀",
		"favored_attr": 2,
		"passive_skill_id": 8001,
		"ultimate_skill_id": 8002,
		"skill_list": ["skill_brave_pursuit", "skill_brave_ultimate"],
		"portrait_color": "#C0392B",
		"is_default_unlock": true,
		"unlock_condition": "none",
	},
	"hero_shadow_dancer": {
		"hero_id": "hero_shadow_dancer",
		"hero_name": "影舞者",
		"class_desc": "敏捷型·多段连击",
		"favored_attr": 3,
		"passive_skill_id": 8003,
		"ultimate_skill_id": 8004,
		"skill_list": ["skill_shadow_wind", "skill_shadow_ultimate"],
		"portrait_color": "#8E44AD",
		"is_default_unlock": false,
		"unlock_condition": "clear_with_hero_warrior",
	},
	"hero_iron_guard": {
		"hero_id": "hero_iron_guard",
		"hero_name": "铁卫",
		"class_desc": "体魄型·防守反击",
		"favored_attr": 1,
		"passive_skill_id": 8005,
		"ultimate_skill_id": 8006,
		"skill_list": ["skill_iron_counter", "skill_iron_ultimate"],
		"portrait_color": "#2980B9",
		"is_default_unlock": false,
		"unlock_condition": "clear_with_hero_shadow_dancer",
	},
}

const _FALLBACK_PARTNER_CONFIGS: Dictionary = {
	"partner_swordsman": {
		"partner_id": "partner_swordsman",
		"name": "剑士",
		"role": "输出",
		"portrait_color": "#E74C3C",
		"rarity_str": "B",
		"skill_charge_max": 3,
		"avatar_path": "",
	},
	"partner_scout": {
		"partner_id": "partner_scout",
		"name": "斥候",
		"role": "输出",
		"portrait_color": "#2ECC71",
		"rarity_str": "B",
		"skill_charge_max": 3,
		"avatar_path": "",
	},
	"partner_shieldguard": {
		"partner_id": "partner_shieldguard",
		"name": "盾卫",
		"role": "防御",
		"portrait_color": "#3498DB",
		"rarity_str": "B",
		"skill_charge_max": 3,
		"avatar_path": "",
	},
	"partner_pharmacist": {
		"partner_id": "partner_pharmacist",
		"name": "药师",
		"role": "辅助",
		"portrait_color": "#F1C40F",
		"rarity_str": "B",
		"skill_charge_max": 3,
		"avatar_path": "",
	},
	"partner_sorcerer": {
		"partner_id": "partner_sorcerer",
		"name": "术士",
		"role": "控场",
		"portrait_color": "#9B59B6",
		"rarity_str": "A",
		"skill_charge_max": 3,
		"avatar_path": "",
	},
	"partner_hunter": {
		"partner_id": "partner_hunter",
		"name": "猎人",
		"role": "斩杀",
		"portrait_color": "#E67E22",
		"rarity_str": "B",
		"skill_charge_max": 3,
		"avatar_path": "",
	},
}

func _ready() -> void:
	_load_all_configs()

func _load_all_configs() -> void:
	var hero_raw: Dictionary = _load_json_safe("res://resources/configs/hero_configs.json", {})
	_hero_configs = hero_raw.get("entries", _FALLBACK_HERO_CONFIGS)
	var partner_raw: Dictionary = _load_json_safe("res://resources/configs/partner_configs.json", {})
	_partner_configs = partner_raw.get("entries", _FALLBACK_PARTNER_CONFIGS)
	var skill_raw: Dictionary = _load_json_safe("res://resources/configs/skill_configs.json", {})
	_skill_configs = skill_raw.get("entries", {})
	var enemy_raw: Dictionary = _load_json_safe("res://resources/configs/enemy_configs.json", {})
	_enemy_configs = enemy_raw.get("entries", {})
	var formula_raw: Dictionary = _load_json_safe("res://resources/configs/battle_formula_configs.json", {})
	_formula_configs = formula_raw.get("entries", {})
	var assist_raw: Dictionary = _load_json_safe("res://resources/configs/partner_assist_configs.json", {})
	_partner_assist_configs = assist_raw.get("entries", {})
	var pvp_raw: Dictionary = _load_json_safe("res://resources/configs/pvp_opponent_templates.json", {})
	_pvp_opponent_configs = pvp_raw.get("entries", {})
	var shop_raw: Dictionary = _load_json_safe("res://resources/configs/shop_configs.json", {})
	_shop_configs = shop_raw.get("entries", {})
	var node_raw: Dictionary = _load_json_safe("res://resources/configs/node_pool_configs.json", {})
	_node_configs = node_raw.get("entries", {})
	var scoring_raw: Dictionary = _load_json_safe("res://resources/configs/scoring_configs.json", {})
	_scoring_configs = scoring_raw.get("entries", {})
	var support_raw: Dictionary = _load_json_safe("res://resources/configs/partner_support_configs.json", {})
	_partner_support_configs = support_raw.get("entries", {})
	_final_boss_configs = _load_json_safe("res://resources/configs/final_boss_configs.json", {})
	
	## 为所有敌人配置自动注入精灵图路径
	for enemy_id in _enemy_configs.keys():
		var cfg: Dictionary = _enemy_configs[enemy_id]
		if not cfg.has("sprite_path"):
			var eid: int = cfg.get("id", int(enemy_id))
			cfg["sprite_path"] = get_enemy_sprite_path(eid)
	
	## 为伙伴配置补充 HUD 所需统一字段
	for partner_id in _partner_configs.keys():
		var cfg: Dictionary = _partner_configs[partner_id]
		if not cfg.has("role"):
			var title: String = cfg.get("title", "")
			if title.contains("输出"):
				cfg["role"] = "输出"
			elif title.contains("防御"):
				cfg["role"] = "防御"
			elif title.contains("辅助"):
				cfg["role"] = "辅助"
			elif title.contains("控场"):
				cfg["role"] = "控场"
			elif title.contains("斩杀"):
				cfg["role"] = "斩杀"
			else:
				cfg["role"] = "伙伴"
		if not cfg.has("avatar_path"):
			cfg["avatar_path"] = ""  ## 占位，后续有资源后填充
		if not cfg.has("skill_charge_max"):
			cfg["skill_charge_max"] = 3
		if not cfg.has("rarity_str"):
			var rarity_int: int = cfg.get("rarity", 1)
			match rarity_int:
				3: cfg["rarity_str"] = "A"
				2: cfg["rarity_str"] = "B"
				1: cfg["rarity_str"] = "C"
				_: cfg["rarity_str"] = "C"
	
	push_warning("[ConfigManager] Configs loaded. H:%d P:%d S:%d E:%d F:%d A:%d PVP:%d Shop:%d Node:%d Score:%d Support:%d" % [_hero_configs.size(), _partner_configs.size(), _skill_configs.size(), _enemy_configs.size(), _formula_configs.size(), _partner_assist_configs.size(), _pvp_opponent_configs.size(), _shop_configs.size(), _node_configs.size(), _scoring_configs.size(), _partner_support_configs.size()])

static func _load_json_safe(file_path: String, fallback: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_warning("[ConfigManager] Config file not found: %s, using fallback" % file_path)
		return fallback.duplicate()

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[ConfigManager] Cannot open file: %s, error: %d" % [file_path, FileAccess.get_open_error()])
		return fallback.duplicate()

	var json_text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)

	if parse_result != OK:
		push_error("[ConfigManager] Parse error in %s at line %d: %s" % [
			file_path, json.get_error_line(), json.get_error_message()
		])
		return fallback.duplicate()

	var result = json.data
	if not result is Dictionary:
		push_error("[ConfigManager] Root must be Dictionary in %s" % file_path)
		return fallback.duplicate()

	return result

func get_hero_config(hero_id: String) -> Dictionary:
	var key: String = _HERO_ID_MAP.get(hero_id, hero_id)
	if not _hero_configs.has(key):
		push_warning("[ConfigManager] hero_id not found: %s, using fallback" % key)
		return _FALLBACK_HERO_CONFIGS.get(key, {})
	return _hero_configs[key]

func get_partner_config(partner_id: String) -> Dictionary:
	var key: String = _PARTNER_ID_MAP.get(partner_id, partner_id)
	if not _partner_configs.has(key):
		push_warning("[ConfigManager] partner_id not found: %s" % key)
		return _FALLBACK_PARTNER_CONFIGS.get(key, {})
	return _partner_configs[key]

func get_all_partner_configs() -> Dictionary:
	return _partner_configs.duplicate()

func get_partner_config_by_name(partner_name: String) -> Dictionary:
	for key in _partner_configs.keys():
		var cfg: Dictionary = _partner_configs[key]
		if cfg.get("name", "") == partner_name:
			return cfg.duplicate()
	for key in _FALLBACK_PARTNER_CONFIGS.keys():
		var cfg: Dictionary = _FALLBACK_PARTNER_CONFIGS[key]
		if cfg.get("name", "") == partner_name:
			return cfg.duplicate()
	return {}

func get_skill_config(skill_id) -> Dictionary:
	var normalized_id: String
	if skill_id is float:
		normalized_id = str(int(skill_id))
	elif skill_id is int:
		normalized_id = str(skill_id)
	else:
		normalized_id = str(skill_id)
		if normalized_id.ends_with(".0"):
			normalized_id = normalized_id.left(normalized_id.length() - 2)
	if not _skill_configs.has(normalized_id):
		push_warning("[ConfigManager] skill_id not found: %s" % normalized_id)
		return {}
	return _skill_configs[normalized_id]

func get_enemy_template(enemy_id: String) -> Dictionary:
	if not _enemy_configs.has(enemy_id):
		push_warning("[ConfigManager] enemy_id not found: %s" % enemy_id)
		return {}
	return _enemy_configs[enemy_id]

func get_shop_price_config() -> Dictionary:
	return _shop_configs.duplicate()

func get_node_weights(phase: String) -> Dictionary:
	if not _node_configs.has(phase):
		push_warning("[ConfigManager] phase not found in node configs: %s" % phase)
		return {}
	return _node_configs[phase]

func get_formula_config() -> Dictionary:
	return _formula_configs.duplicate()

func get_battle_formula_config() -> Dictionary:
	var first: Dictionary = {}
	for k in _formula_configs:
		first = _formula_configs[k]
		break
	return first.duplicate() if not first.is_empty() else {}

func get_enemy_config(enemy_id: String) -> Dictionary:
	if not _enemy_configs.has(enemy_id):
		push_warning("[ConfigManager] enemy_id not found: %s" % enemy_id)
		return {}
	var cfg: Dictionary = _enemy_configs[enemy_id].duplicate()
	## 自动注入精灵图路径（如果没有显式配置）
	if not cfg.has("sprite_path"):
		var eid: int = cfg.get("id", int(enemy_id))
		cfg["sprite_path"] = get_enemy_sprite_path(eid)
	return cfg


func get_all_enemy_configs() -> Dictionary:
	return _enemy_configs.duplicate()

func get_partner_assist_config(assist_id: String) -> Dictionary:
	if not _partner_assist_configs.has(assist_id):
		push_warning("[ConfigManager] assist_id not found: %s" % assist_id)
		return {}
	return _partner_assist_configs[assist_id]

func get_partner_assist_by_partner_id(partner_id: String) -> Dictionary:
	for k in _partner_assist_configs:
		var cfg: Dictionary = _partner_assist_configs[k]
		if str(cfg.get("partner_id", "")) == partner_id:
			return cfg
	return {}

func get_scoring_config() -> Dictionary:
	return _scoring_configs.duplicate()


func get_pvp_opponent_template(template_id: String) -> Dictionary:
	if not _pvp_opponent_configs.has(template_id):
		push_warning("[ConfigManager] pvp_opponent_template not found: %s" % template_id)
		return {}
	return _pvp_opponent_configs[template_id]


func get_unlocked_hero_ids() -> Array[String]:
	var result: Array[String] = []
	var player_data: Dictionary = SaveManager.load_player_data()
	var unlocked: Array = player_data.get("unlocked_heroes", [])
	
	for hero_id in _hero_configs:
		var cfg: Dictionary = _hero_configs[hero_id]
		if cfg.get("is_default_unlock", false) or hero_id in unlocked:
			result.append(hero_id)
	return result

## 根据数字 config_id 判断英雄是否已解锁
func is_hero_unlocked(hero_config_id: int) -> bool:
	var hero_key: String = _HERO_ID_MAP.get(str(hero_config_id), "")
	if hero_key.is_empty():
		return false
	var cfg: Dictionary = get_hero_config(hero_key)
	if cfg.get("is_default_unlock", false):
		return true
	var player_data: Dictionary = SaveManager.load_player_data()
	var unlocked: Array = player_data.get("unlocked_heroes", [])
	return hero_key in unlocked

func get_all_hero_configs() -> Dictionary:
	return _hero_configs.duplicate()


func get_all_partner_ids() -> Array[String]:
	var result: Array[String] = []
	for partner_id in _partner_configs:
		result.append(partner_id)
	return result


func get_all_partner_config_ids() -> Array[int]:
	var result: Array[int] = []
	for partner_id in _partner_configs:
		var cfg: Dictionary = _partner_configs[partner_id]
		var pid: int = cfg.get("id", 0)
		if pid > 0:
			result.append(pid)
	return result


func get_hero_id_by_config_id(config_id: int) -> String:
	return _HERO_ID_MAP.get(str(config_id), "")


func get_hero_config_id_by_hero_id(hero_id: String) -> int:
	for config_id_str in _HERO_ID_MAP.keys():
		if _HERO_ID_MAP[config_id_str] == hero_id:
			return int(config_id_str)
	# 如果 hero_id 本身就是数字字符串
	if hero_id.is_valid_int():
		return int(hero_id)
	return 0


func get_final_boss_configs() -> Dictionary:
	return _final_boss_configs.duplicate()
