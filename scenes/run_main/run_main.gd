class_name RunMain
extends Control

@onready var floor_label: Label = $HudContainer/FloorLabel
@onready var gold_label: Label = $HudContainer/GoldLabel
@onready var hp_label: Label = $HudContainer/HpLabel

@onready var attr_bars: Array[ProgressBar] = [
	$HudContainer/AttrBar1,
	$HudContainer/AttrBar2,
	$HudContainer/AttrBar3,
	$HudContainer/AttrBar4,
	$HudContainer/AttrBar5,
]

@onready var option_buttons: Array[Button] = [
	$OptionContainer/TrainButton,
	$OptionContainer/BattleButton,
	$OptionContainer/RestButton,
	$OptionContainer/OutingButton,
]

@onready var partner_slots: Array[ColorRect] = [
	$PartnerContainer/PartnerSlot1,
	$PartnerContainer/PartnerSlot2,
	$PartnerContainer/PartnerSlot3,
	$PartnerContainer/PartnerSlot4,
	$PartnerContainer/PartnerSlot5,
]

@onready var training_panel: VBoxContainer = $TrainingPanel
@onready var option_container: VBoxContainer = $OptionContainer

@onready var training_select_buttons: Array[Button] = [
	$TrainingPanel/AttrRow1/SelectBtn,
	$TrainingPanel/AttrRow2/SelectBtn,
	$TrainingPanel/AttrRow3/SelectBtn,
	$TrainingPanel/AttrRow4/SelectBtn,
	$TrainingPanel/AttrRow5/SelectBtn,
]

@onready var training_lv_labels: Array[Label] = [
	$TrainingPanel/AttrRow1/LvLabel,
	$TrainingPanel/AttrRow2/LvLabel,
	$TrainingPanel/AttrRow3/LvLabel,
	$TrainingPanel/AttrRow4/LvLabel,
	$TrainingPanel/AttrRow5/LvLabel,
]

var _run_controller: RunController = null


func _ready() -> void:
	# --- 按钮点击绑定 ---
	for i in range(option_buttons.size()):
		option_buttons[i].pressed.connect(_on_node_button_pressed.bind(i))

	# 训练属性选择按钮绑定
	for i in range(training_select_buttons.size()):
		training_select_buttons[i].pressed.connect(_on_training_attr_selected.bind(i + 1))

	# --- EventBus 信号订阅 ---
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.pvp_result.connect(_on_pvp_result)
	EventBus.floor_changed.connect(_on_floor_changed)
	EventBus.node_options_presented.connect(_on_node_options_presented)
	EventBus.run_started.connect(_on_run_started)
	EventBus.floor_advanced.connect(_on_floor_advanced)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.panel_closed.connect(_on_panel_closed)
	EventBus.training_completed.connect(_on_training_completed)

	# --- 实例化并启动 RunController ---
	_run_controller = RunController.new()
	_run_controller.name = "RunController"
	add_child(_run_controller)

	var hero_config_id: int = GameManager.selected_hero_config_id
	var partner_config_ids: Array[int] = GameManager.selected_partner_config_ids.duplicate()

	if hero_config_id <= 0:
		push_error("[RunMain] No hero selected, cannot start run")
		return

	_run_controller.start_new_run(hero_config_id, partner_config_ids)


func _update_hud() -> void:
	if _run_controller == null:
		return
	var summary: Dictionary = _run_controller.get_current_run_summary()
	var current_turn: int = summary.get("current_turn", 1)
	var gold: int = summary.get("gold", 0)
	var hero_data: Dictionary = summary.get("hero", {})
	var current_hp: int = hero_data.get("current_hp", 100)
	var max_hp: int = hero_data.get("max_hp", 100)

	floor_label.text = "层数: %d/30" % current_turn
	gold_label.text = "金币: %d" % gold
	hp_label.text = "生命: %d/%d" % [current_hp, max_hp]

	var attrs: Array[int] = [
		hero_data.get("current_vit", 0),
		hero_data.get("current_str", 0),
		hero_data.get("current_agi", 0),
		hero_data.get("current_tec", 0),
		hero_data.get("current_mnd", 0),
	]
	for i in range(attr_bars.size()):
		attr_bars[i].value = float(attrs[i])


func _on_node_button_pressed(index: int) -> void:
	if _run_controller == null:
		push_warning("[RunMain] RunController not available")
		return
	_run_controller.select_node(index)


func _on_training_attr_selected(attr_type: int) -> void:
	## 玩家从训练面板选择了具体属性
	if _run_controller != null:
		_run_controller.select_training_attr(attr_type)
	_show_option_container()


func _show_training_panel() -> void:
	## 显示训练属性选择面板
	option_container.visible = false
	training_panel.visible = true
	# 更新各属性训练等级显示
	var summary: Dictionary = _run_controller.get_current_run_summary()
	var hero_data: Dictionary = summary.get("hero", {})
	var training_counts: Dictionary = hero_data.get("training_counts", {})
	var attr_names: Array[String] = ["vit", "str", "agi", "tec", "mnd"]
	for i in range(5):
		var count: int = training_counts.get(attr_names[i], 0)
		var level: int = (count / 5) + 1
		training_lv_labels[i].text = "LV:%d" % level


func _show_option_container() -> void:
	## 恢复显示主选项按钮
	training_panel.visible = false
	option_container.visible = true


# --- EventBus 信号处理 ---

func _on_run_started(run_config: Dictionary) -> void:
	_update_hud()
	print("[RunMain] Run started with hero_id=%d, partners=%s" % [
		run_config.get("hero_id", 0),
		run_config.get("partner_ids", [])
	])


func _on_node_options_presented(node_options: Array[Dictionary]) -> void:
	# 设置节点选项按钮文本和可见性
	_show_option_container()
	for i in range(option_buttons.size()):
		if i < node_options.size():
			var opt: Dictionary = node_options[i]
			var node_name: String = opt.get("node_name", "未知节点")
			var desc: String = opt.get("description", "")
			option_buttons[i].text = "%s\n%s" % [node_name, desc] if not desc.is_empty() else node_name
			option_buttons[i].visible = true
			option_buttons[i].disabled = false
		else:
			option_buttons[i].visible = false
			option_buttons[i].disabled = true


func _on_panel_opened(panel_name: String, panel_data: Dictionary) -> void:
	match panel_name:
		"TRAINING_PANEL":
			_show_training_panel()
		"SHOP_PANEL":
			pass  # TODO: 实现商店面板
		"RESCUE_PANEL":
			pass  # TODO: 实现救援面板


func _on_panel_closed(panel_name: String, close_reason: String) -> void:
	_show_option_container()


func _on_training_completed(attr_code: int, attr_name: String, gain_value: int, new_total: int, proficiency_stage: String, bonus_applied: int) -> void:
	_update_hud()
	print("[RunMain] 训练完成: %s +%d (当前%d, %s, 伙伴加成%d)" % [attr_name, gain_value, new_total, proficiency_stage, bonus_applied])


func _on_floor_advanced(new_floor: int, floor_type: String, is_special: bool) -> void:
	# 楼层推进后清空按钮（等待下一轮选项）
	for btn in option_buttons:
		btn.text = "..."
		btn.disabled = true


func _on_gold_changed(new_amount: int, delta: int, _reason: String) -> void:
	gold_label.text = "金币: %d" % new_amount


func _on_stats_changed(_unit_id: String, stat_changes: Dictionary) -> void:
	for attr_code in stat_changes.keys():
		var change: Dictionary = stat_changes[attr_code]
		var code: int = int(attr_code)
		match code:
			0:  # HP
				var new_hp: int = change.get("new", 0)
				var max_hp: int = 100
				hp_label.text = "生命: %d/%d" % [new_hp, max_hp]
			1, 2, 3, 4, 5:
				var bar_index: int = code - 1
				if bar_index >= 0 and bar_index < attr_bars.size():
					attr_bars[bar_index].value = float(change.get("new", 0))


func _on_pvp_result(result: Dictionary) -> void:
	var penalty_tier: String = result.get("penalty_tier", "none")
	var penalty_value: int = result.get("penalty_value", 0)
	if penalty_tier != "none" and penalty_value > 0:
		var won: bool = result.get("won", false)
		var log_msg: String = "PVP %s" % ("胜利" if won else "失败")
		if not won:
			log_msg += "，受到 %s 惩罚 %d" % [penalty_tier, penalty_value]
		print("[RunMain HUD] %s" % log_msg)


func _on_floor_changed(current_floor: int, max_floor: int, floor_type: String) -> void:
	floor_label.text = "层数: %d/%d" % [current_floor, max_floor]
	print("[RunMain HUD] 楼层 %d/%d，类型: %s" % [current_floor, max_floor, floor_type])
