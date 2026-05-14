class_name BattleAnimationPanel
extends Control

@onready var round_label: Label = $BattleField/RoundLabel
@onready var hero_rect: Control = $BattleField/HeroRect
@onready var enemy_rect: Control = $BattleField/EnemyRect
@onready var hero_hp_bar: ProgressBar = $BattleField/HeroHpBar
@onready var enemy_hp_bar: ProgressBar = $BattleField/EnemyHpBar
@onready var battle_log: RichTextLabel = $BattleLog
@onready var speed_button: Button = $SpeedButton
@onready var turn_timer: Timer = $TurnTimer

var _playback_generation: int = 0
var _result_emitted: bool = false
var _is_playing: bool = false
var _current_round: int = 0
var _max_rounds: int = 0
var _hero_hp: int = 0
var _hero_max_hp: int = 0
var _enemy_hp: int = 0
var _enemy_max_hp: int = 0
var _enemy_name: String = "???"

signal confirmed

func _ready() -> void:
	turn_timer.timeout.connect(_on_turn_timer_timeout)
	speed_button.pressed.connect(_on_skip)
	visible = false

func start_battle(enemy_cfg: Dictionary, hero_data: Dictionary) -> void:
	_playback_generation += 1
	_result_emitted = false
	_is_playing = true
	visible = true
	
	_hero_max_hp = hero_data.get("max_hp", 100)
	_hero_hp = hero_data.get("current_hp", 100)
	_enemy_max_hp = enemy_cfg.get("max_hp", 100)
	_enemy_hp = enemy_cfg.get("hp", 100)
	_enemy_name = enemy_cfg.get("name", "???")
	
	var estimated_loss: int = enemy_cfg.get("estimated_hp_loss", 10)
	_max_rounds = clampi(estimated_loss / 5 + 2, 3, 15)
	_current_round = 0
	
	hero_hp_bar.max_value = _hero_max_hp
	hero_hp_bar.value = _hero_hp
	enemy_hp_bar.max_value = _enemy_max_hp
	enemy_hp_bar.value = _enemy_hp
	
	round_label.text = "回合: 1/%d" % _max_rounds
	battle_log.clear()
	battle_log.append_text("[color=yellow]战斗开始！[/color]\n")
	
	print("[BattleAnimation] 开始: gen=%d, %d回合, 敌人=%s" % [_playback_generation, _max_rounds, _enemy_name])
	_play_turn()

func _play_turn() -> void:
	var gen: int = _playback_generation
	
	if not _is_playing or _current_round >= _max_rounds:
		_show_result()
		return
	
	_current_round += 1
	round_label.text = "回合: %d/%d" % [_current_round, _max_rounds]
	
	# 模拟战斗过程（线性插值预估）
	var progress: float = float(_current_round) / float(_max_rounds)
	var hero_loss_est: int = int((_hero_max_hp - _hero_hp) * progress * 0.3)
	var enemy_loss_est: int = int(_enemy_max_hp * progress * 0.7)
	
	hero_hp_bar.value = maxi(0, _hero_hp - hero_loss_est)
	enemy_hp_bar.value = maxi(0, _enemy_hp - enemy_loss_est)
	battle_log.append_text("第 %d 回合... " % _current_round)
	
	turn_timer.start(0.8)

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
	battle_log.append_text("\n[color=yellow]=== 战斗结束 ===[/color]")
	print("[BattleAnimation] confirmed, gen=%d" % _playback_generation)
	confirmed.emit()

func reset_panel() -> void:
	_is_playing = false
	turn_timer.stop()
	_current_round = 0
	_max_rounds = 0
	_hero_hp = 0
	_hero_max_hp = 0
	_enemy_hp = 0
	_enemy_max_hp = 0
	_enemy_name = "???"
	battle_log.text = ""
	round_label.text = "回合: 1/20"
	hero_hp_bar.value = 100
	enemy_hp_bar.value = 100
	visible = false
