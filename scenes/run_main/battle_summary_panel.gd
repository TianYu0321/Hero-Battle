class_name BattleSummaryPanel
extends Panel

@onready var result_label: Label = $ResultLabel
@onready var enemy_name_label: Label = $DetailContainer/EnemyNameLabel
@onready var rounds_label: Label = $DetailContainer/RoundsLabel
@onready var hp_loss_label: Label = $DetailContainer/HpLossLabel
@onready var gold_label: Label = $DetailContainer/GoldLabel
@onready var chain_label: Label = $DetailContainer/ChainLabel
@onready var confirm_button: Button = $ConfirmButton

signal confirmed

func show_result(battle_result: Dictionary) -> void:
	visible = true
	
	var winner = battle_result.get("winner", "")
	var is_victory = winner == "player"
	
	result_label.text = "胜利！" if is_victory else "败北..."
	result_label.modulate = Color(0, 1, 0) if is_victory else Color(1, 0, 0)
	
	var enemies = battle_result.get("enemies", [])
	var enemy_name = "???"
	if enemies.size() > 0:
		enemy_name = enemies[0].get("name", "???")
	var opponent_source = battle_result.get("opponent_source", "ai")
	var source_text = "(档案影子)" if opponent_source == "archive" else "(AI)"
	enemy_name_label.text = "对手: %s %s" % [enemy_name, source_text]
	
	var turns = battle_result.get("turns_elapsed", 0)
	rounds_label.text = "经过%d回合" % turns
	
	var hero_remaining_hp = battle_result.get("hero_remaining_hp", 0)
	var hero_max_hp = battle_result.get("hero_max_hp", 100)
	var hp_loss = hero_max_hp - hero_remaining_hp
	hp_loss_label.text = "损失生命: %d/%d" % [hp_loss, hero_max_hp]
	
	var gold_reward = battle_result.get("gold_reward", 0)
	gold_label.text = "获得金币: %d" % gold_reward
	
	var chain_count = battle_result.get("max_chain_count", 0)
	chain_label.text = "连锁触发: x%d" % chain_count
	
	if not confirm_button.pressed.is_connected(_on_confirmed):
		confirm_button.pressed.connect(_on_confirmed, CONNECT_ONE_SHOT)

func _on_confirmed() -> void:
	visible = false
	confirmed.emit()
