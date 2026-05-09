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
const ARCHIVE_FILE: String = "user://archive.json"

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
var _pvp_opponent_configs: Dictionary = {}

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

# --- Fallback 数据 ---
const _FALLBACK_HERO_CONFIGS: Dictionary = {
	"hero_warrior": {
		"hero_id": "hero_warrior",
		"hero_name": "勇者",
		"class_desc": "力量型·一击必杀",
		"base_physique": 12,
		"base_strength": 16,
		"base_agility": 10,
		"base_technique": 12,
		"base_spirit": 8,
		"favored_attr": 2,
		"passive_skill_id": 8001,
		"ultimate_skill_id": 8002,
		"skill_list": ["skill_brave_pursuit", "skill_brave_ultimate"],
		"portrait_color": "#C0392B",
		"is_default_unlock": true,
	},
	"hero_shadow_dancer": {
		"hero_id": "hero_shadow_dancer",
		"hero_name": "影舞者",
		"class_desc": "敏捷型·多段连击",
		"base_physique": 10,
		"base_strength": 10,
		"base_agility": 16,
		"base_technique": 10,
		"base_spirit": 12,
		"favored_attr": 3,
		"passive_skill_id": 8003,
		"ultimate_skill_id": 8004,
		"skill_list": ["skill_shadow_wind", "skill_shadow_ultimate"],
		"portrait_color": "#8E44AD",
		"is_default_unlock": false,
	},
	"hero_iron_guard": {
		"hero_id": "hero_iron_guard",
		"hero_name": "铁卫",
		"class_desc": "体魄型·防守反击",
		"base_physique": 16,
		"base_strength": 8,
		"base_agility": 10,
		"base_technique": 10,
		"base_spirit": 14,
		"favored_attr": 1,
		"passive_skill_id": 8005,
		"ultimate_skill_id": 8006,
		"skill_list": ["skill_iron_counter", "skill_iron_ultimate"],
		"portrait_color": "#2980B9",
		"is_default_unlock": false,
	},
}

const _FALLBACK_PARTNER_CONFIGS: Dictionary = {
	"partner_swordsman": {
		"partner_id": "partner_swordsman",
		"partner_name": "剑士",
		"role": "输出型·力量",
		"portrait_color": "#E74C3C",
		"base_physique": 10,
		"base_strength": 14,
		"base_agility": 10,
		"base_technique": 10,
		"base_spirit": 8,
	},
	"partner_scout": {
		"partner_id": "partner_scout",
		"partner_name": "斥候",
		"role": "输出型·敏捷",
		"portrait_color": "#2ECC71",
		"base_physique": 8,
		"base_strength": 10,
		"base_agility": 14,
		"base_technique": 12,
		"base_spirit": 8,
	},
	"partner_shieldguard": {
		"partner_id": "partner_shieldguard",
		"partner_name": "盾卫",
		"role": "防御型·体魄",
		"portrait_color": "#3498DB",
		"base_physique": 14,
		"base_strength": 10,
		"base_agility": 8,
		"base_technique": 8,
		"base_spirit": 10,
	},
	"partner_pharmacist": {
		"partner_id": "partner_pharmacist",
		"partner_name": "药师",
		"role": "辅助型·精神",
		"portrait_color": "#F1C40F",
		"base_physique": 8,
		"base_strength": 8,
		"base_agility": 10,
		"base_technique": 10,
		"base_spirit": 14,
	},
	"partner_sorcerer": {
		"partner_id": "partner_sorcerer",
		"partner_name": "术士",
		"role": "控场型·技巧",
		"portrait_color": "#9B59B6",
		"base_physique": 8,
		"base_strength": 10,
		"base_agility": 10,
		"base_technique": 14,
		"base_spirit": 10,
	},
	"partner_hunter": {
		"partner_id": "partner_hunter",
		"partner_name": "猎人",
		"role": "斩杀型·技巧",
		"portrait_color": "#E67E22",
		"base_physique": 10,
		"base_strength": 12,
		"base_agility": 12,
		"base_technique": 12,
		"base_spirit": 8,
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
	push_warning("[ConfigManager] Configs loaded. H:%d P:%d S:%d E:%d F:%d A:%d PVP:%d" % [_hero_configs.size(), _partner_configs.size(), _skill_configs.size(), _enemy_configs.size(), _formula_configs.size(), _partner_assist_configs.size(), _pvp_opponent_configs.size()])

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

func get_skill_config(skill_id: String) -> Dictionary:
	if not _skill_configs.has(skill_id):
		push_warning("[ConfigManager] skill_id not found: %s" % skill_id)
		return {}
	return _skill_configs[skill_id]

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
	return _enemy_configs[enemy_id]

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
	for hero_id in _hero_configs:
		var cfg: Dictionary = _hero_configs[hero_id]
		if cfg.get("is_default_unlock", false):
			result.append(hero_id)
	return result


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
	for hero_id in _hero_configs:
		var cfg: Dictionary = _hero_configs[hero_id]
		if cfg.get("id", 0) == config_id:
			return hero_id
	return ""
