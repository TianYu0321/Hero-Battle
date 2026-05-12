## res://scripts/systems/pvp_penalty_strategy.gd
## 模块: IPVPPenaltyStrategy (接口)
## 职责: PVP惩罚策略接口
## 设计原则: 策略模式 -- 行为变化用策略而非if-else

class_name IPVPPenaltyStrategy
extends RefCounted

## 计算惩罚
## @param pvp_config: PVP配置数据
## @param turn_number: PVP层数(10或20)
## @param player_won: 玩家是否胜利
## @return: {penalty_tier, penalty_value, penalty_desc}
func calculate_penalty(_pvp_config: Dictionary, _turn_number: int, _player_won: bool) -> Dictionary:
    push_error("IPVPPenaltyStrategy.calculate_penalty: must override")
    return {"penalty_tier": "none", "penalty_value": 0, "penalty_desc": ""}

## 是否影响HP/金币
## @return: true表示惩罚会修改玩家HP/金币
func affects_player_stats() -> bool:
    return false

## 获取惩罚描述（用于UI展示）
func get_penalty_description() -> String:
    return ""
