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

@onready var enemy_info_panel: Panel = $EnemyInfoPanel
@onready var enemy_name_label: Label = $EnemyInfoPanel/EnemyNameLabel
@onready var enemy_hp_label: Label = $EnemyInfoPanel/EnemyHpLabel
@onready var estimated_loss_label: Label = $EnemyInfoPanel/EstimatedLossLabel

@onready var combat_confirm_panel: CombatConfirmPanel = $CombatConfirmPanel
@onready var battle_animation_panel: BattleAnimationPanel = $BattleAnimationPanel
@onready var option_container: Control = $OptionContainer

var _run_controller: RunController = null
var _combat_selected_index: int = -1
var _is_combat_preview: bool = false


func _ready() -> void:
	# --- CombatConfirmPanel 信号绑定 ---
	combat_confirm_panel.confirmed.connect(_on_combat_confirmed)
	combat_confirm_panel.cancelled.connect(_on_combat_cancelled)
	
	# --- BattleAnimationPanel 信号绑定 ---
	battle_animation_panel.confirmed.connect(_on_battle_animation_finished)
	
	# --- 选项按钮点击绑定 ---
	for i in range(option_buttons.size()):
		option_buttons[i].pressed.connect(_on_node_button_pressed.bind(i))

	# --- EventBus 信号订阅 ---
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.pvp_result.connect(_on_pvp_result)
	EventBus.floor_changed.connect(_on_floor_changed)
	EventBus.round_changed.connect(_on_round_changed)
	EventBus.node_options_presented.connect(_on_node_options_presented)
	EventBus.run_started.connect(_on_run_started)
	EventBus.floor_advanced.connect(_on_floor_advanced)
	EventBus.enemy_encountered.connect(_on_battle_node_entered)

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


# ============================================================================
# 半覆盖模态面板: 只隐藏/恢复 option_container，保留其他UI
# ============================================================================

func _show_modal_panel(panel: Control) -> void:
	print("[RunMain] _show_modal_panel: panel=%s" % panel.name)
	option_container.visible = false
	panel.visible = true
	panel.z_index = 100


func _hide_modal_panel(panel: Control) -> void:
	print("[RunMain] _hide_modal_panel: panel=%s" % panel.name)
	panel.visible = false
	option_container.visible = true


# ============================================================================
# 节点按钮处理: 战斗类型走预览流程，其他直接执行
# ============================================================================

func _on_node_button_pressed(index: int) -> void:
	if _run_controller == null:
		return
	
	var summary: Dictionary = _run_controller.get_current_run_summary()
	var node_options: Array[Dictionary] = summary.get("node_options", [])
	
	if index < 0 or index >= node_options.size():
		return
	
	var selected_node: Dictionary = node_options[index]
	var node_type: int = selected_node.get("node_type", 0)
	
	match node_type:
		NodePoolSystem.NodeType.BATTLE, NodePoolSystem.NodeType.FINAL_BOSS:
			_show_combat_preview(selected_node, index)
		_:
			_run_controller.select_node(index)


func _show_combat_preview(node_data: Dictionary, index: int) -> void:
	_combat_selected_index = index
	_is_combat_preview = true
	
	var enemy_cfg: Dictionary = node_data.get("enemy_config", {})
	var enemy_name: String = enemy_cfg.get("name", "???")
	combat_confirm_panel.set_enemy(enemy_name)
	combat_confirm_panel.visible = true
	option_container.visible = false
	
	print("[RunMain] 战斗预览: %s" % enemy_name)


func _on_combat_confirmed() -> void:
	combat_confirm_panel.visible = false
	_start_full_battle_ui()


func _on_combat_cancelled() -> void:
	combat_confirm_panel.visible = false
	option_container.visible = true
	_is_combat_preview = false
	_combat_selected_index = -1
	print("[RunMain] 取消战斗，恢复选项")


# ============================================================================
# 启动完整战斗UI: 半透明动画面板 + 延迟执行战斗
# ============================================================================

func _start_full_battle_ui() -> void:
	if _run_controller == null or _combat_selected_index < 0:
		return
	
	var summary: Dictionary = _run_controller.get_current_run_summary()
	var node_options: Array[Dictionary] = summary.get("node_options", [])
	if _combat_selected_index >= node_options.size():
		return
	
	var selected_node: Dictionary = node_options[_combat_selected_index]
	var enemy_cfg: Dictionary = selected_node.get("enemy_config", {})
	var hero_data: Dictionary = summary.get("hero", {})
	
	# 启动战斗动画面板
	_show_modal_panel(battle_animation_panel)
	battle_animation_panel.start_battle({
		"enemy_max_hp": enemy_cfg.get("max_hp", 100),
		"enemy_hp": enemy_cfg.get("current_hp", 100),
		"hero_max_hp": hero_data.get("max_hp", 100),
		"hero_hp": hero_data.get("current_hp", 100),
		"hero_name": hero_data.get("name", "英雄"),
		"enemy_name": enemy_cfg.get("name", "敌人"),
	})
	
	# 延迟执行战斗（给面板时间初始化显示，避免第一回合卡住）
	call_deferred("_execute_combat_deferred", _combat_selected_index)
	_combat_selected_index = -1
	_is_combat_preview = false


func _execute_combat_deferred(index: int) -> void:
	_run_controller.select_node(index)


func _on_battle_animation_finished() -> void:
	print("[RunMain] 战斗动画结束，恢复界面")
	_hide_modal_panel(battle_animation_panel)
	battle_animation_panel.reset_panel()


# ============================================================================
# EventBus 信号处理
# ============================================================================

func _on_run_started(run_config: Dictionary) -> void:
	_update_hud()
	print("[RunMain] Run started with hero_id=%d, partners=%s" % [
		run_config.get("hero_id", 0),
		run_config.get("partner_ids", [])
	])


func _on_node_options_presented(node_options: Array[Dictionary]) -> void:
	# 如果战斗动画正在播放，通知它结束
	if battle_animation_panel.visible:
		battle_animation_panel.finish_battle()
	
	# 确保战斗预览状态被重置
	if _is_combat_preview:
		_is_combat_preview = false
		combat_confirm_panel.visible = false
		enemy_info_panel.visible = false
	
	# 确保选项容器可见
	option_container.visible = true
	
	# 设置节点选项按钮文本和可见性
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
	
	# 默认隐藏敌人信息面板
	enemy_info_panel.visible = false


func _on_floor_changed(_current_floor: int, _max_floor: int, _floor_type: String) -> void:
	_update_hud()


func _on_round_changed(current_round: int, max_round: int, phase: String) -> void:
	_update_hud()
	print("[RunMain] Round changed: %d/%d, phase=%s" % [current_round, max_round, phase])


func _on_floor_advanced(new_floor: int, _floor_type: String, _is_special: bool) -> void:
	_update_hud()
	print("[RunMain] Floor advanced to %d" % new_floor)


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


func _on_battle_node_entered(enemy_data: Dictionary) -> void:
	if enemy_data.is_empty():
		enemy_info_panel.visible = false
		return
	
	if _is_combat_preview:
		return
	
	enemy_info_panel.visible = true
	enemy_info_panel.modulate = Color(1, 1, 1, 1)
	enemy_name_label.text = "敌人: %s" % enemy_data.get("enemy_name", "???")
	enemy_hp_label.text = "HP: %d/%d" % [
		enemy_data.get("enemy_hp", 0),
		enemy_data.get("enemy_max_hp", 0)
	]
	var estimated_loss: int = enemy_data.get("estimated_hp_loss", 0)
	estimated_loss_label.text = "预计损失: %d" % estimated_loss
	print("[RunMain] Battle node entered: %s" % enemy_data.get("enemy_name", "???"))
