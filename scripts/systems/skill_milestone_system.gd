## res://scripts/systems/skill_milestone_system.gd
## 模块: SkillMilestoneSystem
## 职责: 技能质变系统 — 监听伙伴/主角等级变更，触发技能效果升级
## 规格依据: v2补充说明 "Lv2→3技能额外效果，Lv4→5数值提升"
## 设计原则: 观察者模式 — 监听等级变更事件，自动触发升级；事件携带完整上下文

class_name SkillMilestoneSystem
extends Node

## 质变等级常量
const _MILESTONE_LV3: int = 3
const _MILESTONE_LV5: int = 5

## 伙伴Lv3质变效果配置 — 按effect类型映射
const _LV3_EFFECT_MAP: Dictionary = {
    "damage": {"extra_effect": "defense_down", "extra_value": 0.15},
    "heal":   {"extra_effect": "hot",          "extra_value": 0.05},
    "shield": {"extra_effect": "reflect",      "extra_value": 0.20},
}

## 伙伴Lv5数值提升倍率
const _LV5_SCALE: float = 1.5

## 主角被动技能Lv3质变配置
const _HERO_LV3_PASSIVE_MAP: Dictionary = {
    8001: {"extra_effect": "combo_boost", "extra_value": 0.1, "desc": "连击概率+10%"},
    8003: {"extra_effect": "bleed",       "extra_value": 0.05, "desc": "添加流血效果"},
    8005: {"extra_effect": "stun_boost",  "extra_value": 0.1, "desc": "眩晕概率+10%"},
}

## 主角Lv5概率提升值
const _HERO_LV5_PROB_BONUS: float = 0.1

var _character_manager: CharacterManager = null

## 初始化 — 注入依赖，订阅事件
func initialize(cm: CharacterManager) -> void:
    if cm == null:
        push_error("[SkillMilestoneSystem] CharacterManager cannot be null")
        return
    _character_manager = cm

    ## 监听等级变更事件
    if EventBus.has_signal("partner_level_changed"):
        EventBus.partner_level_changed.connect(_on_partner_level_changed)
    else:
        push_warning("[SkillMilestoneSystem] partner_level_changed signal not found")

    if EventBus.has_signal("hero_level_changed"):
        EventBus.hero_level_changed.connect(_on_hero_level_changed)
    else:
        push_warning("[SkillMilestoneSystem] hero_level_changed signal not found")


## 伙伴等级变更回调
## @param partner_id: 伙伴ID字符串
## @param old_level: 变更前等级
## @param new_level: 变更后等级
func _on_partner_level_changed(partner_id: String, old_level: int, new_level: int) -> void:
    if _is_milestone_reached(old_level, new_level, _MILESTONE_LV3):
        _apply_partner_lv3_milestone(partner_id)
    if _is_milestone_reached(old_level, new_level, _MILESTONE_LV5):
        _apply_partner_lv5_milestone(partner_id)


## 主角等级变更回调
## @param old_level: 变更前等级
## @param new_level: 变更后等级
func _on_hero_level_changed(old_level: int, new_level: int) -> void:
    if _is_milestone_reached(old_level, new_level, _MILESTONE_LV3):
        _apply_hero_lv3_milestone()
    if _is_milestone_reached(old_level, new_level, _MILESTONE_LV5):
        _apply_hero_lv5_milestone()


## 检查是否跨越质变等级（纯函数）
## @return: true 当 old_lv < milestone <= new_lv（即升级跨过了质变点）
static func _is_milestone_reached(old_lv: int, new_lv: int, milestone: int) -> bool:
    return old_lv < milestone and new_lv >= milestone


## 应用伙伴Lv3质变: 技能额外效果
func _apply_partner_lv3_milestone(partner_id: String) -> void:
    var assist_cfg: Dictionary = ConfigManager.get_partner_assist_by_partner_id(partner_id)
    if assist_cfg.is_empty():
        push_warning("[SkillMilestone] 伙伴%s无援助配置，跳过Lv3质变" % partner_id)
        return

    var effect: String = assist_cfg.get("effect", "")
    var extra: Dictionary = _LV3_EFFECT_MAP.get(effect, {})

    if extra.is_empty():
        push_warning("[SkillMilestone] 伙伴%s效果类型'%s'无Lv3质变配置" % [partner_id, effect])
        return

    ## 防御式：不直接修改原始配置，通过ConfigManager或运行时覆盖
    assist_cfg["extra_effect"] = extra.get("extra_effect", "")
    assist_cfg["extra_value"] = extra.get("extra_value", 0.0)

    var extra_effect_name: String = extra.get("extra_effect", "")
    EventBus.skill_milestone_reached.emit(partner_id, 3, extra_effect_name)
    print("[SkillMilestone] 伙伴 %s 达到Lv3质变: %s" % [partner_id, extra_effect_name])


## 应用伙伴Lv5质变: 数值提升
func _apply_partner_lv5_milestone(partner_id: String) -> void:
    var assist_cfg: Dictionary = ConfigManager.get_partner_assist_by_partner_id(partner_id)
    if assist_cfg.is_empty():
        push_warning("[SkillMilestone] 伙伴%s无援助配置，跳过Lv5质变" % partner_id)
        return

    ## 所有效果数值 × 1.5倍
    if assist_cfg.has("damage_scale"):
        assist_cfg["damage_scale"] = float(assist_cfg["damage_scale"]) * _LV5_SCALE
    if assist_cfg.has("heal_scale"):
        assist_cfg["heal_scale"] = float(assist_cfg["heal_scale"]) * _LV5_SCALE
    if assist_cfg.has("shield_value"):
        assist_cfg["shield_value"] = int(float(assist_cfg["shield_value"]) * _LV5_SCALE)

    EventBus.skill_milestone_reached.emit(partner_id, 5, "数值提升x%.1f" % _LV5_SCALE)
    print("[SkillMilestone] 伙伴 %s 达到Lv5质变: 数值x%.1f" % [partner_id, _LV5_SCALE])


## 应用主角Lv3质变: 被动技能额外效果
func _apply_hero_lv3_milestone() -> void:
    if _character_manager == null:
        push_warning("[SkillMilestone] CharacterManager未初始化，跳过主角Lv3质变")
        return

    var hero = _character_manager.get_hero()
    if hero == null:
        push_warning("[SkillMilestone] 主角未初始化，跳过Lv3质变")
        return

    var passive_id: int = hero.passive_skill_id
    var passive_cfg: Dictionary = ConfigManager.get_skill_config(str(passive_id))
    if passive_cfg.is_empty():
        push_warning("[SkillMilestone] 被动技能%d无配置，跳过Lv3质变" % passive_id)
        return

    var extra: Dictionary = _HERO_LV3_PASSIVE_MAP.get(passive_id, {})
    if extra.is_empty():
        ## 无特定配置的被动技能，给一个通用增强
        extra = {"extra_effect": "generic_boost", "extra_value": 0.05, "desc": "全属性+5%"}

    passive_cfg["extra_effect"] = extra.get("extra_effect", "")
    passive_cfg["extra_value"] = extra.get("extra_value", 0.0)

    var extra_effect_name: String = extra.get("extra_effect", "")
    EventBus.hero_skill_milestone_reached.emit(3, extra_effect_name)
    print("[SkillMilestone] 主角达到Lv3质变: %s (%s)" % [extra_effect_name, extra.get("desc", "")])


## 应用主角Lv5质变: 概率提升
func _apply_hero_lv5_milestone() -> void:
    if _character_manager == null:
        push_warning("[SkillMilestone] CharacterManager未初始化，跳过主角Lv5质变")
        return

    var hero = _character_manager.get_hero()
    if hero == null:
        push_warning("[SkillMilestone] 主角未初始化，跳过Lv5质变")
        return

    var passive_cfg: Dictionary = ConfigManager.get_skill_config(str(hero.passive_skill_id))
    if passive_cfg.is_empty():
        push_warning("[SkillMilestone] 被动技能%d无配置，跳过Lv5质变" % hero.passive_skill_id)
        return

    ## 概率 +10%
    if passive_cfg.has("prob_base"):
        passive_cfg["prob_base"] = float(passive_cfg["prob_base"]) + _HERO_LV5_PROB_BONUS
        EventBus.hero_skill_milestone_reached.emit(5, "概率+%.0f%%" % (_HERO_LV5_PROB_BONUS * 100.0))
        print("[SkillMilestone] 主角达到Lv5质变: 概率+%.0f%%" % (_HERO_LV5_PROB_BONUS * 100.0))
    else:
        ## 无概率字段时，给一个通用数值提升
        passive_cfg["generic_bonus"] = _HERO_LV5_PROB_BONUS
        EventBus.hero_skill_milestone_reached.emit(5, "通用+%.0f%%" % (_HERO_LV5_PROB_BONUS * 100.0))
        print("[SkillMilestone] 主角达到Lv5质变: 通用+%.0f%%" % (_HERO_LV5_PROB_BONUS * 100.0))


## 清理 — 断开信号连接
func cleanup() -> void:
    if EventBus.has_signal("partner_level_changed"):
        if EventBus.partner_level_changed.is_connected(_on_partner_level_changed):
            EventBus.partner_level_changed.disconnect(_on_partner_level_changed)
    if EventBus.has_signal("hero_level_changed"):
        if EventBus.hero_level_changed.is_connected(_on_hero_level_changed):
            EventBus.hero_level_changed.disconnect(_on_hero_level_changed)
