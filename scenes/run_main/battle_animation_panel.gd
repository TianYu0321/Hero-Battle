class_name BattleAnimationPanel
extends Control

# ==========================================
# @onready 引用
# ==========================================
@onready var semi_transparent_bg: ColorRect = $SemiTransparentBg

## HUD 信息条（顶部）
@onready var hero_name_label: Label = $HudContainer/HeroInfoPanel/NameLabel
@onready var hero_hp_bar: ProgressBar = $HudContainer/HeroInfoPanel/HpBar
@onready var hero_hp_meta: Label = $HudContainer/HeroInfoPanel/HpMeta

@onready var enemy_name_label: Label = $HudContainer/EnemyCard/NameLabel
@onready var enemy_hp_bar: ProgressBar = $HudContainer/EnemyCard/HpBar
@onready var enemy_hp_meta: Label = $HudContainer/EnemyCard/HpMeta

@onready var vs_label: Label = $HudContainer/CenterBadge/VsLabel
@onready var round_label: Label = $HudContainer/CenterBadge/RoundLabel

## 战斗展示卡牌（StageArea）
@onready var hero_card: Control = $StageArea/HeroCard
@onready var hero_portrait: Sprite2D = $StageArea/HeroCard/Portrait
@onready var hero_glow: ColorRect = $StageArea/HeroCard/Portrait/GlowOverlay
@onready var hero_effect: AnimatedSprite2D = $StageArea/HeroCard/Portrait/EffectSprite

@onready var enemy_card: Control = $StageArea/EnemyCard
@onready var enemy_portrait: Sprite2D = $StageArea/EnemyCard/Portrait
@onready var enemy_glow: ColorRect = $StageArea/EnemyCard/Portrait/GlowOverlay
@onready var enemy_effect: AnimatedSprite2D = $StageArea/EnemyCard/Portrait/EffectSprite

@onready var stage_name_label: Label = $StageArea/StageName
@onready var partner_anim_container: Node2D = $StageArea/PartnerAnimContainer

## 伙伴链
@onready var partner_chain_list: VBoxContainer = $PartnerChainLayer/PartnerChainList

## 日志和控件
@onready var log_head: Label = $LogPanel/LogHead
@onready var battle_log: RichTextLabel = $LogPanel/BattleLog
@onready var skip_button: Button = $LogPanel/SkipButton
@onready var turn_timer: Timer = $TurnTimer

## Phantom Camera 节点
@onready var battle_camera: Camera2D = $BattleCamera
@onready var pcam_default: PhantomCamera2D = $Pcam_Default
@onready var pcam_hero: PhantomCamera2D = $Pcam_Hero
@onready var pcam_enemy: PhantomCamera2D = $Pcam_Enemy
@onready var noise_emitter: PhantomCameraNoiseEmitter2D = $NoiseEmitter
@onready var sfx_layer: Node2D = $SfxLayer

# ==========================================
# 常量
# ==========================================
const BASE_CARD_SCALE := 0.7

# ==========================================
# 变量
# ==========================================
var _playback_generation: int = 0
var _result_emitted: bool = false
var _is_playing: bool = false
var _current_round: int = 0

var _hero_hp: int = 0
var _hero_max_hp: int = 0
var _enemy_hp: int = 0
var _enemy_max_hp: int = 0

var _recorder: BattlePlaybackRecorder = null
var _events_by_turn: Dictionary = {}
var _turn_keys: Array = []
var _event_tween: Tween = null

var _sim_total_rounds: int = 0
var _is_frenzy_active: bool = false

## 卡牌原始位置缓存
var _hero_card_orig_pos: Vector2 = Vector2.ZERO
var _enemy_card_orig_pos: Vector2 = Vector2.ZERO
var _hero_portrait_orig_pos: Vector2 = Vector2.ZERO
var _enemy_portrait_orig_pos: Vector2 = Vector2.ZERO

## 伙伴链
var _chain_slots: Array[Control] = []

## 卡牌动画 Tweens（防止冲突和泄漏）
var _hero_attack_tween: Tween = null
var _enemy_attack_tween: Tween = null
var _hero_hurt_tween: Tween = null
var _enemy_hurt_tween: Tween = null
var _hero_death_tween: Tween = null
var _enemy_death_tween: Tween = null
var _hp_bar_flash_tween: Tween = null
var _hunter_poses: Dictionary = {}
var _swordsman_poses: Dictionary = {}
var _scout_poses: Dictionary = {}
var _sorcerer_poses: Dictionary = {}
var _pharmacist_poses: Dictionary = {}
var _shieldguard_poses: Dictionary = {}
var _hero_poses: Dictionary = {}
var _enemy_poses: Dictionary = {}
var _hero_breath_tween: Tween = null
var _enemy_breath_tween: Tween = null
var _pending_ultimate: bool = false
var _is_ultimate_active: bool = false

## 新增：动画速度控制
var _animation_speed: float = 1.0
var _speed_buttons: Array[Button] = []

## 新增：敌方镜像CHAIN槽（PVP用）
var _enemy_chain_slots: Array[Control] = []
var _enemy_chain_layer: CanvasLayer = null

## 新增：关卡背景
var _stage_bg: Sprite2D = null
var _current_floor: int = 1

## 新增：日志背景面板
var _log_bg_panel: PanelContainer = null

## 新增：高级血条
var _hero_hp_bar_fancy: FancyHealthBar = null
var _enemy_hp_bar_fancy: FancyHealthBar = null

@onready var _font_cn: Font = load(RunMainSettings.FONT_CN_PATH) as Font

signal confirmed

func _notification(what: int) -> void:
	## CanvasLayer 不受父节点 visible 影响，需要手动同步
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if partner_chain_list != null:
			partner_chain_list.visible = self.visible
		if _enemy_chain_layer != null:
			_enemy_chain_layer.visible = self.visible
		if _stage_bg != null:
			_stage_bg.visible = self.visible

const COL_TEXT_MAIN := Color(0.90, 0.90, 0.92)
const COL_TEXT_SECOND := Color(0.68, 0.68, 0.71)
const COL_RED_MAIN := Color(0.85, 0.22, 0.15)
const COL_RED_DEEP := Color(0.35, 0.06, 0.04)
const COL_BLUE_MAIN := Color(0.25, 0.55, 0.85)
const COL_BLUE_DEEP := Color(0.08, 0.18, 0.35)
const COL_GOLD := Color(0.90, 0.75, 0.35)
const COL_CRIT := Color(0.95, 0.55, 0.25)
const COL_MISS := Color(0.50, 0.50, 0.55)
const COL_CHAIN := Color(0.75, 0.30, 0.90)

## 拟声词池（SD纸片小剧场风格）
const SFX_ATTACK: Array[String] = ["啪！", "斩！", "嗖！", "唰！"]
const SFX_CRIT: Array[String] = ["砰！", "Duang!", "哐！", "咚！"]
const SFX_SUPPORT: Array[String] = ["来咯！", "援护！", "加油！"]

# ==========================================
# 生命周期
# ==========================================
func _ready() -> void:
	turn_timer.timeout.connect(_on_turn_timer_timeout)
	skip_button.pressed.connect(_on_skip)
	
	skip_button.mouse_entered.connect(func():
		TweenFX.snap(skip_button, 0.1, Vector2.ONE * 1.1, TweenFX.PlayState.ENTER)
	)
	skip_button.mouse_exited.connect(func():
		TweenFX.snap(skip_button, 0.1, Vector2.ONE, TweenFX.PlayState.EXIT)
	)
	
	visible = false
	battle_log.scroll_following = true
	_apply_dark_theme()
	_apply_theme_colors()
	
	## 缓存卡牌原始位置
	_hero_card_orig_pos = hero_card.position
	_enemy_card_orig_pos = enemy_card.position
	_hero_portrait_orig_pos = hero_portrait.position
	_enemy_portrait_orig_pos = enemy_portrait.position
	
	## 初始化伙伴链
	_init_chain_slots()
	_load_hunter_poses()
	_load_swordsman_poses()
	_load_scout_poses()
	_load_sorcerer_poses()
	_load_pharmacist_poses()
	_load_shieldguard_poses()
	_load_hero_poses()
	_load_enemy_poses()

	## 设置初始 Pose
	_set_pose(hero_portrait, _hero_poses.get("idle"))
	_set_pose(enemy_portrait, _enemy_poses.get("idle"))
	hero_portrait.scale = Vector2.ONE * 0.7
	enemy_portrait.scale = Vector2.ONE * 0.7
	enemy_portrait.flip_h = true

	## 启动呼吸动画
	_start_idle_breath(hero_portrait, 1.0)
	_start_idle_breath(enemy_portrait, 1.2)
	
	## 初始化 Phantom Camera 默认状态
	_switch_camera_to("default")
	
	## 初始化 Noise Emitter 资源（场景节点可能因 MCP 限制未正确引用 .tres）
	if noise_emitter != null and noise_emitter.noise == null:
		var fallback_noise: PhantomCameraNoise2D = load("res://resources/phantom_camera_noise_medium.tres") as PhantomCameraNoise2D
		if fallback_noise != null:
			noise_emitter.noise = fallback_noise
	
	## 初始化 Overlay Shader
	var overlay_mat := ShaderMaterial.new()
	overlay_mat.shader = preload("res://shaders/portrait_overlay.gdshader")
	overlay_mat.set_shader_parameter("flash", 0.0)
	overlay_mat.set_shader_parameter("saturation", 1.0)
	hero_portrait.material = overlay_mat
	
	var enemy_overlay_mat := ShaderMaterial.new()
	enemy_overlay_mat.shader = preload("res://shaders/portrait_overlay.gdshader")
	enemy_overlay_mat.set_shader_parameter("flash", 0.0)
	enemy_overlay_mat.set_shader_parameter("saturation", 1.0)
	enemy_portrait.material = enemy_overlay_mat
	
	## 灰烬粒子
	var _ash_parent := Node2D.new()
	_ash_parent.name = "AshParent"
	add_child(_ash_parent)
	var vp_size := get_viewport().get_visible_rect().size
	EnvVFX.create_ash_particles(_ash_parent, vp_size)
	
	## 新增：初始化日志面板背景、速度控制、敌方CHAIN槽、关卡背景、高级血条
	_setup_log_panel()
	_setup_speed_controls()
	_setup_enemy_chain_layer()
	_setup_stage_background()
	_setup_fancy_hp_bars()

func _apply_dark_theme() -> void:
	semi_transparent_bg.color = Color(0.05, 0.05, 0.08, 0.0)

func _apply_theme_colors() -> void:
	var theme := get_theme()
	var text_main_color: Color = COL_TEXT_MAIN
	var gold_color: Color = COL_GOLD
	var text_second_color: Color = COL_TEXT_SECOND
	
	if theme != null:
		if theme.has_color("font_color", "Label"):
			text_main_color = theme.get_color("font_color", "Label")
		if theme.has_color("gold", "custom"):
			gold_color = theme.get_color("gold", "custom")
		if theme.has_color("text_second", "custom"):
			text_second_color = theme.get_color("text_second", "custom")
	
	## 字体统一
	var labels: Array[Label] = [vs_label, round_label, log_head, stage_name_label,
		hero_name_label, enemy_name_label, hero_hp_meta, enemy_hp_meta]
	for lbl in labels:
		if lbl != null:
			lbl.add_theme_font_override("font", _font_cn)
	
	vs_label.add_theme_color_override("font_color", gold_color)
	round_label.add_theme_color_override("font_color", text_main_color)
	log_head.add_theme_color_override("font_color", gold_color)
	stage_name_label.add_theme_color_override("font_color", text_second_color)
	hero_name_label.add_theme_color_override("font_color", text_main_color)
	enemy_name_label.add_theme_color_override("font_color", text_main_color)
	hero_hp_meta.add_theme_color_override("font_color", text_main_color)
	enemy_hp_meta.add_theme_color_override("font_color", text_main_color)
	
	## 战斗日志字体
	battle_log.add_theme_font_override("normal_font", _font_cn)
	battle_log.add_theme_font_override("bold_font", _font_cn)
	
	## Skip 按钮样式：暗木调
	skip_button.add_theme_font_override("font", _font_cn)
	skip_button.add_theme_color_override("font_color", text_main_color)
	skip_button.add_theme_color_override("font_hover_color", gold_color)
	var skip_normal := StyleBoxFlat.new()
	skip_normal.bg_color = Color(0.12, 0.10, 0.08, 0.7)
	skip_normal.border_color = RunMainSettings.COLOR_WOOD_DARK
	skip_normal.border_width_left = 1
	skip_normal.border_width_top = 1
	skip_normal.border_width_right = 1
	skip_normal.border_width_bottom = 1
	skip_normal.corner_radius_top_left = 6
	skip_normal.corner_radius_top_right = 6
	skip_normal.corner_radius_bottom_left = 6
	skip_normal.corner_radius_bottom_right = 6
	skip_button.add_theme_stylebox_override("normal", skip_normal)
	var skip_hover := skip_normal.duplicate()
	skip_hover.bg_color = Color(0.18, 0.15, 0.10, 0.8)
	skip_hover.border_color = RunMainSettings.COLOR_WOOD_MEDIUM
	skip_button.add_theme_stylebox_override("hover", skip_hover)
	var skip_pressed := skip_normal.duplicate()
	skip_pressed.bg_color = Color(0.08, 0.06, 0.04, 0.9)
	skip_button.add_theme_stylebox_override("pressed", skip_pressed)

# ==========================================
# 播放入口
# ==========================================
func start_playback(recorder, hero_name: String, enemy_name: String,
					hero_max_hp: int, enemy_max_hp: int,
					_hero_partners: Array, _enemy_partners: Array,
					total_rounds: int = 0,
					hero_start_hp: int = -1,
					enemy_start_hp: int = -1,
					hero_sprite_path: String = "",
					enemy_sprite_path: String = "",
					current_floor: int = 1,
					events_by_turn: Dictionary = {}) -> void:
	_playback_generation += 1
	_result_emitted = false
	_is_frenzy_active = false
	_is_playing = true
	visible = true
	
	_recorder = recorder
	_events_by_turn = {}
	_turn_keys = []
	var _real_max_turn: int = 0
	
	if not events_by_turn.is_empty():
		## 使用传入的纯数据（跨场景传递）
		for k in events_by_turn.keys():
			var ik: int = int(k)
			_events_by_turn[ik] = events_by_turn[k]
			_turn_keys.append(ik)
			_real_max_turn = maxi(_real_max_turn, ik)
		_turn_keys.sort()
	elif _recorder != null and _recorder.has_method("get_events_by_turn"):
		var raw_events: Dictionary = _recorder.get_events_by_turn()
		for k in raw_events.keys():
			var ik: int = int(k)
			_events_by_turn[ik] = raw_events[k]
			_turn_keys.append(ik)
			_real_max_turn = maxi(_real_max_turn, ik)
		_turn_keys.sort()
	
	_sim_total_rounds = maxi(_real_max_turn, 1)
	
	_hero_max_hp = maxi(1, hero_max_hp)
	_hero_hp = hero_start_hp if hero_start_hp >= 0 else _hero_max_hp
	_enemy_max_hp = maxi(1, enemy_max_hp)
	_enemy_hp = enemy_start_hp if enemy_start_hp >= 0 else _enemy_max_hp
	_current_round = 0
	
	hero_name_label.text = hero_name
	enemy_name_label.text = enemy_name
	stage_name_label.text = "PVP 决斗场"
	
	## 初始化卡牌
	hero_card.visible = true
	enemy_card.visible = true
	_load_card_portrait(hero_portrait, hero_sprite_path, true)
	_load_card_portrait(enemy_portrait, enemy_sprite_path, false)
	
	## 设置关卡背景与敌方伙伴槽
	_current_floor = current_floor
	_set_stage_background(current_floor)
	_update_enemy_chain_slots(_enemy_partners)
	
	## 重置 Overlay
	_reset_card_overlay(true)
	_reset_card_overlay(false)
	
	## 重置卡牌位置和变换
	hero_card.position = _hero_card_orig_pos
	hero_card.rotation = 0.0
	hero_card.scale = Vector2.ONE
	enemy_card.position = _enemy_card_orig_pos
	enemy_card.rotation = 0.0
	enemy_card.scale = Vector2.ONE
	
	## 清理上次残留的5级伙伴动画节点
	for child in partner_anim_container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	
	_update_hp_display()
	_apply_hp_bar_colors()
	
	if _hero_hp <= 0 or _enemy_hp <= 0:
		battle_log.text = ""
		if _hero_hp <= 0:
			battle_log.append_text("[color=#D93826]%s 体力不支，无法战斗！[/color]\n" % hero_name_label.text)
		else:
			battle_log.append_text("[color=#5A8FD0]%s 已被击败！[/color]\n" % enemy_name_label.text)
		_show_result()
		return
	
	battle_log.text = ""
	battle_log.append_text("[color=#E6C040]战斗开始！[/color]\n")
	
	print("[BattleAnimation] 回放开始: gen=%d, 真实%d回合, recorder有效=%s" % [
		_playback_generation, _sim_total_rounds, _real_max_turn > 0
	])
	# 诊断日志：打印事件分组详情
	for turn_key in _turn_keys:
		var turn_events: Array = _events_by_turn.get(turn_key, [])
		print("[BattleAnimation] 回合 %d 事件数=%d" % [turn_key, turn_events.size()])
		for te in turn_events:
			print("[BattleAnimation]   - type=%s" % te.get("type", "???"))
	_clear_damage_numbers()
	_play_next_turn()

func _reset_card_overlay(is_hero: bool) -> void:
	var portrait: Sprite2D = hero_portrait if is_hero else enemy_portrait
	var glow: ColorRect = hero_glow if is_hero else enemy_glow
	portrait.modulate = Color.WHITE
	if portrait.material != null:
		portrait.material.set_shader_parameter("flash", 0.0)
		portrait.material.set_shader_parameter("saturation", 1.0)
	glow.color = Color(1, 1, 1, 0)

# ==========================================
# 多段攻击事件合并
# ==========================================
func _merge_combo_events(events: Array) -> Array:
	var merged: Array = []
	var i: int = 0
	while i < events.size():
		var evt: Dictionary = events[i]
		var evt_type: String = evt.get("type", "")
		
		if evt_type == "action_executed":
			var data: Dictionary = evt.get("data", {})
			var actor: String = data.get("actor_name", "")
			var action_type: String = data.get("action_type", "NORMAL")
			var combo_hits: Array = []
			var pending_damages: Array = []
			
			combo_hits.append({
				"value": data.get("result_summary", {}).get("value", 0),
				"is_crit": data.get("result_summary", {}).get("is_crit", false),
				"is_miss": data.get("result_summary", {}).get("is_miss", false),
			})
			
			var j: int = i + 1
			while j < events.size():
				var next_evt: Dictionary = events[j]
				var next_type: String = next_evt.get("type", "")
				
				if next_type == "unit_damaged":
					pending_damages.append(next_evt)
					j += 1
				elif next_type == "partner_assist" or next_type == "chain_triggered":
					## 合并伙伴援助/chain到当前action_executed，实现判定后立即执行
					if not data.has("follow_up_assists"):
						data["follow_up_assists"] = []
					data["follow_up_assists"].append(next_evt)
					j += 1
				elif next_type == "action_executed":
					var next_data: Dictionary = next_evt.get("data", {})
					if next_data.get("actor_name", "") == actor and next_data.get("action_type", "") == action_type:
						combo_hits.append({
							"value": next_data.get("result_summary", {}).get("value", 0),
							"is_crit": next_data.get("result_summary", {}).get("is_crit", false),
							"is_miss": next_data.get("result_summary", {}).get("is_miss", false),
						})
						j += 1
					else:
						break
				else:
					break
			
			if combo_hits.size() > 1:
				data["combo_hits"] = combo_hits

			data["pending_damages"] = pending_damages
			evt["data"] = data
			merged.append(evt)
			i = j
		else:
			merged.append(evt)
			i += 1
	
	return merged


# ==========================================
# 回合播放
# ==========================================
func _play_next_turn() -> void:
	if not _is_playing:
		print("[BattleAnim] _play_next_turn 被跳过: _is_playing=false")
		return
	
	_current_round += 1
	print("[BattleAnim] _play_next_turn: round=%d/%d, hero_hp=%d, enemy_hp=%d" % [
		_current_round, _sim_total_rounds, _hero_hp, _enemy_hp
	])
	
	var should_end: bool = _current_round > _sim_total_rounds
	if _hero_hp <= 0 or _enemy_hp <= 0:
		should_end = true
	
	if should_end:
		print("[BattleAnim] 战斗结束条件触发: should_end=true")
		_show_result()
		return
	
	round_label.text = "回合 %d" % _current_round
	battle_log.append_text("\n[color=#E6C040]━━ 回合 %d ━━[/color]\n" % _current_round)
	
	if _events_by_turn.has(_current_round):
		var events: Array = _events_by_turn[_current_round]
		var merged_events: Array = _merge_combo_events(events)
		if merged_events.size() > 0:
			if _event_tween != null and _event_tween.is_valid():
				_event_tween.kill()
			_event_tween = _create_anim_tween()
			for i in range(merged_events.size()):
				_event_tween.tween_callback(_safe_process_event.bind(merged_events[i]))
				_event_tween.tween_callback(_update_hp_display)
				_event_tween.tween_interval(0.5)
			_event_tween.tween_callback(func(): turn_timer.start(turn_timer.wait_time))
		else:
			turn_timer.start(turn_timer.wait_time)
	else:
		turn_timer.start(turn_timer.wait_time)

func _safe_process_event(evt: Dictionary) -> void:
	if evt == null or evt.is_empty():
		return
	_process_event(evt)

# ==========================================
# 事件处理
# ==========================================
func _process_event(evt: Dictionary) -> void:
	var type: String = evt.get("type", "")
	var data: Dictionary = evt.get("data", {})
	
	match type:
		"turn_started":
			var order: Array = data.get("order", [])
			if order.size() > 0:
				var actor: String = order[0].get("name", "???")
				battle_log.append_text("[color=#73737A]▸ %s 的行动[/color]\n" % actor)
			print("[BattleAnim] turn_started turn=%d" % data.get("turn", 0))
		
		"action_executed":
			var actor: String = data.get("actor_name", "???")
			var target: String = data.get("target_name", "???")
			var summary: Dictionary = data.get("result_summary", {})
			var is_miss: bool = summary.get("is_miss", false)
			var is_crit: bool = summary.get("is_crit", false)
			var value: int = summary.get("value", 0)
			var action_type: String = data.get("action_type", "NORMAL")
			var combo_hits: Array = data.get("combo_hits", [])
			
			if combo_hits.size() > 1:
				print("[BattleAnim] action_executed actor=%s target=%s action_type=%s COMBO=%d段" % [actor, target, action_type, combo_hits.size()])
			else:
				print("[BattleAnim] action_executed actor=%s target=%s action_type=%s value=%d miss=%s crit=%s" % [actor, target, action_type, value, is_miss, is_crit])
			
			if is_miss:
				battle_log.append_text("[color=#73737A]  %s → %s 闪避[/color]\n" % [actor, target])
				AudioManager.play_sfx("miss")
			elif is_crit:
				battle_log.append_text("[color=#F28A3E]  %s → %s 暴击 %d！[/color]\n" % [actor, target, value])
				AudioManager.play_sfx("crit")
			else:
				battle_log.append_text("  %s → %s %d\n" % [actor, target, value])
				AudioManager.play_sfx("attack")
			
			var anim_action: String = "attack"
			match action_type:
				"ULTIMATE":
					anim_action = "ultimate"
				"SKILL":
					anim_action = "skill"
				_:
					anim_action = "attack"
			
			if actor == hero_name_label.text:
				_pending_ultimate = (anim_action == "ultimate" and not is_miss)
				_play_card_attack(true, anim_action, combo_hits)
			elif actor == enemy_name_label.text:
				_pending_ultimate = (anim_action == "ultimate" and not is_miss)
				_play_card_attack(false, anim_action, combo_hits)
			else:
				print("[BattleAnim] ⚠ actor 不匹配，不播放攻击动画")
			
			## 判定成功后立即执行 follow_up（援助/chain）
			var follow_up_assists: Array = data.get("follow_up_assists", [])
			for assist_evt in follow_up_assists:
				_process_event(assist_evt)
			
			var pending_damages: Array = data.get("pending_damages", [])
			for pd in pending_damages:
				_process_event(pd)
		
		"unit_damaged":
			var is_combo_followup: bool = data.get("is_combo_followup", false)
			var is_combo_finisher: bool = data.get("is_combo_finisher", false)
			print("[BattleAnim] unit_damaged unit_id=%s damage=%d hp=%d followup=%s finisher=%s" % [data.get("unit_id", "???"), data.get("damage", 0), data.get("hp", 0), is_combo_followup, is_combo_finisher])
			
			var unit_id: String = data.get("unit_id", "")
			var hp: int = data.get("hp", 0)
			var is_crit: bool = data.get("is_crit", false)
			var damage: int = data.get("damage", 0)
			
			if unit_id == "hero" or unit_id.begins_with("hero"):
				_hero_hp = maxi(0, hp)
				
				if not is_combo_followup and not _is_ultimate_active:
					_flash_sprite(hero_portrait)
					_screen_shake(8.0, 0.15)
					
					if is_crit:
						VFX.critical_hit(hero_card.global_position + hero_card.size / 2)
						VFX.freeze_frame(0.08, 0.05)
					else:
						VFX.freeze_frame(0.05, 0.05)
					
					## 拟声词（SD纸片小剧场风格）
					var _sfx: String = SFX_CRIT.pick_random() if is_crit else SFX_ATTACK.pick_random()
					var _sfx_color: Color = COL_CRIT if is_crit else Color.WHITE
					_spawn_sfx_text(hero_portrait.global_position + Vector2(0, -140), _sfx, _sfx_color)
					
					_play_card_hurt(true, is_crit, _pending_ultimate)
					_pending_ultimate = false
					
					AudioManager.play_sfx("hero_hit")
					if not is_combo_finisher:
						_show_damage_number(damage, is_crit, false)
				
				if _hero_hp <= 0:
					## 死亡日志由 unit_died 事件统一处理，此处只播动画
					if not is_combo_followup and not _is_ultimate_active:
						VFX.kill_effect(hero_card.global_position + hero_card.size / 2)
						_play_card_death(true)
					AudioManager.play_sfx("defeat")
			else:
				_enemy_hp = maxi(0, hp)
				
				if not is_combo_followup and not _is_ultimate_active:
					_flash_sprite(enemy_portrait)
					_screen_shake(8.0, 0.15)
					
					if is_crit:
						VFX.critical_hit(enemy_card.global_position + enemy_card.size / 2)
						VFX.freeze_frame(0.08, 0.05)
					else:
						VFX.freeze_frame(0.05, 0.05)
					
					## 拟声词（SD纸片小剧场风格）
					var _sfx: String = SFX_CRIT.pick_random() if is_crit else SFX_ATTACK.pick_random()
					var _sfx_color: Color = COL_CRIT if is_crit else Color.WHITE
					_spawn_sfx_text(enemy_portrait.global_position + Vector2(0, -140), _sfx, _sfx_color)
					
					_play_card_hurt(false, is_crit, _pending_ultimate)
					_pending_ultimate = false
					
					AudioManager.play_sfx("enemy_hit")
					if not is_combo_finisher:
						_show_damage_number(damage, is_crit, true)
				
				if _enemy_hp <= 0:
					## 死亡日志由 unit_died 事件统一处理，此处只播动画
					if not is_combo_followup and not _is_ultimate_active:
						VFX.kill_effect(enemy_card.global_position + enemy_card.size / 2)
						_play_card_death(false)
					AudioManager.play_sfx("defeat")
		
		"unit_died":
			print("[BattleAnim] unit_died unit_id=%s" % data.get("unit_id", "???"))
			
			var uname: String = data.get("name", "???")
			battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % uname)
			AudioManager.play_sfx("defeat")
			if uname == hero_name_label.text:
				_play_card_death(true)
			elif uname == enemy_name_label.text:
				_play_card_death(false)
		
		"battle_ended":
			print("[BattleAnim] battle_ended winner=%s" % data.get("winner", "???"))
		
		"partner_assist":
			var pname: String = data.get("partner_name", "???")
			var assist_value: int = data.get("assist_value", 0)
			var assist_type: String = data.get("assist_type", "")
			battle_log.append_text("[color=#BF4DE6]  %s 援助攻击！[/color]\n" % pname)
			AudioManager.play_sfx("partner_assist")
			var slot: Control = _find_chain_slot_by_name(pname)
			## 伙伴特殊动画（传入实际数值，与事件系统同步）
			if pname == "猎人":
				_play_hunter_dash_slash(assist_value)
			elif pname == "剑士":
				_play_swordsman_jump_slash(assist_value)
			elif pname == "斥候":
				_play_scout_snipe(assist_value)
			elif pname == "术士":
				_play_sorcerer_curse(assist_value)
			elif pname == "药师":
				_play_pharmacist_heal(assist_value)
			elif pname == "盾卫":
				_play_shieldguard_defend(assist_value)
			else:
				if slot != null:
					_flash_chain_slot(slot)
		
		"chain_triggered":
			var chain_count: int = data.get("chain_count", 0)
			var pname: String = data.get("partner_name", "???")
			var dmg: int = data.get("damage", 0)
			battle_log.append_text("[color=#BF4DE6]  CHAIN x%d! %s %d[/color]\n" % [chain_count, pname, dmg])
			AudioManager.play_sfx("chain")
			_show_damage_number(dmg, false, true, true, chain_count)
			
			## 高亮所有触发连锁的伙伴 slot
			var partner_names: Array = data.get("partner_names", [pname])
			for chain_pname in partner_names:
				var slot: Control = _find_chain_slot_by_name(chain_pname)
				if slot != null:
					_flash_chain_slot(slot)
					## 更新 chain 数值显示
					var chain_label: Label = slot.get_node("ChainLabel")
					chain_label.text = "x chain %d" % chain_count
			
			## CHAIN 大字特效：在屏幕中央显示 CHAIN xN
			_show_chain_banner(chain_count)
		
		"ultimate_triggered":
			var log_text: String = data.get("log", "")
			battle_log.append_text("[color=#E6C040]  %s[/color]\n" % log_text)
			_screen_shake(18.0, 0.35)
			AudioManager.play_sfx("ultimate")
			_play_card_attack(true, "ultimate")
			_spawn_skill_aura(Color("#E6C040"))
			_show_ultimate_text(log_text)
		
		"frenzy_triggered":
			_is_frenzy_active = true
			var msg: String = data.get("message", "狂暴阶段触发！")
			battle_log.append_text("\n[color=red]★ %s ★[/color]\n" % msg)
			round_label.modulate = Color(1, 0.2, 0.2)
			_update_hp_display()
			AudioManager.play_sfx("frenzy_alert")
			_start_frenzy_glow()
	
	## 日志追加完成

# ==========================================
# 卡牌动画
# ==========================================
func _play_card_attack(is_hero: bool, action_type: String, combo_hits: Array = []) -> void:
	var card: Control = hero_card if is_hero else enemy_card
	var portrait: Sprite2D = hero_portrait if is_hero else enemy_portrait
	var orig_pos: Vector2 = _hero_portrait_orig_pos if is_hero else _enemy_portrait_orig_pos
	var dir: float = 1.0 if is_hero else -1.0
	var poses: Dictionary = _hero_poses if is_hero else _enemy_poses
	
	## 停止该卡牌的旧攻击/受击 tween，避免冲突
	if is_hero:
		_stop_idle_breath(hero_portrait)
		if _hero_attack_tween != null and _hero_attack_tween.is_valid():
			_hero_attack_tween.kill()
		if _hero_hurt_tween != null and _hero_hurt_tween.is_valid():
			_hero_hurt_tween.kill()
		hero_portrait.scale = Vector2.ONE * BASE_CARD_SCALE
		hero_portrait.rotation = 0.0
	else:
		_stop_idle_breath(enemy_portrait)
		if _enemy_attack_tween != null and _enemy_attack_tween.is_valid():
			_enemy_attack_tween.kill()
		if _enemy_hurt_tween != null and _enemy_hurt_tween.is_valid():
			_enemy_hurt_tween.kill()
		enemy_portrait.scale = Vector2.ONE * BASE_CARD_SCALE
		enemy_portrait.rotation = 0.0
	
	var orig_scale_x: float = BASE_CARD_SCALE
	var sign_x: float = sign(portrait.scale.x)
	if sign_x == 0: sign_x = 1
	
	match action_type:
		"ultimate":
			## skill2-01 翻面起手蓄力 —— 镜头推近攻击者 + 舞台暗化
			_is_ultimate_active = true
			var tween := _create_anim_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if is_hero: _hero_attack_tween = tween
			else: _enemy_attack_tween = tween
			
			## 切换 ultimate tween（0.65s 推近/返回）
			var _ult_tween: PhantomCameraTween = load("res://resources/phantom_camera_tween_ultimate.tres") as PhantomCameraTween
			if _ult_tween != null:
				if is_hero: pcam_hero.tween_resource = _ult_tween
				else: pcam_enemy.tween_resource = _ult_tween
				pcam_default.tween_resource = _ult_tween
			_stage_dim(0.4)
			_switch_camera_to("hero" if is_hero else "enemy")
			
			## 起手蓄力：0.25s 放大 + 上浮
			_tween_flip_to_pose(tween, portrait, poses.get("skill2-01", poses.get("idle")), 0.15)
			tween.tween_property(portrait, "scale", Vector2.ONE * 1.15, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(portrait, "position:y", orig_pos.y - 20, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			
			## 停顿 0.5s
			tween.tween_interval(0.5)
			
			## 缩回归位：0.3s 缩回 + 归位
			tween.tween_property(portrait, "scale", Vector2.ONE * 0.7, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tween.parallel().tween_property(portrait, "position:y", orig_pos.y, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			
			## 蓄力完成 —— 同步返回全景
			tween.tween_callback(func(): _switch_camera_to("default"))
			
			## skill2-02 翻面释放（原地多段连击，取消突进）
			_tween_flip_to_pose(tween, portrait, poses.get("skill2-02", poses.get("idle")), 0.12)
			tween.tween_callback(func(): _play_portrait_effect(portrait, "ultimate_slash"))
			
			## 多段伤害判定 —— 每段都触发完整受击震动，与伤害时间对齐
			var _target_portrait: Sprite2D = enemy_portrait if is_hero else hero_portrait
			if combo_hits.size() > 0:
				var hit_interval: float = 0.6 / maxi(combo_hits.size(), 1)
				for idx in range(combo_hits.size()):
					var hit: Dictionary = combo_hits[idx]
					## 在第 idx 段插入伤害回调，同步触发受击反应
					tween.tween_callback(func():
						if not hit.is_miss:
							var _target_is_hero: bool = not is_hero
							_play_hit_reaction(_target_is_hero, true, hit.is_crit)
							_show_damage_number(hit.value, hit.is_crit, is_hero)
							if hit.is_crit:
								var _target_card: Control = hero_card if _target_is_hero else enemy_card
								VFX.critical_hit(_target_card.global_position + _target_card.size / 2)
								VFX.freeze_frame(0.08, 0.05)
							else:
								VFX.freeze_frame(0.05, 0.05)
							AudioManager.play_sfx("hero_hit" if _target_is_hero else "enemy_hit")
						## 强制保持攻击者 scale = BASE_CARD_SCALE 防止异常
						portrait.scale = Vector2.ONE * BASE_CARD_SCALE
					)
					if idx < combo_hits.size() - 1:
						tween.tween_interval(hit_interval)
			else:
				## 无 combo_hits 时的默认单段
				tween.tween_callback(func():
					var _target_is_hero: bool = not is_hero
					_play_hit_reaction(_target_is_hero, true, false)
					VFX.freeze_frame(0.08, 0.05)
					AudioManager.play_sfx("hero_hit" if _target_is_hero else "enemy_hit")
				)
			
			## combo 命中核心 VFX（只在命中时播放一次）
			if combo_hits.size() > 0:
				tween.tween_callback(func():
					var _burst = preload("res://addons/vfx_library/effects/energy_burst.tscn").instantiate()
					sfx_layer.add_child(_burst)
					_burst.global_position = _target_portrait.global_position
					_burst.z_index = 100
					_burst.scale = Vector2.ONE * 4.0
					_burst.restart()
					get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(_burst): _burst.queue_free())
				)
			
			## 回 idle —— 恢复 fast tween，并清除 _is_ultimate_active
			tween.tween_interval(0.4)
			tween.tween_callback(func():
				_is_ultimate_active = false
				_pending_ultimate = false
				portrait.scale = Vector2.ONE * BASE_CARD_SCALE
				_tween_flip_to_pose(_create_anim_tween(), portrait, poses.get("idle"), 0.12)
				_start_idle_breath(portrait, 1.2 if not is_hero else 1.0)
				var _fast_tween: PhantomCameraTween = load("res://resources/phantom_camera_tween_fast.tres") as PhantomCameraTween
				if _fast_tween != null:
					pcam_default.tween_resource = _fast_tween
					pcam_hero.tween_resource = _fast_tween
					pcam_enemy.tween_resource = _fast_tween
			)
		"skill":
			var tween := _create_anim_tween()
			if is_hero: _hero_attack_tween = tween
			else: _enemy_attack_tween = tween
			
			## 疾风连击 pose key 映射：第1段=skill1-1，第2段=skill1-2，第3段=skill1-3，循环
			var _skill_pose_keys: Array[String] = ["skill1-1", "skill1-2", "skill1-3"]
			
			if combo_hits.size() > 1:
				## 多段技能（疾风连击）：每段切换不同 skill1 姿态，快速连击
				for idx in range(combo_hits.size()):
					var hit: Dictionary = combo_hits[idx]
					var _pose_key: String = _skill_pose_keys[idx % _skill_pose_keys.size()]
					if not hit.is_miss:
						_tween_flip_to_pose(tween, portrait, poses.get(_pose_key, poses.get("idle")), 0.08)
						tween.tween_callback(func():
							_play_portrait_effect(portrait, "skill_slash")
							_show_damage_number(hit.value, hit.is_crit, is_hero)
						)
						tween.tween_property(portrait, "position:x", orig_pos.x + dir * 80, 0.06)
						tween.parallel().tween_property(portrait, "rotation", dir * 0.08, 0.06)
						tween.tween_property(portrait, "position:x", orig_pos.x, 0.06)
						tween.parallel().tween_property(portrait, "rotation", 0.0, 0.06)
						tween.tween_interval(0.04)
				## 回 idle
				tween.tween_callback(func():
					_tween_flip_to_pose(_create_anim_tween(), portrait, poses.get("idle"), 0.12)
					_start_idle_breath(portrait, 1.2)
				)
			else:
				_tween_flip_to_pose(tween, portrait, poses.get("skill1-1", poses.get("idle")), 0.15)
				tween.tween_callback(func(): _play_portrait_effect(portrait, "skill_slash"))
				tween.tween_property(portrait, "position:x", orig_pos.x + dir * 120, 0.1)
				tween.parallel().tween_property(portrait, "rotation", dir * 0.12, 0.1)
				tween.tween_property(portrait, "position:x", orig_pos.x, 0.15)
				tween.parallel().tween_property(portrait, "rotation", 0.0, 0.15)
				## 回 idle
				tween.tween_callback(func():
					_tween_flip_to_pose(_create_anim_tween(), portrait, poses.get("idle"), 0.12)
					_start_idle_breath(portrait, 1.2)
				)
		_:
			## 普通攻击
			var tween := _create_anim_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if is_hero: _hero_attack_tween = tween
			else: _enemy_attack_tween = tween
			_tween_flip_to_pose(tween, portrait, poses.get("attack", poses.get("idle")), 0.15)
			tween.tween_callback(func(): _play_portrait_effect(portrait, "attack_slash"))
			tween.tween_property(portrait, "position:x", orig_pos.x + dir * 120, 0.1)
			tween.parallel().tween_property(portrait, "rotation", dir * 0.12, 0.1)
			tween.tween_property(portrait, "position:x", orig_pos.x, 0.15)
			tween.parallel().tween_property(portrait, "rotation", 0.0, 0.15)
			## 回 idle
			tween.tween_callback(func():
				_tween_flip_to_pose(_create_anim_tween(), portrait, poses.get("idle"), 0.12)
				_start_idle_breath(portrait, 1.2)
			)

func _play_card_hurt(is_hero: bool, is_crit: bool, is_knockback: bool = false) -> void:
	var portrait: Sprite2D = hero_portrait if is_hero else enemy_portrait
	var orig_pos: Vector2 = _hero_portrait_orig_pos if is_hero else _enemy_portrait_orig_pos
	var poses: Dictionary = _hero_poses if is_hero else _enemy_poses
	var back_dir: float = -1.0 if is_hero else 1.0
	
	var shake: float
	var back_rot: float
	var fly_time: float
	var recover_time: float
	var stay_time: float
	
	if is_knockback:
		shake = 100.0
		back_rot = 0.35
		fly_time = 0.1
		recover_time = 0.4
		stay_time = 0.4
	elif is_crit:
		shake = 8.0
		back_rot = 0.1
		fly_time = 0.06
		recover_time = 0.15
		stay_time = 0.2
	else:
		shake = 4.0
		back_rot = 0.1
		fly_time = 0.06
		recover_time = 0.15
		stay_time = 0.2
	
	## 停止旧的 hurt tween，避免冲突
	if is_hero:
		_stop_idle_breath(hero_portrait)
		if _hero_hurt_tween != null and _hero_hurt_tween.is_valid():
			_hero_hurt_tween.kill()
		if _hero_attack_tween != null and _hero_attack_tween.is_valid():
			_hero_attack_tween.kill()
		hero_portrait.scale = Vector2.ONE * BASE_CARD_SCALE
		hero_portrait.rotation = 0.0
	else:
		_stop_idle_breath(enemy_portrait)
		if _enemy_hurt_tween != null and _enemy_hurt_tween.is_valid():
			_enemy_hurt_tween.kill()
		if _enemy_attack_tween != null and _enemy_attack_tween.is_valid():
			_enemy_attack_tween.kill()
		enemy_portrait.scale = Vector2.ONE * BASE_CARD_SCALE
		enemy_portrait.rotation = 0.0
	
	var orig_scale_x: float = BASE_CARD_SCALE
	var sign_x: float = sign(portrait.scale.x)
	if sign_x == 0: sign_x = 1
	
	var tween := _create_anim_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if is_hero: _hero_hurt_tween = tween
	else: _enemy_hurt_tween = tween
	
	## 受击不加镜头切换，保持全景（仅保留 shake / 特效）
	
	## 翻面到 hit pose
	tween.tween_property(portrait, "scale:x", 0.06 * sign_x, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _set_pose(portrait, poses.get("hit", poses.get("idle"))))
	tween.tween_property(portrait, "scale:x", orig_scale_x * sign_x, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): _play_portrait_effect(portrait, "hit_spark"))
	
	## 弹性后仰 / 击飞
	tween.tween_property(portrait, "position:x", orig_pos.x + back_dir * shake, fly_time)
	tween.parallel().tween_property(portrait, "rotation", back_dir * back_rot, fly_time)
	tween.tween_property(portrait, "position:x", orig_pos.x, recover_time)
	tween.parallel().tween_property(portrait, "rotation", 0.0, recover_time)
	
	## 停留后再回 idle
	tween.tween_interval(stay_time)
	
	## 回 idle —— 保持全景，不加镜头切换
	tween.tween_callback(func():
		var t2 := _create_anim_tween()
		t2.tween_property(portrait, "scale:x", 0.06 * sign_x, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.tween_callback(func(): _set_pose(portrait, poses.get("idle")))
		t2.tween_property(portrait, "scale:x", orig_scale_x * sign_x, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t2.tween_callback(func(): _start_idle_breath(portrait, 1.2))
	)

## 轻量受击反应 —— 不杀死 attack tween，用于必杀/连招回调中同步触发
func _play_hit_reaction(is_hero_target: bool, is_ultimate: bool = false, is_crit: bool = false) -> void:
	var portrait: Sprite2D = hero_portrait if is_hero_target else enemy_portrait
	var orig_pos: Vector2 = _hero_portrait_orig_pos if is_hero_target else _enemy_portrait_orig_pos
	var back_dir: float = -1.0 if is_hero_target else 1.0

	var shake: float = 100.0 if is_ultimate else (8.0 if is_crit else 4.0)
	var back_rot: float = 0.35 if is_ultimate else 0.1
	var fly_time: float = 0.1 if is_ultimate else 0.06
	var recover_time: float = 0.4 if is_ultimate else 0.15
	var stay_time: float = 0.4 if is_ultimate else 0.2

	_screen_shake(shake, 0.1 if is_ultimate else 0.15)
	_flash_sprite(portrait)

	## 停止 idle breath
	_stop_idle_breath(portrait)

	## 杀死旧的 hurt tween
	if is_hero_target:
		if _hero_hurt_tween != null and _hero_hurt_tween.is_valid():
			_hero_hurt_tween.kill()
	else:
		if _enemy_hurt_tween != null and _enemy_hurt_tween.is_valid():
			_enemy_hurt_tween.kill()

	var sign_x: float = sign(portrait.scale.x)
	if sign_x == 0: sign_x = 1

	var tween := _create_anim_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if is_hero_target:
		_hero_hurt_tween = tween
	else:
		_enemy_hurt_tween = tween

	## 翻面到 hit pose
	tween.tween_property(portrait, "scale:x", 0.06 * sign_x, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(portrait, "scale:x", BASE_CARD_SCALE * sign_x, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	## 受击弹开
	var back_dist: float = 60 if is_ultimate else 40
	tween.tween_property(portrait, "position:x", orig_pos.x + back_dir * back_dist, fly_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(portrait, "rotation", back_dir * back_rot, fly_time)

	## 停留
	tween.tween_interval(stay_time)

	## 恢复
	tween.tween_property(portrait, "position:x", orig_pos.x, recover_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(portrait, "rotation", 0.0, recover_time)

func _play_card_death(is_hero: bool) -> void:
	var card: Control = hero_card if is_hero else enemy_card
	var portrait: Sprite2D = hero_portrait if is_hero else enemy_portrait
	
	## 防止重复播放死亡动画
	if card.modulate.a <= 0.0 or not card.visible:
		return
	
	## 停止该卡牌的所有动画 tween
	if is_hero:
		if _hero_attack_tween != null and _hero_attack_tween.is_valid():
			_hero_attack_tween.kill()
		if _hero_hurt_tween != null and _hero_hurt_tween.is_valid():
			_hero_hurt_tween.kill()
		if _hero_death_tween != null and _hero_death_tween.is_valid():
			_hero_death_tween.kill()
		hero_portrait.scale = Vector2.ONE * BASE_CARD_SCALE
		hero_portrait.rotation = 0.0
	else:
		if _enemy_attack_tween != null and _enemy_attack_tween.is_valid():
			_enemy_attack_tween.kill()
		if _enemy_hurt_tween != null and _enemy_hurt_tween.is_valid():
			_enemy_hurt_tween.kill()
		if _enemy_death_tween != null and _enemy_death_tween.is_valid():
			_enemy_death_tween.kill()
		enemy_portrait.scale = Vector2.ONE * BASE_CARD_SCALE
		enemy_portrait.rotation = 0.0
	
	var gray_tween := _create_anim_tween()
	if is_hero: _hero_death_tween = gray_tween
	else: _enemy_death_tween = gray_tween
	gray_tween.tween_method(func(t: float):
		if is_instance_valid(portrait) and portrait.material != null:
			portrait.material.set_shader_parameter("saturation", 1.0 - t)
	, 0.0, 1.0, 0.5)
	
	var fade_tween := _create_anim_tween()
	fade_tween.tween_property(card, "modulate:a", 0.0, 1.0).set_delay(0.3)
	fade_tween.tween_callback(func():
		if is_instance_valid(card):
			card.visible = false
			card.modulate.a = 1.0
		if is_instance_valid(portrait) and portrait.material != null:
			portrait.material.set_shader_parameter("saturation", 1.0)
	)

func _card_glow_pulse(card: Control, glow_color: Color, duration: float) -> void:
	var glow: ColorRect = null
	if card.has_node("Portrait/GlowOverlay"):
		glow = card.get_node("Portrait/GlowOverlay")
	elif card.has_node("GlowOverlay"):
		glow = card.get_node("GlowOverlay")
	if glow == null:
		return
	
	## 停止旧的 glow tween
	if glow.has_meta("glow_pulse_tween"):
		var old: Tween = glow.get_meta("glow_pulse_tween")
		if old != null and old.is_valid():
			old.kill()
		glow.remove_meta("glow_pulse_tween")
	
	glow.color = glow_color
	var tween := _create_anim_tween()
	glow.set_meta("glow_pulse_tween", tween)
	tween.tween_property(glow, "color:a", 0.6, duration * 0.3)
	tween.tween_property(glow, "color:a", 0.0, duration * 0.7)

func _flash_sprite(sprite: Sprite2D) -> void:
	sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween := _create_anim_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)

# ==========================================
# VFX 辅助
# ==========================================
func _spawn_slash_trail(from: Vector2, to: Vector2, is_hero: bool) -> void:
	var slash := Line2D.new()
	slash.name = "SlashTrail"
	slash.points = [from, to]
	slash.width = 4.0
	slash.default_color = Color("#E6C040") if is_hero else Color("#D93826")
	slash.antialiased = true
	add_child(slash)
	
	var tween := _create_anim_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.2).set_delay(0.05)
	tween.tween_callback(func():
		if is_instance_valid(slash):
			slash.queue_free()
	)
	## 备份删除：即使 tween 被中断，0.5 秒后强制删除
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(slash):
			slash.queue_free()
	)

func _spawn_skill_aura(aura_color: Color) -> void:
	var aura := ColorRect.new()
	aura.name = "SkillAura"
	aura.set_anchors_preset(Control.PRESET_FULL_RECT)
	aura.color = Color(0, 0, 0, 0)
	
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/radial_burst.gdshader")
	mat.set_shader_parameter("aura_color", aura_color)
	aura.material = mat
	
	add_child(aura)
	
	var tween := _create_anim_tween()
	tween.tween_method(func(t: float):
		mat.set_shader_parameter("progress", t)
	, 0.0, 1.0, 0.6)
	tween.tween_callback(func():
		if is_instance_valid(aura):
			aura.queue_free()
	)

func _show_ultimate_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font_cn)
	label.add_theme_font_size_override("font_size", 48)
	label.modulate = Color("#E6C040")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	
	var min_size: Vector2 = label.get_combined_minimum_size()
	label.position = Vector2(size.x / 2 - min_size.x / 2, size.y * 0.3)
	label.scale = Vector2(1.5, 1.5)
	
	var tween := _create_anim_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 60, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)

func _start_frenzy_glow() -> void:
	_stop_frenzy_glow()
	
	## 回合数红色标记
	round_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	
	## 血条外框红色闪烁（通过 border_flash_color，不污染整体色调）
	if _hero_hp_bar_fancy != null:
		_hero_hp_bar_fancy.start_frenzy_border_flash()
	if _enemy_hp_bar_fancy != null:
		_enemy_hp_bar_fancy.start_frenzy_border_flash()
	
	set_meta("frenzy_active", true)

func _stop_frenzy_glow() -> void:
	if has_meta("frenzy_active"):
		remove_meta("frenzy_active")
	
	## 恢复回合数颜色
	round_label.add_theme_color_override("font_color", COL_TEXT_MAIN)
	
	## 停止血条外框闪烁
	if _hero_hp_bar_fancy != null:
		_hero_hp_bar_fancy.stop_frenzy_border_flash()
	if _enemy_hp_bar_fancy != null:
		_enemy_hp_bar_fancy.stop_frenzy_border_flash()

# ==========================================
# 伙伴链
# ==========================================
func _init_chain_slots() -> void:
	_chain_slots.clear()
	for child in partner_chain_list.get_children():
		if child is HBoxContainer:
			_chain_slots.append(child)
			child.visible = false
			## 给 slot 内的标签统一字体和颜色
			var name_label: Label = child.get_node("NameLabel")
			var chain_label: Label = child.get_node("ChainLabel")
			name_label.add_theme_font_override("font", _font_cn)
			chain_label.add_theme_font_override("font", _font_cn)
			name_label.add_theme_color_override("font_color", COL_GOLD)
			chain_label.add_theme_color_override("font_color", COL_TEXT_SECOND)
			name_label.add_theme_font_size_override("font_size", 14)
			chain_label.add_theme_font_size_override("font_size", 12)

func _get_partner_icon_path(partner_name: String) -> String:
	match partner_name:
		"猎人": return "res://assets/characters/card/partners/aibo icon/assassin icon.png"
		"斥候": return "res://assets/characters/card/partners/aibo icon/archor icon.png"
		"术士": return "res://assets/characters/card/partners/aibo icon/maho icon.png"
		"药师": return "res://assets/characters/card/partners/aibo icon/wizard icon.png"
		"剑士": return "res://assets/characters/card/partners/aibo icon/sword icon.png"
		_: return ""


func _update_chain_slots(partners: Array) -> void:
	for i in range(_chain_slots.size()):
		var slot: Control = _chain_slots[i]
		if i < partners.size():
			var p = partners[i]
			var name_label: Label = slot.get_node("NameLabel")
			var chain_label: Label = slot.get_node("ChainLabel")
			var avatar: TextureRect = slot.get_node("Avatar")
			
			name_label.text = p.get("name", "???")
			chain_label.text = "x chain %d" % p.get("chain_count", 0)
			
			## 职业图标（32×32）
			var icon_path: String = _get_partner_icon_path(p.get("name", ""))
			var tex: Texture2D = load(icon_path) as Texture2D if not icon_path.is_empty() else null
			if tex == null:
				## fallback 到旧头像
				var fallback_path: String = p.get("icon_path", "")
				tex = _resolve_texture_from_path(fallback_path)
				if tex == null or fallback_path.is_empty():
					var fallback_name: String = p.get("name", "")
					if not fallback_name.is_empty():
						fallback_path = "res://assets/characters/partner/" + fallback_name + "/partner_" + fallback_name + "_lv1.png"
						tex = _resolve_texture_from_path(fallback_path)
			if avatar != null:
				avatar.texture = tex
				avatar.custom_minimum_size = Vector2(32, 32)
			slot.visible = true
		else:
			slot.visible = false

func _find_chain_slot_by_name(pname: String) -> Control:
	for slot in _chain_slots:
		var name_label: Label = slot.get_node("NameLabel")
		if name_label.text == pname:
			return slot
	return null

func _flash_chain_slot(slot: Control) -> void:
	var orig: Color = slot.modulate
	var tween := _create_anim_tween()
	tween.tween_property(slot, "modulate", Color(1.3, 1.3, 1.0), 0.15)
	tween.tween_property(slot, "modulate", orig, 0.3)

# ==========================================
# 5级伙伴逐帧动画
# ==========================================
func _play_partner_action(partner_name: String, partner_level: int, action: String, partner_sprite_path: String, partner_anim_name: String) -> void:
	if partner_level < 5:
		var slot: Control = _find_chain_slot_by_name(partner_name)
		if slot != null:
			_flash_chain_slot(slot)
		return
	
	var sprite := AnimatedSprite2D.new()
	sprite.name = "PartnerAnim_%s" % partner_name
	
	var frames: Resource = load(partner_sprite_path)
	if frames == null or not frames is SpriteFrames:
		push_warning("[BattleAnimation] 无法加载5级伙伴动画: %s" % partner_sprite_path)
		sprite.queue_free()
		return
	
	sprite.sprite_frames = frames
	sprite.autoplay = partner_anim_name
	
	## 使用全局坐标，再转换为 partner_anim_container 的局部坐标
	var spawn_pos_global: Vector2 = _get_partner_spawn_position(action)
	var attack_pos_global: Vector2 = enemy_card.global_position + Vector2(-10, 0)
	var spawn_pos_local: Vector2 = partner_anim_container.to_local(spawn_pos_global)
	var attack_pos_local: Vector2 = partner_anim_container.to_local(attack_pos_global)
	
	sprite.position = spawn_pos_local
	sprite.scale = Vector2(2.0, 2.0)
	sprite.modulate.a = 0.0
	
	partner_anim_container.add_child(sprite)
	sprite.play(partner_anim_name)
	
	var enter_tween := _create_anim_tween()
	enter_tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	enter_tween.tween_property(sprite, "position", attack_pos_local, 0.3)
	
	## 动画结束后飞回并删除
	var _anim_finished := func():
		if not is_instance_valid(sprite):
			return
		var exit_tween := _create_anim_tween()
		exit_tween.tween_property(sprite, "position", spawn_pos_local, 0.2)
		exit_tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
		exit_tween.tween_callback(func():
			if is_instance_valid(sprite):
				sprite.queue_free()
		)
	
	## 用动画时长或 fallback 定时器
	if sprite.sprite_frames.has_animation(partner_anim_name):
		var anim_frames: int = sprite.sprite_frames.get_frame_count(partner_anim_name)
		var anim_fps: float = sprite.sprite_frames.get_animation_speed(partner_anim_name)
		var anim_duration: float = anim_frames / maxf(anim_fps, 1.0)
		await get_tree().create_timer(anim_duration).timeout
		if is_instance_valid(sprite):
			_anim_finished.call()
	else:
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(sprite):
			_anim_finished.call()

func _get_partner_spawn_position(_action: String) -> Vector2:
	return hero_card.global_position + Vector2(-350, -40)

# ==========================================
# 头像加载
# ==========================================
func _resolve_texture_from_path(path: String) -> Texture2D:
	## 统一处理纹理加载：支持 Texture2D 和 SpriteFrames（自动取第一帧）
	if path.is_empty():
		return null
	var res: Resource = load(path)
	if res == null:
		return null
	if res is Texture2D:
		return res as Texture2D
	if res is SpriteFrames:
		var frames: SpriteFrames = res
		var anim_names: PackedStringArray = frames.get_animation_names()
		for anim_name in anim_names:
			var frame_count: int = frames.get_frame_count(anim_name)
			if frame_count > 0:
				return frames.get_frame_texture(anim_name, 0)
	return null

func _create_placeholder_texture(is_hero: bool) -> GradientTexture2D:
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	if is_hero:
		gradient.gradient.colors = [Color("#4ECDC4"), Color("#2B6B5E")]
	else:
		gradient.gradient.colors = [Color("#FF6B6B"), Color("#8B2E2E")]
	gradient.width = 200
	gradient.height = 200
	return gradient

func _load_card_portrait(portrait: Sprite2D, path: String, is_hero: bool) -> void:
	var texture: Texture2D = _resolve_texture_from_path(path)
	if texture == null:
		if not path.is_empty():
			push_warning("[BattleAnimation] 无法加载头像: %s" % path)
		## 路径为空时使用已有的 pose 纹理，不覆盖为 placeholder
		var poses: Dictionary = _hero_poses if is_hero else _enemy_poses
		texture = poses.get("idle") as Texture2D
		if texture == null:
			texture = _create_placeholder_texture(is_hero)
	if portrait != null:
		portrait.texture = texture
	## 同步更新 pose 字典中的 idle 纹理（仅当传入了有效路径时）
	## 注意：不覆盖 attack/hit/skill1/skill2/victory，保留 _load_hero_poses 加载的完整 pose 图
	if not path.is_empty():
		var poses: Dictionary = _hero_poses if is_hero else _enemy_poses
		poses["idle"] = texture
	


# ==========================================
# HP 条与辅助
# ==========================================
func _apply_hp_bar_colors() -> void:
	## 如果高级血条已初始化，跳过 ProgressBar 样式设置
	if _hero_hp_bar_fancy != null and _enemy_hp_bar_fancy != null:
		return
	
	## 英雄 HP 条：蓝色填充 + 暗木边框背景
	var hero_bg := StyleBoxFlat.new()
	hero_bg.bg_color = Color(0.10, 0.08, 0.06, 1.0)
	hero_bg.border_color = RunMainSettings.COLOR_WOOD_DARK
	hero_bg.border_width_left = 2
	hero_bg.border_width_top = 2
	hero_bg.border_width_right = 2
	hero_bg.border_width_bottom = 2
	hero_bg.corner_radius_top_left = 6
	hero_bg.corner_radius_top_right = 6
	hero_bg.corner_radius_bottom_left = 6
	hero_bg.corner_radius_bottom_right = 6
	hero_hp_bar.add_theme_stylebox_override("background", hero_bg)

	var hero_fill := StyleBoxFlat.new()
	hero_fill.bg_color = COL_BLUE_MAIN
	hero_fill.corner_radius_top_left = 4
	hero_fill.corner_radius_top_right = 4
	hero_fill.corner_radius_bottom_left = 4
	hero_fill.corner_radius_bottom_right = 4
	hero_hp_bar.add_theme_stylebox_override("fill", hero_fill)

	## 敌人 HP 条：红色填充 + 暗木边框背景
	var enemy_bg := StyleBoxFlat.new()
	enemy_bg.bg_color = Color(0.10, 0.08, 0.06, 1.0)
	enemy_bg.border_color = RunMainSettings.COLOR_WOOD_DARK
	enemy_bg.border_width_left = 2
	enemy_bg.border_width_top = 2
	enemy_bg.border_width_right = 2
	enemy_bg.border_width_bottom = 2
	enemy_bg.corner_radius_top_left = 6
	enemy_bg.corner_radius_top_right = 6
	enemy_bg.corner_radius_bottom_left = 6
	enemy_bg.corner_radius_bottom_right = 6
	enemy_hp_bar.add_theme_stylebox_override("background", enemy_bg)

	var enemy_fill := StyleBoxFlat.new()
	enemy_fill.bg_color = COL_RED_MAIN
	enemy_fill.corner_radius_top_left = 4
	enemy_fill.corner_radius_top_right = 4
	enemy_fill.corner_radius_bottom_left = 4
	enemy_fill.corner_radius_bottom_right = 4
	enemy_hp_bar.add_theme_stylebox_override("fill", enemy_fill)

func _on_turn_timer_timeout() -> void:
	if not _is_playing:
		return
	_play_next_turn()

func finish_battle() -> void:
	if _is_playing and not _result_emitted:
		_show_result()

func _on_skip() -> void:
	if _result_emitted or not visible:
		return
	print("[BattleAnimation] 跳过, gen=%d" % _playback_generation)
	_is_playing = false
	turn_timer.stop()
	if _event_tween != null and _event_tween.is_valid():
		_event_tween.kill()
	## 清理所有残留 VFX（黄框/黄线等）
	_clear_vfx_residuals()
	_show_result()

func _play_victory_pose(is_hero: bool) -> void:
	var portrait: Sprite2D = hero_portrait if is_hero else enemy_portrait
	var poses: Dictionary = _hero_poses if is_hero else _enemy_poses
	var sign_x: float = sign(portrait.scale.x)
	if sign_x == 0: sign_x = 1
	
	var tween := _create_anim_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(portrait, "scale:x", 0.06 * sign_x, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _set_pose(portrait, poses.get("victory", poses.get("idle"))))
	tween.tween_property(portrait, "scale:x", BASE_CARD_SCALE * sign_x, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_result() -> void:
	_is_playing = false
	turn_timer.stop()
	if _result_emitted:
		return
	_result_emitted = true
	
	## 清理所有残留 VFX（黄框/黄线/粒子等）
	_clear_vfx_residuals()
	
	## 胜利/失败 Pose
	if _hero_hp <= 0 and _enemy_hp > 0:
		_play_victory_pose(false)
	elif _enemy_hp <= 0 and _hero_hp > 0:
		_play_victory_pose(true)
	_update_hp_display()
	
	## 战斗结束标记（死亡日志已由 unit_died 事件处理，此处不再重复）
	battle_log.append_text("\n[color=#E6C040]=== 战斗结束 ===[/color]")
	print("[BattleAnimation] confirmed, gen=%d" % _playback_generation)
	confirmed.emit.call_deferred()

func reset_panel() -> void:
	_is_playing = false
	turn_timer.stop()
	if _event_tween != null and _event_tween.is_valid():
		_event_tween.kill()
	_current_round = 0
	_hero_hp = 0
	_hero_max_hp = 0
	_enemy_hp = 0
	_enemy_max_hp = 0
	_recorder = null
	_events_by_turn = {}
	_turn_keys = []
	_is_frenzy_active = false
	_pending_ultimate = false
	_is_ultimate_active = false
	_stop_frenzy_glow()
	_clear_damage_numbers()
	battle_log.text = ""
	
	## Kill 所有残留 tween
	if _hero_attack_tween != null and _hero_attack_tween.is_valid(): _hero_attack_tween.kill()
	if _enemy_attack_tween != null and _enemy_attack_tween.is_valid(): _enemy_attack_tween.kill()
	if _hero_hurt_tween != null and _hero_hurt_tween.is_valid(): _hero_hurt_tween.kill()
	if _enemy_hurt_tween != null and _enemy_hurt_tween.is_valid(): _enemy_hurt_tween.kill()
	if _hero_death_tween != null and _hero_death_tween.is_valid(): _hero_death_tween.kill()
	if _enemy_death_tween != null and _enemy_death_tween.is_valid(): _enemy_death_tween.kill()
	if _event_tween != null and _event_tween.is_valid(): _event_tween.kill()
	
	## 清理所有残留 VFX（黄框/黄线等）
	_clear_vfx_residuals()
	
	## 重置主角/敌方卡牌
	hero_card.visible = true
	hero_card.modulate.a = 1.0
	hero_card.position = _hero_card_orig_pos
	hero_card.rotation = 0.0
	hero_card.scale = Vector2.ONE
	_reset_card_overlay(true)
	
	enemy_card.visible = true
	enemy_card.modulate.a = 1.0
	enemy_card.position = _enemy_card_orig_pos
	enemy_card.rotation = 0.0
	enemy_card.scale = Vector2.ONE
	_reset_card_overlay(false)
	
	## 重置 Portrait
	_stop_idle_breath(hero_portrait)
	_stop_idle_breath(enemy_portrait)
	if hero_portrait != null:
		hero_portrait.position = _hero_portrait_orig_pos
		hero_portrait.rotation = 0.0
		hero_portrait.scale = Vector2.ONE * 0.7
		_set_pose(hero_portrait, _hero_poses.get("idle"))
		_start_idle_breath(hero_portrait, 1.2)
	if enemy_portrait != null:
		enemy_portrait.position = _enemy_portrait_orig_pos
		enemy_portrait.rotation = 0.0
		enemy_portrait.scale = Vector2.ONE * 0.7
		enemy_portrait.flip_h = true
		_set_pose(enemy_portrait, _enemy_poses.get("idle"))
		_start_idle_breath(enemy_portrait, 1.2)
	
	## 清理5级伙伴动画节点
	for child in partner_anim_container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	
	visible = false

func _update_hp_display() -> void:
	var hero_current: int = maxi(0, _hero_hp)
	var enemy_current: int = maxi(0, _enemy_hp)
	hero_hp_meta.text = "%d / %d" % [hero_current, _hero_max_hp]
	enemy_hp_meta.text = "%d / %d" % [enemy_current, _enemy_max_hp]
	
	var hero_ratio: float = float(_hero_hp) / maxi(1, _hero_max_hp)
	
	## 使用高级血条动画更新
	if _hero_hp_bar_fancy != null:
		_hero_hp_bar_fancy.max_value = float(_hero_max_hp)
		_hero_hp_bar_fancy.set_value_animated(float(_hero_hp), 0.35)
	else:
		hero_hp_bar.value = hero_ratio * 100
	
	if _enemy_hp_bar_fancy != null:
		_enemy_hp_bar_fancy.max_value = float(_enemy_max_hp)
		_enemy_hp_bar_fancy.set_value_animated(float(_enemy_hp), 0.35)
	else:
		enemy_hp_bar.value = float(_enemy_hp) / maxi(1, _enemy_max_hp) * 100
	
	## 低血量闪烁（旧版 ProgressBar 兼容）
	if _hero_hp_bar_fancy == null:
		if hero_ratio < 0.3 and not _is_frenzy_active:
			if _hp_bar_flash_tween == null or not _hp_bar_flash_tween.is_valid():
				_hp_bar_flash_tween = create_tween().set_loops()
				_hp_bar_flash_tween.tween_property(hero_hp_bar, "modulate", Color(1, 0.3, 0.3), 0.3)
				_hp_bar_flash_tween.tween_property(hero_hp_bar, "modulate", Color(1, 1, 1), 0.3)
		else:
			if _hp_bar_flash_tween != null and _hp_bar_flash_tween.is_valid():
				_hp_bar_flash_tween.kill()
			_hp_bar_flash_tween = null
			if not _is_frenzy_active:
				hero_hp_bar.modulate = Color(1, 1, 1)
	
	if _is_frenzy_active:
		if _hero_hp_bar_fancy == null:
			hero_hp_bar.modulate = Color(1, 0.2, 0.2)
		if _enemy_hp_bar_fancy == null:
			enemy_hp_bar.modulate = Color(1, 0.2, 0.2)
	else:
		if _enemy_hp_bar_fancy == null:
			enemy_hp_bar.modulate = Color(1, 1, 1)

func _show_damage_number(damage: int, is_crit: bool, is_enemy_side: bool, is_chain: bool = false, chain_count: int = 0) -> void:
	var label := Label.new()
	label.name = "DamageNum_%d" % randi()
	label.add_theme_font_override("font", _font_cn)
	
	if is_chain:
		label.text = "CHAIN x%d! %d" % [chain_count, damage]
		label.add_theme_font_size_override("font_size", 28)
		label.modulate = Color(0.8, 0.3, 1.0)
	elif is_crit:
		label.text = str(damage)
		label.add_theme_font_size_override("font_size", 36)
		label.modulate = Color(1, 0.1, 0.1)
	else:
		label.text = str(damage)
		label.add_theme_font_size_override("font_size", 26)
		label.modulate = Color(1, 0.9, 0.3)
	
	var label_settings := LabelSettings.new()
	label_settings.font_size = label.get_theme_font_size("font_size")
	label_settings.font_color = label.modulate
	label_settings.outline_size = 2
	label_settings.outline_color = Color(0, 0, 0, 0.8)
	label_settings.shadow_size = 2
	label_settings.shadow_color = Color(0, 0, 0, 0.5)
	label.label_settings = label_settings
	
	var target_card: Control = enemy_card if is_enemy_side else hero_card
	var card_center: Vector2 = target_card.global_position + target_card.size / 2
	label.global_position = Vector2(card_center.x - 20, card_center.y - 30)
	label.z_index = 100
	add_child(label)
	
	var tween := _create_anim_tween()
	var start_y: float = label.global_position.y
	
	if is_crit:
		label.scale = Vector2(1.5, 1.5)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "global_position:y", start_y - 80, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "global_position:y", start_y + 20, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(label, "modulate:a", 0, 0.3)
	elif is_chain:
		tween.tween_property(label, "global_position:y", start_y - 100, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(label, "rotation", deg_to_rad(10), 0.3)
		tween.tween_property(label, "modulate:a", 0, 0.4)
	else:
		label.scale = Vector2(1.15, 1.15)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "global_position:y", start_y - 60, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "global_position:y", start_y + 10, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(label, "modulate:a", 0, 0.3)
	
	tween.tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)

func _clear_damage_numbers() -> void:
	for child in get_children():
		if is_instance_valid(child) and child is Label and child.name.begins_with("DamageNum_"):
			child.queue_free()


func _clear_vfx_residuals() -> void:
	## 清理 GlowOverlay 颜色残留（防止黄框）
	if hero_glow != null:
		hero_glow.color = Color(1, 1, 1, 0)
	if enemy_glow != null:
		enemy_glow.color = Color(1, 1, 1, 0)
	## 清理 Line2D 残留（防止黄线）
	for child in get_children():
		if not is_instance_valid(child):
			continue
		if child is Line2D and child.name == "SlashTrail":
			child.queue_free()
	## 清理 SkillAura 残留
	for child in get_children():
		if not is_instance_valid(child):
			continue
		if child is ColorRect and child.name == "SkillAura":
			child.queue_free()
	## 清理 sfx_layer 中的残留粒子/效果
	if sfx_layer != null:
		for child in sfx_layer.get_children():
			if is_instance_valid(child):
				child.queue_free()

## ==========================================
## Phantom Camera 镜头控制
## ==========================================
func _stage_dim(duration: float = 0.5) -> void:
	## 舞台暗化：背景变暗，聚焦角色
	var bg: ColorRect = $SemiTransparentBg
	var tween: Tween = _create_anim_tween()
	tween.tween_property(bg, "modulate", Color(0.4, 0.4, 0.5, 0.70), duration)
	tween.tween_interval(duration)
	tween.tween_property(bg, "modulate", Color(1, 1, 1, 0.0), duration * 1.5)

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

func _screen_shake(strength: float = 4.0, duration: float = 0.1) -> void:
	## 使用 Phantom Camera Noise Emitter 替代手写 offset 震动
	if noise_emitter == null:
		return
	## 根据强度动态切换 noise 资源
	var noise_res: PhantomCameraNoise2D
	if strength >= 15.0:
		noise_res = load("res://resources/phantom_camera_noise_heavy.tres") as PhantomCameraNoise2D
	else:
		noise_res = load("res://resources/phantom_camera_noise_medium.tres") as PhantomCameraNoise2D
	if noise_res != null:
		noise_emitter.noise = noise_res
	noise_emitter.duration = duration
	noise_emitter.emit()

func _flash_partner_icon(_partner_name: String) -> void:
	pass


# ==========================================
# CHAIN 横幅特效
# ==========================================
func _show_chain_banner(chain_count: int) -> void:
	if chain_count <= 0:
		return
	var banner := Label.new()
	banner.name = "ChainBanner_%d" % randi()
	banner.text = "CHAIN x%d!" % chain_count
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_override("font", _font_cn)
	banner.add_theme_font_size_override("font_size", 48)
	banner.modulate = Color(0.9, 0.4, 1.0)
	
	## 描边效果：用阴影偏移模拟
	banner.add_theme_color_override("font_shadow_color", Color(0.3, 0.0, 0.5))
	banner.add_theme_constant_override("shadow_offset_x", 2)
	banner.add_theme_constant_override("shadow_offset_y", 2)
	
	## 定位到屏幕中央偏上
	var vp_size: Vector2 = get_viewport_rect().size
	banner.position = Vector2(vp_size.x * 0.5 - 150, vp_size.y * 0.25)
	banner.size = Vector2(300, 80)
	add_child(banner)
	
	## 动画：弹入 + 停留 + 淡出
	var tween := _create_anim_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner.scale = Vector2(0.3, 0.3)
	tween.tween_property(banner, "scale", Vector2(1.3, 1.3), 0.25)
	tween.chain().tween_property(banner, "scale", Vector2(1.0, 1.0), 0.15)
	tween.chain().tween_interval(0.6)
	tween.chain().tween_property(banner, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): if is_instance_valid(banner): banner.queue_free())


# ==========================================
# 斥候狙击动画
# ==========================================
func _load_scout_poses() -> void:
	var base: String = "res://assets/characters/partner/scout/"
	for pose_name in ["idle", "ready", "action"]:
		var path: String = base + pose_name + "/" + pose_name + ".png"
		var tex: Texture2D = _resolve_texture_from_path(path)
		if tex != null:
			_scout_poses[pose_name] = tex

# ==========================================
# 术士黑暗诅咒动画
# ==========================================
func _load_sorcerer_poses() -> void:
	var base: String = "res://assets/characters/partner/sorcerer/"
	for pose_name in ["ready", "action", "pose"]:
		var path: String = base + pose_name + "/" + pose_name + ".png"
		var tex: Texture2D = _resolve_texture_from_path(path)
		if tex != null:
			_sorcerer_poses[pose_name] = tex

# ==========================================
# 药师治愈之光动画
# ==========================================
func _load_pharmacist_poses() -> void:
	var base: String = "res://assets/characters/partner/pharmacist/"
	for pose_name in ["ready", "action", "pose"]:
		var path: String = base + pose_name + "/" + pose_name + ".png"
		var tex: Texture2D = _resolve_texture_from_path(path)
		if tex != null:
			_pharmacist_poses[pose_name] = tex

# ==========================================
# 盾卫天降援护动画
# ==========================================
func _load_shieldguard_poses() -> void:
	var base: String = "res://assets/characters/partner/shieldguard/"
	for pose_name in ["idle", "ready", "action"]:
		var path: String = base + pose_name + "/" + pose_name + ".png"
		var tex: Texture2D = _resolve_texture_from_path(path)
		if tex != null:
			_shieldguard_poses[pose_name] = tex

# ==========================================
# 猎人冲刺斩杀动画
# ==========================================
func _load_hunter_poses() -> void:
	var base: String = "res://assets/characters/partner/hunter/"
	for pose_name in ["idle", "ready", "action"]:
		var path: String = base + pose_name + "/" + pose_name + ".png"
		var tex: Texture2D = _resolve_texture_from_path(path)
		if tex != null:
			_hunter_poses[pose_name] = tex

func _play_hunter_dash_slash(assist_value: int = 0) -> void:
	if not _hunter_poses.has("idle") or not _hunter_poses.has("ready") or not _hunter_poses.has("action"):
		return
	var sprite := Sprite2D.new()
	sprite.texture = _hunter_poses["idle"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	## slash_pos 预补偿 _switch_partner_pose 的 +200 右跳，dash 目标设为 -200，经偏移后 sprite 正好停在 slash_pos
	var slash_pos_global: Vector2 = enemy_card.global_position + enemy_card.size / 2 + Vector2(-60, 0)
	var dash_target_global: Vector2 = slash_pos_global + Vector2(-200, 0)
	var start_global: Vector2 = dash_target_global + Vector2(-500, 0)
	var end_global: Vector2 = slash_pos_global + Vector2(500, 0)
	sprite.position = partner_anim_container.to_local(start_global)
	partner_anim_container.add_child(sprite)
	## 阶段1: 登场蓄力
	var enter_tween := _create_anim_tween().set_parallel()
	enter_tween.tween_property(sprite, "modulate:a", 1.0, 0.25)
	enter_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.25).set_trans(Tween.TRANS_BACK)
	await enter_tween.finished
	_switch_partner_pose(sprite, _hunter_poses["ready"])
	var dash_trail: CPUParticles2D = VFX.create_dash_trail(sprite, Vector2.ZERO)
	## 阶段2: 冲刺到预补偿位置
	var dash_tween := _create_anim_tween()
	dash_tween.tween_property(sprite, "position", partner_anim_container.to_local(dash_target_global), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await dash_tween.finished
	## 阶段3: 斩击命中（_switch_partner_pose 右跳 200px 后，sprite.global_position 才是真正的攻击点）
	_switch_partner_pose(sprite, _hunter_poses["action"])
	var actual_slash_pos: Vector2 = sprite.to_global(Vector2.ZERO)
	VFX.freeze_frame(0.1, 0.05)
	_screen_shake(12.0, 0.25)
	_flash_sprite(enemy_portrait)
	VFX.spawn_energy_burst(actual_slash_pos, Color(0.8, 0.3, 0.9))
	VFX.spawn_combo_ring(actual_slash_pos)
	_play_card_hurt(false, false)
	_spawn_sfx_text(actual_slash_pos + Vector2(0, -120), "斩！", Color("#BF4DE6"))
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(dash_trail): dash_trail.queue_free()
	## 阶段4: 穿出
	var exit := _create_anim_tween()
	exit.tween_property(sprite, "position", partner_anim_container.to_local(end_global), 0.35)
	exit.parallel().tween_property(sprite, "modulate:a", 0.0, 0.25)
	await exit.finished
	if is_instance_valid(sprite): sprite.queue_free()

func _load_swordsman_poses() -> void:
	var base: String = "res://assets/characters/partner/swordsman/"
	for pose_name in ["idle", "ready", "action"]:
		var path: String = base + pose_name + "/" + pose_name + ".png"
		var tex: Texture2D = _resolve_texture_from_path(path)
		if tex != null:
			_swordsman_poses[pose_name] = tex

func _play_swordsman_jump_slash(assist_value: int = 0) -> void:
	if not _swordsman_poses.has("ready") or not _swordsman_poses.has("action"):
		return
	
	var sprite := Sprite2D.new()
	sprite.texture = _swordsman_poses["ready"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	
	var enemy_center: Vector2 = enemy_card.global_position + enemy_card.size / 2
	## slash_global 预补偿 _switch_partner_pose 的 +200 右跳 + 剑尖偏移 127.5，合计约 330
	var spawn_global: Vector2 = enemy_center + Vector2(-500, -450)
	var slash_global: Vector2 = enemy_center + Vector2(-250, 0)
	
	var spawn_local: Vector2 = partner_anim_container.to_local(spawn_global)
	var slash_local: Vector2 = partner_anim_container.to_local(slash_global)
	
	sprite.position = spawn_local
	partner_anim_container.add_child(sprite)
	
	## 一条连续的右下弧线直接劈到敌人身上
	## x 减速接近 + y 加速下落 = 右下弧线
	var arc_tween := _create_anim_tween().set_parallel()
	arc_tween.tween_property(sprite, "modulate:a", 1.0, 0.15)
	arc_tween.tween_property(sprite, "position:x", slash_local.x, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc_tween.tween_property(sprite, "position:y", slash_local.y, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	arc_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	## ready 前半段稍慢，约 64% 处切换 action，后半段劈砍更快
	arc_tween.tween_callback(func(): _switch_partner_pose(sprite, _swordsman_poses["action"])).set_delay(0.35)
	await arc_tween.finished
	
	## 命中：震屏+冲击波+爆发+尘土+碎石+受击同步触发，无冻结帧
	_screen_shake(12.0, 0.25)
	## 剑士 action.png（1000x480）中剑尖相对纹理中心的偏移（剑尖约 755,465）
	const SWORDSMAN_ACTION_TIP_OFFSET_TEX := Vector2(255, 225)
	## 按当前 sprite.scale 换算为全局坐标，确保特效始终挂在剑尖而非角色中心
	var sword_tip_global: Vector2 = sprite.to_global(Vector2.ZERO) + SWORDSMAN_ACTION_TIP_OFFSET_TEX * sprite.scale
	VFX.spawn_shockwave(sword_tip_global)
	_flash_sprite(enemy_portrait)
	VFX.spawn_energy_burst(slash_global, Color(0.9, 0.95, 1.0))
	VFX.spawn_combo_ring(slash_global)
	## 底部尘土（放大版）
	var dust = preload("res://addons/vfx_library/effects/jump_dust.tscn").instantiate()
	sfx_layer.add_child(dust)
	dust.global_position = sword_tip_global
	dust.scale_amount_min = 8.0
	dust.scale_amount_max = 16.0
	dust.amount = 20
	dust.emitting = true
	get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(dust): dust.queue_free())
	## 碎石飞溅（放大版）
	var debris = preload("res://addons/vfx_library/effects/wood_debris.tscn").instantiate()
	sfx_layer.add_child(debris)
	debris.global_position = sword_tip_global
	debris.scale_amount_min = 6.0
	debris.scale_amount_max = 12.0
	debris.amount = 25
	debris.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(debris): debris.queue_free())
	_play_card_hurt(false, false)
	_spawn_sfx_text(slash_global + Vector2(0, -120), "斩！", Color("#4A90D9"))
	
	## 原地消失
	var fade_tween := _create_anim_tween()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	fade_tween.parallel().tween_property(sprite, "scale", Vector2(0.4, 0.4), 0.2)
	await fade_tween.finished
	if is_instance_valid(sprite): sprite.queue_free()

# ==========================================
# 斥候狙击动画
# ==========================================
func _play_scout_snipe(assist_value: int = 0) -> void:
	if not _scout_poses.has("ready") or not _scout_poses.has("action"):
		return
	
	var sprite := Sprite2D.new()
	sprite.texture = _scout_poses["idle"] if _scout_poses.has("idle") else _scout_poses["ready"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	## 素材本身朝右，正好面向敌人射击，不需要 flip_h
	
	var hero_center: Vector2 = hero_card.global_position + hero_card.size / 2
	var enemy_center: Vector2 = enemy_card.global_position + enemy_card.size / 2
	## 站到主角后边的身位（与主角同高，略偏上），正面朝右射击
	var spawn_global: Vector2 = hero_center + Vector2(-700, -10)
	var aim_global: Vector2 = hero_center + Vector2(-370, -10)
	var hit_global: Vector2 = enemy_center + Vector2(-40, 0)
	
	var spawn_local: Vector2 = partner_anim_container.to_local(spawn_global)
	var aim_local: Vector2 = partner_anim_container.to_local(aim_global)
	var hit_local: Vector2 = partner_anim_container.to_local(hit_global)
	
	sprite.position = spawn_local
	partner_anim_container.add_child(sprite)
	
	## 阶段1: 淡入登场并移动到主角后方的瞄准位
	var enter_tween := _create_anim_tween().set_parallel()
	enter_tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	enter_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tween.tween_property(sprite, "position", aim_local, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await enter_tween.finished
	
	## 阶段2: 切换 ready（拉弓瞄准），蓄力停顿
	_switch_partner_pose(sprite, _scout_poses["ready"])
	await get_tree().create_timer(0.25).timeout
	
	## 阶段3: 射箭 —— 箭矢从弓弦位置直线射向敌人
	## ready.png(600x480) 中弓弦约在 (360,250)，相对中心 (300,240) 偏移 (60,10)
	## 素材朝右，弓弦在中心右侧，x 取正
	const SCOUT_BOW_STRING_OFFSET_TEX := Vector2(60, 10)
	var arrow_start_global: Vector2 = sprite.to_global(SCOUT_BOW_STRING_OFFSET_TEX * sprite.scale)
	var arrow := ColorRect.new()
	arrow.size = Vector2(140, 5)
	arrow.color = Color(0.95, 0.98, 1.0)
	arrow.rotation = (hit_global - arrow_start_global).angle()
	var arrow_pivot_offset := Vector2(arrow.size.x * 0.5, arrow.size.y * 0.5)
	sfx_layer.add_child(arrow)
	arrow.global_position = arrow_start_global - arrow_pivot_offset
	
	## 同时切换 action（射箭后坐力姿势）
	_switch_partner_pose(sprite, _scout_poses["action"])
	
	var arrow_tween := _create_anim_tween()
	arrow_tween.tween_property(arrow, "global_position", hit_global - arrow_pivot_offset, 0.18).set_trans(Tween.TRANS_QUAD)
	await arrow_tween.finished
	
	## 命中：震屏 + 闪白 + 火花 + 受击
	_screen_shake(5.0, 0.15)
	_flash_sprite(enemy_portrait)
	var _sparks = preload("res://addons/vfx_library/effects/sparks.tscn").instantiate()
	sfx_layer.add_child(_sparks)
	_sparks.global_position = hit_global
	_sparks.scale_amount_min = 3.0
	_sparks.scale_amount_max = 6.0
	_sparks.amount = 16
	_sparks.emitting = true
	get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(_sparks): _sparks.queue_free())
	arrow.queue_free()
	
	_play_card_hurt(false, false)
	_spawn_sfx_text(hit_global + Vector2(0, -120), "嗖！", Color("#2ECC71"))
	
	## 停留让用户看清 action pose
	await get_tree().create_timer(0.25).timeout
	
	## 阶段4: 退场淡出
	var fade_tween := _create_anim_tween()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	fade_tween.parallel().tween_property(sprite, "scale", Vector2(0.4, 0.4), 0.2)
	await fade_tween.finished
	if is_instance_valid(sprite): sprite.queue_free()

# ==========================================
# 术士黑暗诅咒动画
# ==========================================
func _play_sorcerer_curse(assist_value: int = 0) -> void:
	if not _sorcerer_poses.has("ready") or not _sorcerer_poses.has("action") or not _sorcerer_poses.has("pose"):
		return
	
	var sprite := Sprite2D.new()
	sprite.texture = _sorcerer_poses["ready"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	
	var hero_center: Vector2 = hero_card.global_position + hero_card.size / 2
	var enemy_center: Vector2 = enemy_card.global_position + enemy_card.size / 2
	## 术士从主角身后飘到主角前方 200px 处施法（素材朝右，面朝敌人）
	var spawn_global: Vector2 = hero_center + Vector2(-300, -20)
	var cast_global: Vector2 = hero_center + Vector2(200, -20)
	
	var spawn_local: Vector2 = partner_anim_container.to_local(spawn_global)
	var cast_local: Vector2 = partner_anim_container.to_local(cast_global)
	
	sprite.position = spawn_local
	partner_anim_container.add_child(sprite)
	
	## 阶段1: 淡入登场
	var enter_tween := _create_anim_tween().set_parallel()
	enter_tween.tween_property(sprite, "modulate:a", 1.0, 0.3)
	enter_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tween.tween_property(sprite, "position", cast_local, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await enter_tween.finished
	
	## 阶段2: 召唤魔法阵（敌人脚下）
	var circle_global: Vector2 = enemy_center + Vector2(0, 80)
	var magic_circle := _spawn_magic_circle(circle_global)
	
	## 切换到 action pose（施法动作）
	_switch_partner_pose(sprite, _sorcerer_poses["action"])
	await get_tree().create_timer(0.2).timeout
	
	## 阶段3: 诅咒释放 + debuff 表现
	_screen_shake(6.0, 0.2)
	_apply_debuff_tint(enemy_portrait)
	
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
	
	## 伤害与受击
	_play_card_hurt(false, false)
	_spawn_sfx_text(enemy_center + Vector2(0, -120), "咒！", Color("#9B59B6"))
	
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
	var fade_tween := _create_anim_tween().set_parallel()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	if is_instance_valid(magic_circle):
		fade_tween.tween_property(magic_circle, "modulate:a", 0.0, 0.5)
	await fade_tween.finished
	if is_instance_valid(sprite):
		sprite.queue_free()
	if is_instance_valid(magic_circle):
		magic_circle.queue_free()


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
func _apply_debuff_tint(portrait: Sprite2D) -> void:
	var tween := create_tween()
	tween.tween_property(portrait, "modulate", Color(0.55, 0.25, 0.75), 0.1)
	tween.tween_interval(0.5)
	tween.tween_property(portrait, "modulate", Color.WHITE, 0.6)


## debuff 标签（头顶 ↓攻 图标，弹跳入场后上浮消失）
func _spawn_debuff_label(pos: Vector2, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font_cn)
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


## 治疗数字（绿色 +XXX）
func _spawn_heal_number(pos: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "+%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font_cn)
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
	label.z_index = 100
	
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE * 1.3, 0.15)
	tween.tween_property(label, "scale", Vector2.ONE, 0.1)
	tween.tween_property(label, "position:y", pos.y - 70, 0.6).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.tween_callback(func(): if is_instance_valid(label): label.queue_free())


# ==========================================
# 药师治愈之光动画
# ==========================================
func _play_pharmacist_heal(heal_amount: int = 0) -> void:
	if not _pharmacist_poses.has("ready") or not _pharmacist_poses.has("action") or not _pharmacist_poses.has("pose"):
		return
	
	var sprite := Sprite2D.new()
	sprite.texture = _pharmacist_poses["ready"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	
	var hero_center: Vector2 = hero_card.global_position + hero_card.size / 2
	var spawn_global: Vector2 = hero_center + Vector2(-400, -20)
	var cast_global: Vector2 = hero_center + Vector2(-150, -20)
	
	var spawn_local: Vector2 = partner_anim_container.to_local(spawn_global)
	var cast_local: Vector2 = partner_anim_container.to_local(cast_global)
	
	sprite.position = spawn_local
	partner_anim_container.add_child(sprite)
	
	## 阶段1: 淡入登场
	var enter_tween := _create_anim_tween().set_parallel()
	enter_tween.tween_property(sprite, "modulate:a", 1.0, 0.3)
	enter_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tween.tween_property(sprite, "position", cast_local, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await enter_tween.finished
	
	## 阶段2: 纸片翻转 action
	await _flip_pose_sprite(sprite, _pharmacist_poses["action"])
	await get_tree().create_timer(0.15).timeout
	
	## 阶段3: 治疗特效
	var heal = preload("res://addons/vfx_library/effects/heal_particles.tscn").instantiate()
	sfx_layer.add_child(heal)
	heal.global_position = cast_global + Vector2(80, -20)
	heal.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(heal): heal.queue_free())
	
	_apply_heal_tint(hero_portrait)
	_spawn_heal_label(hero_center + Vector2(0, -200))
	
	## 绿色回血数字（与事件系统同步，使用实际治疗量）
	var _show_heal: int = heal_amount if heal_amount > 0 else randi_range(100, 200)
	_spawn_heal_number(hero_center + Vector2(0, -140), _show_heal)
	_spawn_sfx_text(hero_center + Vector2(0, -260), "治愈！", Color("#2ECC71"))
	
	await get_tree().create_timer(0.3).timeout
	
	## 阶段4: 纸片翻转 pose 收势
	await _flip_pose_sprite(sprite, _pharmacist_poses["pose"])
	await get_tree().create_timer(0.4).timeout
	
	## 阶段5: 退场
	var fade_tween := _create_anim_tween()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	await fade_tween.finished
	if is_instance_valid(sprite):
		sprite.queue_free()


# ==========================================
# 盾卫天降援护动画
# ==========================================
func _play_shieldguard_defend(shield_value: int = 0) -> void:
	if not _shieldguard_poses.has("idle") or not _shieldguard_poses.has("ready") or not _shieldguard_poses.has("action"):
		return
	
	var sprite := Sprite2D.new()
	sprite.texture = _shieldguard_poses["idle"]
	sprite.scale = Vector2(0.3, 0.3)
	sprite.modulate.a = 0.0
	
	var hero_center: Vector2 = hero_card.global_position + hero_card.size / 2
	var spawn_global: Vector2 = hero_center + Vector2(200, -450)
	var land_global: Vector2 = hero_center + Vector2(200, 0)
	
	var spawn_local: Vector2 = partner_anim_container.to_local(spawn_global)
	var land_local: Vector2 = partner_anim_container.to_local(land_global)
	
	sprite.position = spawn_local
	partner_anim_container.add_child(sprite)
	
	## 阶段1: 天降（加速下落，idle = 空中下落姿势）
	var fall_tween := _create_anim_tween().set_parallel()
	fall_tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	fall_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fall_tween.tween_property(sprite, "position", land_local, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall_tween.finished
	
	## 落地震屏 + 尘土
	_screen_shake(10.0, 0.2)
	var dust = preload("res://addons/vfx_library/effects/jump_dust.tscn").instantiate()
	sfx_layer.add_child(dust)
	dust.global_position = land_global
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
	
	## 阶段4: 护盾展开
	_spawn_shield_aura(hero_center)
	_apply_shield_tint(hero_portrait)
	
	## 护盾吸收量显示（与事件系统同步）
	var _show_shield: int = shield_value if shield_value > 0 else randi_range(50, 100)
	var _shield_label_pos: Vector2 = hero_center + Vector2(0, -220)
	var shield_label := Label.new()
	shield_label.text = "+%d 护盾" % _show_shield
	shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shield_label.add_theme_font_override("font", _font_cn)
	shield_label.add_theme_font_size_override("font_size", 28)
	shield_label.add_theme_color_override("font_color", Color("#3498DB"))
	shield_label.add_theme_constant_override("outline_size", 2)
	shield_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sfx_layer.add_child(shield_label)
	shield_label.global_position = _shield_label_pos
	shield_label.scale = Vector2.ZERO
	shield_label.z_index = 100
	var sl_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sl_tween.tween_property(shield_label, "scale", Vector2.ONE, 0.15)
	sl_tween.tween_property(shield_label, "position:y", _shield_label_pos.y - 50, 0.5).set_trans(Tween.TRANS_QUAD)
	sl_tween.parallel().tween_property(shield_label, "modulate:a", 0.0, 0.5).set_delay(0.2)
	sl_tween.tween_callback(func(): if is_instance_valid(shield_label): shield_label.queue_free())
	
	_spawn_sfx_text(land_global + Vector2(0, -180), "盾反！", Color("#3498DB"))
	
	await get_tree().create_timer(0.4).timeout
	
	## 阶段5: 退场（直接从 action 淡出，无需翻回 ready）
	var fade_tween := _create_anim_tween()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	await fade_tween.finished
	if is_instance_valid(sprite):
		sprite.queue_free()


## 纸片翻转（单个 Sprite2D 版，无外层 Actor）
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


## 治疗绿色 tint
func _apply_heal_tint(portrait: Sprite2D) -> void:
	var tween := create_tween()
	tween.tween_property(portrait, "modulate", Color(0.5, 0.9, 0.5), 0.15)
	tween.tween_interval(0.4)
	tween.tween_property(portrait, "modulate", Color.WHITE, 0.5)


## 治疗标签（绿色十字弹跳入场）
func _spawn_heal_label(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "✚"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font_cn)
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


## 蓝色护盾光环（罩住主角）
func _spawn_shield_aura(pos: Vector2) -> void:
	var shield_ring := Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(24):
		var angle := deg_to_rad(i * 15)
		pts.push_back(Vector2(cos(angle), sin(angle)) * 70)
	shield_ring.polygon = pts
	shield_ring.color = Color(0.25, 0.55, 0.95, 0.15)
	shield_ring.position = pos
	sfx_layer.add_child(shield_ring)
	
	var inner := Polygon2D.new()
	var inner_pts: PackedVector2Array = PackedVector2Array()
	for i in range(12):
		var angle := deg_to_rad(i * 30)
		inner_pts.push_back(Vector2(cos(angle), sin(angle)) * 45)
	inner.polygon = inner_pts
	inner.color = Color(0.4, 0.7, 1.0, 0.3)
	inner.position = pos
	sfx_layer.add_child(inner)
	
	shield_ring.scale = Vector2.ZERO
	inner.scale = Vector2.ZERO
	var tween := create_tween().set_parallel()
	tween.tween_property(shield_ring, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(inner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	
	await get_tree().create_timer(0.6).timeout
	var fade := create_tween().set_parallel()
	fade.tween_property(shield_ring, "modulate:a", 0.0, 0.4)
	fade.tween_property(inner, "modulate:a", 0.0, 0.4)
	await fade.finished
	if is_instance_valid(shield_ring): shield_ring.queue_free()
	if is_instance_valid(inner): inner.queue_free()


## 护盾蓝色 tint
func _apply_shield_tint(portrait: Sprite2D) -> void:
	var tween := create_tween()
	tween.tween_property(portrait, "modulate", Color(0.6, 0.75, 0.95), 0.1)
	tween.tween_interval(0.5)
	tween.tween_property(portrait, "modulate", Color.WHITE, 0.5)


func _switch_partner_pose(sprite: Sprite2D, tex: Texture2D) -> void:
	if tex == null or sprite.texture == tex: return
	var old_size: Vector2 = sprite.texture.get_size()
	var new_size: Vector2 = tex.get_size()
	sprite.texture = tex
	sprite.position.x += (new_size.x - old_size.x) / 2.0
	sprite.position.y += (new_size.y - old_size.y) / 2.0


# ==========================================
# SFX 文字弹出
# ==========================================
func _spawn_sfx_text(pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font_cn)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))

	add_child(label)
	label.global_position = pos

	label.scale = Vector2.ZERO
	label.rotation = randf_range(-0.15, 0.15)

	var tween: Tween = _create_anim_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE * 1.3, 0.12)
	tween.tween_property(label, "scale", Vector2.ONE, 0.08)

	await get_tree().create_timer(0.15).timeout

	var fade: Tween = _create_anim_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(label, "position:y", pos.y - 80, 0.4)
	fade.parallel().tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.15)
	fade.tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)


# ==========================================
# Pose 加载与切换（Demo 迁移）
# ==========================================
func _load_hero_poses() -> void:
	var base: String = "res://assets/characters/hero/shinobi/"
	var idle_tex: Texture2D = _resolve_texture_from_path(base + "idle/shinobi_idle_01.png")
	var attack_tex: Texture2D = _resolve_texture_from_path(base + "attack/shinobi_attack_01.png")
	var hit_tex: Texture2D = _resolve_texture_from_path(base + "hit/shinobi_hit_01.png")
	## skill1: 疾风连击（多段），有 01-1 / 01-2 / 01-3
	var skill1_1_tex: Texture2D = _resolve_texture_from_path(base + "skill1/shinobi_skill1_01-1.png")
	var skill1_2_tex: Texture2D = _resolve_texture_from_path(base + "skill1/shinobi_skill1_01-2.png")
	var skill1_3_tex: Texture2D = _resolve_texture_from_path(base + "skill1/shinobi_skill1_01-3.png")
	## skill2: 必杀技，01=起手蓄力，02=突进释放
	var skill2_01_tex: Texture2D = _resolve_texture_from_path(base + "skill2/shinobi_skill2_01.png")
	var skill2_02_tex: Texture2D = _resolve_texture_from_path(base + "skill2/shinobi_skill2_02.png")
	var victory_tex: Texture2D = _resolve_texture_from_path(base + "victory/shinobi_victory_01.png")
	
	for key in ["idle", "attack", "hit", "skill", "skill1", "skill1-1", "skill1-2", "skill1-3", "skill2", "skill2-01", "skill2-02", "victory"]:
		_hero_poses[key] = idle_tex
	_hero_poses["attack"] = attack_tex
	_hero_poses["hit"] = hit_tex
	_hero_poses["skill"] = skill1_1_tex
	_hero_poses["skill1"] = skill1_1_tex
	_hero_poses["skill1-1"] = skill1_1_tex
	_hero_poses["skill1-2"] = skill1_2_tex
	_hero_poses["skill1-3"] = skill1_3_tex
	_hero_poses["skill2"] = skill2_02_tex
	_hero_poses["skill2-01"] = skill2_01_tex
	_hero_poses["skill2-02"] = skill2_02_tex
	_hero_poses["victory"] = victory_tex

func _load_enemy_poses() -> void:
	## 敌人复用主角素材，但敌方朝向 flip_h 已在 _ready() 中设置
	var base: String = "res://assets/characters/hero/shinobi/"
	var idle_tex: Texture2D = _resolve_texture_from_path(base + "idle/shinobi_idle_01.png")
	var attack_tex: Texture2D = _resolve_texture_from_path(base + "attack/shinobi_attack_01.png")
	var hit_tex: Texture2D = _resolve_texture_from_path(base + "hit/shinobi_hit_01.png")
	var skill1_1_tex: Texture2D = _resolve_texture_from_path(base + "skill1/shinobi_skill1_01-1.png")
	var skill1_2_tex: Texture2D = _resolve_texture_from_path(base + "skill1/shinobi_skill1_01-2.png")
	var skill1_3_tex: Texture2D = _resolve_texture_from_path(base + "skill1/shinobi_skill1_01-3.png")
	var skill2_01_tex: Texture2D = _resolve_texture_from_path(base + "skill2/shinobi_skill2_01.png")
	var skill2_02_tex: Texture2D = _resolve_texture_from_path(base + "skill2/shinobi_skill2_02.png")
	var victory_tex: Texture2D = _resolve_texture_from_path(base + "victory/shinobi_victory_01.png")
	
	for key in ["idle", "attack", "hit", "skill1", "skill1-1", "skill1-2", "skill1-3", "skill2", "skill2-01", "skill2-02", "victory"]:
		_enemy_poses[key] = idle_tex
	_enemy_poses["attack"] = attack_tex
	_enemy_poses["hit"] = hit_tex
	_enemy_poses["skill1"] = skill1_1_tex
	_enemy_poses["skill1-1"] = skill1_1_tex
	_enemy_poses["skill1-2"] = skill1_2_tex
	_enemy_poses["skill1-3"] = skill1_3_tex
	_enemy_poses["skill2"] = skill2_02_tex
	_enemy_poses["skill2-01"] = skill2_01_tex
	_enemy_poses["skill2-02"] = skill2_02_tex
	_enemy_poses["victory"] = victory_tex

func _set_pose(sprite: Sprite2D, tex: Texture2D) -> void:
	if tex != null:
		sprite.texture = tex
		sprite.centered = true

## 播放角色身上的逐帧特效（混合方案：主体翻页 + 局部逐帧）
func _play_portrait_effect(portrait: Sprite2D, effect_name: String) -> void:
	var effect: AnimatedSprite2D = hero_effect if portrait == hero_portrait else enemy_effect
	if effect == null:
		return
	if effect.sprite_frames == null:
		return
	if not effect.sprite_frames.has_animation(effect_name):
		return
	
	effect.visible = true
	effect.play(effect_name)
	
	## 动画结束后自动隐藏（CONNECT_ONE_SHOT 自动断开）
	var _on_finished := func():
		if is_instance_valid(effect):
			effect.visible = false
	
	## 安全连接：如果之前连接过，先断开避免重复
	var conns: Array = effect.animation_finished.get_connections()
	for c in conns:
		if c.callable.get_object() == effect:
			effect.animation_finished.disconnect(c.callable)
	effect.animation_finished.connect(_on_finished, CONNECT_ONE_SHOT)

func _tween_flip_to_pose(tween: Tween, portrait: Sprite2D, tex: Texture2D, duration: float = 0.18) -> void:
	if tex == null:
		return
	var sign_x: float = sign(portrait.scale.x)
	if sign_x == 0:
		sign_x = 1
	## 压缩（翻面）
	tween.tween_property(portrait, "scale:x", 0.06 * sign_x, duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	## 切换 Pose
	tween.tween_callback(func(): _set_pose(portrait, tex))
	## 展开（弹回）—— 始终恢复到基准比例，防止 tween 打断后 scale 永久异常
	tween.tween_property(portrait, "scale:x", BASE_CARD_SCALE * sign_x, duration * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _start_idle_breath(portrait: Sprite2D, speed: float) -> void:
	if portrait == hero_portrait:
		if _hero_breath_tween != null and _hero_breath_tween.is_valid():
			_hero_breath_tween.kill()
		_hero_breath_tween = create_tween().set_loops()
		_hero_breath_tween.tween_property(portrait, "position:y", portrait.position.y - 4, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_hero_breath_tween.tween_property(portrait, "position:y", portrait.position.y + 4, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		if _enemy_breath_tween != null and _enemy_breath_tween.is_valid():
			_enemy_breath_tween.kill()
		_enemy_breath_tween = create_tween().set_loops()
		_enemy_breath_tween.tween_property(portrait, "position:y", portrait.position.y - 4, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_enemy_breath_tween.tween_property(portrait, "position:y", portrait.position.y + 4, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_idle_breath(portrait: Sprite2D) -> void:
	if portrait == hero_portrait:
		if _hero_breath_tween != null and _hero_breath_tween.is_valid():
			_hero_breath_tween.kill()
		_hero_breath_tween = null
	else:
		if _enemy_breath_tween != null and _enemy_breath_tween.is_valid():
			_enemy_breath_tween.kill()
		_enemy_breath_tween = null

# ==========================================
# 新增：日志面板、速度控制、敌方CHAIN槽、关卡背景
# ==========================================

func _setup_log_panel() -> void:
	var log_panel: Control = $LogPanel
	
	## 1. 下方UI整体浅色背景板（全宽覆盖）
	_log_bg_panel = PanelContainer.new()
	_log_bg_panel.name = "LogBgPanel"
	_log_bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	log_panel.add_child(_log_bg_panel)
	log_panel.move_child(_log_bg_panel, 0)
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.22, 0.18, 0.14, 0.92)  ## 浅木色调
	bg_style.border_color = RunMainSettings.COLOR_WOOD_MEDIUM
	bg_style.border_width_top = 2
	bg_style.corner_radius_top_left = 12
	bg_style.corner_radius_top_right = 12
	bg_style.shadow_color = Color(0, 0, 0, 0.35)
	bg_style.shadow_size = 10
	bg_style.shadow_offset = Vector2(0, -4)
	_log_bg_panel.add_theme_stylebox_override("panel", bg_style)
	
	## 2. 战斗日志深色圆角背景（单独包裹日志）
	var log_inner_bg := PanelContainer.new()
	log_inner_bg.name = "LogInnerBg"
	log_inner_bg.position = Vector2(210, 55)
	log_inner_bg.size = Vector2(960, 200)
	log_panel.add_child(log_inner_bg)
	log_panel.move_child(log_inner_bg, 1)
	
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0.08, 0.06, 0.04, 0.95)  ## 深色调
	inner_style.border_color = RunMainSettings.COLOR_WOOD_DARK
	inner_style.border_width_left = 1
	inner_style.border_width_top = 1
	inner_style.border_width_right = 1
	inner_style.border_width_bottom = 1
	inner_style.corner_radius_top_left = 8
	inner_style.corner_radius_top_right = 8
	inner_style.corner_radius_bottom_left = 8
	inner_style.corner_radius_bottom_right = 8
	log_inner_bg.add_theme_stylebox_override("panel", inner_style)
	
	## 调整 BattleLog 位置使其在深色背景内
	battle_log.position = Vector2(225, 65)
	battle_log.size = Vector2(930, 180)
	
	## 日志标题样式
	log_head.position = Vector2(210, 16)
	log_head.size = Vector2(960, 32)
	log_head.add_theme_font_override("font", _font_cn)
	log_head.add_theme_font_size_override("font_size", 18)
	log_head.add_theme_color_override("font_color", COL_GOLD)
	log_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	## 日志内容样式
	battle_log.add_theme_font_override("normal_font", _font_cn)
	battle_log.add_theme_font_override("bold_font", _font_cn)
	battle_log.add_theme_font_size_override("normal_font_size", 13)
	battle_log.add_theme_color_override("default_color", COL_TEXT_MAIN)


func _setup_speed_controls() -> void:
	## 右侧添加 1x/2x 速度按钮 + 跳过按钮
	var log_panel: Control = $LogPanel
	var speed_container := HBoxContainer.new()
	speed_container.name = "SpeedContainer"
	speed_container.position = Vector2(1190, 20)
	speed_container.size = Vector2(160, 36)
	speed_container.add_theme_constant_override("separation", 6)
	log_panel.add_child(speed_container)
	
	for speed in [1.0, 2.0]:
		var btn := Button.new()
		btn.name = "Speed%.0fx" % speed
		btn.text = "%.0fx" % speed
		btn.toggle_mode = true
		btn.button_pressed = speed == 1.0
		btn.custom_minimum_size = Vector2(52, 36)
		btn.add_theme_font_override("font", _font_cn)
		btn.add_theme_font_size_override("font_size", 14)
		_apply_speed_button_style(btn, speed == 1.0)
		btn.pressed.connect(_on_speed_changed.bind(speed))
		speed_container.add_child(btn)
		_speed_buttons.append(btn)
	
	## 调整跳过按钮位置到速度按钮右侧
	skip_button.position = Vector2(1360, 20)
	skip_button.size = Vector2(80, 36)
	skip_button.text = "跳过"


func _apply_speed_button_style(button: Button, is_active: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.14, 0.10, 0.8) if not is_active else Color(0.35, 0.55, 0.85, 0.9)
	normal.border_color = RunMainSettings.COLOR_WOOD_DARK if not is_active else Color(0.45, 0.65, 0.95)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7) if not is_active else Color.WHITE)
	
	var hover := normal.duplicate()
	hover.bg_color = Color(0.25, 0.20, 0.15, 0.9) if not is_active else Color(0.45, 0.65, 0.95, 1.0)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.10, 0.08, 0.05, 0.95)
	button.add_theme_stylebox_override("pressed", pressed)


func _create_anim_tween() -> Tween:
	var tween := create_tween()
	tween.set_speed_scale(_animation_speed)
	return tween


func _on_speed_changed(speed: float) -> void:
	_animation_speed = speed
	AudioManager.play_ui("click")
	
	## 更新所有速度按钮状态
	for btn in _speed_buttons:
		var btn_speed := float(btn.text.replace("x", ""))
		_apply_speed_button_style(btn, btn_speed == speed)
	
	## 调整 TurnTimer 和 EventTween 速度
	turn_timer.wait_time = 1.0 / speed
	if _event_tween != null and _event_tween.is_valid():
		_event_tween.set_speed_scale(speed)
	print("[BattleAnimation] 动画速度切换到 %.0fx" % speed)


func _flash_log_border() -> void:
	## 对深色日志内背景板的边框进行蓝色闪烁
	var log_inner_bg: PanelContainer = $LogPanel.get_node_or_null("LogInnerBg")
	if log_inner_bg == null:
		return
	
	var flash_style := StyleBoxFlat.new()
	flash_style.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	flash_style.border_color = Color(0.4, 0.6, 1.0, 0.6)
	flash_style.border_width_left = 2
	flash_style.border_width_top = 2
	flash_style.border_width_right = 2
	flash_style.border_width_bottom = 2
	flash_style.corner_radius_top_left = 10
	flash_style.corner_radius_top_right = 10
	flash_style.corner_radius_bottom_left = 10
	flash_style.corner_radius_bottom_right = 10
	flash_style.shadow_color = Color(0.4, 0.6, 1.0, 0.2)
	flash_style.shadow_size = 10
	flash_style.shadow_offset = Vector2(0, 4)
	log_inner_bg.add_theme_stylebox_override("panel", flash_style)
	
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(log_inner_bg):
		return
	
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	normal_style.border_color = RunMainSettings.COLOR_WOOD_DARK
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	log_inner_bg.add_theme_stylebox_override("panel", normal_style)


func _setup_enemy_chain_layer() -> void:
	## PVP 敌方镜像CHAIN槽：CanvasLayer + 右侧VBoxContainer
	_enemy_chain_layer = CanvasLayer.new()
	_enemy_chain_layer.name = "EnemyChainLayer"
	_enemy_chain_layer.layer = 4
	add_child(_enemy_chain_layer)
	
	var chain_list := VBoxContainer.new()
	chain_list.name = "EnemyChainList"
	chain_list.offset_left = 1690
	chain_list.offset_top = 300
	chain_list.offset_right = 1890
	chain_list.offset_bottom = 500
	chain_list.add_theme_constant_override("separation", 8)
	_enemy_chain_layer.add_child(chain_list)
	
	## 创建3个镜像slot
	for i in range(3):
		var slot := HBoxContainer.new()
		slot.name = "EnemyChainSlot_%d" % i
		slot.visible = false
		
		## 镜像布局：计数 + chain + 名字 + 头像（翻转）
		var chain_label := Label.new()
		chain_label.name = "ChainLabel"
		chain_label.text = "0 x"
		chain_label.add_theme_font_override("font", _font_cn)
		chain_label.add_theme_color_override("font_color", COL_TEXT_SECOND)
		chain_label.add_theme_font_size_override("font_size", 12)
		chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot.add_child(chain_label)
		
		var name_label := Label.new()
		name_label.name = "NameLabel"
		name_label.text = "???"
		name_label.add_theme_font_override("font", _font_cn)
		name_label.add_theme_color_override("font_color", COL_GOLD)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot.add_child(name_label)
		
		var avatar := TextureRect.new()
		avatar.name = "Avatar"
		avatar.custom_minimum_size = Vector2(32, 32)
		avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.flip_h = true  ## 镜像翻转
		slot.add_child(avatar)
		
		chain_list.add_child(slot)
		_enemy_chain_slots.append(slot)


func _update_enemy_chain_slots(enemy_partners: Array) -> void:
	if enemy_partners.is_empty():
		if _enemy_chain_layer != null:
			_enemy_chain_layer.visible = false
		return
	
	if _enemy_chain_layer != null:
		_enemy_chain_layer.visible = true
	
	for i in range(_enemy_chain_slots.size()):
		var slot: Control = _enemy_chain_slots[i]
		if i < enemy_partners.size():
			var p = enemy_partners[i]
			var name_label: Label = slot.get_node("NameLabel")
			var chain_label: Label = slot.get_node("ChainLabel")
			var avatar: TextureRect = slot.get_node("Avatar")
			
			name_label.text = p.get("name", "???")
			chain_label.text = "%d x" % p.get("chain_count", 0)
			
			var icon_path: String = _get_partner_icon_path(p.get("name", ""))
			var tex: Texture2D = load(icon_path) as Texture2D if not icon_path.is_empty() else null
			if tex == null:
				var fallback_path: String = p.get("icon_path", "")
				tex = _resolve_texture_from_path(fallback_path)
			if avatar != null:
				avatar.texture = tex
			slot.visible = true
		else:
			slot.visible = false


func _setup_stage_background() -> void:
	## 使用 Sprite2D 作为背景，便于缩放控制
	_stage_bg = Sprite2D.new()
	_stage_bg.name = "StageBackground"
	_stage_bg.z_index = -1
	_stage_bg.centered = true
	_stage_bg.position = Vector2(960, 480)
	add_child(_stage_bg)
	move_child(_stage_bg, 0)


func _set_stage_background(floor_num: int) -> void:
	if _stage_bg == null:
		return
	
	var bg_path := _get_stage_bg_path(floor_num)
	if bg_path.is_empty():
		_stage_bg.visible = false
		return
	
	var tex: Texture2D = load(bg_path) as Texture2D
	if tex != null:
		_stage_bg.texture = tex
		_stage_bg.visible = true
		
		## 计算保持比例铺满屏幕的缩放，再额外放大1.6倍防止Camera zoom时露边
		var tex_size := tex.get_size()
		var screen_size := Vector2(1920, 1080)
		var cover_scale := maxf(screen_size.x / tex_size.x, screen_size.y / tex_size.y)
		_stage_bg.scale = Vector2.ONE * cover_scale * 1.6
		
		## 轻微暗化使前景角色更突出
		_stage_bg.modulate = Color(0.85, 0.85, 0.90, 1.0)
	else:
		_stage_bg.visible = false
		push_warning("[BattleAnimation] 关卡背景加载失败: %s" % bg_path)


func _get_stage_bg_path(floor_num: int) -> String:
	## 阶段划分：每10层一个阶段
	if floor_num <= 10:
		return "res://assets/backgrounds/pve/stages1/dead forest.png"
	elif floor_num <= 20:
		return "res://assets/backgrounds/pve/stages2/castle.png"
	else:
		return "res://assets/backgrounds/pve/stages3/terrace.png"


func _setup_fancy_hp_bars() -> void:
	## 双方血条统一使用 Style 02 经典JRPG分段式（策略感 + 木质装饰外框）
	_hero_hp_bar_fancy = FancyHealthBar.new()
	_hero_hp_bar_fancy.name = "HeroHpBarFancy"
	_hero_hp_bar_fancy.style_mode = 0  ## 分段式
	_hero_hp_bar_fancy.max_value = float(_hero_max_hp)
	_hero_hp_bar_fancy.value = float(_hero_hp)
	_hero_hp_bar_fancy.custom_minimum_size = hero_hp_bar.size
	_hero_hp_bar_fancy.position = hero_hp_bar.position
	_hero_hp_bar_fancy.size = hero_hp_bar.size
	hero_hp_bar.get_parent().add_child(_hero_hp_bar_fancy)
	hero_hp_bar.visible = false
	
	_enemy_hp_bar_fancy = FancyHealthBar.new()
	_enemy_hp_bar_fancy.name = "EnemyHpBarFancy"
	_enemy_hp_bar_fancy.style_mode = 0  ## 分段式
	_enemy_hp_bar_fancy.max_value = float(_enemy_max_hp)
	_enemy_hp_bar_fancy.value = float(_enemy_hp)
	_enemy_hp_bar_fancy.custom_minimum_size = enemy_hp_bar.size
	_enemy_hp_bar_fancy.position = enemy_hp_bar.position
	_enemy_hp_bar_fancy.size = enemy_hp_bar.size
	enemy_hp_bar.get_parent().add_child(_enemy_hp_bar_fancy)
	enemy_hp_bar.visible = false
