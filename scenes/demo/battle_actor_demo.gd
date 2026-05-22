extends Control

## SD 纸片小剧场风格验证 Demo
## 核心：完整 Pose 单帧 + 翻面切换 + Tween 整体变换 + 外部反馈

@onready var hero_actor: Node2D = $HeroActor
@onready var enemy_actor: Node2D = $EnemyActor
@onready var partner_actor: Node2D = $PartnerActor
@onready var hero_sprite: Sprite2D = $HeroActor/Sprite2D
@onready var enemy_sprite: Sprite2D = $EnemyActor/Sprite2D
@onready var partner_sprite: Sprite2D = $PartnerActor/Sprite2D

@onready var hero_hp_bar: ProgressBar = $UI/HeroHP
@onready var enemy_hp_bar: ProgressBar = $UI/EnemyHP
@onready var hero_hp_label: Label = $UI/HeroHP/HPLabel
@onready var enemy_hp_label: Label = $UI/EnemyHP/HPLabel
@onready var damage_container: Control = $DamageContainer
@onready var log_label: RichTextLabel = $UI/LogLabel
@onready var victory_panel: Panel = $UI/VictoryPanel
@onready var sfx_layer: Node2D = $SfxLayer

var _hero_hp: int = 1000
var _hero_max_hp: int = 1000
var _enemy_hp: int = 1000
var _enemy_max_hp: int = 1000

var _hero_orig_pos: Vector2
var _enemy_orig_pos: Vector2
var _partner_hide_pos: Vector2 = Vector2(2100, 620)
var _partner_show_pos: Vector2 = Vector2(1700, 620)

var _is_animating: bool = false

var _sfx_attack: Array[String] = ["啪！", "斩！", "嗖！", "唰！"]
var _sfx_crit: Array[String] = ["砰！", "Duang!", "哐！", "咚！"]
var _sfx_support: Array[String] = ["来咯！", "援护！", "加油！"]

# 每个角色的 Pose 纹理（单帧）
var _hero_poses: Dictionary[String, Texture2D] = {}
var _enemy_poses: Dictionary[String, Texture2D] = {}
var _partner_poses: Dictionary[String, Texture2D] = {}
var _hunter_poses: Dictionary[String, Texture2D] = {}

func _ready() -> void:
	# 加载单帧 Pose 图（hero/enemy 共用 shinobi 素材）
	var _shinobi_idle := _load_tex("assets/characters/hero/shinobi/idle/shinobi_idle_01.png")
	var _shinobi_attack := _load_tex("assets/characters/hero/shinobi/attack/shinobi_attack_01.png")
	var _shinobi_hit := _load_tex("assets/characters/hero/shinobi/hit/shinobi_hit_01.png")
	var _shinobi_skill1 := _load_tex("assets/characters/hero/shinobi/skill1/shinobi_skill1_01.png")
	var _shinobi_skill2 := _load_tex("assets/characters/hero/shinobi/skill2/shinobi_skill2_01.png")
	var _shinobi_victory := _load_tex("assets/characters/hero/shinobi/victory/shinobi_victory_01.png")
	
	for key in ["idle", "attack", "hit", "skill", "skill1", "skill2", "victory"]:
		_hero_poses[key] = _shinobi_idle
		_enemy_poses[key] = _shinobi_idle
	_hero_poses["attack"] = _shinobi_attack
	_hero_poses["hit"] = _shinobi_hit
	_hero_poses["skill"] = _shinobi_skill1
	_hero_poses["skill1"] = _shinobi_skill1
	_hero_poses["skill2"] = _shinobi_skill2
	_hero_poses["victory"] = _shinobi_victory
	_enemy_poses["attack"] = _shinobi_attack
	_enemy_poses["hit"] = _shinobi_hit
	_enemy_poses["skill1"] = _shinobi_skill1
	_enemy_poses["skill2"] = _shinobi_skill2
	_enemy_poses["victory"] = _shinobi_victory

	_partner_poses["idle"] = _shinobi_idle
	_partner_poses["support_in"] = _shinobi_idle
	_partner_poses["support_action"] = _shinobi_idle

	# 初始化显示
	_set_pose(hero_sprite, _hero_poses["idle"])
	_set_pose(enemy_sprite, _enemy_poses["idle"])
	_set_pose(partner_sprite, _partner_poses["idle"])

	# 缩放 & 朝向（统一大小，敌人用 flip_h 翻转）
	hero_actor.scale = Vector2.ONE * 0.7
	enemy_actor.scale = Vector2.ONE * 0.7
	enemy_sprite.flip_h = true
	partner_actor.scale = Vector2.ONE * 0.7

	_hero_orig_pos = hero_actor.position
	_enemy_orig_pos = enemy_actor.position
	partner_actor.position = _partner_hide_pos
	partner_actor.visible = false

	# 启动 idle 呼吸动画
	_idle_breath(hero_actor, 1.0)
	_idle_breath(enemy_actor, 1.2)

	victory_panel.visible = false
	victory_panel.modulate = Color(1, 1, 1, 0)

	_update_hp_display()
	_log("[color=#F2B93D]🎭 纸片小剧场战斗 Demo 🎭[/color]")
	_log("翻面切 Pose · 拟声词 · 整体倾斜 · 支援登场")
	
	## 加载猎人 Pose
	var _hunter_idle := _load_tex("assets/characters/partner/hunter/idle/idle.png")
	var _hunter_ready := _load_tex("assets/characters/partner/hunter/ready/ready.png")
	var _hunter_action := _load_tex("assets/characters/partner/hunter/action/action.png")
	if _hunter_idle != null:
		_hunter_poses["idle"] = _hunter_idle
	if _hunter_ready != null:
		_hunter_poses["ready"] = _hunter_ready
	if _hunter_action != null:
		_hunter_poses["action"] = _hunter_action


func _load_tex(path: String) -> Texture2D:
	var full_path := "res://" + path
	if ResourceLoader.exists(full_path):
		return load(full_path) as Texture2D
	push_error("Failed to load: " + full_path)
	return null


func _set_pose(sprite: Sprite2D, tex: Texture2D) -> void:
	if tex:
		sprite.texture = tex
		# 自动居中
		sprite.centered = true


func _switch_partner_pose(sprite: Sprite2D, tex: Texture2D) -> void:
	if tex == null or sprite.texture == tex:
		return
	var old_tex: Texture2D = sprite.texture
	sprite.texture = tex
	if old_tex != null:
		var old_size: Vector2 = old_tex.get_size()
		var new_size: Vector2 = tex.get_size()
		## 保持角色中心近似不变
		sprite.position.x += (new_size.x - old_size.x) / 2.0
		sprite.position.y += (new_size.y - old_size.y) / 2.0


# ==========================================
# Idle 呼吸（整体上下浮动，不用多帧）
# ==========================================

func _idle_breath(actor: Node2D, speed: float) -> void:
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(actor, "position:y", actor.position.y - 4, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(actor, "position:y", actor.position.y + 4, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_idle_breath(actor: Node2D) -> void:
	# 停止所有作用在该 actor 上的 tween（简单处理：取消所有 tween）
	# Godot 没有简单的方式停止特定 tween，这里用 create_tween 每次都会新建
	# 我们只需要在攻击时覆盖位置 tween 即可
	pass


# ==========================================
# 翻面切 Pose（核心纸片感）
# ==========================================

func _flip_pose(actor: Node2D, sprite: Sprite2D, tex: Texture2D, duration: float = 0.18) -> void:
	if tex == null:
		return

	var orig_scale_y: float = actor.scale.y
	var sign: float = sign(actor.scale.x)
	if sign == 0:
		sign = 1

	# 1. 压缩（翻面）
	var t1: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t1.tween_property(actor, "scale:x", 0.06 * sign, duration * 0.35)
	await t1.finished

	# 2. 切换 Pose
	_set_pose(sprite, tex)

	# 3. 展开（弹回）
	var t2: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(actor, "scale:x", orig_scale_y * sign, duration * 0.65)
	await t2.finished


# ==========================================
# 拟声词
# ==========================================

func _spawn_sfx_text(pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))

	sfx_layer.add_child(label)
	label.global_position = pos

	label.scale = Vector2.ZERO
	label.rotation = randf_range(-0.15, 0.15)

	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE * 1.3, 0.12)
	tween.tween_property(label, "scale", Vector2.ONE, 0.08)

	await get_tree().create_timer(0.15).timeout

	var fade: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(label, "position:y", pos.y - 80, 0.4)
	fade.parallel().tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.15)
	fade.tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)


# ==========================================
# 伤害数字
# ==========================================

func _spawn_damage_number(pos: Vector2, damage: int, is_crit: bool) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % damage
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if is_crit:
		label.add_theme_font_size_override("font_size", 48)
		label.add_theme_color_override("font_color", Color("#DB5247"))
		label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.scale = Vector2(1.5, 1.5)
	else:
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", Color("#F2B93D"))

	damage_container.add_child(label)
	label.global_position = pos

	var tween: Tween = create_tween()
	if is_crit:
		tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2.ONE * 1.8, 0.15)
		tween.tween_property(label, "scale", Vector2.ONE * 1.3, 0.1)

	tween.tween_property(label, "position:y", pos.y - 90, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.25)
	tween.tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)


# ==========================================
# 屏幕震动 / 闪白
# ==========================================

func _screen_shake(strength: float, duration: float) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	var orig_offset: Vector2 = camera.offset
	var tween: Tween = create_tween()
	var steps: int = int(duration * 60)
	for i in range(steps):
		var offset: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength
		tween.tween_property(camera, "offset", orig_offset + offset, 0.016)
		strength *= 0.9
	tween.tween_property(camera, "offset", orig_offset, 0.05)


func _flash_sprite(sprite: Sprite2D) -> void:
	sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)


# ==========================================
# 猎人冲刺斩杀
# ==========================================

func _on_hunter_assist_pressed() -> void:
	if _is_animating or _hero_hp <= 0 or _enemy_hp <= 0:
		return
	if not _hunter_poses.has("idle") or not _hunter_poses.has("ready") or not _hunter_poses.has("action"):
		_log("[color=red]猎人素材未加载[/color]")
		return
	_is_animating = true

	_log("▸ [color=#BF4DE6]猎人 冲刺斩杀！[/color]")

	## 斩击点：敌人左侧 150px
	var slash_pos: Vector2 = enemy_actor.global_position + Vector2(-150, 0)

	var sprite := Sprite2D.new()
	sprite.texture = _hunter_poses["idle"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	sprite.global_position = slash_pos + Vector2(-700, 0)
	sfx_layer.add_child(sprite)

	## 阶段1: 登场蓄力（淡入 + scale 放大）
	var enter_tween := create_tween()
	enter_tween.set_parallel()
	enter_tween.tween_property(sprite, "modulate:a", 1.0, 0.25)
	enter_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await enter_tween.finished

	## 切换冲刺姿态
	_switch_partner_pose(sprite, _hunter_poses["ready"])

	## 开启拖尾粒子
	var dash_trail: CPUParticles2D = VFX.create_dash_trail(sprite, Vector2.ZERO)

	## 阶段2: 冲刺到斩击点
	var dash_tween := create_tween()
	dash_tween.tween_property(sprite, "global_position", slash_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await dash_tween.finished

	## 阶段3: 斩击命中
	_switch_partner_pose(sprite, _hunter_poses["action"])

	## 打击停顿（时间冻结）
	VFX.freeze_frame(0.1, 0.05)

	## 震屏 + 闪白 + 能量爆发 + 连击环
	_screen_shake(12.0, 0.25)
	_flash_sprite(enemy_sprite)
	VFX.spawn_energy_burst(slash_pos, Color(0.8, 0.3, 0.9))
	VFX.spawn_combo_ring(slash_pos)

	## 伤害
	var dmg: int = randi_range(150, 300)
	_enemy_hp = maxi(0, _enemy_hp - dmg)
	_update_hp_display()
	_spawn_damage_number(slash_pos + Vector2(0, -140), dmg, true)
	_spawn_sfx_text(slash_pos + Vector2(0, -220), "斩！", Color("#BF4DE6"))

	## 敌人受击
	_flip_pose(enemy_actor, enemy_sprite, _enemy_poses["hit"], 0.1)
	var hurt := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	hurt.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x + 40, 0.06)
	hurt.parallel().tween_property(enemy_actor, "rotation", 0.1, 0.06)
	hurt.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x, 0.15)
	hurt.parallel().tween_property(enemy_actor, "rotation", 0.0, 0.15)

	## 停留让用户看清斩击 pose
	await get_tree().create_timer(0.25).timeout

	## 关闭拖尾
	if is_instance_valid(dash_trail):
		dash_trail.emitting = false
		dash_trail.queue_free()

	## 阶段4: 穿出画面
	var exit := create_tween()
	exit.tween_property(sprite, "global_position", slash_pos + Vector2(600, 0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	exit.parallel().tween_property(sprite, "modulate:a", 0.0, 0.25)
	await exit.finished
	if is_instance_valid(sprite):
		sprite.queue_free()

	await get_tree().create_timer(0.2).timeout
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["idle"], 0.1)

	_is_animating = false
	_check_death()


# ==========================================
# 主角攻击
# ==========================================

func _on_hero_attack_pressed() -> void:
	if _is_animating or _hero_hp <= 0 or _enemy_hp <= 0:
		return
	_is_animating = true

	_log("▸ 主角 [攻击]")

	# 翻面切到攻击 Pose
	await _flip_pose(hero_actor, hero_sprite, _hero_poses["attack"], 0.15)

	# 前冲刺击（整体倾斜）
	var dash: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dash.tween_property(hero_actor, "position:x", _hero_orig_pos.x + 120, 0.1)
	dash.parallel().tween_property(hero_actor, "rotation", 0.12, 0.1)
	dash.tween_property(hero_actor, "position:x", _hero_orig_pos.x, 0.15)
	dash.parallel().tween_property(hero_actor, "rotation", 0.0, 0.15)

	await get_tree().create_timer(0.08).timeout

	# 命中
	var dmg: int = randi_range(80, 150)
	var is_crit: bool = randf() < 0.2
	if is_crit:
		dmg = int(dmg * 1.8)
	_enemy_hp = maxi(0, _enemy_hp - dmg)
	_update_hp_display()

	# 敌人受击：翻面切 hit + 后仰
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["hit"], 0.1)
	var hurt: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	hurt.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x + 30, 0.06)
	hurt.parallel().tween_property(enemy_actor, "rotation", 0.1, 0.06)
	hurt.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x, 0.15)
	hurt.parallel().tween_property(enemy_actor, "rotation", 0.0, 0.15)

	_screen_shake(4.0, 0.1)
	_flash_sprite(enemy_sprite)
	_spawn_damage_number(enemy_actor.global_position + Vector2(0, -140), dmg, is_crit)

	var sfx: String = _sfx_crit.pick_random() if is_crit else _sfx_attack.pick_random()
	var sfx_color: Color = Color("#DB5247") if is_crit else Color.WHITE
	_spawn_sfx_text(enemy_actor.global_position + Vector2(0, -220), sfx, sfx_color)

	await get_tree().create_timer(0.4).timeout

	# 回 idle
	await _flip_pose(hero_actor, hero_sprite, _hero_poses["idle"], 0.12)
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["idle"], 0.1)

	_is_animating = false
	_check_death()


# ==========================================
# 敌人攻击
# ==========================================

func _on_enemy_attack_pressed() -> void:
	if _is_animating or _hero_hp <= 0 or _enemy_hp <= 0:
		return
	_is_animating = true

	_log("▸ 敌人 [攻击]")

	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["attack"], 0.15)

	var dash: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dash.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x - 120, 0.1)
	dash.parallel().tween_property(enemy_actor, "rotation", -0.12, 0.1)
	dash.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x, 0.15)
	dash.parallel().tween_property(enemy_actor, "rotation", 0.0, 0.15)

	await get_tree().create_timer(0.08).timeout

	var dmg: int = randi_range(60, 120)
	var is_crit: bool = randf() < 0.15
	if is_crit:
		dmg = int(dmg * 1.8)
	_hero_hp = maxi(0, _hero_hp - dmg)
	_update_hp_display()

	await _flip_pose(hero_actor, hero_sprite, _hero_poses["hit"], 0.1)
	var hurt: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	hurt.tween_property(hero_actor, "position:x", _hero_orig_pos.x - 30, 0.06)
	hurt.parallel().tween_property(hero_actor, "rotation", -0.1, 0.06)
	hurt.tween_property(hero_actor, "position:x", _hero_orig_pos.x, 0.15)
	hurt.parallel().tween_property(hero_actor, "rotation", 0.0, 0.15)

	_screen_shake(4.0, 0.1)
	_flash_sprite(hero_sprite)
	_spawn_damage_number(hero_actor.global_position + Vector2(0, -140), dmg, is_crit)

	var sfx: String = _sfx_crit.pick_random() if is_crit else _sfx_attack.pick_random()
	var sfx_color: Color = Color("#DB5247") if is_crit else Color.WHITE
	_spawn_sfx_text(hero_actor.global_position + Vector2(0, -220), sfx, sfx_color)

	await get_tree().create_timer(0.4).timeout
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["idle"], 0.12)
	await _flip_pose(hero_actor, hero_sprite, _hero_poses["idle"], 0.1)

	_is_animating = false
	_check_death()


# ==========================================
# 大招
# ==========================================

func _on_hero_ultimate_pressed() -> void:
	if _is_animating or _hero_hp <= 0 or _enemy_hp <= 0:
		return
	_is_animating = true

	_log("[color=#F2B93D]★★★ 主角释放 [大招] ★★★[/color]")

	# 起手：翻面切 skill1（大招待机）
	await _flip_pose(hero_actor, hero_sprite, _hero_poses["skill1"], 0.15)

	# 蓄力放大
	var charge: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge.tween_property(hero_actor, "scale", Vector2.ONE * 1.0, 0.2)
	charge.tween_property(hero_actor, "scale", Vector2.ONE * 0.7, 0.3)
	await charge.finished

	await get_tree().create_timer(0.15).timeout

	# 释放：翻面切 skill2（大招攻击）
	await _flip_pose(hero_actor, hero_sprite, _hero_poses["skill2"], 0.12)

	# 突进
	var dash: Tween = create_tween()
	dash.tween_property(hero_actor, "position:x", _hero_orig_pos.x + 250, 0.12)
	dash.parallel().tween_property(hero_actor, "rotation", 0.2, 0.12)
	dash.tween_property(hero_actor, "position:x", _hero_orig_pos.x, 0.2)
	dash.parallel().tween_property(hero_actor, "rotation", 0.0, 0.2)

	_screen_shake(18.0, 0.35)

	await get_tree().create_timer(0.15).timeout

	# 敌人被击飞
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["hit"], 0.1)
	var fly: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x + 100, 0.1)
	fly.parallel().tween_property(enemy_actor, "rotation", 0.35, 0.1)
	fly.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x, 0.4)
	fly.parallel().tween_property(enemy_actor, "rotation", 0.0, 0.4)

	var dmg: int = randi_range(300, 500)
	_enemy_hp = maxi(0, _enemy_hp - dmg)
	_update_hp_display()
	_flash_sprite(enemy_sprite)
	_spawn_damage_number(enemy_actor.global_position + Vector2(0, -160), dmg, true)
	_spawn_sfx_text(enemy_actor.global_position + Vector2(0, -260), "哐！！", Color("#F2B93D"))

	await get_tree().create_timer(0.8).timeout
	await _flip_pose(hero_actor, hero_sprite, _hero_poses["idle"], 0.12)
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["idle"], 0.1)

	_is_animating = false
	_check_death()


func _on_enemy_ultimate_pressed() -> void:
	if _is_animating or _hero_hp <= 0 or _enemy_hp <= 0:
		return
	_is_animating = true

	_log("[color=#BF7AE6]★★★ 敌人释放 [大招] ★★★[/color]")

	# 起手：翻面切 skill1
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["skill1"], 0.15)

	# 蓄力放大（0.5s）
	var charge: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge.tween_property(enemy_actor, "scale", Vector2.ONE * 1.0, 0.2)
	charge.tween_property(enemy_actor, "scale", Vector2.ONE * 0.7, 0.3)
	await charge.finished

	# 蓄力完成后停顿 0.15s，再翻面切 skill2
	await get_tree().create_timer(0.15).timeout

	# 释放：翻面切 skill2
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["skill2"], 0.12)

	var dash: Tween = create_tween()
	dash.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x - 250, 0.12)
	dash.parallel().tween_property(enemy_actor, "rotation", -0.2, 0.12)
	dash.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x, 0.2)
	dash.parallel().tween_property(enemy_actor, "rotation", 0.0, 0.2)

	_screen_shake(18.0, 0.35)

	await get_tree().create_timer(0.15).timeout

	await _flip_pose(hero_actor, hero_sprite, _hero_poses["hit"], 0.1)
	var fly: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(hero_actor, "position:x", _hero_orig_pos.x - 100, 0.1)
	fly.parallel().tween_property(hero_actor, "rotation", -0.35, 0.1)
	fly.tween_property(hero_actor, "position:x", _hero_orig_pos.x, 0.4)
	fly.parallel().tween_property(hero_actor, "rotation", 0.0, 0.4)

	var dmg: int = randi_range(250, 400)
	_hero_hp = maxi(0, _hero_hp - dmg)
	_update_hp_display()
	_flash_sprite(hero_sprite)
	_spawn_damage_number(hero_actor.global_position + Vector2(0, -160), dmg, true)
	_spawn_sfx_text(hero_actor.global_position + Vector2(0, -260), "砰！！", Color("#BF7AE6"))

	await get_tree().create_timer(0.8).timeout
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["idle"], 0.12)
	await _flip_pose(hero_actor, hero_sprite, _hero_poses["idle"], 0.1)

	_is_animating = false
	_check_death()


# ==========================================
# 胜利面板
# ==========================================

func _show_victory(winner: String) -> void:
	var title: Label = victory_panel.get_node("Title")
	var sub: Label = victory_panel.get_node("Subtitle")

	if winner == "hero":
		title.text = "🎉 胜利！"
		sub.text = "主角成功击败敌人！"
		title.add_theme_color_override("font_color", Color("#F2B93D"))
	else:
		title.text = "💀 失败..."
		sub.text = "主角被击败了..."
		title.add_theme_color_override("font_color", Color("#DB5247"))

	victory_panel.visible = true
	victory_panel.pivot_offset = victory_panel.size / 2
	victory_panel.scale = Vector2(0.5, 0.5)
	victory_panel.modulate = Color(1, 1, 1, 0)

	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(victory_panel, "modulate", Color.WHITE, 0.2)
	tween.parallel().tween_property(victory_panel, "scale", Vector2.ONE, 0.35)

	for i in range(8):
		var p: Label = Label.new()
		p.text = ["★", "♪", "✦", "♡"].pick_random()
		p.add_theme_font_size_override("font_size", 28)
		p.modulate = [Color("#F2B93D"), Color("#479DD1"), Color("#DB5247")].pick_random()
		victory_panel.add_child(p)
		p.global_position = victory_panel.global_position + Vector2(300, 100)

		var pt: Tween = create_tween()
		var dir: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1.5, -0.5)).normalized()
		pt.tween_property(p, "position", p.position + dir * randf_range(80, 150), 0.5)
		pt.parallel().tween_property(p, "modulate:a", 0.0, 0.5)
		pt.tween_callback(func(): if is_instance_valid(p): p.queue_free())
		await get_tree().create_timer(0.05).timeout


func _check_death() -> void:
	if _enemy_hp <= 0 and _hero_hp > 0:
		_log("[color=#DB5247]★ 敌人被击败！★[/color]")
		await get_tree().create_timer(0.3).timeout
		await _flip_pose(hero_actor, hero_sprite, _hero_poses["victory"], 0.2)
		_show_victory("hero")
	elif _hero_hp <= 0 and _enemy_hp > 0:
		_log("[color=#DB5247]★ 主角被击败！★[/color]")
		await get_tree().create_timer(0.3).timeout
		await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["victory"], 0.2)
		_show_victory("enemy")


# ==========================================
# 重置
# ==========================================

func _on_reset_pressed() -> void:
	_log("━━ 重置 ━━")
	_hero_hp = _hero_max_hp
	_enemy_hp = _enemy_max_hp
	_update_hp_display()

	hero_actor.position = _hero_orig_pos
	hero_actor.rotation = 0.0
	hero_actor.scale = Vector2.ONE * 0.7
	hero_actor.modulate = Color.WHITE

	enemy_actor.position = _enemy_orig_pos
	enemy_actor.rotation = 0.0
	enemy_actor.scale = Vector2.ONE * 0.7
	enemy_sprite.flip_h = true
	enemy_actor.modulate = Color.WHITE

	partner_actor.visible = false
	partner_actor.position = _partner_hide_pos

	_set_pose(hero_sprite, _hero_poses["idle"])
	_set_pose(enemy_sprite, _enemy_poses["idle"])
	_set_pose(partner_sprite, _partner_poses["idle"])

	victory_panel.visible = false
	_is_animating = false

	for child in damage_container.get_children():
		child.queue_free()
	for child in sfx_layer.get_children():
		child.queue_free()


# ==========================================
# UI Helpers
# ==========================================

func _update_hp_display() -> void:
	hero_hp_bar.value = float(_hero_hp) / _hero_max_hp * 100
	enemy_hp_bar.value = float(_enemy_hp) / _enemy_max_hp * 100
	hero_hp_label.text = "%d / %d" % [_hero_hp, _hero_max_hp]
	enemy_hp_label.text = "%d / %d" % [_enemy_hp, _enemy_max_hp]

	hero_hp_bar.modulate = Color.WHITE if float(_hero_hp)/_hero_max_hp >= 0.3 else Color(1.0, 0.5, 0.5)
	enemy_hp_bar.modulate = Color.WHITE if float(_enemy_hp)/_enemy_max_hp >= 0.3 else Color(1.0, 0.5, 0.5)


func _log(text: String) -> void:
	log_label.append_text(text + "\n")
