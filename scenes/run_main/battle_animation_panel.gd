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

@onready var hero_art: ColorRect = $StageArea/HeroArt
@onready var enemy_art: ColorRect = $StageArea/EnemyArt
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

# 摘要模拟模式
var _sim_total_rounds: int = 0
var _sim_hero_final_hp: int = 0
var _sim_enemy_final_hp: int = 0
var _sim_victory: bool = false

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
	visible = false
	battle_log.scroll_following = true
	_apply_dark_theme()

func _apply_dark_theme() -> void:
	semi_transparent_bg.color = Color(0.05, 0.05, 0.08, 0.92)
	hero_portrait.color = COL_BLUE_DEEP
	enemy_portrait.color = COL_RED_DEEP
	vs_label.add_theme_color_override("font_color", COL_GOLD)
	round_label.add_theme_color_override("font_color", COL_TEXT_MAIN)
	log_head.add_theme_color_override("font_color", COL_GOLD)
	stage_name_label.add_theme_color_override("font_color", COL_TEXT_SECOND)
	skip_button.add_theme_color_override("font_color", COL_TEXT_MAIN)
	skip_button.add_theme_color_override("font_hover_color", COL_GOLD)

# === 模式A：Recorder回放（PVP用） ===

func start_playback(recorder, hero_name: String, enemy_name: String,
					hero_max_hp: int, enemy_max_hp: int,
					_hero_partners: Array, _enemy_partners: Array,
					total_rounds: int = 0) -> void:
	_playback_generation += 1
	_result_emitted = false
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
	_current_round = 0
	
	hero_name_label.text = hero_name
	enemy_name_label.text = enemy_name
	stage_name_label.text = "PVP 决斗场"
	
	hero_art.visible = true
	enemy_art.visible = true
	
	_update_hp_display()
	_apply_hp_bar_colors()
	
	battle_log.text = ""
	battle_log.append_text("[color=#E6C040]战斗开始！[/color]\n")
	
	print("[BattleAnimation] 回放开始: gen=%d, 真实%d回合, recorder有效=%s" % [
		_playback_generation, effective_rounds, _real_max_turn > 0
	])
	_play_next_turn()

# === 模式B：摘要模拟（爬塔用） ===

func start_battle(battle_result: Dictionary) -> void:
	_playback_generation += 1
	_result_emitted = false
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
	
	_hero_hp = _hero_max_hp
	_enemy_hp = _enemy_max_hp
	_update_hp_display()
	_apply_hp_bar_colors()
	
	battle_log.text = ""
	battle_log.append_text("[color=#E6C040]战斗开始！[/color]\n")
	
	_current_round = 0
	print("[BattleAnimation] 模拟开始: gen=%d, %d回合" % [_playback_generation, _sim_total_rounds])
	_play_next_turn()

# === 统一回合播放 ===

func _play_next_turn() -> void:
	if not _is_playing:
		return
	
	_current_round += 1
	
	# 结束条件
	var should_end: bool = _current_round > _sim_total_rounds
	if (_hero_hp <= 0 or _enemy_hp <= 0) and _current_round > 3:
		should_end = true
	
	if should_end:
		_show_result()
		return
	
	round_label.text = "回合 %d" % _current_round
	
	# 日志里加回合标题（暗金颜色，换行）
	battle_log.append_text("\n[color=#E6C040]━━ 回合 %d ━━[/color]\n" % _current_round)
	
	# 播放本回合事件
	if _recorder != null and _events_by_turn.has(_current_round):
		var events: Array = _events_by_turn[_current_round]
		for evt in events:
			_process_event(evt)
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
			elif is_crit:
				battle_log.append_text("[color=#F28A3E]  %s → %s 暴击 %d！[/color]\n" % [actor, target, value])
			else:
				battle_log.append_text("  %s → %s %d\n" % [actor, target, value])
		
		"unit_damaged":
			var unit_id: String = data.get("unit_id", "")
			var hp: int = data.get("hp", 0)
			var is_crit: bool = data.get("is_crit", false)
			
			if unit_id == "hero" or unit_id.begins_with("hero"):
				_hero_hp = maxi(0, hp)
				_flash_sprite(true, is_crit)
			else:
				_enemy_hp = maxi(0, hp)
				_flash_sprite(false, is_crit)
			
			if _hero_hp <= 0:
				battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % hero_name_label.text)
				_death_flash(true)
			elif _enemy_hp <= 0:
				battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % enemy_name_label.text)
				_death_flash(false)
		
		"unit_died":
			var uname: String = data.get("name", "???")
			battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % uname)
		
		"partner_assist":
			var pname: String = data.get("partner_name", "???")
			battle_log.append_text("[color=#BF4DE6]  %s 援助攻击！[/color]\n" % pname)
		
		"chain_triggered":
			var chain_count: int = data.get("chain_count", 0)
			var pname: String = data.get("partner_name", "???")
			var dmg: int = data.get("damage", 0)
			battle_log.append_text("[color=#BF4DE6]  CHAIN x%d! %s %d[/color]\n" % [chain_count, pname, dmg])
		
		"ultimate_triggered":
			var log_text: String = data.get("log", "")
			battle_log.append_text("[color=#E6C040]  %s[/color]\n" % log_text)
			_screen_shake()

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
		elif is_crit:
			battle_log.append_text("[color=#F28A3E]  %s → %s 暴击 %d！[/color]\n" % [hero_name_label.text, enemy_name_label.text, hero_dmg * 2])
			_enemy_hp = maxi(0, _enemy_hp - hero_dmg * 2)
		else:
			battle_log.append_text("  %s → %s %d\n" % [hero_name_label.text, enemy_name_label.text, hero_dmg])
			_enemy_hp = maxi(0, _enemy_hp - hero_dmg)
		
		if _enemy_hp <= 0:
			battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % enemy_name_label.text)
			_death_flash(false)
	
	# 敌人行动
	if _current_round < maxi(_sim_total_rounds, 3) and _hero_hp > 0 and _enemy_hp > 0:
		var enemy_target_hp: int = int(lerpf(_hero_max_hp, _sim_hero_final_hp, progress))
		var enemy_dmg: int = maxi(0, _hero_hp - enemy_target_hp)
		if enemy_dmg > 0:
			var is_miss: bool = randf() < 0.10
			if is_miss:
				battle_log.append_text("[color=#73737A]  %s → %s 闪避[/color]\n" % [enemy_name_label.text, hero_name_label.text])
			else:
				battle_log.append_text("  %s → %s %d\n" % [enemy_name_label.text, hero_name_label.text, enemy_dmg])
				_hero_hp = maxi(0, _hero_hp - enemy_dmg)
			
			if _hero_hp <= 0:
				battle_log.append_text("[color=#D93826]  %s 被击败！[/color]\n" % hero_name_label.text)
				_death_flash(true)

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
	print("[BattleAnimation] 跳过, gen=%d" % _playback_generation)
	_is_playing = false
	turn_timer.stop()
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
	_current_round = 0
	_hero_hp = 0
	_hero_max_hp = 0
	_enemy_hp = 0
	_enemy_max_hp = 0
	_recorder = null
	_events_by_turn = {}
	_turn_keys = []
	battle_log.text = ""
	visible = false

func _update_hp_display() -> void:
	hero_hp_bar.value = float(_hero_hp) / maxi(1, _hero_max_hp) * 100
	enemy_hp_bar.value = float(_enemy_hp) / maxi(1, _enemy_max_hp) * 100
	var hero_current: int = maxi(0, _hero_hp)
	var enemy_current: int = maxi(0, _enemy_hp)
	hero_hp_meta.text = "%d / %d" % [hero_current, _hero_max_hp]
	enemy_hp_meta.text = "%d / %d" % [enemy_current, _enemy_max_hp]

func _flash_sprite(is_hero: bool, is_crit: bool) -> void:
	var sprite: ColorRect = hero_art if is_hero else enemy_art
	var flash_color: Color = COL_CRIT if is_crit else Color(1, 1, 1)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", flash_color, 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.3), 0.2)

func _death_flash(is_hero: bool) -> void:
	var sprite: ColorRect = hero_art if is_hero else enemy_art
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.8, 0.1, 0.1), 0.15)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.3), 0.3)

func _screen_shake() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + 3, 0.05)
	tween.tween_property(self, "position:x", position.x - 3, 0.05)
	tween.tween_property(self, "position:x", position.x, 0.05)
