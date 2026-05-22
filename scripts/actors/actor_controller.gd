class_name ActorController
extends Node2D

## 纸片人角色动画控制器
## 每个动作是一套完整的 SpriteFrames，通过切换动画 + Tween 位移/旋转/缩放
## 来模拟纸片人打架的感觉。
##
## 受 FNF Character.hx 启发：
## - JSON/Resource 驱动配置
## - 动画偏移表解决不同姿势中心点对齐
## - specialAnim 锁防止状态冲突
## - 自动回退到 idle

@export var actor_data: ActorData

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# 状态机变量（对应 FNF 的 holdTimer / specialAnim / danceIdle）
var _hold_timer: float = 0.0
var _special_anim: bool = false
var _idle_anim_name: String = "idle"
var _is_dead: bool = false

# 动画偏移缓存: anim_name -> Vector2
var _anim_offsets: Dictionary = {}

# Tween 引用（防止冲突）
var _pose_tween: Tween = null
var _move_tween: Tween = null

# 原始变换（用于受击后恢复）
var _orig_position: Vector2 = Vector2.ZERO
var _orig_rotation: float = 0.0
var _orig_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	# 缓存原始变换
	_orig_position = position
	_orig_rotation = rotation
	_orig_scale = scale
	
	# 初始化动画偏移表
	if actor_data != null:
		for anim in actor_data.animations:
			_anim_offsets[anim.name] = anim.offset
		
		# 检测 danceIdle 模式
		if sprite.sprite_frames != null:
			if sprite.sprite_frames.has_animation("danceLeft") and sprite.sprite_frames.has_animation("danceRight"):
				_idle_anim_name = "danceLeft"  # 第一帧从 danceLeft 开始
			elif sprite.sprite_frames.has_animation("idle"):
				_idle_anim_name = "idle"
		
		# 应用全局缩放
		scale = Vector2.ONE * actor_data.scale
		_orig_scale = scale
	
	# 播放初始 idle
	_return_to_idle()


# ==========================================
# 公共接口
# ==========================================

## 通过统一动作名播放动画（自动查找 action_map 映射）
func play_mapped(action: String, force: bool = false) -> void:
	var anim_name: String = action
	if actor_data != null and actor_data.action_map.has(action):
		anim_name = actor_data.action_map[action]
	play_anim(anim_name, force)

## 播放普通动画（可被其他动画覆盖）
func play_anim(anim_name: String, force: bool = false) -> void:
	if _is_dead:
		return
	_special_anim = false
	_hold_timer = 0.0
	
	if sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim_name):
		push_warning("[ActorController] 动画不存在: %s" % anim_name)
		return
	
	sprite.play(anim_name)
	_apply_anim_offset(anim_name)


## 播放特殊动画（带锁，期间不自动回 idle）
## duration: 动画持续时间，超时自动解锁并回 idle
func play_special(anim_name: String, duration: float = 1.0) -> void:
	if _is_dead:
		return
	_special_anim = true
	_hold_timer = 0.0
	play_anim(anim_name, true)
	
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self) and not _is_dead:
		_special_anim = false
		_return_to_idle()


## 攻击动作：切动画 + 向前冲刺 Tween
## 返回 Tween 以便调用者连接完成信号
func play_attack(dir: float = 1.0, dash_distance: float = 30.0, duration: float = 0.2) -> Tween:
	if _is_dead:
		return null
	
	# 停止旧的移动 tween
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	
	play_special("attack", duration + 0.1)
	
	# 向前冲刺
	_move_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position:x", _orig_position.x + dir * dash_distance, duration * 0.4)
	_move_tween.tween_property(self, "position:x", _orig_position.x, duration * 0.6)
	
	return _move_tween


## 受击动作：向后震动 + 红色闪白
func play_hurt(dir: float = -1.0, shake: float = 8.0, is_crit: bool = false) -> void:
	if _is_dead:
		return
	
	var actual_shake: float = shake * (1.5 if is_crit else 1.0)
	
	# 停止旧的 pose tween
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	
	play_anim("hurt", true)
	
	_pose_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(self, "position:x", _orig_position.x + dir * actual_shake, 0.06)
	_pose_tween.parallel().tween_property(self, "rotation", dir * 0.08, 0.06)
	_pose_tween.tween_property(self, "position:x", _orig_position.x, 0.15)
	_pose_tween.parallel().tween_property(self, "rotation", 0.0, 0.15)
	
	# 闪白
	_flash_white(0.1)


## 死亡动作：灰度化 + 淡出
func play_death(duration: float = 1.0) -> void:
	_is_dead = true
	
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	
	play_anim("dead", true)
	
	# 灰度 + 淡出
	var tween := create_tween()
	tween.tween_property(self, "modulate:s", 0.0, duration * 0.5)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.5)


## 大招动作：放大 + 发光 + 向前突进
func play_ultimate(dir: float = 1.0) -> Tween:
	if _is_dead:
		return null
	
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	
	play_special("ultimate", 0.8)
	
	_pose_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(self, "scale", _orig_scale * 1.2, 0.2)
	_pose_tween.tween_property(self, "scale", _orig_scale, 0.3)
	_pose_tween.parallel().tween_property(self, "position:x", _orig_position.x + dir * 40, 0.15)
	_pose_tween.tween_property(self, "position:x", _orig_position.x, 0.2)
	
	return _pose_tween


## 复活/重置
func reset() -> void:
	_is_dead = false
	_special_anim = false
	_hold_timer = 0.0
	modulate = Color(1, 1, 1, 1)
	position = _orig_position
	rotation = _orig_rotation
	scale = _orig_scale
	_return_to_idle()


# ==========================================
# 内部方法
# ==========================================

func _process(delta: float) -> void:
	if _is_dead:
		return
	
	# 自动回 idle 逻辑（类似 FNF 的 holdTimer）
	if not _special_anim:
		var current_anim: String = sprite.animation if sprite.sprite_frames != null else ""
		if current_anim != _idle_anim_name and current_anim != "":
			_hold_timer += delta
			# 默认 0.8 秒后回 idle（可通过 actor_data 配置）
			var return_time: float = actor_data.idle_return_time if actor_data != null else 0.8
			if _hold_timer >= return_time:
				_hold_timer = 0.0
				_return_to_idle()
		else:
			_hold_timer = 0.0


func _return_to_idle() -> void:
	if _is_dead or _special_anim:
		return
	
	if sprite.sprite_frames == null:
		return
	
	# danceIdle 模式：左右交替
	if sprite.sprite_frames.has_animation("danceLeft") and sprite.sprite_frames.has_animation("danceRight"):
		# 简单交替：根据时间奇偶切换
		var use_right: bool = (Time.get_ticks_msec() / 500) % 2 == 0
		_idle_anim_name = "danceRight" if use_right else "danceLeft"
	elif sprite.sprite_frames.has_animation("idle"):
		_idle_anim_name = "idle"
	else:
		return  # 没有 idle 动画
	
	sprite.play(_idle_anim_name)
	_apply_anim_offset(_idle_anim_name)


func _apply_anim_offset(anim_name: String) -> void:
	if _anim_offsets.has(anim_name):
		sprite.offset = _anim_offsets[anim_name]
	else:
		sprite.offset = Vector2.ZERO


func _flash_white(duration: float) -> void:
	var orig_mod: Color = modulate
	modulate = Color(2.0, 2.0, 2.0, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", orig_mod, duration)
