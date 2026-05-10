## res://scripts/systems/null_penalty_strategy.gd
## 模块: NullPenaltyStrategy
## 职责: v2.0 -- PVP失败无惩罚
## 规格依据: v2.0(1)明确"失败不处罚，只影响奖励"

class_name NullPenaltyStrategy
extends IPVPPenaltyStrategy

func calculate_penalty(_pvp_config: Dictionary, _turn_number: int, _player_won: bool) -> Dictionary:
    return {
        "penalty_tier": "none",
        "penalty_value": 0,
        "penalty_desc": "v2.0: PVP失败不影响HP和金币"
    }

func affects_player_stats() -> bool:
    return false

func get_penalty_description() -> String:
    return "PVP失败不影响HP和金币（v2.0规则）"
