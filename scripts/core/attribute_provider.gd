## res://scripts/core/attribute_provider.gd
## 模块: IAttributeProvider (接口)
## 职责: 属性提供器接口 -- 解耦ActionOrder与具体属性来源
## 设计原则: 依赖倒置 -- ActionOrder依赖接口而非实现

class_name IAttributeProvider
extends RefCounted

## 获取速度值
## v2.0: 速度 = 基础值(10) + 敏捷x系数 + 招式加成 + BUFF加成
## @param unit: 战斗单位数据
## @return: 速度值
func get_speed(_unit: Dictionary) -> float:
    push_error("IAttributeProvider.get_speed: must override")
    return 0.0

## 获取敏捷值
func get_agility(_unit: Dictionary) -> int:
    push_error("IAttributeProvider.get_agility: must override")
    return 0

## 获取BUFF列表
func get_buffs(unit: Dictionary) -> Array:
    return unit.get("buff_list", [])
