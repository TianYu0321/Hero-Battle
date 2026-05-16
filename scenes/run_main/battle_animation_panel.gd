class_name BattleAnimationPanel
extends Control

@onready var semi_transparent_bg: ColorRect = $SemiTransparentBg

@onready var hero_portrait: ColorRect = $HudContainer/HeroCard/Portrait
@onready var hero_name_label: Label = $HudContainer/HeroCard/NameLabel
@onready var hero_hp_bar: ProgressBar = $HudContainer/HeroCard/HpBar
@onready var hero_hp_meta: Label = $HudContainer/HeroCard/HpMeta

@onready var enemy_portrait: ColorRect = $HudContainer/EnemyCard/Portrait
@onready var enemy_name_label: Label = $HudContainer/EnemyCard/NameLabel
@onready var enemy_hp_bar: ProgressBar = $HudContainer/EnemyCard/HpBar
@onready var enemy_hp_meta: Label = $HudContainer/EnemyCard/HpMeta

@onready var vs_label: Label = $HudContainer/CenterBadge/VsLabel
@onready var round_label: Label = $HudContainer/CenterBadge/RoundLabel

@onready var hero_art: AnimatedSprite2D  = $StageArea/HeroArt
@onready var enemy_art: AnimatedSprite2D  = $StageArea/EnemyArt
@onready var stage_name_label: Label = $StageArea/StageName

@onready var log_head: Label = $LogPanel/LogHead
@onready var battle_log: RichTextLabel = $LogPanel/BattleLog
@onready var skip_button: Button = $LogPanel/SkipButton

@onready var turn_timer: Timer = $TurnTimer

var _playback_generation: int = 0
var _result_emitted: bool = false
var _is_playing: bool = false
var _current_round: int = 0

var _hero_hp: int = 0
var _hero_max_hp: int = 0
var _enemy_hp: int = 0
var _enemy_max_hp: int = 0

# Recorder回放模式
var _recorder: BattlePlaybackRecorder = null
var _events_by_turn: Dictionary = {}
var _turn_keys: Array = []
var _event_tween: Tween = null

# 摘要模拟模式
var _sim_total_rounds: int = 0
var _sim_hero_final_hp: int = 0
var _sim_enemy_final_hp: int = 0
var _sim_victory: bool = false

# 狂暴阶段
var _is_frenzy_active: bool = false

signal confirmed

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

func _ready() -> void:
	turn_timer.timeout.connect(_on_turn_timer_timeout)
	skip_button.pressed.connect(_on_skip)
	
	# 按钮回弹效果
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
	
	# 战斗场景氛围：灰烬粒子
	var _ash_parent := Node2D.new()
	_ash_parent.name = "AshParent"
	add_child(_ash_parent)
	EnvVFX.create_ash_particles(_ash_parent, Vector2(1280, 720))

func _apply_dark_theme() -> void:
	semi_transparent_bg.color = Color(0.05, 0.05, 0.08, 0.92)
	hero_portrait.color = COL_BLUE_DEEP
	enemy_portrait.color = COL_RED_DEEP

func _apply_theme_colors() -> void:
	var theme := get_theme()
	
	# 从 Theme 读取颜色，Theme 没定义就用代码常量
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
	
	# 应用到所有文字节点
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

# === 模式A：Recorder回放（PVP用） ===

func start_playback(recorder, hero_name: String, enemy_name: String,
					hero_max_hp: int, enemy_max_hp: int,
					_hero_partners: Array, _enemy_partners: Array,
					total_rounds: int = 0,
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
		_events_by_turn = _recorder.get_events_by_turn()
		_turn_keys = _events_by_turn.keys()
		for t in _turn_keys:
			_real_max_turn = maxi(_real_max_turn, int(t))
	
	# 使用传入的 total_rounds 作为真实回合数保底
	var effective_rounds: int = total_rounds
	if effective_rounds <= 0:
		effective_rounds = maxi(_real_max_turn, 3)
	
	_sim_total_rounds = effective_rounds
	
	_hero_max_hp = maxi(1, hero_max_hp)
	_hero_hp = _hero_max_hp
	_enemy_max_hp = maxi(1, enemy_max_hp)
	_enemy_hp = _enemy_max_hp
	_sim_hero_final_hp = _hero_hp
	_sim_enemy_final_hp = _enemy_hp
	_current_round = 0
	
	hero_name_label.text = hero_name
	enemy_name_label.text = enemy_name
	stage_name_label.text = "PVP 决斗场"
	
	hero_art.visible = true
	enemy_art.visible = true
	_load_sprite(hero_art, hero_sprite_path)
	_load_sprite(enemy_art, enemy_sprite_path)
	
	_update_hp_display()
	_apply_hp_bar_colors()
	
	battle_log.text = ""
	battle_log.append_text("[color=#E6C040]战斗开始！[/color]\n")
	
	print("[BattleAnimation] 回放开始: gen=%d, 真实%d回合, recorder有效=%s" % [
		_playback_generation, effective_rounds, _real_max_turn > 0
	])
	_clear_damage_numbers()
	_play_next_turn()

# === 模式B：摘要模拟（爬塔用） ===

func start_battle(battle_result: Dictionary) -> void:
	_playback_generation += 1
	_result_emitted = false
	_is_frenzy_active = false
	_is_playing = true
	visible = true
	
	_recorder = null
	_events_by_turn = {}
	_turn_keys = []
	
	_hero_max_hp = maxi(1, battle_result.get("hero_max_hp", 100))
	_hero_hp = clampi(battle_result.get("hero_hp", _hero_max_hp), 0, _hero_max_hp)
	_enemy_max_hp = maxi(1, battle_result.get("enemy_max_hp", 100))
	_enemy_hp = clampi(battle_result.get("enemy_hp", _enemy_max_hp), 0, _enemy_max_hp)
	
	_sim_total_rounds = maxi(1, battle_result.get("total_rounds", 1))
	_sim_hero_final_hp = _hero_hp
	_sim_enemy_final_hp = _enemy_hp
	_sim_victory = battle_result.get("victory", true)
	
	var hero_name: String = battle_result.get("hero_name", "英雄")
	var enemy_name: String = battle_result.get("enemy_name", "???")
	var stage_name: String = battle_result.get("stage_name", "深渊斗技场")
	
	hero_name_label.text = hero_name
	enemy_name_label.text = enemy_name
	stage_name_label.text = stage_name
	
	hero_art.visible = true
	enemy_art.visible = true
	_load_sprite(hero_art, battle_result.get("hero_sprite_path", ""))
	_load_sprite(enemy_art, battle_result.get("enemy_sprite_path", ""))
	
	_hero_hp = _hero_max_hp
	_enemy_hp = _enemy_max_hp
	_update_hp_display()
	_apply_hp_bar_colors()
	
	battle_log.text = ""
	battle_log.append_text("[color=#E6C040]战斗开始！[/color]\n")
	
	_current_round = 0
	print("[BattleAnimation] 模拟开始: gen=%d, %d回合" % [_playback_generation, _sim_total_rounds])
	_clear_damage_numbers()
	_play_next_turn()

# === 统一回合播放 ===

func _play_next_turn() -> void:
	if not _is_playing:
		return
	
	_current_round += 1
	
	# 结束条件
	var should_end: bool = _current_round > _sim_total_rounds
	if _hero_hp <= 0 or _enemy_hp <= 0:
		should_end = true
	
	if should_end:
		_show_result()
		return
	
	round_label.text = "回合 %d" % _current_round
	
	# 日志里加回合标题（暗金颜色，换行）
	battle_log.append_text("\n[color=#E6C040]━━ 回合 %d ━━[/color]\n" % _current_round)
	
	# 播放本回合事件（Tween 串行，每个间隔 0.5 秒）
	if _recorder != null and _events_by_turn.has(_current_round):
		var events: Array = _events_by_turn[_current_round]
		if events.size() > 0:
			if _event_tween != null and _event_tween.is_valid():
				_event_tween.kill()
			_event_tween = create_tween()
			for i in range(events.size()):
				_event_tween.tween_callback(_process_event.bind(events[i]))
				_event_tween.tween_callback(_update_hp_display)
				_event_tween.tween_interval(0.5)
			_event_tween.tween_callback(func(): turn_timer.start(1.0))
		else:
			turn_timer.start(1.0)
	else:
		_generate_simulated_turn()
		_update_hp_display()
		turn_timer.start(1.0)

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
			
			if is_miss:
				battle_log.append_text("[color=#73737A]  %s → %s 闪避[/color]\n" % [actor, target])
				AudioManager.play_sfx("miss")
			elif is_crit:
				battle_log.append_text("[color=#F28A3E]  %s → %s 暴击 %d！[/color]\n" % [actor, target, value])
				AudioManager.play_sfx("crit")
			else:
				battle_log.append_text("  %s → %s %d\n" % [actor, target, value])
				AudioManager.play_sfx("attack")
			
			# 攻击方播放攻击动画
			if actor == hero_name_label.text:
				_play_anim(hero_art, "attack")
			elif actor == enemy_name_label.text:
				_play_anim(enemy_art, "attack")
		
		"unit_damaged":
			var unit_id: String = data.get("unit_id", "")
			var hp: int = data.get("hp", 0)
			var is_crit: bool = data.get("is_crit", false)
			var damage: int = data.get("damage", 0)
			
			if unit_id == "hero" or unit_id.begins_with("hero"):
				_hero_hp = maxi(0, hp)
				_flash_sprite(true, is_crit)
				
				# 受击闪白 + 屏幕震动
				VFX.flash_white(hero_art, 0.1)
				VFX.screen_shake(8.0, 0.15)
				
				# 暴击额外特效
				if is_crit:
					VFX.critical_hit(hero_art.global_position)
					VFX.freeze_frame(0.08, 0.05)
				
				# 伤害数字
				VFX.spawn_damage_number(hero_art.global_position, damage, is_crit)
				
				# 受击动画
				_play_anim(hero_art, "hurt")
				
				AudioManager.play_sfx("hero_hit")
				
				if _hero_hp <= 0:
					battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % hero_name_label.text)
					VFX.kill_effect(hero_art.global_position)
					_play_anim(hero_art, "dead")
					_death_flash(true)
					AudioManager.play_sfx("defeat")
			else:
				_enemy_hp = maxi(0, hp)
				_flash_sprite(false, is_crit)
				
				# 受击闪白 + 屏幕震动
				VFX.flash_white(enemy_art, 0.1)
				VFX.screen_shake(8.0, 0.15)
				
				# 暴击额外特效
				if is_crit:
					VFX.critical_hit(enemy_art.global_position)
					VFX.freeze_frame(0.08, 0.05)
				
				# 伤害数字
				VFX.spawn_damage_number(enemy_art.global_position, damage, is_crit)
				
				# 受击动画
				_play_anim(enemy_art, "hurt")
				
				AudioManager.play_sfx("enemy_hit")
				
				if _enemy_hp <= 0:
					battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % enemy_name_label.text)
					VFX.kill_effect(enemy_art.global_position)
					_play_anim(enemy_art, "dead")
					_death_flash(false)
					AudioManager.play_sfx("defeat")
		
		"unit_died":
			var uname: String = data.get("name", "???")
			battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % uname)
			AudioManager.play_sfx("defeat")
			if uname == hero_name_label.text:
				_play_anim(hero_art, "dead")
			elif uname == enemy_name_label.text:
				_play_anim(enemy_art, "dead")
		
		"partner_assist":
			var pname: String = data.get("partner_name", "???")
			battle_log.append_text("[color=#BF4DE6]  %s 援助攻击！[/color]\n" % pname)
			AudioManager.play_sfx("partner_assist")
			_flash_partner_icon(pname)
		
		"chain_triggered":
			var chain_count: int = data.get("chain_count", 0)
			var pname: String = data.get("partner_name", "???")
			var dmg: int = data.get("damage", 0)
			battle_log.append_text("[color=#BF4DE6]  CHAIN x%d! %s %d[/color]\n" % [chain_count, pname, dmg])
			AudioManager.play_sfx("chain")
			_show_damage_number(dmg, false, false, true, chain_count)
		
		"ultimate_triggered":
			var log_text: String = data.get("log", "")
			battle_log.append_text("[color=#E6C040]  %s[/color]\n" % log_text)
			_screen_shake()
			AudioManager.play_sfx("ultimate")
		
		"frenzy_triggered":
			_is_frenzy_active = true
			var msg: String = data.get("message", "狂暴阶段触发！")
			battle_log.append_text("\n[color=red]★ %s ★[/color]\n" % msg)
			round_label.modulate = Color(1, 0.2, 0.2)
			_update_hp_display()
			AudioManager.play_sfx("frenzy_alert")
func _generate_simulated_turn() -> void:
	var progress: float = float(_current_round) / float(max(_sim_total_rounds, 3))
	
	# 英雄行动
	var hero_target_hp: int = int(lerpf(_enemy_max_hp, _sim_enemy_final_hp, progress))
	var hero_dmg: int = maxi(0, _enemy_hp - hero_target_hp)
	if hero_dmg > 0 and _enemy_hp > 0:
		var is_crit: bool = randf() < 0.15
		var is_miss: bool = randf() < 0.10
		if is_miss:
			battle_log.append_text("[color=#73737A]  %s → %s 闪避[/color]\n" % [hero_name_label.text, enemy_name_label.text])
			AudioManager.play_sfx("miss")
		elif is_crit:
			battle_log.append_text("[color=#F28A3E]  %s → %s 暴击 %d！[/color]\n" % [hero_name_label.text, enemy_name_label.text, hero_dmg * 2])
			_enemy_hp = maxi(0, _enemy_hp - hero_dmg * 2)
			AudioManager.play_sfx("crit")
		else:
			battle_log.append_text("  %s → %s %d\n" % [hero_name_label.text, enemy_name_label.text, hero_dmg])
			_enemy_hp = maxi(0, _enemy_hp - hero_dmg)
			AudioManager.play_sfx("attack")
		
			
			# 受击特效
			VFX.flash_white(enemy_art, 0.1)
			VFX.screen_shake(5.0, 0.1)
			VFX.spawn_damage_number(enemy_art.global_position, hero_dmg, is_crit)
			
			if is_crit:
				VFX.critical_hit(enemy_art.global_position)
				VFX.freeze_frame(0.08, 0.05)
			
			# 敌人受击动画
			_play_anim(enemy_art, "hurt")
			
			if _enemy_hp <= 0:
				battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % enemy_name_label.text)
				_play_anim(enemy_art, "dead")
				_death_flash(false)
				AudioManager.play_sfx("defeat")
	
	# 敌人行动
	if _current_round < maxi(_sim_total_rounds, 3) and _hero_hp > 0 and _enemy_hp > 0:
		var enemy_target_hp: int = int(lerpf(_hero_max_hp, _sim_hero_final_hp, progress))
		var enemy_dmg: int = maxi(0, _hero_hp - enemy_target_hp)
		if enemy_dmg > 0:
			var is_miss: bool = randf() < 0.10
			if is_miss:
				battle_log.append_text("[color=#73737A]  %s → %s 闪避[/color]\n" % [enemy_name_label.text, hero_name_label.text])
				AudioManager.play_sfx("miss")
			else:
				battle_log.append_text("  %s → %s %d\n" % [enemy_name_label.text, hero_name_label.text, enemy_dmg])
				_hero_hp = maxi(0, _hero_hp - enemy_dmg)
				AudioManager.play_sfx("attack")
			
				# 受击特效
				VFX.flash_white(hero_art, 0.1)
				VFX.screen_shake(5.0, 0.1)
				VFX.spawn_damage_number(hero_art.global_position, enemy_dmg, false)
				
				# 英雄受击动画
				_play_anim(hero_art, "hurt")
				
				if _hero_hp <= 0:
					battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % hero_name_label.text)
					_play_anim(hero_art, "dead")
					_death_flash(true)
					AudioManager.play_sfx("defeat")

func _apply_hp_bar_colors() -> void:
	hero_hp_bar.add_theme_color_override("theme_fg", COL_BLUE_MAIN)
	hero_hp_bar.add_theme_color_override("theme_bg", COL_BLUE_DEEP)
	enemy_hp_bar.add_theme_color_override("theme_fg", COL_RED_MAIN)
	enemy_hp_bar.add_theme_color_override("theme_bg", COL_RED_DEEP)

func _load_sprite(animated_sprite: AnimatedSprite2D, path: String) -> void:
	if path.is_empty():
		return
	var frames: Resource = load(path)
	if frames == null or not frames is SpriteFrames:
		push_warning("[BattleAnimation] 无法加载 SpriteFrames: %s" % path)
		return
	animated_sprite.sprite_frames = frames
	animated_sprite.autoplay = "idle"
	animated_sprite.play("idle")

func _play_anim(animated_sprite: AnimatedSprite2D, action: String) -> void:
	if animated_sprite.sprite_frames == null:
		return
	var anim_name: String = action
	match action:
		"attack":
			if animated_sprite.sprite_frames.has_animation("attack_1"):
				anim_name = "attack_1"
			elif not animated_sprite.sprite_frames.has_animation("attack"):
				return
		"hurt", "dead", "idle":
			if not animated_sprite.sprite_frames.has_animation(action):
				return
	animated_sprite.play(anim_name)

func _on_turn_timer_timeout() -> void:
	if not _is_playing:
		return
	_play_next_turn()

func finish_battle() -> void:
	if _is_playing and not _result_emitted:
		_show_result()

func _on_skip() -> void:
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
	
	if _turn_keys.size() == 0:
		_hero_hp = _sim_hero_final_hp
		_enemy_hp = _sim_enemy_final_hp
	
	_update_hp_display()
	
	if _hero_hp <= 0:
		battle_log.append_text("\n[color=#D93826]%s 被击败！[/color]" % hero_name_label.text)
	elif _enemy_hp <= 0:
		battle_log.append_text("\n[color=#5A8FD0]%s 被击败！[/color]" % enemy_name_label.text)
	
	battle_log.append_text("\n[color=#E6C040]=== 战斗结束 ===[/color]")
	print("[BattleAnimation] confirmed, gen=%d" % _playback_generation)
	confirmed.emit()

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
	_clear_damage_numbers()
	battle_log.text = ""
	_play_anim(hero_art, "idle")
	_play_anim(enemy_art, "idle")
	visible = false

func _update_hp_display() -> void:
	hero_hp_bar.value = float(_hero_hp) / maxi(1, _hero_max_hp) * 100
	enemy_hp_bar.value = float(_enemy_hp) / maxi(1, _enemy_max_hp) * 100
	var hero_current: int = maxi(0, _hero_hp)
	var enemy_current: int = maxi(0, _enemy_hp)
	hero_hp_meta.text = "%d / %d" % [hero_current, _hero_max_hp]
	enemy_hp_meta.text = "%d / %d" % [enemy_current, _enemy_max_hp]
	
	var hero_ratio: float = float(_hero_hp) / maxi(1, _hero_max_hp)
	
	# 低血量闪烁（英雄，低于30%）
	if hero_ratio < 0.3 and not _is_frenzy_active:
		var tween := create_tween().set_loops()
		tween.tween_property(hero_hp_bar, "modulate", Color(1, 0.3, 0.3), 0.3)
		tween.tween_property(hero_hp_bar, "modulate", Color(1, 1, 1), 0.3)
	elif not _is_frenzy_active:
		hero_hp_bar.modulate = Color(1, 1, 1)
	
	# 狂暴阶段血条变红提示
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
		label.modulate = Color(0.8, 0.3, 1.0)  # 紫色
	elif is_crit:
		label.text = str(damage)
		label.add_theme_font_size_override("font_size", 36)
		label.modulate = Color(1, 0.1, 0.1)  # 鲜红
	else:
		label.text = str(damage)
		label.add_theme_font_size_override("font_size", 26)
		label.modulate = Color(1, 0.9, 0.3)  # 金黄
	
	var label_settings := LabelSettings.new()
	label_settings.font_size = label.get_theme_font_size("font_size")
	label_settings.font_color = label.modulate
	label_settings.outline_size = 2
	label_settings.outline_color = Color(0, 0, 0, 0.8)
	label_settings.shadow_size = 2
	label_settings.shadow_color = Color(0, 0, 0, 0.5)
	label.label_settings = label_settings
	
	var target_sprite: Node2D = enemy_art if is_enemy_side else hero_art
	var sprite_pos: Vector2 = target_sprite.global_position
	label.global_position = Vector2(sprite_pos.x - 20, sprite_pos.y - 30)
	label.z_index = 100
	add_child(label)
	
	# 动画
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
	
	tween.tween_callback(label.queue_free)

func _clear_damage_numbers() -> void:
	for child in get_children():
		if child is Label and child.name.begins_with("DamageNum_"):
			child.queue_free()

func _flash_sprite(is_hero: bool, is_crit: bool) -> void:
	var sprite: AnimatedSprite2D  = hero_art if is_hero else enemy_art
	var flash_color: Color = COL_CRIT if is_crit else Color(1, 1, 1)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", flash_color, 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.3), 0.2)

func _death_flash(is_hero: bool) -> void:
	var sprite: AnimatedSprite2D  = hero_art if is_hero else enemy_art
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.8, 0.1, 0.1), 0.15)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.3), 0.3)

func _screen_shake() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + 3, 0.05)
	tween.tween_property(self, "position:x", position.x - 3, 0.05)
	tween.tween_property(self, "position:x", position.x, 0.05)

func _flash_partner_icon(_partner_name: String) -> void:
	pass
