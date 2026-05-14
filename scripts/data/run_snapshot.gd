## res://scripts/data/run_snapshot.gd
## 模块: RunSnapshot
## 职责: 纯数据类，统一存档格式，解耦存档字段命名混用问题
## 依赖: 无
## class_name: RunSnapshot

class_name RunSnapshot
extends RefCounted

var hero_config_id: int = 0
var current_floor: int = 1
var gold: int = 0

# 英雄属性
var hero_vit: int = 0
var hero_str: int = 0
var hero_agi: int = 0
var hero_tec: int = 0
var hero_mnd: int = 0
var hero_hp: int = 0
var hero_max_hp: int = 0

# 训练计数
var training_counts: Dictionary = {}

# 伙伴列表（存 partner_config_id + favored_attr + is_active）
var partners: Array = []

# 其他运行时数据
var node_history: Array = []
var battle_win_count: int = 0
var elite_win_count: int = 0

# 跨局持久化字段（用于继续游戏恢复）
var pvp_net_wins: int = 0
var mocheng_coin: int = 0
var event_forecast_charges: int = 0

# 存档状态与SL种子
var run_status: int = 1  # 1=进行中, 2=通关, 3=战败, 4=放弃
var node_options: Array = []  # 当前层4个选项的种子数据

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"hero_config_id": hero_config_id,
		"current_floor": current_floor,
		"gold": gold,
		"hero": {
			"current_vit": hero_vit,
			"current_str": hero_str,
			"current_agi": hero_agi,
			"current_tec": hero_tec,
			"current_mnd": hero_mnd,
			"current_hp": hero_hp,
			"max_hp": hero_max_hp,
			"training_counts": training_counts,
		},
		"partners": partners,
		"node_history": node_history,
		"battle_win_count": battle_win_count,
		"elite_win_count": elite_win_count,
		"pvp_net_wins": pvp_net_wins,
		"mocheng_coin": mocheng_coin,
		"event_forecast_charges": event_forecast_charges,
		"run_status": run_status,
		"node_options": node_options,
	}

static func from_dict(data: Dictionary) -> RunSnapshot:
	var snap = RunSnapshot.new()
	snap.hero_config_id = data.get("hero_config_id", data.get("hero_id", 0))
	if snap.hero_config_id == 0:
		var hero_data = data.get("hero", {})
		snap.hero_config_id = hero_data.get("hero_config_id", 0)
	snap.current_floor = data.get("current_floor", data.get("current_turn", 1))
	snap.gold = data.get("gold", data.get("gold_owned", 0))

	var hero_data = data.get("hero", {})
	snap.hero_vit = hero_data.get("current_vit", 0)
	snap.hero_str = hero_data.get("current_str", 0)
	snap.hero_agi = hero_data.get("current_agi", 0)
	snap.hero_tec = hero_data.get("current_tec", 0)
	snap.hero_mnd = hero_data.get("current_mnd", 0)
	snap.hero_hp = hero_data.get("current_hp", 0)
	snap.hero_max_hp = hero_data.get("max_hp", 0)
	snap.training_counts = hero_data.get("training_counts", {})
	
	snap.partners = data.get("partners", [])
	snap.node_history = data.get("node_history", [])
	snap.battle_win_count = data.get("battle_win_count", 0)
	snap.elite_win_count = data.get("elite_win_count", 0)
	snap.pvp_net_wins = data.get("pvp_net_wins", 0)
	snap.mocheng_coin = data.get("mocheng_coin", 0)
	snap.event_forecast_charges = data.get("event_forecast_charges", 0)
	snap.run_status = data.get("run_status", 1)
	snap.node_options = data.get("node_options", [])
	return snap
