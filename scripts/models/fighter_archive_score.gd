## res://scripts/models/fighter_archive_score.gd
## 模块: FighterArchiveScore
## 职责: 档案评分明细数据模型
## 依赖: 无
## class_name: FighterArchiveScore

class_name FighterArchiveScore
extends RefCounted

var id: String = ""
var archive_id: String = ""
var final_performance_raw: float = 0.0
var final_performance_weighted: float = 0.0
var training_efficiency_raw: float = 0.0
var training_efficiency_weighted: float = 0.0
var pvp_performance_raw: float = 0.0
var pvp_performance_weighted: float = 0.0
var build_purity_raw: float = 0.0
var build_purity_weighted: float = 0.0
var chain_showcase_raw: float = 0.0
var chain_showcase_weighted: float = 0.0
var total_score: float = 0.0
var grade: String = ""
var created_at: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"archive_id": archive_id,
		"final_performance_raw": final_performance_raw,
		"final_performance_weighted": final_performance_weighted,
		"training_efficiency_raw": training_efficiency_raw,
		"training_efficiency_weighted": training_efficiency_weighted,
		"pvp_performance_raw": pvp_performance_raw,
		"pvp_performance_weighted": pvp_performance_weighted,
		"build_purity_raw": build_purity_raw,
		"build_purity_weighted": build_purity_weighted,
		"chain_showcase_raw": chain_showcase_raw,
		"chain_showcase_weighted": chain_showcase_weighted,
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
	s.training_efficiency_raw = data.get("training_efficiency_raw", 0.0)
	s.training_efficiency_weighted = data.get("training_efficiency_weighted", 0.0)
	s.pvp_performance_raw = data.get("pvp_performance_raw", 0.0)
	s.pvp_performance_weighted = data.get("pvp_performance_weighted", 0.0)
	s.build_purity_raw = data.get("build_purity_raw", 0.0)
	s.build_purity_weighted = data.get("build_purity_weighted", 0.0)
	s.chain_showcase_raw = data.get("chain_showcase_raw", 0.0)
	s.chain_showcase_weighted = data.get("chain_showcase_weighted", 0.0)
	s.total_score = data.get("total_score", 0.0)
	s.grade = data.get("grade", "")
	s.created_at = data.get("created_at", 0)
	return s
