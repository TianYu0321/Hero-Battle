## res://scripts/systems/leaderboard_system.gd
## 模块: LeaderboardSystem
## 职责: 本地排行榜管理：读取 archive.json，按 total_score 降序排序，支持过滤，缓存上次排名
## 依赖: ConfigManager, EventBus
## class_name: LeaderboardSystem

class_name LeaderboardSystem
extends Node

const _DEFAULT_LIMIT: int = 10

var _prev_leaderboard: Array[Dictionary] = []
var _prev_archive_ids: Dictionary = {}

func get_leaderboard(limit: int = _DEFAULT_LIMIT, filter_hero: String = "") -> Array[Dictionary]:
	var archives: Array[Dictionary] = SaveManager.load_archives("date", 9999, filter_hero)
	# 按档案级净胜场降序排序
	archives.sort_custom(func(a, b): return a.get("net_wins", 0) > b.get("net_wins", 0))
	var result: Array[Dictionary] = []

	# 构建当前排名映射
	var current_ids: Dictionary = {}
	for i in range(archives.size()):
		var entry: Dictionary = archives[i]
		var rank: int = i + 1
		var archive_id: String = entry.get("archive_id", "")
		current_ids[archive_id] = rank

		var prev_rank: int = -1
		if _prev_archive_ids.has(archive_id):
			prev_rank = _prev_archive_ids[archive_id]

		result.append({
			"rank": rank,
			"prev_rank": prev_rank,
			"archive_id": archive_id,
			"hero_name": entry.get("hero_name", ""),
			"rating": entry.get("final_grade", entry.get("rating", "")),
			"total_score": entry.get("final_score", entry.get("total_score", 0)),
			"date": _format_date(entry.get("created_at", 0)),
		})

		if rank >= limit:
			break

	# 保存本次排名用于下次对比
	_prev_leaderboard = result.duplicate(true)
	_prev_archive_ids = current_ids.duplicate()
	return result


func get_rank_change_indicator(rank: int, prev_rank: int) -> String:
	if prev_rank < 0:
		return "NEW"
	if rank < prev_rank:
		return "↑"
	if rank > prev_rank:
		return "↓"
	return "—"


func clear_cache() -> void:
	_prev_leaderboard.clear()
	_prev_archive_ids.clear()


func _format_date(unix_time: int) -> String:
	if unix_time <= 0:
		return ""
	return Time.get_datetime_string_from_unix_time(unix_time, true).split(" ")[0]
