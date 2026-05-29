## achievement_panel.gd
## 成就总览面板 — 列表样式（图标 | 名称+条件 | 状态）
extends PanelContainer

signal closed

@export var play_open_animation: bool = true

@onready var tab_container: TabContainer = $Content/TabContainer
@onready var close_button: Button = $Content/TitleBar/CloseButton
@onready var total_label: Label = $Content/TitleBar/TotalLabel
@onready var bg_dismiss: Button = $"Background/BgDismiss"

const ROW_HEIGHT := 72
const ICON_SIZE := 48

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	bg_dismiss.pressed.connect(_on_close_pressed)

	# 将背景层移到最前，确保 Content 及其子节点在绘制和输入上优先
	move_child($Background, 0)

	_update_total_label()
	_build_category_tabs()

	if play_open_animation:
		_animate_in()
	else:
		modulate = Color.WHITE
		scale = Vector2.ONE


func _update_total_label() -> void:
	total_label.text = "成就进度: %d / %d" % [AchievementManager.get_unlock_count(), AchievementManager.get_total_count()]


func _build_category_tabs() -> void:
	for cat in AchievementData.Category.values():
		var category_name: String = AchievementData.get_category_name(cat)

		var scroll := ScrollContainer.new()
		scroll.name = category_name
		tab_container.add_child(scroll)

		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 8)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)

		var achievements: Dictionary = AchievementData.get_achievements_by_category(cat)
		for id in achievements.keys():
			var row := _create_achievement_row(id, achievements[id])
			list.add_child(row)


func _create_achievement_row(id: String, data: Dictionary) -> PanelContainer:
	var is_unlocked: bool = AchievementManager.is_unlocked(id)
	var is_hidden: bool = data.get("hidden", false) and not is_unlocked

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 背景样式
	var style := StyleBoxFlat.new()
	if is_unlocked:
		style.bg_color = Color(0.98, 0.96, 0.88, 1.0)
		style.border_color = Color(0.85, 0.65, 0.15, 0.6)
	elif is_hidden:
		style.bg_color = Color(0.88, 0.88, 0.90, 1.0)
		style.border_color = Color(0.70, 0.70, 0.74, 0.4)
	else:
		style.bg_color = Color(0.96, 0.96, 0.96, 1.0)
		style.border_color = Color(0.80, 0.80, 0.82, 0.5)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	row.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hbox)

	# 左侧留白
	var left_pad := Control.new()
	left_pad.custom_minimum_size = Vector2(8, 0)
	hbox.add_child(left_pad)

	# 图标
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if is_hidden:
		icon.modulate = Color(0.5, 0.5, 0.55, 0.3)
	else:
		var icon_path: String = data.get("icon", "")
		if not icon_path.is_empty():
			var tex: Texture2D = load(icon_path)
			if tex != null:
				icon.texture = tex
		icon.modulate = Color(1, 1, 1, 1) if is_unlocked else Color(0.5, 0.5, 0.55, 0.5)
	hbox.add_child(icon)

	# 名称 + 描述 区域
	var text_vbox := VBoxContainer.new()
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.add_theme_constant_override("separation", 2)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_vbox)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 15)
	if is_hidden:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60, 1))
	else:
		name_label.text = data.get("name", "???")
		if is_unlocked:
			name_label.add_theme_color_override("font_color", Color(0.15, 0.12, 0.08, 1))
		else:
			name_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50, 1))
	text_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.add_theme_font_size_override("font_size", 12)
	if is_hidden:
		desc_label.text = "达成条件未知"
		desc_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60, 0.7))
	else:
		var condition_text: String = _get_condition_text(data)
		desc_label.text = data.get("description", "") + "  (" + condition_text + ")"
		if is_unlocked:
			desc_label.add_theme_color_override("font_color", Color(0.45, 0.42, 0.35, 1))
		else:
			desc_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58, 0.8))
	text_vbox.add_child(desc_label)

	# 进度条（仅未达成且非隐藏）
	if not is_unlocked and not is_hidden:
		var progress: float = AchievementManager.get_progress_percent(id)
		if progress > 0.0:
			var progress_bar := ProgressBar.new()
			progress_bar.custom_minimum_size = Vector2(180, 6)
			progress_bar.max_value = 1.0
			progress_bar.value = progress
			progress_bar.show_percentage = false
			var fg := StyleBoxFlat.new()
			fg.bg_color = Color(0.85, 0.65, 0.15, 1.0)
			fg.corner_radius_top_left = 3
			fg.corner_radius_top_right = 3
			fg.corner_radius_bottom_left = 3
			fg.corner_radius_bottom_right = 3
			progress_bar.add_theme_stylebox_override("fill", fg)
			var bg := StyleBoxFlat.new()
			bg.bg_color = Color(0.88, 0.88, 0.90, 1.0)
			bg.corner_radius_top_left = 3
			bg.corner_radius_top_right = 3
			bg.corner_radius_bottom_left = 3
			bg.corner_radius_bottom_right = 3
			progress_bar.add_theme_stylebox_override("background", bg)
			text_vbox.add_child(progress_bar)

	# 状态标签
	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_unlocked:
		status_label.text = "已达成"
		status_label.add_theme_color_override("font_color", Color(0.85, 0.55, 0.10, 1))
	elif is_hidden:
		status_label.text = "???"
		status_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60, 0.5))
	else:
		status_label.text = "未达成"
		status_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58, 0.7))
	hbox.add_child(status_label)

	# 右侧留白
	var right_pad := Control.new()
	right_pad.custom_minimum_size = Vector2(12, 0)
	hbox.add_child(right_pad)

	return row


func _get_condition_text(data: Dictionary) -> String:
	var condition_type: int = data.get("condition_type", -1)
	var target: int = data.get("target_value", 1)
	match condition_type:
		AchievementData.ConditionType.REACH_FLOOR:
			return "到达第 %d 层" % target
		AchievementData.ConditionType.WIN_BATTLE:
			return "累计获胜 %d 场" % target
		AchievementData.ConditionType.NO_DAMAGE:
			return "无伤通关 %d 次" % target
		AchievementData.ConditionType.KILL_COUNT:
			return "累计击败 %d 个敌人" % target
		AchievementData.ConditionType.CRITICAL_COUNT:
			return "累计暴击 %d 次" % target
		AchievementData.ConditionType.GOLD_TOTAL:
			return "累计获得 %d 金币" % target
		AchievementData.ConditionType.RUN_COUNT:
			return "进行 %d 场冒险" % target
		AchievementData.ConditionType.UNLOCK_PARTNER:
			return "解锁 %d 个伙伴" % target
		AchievementData.ConditionType.HEAL_AMOUNT:
			return "累计恢复 %d 点生命" % target
		AchievementData.ConditionType.DAMAGE_DEALT:
			return "累计造成 %d 点伤害" % target
		AchievementData.ConditionType.TURN_CLEAR:
			return "%d 回合内通关" % target
		AchievementData.ConditionType.SCORE_GRADE:
			return "获得 %d 分以上" % target
		AchievementData.ConditionType.ELITE_KILL:
			return "累计击败 %d 个精英" % target
		AchievementData.ConditionType.MAX_HP_REACH:
			return "最大生命达到 %d" % target
		_:
			return "目标: %d" % target


func _on_close_pressed() -> void:
	_animate_out()


func _animate_in() -> void:
	scale = Vector2(0.9, 0.9)
	modulate.a = 0.0

	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.25)


func _animate_out() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)

	await tween.finished
	closed.emit()
	queue_free()
