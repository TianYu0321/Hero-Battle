## achievement_manager.gd — Autoload
extends Node

signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)
signal achievement_progress_updated(achievement_id: String, current: int, target: int)
signal reward_granted(gold: int)

## 从全局存档读取的解锁状态
var _unlocked_achievements: Array[String] = []
var _achievement_progress: Dictionary = {}

## 当前RUN临时计数
var _session_stats: Dictionary = {}
## 当前RUN上下文
var _current_floor: int = 0
var _current_run_partner_ids: Array[String] = []
var _lone_wolf_active: bool = false


func _ready() -> void:
	_load_from_save()
	_reset_session()
	# migrate_legacy_achievements()  # 手动启用以便迁移旧版成就数据


func _load_from_save() -> void:
	var player_data: Dictionary = SaveManager.load_player_data()
	var raw_unlocked: Array = player_data.get("unlocked_achievements", [])
	_unlocked_achievements.clear()
	for id in raw_unlocked:
		if id is String:
			_unlocked_achievements.append(id)
	_achievement_progress = player_data.get("achievement_progress", {})
	if raw_unlocked is not Array:
		_unlocked_achievements.clear()


func _save_to_disk() -> void:
	var player_data: Dictionary = SaveManager.load_player_data()
	player_data["unlocked_achievements"] = _unlocked_achievements.duplicate()
	player_data["achievement_progress"] = _achievement_progress.duplicate()
	SaveManager.save_player_data(player_data)


func _reset_session() -> void:
	_session_stats = {
		"kill_count": 0,
		"critical_count": 0,
		"heal_amount": 0,
		"damage_dealt": 0,
		"no_damage_wins": 0,
		"current_run_no_damage": true,
	}
	_current_floor = 0
	_current_run_partner_ids.clear()
	_lone_wolf_active = false


## ========== 核心API ==========

func check_and_unlock(condition_type: AchievementData.ConditionType, value: int = 1, context: Dictionary = {}) -> void:
	for id in AchievementData.ACHIEVEMENTS.keys():
		if _is_unlocked(id):
			continue
		var data: Dictionary = AchievementData.ACHIEVEMENTS[id]
		if data.get("condition_type", -1) != condition_type:
			continue
		var target: int = data.get("target_value", 1)
		var current: int = _get_current_progress(id, data, context)
		if current >= target:
			_unlock_achievement(id)


## ========== 事件触发 ==========

func on_battle_won(battle_result: Dictionary) -> void:
	check_and_unlock(AchievementData.ConditionType.WIN_BATTLE, 1)
	
	var hero_damage_taken: int = battle_result.get("hero_damage_taken", 0)
	if hero_damage_taken <= 0:
		_session_stats["no_damage_wins"] = _session_stats.get("no_damage_wins", 0) + 1
		check_and_unlock(AchievementData.ConditionType.NO_DAMAGE, _session_stats["no_damage_wins"])
	
	var enemies_killed: int = battle_result.get("enemies_killed", 1)
	_add_progress(AchievementData.ConditionType.KILL_COUNT, enemies_killed)
	
	var crit_count: int = battle_result.get("critical_count", 0)
	if crit_count > 0:
		_add_progress(AchievementData.ConditionType.CRITICAL_COUNT, crit_count)
	
	var damage_dealt: int = battle_result.get("damage_dealt", 0)
	if damage_dealt > 0:
		_add_progress(AchievementData.ConditionType.DAMAGE_DEALT, damage_dealt)
	
	var is_elite: bool = battle_result.get("is_elite", false)
	if is_elite:
		_add_progress(AchievementData.ConditionType.ELITE_KILL, 1)


func on_floor_reached(floor_num: int) -> void:
	_current_floor = floor_num
	check_and_unlock(AchievementData.ConditionType.REACH_FLOOR, floor_num, {"floor": floor_num, "lone_wolf": _lone_wolf_active})


func on_run_started(_hero_id: String, partner_ids: Array[String]) -> void:
	_reset_session()
	_current_run_partner_ids = partner_ids
	
	check_and_unlock(AchievementData.ConditionType.RUN_COUNT, _get_total_runs())
	
	if partner_ids.is_empty():
		_lone_wolf_active = true


func on_run_ended(victory: bool, floor_reached: int, final_score: int, turn_count: int, partner_ids: Array[String]) -> void:
	_current_floor = floor_reached
	
	if victory:
		if _lone_wolf_active and partner_ids.is_empty():
			check_and_unlock(AchievementData.ConditionType.REACH_FLOOR, floor_reached, {"floor": floor_reached, "lone_wolf": true})
		
		if turn_count <= 25:
			check_and_unlock(AchievementData.ConditionType.TURN_CLEAR, turn_count, {"turn_count": turn_count, "victory": true})
		
		if final_score >= 90:
			check_and_unlock(AchievementData.ConditionType.SCORE_GRADE, final_score, {"score": final_score})


func on_partner_unlocked(_partner_id: String) -> void:
	var total_partners: int = _get_unlocked_partner_count()
	check_and_unlock(AchievementData.ConditionType.UNLOCK_PARTNER, total_partners)


func on_gold_earned(amount: int) -> void:
	_add_progress(AchievementData.ConditionType.GOLD_TOTAL, amount)


func on_heal(amount: int) -> void:
	_session_stats["heal_amount"] = _session_stats.get("heal_amount", 0) + amount
	_add_progress(AchievementData.ConditionType.HEAL_AMOUNT, amount)


func on_hero_damage_taken(amount: int) -> void:
	if amount > 0:
		_session_stats["current_run_no_damage"] = false


func on_critical_hit() -> void:
	_session_stats["critical_count"] = _session_stats.get("critical_count", 0) + 1


func on_max_hp_changed(current_max_hp: int) -> void:
	check_and_unlock(AchievementData.ConditionType.MAX_HP_REACH, current_max_hp, {"max_hp": current_max_hp})


func on_elite_enemy_killed() -> void:
	_add_progress(AchievementData.ConditionType.ELITE_KILL, 1)


## ========== 进度管理 ==========

func _get_current_progress(achievement_id: String, _data: Dictionary, context: Dictionary) -> int:
	var condition_type: int = _data.get("condition_type", -1)
	
	match condition_type:
		AchievementData.ConditionType.REACH_FLOOR:
			if _data.get("id", "") == "lone_wolf" and not context.get("lone_wolf", false):
				return 0
			return context.get("floor", _current_floor)
		AchievementData.ConditionType.WIN_BATTLE:
			return _get_progress(AchievementData.ConditionType.WIN_BATTLE) + 1
		AchievementData.ConditionType.NO_DAMAGE:
			return _session_stats.get("no_damage_wins", 0)
		AchievementData.ConditionType.KILL_COUNT:
			return _get_progress(AchievementData.ConditionType.KILL_COUNT)
		AchievementData.ConditionType.CRITICAL_COUNT:
			return _get_progress(AchievementData.ConditionType.CRITICAL_COUNT)
		AchievementData.ConditionType.GOLD_TOTAL:
			return _get_progress(AchievementData.ConditionType.GOLD_TOTAL)
		AchievementData.ConditionType.RUN_COUNT:
			return _get_total_runs()
		AchievementData.ConditionType.UNLOCK_PARTNER:
			return _get_unlocked_partner_count()
		AchievementData.ConditionType.HEAL_AMOUNT:
			return _get_progress(AchievementData.ConditionType.HEAL_AMOUNT)
		AchievementData.ConditionType.DAMAGE_DEALT:
			return _get_progress(AchievementData.ConditionType.DAMAGE_DEALT)
		AchievementData.ConditionType.TURN_CLEAR:
			if not context.get("victory", false):
				return 999
			return context.get("turn_count", 999)
		AchievementData.ConditionType.SCORE_GRADE:
			return context.get("score", 0)
		AchievementData.ConditionType.ELITE_KILL:
			return _get_progress(AchievementData.ConditionType.ELITE_KILL)
		AchievementData.ConditionType.MAX_HP_REACH:
			return context.get("max_hp", 0)
		_:
			return 0


func _add_progress(condition_type: AchievementData.ConditionType, amount: int) -> void:
	var key := str(condition_type)
	var current: int = _achievement_progress.get(key, 0)
	current += amount
	_achievement_progress[key] = current
	
	for id in AchievementData.ACHIEVEMENTS.keys():
		if _is_unlocked(id):
			continue
		var data: Dictionary = AchievementData.ACHIEVEMENTS[id]
		if data.get("condition_type", -1) != condition_type:
			continue
		var target: int = data.get("target_value", 1)
		if current >= target:
			_unlock_achievement(id)


func _get_progress(condition_type: AchievementData.ConditionType) -> int:
	return _achievement_progress.get(str(condition_type), 0)


func _get_total_runs() -> int:
	var player_data: Dictionary = SaveManager.load_player_data()
	return player_data.get("total_runs", 0)


func _get_unlocked_partner_count() -> int:
	var player_data: Dictionary = SaveManager.load_player_data()
	return player_data.get("unlocked_partners", []).size()


## ========== 解锁流程 ==========

func _unlock_achievement(achievement_id: String) -> void:
	if _is_unlocked(achievement_id):
		return
	
	_unlocked_achievements.append(achievement_id)
	
	var data: Dictionary = AchievementData.get_achievement(achievement_id)
	
	## 金币奖励
	var reward: int = data.get("reward_gold", 0)
	if reward > 0:
		SaveManager.add_mocheng_coin(reward)
		reward_granted.emit(reward)
	
	## 伙伴解锁奖励
	var reward_partner: String = data.get("reward_partner", "")
	if not reward_partner.is_empty():
		_unlock_partner(reward_partner)
	
	_save_to_disk()
	
	achievement_unlocked.emit(achievement_id, data)
	EventBus.emit_signal("achievement_unlocked", achievement_id, data)
	
	_show_unlock_notification(achievement_id, data)


func _unlock_partner(partner_key: String) -> void:
	var cfg: Dictionary = ConfigManager.get_partner_config(partner_key)
	if cfg.is_empty():
		push_warning("[AchievementManager] 尝试解锁不存在的伙伴: %s" % partner_key)
		return
	
	var unlock_state: Dictionary = SaveManager.load_unlock_state()
	var unlocked: Array = unlock_state.get("unlocked_partners", [])
	var partner_id: int = cfg.get("id", 0)
	if partner_id <= 0:
		return
	
	for u in unlocked:
		if int(u) == partner_id:
			return  ## 已解锁
	
	unlocked.append(partner_id)
	var unlocked_heroes: Array[int] = unlock_state.get("unlocked_heroes", [1])
	SaveManager.save_unlock_state(unlocked_heroes, unlocked, unlock_state.get("unlocked_skins", []))
	print("[AchievementManager] 成就解锁伙伴: %s (id=%d)" % [partner_key, partner_id])


func _is_unlocked(achievement_id: String) -> bool:
	return _unlocked_achievements.has(achievement_id)


## ========== 解锁通知UI ==========

var _notification_queue: Array = []
var _notification_visible: bool = false


func _show_unlock_notification(achievement_id: String, data: Dictionary) -> void:
	_notification_queue.append({"id": achievement_id, "data": data})
	if not _notification_visible:
		_process_notification_queue()


func _process_notification_queue() -> void:
	if _notification_queue.is_empty():
		_notification_visible = false
		return
	
	_notification_visible = true
	var item = _notification_queue.pop_front()
	
	var notification_scene = load("res://scenes/ui/achievement_unlock_notification.tscn")
	if notification_scene == null:
		_notification_visible = false
		_process_notification_queue()
		return
	
	var notification = notification_scene.instantiate()
	notification.setup(item["data"])
	
	var canvas := CanvasLayer.new()
	canvas.layer = 90
	canvas.name = "AchievementNotification"
	get_tree().root.add_child(canvas)
	canvas.add_child(notification)
	
	notification.tree_exited.connect(func():
		# 移除空的 CanvasLayer
		if is_instance_valid(canvas) and canvas.get_child_count() == 0:
			canvas.queue_free()
		_process_notification_queue()
	)
	
	AudioManager.play_ui("achievement")


## ========== 查询API ==========

func get_unlocked_ids() -> Array[String]:
	return _unlocked_achievements.duplicate()

func get_unlock_count() -> int:
	return _unlocked_achievements.size()

func get_total_count() -> int:
	return AchievementData.ACHIEVEMENTS.size()

func is_unlocked(achievement_id: String) -> bool:
	return _is_unlocked(achievement_id)

func get_progress_percent(achievement_id: String) -> float:
	var data: Dictionary = AchievementData.get_achievement(achievement_id)
	if data.is_empty():
		return 0.0
	
	var condition_type: int = data.get("condition_type", -1)
	var target: int = data.get("target_value", 1)
	
	if condition_type == AchievementData.ConditionType.REACH_FLOOR or condition_type == AchievementData.ConditionType.TURN_CLEAR or condition_type == AchievementData.ConditionType.SCORE_GRADE or condition_type == AchievementData.ConditionType.MAX_HP_REACH:
		return 0.0
	
	var current: int = _achievement_progress.get(str(condition_type), 0)
	return clampf(float(current) / float(target), 0.0, 1.0)


## ========== 迁移旧版成就 ==========

func migrate_legacy_achievements() -> void:
	var player_data: Dictionary = SaveManager.load_player_data()
	var legacy: Dictionary = player_data.get("achievements", {})
	if legacy.is_empty():
		return
	
	var legacy_to_new: Dictionary = {
		"first_run": "first_step",
		"first_victory": "first_victory",
		"veteran_runner": "veteran",
		"gold_hoarder": "gold_hoarder",
		"elite_killer": "elite_killer",
	}
	
	var migrated_count := 0
	for old_id in legacy.keys():
		if not legacy.get(old_id, false):
			continue
		var new_id: String = legacy_to_new.get(old_id, "")
		if new_id.is_empty():
			continue
		if not _is_unlocked(new_id):
			_unlocked_achievements.append(new_id)
			migrated_count += 1
	
	player_data.erase("achievements")
	_save_to_disk()
	if migrated_count > 0:
		print("[AchievementManager] 迁移旧版成就: %d 个" % migrated_count)


## ========== 调试 ==========

func force_unlock(achievement_id: String) -> void:
	_unlock_achievement(achievement_id)

func reset_all() -> void:
	_unlocked_achievements.clear()
	_achievement_progress.clear()
	_save_to_disk()
