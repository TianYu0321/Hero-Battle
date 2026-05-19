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

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	result_panel.visible = false

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
		choices_container.add_child(btn)
	
	visible = true

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
	if _selected_choice >= 0:
		confirmed.emit(_selected_choice)
	visible = false
	choices_container.visible = true
	result_panel.visible = false
