## res://scripts/core/default_attribute_provider.gd
## 模块: DefaultAttributeProvider
## 职责: v2.0默认实现 -- 速度=10+敏捷x系数+BUFF

class_name DefaultAttributeProvider
extends IAttributeProvider

const _BASE_SPEED: float = 10.0
const _AGI_COEFF: float = 1.0

func get_speed(unit: Dictionary) -> float:
    var agi: int = get_agility(unit)
    var buff_bonus: float = _calc_buff_speed_bonus(unit)
    return _BASE_SPEED + float(agi) * _AGI_COEFF + buff_bonus

func get_agility(unit: Dictionary) -> int:
    return unit.get("stats", {}).get("agility", 0)

func _calc_buff_speed_bonus(unit: Dictionary) -> float:
    var bonus: float = 0.0
    for buff in unit.get("buff_list", []):
        if buff.get("type", "") == "speed_up":
            bonus += buff.get("value", 0)
    return bonus
