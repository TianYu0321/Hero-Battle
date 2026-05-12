class_name Battle
extends Control

@onready var hero_hp_bar: ProgressBar = $BattleField/HeroHpBar
@onready var enemy_hp_bar: ProgressBar = $BattleField/EnemyHpBar
@onready var round_label: Label = $BattleField/RoundLabel
@onready var battle_log: RichTextLabel = $BattleLog

func _ready() -> void:
	hero_hp_bar.value = 100.0
	enemy_hp_bar.value = 100.0
	round_label.text = "回合: 1/20"

func update_hp(hero_hp: int, enemy_hp: int) -> void:
	hero_hp_bar.value = hero_hp
	enemy_hp_bar.value = enemy_hp

func append_log(text: String) -> void:
	battle_log.append_text(text + "\n")
