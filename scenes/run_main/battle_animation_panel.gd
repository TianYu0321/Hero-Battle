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
var _total_rounds: int = 0

var _hero_hp: int = 0
var _hero_max_hp: int = 0
var _enemy_hp: int = 0
var _enemy_max_hp: int = 0

signal confirmed

const COL_TEXT_MAIN := Color(0.90, 0.90, 0.92)
const COL_TEXT_SECOND := Color(0.68, 0.68, 0.71)
const COL_RED_MAIN := Color(0.85, 0.22, 0.15)
const COL_RED_DEEP := Color(0.35, 0.06, 0.04)
const COL_BLUE_MAIN := Color(0.25, 0.55, 0.85)
const COL_BLUE_DEEP := Color(0.08, 0.18, 0.35)
const COL_GOLD := Color(0.90, 0.75, 0.35)

func _ready() -> void:
	turn_timer.timeout.connect(_on_turn_timer_timeout)
	skip_button.pressed.connect(_on_skip)
	visible = false
	_apply_dark_theme()

func _apply_dark_theme() -> void:
	semi_transparent_bg.color = Color(0.05, 0.05, 0.08, 0.85)
	hero_portrait.color = COL_BLUE_DEEP
	enemy_portrait.color = COL_RED_DEEP
	vs_label.add_theme_color_override("font_color", COL_GOLD)
	round_label.add_theme_color_override("font_color", COL_TEXT_MAIN)
	log_head.add_theme_color_override("font_color", COL_GOLD)
	stage_name_label.add_theme_color_override("font_color", COL_TEXT_SECOND)
	skip_button.add_theme_color_override("font_color", COL_TEXT_MAIN)
	skip_button.add_theme_color_override("font_hover_color", COL_GOLD)

## 兼容 PVP 大厅的旧版调用
func start_playback(recorder, hero_name: String, enemy_name: String,
					hero_max_hp: int, enemy_max_hp: int,
					_hero_partners: Array, _enemy_partners: Array) -> void:
	# 从 recorder 提取回合数
	var total_rounds: int = 1
	if recorder != null and recorder.has_method("get_events"):
		var events = recorder.get_events()
		total_rounds = maxi(1, events.size() / 2)
	
	var battle_result: Dictionary = {
		"hero_name": hero_name,
		"enemy_name": enemy_name,
		"hero_max_hp": hero_max_hp,
		"enemy_max_hp": enemy_max_hp,
		"hero_hp": hero_max_hp,
		"enemy_hp": 0,
		"total_rounds": clampi(total_rounds, 3, 20),
		"stage_name": "PVP 决斗场",
	}
	start_battle(battle_result)

func start_battle(battle_result: Dictionary) -> void:
	_playback_generation += 1
	_result_emitted = false
	_is_playing = true
	visible = true
	
	_total_rounds = maxi(1, battle_result.get("total_rounds", 1))
	_current_round = 0
	
	_hero_max_hp = maxi(1, battle_result.get("hero_max_hp", 100))
	_hero_hp = clampi(battle_result.get("hero_hp", _hero_max_hp), 0, _hero_max_hp)
	_enemy_max_hp = maxi(1, battle_result.get("enemy_max_hp", 100))
	_enemy_hp = clampi(battle_result.get("enemy_hp", _enemy_max_hp), 0, _enemy_max_hp)
	
	var hero_name: String = battle_result.get("hero_name", "英雄")
	var enemy_name: String = battle_result.get("enemy_name", "???")
	var stage_name: String = battle_result.get("stage_name", "深渊斗技场")
	
	hero_name_label.text = hero_name
	enemy_name_label.text = enemy_name
	stage_name_label.text = stage_name
	
	# 确保舞台剪影可见
	hero_art.visible = true
	enemy_art.visible = true
	
	_update_hp_display()
	
	hero_hp_bar.add_theme_color_override("theme_fg", COL_BLUE_MAIN)
	hero_hp_bar.add_theme_color_override("theme_bg", COL_BLUE_DEEP)
	enemy_hp_bar.add_theme_color_override("theme_fg", COL_RED_MAIN)
	enemy_hp_bar.add_theme_color_override("theme_bg", COL_RED_DEEP)
	
	battle_log.text = ""
	battle_log.append_text("[color=#E6C040]战斗开始！[/color]\n")
	
	print("[BattleAnimation] 开始: gen=%d, %d回合, 英雄=%s, 敌人=%s" % [
		_playback_generation, _total_rounds, hero_name, enemy_name
	])
	_play_turn()

func _play_turn() -> void:
	if not _is_playing:
		return
	
	_current_round += 1
	if _current_round > _total_rounds:
		_show_result()
		return
	
	round_label.text = "回合 %d/%d" % [_current_round, _total_rounds]
	
	var progress: float = float(_current_round) / float(_total_rounds)
	var hero_loss_est: int = int((_hero_max_hp - _hero_hp) * progress * 0.3)
	var enemy_loss_est: int = int(_enemy_max_hp * progress * 0.7)
	
	hero_hp_bar.value = maxi(0, _hero_hp - hero_loss_est)
	enemy_hp_bar.value = maxi(0, _enemy_hp - enemy_loss_est)
	_update_hp_display()
	
	if _current_round == 1:
		battle_log.append_text("[color=#5A8FD0]第 %d 回合... [/color]" % _current_round)
	else:
		battle_log.append_text("第 %d 回合... " % _current_round)
	
	turn_timer.start(1.0)

func _on_turn_timer_timeout() -> void:
	if not _is_playing:
		return
	_play_turn()

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
	
	hero_hp_bar.value = _hero_hp
	enemy_hp_bar.value = _enemy_hp
	_update_hp_display()
	
	battle_log.append_text("\n[color=#E6C040]=== 战斗结束 ===[/color]")
	print("[BattleAnimation] confirmed, gen=%d" % _playback_generation)
	confirmed.emit()

func reset_panel() -> void:
	_is_playing = false
	turn_timer.stop()
	_current_round = 0
	_total_rounds = 0
	_hero_hp = 0
	_hero_max_hp = 0
	_enemy_hp = 0
	_enemy_max_hp = 0
	battle_log.text = ""
	visible = false

func _update_hp_display() -> void:
	var hero_current: int = maxi(0, _hero_hp)
	var enemy_current: int = maxi(0, _enemy_hp)
	hero_hp_meta.text = "%d / %d" % [hero_current, _hero_max_hp]
	enemy_hp_meta.text = "%d / %d" % [enemy_current, _enemy_max_hp]