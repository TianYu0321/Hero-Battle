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

var _font_cn: Font = preload(RunMainSettings.FONT_CN_PATH)

func _ready() -> void:
	_setup_panel_style()
	_setup_labels()
	_setup_button()

func _setup_panel_style() -> void:
	var base_style := RunMainSettings.create_parchment_flat_style(12)
	base_style.border_width_left = 3
	base_style.border_width_top = 3
	base_style.border_width_right = 3
	base_style.border_width_bottom = 3
	base_style.border_color = RunMainSettings.COLOR_WOOD_MEDIUM
	base_style.shadow_color = RunMainSettings.COLOR_SHADOW
	base_style.shadow_size = 12
	base_style.shadow_offset = Vector2(0, 6)
	add_theme_stylebox_override("panel", base_style)

func _setup_labels() -> void:
	for label in [result_label, enemy_name_label, rounds_label, hp_loss_label, gold_label, chain_label]:
		label.add_theme_font_override("font", _font_cn)
	
	result_label.add_theme_font_size_override("font_size", 32)
	enemy_name_label.add_theme_font_size_override("font_size", 14)
	rounds_label.add_theme_font_size_override("font_size", 14)
	hp_loss_label.add_theme_font_size_override("font_size", 14)
	gold_label.add_theme_font_size_override("font_size", 14)
	chain_label.add_theme_font_size_override("font_size", 14)

func _setup_button() -> void:
	var normal := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_WOOD_PANEL,
		RunMainSettings.COLOR_WOOD_MEDIUM, 2,
		RunMainSettings.CORNER_WOOD
	)
	var hover := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_WOOD_LIGHT,
		RunMainSettings.COLOR_GOLD, 2,
		RunMainSettings.CORNER_WOOD
	)
	var pressed := RunMainSettings.create_wood_flat_style(
		RunMainSettings.COLOR_WOOD_MEDIUM,
		RunMainSettings.COLOR_WOOD_DARK, 3,
		RunMainSettings.CORNER_WOOD
	)
	confirm_button.add_theme_stylebox_override("normal", normal)
	confirm_button.add_theme_stylebox_override("hover", hover)
	confirm_button.add_theme_stylebox_override("pressed", pressed)
	confirm_button.add_theme_stylebox_override("focus", normal)
	confirm_button.add_theme_color_override("font_color", RunMainSettings.COLOR_INK)
	confirm_button.add_theme_color_override("font_hover_color", RunMainSettings.COLOR_INK)
	confirm_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	confirm_button.add_theme_font_override("font", _font_cn)
	confirm_button.add_theme_font_size_override("font_size", 16)

func show_result(battle_result: Dictionary) -> void:
	visible = true
	
	var winner = battle_result.get("winner", "")
	var is_victory = winner == "player"
	
	# 更新边框颜色：胜利绿色，失败红色，背景保持羊皮纸
	var style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	if is_victory:
		style.border_color = Color(0.3, 0.7, 0.4, 1.0)   # 胜利绿
		style.shadow_color = Color(0.3, 0.7, 0.4, 0.25)
		result_label.text = "🏆 胜利！"
		result_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.4, 1.0))
	else:
		style.border_color = Color(0.8, 0.3, 0.3, 1.0)    # 失败红
		style.shadow_color = Color(0.8, 0.3, 0.3, 0.25)
		result_label.text = "💀 败北..."
		result_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1.0))
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
	
	var chain_count = battle_result.get("max_chain_count", battle_result.get("chain_stats", {}).get("max_chain", 0))
	chain_label.text = "🔗 连锁触发: x%d" % chain_count
	
	if not confirm_button.pressed.is_connected(_on_confirmed):
		confirm_button.pressed.connect(_on_confirmed, CONNECT_ONE_SHOT)
	
	## 弹跳入场动画
	_popup_entrance_animation()


func _popup_entrance_animation() -> void:
	scale = Vector2(0.85, 0.85)
	modulate.a = 0.0
	
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)

func _on_confirmed() -> void:
	visible = false
	confirmed.emit()
