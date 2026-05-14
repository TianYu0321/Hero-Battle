## res://scripts/systems/shadow_ai_controller.gd
## 模块: ShadowAIController
## 职责: 影子AI战斗风格标记（激进/防御/平衡）
## 说明: 当前版本作为影子数据的策略标签容器，实际战斗策略由BattleEngine内部控制
## class_name: ShadowAIController

class_name ShadowAIController
extends Node

var _combat_style: Array[String] = []

func setup(style_tags: Array[String]) -> void:
	_combat_style = style_tags.duplicate()

func get_combat_style() -> Array[String]:
	return _combat_style.duplicate()

func is_aggressive() -> bool:
	return "aggressive" in _combat_style

func is_defensive() -> bool:
	return "defensive" in _combat_style

func is_balanced() -> bool:
	return _combat_style.is_empty() or "balanced" in _combat_style

## 根据战斗风格返回策略描述（用于UI展示）
func get_strategy_description() -> String:
	if is_aggressive():
		return "激进型：优先攻击，血量低也不退缩"
	elif is_defensive():
		return "防御型：血量低时优先防御"
	else:
		return "平衡型：攻守兼备"
