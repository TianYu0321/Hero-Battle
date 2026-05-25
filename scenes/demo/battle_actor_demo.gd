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
@onready var partner_select_popup: PartnerSelectPopup = $PartnerSelectPopup

## Phantom Camera 节点
@onready var pcam_default: PhantomCamera2D = $Pcam_Default
@onready var pcam_hero: PhantomCamera2D = $Pcam_Hero
@onready var pcam_enemy: PhantomCamera2D = $Pcam_Enemy
@onready var noise_emitter: PhantomCameraNoiseEmitter2D = $NoiseEmitter

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
var _swordsman_poses: Dictionary[String, Texture2D] = {}
var _scout_poses: Dictionary[String, Texture2D] = {}
var _sorcerer_poses: Dictionary[String, Texture2D] = {}
var _pharmacist_poses: Dictionary[String, Texture2D] = {}
var _shieldguard_poses: Dictionary[String, Texture2D] = {}

func _ready() -> void:
	# 加载单帧 Pose 图（hero/enemy 共用 shinobi 素材）
	var _shinobi_idle := _load_tex("assets/characters/hero/shinobi/idle/shinobi_idle_01.png")
	var _shinobi_attack := _load_tex("assets/characters/hero/shinobi/attack/shinobi_attack_01.png")
	var _shinobi_hit := _load_tex("assets/characters/hero/shinobi/hit/shinobi_hit_01.png")
	## skill1 = 疾风连击（多段），有 01-1 / 01-2 / 01-3
	var _shinobi_skill1_1 := _load_tex("assets/characters/hero/shinobi/skill1/shinobi_skill1_01-1.png")
	var _shinobi_skill1_2 := _load_tex("assets/characters/hero/shinobi/skill1/shinobi_skill1_01-2.png")
	var _shinobi_skill1_3 := _load_tex("assets/characters/hero/shinobi/skill1/shinobi_skill1_01-3.png")
	## skill2 = 必杀技，01=起手蓄力，02=突进释放
	var _shinobi_skill2_01 := _load_tex("assets/characters/hero/shinobi/skill2/shinobi_skill2_01.png")
	var _shinobi_skill2_02 := _load_tex("assets/characters/hero/shinobi/skill2/shinobi_skill2_02.png")
	var _shinobi_victory := _load_tex("assets/characters/hero/shinobi/victory/shinobi_victory_01.png")
	
	for key in ["idle", "attack", "hit", "skill", "skill1", "skill1-1", "skill1-2", "skill1-3", "skill2", "skill2-01", "skill2-02", "victory"]:
		_hero_poses[key] = _shinobi_idle
		_enemy_poses[key] = _shinobi_idle
	_hero_poses["attack"] = _shinobi_attack
	_hero_poses["hit"] = _shinobi_hit
	_hero_poses["skill"] = _shinobi_skill1_1
	_hero_poses["skill1"] = _shinobi_skill1_1
	_hero_poses["skill1-1"] = _shinobi_skill1_1
	_hero_poses["skill1-2"] = _shinobi_skill1_2
	_hero_poses["skill1-3"] = _shinobi_skill1_3
	_hero_poses["skill2"] = _shinobi_skill2_02
	_hero_poses["skill2-01"] = _shinobi_skill2_01
	_hero_poses["skill2-02"] = _shinobi_skill2_02
	_hero_poses["victory"] = _shinobi_victory
	_enemy_poses["attack"] = _shinobi_attack
	_enemy_poses["hit"] = _shinobi_hit
	_enemy_poses["skill1"] = _shinobi_skill1_1
	_enemy_poses["skill1-1"] = _shinobi_skill1_1
	_enemy_poses["skill1-2"] = _shinobi_skill1_2
	_enemy_poses["skill1-3"] = _shinobi_skill1_3
	_enemy_poses["skill2"] = _shinobi_skill2_02
	_enemy_poses["skill2-01"] = _shinobi_skill2_01
	_enemy_poses["skill2-02"] = _shinobi_skill2_02
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

	# PartnerSelectPopup 信号
	partner_select_popup.partner_selected.connect(_on_demo_partner_selected)
	partner_select_popup.popup_cancelled.connect(_on_demo_partner_cancelled)

	# 启动 idle 呼吸动画
	_idle_breath(hero_actor, 1.0)
	_idle_breath(enemy_actor, 1.2)
	


	victory_panel.visible = false
	victory_panel.modulate = Color(1, 1, 1, 0)

	## 初始化 Phantom Camera 默认状态
	_switch_camera_to("default")
	
	## 初始化 Noise Emitter 资源（场景节点可能因 MCP 限制未正确引用 .tres）
	if noise_emitter != null and noise_emitter.noise == null:
		var fallback_noise: PhantomCameraNoise2D = load("res://resources/phantom_camera_noise_medium.tres") as PhantomCameraNoise2D
		if fallback_noise != null:
			noise_emitter.noise = fallback_noise

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
	
	## 加载剑士 Pose
	var _swordsman_idle := _load_tex("assets/characters/partner/swordsman/idle/idle.png")
	var _swordsman_ready := _load_tex("assets/characters/partner/swordsman/ready/ready.png")
	var _swordsman_action := _load_tex("assets/characters/partner/swordsman/action/action.png")
	if _swordsman_idle != null:
		_swordsman_poses["idle"] = _swordsman_idle
	if _swordsman_ready != null:
		_swordsman_poses["ready"] = _swordsman_ready
	if _swordsman_action != null:
		_swordsman_poses["action"] = _swordsman_action
	
	## 加载斥候 Pose
	var _scout_idle := _load_tex("assets/characters/partner/scout/idle/idle.png")
	var _scout_ready := _load_tex("assets/characters/partner/scout/ready/ready.png")
	var _scout_action := _load_tex("assets/characters/partner/scout/action/action.png")
	if _scout_idle != null:
		_scout_poses["idle"] = _scout_idle
	if _scout_ready != null:
		_scout_poses["ready"] = _scout_ready
	if _scout_action != null:
		_scout_poses["action"] = _scout_action
	
	## 加载术士 Pose（无 idle，用 ready → action → pose 三阶段）
	var _sorcerer_ready := _load_tex("assets/characters/partner/sorcerer/ready/ready.png")
	var _sorcerer_action := _load_tex("assets/characters/partner/sorcerer/action/action.png")
	var _sorcerer_pose := _load_tex("assets/characters/partner/sorcerer/pose/pose.png")
	if _sorcerer_ready != null:
		_sorcerer_poses["ready"] = _sorcerer_ready
	if _sorcerer_action != null:
		_sorcerer_poses["action"] = _sorcerer_action
	if _sorcerer_pose != null:
		_sorcerer_poses["pose"] = _sorcerer_pose
	
	## 动态添加斥候测试按钮
	var btn_container: HBoxContainer = $UI/ButtonContainer
	var btn_scout := Button.new()
	btn_scout.text = "斥候狙击"
	btn_scout.add_theme_color_override("font_color", Color("#2ECC71"))
	btn_scout.add_theme_font_size_override("font_size", 16)
	btn_scout.pressed.connect(_on_scout_assist_pressed)
	btn_container.add_child(btn_scout)
	
	## 动态添加术士测试按钮
	var btn_sorcerer := Button.new()
	btn_sorcerer.text = "术士诅咒"
	btn_sorcerer.add_theme_color_override("font_color", Color("#9B59B6"))
	btn_sorcerer.add_theme_font_size_override("font_size", 16)
	btn_sorcerer.pressed.connect(_on_sorcerer_assist_pressed)
	btn_container.add_child(btn_sorcerer)
	
	## 加载药师 Pose（ready → action → pose）
	var _pharmacist_ready := _load_tex("assets/characters/partner/pharmacist/ready/ready.png")
	var _pharmacist_action := _load_tex("assets/characters/partner/pharmacist/action/action.png")
	var _pharmacist_pose := _load_tex("assets/characters/partner/pharmacist/pose/pose.png")
	if _pharmacist_ready != null:
		_pharmacist_poses["ready"] = _pharmacist_ready
	if _pharmacist_action != null:
		_pharmacist_poses["action"] = _pharmacist_action
	if _pharmacist_pose != null:
		_pharmacist_poses["pose"] = _pharmacist_pose
	
	## 加载盾卫 Pose（idle → action，idle/ready 1000px，action 600px）
	var _shieldguard_idle := _load_tex("assets/characters/partner/shieldguard/idle/idle.png")
	var _shieldguard_ready := _load_tex("assets/characters/partner/shieldguard/ready/ready.png")
	var _shieldguard_action := _load_tex("assets/characters/partner/shieldguard/action/action.png")
	if _shieldguard_idle != null:
		_shieldguard_poses["idle"] = _shieldguard_idle
	if _shieldguard_ready != null:
		_shieldguard_poses["ready"] = _shieldguard_ready
	if _shieldguard_action != null:
		_shieldguard_poses["action"] = _shieldguard_action
	
	## 动态添加药师测试按钮
	var btn_pharmacist := Button.new()
	btn_pharmacist.text = "药师治疗"
	btn_pharmacist.add_theme_color_override("font_color", Color("#2ECC71"))
	btn_pharmacist.add_theme_font_size_override("font_size", 16)
	btn_pharmacist.pressed.connect(_on_pharmacist_assist_pressed)
	btn_container.add_child(btn_pharmacist)
	
	## 动态添加盾卫测试按钮
	var btn_shieldguard := Button.new()
	btn_shieldguard.text = "盾卫援护"
	btn_shieldguard.add_theme_color_override("font_color", Color("#3498DB"))
	btn_shieldguard.add_theme_font_size_override("font_size", 16)
	btn_shieldguard.pressed.connect(_on_shieldguard_assist_pressed)
	btn_container.add_child(btn_shieldguard)


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
# 舞台特效（P2 验证用）
# ==========================================

func _stage_dim(duration: float = 0.5) -> void:
	## 舞台暗化：背景变暗，聚焦角色
	var bg: TextureRect = $Bg
	var tween: Tween = create_tween()
	tween.tween_property(bg, "modulate", Color(0.4, 0.4, 0.5, 1.0), duration)
	tween.tween_interval(duration)
	tween.tween_property(bg, "modulate", Color.WHITE, duration * 1.5)

func _stage_flash(flash_color: Color = Color.WHITE, duration: float = 0.15) -> void:
	## 全屏闪光
	var flash: ColorRect = ColorRect.new()
	flash.name = "StageFlash"
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = flash_color
	flash.modulate.a = 0.8
	add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.tween_callback(func(): if is_instance_valid(flash): flash.queue_free())

func _spawn_burst(pos: Vector2, burst_color: Color = Color("#F2B93D")) -> void:
	## 能量爆发粒子（简化版用 CPUParticles2D）
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.global_position = pos
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 24
	burst.lifetime = 0.4
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 200.0
	burst.initial_velocity_max = 400.0
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 6.0
	burst.color = burst_color
	add_child(burst)
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(burst):
		burst.queue_free()

# ==========================================
# Phantom Camera 镜头控制 / 屏幕震动
# ==========================================

func _switch_camera_to(target: String) -> void:
	## target: "default" | "hero" | "enemy"
	if pcam_default == null or pcam_hero == null or pcam_enemy == null:
		return
	match target:
		"hero":
			pcam_hero.set_priority(20)
			pcam_enemy.set_priority(0)
			pcam_default.set_priority(0)
		"enemy":
			pcam_hero.set_priority(0)
			pcam_enemy.set_priority(20)
			pcam_default.set_priority(0)
		_:
			pcam_hero.set_priority(0)
			pcam_enemy.set_priority(0)
			pcam_default.set_priority(10)

func _screen_shake(strength: float, duration: float) -> void:
	## 使用 Phantom Camera Noise Emitter 替代手写 offset 震动
	if noise_emitter == null:
		return
	var noise_res: PhantomCameraNoise2D
	if strength >= 15.0:
		noise_res = load("res://resources/phantom_camera_noise_heavy.tres") as PhantomCameraNoise2D
	else:
		noise_res = load("res://resources/phantom_camera_noise_medium.tres") as PhantomCameraNoise2D
	if noise_res != null:
		noise_emitter.noise = noise_res
	noise_emitter.duration = duration
	noise_emitter.emit()


func _flash_sprite(sprite: Sprite2D) -> void:
	sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)


# ==========================================
# 剑士跳跃重劈
# ==========================================

func _on_swordsman_assist_pressed() -> void:
	if _is_animating or _hero_hp <= 0 or _enemy_hp <= 0:
		return
	if not _swordsman_poses.has("ready") or not _swordsman_poses.has("action"):
		_log("[color=red]剑士素材未加载[/color]")
		return
	_is_animating = true

	_log("▸ [color=#4A90D9]剑士 跳跃重劈！[/color]")

	var enemy_center: Vector2 = enemy_actor.global_position
	## slash_pos 需要补偿 _switch_partner_pose 的 +200 右跳 + 剑尖偏移 127.5，合计约 330
	## 最终让剑尖落在敌人身前
	var spawn_pos: Vector2 = enemy_center + Vector2(-500, -350)
	var slash_pos: Vector2 = enemy_center + Vector2(-250, 0)

	var sprite := Sprite2D.new()
	sprite.texture = _swordsman_poses["ready"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	sprite.global_position = spawn_pos
	sfx_layer.add_child(sprite)

	## 一条连续的右下弧线直接劈到敌人身上
	## x 减速接近 + y 加速下落 = 右下弧线
	var arc_tween := create_tween().set_parallel()
	arc_tween.tween_property(sprite, "modulate:a", 1.0, 0.15)
	arc_tween.tween_property(sprite, "global_position:x", slash_pos.x, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc_tween.tween_property(sprite, "global_position:y", slash_pos.y, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	arc_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	## ready 前半段稍慢，约 64% 处切换 action，后半段劈砍更快
	arc_tween.tween_callback(func(): _switch_partner_pose(sprite, _swordsman_poses["action"])).set_delay(0.35)
	await arc_tween.finished

	## 命中：震屏+冲击波+爆发+尘土+碎石+受击同步触发，无冻结帧
	_screen_shake(12.0, 0.25)
	## 剑士 action.png（1000x480）中剑尖相对纹理中心的偏移（剑尖约 755,465）
	const SWORDSMAN_ACTION_TIP_OFFSET_TEX := Vector2(255, 225)
	## 按当前 sprite.scale 换算为全局坐标，确保特效始终挂在剑尖而非角色中心
	var sword_tip_pos: Vector2 = sprite.global_position + SWORDSMAN_ACTION_TIP_OFFSET_TEX * sprite.scale
	VFX.spawn_shockwave(sword_tip_pos)
	## 底部尘土（放大版）
	var dust = preload("res://addons/vfx_library/effects/jump_dust.tscn").instantiate()
	sfx_layer.add_child(dust)
	dust.global_position = sword_tip_pos
	dust.scale_amount_min = 8.0
	dust.scale_amount_max = 16.0
	dust.amount = 20
	dust.emitting = true
	get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(dust): dust.queue_free())
	
	## 碎石飞溅（放大版）
	var debris = preload("res://addons/vfx_library/effects/wood_debris.tscn").instantiate()
	sfx_layer.add_child(debris)
	debris.global_position = sword_tip_pos
	debris.scale_amount_min = 6.0
	debris.scale_amount_max = 12.0
	debris.amount = 25
	debris.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(debris): debris.queue_free())
	_flash_sprite(enemy_sprite)

	## 能量爆发粒子
	var _burst = preload("res://addons/vfx_library/effects/energy_burst.tscn").instantiate()
	sfx_layer.add_child(_burst)
	_burst.global_position = slash_pos
	_burst.z_index = 100
	_burst.scale = Vector2.ONE * 4.0
	_burst.restart()
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(_burst): _burst.queue_free())
	var _ring = preload("res://addons/vfx_library/effects/combo_ring.tscn").instantiate()
	sfx_layer.add_child(_ring)
	_ring.global_position = slash_pos
	_ring.z_index = 100
	_ring.scale = Vector2.ONE * 4.0
	_ring.restart()
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(_ring): _ring.queue_free())

	## 伤害
	var dmg: int = randi_range(150, 300)
	_enemy_hp = maxi(0, _enemy_hp - dmg)
	_update_hp_display()
	_spawn_damage_number(slash_pos + Vector2(0, -140), dmg, true)
	_spawn_sfx_text(slash_pos + Vector2(0, -220), "斩！", Color("#4A90D9"))

	## 敌人受击
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["hit"], 0.1)
	var hurt := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	hurt.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x + 40, 0.06)
	hurt.parallel().tween_property(enemy_actor, "rotation", 0.1, 0.06)
	hurt.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x, 0.15)
	hurt.parallel().tween_property(enemy_actor, "rotation", 0.0, 0.15)

	## 原地消失
	var fade_tween := create_tween()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	fade_tween.parallel().tween_property(sprite, "scale", Vector2(0.4, 0.4), 0.2)
	await fade_tween.finished
	if is_instance_valid(sprite):
		sprite.queue_free()

	await get_tree().create_timer(0.2).timeout
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["idle"], 0.1)

	_is_animating = false
	_check_death()


# ==========================================
# 斥候狙击
# ==========================================

func _on_scout_assist_pressed() -> void:
	if _is_animating or _hero_hp <= 0 or _enemy_hp <= 0:
		return
	if not _scout_poses.has("ready") or not _scout_poses.has("action"):
		_log("[color=red]斥候素材未加载[/color]")
		return
	_is_animating = true

	_log("▸ [color=#2ECC71]斥候 狙击！[/color]")

	var hero_center: Vector2 = hero_actor.global_position
	var enemy_center: Vector2 = enemy_actor.global_position
	## 站到主角后边的身位（与主角同高，略偏上），正面朝右射击
	var spawn_pos: Vector2 = hero_center + Vector2(-400, -10)
	var aim_pos: Vector2 = hero_center + Vector2(-150, -10)
	var hit_pos: Vector2 = enemy_center + Vector2(-40, 0)

	var sprite := Sprite2D.new()
	sprite.texture = _scout_poses["idle"] if _scout_poses.has("idle") else _scout_poses["ready"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	sprite.global_position = spawn_pos
	## 素材本身朝右，正好面向敌人射击，不需要 flip_h
	sfx_layer.add_child(sprite)

	## 阶段1: 淡入登场并移动到主角后方的瞄准位
	var enter_tween := create_tween().set_parallel()
	enter_tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	enter_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tween.tween_property(sprite, "global_position", aim_pos, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await enter_tween.finished

	## 阶段2: 切换 ready（拉弓瞄准），蓄力停顿
	_switch_partner_pose(sprite, _scout_poses["ready"])
	await get_tree().create_timer(0.25).timeout

	## 阶段3: 射箭 —— 箭矢从弓弦位置直线射向敌人
	## ready.png(600x480) 中弓弦约在 (360,250)，相对中心 (300,240) 偏移 (60,10)
	## 素材朝右，弓弦在中心右侧，x 取正
	const SCOUT_BOW_STRING_OFFSET_TEX := Vector2(60, 10)
	var arrow_start: Vector2 = sprite.global_position + SCOUT_BOW_STRING_OFFSET_TEX * sprite.scale
	var arrow := ColorRect.new()
	arrow.size = Vector2(140, 5)
	arrow.color = Color(0.95, 0.98, 1.0)
	arrow.rotation = (hit_pos - arrow_start).angle()
	## 以箭头尖端为锚点：先偏移 size/2，再微调让尖端对齐
	var arrow_pivot_offset := Vector2(arrow.size.x * 0.5, arrow.size.y * 0.5)
	sfx_layer.add_child(arrow)
	arrow.global_position = arrow_start - arrow_pivot_offset

	## 同时切换 action（射箭后坐力姿势）
	_switch_partner_pose(sprite, _scout_poses["action"])

	var arrow_tween := create_tween()
	arrow_tween.tween_property(arrow, "global_position", hit_pos - arrow_pivot_offset, 0.18).set_trans(Tween.TRANS_QUAD)
	await arrow_tween.finished

	## 命中：震屏 + 闪白 + 火花 + 受击
	_screen_shake(5.0, 0.15)
	_flash_sprite(enemy_sprite)
	var _sparks = preload("res://addons/vfx_library/effects/sparks.tscn").instantiate()
	sfx_layer.add_child(_sparks)
	_sparks.global_position = hit_pos
	_sparks.scale_amount_min = 3.0
	_sparks.scale_amount_max = 6.0
	_sparks.amount = 16
	_sparks.emitting = true
	get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(_sparks): _sparks.queue_free())
	arrow.queue_free()

	## 伤害
	var dmg: int = randi_range(150, 300)
	_enemy_hp = maxi(0, _enemy_hp - dmg)
	_update_hp_display()
	_spawn_damage_number(hit_pos + Vector2(0, -140), dmg, true)
	_spawn_sfx_text(hit_pos + Vector2(0, -220), "嗖！", Color("#2ECC71"))

	## 敌人受击（弓箭冲击力较小，位移也小）
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["hit"], 0.1)
	var hurt := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	hurt.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x + 15, 0.06)
	hurt.parallel().tween_property(enemy_actor, "rotation", 0.05, 0.06)
	hurt.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x, 0.15)
	hurt.parallel().tween_property(enemy_actor, "rotation", 0.0, 0.15)

	## 停留让用户看清 action pose
	await get_tree().create_timer(0.25).timeout

	## 阶段4: 退场淡出
	var fade_tween := create_tween()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	fade_tween.parallel().tween_property(sprite, "scale", Vector2(0.4, 0.4), 0.2)
	await fade_tween.finished
	if is_instance_valid(sprite):
		sprite.queue_free()

	await get_tree().create_timer(0.2).timeout
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["idle"], 0.1)

	_is_animating = false
	_check_death()


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

	## 斩击点：敌人身前（已预补偿 _switch_partner_pose 的 +200 右跳）
	## dash_tween 目标设为 slash_pos - 200，经 _switch_partner_pose 后 sprite 正好停在 slash_pos
	var slash_pos: Vector2 = enemy_actor.global_position + Vector2(-60, 0)
	var dash_target: Vector2 = slash_pos + Vector2(-200, 0)

	var sprite := Sprite2D.new()
	sprite.texture = _hunter_poses["idle"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	sprite.global_position = dash_target + Vector2(-500, 0)
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

	## 阶段2: 冲刺到预补偿位置（经 _switch_partner_pose 后会右跳 200px 到真正的 slash_pos）
	var dash_tween := create_tween()
	dash_tween.tween_property(sprite, "global_position", dash_target, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await dash_tween.finished

	## 阶段3: 斩击命中
	_switch_partner_pose(sprite, _hunter_poses["action"])
	## _switch_partner_pose 会让 sprite 右跳 200px，此时 sprite.global_position 才是真正的攻击点
	var actual_slash_pos: Vector2 = sprite.global_position

	## 打击停顿（时间冻结）
	VFX.freeze_frame(0.12, 0.05)

	## 震屏 + 闪白 + 能量爆发 + 连击环
	_screen_shake(12.0, 0.25)
	_flash_sprite(enemy_sprite)
	## 能量爆发粒子（挂在 sprite 实际位置，避免与 _switch_partner_pose 脱节）
	var _burst = preload("res://addons/vfx_library/effects/energy_burst.tscn").instantiate()
	sfx_layer.add_child(_burst)
	_burst.global_position = actual_slash_pos
	_burst.z_index = 100
	_burst.scale = Vector2.ONE * 4.0
	_burst.restart()
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(_burst): _burst.queue_free())
	var _ring = preload("res://addons/vfx_library/effects/combo_ring.tscn").instantiate()
	sfx_layer.add_child(_ring)
	_ring.global_position = actual_slash_pos
	_ring.z_index = 100
	_ring.scale = Vector2.ONE * 4.0
	_ring.restart()
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(_ring): _ring.queue_free())

	## 伤害
	var dmg: int = randi_range(150, 300)
	_enemy_hp = maxi(0, _enemy_hp - dmg)
	_update_hp_display()
	_spawn_damage_number(actual_slash_pos + Vector2(0, -140), dmg, true)
	_spawn_sfx_text(actual_slash_pos + Vector2(0, -220), "斩！", Color("#BF4DE6"))

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

	## 阶段4: 穿出画面 — 镜头切回全景
	var exit := create_tween()
	exit.tween_property(sprite, "global_position", slash_pos + Vector2(400, 0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	exit.parallel().tween_property(sprite, "modulate:a", 0.0, 0.25)
	await exit.finished
	if is_instance_valid(sprite):
		sprite.queue_free()

	await get_tree().create_timer(0.2).timeout
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["idle"], 0.1)

	_is_animating = false
	_check_death()


# ==========================================
# 术士黑暗诅咒
# ==========================================

func _on_sorcerer_assist_pressed() -> void:
	if _is_animating or _hero_hp <= 0 or _enemy_hp <= 0:
		return
	if not _sorcerer_poses.has("ready") or not _sorcerer_poses.has("action") or not _sorcerer_poses.has("pose"):
		_log("[color=red]术士素材未加载[/color]")
		return
	_is_animating = true

	_log("▸ [color=#9B59B6]术士 黑暗诅咒！[/color]")

	var enemy_center: Vector2 = enemy_actor.global_position
	var hero_center: Vector2 = hero_actor.global_position
	## 术士从主角身后飘到主角前方 200px 处施法（面朝左）
	var spawn_pos: Vector2 = hero_center + Vector2(-300, -20)
	var cast_pos: Vector2 = hero_center + Vector2(200, -20)

	var sprite := Sprite2D.new()
	sprite.texture = _sorcerer_poses["ready"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	sprite.global_position = spawn_pos
	sfx_layer.add_child(sprite)

	## 阶段1: 淡入登场
	var enter_tween := create_tween().set_parallel()
	enter_tween.tween_property(sprite, "modulate:a", 1.0, 0.3)
	enter_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tween.tween_property(sprite, "global_position", cast_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await enter_tween.finished

	## 阶段2: 召唤魔法阵（敌人脚下）
	var circle_pos: Vector2 = enemy_center + Vector2(0, 80)
	var magic_circle := _spawn_magic_circle(circle_pos)

	## 切换到 action pose（施法动作）
	_switch_partner_pose(sprite, _sorcerer_poses["action"])
	await get_tree().create_timer(0.2).timeout

	## 阶段3: 诅咒释放 + debuff 表现
	_screen_shake(6.0, 0.2)
	_apply_debuff_tint(enemy_sprite)

	## 紫色能量漩涡（portal_vortex 本身即为紫色调）
	var vortex = preload("res://addons/vfx_library/effects/portal_vortex.tscn").instantiate()
	sfx_layer.add_child(vortex)
	vortex.global_position = enemy_center
	vortex.scale_amount_min = 4.0
	vortex.scale_amount_max = 10.0
	vortex.amount = 120
	vortex.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func(): if is_instance_valid(vortex): vortex.queue_free())

	## debuff 标签
	_spawn_debuff_label(enemy_center + Vector2(0, -180), "↓攻")

	## 伤害
	var dmg: int = randi_range(80, 150)
	_enemy_hp = maxi(0, _enemy_hp - dmg)
	_update_hp_display()
	_spawn_damage_number(enemy_center + Vector2(0, -140), dmg, false)
	_spawn_sfx_text(enemy_center + Vector2(0, -240), "咒！", Color("#9B59B6"))

	await get_tree().create_timer(0.3).timeout

	## 阶段4: 收势（纸片翻转切到 pose pose）
	var _orig_scale_y: float = sprite.scale.y
	var _sign_x: float = sign(sprite.scale.x)
	if _sign_x == 0: _sign_x = 1
	var _flip_t1: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flip_t1.tween_property(sprite, "scale:x", 0.06 * _sign_x, 0.06)
	await _flip_t1.finished
	_switch_partner_pose(sprite, _sorcerer_poses["pose"])
	var _flip_t2: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flip_t2.tween_property(sprite, "scale:x", _orig_scale_y * _sign_x, 0.12)
	await _flip_t2.finished
	await get_tree().create_timer(0.4).timeout

	## 阶段5: 退场 + 魔法阵消失
	var fade_tween := create_tween().set_parallel()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	if is_instance_valid(magic_circle):
		fade_tween.tween_property(magic_circle, "modulate:a", 0.0, 0.5)
	await fade_tween.finished
	if is_instance_valid(sprite):
		sprite.queue_free()
	if is_instance_valid(magic_circle):
		magic_circle.queue_free()

	_is_animating = false
	_check_death()


## 魔法阵（六角星 + 外圈环，旋转 + 放大入场）
func _spawn_magic_circle(pos: Vector2) -> Node2D:
	var container := Node2D.new()
	container.global_position = pos
	container.modulate = Color(1, 1, 1, 0)
	sfx_layer.add_child(container)

	## 外圈六边形
	var hex := Polygon2D.new()
	var hex_pts: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var angle := deg_to_rad(i * 60 - 30)
		hex_pts.push_back(Vector2(cos(angle), sin(angle)) * 55)
	hex.polygon = hex_pts
	hex.color = Color(0.5, 0.1, 0.8, 0.25)
	container.add_child(hex)

	## 内圈六角星
	var star := Polygon2D.new()
	var star_pts: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var outer_angle := deg_to_rad(i * 60 - 90)
		var inner_angle := deg_to_rad(i * 60 - 60)
		star_pts.push_back(Vector2(cos(outer_angle), sin(outer_angle)) * 40)
		star_pts.push_back(Vector2(cos(inner_angle), sin(inner_angle)) * 18)
	star.polygon = star_pts
	star.color = Color(0.75, 0.3, 1.0, 0.45)
	container.add_child(star)

	## 放大 + 淡入
	container.scale = Vector2.ZERO
	var tween := create_tween().set_parallel()
	tween.tween_property(container, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "modulate:a", 1.0, 0.3)

	## 持续旋转
	var rot_tween := create_tween()
	rot_tween.tween_property(container, "rotation", PI * 4, 3.0)

	return container


## debuff 紫色 tint（敌人 portrait 闪烁暗紫后恢复）
func _apply_debuff_tint(sprite: Sprite2D) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.55, 0.25, 0.75), 0.1)
	tween.tween_interval(0.5)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.6)


## debuff 标签（头顶 ↓攻 图标，弹跳入场后上浮消失）
func _spawn_debuff_label(pos: Vector2, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(0.75, 0.35, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sfx_layer.add_child(label)
	label.global_position = pos
	label.scale = Vector2.ZERO
	label.z_index = 100

	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.15)
	tween.tween_property(label, "position:y", pos.y - 60, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tween.tween_callback(func(): if is_instance_valid(label): label.queue_free())


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

	# 舞台暗化 —— 聚焦大招
	_stage_dim(0.4)

	# 起手：翻面切 skill2-01（大招蓄力）— 同步启动镜头推近
	var _ult_tween: PhantomCameraTween = load("res://resources/phantom_camera_tween_ultimate.tres") as PhantomCameraTween
	if _ult_tween != null:
		pcam_hero.tween_resource = _ult_tween
	_switch_camera_to("hero")
	await _flip_pose(hero_actor, hero_sprite, _hero_poses["skill2-01"], 0.15)

	# 蓄力放大（镜头推近与蓄力同步：0.2 + 0.3 = 0.5s，加上翻面 0.15s，总计 0.65s）
	var charge: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge.tween_property(hero_actor, "scale", Vector2.ONE * 1.0, 0.2)
	charge.tween_property(hero_actor, "scale", Vector2.ONE * 0.7, 0.3)
	await charge.finished

	# skill2-01 蓄力完成 — 同步返回全景（速度一致：0.65s）
	if _ult_tween != null:
		pcam_default.tween_resource = _ult_tween
	_switch_camera_to("default")

	await get_tree().create_timer(0.15).timeout

	# 释放：翻面切 skill2-02（大招突进）
	await _flip_pose(hero_actor, hero_sprite, _hero_poses["skill2-02"], 0.12)

	# 突进
	var dash: Tween = create_tween()
	dash.tween_property(hero_actor, "position:x", _hero_orig_pos.x + 250, 0.12)
	dash.parallel().tween_property(hero_actor, "rotation", 0.2, 0.12)
	dash.tween_property(hero_actor, "position:x", _hero_orig_pos.x, 0.2)
	dash.parallel().tween_property(hero_actor, "rotation", 0.0, 0.2)

	_screen_shake(18.0, 0.35)
	## 能量爆发粒子（挂到 Node2D 层，放大 + restart 确保可见）
	var _burst = preload("res://addons/vfx_library/effects/energy_burst.tscn").instantiate()
	sfx_layer.add_child(_burst)
	_burst.global_position = enemy_actor.global_position
	_burst.z_index = 100
	_burst.scale = Vector2.ONE * 4.0
	_burst.restart()
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(_burst): _burst.queue_free())
	var _ring = preload("res://addons/vfx_library/effects/combo_ring.tscn").instantiate()
	sfx_layer.add_child(_ring)
	_ring.global_position = enemy_actor.global_position
	_ring.z_index = 100
	_ring.scale = Vector2.ONE * 4.0
	_ring.restart()
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(_ring): _ring.queue_free())
	VFX.freeze_frame(0.08, 0.05)

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


func _on_hero_skill_combo_pressed() -> void:
	if _is_animating or _hero_hp <= 0 or _enemy_hp <= 0:
		return
	_is_animating = true
	
	_log("▸ 主角 [影舞者·三连击]")
	
	# 疾风连击 pose key：第1段=skill1-1，第2段=skill1-2，第3段=skill1-3
	var _skill_pose_keys: Array[String] = ["skill1-1", "skill1-2", "skill1-3"]
	
	# 3段快速连击
	var combo_hits: Array = [
		{"dmg": randi_range(40, 70), "is_crit": randf() < 0.15},
		{"dmg": randi_range(40, 70), "is_crit": randf() < 0.15},
		{"dmg": randi_range(40, 70), "is_crit": randf() < 0.15},
	]
	
	for i in range(3):
		var hit = combo_hits[i]
		if hit.is_crit:
			hit.dmg = int(hit.dmg * 1.8)
		
		# 翻面切对应段 pose
		var _pose_key: String = _skill_pose_keys[i]
		await _flip_pose(hero_actor, hero_sprite, _hero_poses[_pose_key], 0.08)
		
		# 小段突进
		var slash: Tween = create_tween()
		slash.tween_property(hero_actor, "position:x", _hero_orig_pos.x + 80, 0.05)
		slash.parallel().tween_property(hero_actor, "rotation", 0.08, 0.05)
		slash.tween_property(hero_actor, "position:x", _hero_orig_pos.x, 0.05)
		slash.parallel().tween_property(hero_actor, "rotation", 0.0, 0.05)
		await slash.finished
		
		# 显示伤害
		_enemy_hp = maxi(0, _enemy_hp - hit.dmg)
		_update_hp_display()
		_spawn_damage_number(enemy_actor.global_position + Vector2(0, -140), hit.dmg, hit.is_crit)
		
		if i < 2:
			await get_tree().create_timer(0.04).timeout
	
	# 最后一段的受击动画
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["hit"], 0.1)
	var hurt: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	hurt.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x + 30, 0.06)
	hurt.parallel().tween_property(enemy_actor, "rotation", 0.1, 0.06)
	hurt.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x, 0.15)
	hurt.parallel().tween_property(enemy_actor, "rotation", 0.0, 0.15)
	
	_screen_shake(8.0, 0.15)
	_flash_sprite(enemy_sprite)
	
	var last_hit = combo_hits[2]
	var sfx: String = _sfx_crit.pick_random() if last_hit.is_crit else _sfx_attack.pick_random()
	var sfx_color: Color = Color("#DB5247") if last_hit.is_crit else Color.WHITE
	_spawn_sfx_text(enemy_actor.global_position + Vector2(0, -220), sfx, sfx_color)
	
	await get_tree().create_timer(0.3).timeout
	await _flip_pose(hero_actor, hero_sprite, _hero_poses["idle"], 0.12)
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["idle"], 0.1)
	
	_is_animating = false
	_check_death()


func _on_hero_ult_combo_pressed() -> void:
	if _is_animating or _hero_hp <= 0 or _enemy_hp <= 0:
		return
	_is_animating = true
	
	_log("[color=#F2B93D]★★★ 主角释放 [影舞者·必杀] ★★★[/color]")
	
	# 舞台暗化
	_stage_dim(0.4)
	
	# 起手：翻面切 skill1 + 镜头推近
	var _ult_tween: PhantomCameraTween = load("res://resources/phantom_camera_tween_ultimate.tres") as PhantomCameraTween
	if _ult_tween != null:
		pcam_hero.tween_resource = _ult_tween
	_switch_camera_to("hero")
	await _flip_pose(hero_actor, hero_sprite, _hero_poses["skill1"], 0.15)
	
	# 蓄力放大
	var charge: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge.tween_property(hero_actor, "scale", Vector2.ONE * 1.0, 0.2)
	charge.tween_property(hero_actor, "scale", Vector2.ONE * 0.7, 0.3)
	await charge.finished
	
	# 返回全景
	if _ult_tween != null:
		pcam_default.tween_resource = _ult_tween
	_switch_camera_to("default")
	
	await get_tree().create_timer(0.15).timeout
	
	# 释放：翻面切 skill2
	await _flip_pose(hero_actor, hero_sprite, _hero_poses["skill2"], 0.12)
	
	# 突进
	var dash: Tween = create_tween()
	dash.tween_property(hero_actor, "position:x", _hero_orig_pos.x + 250, 0.12)
	dash.parallel().tween_property(hero_actor, "rotation", 0.2, 0.12)
	dash.tween_property(hero_actor, "position:x", _hero_orig_pos.x, 0.2)
	dash.parallel().tween_property(hero_actor, "rotation", 0.0, 0.2)
	
	# 突进命中：震屏 + 粒子
	_screen_shake(18.0, 0.35)
	var _burst = preload("res://addons/vfx_library/effects/energy_burst.tscn").instantiate()
	sfx_layer.add_child(_burst)
	_burst.global_position = enemy_actor.global_position
	_burst.z_index = 100
	_burst.scale = Vector2.ONE * 4.0
	_burst.restart()
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(_burst): _burst.queue_free())
	VFX.freeze_frame(0.08, 0.05)
	
	# 依次显示6段伤害
	var total_dmg: int = 0
	for i in range(6):
		var dmg: int = randi_range(50, 90)
		var is_crit: bool = randf() < 0.1
		if is_crit:
			dmg = int(dmg * 1.8)
		total_dmg += dmg
		
		_enemy_hp = maxi(0, _enemy_hp - dmg)
		_update_hp_display()
		_spawn_damage_number(enemy_actor.global_position + Vector2(0, -160), dmg, is_crit)
		
		if i < 5:
			await get_tree().create_timer(0.06).timeout
	
	await get_tree().create_timer(0.15).timeout
	
	# 敌人被击飞
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["hit"], 0.1)
	var fly: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x + 100, 0.1)
	fly.parallel().tween_property(enemy_actor, "rotation", 0.35, 0.1)
	fly.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x, 0.4)
	fly.parallel().tween_property(enemy_actor, "rotation", 0.0, 0.4)
	
	_flash_sprite(enemy_sprite)
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

	# 舞台暗化 —— 聚焦大招
	_stage_dim(0.4)

	# 起手：翻面切 skill2-01 — 同步启动镜头推近
	var _ult_tween: PhantomCameraTween = load("res://resources/phantom_camera_tween_ultimate.tres") as PhantomCameraTween
	if _ult_tween != null:
		pcam_enemy.tween_resource = _ult_tween
	_switch_camera_to("enemy")
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["skill2-01"], 0.15)

	# 蓄力放大（镜头推近与蓄力同步：0.2 + 0.3 = 0.5s，加上翻面 0.15s，总计 0.65s）
	var charge: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge.tween_property(enemy_actor, "scale", Vector2.ONE * 1.0, 0.2)
	charge.tween_property(enemy_actor, "scale", Vector2.ONE * 0.7, 0.3)
	await charge.finished

	# skill2-01 蓄力完成 — 同步返回全景（速度一致：0.65s）
	if _ult_tween != null:
		pcam_default.tween_resource = _ult_tween
	_switch_camera_to("default")

	# 蓄力完成后停顿 0.15s，再翻面切 skill2-02
	await get_tree().create_timer(0.15).timeout

	# 释放：翻面切 skill2-02
	await _flip_pose(enemy_actor, enemy_sprite, _enemy_poses["skill2-02"], 0.12)

	var dash: Tween = create_tween()
	dash.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x - 250, 0.12)
	dash.parallel().tween_property(enemy_actor, "rotation", -0.2, 0.12)
	dash.tween_property(enemy_actor, "position:x", _enemy_orig_pos.x, 0.2)
	dash.parallel().tween_property(enemy_actor, "rotation", 0.0, 0.2)

	_screen_shake(18.0, 0.35)
	## 能量爆发粒子（挂到 Node2D 层，放大 + restart 确保可见）
	var _burst = preload("res://addons/vfx_library/effects/energy_burst.tscn").instantiate()
	sfx_layer.add_child(_burst)
	_burst.global_position = hero_actor.global_position
	_burst.z_index = 100
	_burst.scale = Vector2.ONE * 4.0
	_burst.restart()
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(_burst): _burst.queue_free())
	var _ring = preload("res://addons/vfx_library/effects/combo_ring.tscn").instantiate()
	sfx_layer.add_child(_ring)
	_ring.global_position = hero_actor.global_position
	_ring.z_index = 100
	_ring.scale = Vector2.ONE * 4.0
	_ring.restart()
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(_ring): _ring.queue_free())
	VFX.freeze_frame(0.08, 0.05)

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

	# 恢复镜头默认 tween（防止大招修改后残留）
	var _fast_tween: PhantomCameraTween = load("res://resources/phantom_camera_tween_fast.tres") as PhantomCameraTween
	if _fast_tween != null:
		pcam_default.tween_resource = _fast_tween
		pcam_hero.tween_resource = _fast_tween
		pcam_enemy.tween_resource = _fast_tween
	_switch_camera_to("default")

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


func _on_partner_select_pressed() -> void:
	_log("━━ 打开伙伴选择弹窗 ━━")
	var test_partners: Array[Dictionary] = [
		{
			"partner_id": 1,
			"name": "暗影刺客",
			"level": 3,
			"role": "刺客",
			"rarity_str": "S",
			"skill_desc": "对敌方单体造成高额物理伤害，并有概率触发连击。",
			"portrait_path": ""
		},
		{
			"partner_id": 2,
			"name": "圣光祭司",
			"level": 2,
			"role": "治疗",
			"rarity_str": "A",
			"skill_desc": "恢复主角 15% 最大生命值，并清除一个负面状态。",
			"portrait_path": ""
		},
		{
			"partner_id": 3,
			"name": "铁壁卫士",
			"level": 4,
			"role": "坦克",
			"rarity_str": "B",
			"skill_desc": "为主角提供护盾，吸收相当于自身生命 20% 的伤害。",
			"portrait_path": ""
		}
	]
	partner_select_popup.show_popup(test_partners)


func _on_demo_partner_selected(partner_id: String, partner_data: Dictionary) -> void:
	_log("✅ 招募伙伴: %s (ID=%s)" % [partner_data.get("name", "???"), partner_id])


func _on_demo_partner_cancelled() -> void:
	_log("❌ 取消招募伙伴")


# ==========================================
# 纸片翻转（单个 Sprite2D 版，无外层 Actor）
# ==========================================
func _flip_pose_sprite(sprite: Sprite2D, tex: Texture2D, duration: float = 0.18) -> void:
	if tex == null:
		return
	var orig_scale_y: float = sprite.scale.y
	var sign: float = sign(sprite.scale.x)
	if sign == 0:
		sign = 1
	var t1: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t1.tween_property(sprite, "scale:x", 0.06 * sign, duration * 0.35)
	await t1.finished
	_set_pose(sprite, tex)
	var t2: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(sprite, "scale:x", orig_scale_y * sign, duration * 0.65)
	await t2.finished


# ==========================================
# 药师治疗
# ==========================================
func _on_pharmacist_assist_pressed() -> void:
	if _is_animating or _hero_hp <= 0 or _enemy_hp <= 0:
		return
	if not _pharmacist_poses.has("ready") or not _pharmacist_poses.has("action") or not _pharmacist_poses.has("pose"):
		_log("[color=red]药师素材未加载[/color]")
		return
	_is_animating = true

	_log("▸ [color=#2ECC71]药师 治愈之光！[/color]")

	var hero_center: Vector2 = hero_actor.global_position
	var spawn_pos: Vector2 = hero_center + Vector2(-400, -20)
	var cast_pos: Vector2 = hero_center + Vector2(-150, -20)

	var sprite := Sprite2D.new()
	sprite.texture = _pharmacist_poses["ready"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	sprite.global_position = spawn_pos
	sfx_layer.add_child(sprite)

	## 阶段1: 淡入登场
	var enter_tween := create_tween().set_parallel()
	enter_tween.tween_property(sprite, "modulate:a", 1.0, 0.3)
	enter_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tween.tween_property(sprite, "global_position", cast_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await enter_tween.finished

	## 阶段2: 纸片翻转 action（洒药）
	await _flip_pose_sprite(sprite, _pharmacist_poses["action"])
	await get_tree().create_timer(0.15).timeout

	## 阶段3: 治疗特效
	## 绿色粒子飘向主角
	var heal = preload("res://addons/vfx_library/effects/heal_particles.tscn").instantiate()
	sfx_layer.add_child(heal)
	heal.global_position = cast_pos + Vector2(80, -20)
	heal.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(heal): heal.queue_free())

	## 主角闪绿色
	_apply_heal_tint(hero_sprite)

	## 绿色 +HP 标签
	_spawn_heal_label(hero_center + Vector2(0, -200))

	## 回血
	var heal_amount: int = randi_range(100, 200)
	_hero_hp = mini(_hero_max_hp, _hero_hp + heal_amount)
	_update_hp_display()
	_spawn_heal_number(hero_center + Vector2(0, -140), heal_amount)
	_spawn_sfx_text(hero_center + Vector2(0, -260), "治愈！", Color("#2ECC71"))

	await get_tree().create_timer(0.3).timeout

	## 阶段4: 纸片翻转 pose 收势
	await _flip_pose_sprite(sprite, _pharmacist_poses["pose"])
	await get_tree().create_timer(0.4).timeout

	## 阶段5: 退场
	var fade_tween := create_tween()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	await fade_tween.finished
	if is_instance_valid(sprite):
		sprite.queue_free()

	_is_animating = false


## 治疗绿色 tint
func _apply_heal_tint(sprite: Sprite2D) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.5, 0.9, 0.5), 0.15)
	tween.tween_interval(0.4)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)


## 治疗标签（绿色十字弹跳入场）
func _spawn_heal_label(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "✚"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.4))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sfx_layer.add_child(label)
	label.global_position = pos
	label.scale = Vector2.ZERO
	label.z_index = 100

	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE * 1.2, 0.15)
	tween.tween_property(label, "scale", Vector2.ONE, 0.1)
	tween.tween_property(label, "position:y", pos.y - 50, 0.5).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tween.tween_callback(func(): if is_instance_valid(label): label.queue_free())


## 治疗数字（绿色 +XXX）
func _spawn_heal_number(pos: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "+%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color("#2ECC71"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sfx_layer.add_child(label)
	label.global_position = pos
	label.scale = Vector2(0.5, 0.5)

	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE * 1.3, 0.15)
	tween.tween_property(label, "scale", Vector2.ONE, 0.1)
	tween.tween_property(label, "position:y", pos.y - 70, 0.6).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.tween_callback(func(): if is_instance_valid(label): label.queue_free())


# ==========================================
# 盾卫天降援护
# ==========================================
func _on_shieldguard_assist_pressed() -> void:
	if _is_animating or _hero_hp <= 0 or _enemy_hp <= 0:
		return
	if not _shieldguard_poses.has("idle") or not _shieldguard_poses.has("ready") or not _shieldguard_poses.has("action"):
		_log("[color=red]盾卫素材未加载[/color]")
		return
	_is_animating = true

	_log("▸ [color=#3498DB]盾卫 天降援护！[/color]")

	var hero_center: Vector2 = hero_actor.global_position
	## 天降：从主角上方落下，落地在主角前方
	var spawn_pos: Vector2 = hero_center + Vector2(200, -450)
	var land_pos: Vector2 = hero_center + Vector2(200, 0)

	var sprite := Sprite2D.new()
	sprite.texture = _shieldguard_poses["idle"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	sprite.global_position = spawn_pos
	sfx_layer.add_child(sprite)

	## 阶段1: 天降（加速下落，idle = 空中下落姿势）
	var fall_tween := create_tween().set_parallel()
	fall_tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	fall_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fall_tween.tween_property(sprite, "global_position", land_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall_tween.finished

	## 落地震屏 + 尘土
	_screen_shake(10.0, 0.2)
	var dust = preload("res://addons/vfx_library/effects/jump_dust.tscn").instantiate()
	sfx_layer.add_child(dust)
	dust.global_position = land_pos
	dust.scale_amount_min = 6.0
	dust.scale_amount_max = 12.0
	dust.amount = 20
	dust.emitting = true
	get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(dust): dust.queue_free())

	## 阶段2: 直接切 ready（落地姿势，idle/ready 同尺寸 1000px，无纸片翻转）
	_switch_partner_pose(sprite, _shieldguard_poses["ready"])
	await get_tree().create_timer(0.1).timeout

	## 阶段3: 纸片翻转 action（举盾格挡，1000→600 左移 200px 正好贴身）
	await _flip_pose_sprite(sprite, _shieldguard_poses["action"])
	await get_tree().create_timer(0.15).timeout

	## 阶段4: 护盾展开特效
	_spawn_shield_aura(hero_center)
	_apply_shield_tint(hero_sprite)

	## 反弹伤害（模拟）
	var reflect_dmg: int = randi_range(50, 100)
	_enemy_hp = maxi(0, _enemy_hp - reflect_dmg)
	_update_hp_display()
	_spawn_damage_number(enemy_actor.global_position + Vector2(0, -140), reflect_dmg, false)
	_spawn_sfx_text(land_pos + Vector2(0, -180), "盾反！", Color("#3498DB"))

	await get_tree().create_timer(0.4).timeout

	## 阶段5: 退场（直接从 action 淡出，无需翻回 ready）
	var fade_tween := create_tween()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	await fade_tween.finished
	if is_instance_valid(sprite):
		sprite.queue_free()

	_is_animating = false
	_check_death()


## 蓝色护盾光环（罩住主角）
func _spawn_shield_aura(pos: Vector2) -> void:
	## 外圈护盾环
	var shield_ring := Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(24):
		var angle := deg_to_rad(i * 15)
		pts.push_back(Vector2(cos(angle), sin(angle)) * 70)
	shield_ring.polygon = pts
	shield_ring.color = Color(0.25, 0.55, 0.95, 0.15)
	shield_ring.position = pos
	sfx_layer.add_child(shield_ring)

	## 内圈光点
	var inner := Polygon2D.new()
	var inner_pts: PackedVector2Array = PackedVector2Array()
	for i in range(12):
		var angle := deg_to_rad(i * 30)
		inner_pts.push_back(Vector2(cos(angle), sin(angle)) * 45)
	inner.polygon = inner_pts
	inner.color = Color(0.4, 0.7, 1.0, 0.3)
	inner.position = pos
	sfx_layer.add_child(inner)

	## 放大 + 闪烁
	shield_ring.scale = Vector2.ZERO
	inner.scale = Vector2.ZERO
	var tween := create_tween().set_parallel()
	tween.tween_property(shield_ring, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(inner, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)

	await get_tree().create_timer(0.6).timeout
	var fade := create_tween().set_parallel()
	fade.tween_property(shield_ring, "modulate:a", 0.0, 0.4)
	fade.tween_property(inner, "modulate:a", 0.0, 0.4)
	await fade.finished
	if is_instance_valid(shield_ring): shield_ring.queue_free()
	if is_instance_valid(inner): inner.queue_free()


## 护盾蓝色 tint
func _apply_shield_tint(sprite: Sprite2D) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.6, 0.75, 0.95), 0.1)
	tween.tween_interval(0.5)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
