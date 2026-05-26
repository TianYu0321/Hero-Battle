## res://scenes/effects/feedback_manager.gd
## 模块: FeedbackManager
## 职责: 统一打击感反馈接口，整合 ComicSFX + FloatingText + ScreenShake + HitPause
## 依赖: ComicSFXData, ScreenShake, HitPause
## 被依赖: 战斗场景

extends Node

@onready var _combat_text_layer: CanvasLayer = null

func _ready() -> void:
	_setup_combat_text_layer()

func _setup_combat_text_layer() -> void:
	_combat_text_layer = CanvasLayer.new()
	_combat_text_layer.layer = 50
	_combat_text_layer.name = "CombatTextLayer"
	get_tree().root.add_child(_combat_text_layer)

## ========== 主要API ==========

func play_attack_feedback(
	target_position: Vector2,
	damage: int,
	is_crit: bool = false,
	is_heal: bool = false,
	is_missed: bool = false,
	is_blocked: bool = false,
	is_kill: bool = false,
	attacker_direction: Vector2 = Vector2.RIGHT
) -> void:
	## 统一的攻击反馈调用
	
	## 1. 浮动数字
	if not is_missed:
		_spawn_floating_text(target_position, damage, is_heal, is_crit, is_missed)
	else:
		_spawn_floating_text(target_position, 0, false, false, true)
	
	## 2. 漫画拟声词
	var sfx_type := _determine_sfx_type(is_crit, is_heal, is_missed, is_blocked, is_kill, damage)
	_spawn_comic_sfx(sfx_type, target_position, attacker_direction)
	
	## 3. 屏幕震动
	var shake_amount := _calculate_shake_amount(is_crit, is_kill, damage)
	if shake_amount > 0:
		ScreenShake.add_trauma(shake_amount)
	
	## 4. 受击停顿
	var pause_duration := _calculate_pause_duration(is_crit, is_kill)
	if pause_duration > 0:
		HitPause.trigger(pause_duration)

func play_damage_only(position: Vector2, damage: int, is_crit: bool = false) -> void:
	## 仅显示伤害数字（无其他效果）
	_spawn_floating_text(position, damage, false, is_crit, false)

func play_sfx_only(sfx_type: ComicSFXData.SFXType, position: Vector2, direction: Vector2 = Vector2.UP) -> void:
	## 仅显示拟声词
	_spawn_comic_sfx(sfx_type, position, direction)

func play_shake(amount: float) -> void:
	## 仅震动
	ScreenShake.add_trauma(amount)

func play_hit_pause(duration_ms: float) -> void:
	## 仅停顿
	HitPause.trigger(duration_ms)

## ========== 内部方法 ==========

func _spawn_floating_text(position: Vector2, value: int, is_heal: bool, is_crit: bool, is_missed: bool) -> void:
	var label := Label.new()
	label.set_script(load("res://scenes/effects/floating_text.gd"))
	
	_combat_text_layer.add_child(label)
	
	## 随机偏移，避免重叠
	var random_offset := Vector2(randf_range(-30, 30), randf_range(-20, 0))
	label.setup(value, is_heal, is_crit, is_missed, position + random_offset)

func _spawn_comic_sfx(sfx_type: ComicSFXData.SFXType, position: Vector2, direction: Vector2) -> void:
	var label := Label.new()
	label.set_script(load("res://scenes/effects/comic_sfx_label.gd"))
	
	_combat_text_layer.add_child(label)
	
	## 拟声词在目标上方略偏
	var offset := Vector2(randf_range(-40, 40), -randf_range(50, 90))
	label.setup(sfx_type, position + offset, direction)

func _determine_sfx_type(is_crit: bool, is_heal: bool, is_missed: bool, is_blocked: bool, is_kill: bool, damage: int) -> ComicSFXData.SFXType:
	if is_kill:
		return ComicSFXData.SFXType.KILL
	elif is_heal:
		return ComicSFXData.SFXType.HEAL
	elif is_missed:
		return ComicSFXData.SFXType.MISS
	elif is_blocked:
		return ComicSFXData.SFXType.BLOCK
	elif is_crit:
		return ComicSFXData.SFXType.HIT_CRIT
	elif damage >= 50:
		return ComicSFXData.SFXType.HIT_HEAVY
	elif damage >= 20:
		return ComicSFXData.SFXType.HIT_NORMAL
	else:
		return ComicSFXData.SFXType.HIT_LIGHT

func _calculate_shake_amount(is_crit: bool, is_kill: bool, damage: int) -> float:
	if is_kill:
		return 0.6
	elif is_crit:
		return 0.5
	elif damage >= 50:
		return 0.3
	elif damage >= 20:
		return 0.15
	else:
		return 0.05

func _calculate_pause_duration(is_crit: bool, is_kill: bool) -> float:
	## 返回毫秒数
	if is_kill:
		return 120.0
	elif is_crit:
		return 80.0
	else:
		return 0.0
