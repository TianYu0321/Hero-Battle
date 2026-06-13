class_name OutingPopup
extends PanelContainer

signal confirmed(choice_index: int)

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionLabel
@onready var choices_container: VBoxContainer = $VBoxContainer/ChoicesContainer
@onready var result_panel: VBoxContainer = $VBoxContainer/ResultPanel
@onready var result_label: Label = $VBoxContainer/ResultPanel/ResultLabel
@onready var effect_label: Label = $VBoxContainer/ResultPanel/EffectLabel
@onready var confirm_button: Button = $VBoxContainer/ResultPanel/ConfirmButton

var _event_data: Dictionary = {}
var _selected_choice: int = -1
var _font_cn: Font = preload(RunMainSettings.FONT_CN_PATH)

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	result_panel.visible = false
	_init_styles()
	_apply_font_recursive(self)


func _init_styles() -> void:
	## 自身羊皮纸弹窗样式
	var parchment := RunMainSettings.create_parchment_flat_style(RunMainSettings.CORNER_PARCHMENT)
	add_theme_stylebox_override("panel", parchment)
	
	## 确认按钮
	_apply_primary_button_style(confirm_button)
	
	## 标题（木牌样式背景）
	title_label.add_theme_font_override("font", _font_cn)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", RunMainSettings.COLOR_INK)
	
	## 描述文字
	description_label.add_theme_font_override("normal_font", _font_cn)
	description_label.add_theme_color_override("default_color", RunMainSettings.COLOR_INK)
	
	## 结果标签
	result_label.add_theme_font_override("font", _font_cn)
	result_label.add_theme_color_override("font_color", RunMainSettings.COLOR_HERO_RED_DARK)
	effect_label.add_theme_font_override("font", _font_cn)
	effect_label.add_theme_color_override("font_color", RunMainSettings.COLOR_WOOD_MEDIUM)


func _apply_primary_button_style(btn: Button) -> void:
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
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", RunMainSettings.COLOR_INK)
	btn.add_theme_color_override("font_hover_color", RunMainSettings.COLOR_INK)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_override("font", _font_cn)
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size.y = RunMainSettings.BUTTON_HEIGHT


func _apply_font_recursive(node: Node) -> void:
	if node is Label or node is Button:
		node.add_theme_font_override("font", _font_cn)
	for child in node.get_children():
		_apply_font_recursive(child)


func setup(event_data: Dictionary, current_gold: int = 99999, current_hp: int = 99999) -> void:
	_event_data = event_data
	_selected_choice = -1
	result_panel.visible = false
	choices_container.visible = true
	
	title_label.text = event_data.get("title", "外出遭遇")
	description_label.text = event_data.get("description", "")
	
	## 清除旧按钮
	for child in choices_container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	
	var choices: Array = event_data.get("choices", [])
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		var cost_gold: int = choice.get("cost_gold", 0)
		var cost_hp: int = choice.get("cost_hp", 0)
		var btn_text: String = choice.get("text", "选项 %d" % (i + 1))
		
		## 金币不足时标记
		if cost_gold > 0 and current_gold < cost_gold:
			btn_text += " [金币不足]"
			btn.disabled = true
		## HP 不足时标记
		if cost_hp > 0 and current_hp <= cost_hp:
			btn_text += " [体力不足]"
			btn.disabled = true
		
		btn.text = btn_text
		btn.pressed.connect(_on_choice_selected.bind(i))
		_apply_primary_button_style(btn)
		choices_container.add_child(btn)
	
	## 若无有效选择（如事件为空），自动补一个“继续”
	if choices.is_empty():
		var continue_btn := Button.new()
		continue_btn.text = "继续"
		continue_btn.pressed.connect(_on_choice_selected.bind(0))
		_apply_primary_button_style(continue_btn)
		choices_container.add_child(continue_btn)
	
	visible = true
	_play_entrance_animation()


func _kill_popup_tween() -> void:
	if has_meta("popup_tween"):
		var old: Tween = get_meta("popup_tween")
		if old != null and old.is_valid():
			old.kill()
		remove_meta("popup_tween")

func _play_entrance_animation() -> void:
	_kill_popup_tween()
	scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	pivot_offset = size / 2
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)
	set_meta("popup_tween", tween)


func _play_exit_animation(on_finished: Callable) -> void:
	_kill_popup_tween()
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(on_finished)
	set_meta("popup_tween", tween)


func _on_choice_selected(index: int) -> void:
	_selected_choice = index
	var choices: Array = _event_data.get("choices", [])
	if index < choices.size():
		var choice: Dictionary = choices[index]
		result_label.text = "你选择了：%s" % choice.get("text", "")
		
		var effect_parts: Array[String] = []
		var cost_gold: int = choice.get("cost_gold", 0)
		var cost_hp: int = choice.get("cost_hp", 0)
		if cost_gold > 0:
			effect_parts.append("金币 -%d" % cost_gold)
		elif cost_gold < 0:
			effect_parts.append("金币 +%d" % (-cost_gold))
		if cost_hp > 0:
			effect_parts.append("HP -%d" % cost_hp)
		elif cost_hp < 0:
			effect_parts.append("HP +%d" % (-cost_hp))
		
		var effect: Dictionary = choice.get("effect", {})
		if effect.has("gold"):
			effect_parts.append("金币+%d" % effect.get("gold", 0))
		if effect.has("level"):
			effect_parts.append("伙伴等级+%d" % effect.get("level", 1))
		if effect.has("heal_ratio"):
			effect_parts.append("恢复%d%%生命" % int(effect.get("heal_ratio", 0.4) * 100))
		if effect.has("training_level"):
			effect_parts.append("LV%d训练" % effect.get("training_level", 5))
		if effect.has("damage_ratio"):
			effect_parts.append("受到伤害%d%%" % int(effect.get("damage_ratio", 0.15) * 100))
		if effect.has("steal_gold_ratio"):
			effect_parts.append("损失%d%%金币" % int(effect.get("steal_gold_ratio", 0.2) * 100))
		if effect.has("debuff_type"):
			effect_parts.append("获得减益[%s]" % effect.get("debuff_type", ""))
		if effect.has("damage_reduction"):
			effect_parts.append("获得伤害减免")
		if effect.has("forecast_charge"):
			effect_parts.append("获得透视次数")
		if effect.has("bet_win"):
			effect_parts.append("押注已记录")
		if effect.has("training_bonus"):
			effect_parts.append("训练次数+%d" % effect.get("training_bonus", 0))
		if effect.has("random_attr"):
			effect_parts.append("随机属性+%d" % effect.get("random_attr", 0))
		
		if effect_parts.is_empty():
			effect_label.text = "无事发生"
		else:
			effect_label.text = " ".join(effect_parts)
	
	choices_container.visible = false
	result_panel.visible = true

func _on_confirm_pressed() -> void:
	_play_exit_animation(func():
		if _selected_choice >= 0:
			confirmed.emit(_selected_choice)
		visible = false
		choices_container.visible = true
		result_panel.visible = false
		## 重置缩放和透明度，为下次显示做准备
		scale = Vector2.ONE
		modulate = Color.WHITE
	)
