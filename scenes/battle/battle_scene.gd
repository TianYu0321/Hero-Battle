class_name BattleScene
extends Control

## 独立战斗场景
## 职责：接收 GameManager.current_battle_data，播放战斗动画，结束后返回爬塔

@onready var battle_animation_panel: BattleAnimationPanel = $BattleAnimationPanel

func _ready() -> void:
	## 从 GameManager 读取战斗数据
	var battle_data: Dictionary = GameManager.current_battle_data
	if battle_data.is_empty():
		push_warning("[BattleScene] 没有战斗数据，直接返回")
		_return_to_run_main()
		return
	
	var recorder = battle_data.get("recorder", null)
	var hero_name: String = battle_data.get("hero_name", "英雄")
	var enemy_name: String = battle_data.get("enemy_name", "敌人")
	var hero_max_hp: int = battle_data.get("hero_max_hp", 100)
	var enemy_max_hp: int = battle_data.get("enemy_max_hp", 100)
	var hero_partners: Array = battle_data.get("hero_partners", [])
	var enemy_partners: Array = battle_data.get("enemy_partners", [])
	var total_rounds: int = battle_data.get("total_rounds", 0)
	var hero_start_hp: int = battle_data.get("hero_start_hp", -1)
	var enemy_start_hp: int = battle_data.get("enemy_start_hp", -1)
	var hero_sprite_path: String = battle_data.get("hero_sprite_path", "")
	var enemy_sprite_path: String = battle_data.get("enemy_sprite_path", "")
	var current_floor: int = battle_data.get("current_floor", 1)
	
	## 连接动画结束信号
	battle_animation_panel.confirmed.connect(_on_battle_animation_finished, CONNECT_ONE_SHOT)
	
	## 启动战斗动画回放
	battle_animation_panel.start_playback(
		null, hero_name, enemy_name,
		hero_max_hp, enemy_max_hp,
		hero_partners, enemy_partners,
		total_rounds,
		hero_start_hp, enemy_start_hp,
		hero_sprite_path, enemy_sprite_path,
		current_floor,
		battle_data.get("events_by_turn", {})
	)


func _on_battle_animation_finished() -> void:
	## 战斗动画播放完毕，返回爬塔场景
	## 结算面板由 RunMain 在返回后显示
	_return_to_run_main()


func _return_to_run_main() -> void:
	## 设置返回标记，RunMain 读取 pending_battle_result 显示结算
	GameManager.returning_from_battle = true
	## 清理战斗数据标记
	GameManager.current_battle_data = {}
	## 返回爬塔场景
	GameManager.change_scene("RUNNING", "fade")
