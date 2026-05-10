## res://scripts/models/fighter_archive_score.gd
## 模块: FighterArchiveScore
## 职责: 档案评分明细数据模型 (v2.0 四维度评分)
## 依赖: 无
## class_name: FighterArchiveScore

class_name FighterArchiveScore
extends RefCounted

var id: String = ""
var archive_id: String = ""

# v2.0 四维度评分
var final_performance_raw: float = 0.0
var final_performance_weighted: float = 0.0

var attr_total_raw: float = 0.0
var attr_total_weighted: float = 0.0

var level_score_raw: float = 0.0
var level_score_weighted: float = 0.0

var gold_score_raw: float = 0.0
var gold_score_weighted: float = 0.0

var total_score: float = 0.0
var grade: String = ""
var created_at: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"archive_id": archive_id,
		"final_performance_raw": final_performance_raw,
		"final_performance_weighted": final_performance_weighted,
		"attr_total_raw": attr_total_raw,
		"attr_total_weighted": attr_total_weighted,
		"level_score_raw": level_score_raw,
		"level_score_weighted": level_score_weighted,
		"gold_score_raw": gold_score_raw,
		"gold_score_weighted": gold_score_weighted,
		"total_score": total_score,
		"grade": grade,
		"created_at": created_at,
	}


static func from_dict(data: Dictionary) -> FighterArchiveScore:
	var s := FighterArchiveScore.new()
	s.id = data.get("id", "")
	s.archive_id = data.get("archive_id", "")
	s.final_performance_raw = data.get("final_performance_raw", 0.0)
	s.final_performance_weighted = data.get("final_performance_weighted", 0.0)
	s.attr_total_raw = data.get("attr_total_raw", 0.0)
	s.attr_total_weighted = data.get("attr_total_weighted", 0.0)
	s.level_score_raw = data.get("level_score_raw", 0.0)
	s.level_score_weighted = data.get("level_score_weighted", 0.0)
	s.gold_score_raw = data.get("gold_score_raw", 0.0)
	s.gold_score_weighted = data.get("gold_score_weighted", 0.0)
	s.total_score = data.get("total_score", 0.0)
	s.grade = data.get("grade", "")
	s.created_at = data.get("created_at", 0)
	return s
