class_name BattleAnimationPanel
extends Control

# ==========================================
# @onready 引用
# ==========================================
@onready var semi_transparent_bg: ColorRect = $SemiTransparentBg

## HUD 信息条（顶部）
@onready var hero_name_label: Label = $HudContainer/HeroCard/NameLabel
@onready var hero_hp_bar: ProgressBar = $HudContainer/HeroCard/HpBar
@onready var hero_hp_meta: Label = $HudContainer/HeroCard/HpMeta

@onready var enemy_name_label: Label = $HudContainer/EnemyCard/NameLabel
@onready var enemy_hp_bar: ProgressBar = $HudContainer/EnemyCard/HpBar
@onready var enemy_hp_meta: Label = $HudContainer/EnemyCard/HpMeta

@onready var vs_label: Label = $HudContainer/CenterBadge/VsLabel
@onready var round_label: Label = $HudContainer/CenterBadge/RoundLabel

## 战斗展示卡牌（StageArea）
@onready var hero_card: Control = $StageArea/HeroCard
@onready var hero_portrait: TextureRect = $StageArea/HeroCard/Portrait
@onready var hero_portrait_overlay: ColorRect = $StageArea/HeroCard/Portrait/PortraitOverlay
@onready var hero_glow: ColorRect = $StageArea/HeroCard/Portrait/GlowOverlay

@onready var enemy_card: Control = $StageArea/EnemyCard
@onready var enemy_portrait: TextureRect = $StageArea/EnemyCard/Portrait
@onready var enemy_portrait_overlay: ColorRect = $StageArea/EnemyCard/Portrait/PortraitOverlay
@onready var enemy_glow: ColorRect = $StageArea/EnemyCard/Portrait/GlowOverlay

@onready var stage_name_label: Label = $StageArea/StageName
@onready var partner_anim_container: Node2D = $StageArea/PartnerAnimContainer

## 伙伴链
@onready var partner_chain_list: VBoxContainer = $PartnerChainLayer/PartnerChainList

## 日志和控件
@onready var log_head: Label = $LogPanel/LogHead
@onready var battle_log: RichTextLabel = $LogPanel/BattleLog
@onready var skip_button: Button = $LogPanel/SkipButton
@onready var turn_timer: Timer = $TurnTimer

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

signal confirmed

func _notification(what: int) -> void:
	## CanvasLayer 不受父节点 visible 影响，需要手动同步
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if partner_chain_list != null:
			partner_chain_list.visible = self.visible

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
	
	## 初始化伙伴链
	_init_chain_slots()
	_load_hunter_poses()
	
	## 初始化 Overlay Shader
	var overlay_mat := ShaderMaterial.new()
	overlay_mat.shader = preload("res://shaders/portrait_overlay.gdshader")
	overlay_mat.set_shader_parameter("flash", 0.0)
	overlay_mat.set_shader_parameter("saturation", 1.0)
	hero_portrait_overlay.material = overlay_mat
	
	var enemy_overlay_mat := ShaderMaterial.new()
	enemy_overlay_mat.shader = preload("res://shaders/portrait_overlay.gdshader")
	enemy_overlay_mat.set_shader_parameter("flash", 0.0)
	enemy_overlay_mat.set_shader_parameter("saturation", 1.0)
	enemy_portrait_overlay.material = enemy_overlay_mat
	
	## 灰烬粒子
	var _ash_parent := Node2D.new()
	_ash_parent.name = "AshParent"
	add_child(_ash_parent)
	var vp_size := get_viewport().get_visible_rect().size
	EnvVFX.create_ash_particles(_ash_parent, vp_size)

func _apply_dark_theme() -> void:
	semi_transparent_bg.color = Color(0.05, 0.05, 0.08, 0.92)

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
	
	vs_label.add_theme_color_override("font_color", gold_color)
	round_label.add_theme_color_override("font_color", text_main_color)
	log_head.add_theme_color_override("font_color", gold_color)
	stage_name_label.add_theme_color_override("font_color", text_second_color)
	hero_name_label.add_theme_color_override("font_color", text_main_color)
	enemy_name_label.add_theme_color_override("font_color", text_main_color)
	hero_hp_meta.add_theme_color_override("font_color", text_main_color)
	enemy_hp_meta.add_theme_color_override("font_color", text_main_color)
	skip_button.add_theme_color_override("font_color", text_main_color)
	skip_button.add_theme_color_override("font_hover_color", gold_color)

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
					enemy_sprite_path: String = "") -> void:
	_playback_generation += 1
	_result_emitted = false
	_is_frenzy_active = false
	_is_playing = true
	visible = true
	
	_recorder = recorder
	_events_by_turn = {}
	_turn_keys = []
	var _real_max_turn: int = 0
	
	if _recorder != null and _recorder.has_method("get_events_by_turn"):
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
	_clear_damage_numbers()
	_play_next_turn()

func _reset_card_overlay(is_hero: bool) -> void:
	var overlay: ColorRect = hero_portrait_overlay if is_hero else enemy_portrait_overlay
	var glow: ColorRect = hero_glow if is_hero else enemy_glow
	var portrait: TextureRect = hero_portrait if is_hero else enemy_portrait
	overlay.color = Color(1, 1, 1, 0)
	if overlay.material != null:
		overlay.material.set_shader_parameter("flash", 0.0)
		overlay.material.set_shader_parameter("saturation", 1.0)
		overlay.material.set_shader_parameter("input_texture", portrait.texture)
	glow.color = Color(1, 1, 1, 0)

# ==========================================
# 回合播放
# ==========================================
func _play_next_turn() -> void:
	if not _is_playing:
		return
	
	_current_round += 1
	
	var should_end: bool = _current_round > _sim_total_rounds
	if _hero_hp <= 0 or _enemy_hp <= 0:
		should_end = true
	
	if should_end:
		_show_result()
		return
	
	round_label.text = "回合 %d" % _current_round
	battle_log.append_text("\n[color=#E6C040]━━ 回合 %d ━━[/color]\n" % _current_round)
	
	if _recorder != null and _events_by_turn.has(_current_round):
		var events: Array = _events_by_turn[_current_round]
		if events.size() > 0:
			if _event_tween != null and _event_tween.is_valid():
				_event_tween.kill()
			_event_tween = create_tween()
			for i in range(events.size()):
				_event_tween.tween_callback(_safe_process_event.bind(events[i]))
				_event_tween.tween_callback(_update_hp_display)
				_event_tween.tween_interval(0.5)
			_event_tween.tween_callback(func(): turn_timer.start(1.0))
		else:
			turn_timer.start(1.0)
	else:
		turn_timer.start(1.0)

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
		
		"action_executed":
			var actor: String = data.get("actor_name", "???")
			var target: String = data.get("target_name", "???")
			var summary: Dictionary = data.get("result_summary", {})
			var is_miss: bool = summary.get("is_miss", false)
			var is_crit: bool = summary.get("is_crit", false)
			var value: int = summary.get("value", 0)
			var action_type: String = data.get("action_type", "NORMAL")
			
			print("[BattleAnim] action_executed actor=%s action_type=%s" % [actor, action_type])
			
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
				_play_card_attack(true, anim_action)
			elif actor == enemy_name_label.text:
				_play_card_attack(false, anim_action)
			else:
				print("[BattleAnim] ⚠ actor 不匹配，不播放攻击动画")
		
		"unit_damaged":
			var unit_id: String = data.get("unit_id", "")
			var hp: int = data.get("hp", 0)
			var is_crit: bool = data.get("is_crit", false)
			var damage: int = data.get("damage", 0)
			
			if unit_id == "hero" or unit_id.begins_with("hero"):
				_hero_hp = maxi(0, hp)
				_flash_overlay(true, is_crit)
				
				VFX.flash_white(hero_portrait_overlay, 0.1)
				VFX.screen_shake(8.0, 0.15)
				
				if is_crit:
					VFX.critical_hit(hero_card.global_position + hero_card.size / 2)
					VFX.freeze_frame(0.08, 0.05)
				
				VFX.spawn_damage_number(hero_card.global_position + hero_card.size / 2, damage, is_crit)
				_play_card_hurt(true, is_crit)
				
				AudioManager.play_sfx("hero_hit")
				
				if _hero_hp <= 0:
					battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % hero_name_label.text)
					VFX.kill_effect(hero_card.global_position + hero_card.size / 2)
					_play_card_death(true)
					AudioManager.play_sfx("defeat")
			else:
				_enemy_hp = maxi(0, hp)
				_flash_overlay(false, is_crit)
				
				VFX.flash_white(enemy_portrait_overlay, 0.1)
				VFX.screen_shake(8.0, 0.15)
				
				if is_crit:
					VFX.critical_hit(enemy_card.global_position + enemy_card.size / 2)
					VFX.freeze_frame(0.08, 0.05)
				
				VFX.spawn_damage_number(enemy_card.global_position + enemy_card.size / 2, damage, is_crit)
				_play_card_hurt(false, is_crit)
				
				AudioManager.play_sfx("enemy_hit")
				
				if _enemy_hp <= 0:
					battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % enemy_name_label.text)
					VFX.kill_effect(enemy_card.global_position + enemy_card.size / 2)
					_play_card_death(false)
					AudioManager.play_sfx("defeat")
		
		"unit_died":
			var uname: String = data.get("name", "???")
			battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % uname)
			AudioManager.play_sfx("defeat")
			if uname == hero_name_label.text:
				_play_card_death(true)
			elif uname == enemy_name_label.text:
				_play_card_death(false)
		
		"partner_assist":
			var pname: String = data.get("partner_name", "???")
			battle_log.append_text("[color=#BF4DE6]  %s 援助攻击！[/color]\n" % pname)
			AudioManager.play_sfx("partner_assist")
			var slot: Control = _find_chain_slot_by_name(pname)
			if slot != null:
				_flash_chain_slot(slot)
			if pname == "猎人":
				_play_hunter_dash_slash()
			else:
				if slot != null:
					_fly_partner_avatar(slot, false)
		
		"chain_triggered":
			var chain_count: int = data.get("chain_count", 0)
			var pname: String = data.get("partner_name", "???")
			var dmg: int = data.get("damage", 0)
			battle_log.append_text("[color=#BF4DE6]  CHAIN x%d! %s %d[/color]\n" % [chain_count, pname, dmg])
			AudioManager.play_sfx("chain")
			_show_damage_number(dmg, false, true, true, chain_count)
			
			## 触发伙伴动作（1-4级轻量飞出，5级完整动画）
			var pconfig: Dictionary = ConfigManager.get_partner_config_by_name(pname)
			var plevel: int = pconfig.get("level", 1)
			var ppath: String = pconfig.get("sprite_frames_path", "")
			if plevel >= 5 and not ppath.is_empty():
				_play_partner_action(pname, plevel, "attack", ppath, "attack")
			else:
				var slot: Control = _find_chain_slot_by_name(pname)
				if slot != null:
					_flash_chain_slot(slot)
					_fly_partner_avatar(slot, false)
		
		"ultimate_triggered":
			var log_text: String = data.get("log", "")
			battle_log.append_text("[color=#E6C040]  %s[/color]\n" % log_text)
			_screen_shake()
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

# ==========================================
# 卡牌动画
# ==========================================
func _play_card_attack(is_hero: bool, action_type: String) -> void:
	var card: Control = hero_card if is_hero else enemy_card
	var orig_pos: Vector2 = _hero_card_orig_pos if is_hero else _enemy_card_orig_pos
	var dir: float = 1.0 if is_hero else -1.0
	
	## 停止该卡牌的旧攻击/受击 tween，避免冲突
	if is_hero:
		if _hero_attack_tween != null and _hero_attack_tween.is_valid():
			_hero_attack_tween.kill()
		if _hero_hurt_tween != null and _hero_hurt_tween.is_valid():
			_hero_hurt_tween.kill()
	else:
		if _enemy_attack_tween != null and _enemy_attack_tween.is_valid():
			_enemy_attack_tween.kill()
		if _enemy_hurt_tween != null and _enemy_hurt_tween.is_valid():
			_enemy_hurt_tween.kill()
	
	match action_type:
		"ultimate":
			var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if is_hero: _hero_attack_tween = tween
			else: _enemy_attack_tween = tween
			tween.tween_property(card, "scale", Vector2(1.15, 1.15), 0.2)
			tween.tween_property(card, "scale", Vector2.ONE, 0.3)
			tween.parallel().tween_property(card, "position:x", orig_pos.x + dir * 30, 0.15)
			tween.tween_property(card, "position:x", orig_pos.x, 0.2)
			_spawn_slash_trail(card.global_position + card.size / 2,
							   (enemy_card if is_hero else hero_card).global_position + (enemy_card if is_hero else hero_card).size / 2,
							   is_hero)
		"skill":
			_card_glow_pulse(card, Color("#E6C040"), 0.3)
			var tween := create_tween()
			if is_hero: _hero_attack_tween = tween
			else: _enemy_attack_tween = tween
			tween.tween_property(card, "position:x", orig_pos.x + dir * 15, 0.1)
			tween.tween_property(card, "position:x", orig_pos.x, 0.15)
			_spawn_slash_trail(card.global_position + card.size / 2,
							   (enemy_card if is_hero else hero_card).global_position + (enemy_card if is_hero else hero_card).size / 2,
							   is_hero)
		_:
			var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if is_hero: _hero_attack_tween = tween
			else: _enemy_attack_tween = tween
			tween.tween_property(card, "position:x", orig_pos.x + dir * 20, 0.08)
			tween.tween_property(card, "position:x", orig_pos.x, 0.12)
			_spawn_slash_trail(card.global_position + card.size / 2,
							   (enemy_card if is_hero else hero_card).global_position + (enemy_card if is_hero else hero_card).size / 2,
							   is_hero)

func _play_card_hurt(is_hero: bool, is_crit: bool) -> void:
	var card: Control = hero_card if is_hero else enemy_card
	var orig_pos: Vector2 = _hero_card_orig_pos if is_hero else _enemy_card_orig_pos
	var shake: float = 8.0 if is_crit else 4.0
	var back_dir: float = -1.0 if is_hero else 1.0
	
	## 停止旧的 hurt tween，避免冲突
	if is_hero:
		if _hero_hurt_tween != null and _hero_hurt_tween.is_valid():
			_hero_hurt_tween.kill()
	else:
		if _enemy_hurt_tween != null and _enemy_hurt_tween.is_valid():
			_enemy_hurt_tween.kill()
	
	var tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if is_hero: _hero_hurt_tween = tween
	else: _enemy_hurt_tween = tween
	tween.tween_property(card, "position:x", orig_pos.x + back_dir * shake, 0.06)
	tween.parallel().tween_property(card, "rotation", back_dir * 0.05, 0.06)
	tween.tween_property(card, "position:x", orig_pos.x, 0.1)
	tween.parallel().tween_property(card, "rotation", 0.0, 0.1)

func _play_card_death(is_hero: bool) -> void:
	var card: Control = hero_card if is_hero else enemy_card
	var overlay: ColorRect = hero_portrait_overlay if is_hero else enemy_portrait_overlay
	
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
	else:
		if _enemy_attack_tween != null and _enemy_attack_tween.is_valid():
			_enemy_attack_tween.kill()
		if _enemy_hurt_tween != null and _enemy_hurt_tween.is_valid():
			_enemy_hurt_tween.kill()
		if _enemy_death_tween != null and _enemy_death_tween.is_valid():
			_enemy_death_tween.kill()
	
	var gray_tween := create_tween()
	if is_hero: _hero_death_tween = gray_tween
	else: _enemy_death_tween = gray_tween
	gray_tween.tween_method(func(t: float):
		if is_instance_valid(overlay) and overlay.material != null:
			overlay.material.set_shader_parameter("saturation", 1.0 - t)
	, 0.0, 1.0, 0.5)
	
	var fade_tween := create_tween()
	fade_tween.tween_property(card, "modulate:a", 0.0, 1.0).set_delay(0.3)
	fade_tween.tween_callback(func():
		if is_instance_valid(card):
			card.visible = false
			card.modulate.a = 1.0
		if is_instance_valid(overlay) and overlay.material != null:
			overlay.material.set_shader_parameter("saturation", 1.0)
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
	var tween := create_tween()
	glow.set_meta("glow_pulse_tween", tween)
	tween.tween_property(glow, "color:a", 0.6, duration * 0.3)
	tween.tween_property(glow, "color:a", 0.0, duration * 0.7)

func _flash_overlay(is_hero: bool, is_crit: bool) -> void:
	var overlay: ColorRect = hero_portrait_overlay if is_hero else enemy_portrait_overlay
	if not is_instance_valid(overlay):
		return
	
	## 停止旧的 flash tween
	if overlay.has_meta("flash_tween"):
		var old: Tween = overlay.get_meta("flash_tween")
		if old != null and old.is_valid():
			old.kill()
		overlay.remove_meta("flash_tween")
	
	var flash_color: Color = COL_CRIT if is_crit else Color(1, 1, 1)
	overlay.color = flash_color
	var tween := create_tween()
	overlay.set_meta("flash_tween", tween)
	tween.tween_property(overlay, "color:a", 0.8, 0.05)
	tween.tween_property(overlay, "color:a", 0.0, 0.15)

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
	
	var tween := create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.2).set_delay(0.05)
	tween.tween_callback(func():
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
	
	var tween := create_tween()
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
	label.add_theme_font_size_override("font_size", 48)
	label.modulate = Color("#E6C040")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	
	var min_size: Vector2 = label.get_combined_minimum_size()
	label.position = Vector2(size.x / 2 - min_size.x / 2, size.y * 0.3)
	label.scale = Vector2(1.5, 1.5)
	
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 60, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)

func _start_frenzy_glow() -> void:
	_stop_frenzy_glow()  ## 先停止旧的狂暴 tween，防止叠加
	var tween := create_tween().set_loops()
	tween.tween_property(hero_glow, "color", Color(1, 0.1, 0.1, 0.5), 0.4)
	tween.tween_property(hero_glow, "color", Color(1, 0.1, 0.1, 0.1), 0.4)
	tween.parallel().tween_property(enemy_glow, "color", Color(1, 0.1, 0.1, 0.5), 0.4)
	tween.parallel().tween_property(enemy_glow, "color", Color(1, 0.1, 0.1, 0.1), 0.4)
	set_meta("frenzy_tween", tween)

func _stop_frenzy_glow() -> void:
	if has_meta("frenzy_tween"):
		var t: Tween = get_meta("frenzy_tween")
		if t != null and t.is_valid():
			t.kill()
		remove_meta("frenzy_tween")
	hero_glow.color = Color(1, 1, 1, 0)
	enemy_glow.color = Color(1, 1, 1, 0)

# ==========================================
# 伙伴链
# ==========================================
func _init_chain_slots() -> void:
	_chain_slots.clear()
	for child in partner_chain_list.get_children():
		if child is HBoxContainer:
			_chain_slots.append(child)
			child.visible = false

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
			
			var path: String = p.get("icon_path", "")
			var tex: Texture2D = _resolve_texture_from_path(path)
			if tex == null or path.is_empty():
				var fallback_name: String = p.get("name", "")
				if not fallback_name.is_empty():
					var fallback_path: String = "res://assets/characters/partner/" + fallback_name + "/partner_" + fallback_name + "_lv1.png"
					tex = _resolve_texture_from_path(fallback_path)
			avatar.texture = tex
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
	var tween := create_tween()
	tween.tween_property(slot, "modulate", Color(1.3, 1.3, 1.0), 0.15)
	tween.tween_property(slot, "modulate", orig, 0.3)

func _fly_partner_avatar(slot: Control, _is_level5: bool) -> void:
	var orig_avatar: TextureRect = slot.get_node("Avatar") if slot.has_node("Avatar") else null
	if orig_avatar == null or orig_avatar.texture == null:
		return
	
	var flying := TextureRect.new()
	flying.texture = orig_avatar.texture
	flying.custom_minimum_size = Vector2(48, 48)
	flying.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	flying.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(flying)
	
	var start: Vector2 = slot.global_position
	var target: Vector2 = enemy_card.global_position + enemy_card.size / 2 - flying.size / 2
	flying.global_position = start
	
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flying, "global_position", target, 0.3)
	tween.tween_callback(func():
		_flash_overlay(false, false)
		_play_card_hurt(false, false)
	)
	tween.tween_property(flying, "global_position", start, 0.25)
	tween.tween_property(flying, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		if is_instance_valid(flying):
			flying.queue_free()
	)

# ==========================================
# 5级伙伴逐帧动画
# ==========================================
func _play_partner_action(partner_name: String, partner_level: int, action: String,
						  partner_sprite_path: String, partner_anim_name: String) -> void:
	if partner_level < 5:
		var slot: Control = _find_chain_slot_by_name(partner_name)
		if slot != null:
			_fly_partner_avatar(slot, false)
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
	var attack_pos_global: Vector2 = enemy_card.global_position + Vector2(-160, 0)
	var spawn_pos_local: Vector2 = partner_anim_container.to_local(spawn_pos_global)
	var attack_pos_local: Vector2 = partner_anim_container.to_local(attack_pos_global)
	
	sprite.position = spawn_pos_local
	sprite.scale = Vector2(2.0, 2.0)
	sprite.modulate.a = 0.0
	
	partner_anim_container.add_child(sprite)
	sprite.play(partner_anim_name)
	
	var enter_tween := create_tween()
	enter_tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	enter_tween.tween_property(sprite, "position", attack_pos_local, 0.3)
	
	## 动画结束后飞回并删除
	var _anim_finished := func():
		if not is_instance_valid(sprite):
			return
		var exit_tween := create_tween()
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
	return hero_card.global_position + Vector2(-200, -40)

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

func _load_card_portrait(portrait: TextureRect, path: String, is_hero: bool) -> void:
	var texture: Texture2D = _resolve_texture_from_path(path)
	if texture == null:
		if not path.is_empty():
			push_warning("[BattleAnimation] 无法加载头像: %s" % path)
		portrait.texture = _create_placeholder_texture(is_hero)
	else:
		portrait.texture = texture
	
	## 同步更新 overlay shader 的 input_texture
	var overlay: ColorRect = hero_portrait_overlay if portrait == hero_portrait else enemy_portrait_overlay
	if overlay.material != null:
		overlay.material.set_shader_parameter("input_texture", portrait.texture)

# ==========================================
# HP 条与辅助
# ==========================================
func _apply_hp_bar_colors() -> void:
	hero_hp_bar.add_theme_color_override("theme_fg", COL_BLUE_MAIN)
	hero_hp_bar.add_theme_color_override("theme_bg", COL_BLUE_DEEP)
	enemy_hp_bar.add_theme_color_override("theme_fg", COL_RED_MAIN)
	enemy_hp_bar.add_theme_color_override("theme_bg", COL_RED_DEEP)

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
	_show_result()

func _show_result() -> void:
	_is_playing = false
	turn_timer.stop()
	if _result_emitted:
		return
	_result_emitted = true
	
	_update_hp_display()
	
	if _hero_hp <= 0:
		battle_log.append_text("\n[color=#D93826]%s 被击败！[/color]" % hero_name_label.text)
	elif _enemy_hp <= 0:
		battle_log.append_text("\n[color=#5A8FD0]%s 被击败！[/color]" % enemy_name_label.text)
	
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
	_stop_frenzy_glow()
	_clear_damage_numbers()
	battle_log.text = ""
	
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
	
	## 清理5级伙伴动画节点
	for child in partner_anim_container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	
	visible = false

func _update_hp_display() -> void:
	hero_hp_bar.value = float(_hero_hp) / maxi(1, _hero_max_hp) * 100
	enemy_hp_bar.value = float(_enemy_hp) / maxi(1, _enemy_max_hp) * 100
	var hero_current: int = maxi(0, _hero_hp)
	var enemy_current: int = maxi(0, _enemy_hp)
	hero_hp_meta.text = "%d / %d" % [hero_current, _hero_max_hp]
	enemy_hp_meta.text = "%d / %d" % [enemy_current, _enemy_max_hp]
	
	var hero_ratio: float = float(_hero_hp) / maxi(1, _hero_max_hp)
	
	## 低血量闪烁：避免重复创建无限循环 Tween
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
		hero_hp_bar.modulate = Color(1, 0.2, 0.2)
		enemy_hp_bar.modulate = Color(1, 0.2, 0.2)
	else:
		enemy_hp_bar.modulate = Color(1, 1, 1)

func _show_damage_number(damage: int, is_crit: bool, is_enemy_side: bool, is_chain: bool = false, chain_count: int = 0) -> void:
	var label := Label.new()
	label.name = "DamageNum_%d" % randi()
	
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
	
	var tween := create_tween()
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

func _screen_shake() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + 3, 0.05)
	tween.tween_property(self, "position:x", position.x - 3, 0.05)
	tween.tween_property(self, "position:x", position.x, 0.05)

func _flash_partner_icon(_partner_name: String) -> void:
	pass


# ==========================================
# 猎人冲刺斩杀动画
# ==========================================
func _load_hunter_poses() -> void:
	var base: String = "res://assets/characters/partner/hunter/"
	for pose_name in ["idle", "ready", "action"]:
		var path: String = base + pose_name + ".png"
		var tex: Texture2D = _resolve_texture_from_path(path)
		if tex != null:
			_hunter_poses[pose_name] = tex

func _play_hunter_dash_slash() -> void:
	if not _hunter_poses.has("idle") or not _hunter_poses.has("ready") or not _hunter_poses.has("action"):
		return
	var sprite := Sprite2D.new()
	sprite.texture = _hunter_poses["idle"]
	sprite.scale = Vector2(0.6, 0.6)
	sprite.modulate.a = 0.0
	var slash_pos_global: Vector2 = enemy_card.global_position + enemy_card.size / 2 + Vector2(-150, 0)
	var start_global: Vector2 = slash_pos_global + Vector2(-700, 0)
	var end_global: Vector2 = slash_pos_global + Vector2(600, 0)
	sprite.position = partner_anim_container.to_local(start_global)
	partner_anim_container.add_child(sprite)
	## 阶段1: 登场蓄力
	var enter_tween := create_tween().set_parallel()
	enter_tween.tween_property(sprite, "modulate:a", 1.0, 0.25)
	enter_tween.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.25).set_trans(Tween.TRANS_BACK)
	await enter_tween.finished
	_switch_partner_pose(sprite, _hunter_poses["ready"])
	var dash_trail: CPUParticles2D = VFX.create_dash_trail(sprite, Vector2.ZERO)
	## 阶段2: 冲刺
	var dash_tween := create_tween()
	dash_tween.tween_property(sprite, "position", partner_anim_container.to_local(slash_pos_global), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await dash_tween.finished
	## 阶段3: 斩击命中
	_switch_partner_pose(sprite, _hunter_poses["action"])
	VFX.freeze_frame(0.1, 0.05)
	VFX.screen_shake(12.0, 0.25)
	VFX.flash_white(enemy_portrait_overlay, 0.1)
	VFX.spawn_energy_burst(slash_pos_global, Color(0.8, 0.3, 0.9))
	VFX.spawn_combo_ring(slash_pos_global)
	_play_card_hurt(false, false)
	_spawn_sfx_text(slash_pos_global + Vector2(0, -120), "斩！", Color("#BF4DE6"))
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(dash_trail): dash_trail.queue_free()
	## 阶段4: 穿出
	var exit := create_tween()
	exit.tween_property(sprite, "position", partner_anim_container.to_local(end_global), 0.35)
	exit.parallel().tween_property(sprite, "modulate:a", 0.0, 0.25)
	await exit.finished
	if is_instance_valid(sprite): sprite.queue_free()

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
