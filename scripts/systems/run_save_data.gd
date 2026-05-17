## res://scripts/systems/run_save_data.gd
## 模块: RunSaveData
## 职责: 独立存档数据层，与 RuntimeRun/RuntimeHero 完全解耦
##        负责运行时对象 ↔ 存档字典 的双向转换，带版本迁移
## 依赖: RuntimeRun, RuntimeHero, RuntimePartner, CharacterManager
## class_name: RunSaveData

class_name RunSaveData
extends RefCounted

const CURRENT_VERSION: int = 1

static func from_runtime(run: RuntimeRun, hero: RuntimeHero, partners: Array, node_options: Array, forecast_charges: int, special_floor_phase: int = 0) -> Dictionary:
	var data := {
		"version": CURRENT_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"current_floor": run.current_turn,
		"hero": {
			"config_id": run.hero_config_id,
			"current_hp": hero.current_hp,
			"max_hp": hero.max_hp,
			"vit": hero.current_vit,
			"str": hero.current_str,
			"agi": hero.current_agi,
			"tec": hero.current_tec,
			"mnd": hero.current_mnd,
			"training_counts": hero.training_counts.duplicate(),
		},
		"gold": run.gold_owned,
		"battle_win_count": run.battle_win_count,
		"elite_win_count": run.elite_win_count,
		"shop_visit_count": run.shop_visit_count,
		"pvp_10th_result": run.pvp_10th_result,
		"pvp_20th_result": run.pvp_20th_result,
		"node_history": _compress_history(run.node_history),
		"partners": _partners_to_dicts(partners),
		"node_options": node_options.duplicate(true),
		"event_forecast_charges": forecast_charges,
		"run_seed": run.run_seed,
		"run_status": run.run_status,
		"special_floor_phase": special_floor_phase,
	}
	return data


static func to_runtime(data: Dictionary) -> Dictionary:
	## 返回：{"run": RuntimeRun, "hero": RuntimeHero, "partners": Array[RuntimePartner],
	##         "node_options": Array, "event_forecast_charges": int, "special_floor_phase": int}
	
	# 版本迁移
	var version: int = data.get("version", 0)
	if version == 0:
		data = _migrate_v0_to_v1(data)
	
	var hero_data: Dictionary = data.get("hero", {})
	var hero := RuntimeHero.new()
	hero.hero_config_id = hero_data.get("config_id", 0)
	hero.current_hp = hero_data.get("current_hp", 100)
	hero.max_hp = hero_data.get("max_hp", 100)
	hero.current_vit = hero_data.get("vit", 10)
	hero.current_str = hero_data.get("str", 10)
	hero.current_agi = hero_data.get("agi", 10)
	hero.current_tec = hero_data.get("tec", 10)
	hero.current_mnd = hero_data.get("mnd", 10)
	hero.training_counts = hero_data.get("training_counts", {}).duplicate()
	
	var run := RuntimeRun.new()
	run.hero_config_id = hero.hero_config_id
	run.current_turn = data.get("current_floor", 1)
	run.gold_owned = data.get("gold", 0)
	run.battle_win_count = data.get("battle_win_count", 0)
	run.elite_win_count = data.get("elite_win_count", 0)
	run.shop_visit_count = data.get("shop_visit_count", 0)
	run.pvp_10th_result = data.get("pvp_10th_result", 0)
	run.pvp_20th_result = data.get("pvp_20th_result", 0)
	run.node_history = data.get("node_history", [])
	run.run_seed = data.get("run_seed", randi())
	run.run_status = data.get("run_status", 1)
	
	var partners: Array = []
	var partner_dicts: Array = data.get("partners", [])
	for pd in partner_dicts:
		if pd is Dictionary:
			var p = RuntimePartner.from_dict(pd)
			partners.append(p)
	
	return {
		"run": run,
		"hero": hero,
		"partners": partners,
		"node_options": data.get("node_options", []),
		"event_forecast_charges": data.get("event_forecast_charges", 0),
		"special_floor_phase": data.get("special_floor_phase", 0),
	}


static func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	## v0 是旧的直接 to_dict() 格式，字段名混乱
	var migrated := data.duplicate(true)
	
	# 楼层：旧版可能叫 current_turn
	if not migrated.has("current_floor") and migrated.has("current_turn"):
		migrated["current_floor"] = migrated["current_turn"]
	
	# 英雄：旧版 hero 字段结构不同
	var old_hero = migrated.get("hero", {})
	if old_hero is Dictionary:
		var new_hero := {}
		new_hero["config_id"] = old_hero.get("hero_config_id", old_hero.get("config_id", 0))
		new_hero["current_hp"] = old_hero.get("current_hp", 100)
		new_hero["max_hp"] = old_hero.get("max_hp", 100)
		new_hero["vit"] = old_hero.get("current_vit", old_hero.get("vit", 10))
		new_hero["str"] = old_hero.get("current_str", old_hero.get("str", 10))
		new_hero["agi"] = old_hero.get("current_agi", old_hero.get("agi", 10))
		new_hero["tec"] = old_hero.get("current_tec", old_hero.get("tec", 10))
		new_hero["mnd"] = old_hero.get("current_mnd", old_hero.get("mnd", 10))
		new_hero["training_counts"] = old_hero.get("training_counts", {})
		migrated["hero"] = new_hero
	
	# 兼容旧版 special_floor_phase（可能存于根或不存在）
	if not migrated.has("special_floor_phase"):
		migrated["special_floor_phase"] = 0
	
	migrated["version"] = 1
	return migrated


static func _compress_history(history: Array) -> Array:
	## 压缩历史记录，只保留必要字段，减少存档体积
	var compressed: Array = []
	for h in history:
		compressed.append({
			"turn": h.get("turn", 0),
			"node_type": h.get("node_type", 0),
		})
	return compressed


static func _partners_to_dicts(partners: Array) -> Array:
	var result: Array = []
	for p in partners:
		if p is RuntimePartner:
			result.append(p.to_dict())
		elif p is Dictionary:
			result.append(p.duplicate())
	return result
