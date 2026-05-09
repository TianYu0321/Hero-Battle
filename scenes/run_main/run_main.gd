class_name RunMain
extends Control

@onready var round_label: Label = $HudContainer/RoundLabel
@onready var gold_label: Label = $HudContainer/GoldLabel
@onready var hp_label: Label = $HudContainer/HpLabel

@onready var attr_bars: Array[ProgressBar] = [
	$HudContainer/AttrBar1,
	$HudContainer/AttrBar2,
	$HudContainer/AttrBar3,
	$HudContainer/AttrBar4,
	$HudContainer/AttrBar5,
]

@onready var node_buttons: Array[Button] = [
	$NodeSelectContainer/NodeButton1,
	$NodeSelectContainer/NodeButton2,
	$NodeSelectContainer/NodeButton3,
]

@onready var partner_slots: Array[ColorRect] = [
	$PartnerContainer/PartnerSlot1,
	$PartnerContainer/PartnerSlot2,
	$PartnerContainer/PartnerSlot3,
	$PartnerContainer/PartnerSlot4,
	$PartnerContainer/PartnerSlot5,
]

var _run_controller: RunController = null


func _ready() -> void:
	# --- 按钮点击绑定 ---
	for i in range(node_buttons.size()):
		node_buttons[i].pressed.connect(_on_node_button_pressed.bind(i))

	# --- EventBus 信号订阅（必须在 RunController 启动前连接，否则首回合信号会丢失） ---
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.pvp_result.connect(_on_pvp_result)
	EventBus.round_changed.connect(_on_round_changed)
	EventBus.node_options_presented.connect(_on_node_options_presented)
	EventBus.run_started.connect(_on_run_started)
	EventBus.turn_advanced.connect(_on_turn_advanced)

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

	round_label.text = "回合: %d/30" % current_turn
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
	if _run_controller != null:
		_run_controller.select_node(index)
	else:
		push_warning("[RunMain] RunController not available")


# --- EventBus 信号处理 ---

func _on_run_started(run_config: Dictionary) -> void:
	# 初始化 HUD 显示
	_update_hud()
	print("[RunMain] Run started with hero_id=%d, partners=%s" % [
		run_config.get("hero_id", 0),
		run_config.get("partner_ids", [])
	])


func _on_node_options_presented(node_options: Array[Dictionary]) -> void:
	# 设置节点选项按钮文本和可见性
	for i in range(node_buttons.size()):
		if i < node_options.size():
			var opt: Dictionary = node_options[i]
			var node_name: String = opt.get("node_name", "未知节点")
			var desc: String = opt.get("description", "")
			node_buttons[i].text = "%s\n%s" % [node_name, desc] if not desc.is_empty() else node_name
			node_buttons[i].visible = true
			node_buttons[i].disabled = false
		else:
			node_buttons[i].visible = false
			node_buttons[i].disabled = true


func _on_turn_advanced(new_turn: int, phase: String, _is_fixed_node: bool) -> void:
	# 回合推进后清空按钮（等待下一轮选项）
	for btn in node_buttons:
		btn.text = "..."
		btn.disabled = true


func _on_gold_changed(new_amount: int, delta: int, _reason: String) -> void:
	gold_label.text = "金币: %d" % new_amount
	# 可以在这里添加金币变化动画效果（Phase 4）


func _on_stats_changed(_unit_id: String, stat_changes: Dictionary) -> void:
	# stat_changes: {attr_code: {old, new, delta, attr_code}}
	# attr_code: 1=体魄, 2=力量, 3=敏捷, 4=技巧, 5=精神
	# attr_code 0 = HP（PVP惩罚等）
	for attr_code in stat_changes.keys():
		var change: Dictionary = stat_changes[attr_code]
		var code: int = int(attr_code)
		match code:
			0:  # HP
				var new_hp: int = change.get("new", 0)
				var max_hp: int = 100  # HUD暂时使用固定最大值，实际应从RunController获取
				hp_label.text = "生命: %d/%d" % [new_hp, max_hp]
			1, 2, 3, 4, 5:
				var bar_index: int = code - 1
				if bar_index >= 0 and bar_index < attr_bars.size():
					attr_bars[bar_index].value = float(change.get("new", 0))


func _on_pvp_result(result: Dictionary) -> void:
	# PVP结束后刷新金币/生命显示
	var penalty_tier: String = result.get("penalty_tier", "none")
	var penalty_value: int = result.get("penalty_value", 0)
	if penalty_tier != "none" and penalty_value > 0:
		var won: bool = result.get("won", false)
		var log_msg: String = "PVP %s" % ("胜利" if won else "失败")
		if not won:
			log_msg += "，受到 %s 惩罚 %d" % [penalty_tier, penalty_value]
		print("[RunMain HUD] %s" % log_msg)


func _on_round_changed(current_round: int, max_round: int, phase: String) -> void:
	round_label.text = "回合: %d/%d" % [current_round, max_round]
	print("[RunMain HUD] 回合 %d/%d，阶段: %s" % [current_round, max_round, phase])
