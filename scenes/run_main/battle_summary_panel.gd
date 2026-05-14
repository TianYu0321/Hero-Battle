class_name BattleSummaryPanel
extends PanelContainer

@onready var result_label: Label = $MarginContainer/ContentVBox/ResultLabel
@onready var enemy_name_label: Label = $MarginContainer/ContentVBox/DetailContainer/EnemyNameLabel
@onready var rounds_label: Label = $MarginContainer/ContentVBox/DetailContainer/RoundsLabel
@onready var hp_loss_label: Label = $MarginContainer/ContentVBox/DetailContainer/HpLossLabel
@onready var gold_label: Label = $MarginContainer/ContentVBox/DetailContainer/GoldLabel
@onready var chain_label: Label = $MarginContainer/ContentVBox/DetailContainer/ChainLabel
@onready var confirm_button: Button = $MarginContainer/ContentVBox/ConfirmButton

signal confirmed

func _ready() -> void:
	_setup_panel_style()

func _setup_panel_style() -> void:
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	base_style.corner_radius_top_left = 12
	base_style.corner_radius_top_right = 12
	base_style.corner_radius_bottom_left = 12
	base_style.corner_radius_bottom_right = 12
	base_style.border_width_left = 3
	base_style.border_width_top = 3
	base_style.border_width_right = 3
	base_style.border_width_bottom = 3
	base_style.border_color = Color(0.6, 0.5, 0.2, 0.9)  # 默认金色边框
	base_style.shadow_color = Color(0, 0, 0, 0.5)
	base_style.shadow_size = 8
	base_style.shadow_offset = Vector2(4, 4)
	add_theme_stylebox_override("panel", base_style)

func show_result(battle_result: Dictionary) -> void:
	visible = true
	
	var winner = battle_result.get("winner", "")
	var is_victory = winner == "player"
	
	# 更新边框颜色：胜利金色，失败暗红
	var style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	if is_victory:
		style.border_color = Color(1.0, 0.84, 0.0, 0.95)   # 金色
		style.bg_color = Color(0.08, 0.08, 0.10, 0.93)
		result_label.text = "🏆 胜利！"
		result_label.modulate = Color(1.0, 0.84, 0.0)
	else:
		style.border_color = Color(0.6, 0.1, 0.1, 0.95)    # 暗红
		style.bg_color = Color(0.12, 0.05, 0.05, 0.93)
		result_label.text = "💀 败北..."
		result_label.modulate = Color(0.8, 0.2, 0.2)
	add_theme_stylebox_override("panel", style)
	
	var enemies = battle_result.get("enemies", [])
	var enemy_name = "???"
	if enemies.size() > 0:
		enemy_name = enemies[0].get("name", "???")
	var opponent_source = battle_result.get("opponent_source", "ai")
	var source_text = "(档案影子)" if opponent_source == "archive" else "(AI)"
	enemy_name_label.text = "👹 对手: %s %s" % [enemy_name, source_text]
	
	var turns = battle_result.get("turns_elapsed", 0)
	rounds_label.text = "⏱️ 经过 %d 回合" % turns
	
	var hero_remaining_hp = battle_result.get("hero_remaining_hp", 0)
	var hero_max_hp = battle_result.get("hero_max_hp", 100)
	var hp_loss = hero_max_hp - hero_remaining_hp
	hp_loss_label.text = "❤️ 损失生命: %d/%d" % [hp_loss, hero_max_hp]
	
	var gold_reward = battle_result.get("gold_reward", 0)
	gold_label.text = "💰 获得金币: %d" % gold_reward
	
	var chain_count = battle_result.get("max_chain_count", 0)
	chain_label.text = "🔗 连锁触发: x%d" % chain_count
	
	if not confirm_button.pressed.is_connected(_on_confirmed):
		confirm_button.pressed.connect(_on_confirmed, CONNECT_ONE_SHOT)

func _on_confirmed() -> void:
	visible = false
	confirmed.emit()
