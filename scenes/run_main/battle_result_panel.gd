## 战斗结算面板（胜利专用）
## 职责：战斗胜利后弹出，展示简要战果，玩家点击"继续"后推进状态机
## 位置：RunMain 场景子节点（CanvasLayer），不耦合业务逻辑

extends CanvasLayer

signal primary_action_pressed
signal secondary_action_pressed

@onready var main_panel: PanelContainer = $MainPanel
@onready var title_label: Label = $MainPanel/VBoxContainer/OutcomeTitle
@onready var content_container: Control = $MainPanel/VBoxContainer/ContentContainer
@onready var primary_btn: Button = $MainPanel/VBoxContainer/ButtonRow/PrimaryBtn
@onready var secondary_btn: Button = $MainPanel/VBoxContainer/ButtonRow/SecondaryBtn
@onready var overlay: ColorRect = $Overlay
@onready var particles: CPUParticles2D = $ParticleEffect

var _font_cn: Font = preload(RunMainSettings.FONT_CN_PATH)

func _ready() -> void:
	_setup_styles()
	primary_btn.pressed.connect(_on_primary)
	secondary_btn.pressed.connect(_on_secondary)
	
	## 默认隐藏
	visible = false
	overlay.modulate.a = 0.0
	main_panel.scale = Vector2(0.85, 0.85)
	main_panel.modulate.a = 0.0

func _setup_styles() -> void:
	## 面板样式：羊皮纸底 + 动态边框（胜利绿/失败红）
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = RunMainSettings.COLOR_PARCHMENT
	panel_style.border_color = RunMainSettings.COLOR_WOOD_MEDIUM
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.shadow_color = RunMainSettings.COLOR_SHADOW
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 6)
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	## 标题字体
	title_label.add_theme_font_override("font", _font_cn)
	title_label.add_theme_font_size_override("font_size", 32)
	
	## 按钮样式
	_apply_button_style(primary_btn)

func show_result(data: Dictionary) -> void:
	visible = true
	
	## 清空旧内容
	for child in content_container.get_children():
		child.queue_free()
	
	var outcome: String = data.get("outcome", "victory")
	match outcome:
		"victory":
			_setup_victory(data)
		"defeat":
			_setup_defeat(data)
	
	## 入场动画
	overlay.modulate.a = 0.0
	main_panel.scale = Vector2(0.85, 0.85)
	main_panel.modulate.a = 0.0
	
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(main_panel, "modulate:a", 1.0, 0.35)
	tween.parallel().tween_property(main_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)

## ========== 胜利布局 ==========

func _setup_victory(data: Dictionary) -> void:
	title_label.text = "胜利！"
	title_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.4, 1.0))
	
	## 胜利绿边框
	var style: StyleBoxFlat = main_panel.get_theme_stylebox("panel").duplicate()
	style.border_color = Color(0.3, 0.7, 0.4, 1.0)
	style.shadow_color = Color(0.3, 0.7, 0.4, 0.25)
	main_panel.add_theme_stylebox_override("panel", style)
	
	particles.emitting = true
	
	primary_btn.text = "继续"
	primary_btn.visible = true
	secondary_btn.visible = false
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	content_container.add_child(vbox)
	
	## 金币行（本场获得）
	var gold_earned: int = data.get("gold_earned", 0)
	if gold_earned > 0:
		var gold_row := _create_stat_row("获得金币", "+%d" % gold_earned, Color(0.85, 0.65, 0.15, 1))
		vbox.add_child(gold_row)
	
	## 持有金币
	var total_gold: int = data.get("total_gold", 0)
	var total_row := _create_stat_row("持有金币", "%d" % total_gold, Color(0.55, 0.55, 0.58, 1))
	vbox.add_child(total_row)
	
	## 连锁行
	var chain_count: int = data.get("chain_count", 0)
	if chain_count > 0:
		var chain_row := _create_stat_row("连锁触发", "x%d" % chain_count, Color(0.25, 0.55, 0.9, 1))
		vbox.add_child(chain_row)
	
	## 回合数
	var turns: int = data.get("turns", 0)
	if turns > 0:
		var turns_row := _create_stat_row("战斗回合", "%d" % turns, Color(0.55, 0.55, 0.58, 1))
		vbox.add_child(turns_row)
	
	## 对手名
	var enemy_name: String = data.get("enemy_name", "")
	if not enemy_name.is_empty():
		var enemy_row := _create_stat_row("击败对手", enemy_name, Color(0.55, 0.55, 0.58, 1))
		vbox.add_child(enemy_row)

## ========== 失败布局 ==========

func _setup_defeat(data: Dictionary) -> void:
	title_label.text = "败北..."
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.75, 0.25, 0.25, 1))
	
	var style: StyleBoxFlat = main_panel.get_theme_stylebox("panel").duplicate()
	style.border_color = Color(0.75, 0.25, 0.25, 1)
	style.shadow_color = Color(0.75, 0.25, 0.25, 0.25)
	main_panel.add_theme_stylebox_override("panel", style)
	
	particles.emitting = false
	
	## === 双按钮 ===
	primary_btn.text = "重新开始"
	primary_btn.visible = true
	secondary_btn.text = "返回主菜单"
	secondary_btn.visible = true
	
	## 按钮样式
	_apply_button_style(primary_btn, true)    ## 蓝色主按钮
	_apply_button_style(secondary_btn, false) ## 灰色次按钮
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	content_container.add_child(vbox)
	
	## 统计标题
	var stats_title := Label.new()
	stats_title.text = "本次冒险统计"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_override("font", _font_cn)
	stats_title.add_theme_font_size_override("font_size", 16)
	stats_title.add_theme_color_override("font_color", Color(0.35, 0.35, 0.38, 1))
	vbox.add_child(stats_title)
	
	## 统计行
	var stats: Dictionary = data.get("battle_stats", {})
	var stat_rows := [
		["到达层数", "%d层" % stats.get("total_floors", 1)],
		["击败敌人", "%d个" % stats.get("enemies_defeated", 0)],
		["累计金币", "%d" % stats.get("total_gold_collected", 0)],
		["战斗次数", "%d场" % stats.get("total_battles", 0)],
		["冒险时长", stats.get("play_time", "00:00")],
	]
	
	for row_data in stat_rows:
		var row := _create_stat_row(row_data[0], row_data[1], Color(0.55, 0.55, 0.58, 1))
		vbox.add_child(row)
	
	## 提示
	var hint := Label.new()
	hint.text = "胜败乃兵家常事，请大侠重新来过"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_override("font", _font_cn)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.68, 1))
	vbox.add_child(hint)

## ========== 通用辅助 ==========

func _create_stat_row(label_text: String, value_text: String, value_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", _font_cn)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.48, 1))
	row.add_child(label)
	
	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_override("font", _font_cn)
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", value_color)
	row.add_child(value)
	
	return row

func _apply_button_style(btn: Button, is_primary: bool = true) -> void:
	if is_primary:
		## 主按钮：蓝色调
		var normal := RunMainSettings.create_wood_flat_style(
			Color(0.25, 0.45, 0.75),
			Color(0.35, 0.55, 0.85), 2,
			RunMainSettings.CORNER_WOOD
		)
		var hover := RunMainSettings.create_wood_flat_style(
			Color(0.3, 0.5, 0.8),
			Color(0.45, 0.65, 0.95), 2,
			RunMainSettings.CORNER_WOOD
		)
		var pressed := RunMainSettings.create_wood_flat_style(
			Color(0.2, 0.4, 0.7),
			Color(0.3, 0.5, 0.8), 3,
			RunMainSettings.CORNER_WOOD
		)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("focus", normal)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.9, 1.0))
	else:
		## 次按钮：灰色调
		var normal := RunMainSettings.create_wood_flat_style(
			Color(0.45, 0.45, 0.48),
			Color(0.55, 0.55, 0.58), 2,
			RunMainSettings.CORNER_WOOD
		)
		var hover := RunMainSettings.create_wood_flat_style(
			Color(0.5, 0.5, 0.53),
			Color(0.6, 0.6, 0.63), 2,
			RunMainSettings.CORNER_WOOD
		)
		var pressed := RunMainSettings.create_wood_flat_style(
			Color(0.4, 0.4, 0.43),
			Color(0.5, 0.5, 0.53), 3,
			RunMainSettings.CORNER_WOOD
		)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("focus", normal)
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.8, 0.82))
	
	btn.add_theme_font_override("font", _font_cn)
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(140, 44)

func _on_primary() -> void:
	_hide_panel()
	primary_action_pressed.emit()

func _on_secondary() -> void:
	_hide_panel()
	secondary_action_pressed.emit()

func _hide_panel() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(main_panel, "scale", Vector2(0.9, 0.9), 0.2)
	tween.parallel().tween_property(main_panel, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(overlay, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func():
		visible = false
		particles.emitting = false
	)
