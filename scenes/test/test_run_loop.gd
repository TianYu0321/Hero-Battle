## res://scenes/test/test_run_loop.gd
## 模块: TestRunLoop
## 职责: 任务5养成循环测试场景
## 依赖: RunController

extends Control

@onready var _btn_start: Button = $VBoxContainer/BtnStart
@onready var _btn_advance: Button = $VBoxContainer/BtnAdvance
@onready var _btn_train_vit: Button = $VBoxContainer/HBoxContainer/BtnTrainVit
@onready var _btn_train_str: Button = $VBoxContainer/HBoxContainer/BtnTrainStr
@onready var _btn_train_agi: Button = $VBoxContainer/HBoxContainer/BtnTrainAgi
@onready var _btn_train_tec: Button = $VBoxContainer/HBoxContainer/BtnTrainTec
@onready var _btn_train_mnd: Button = $VBoxContainer/HBoxContainer/BtnTrainMnd
@onready var _label_status: Label = $VBoxContainer/LabelStatus
@onready var _label_log: Label = $VBoxContainer/LabelLog

var _run_controller: RunController = null


func _ready() -> void:
	_btn_start.pressed.connect(_on_start)
	_btn_advance.pressed.connect(_on_advance)
	_btn_train_vit.pressed.connect(_on_train.bind(1))
	_btn_train_str.pressed.connect(_on_train.bind(2))
	_btn_train_agi.pressed.connect(_on_train.bind(3))
	_btn_train_tec.pressed.connect(_on_train.bind(4))
	_btn_train_mnd.pressed.connect(_on_train.bind(5))

	_run_controller = RunController.new()
	_run_controller.name = "RunController"
	add_child(_run_controller)

	_update_ui("点击【开始新局】启动测试")

	# Headless 自动运行
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		_on_start()
		for i in range(3):
			await get_tree().process_frame
			var turn: int = _run_controller.get_current_run_summary().get("current_turn", 0)
			if turn in [5, 15, 25]:
				_run_controller.select_rescue_partner(1001)
				await get_tree().process_frame
				_run_controller.close_shop_panel()
				continue
			_on_advance()
		print("test_run_loop headless pass")
		get_tree().quit()


func _on_start() -> void:
	_run_controller.start_new_run(1, [1001, 1002])  # 勇者 + 剑士/斥候
	_update_ui("新局开始")
	_refresh_options()


func _on_advance() -> void:
	if _run_controller._state == RunController.RunState.TURN_ADVANCE:
		_run_controller.advance_turn()
		_update_ui("回合推进")
		_refresh_options()
	elif _run_controller._state == RunController.RunState.RUNNING_NODE_SELECT:
		# 自动选择第一个选项
		_run_controller.select_node(0)
		_update_ui("执行节点")
		_refresh_options()


func _on_train(attr_type: int) -> void:
	if _run_controller._state != RunController.RunState.RUNNING_NODE_SELECT:
		return
	var options: Array[Dictionary] = _run_controller.get_current_node_options()
	for i in range(options.size()):
		if options[i].get("node_type") == 1:  # TRAINING
			_run_controller.select_node(i)
			_update_ui("锻炼属性%d" % attr_type)
			_refresh_options()
			return


func _update_ui(msg: String) -> void:
	var summary: Dictionary = _run_controller.get_current_run_summary()
	if summary.is_empty():
		_label_status.text = msg
		return

	var hero_dict: Dictionary = summary.get("hero", {})
	var turn: int = summary.get("current_turn", 0)
	var gold: int = summary.get("gold", 0)
	var phase: String = summary.get("phase", "")

	var text: String = ""
	text += "回合: %d/30 阶段: %s 金币: %d\n" % [turn, phase, gold]
	text += "体魄:%d 力量:%d 敏捷:%d 技巧:%d 精神:%d\n" % [
		hero_dict.get("current_vit", 0),
		hero_dict.get("current_str", 0),
		hero_dict.get("current_agi", 0),
		hero_dict.get("current_tec", 0),
		hero_dict.get("current_mnd", 0),
	]
	text += "HP: %d/%d  锻炼:%d次\n" % [
		hero_dict.get("current_hp", 0),
		hero_dict.get("max_hp", 0),
		hero_dict.get("total_training_count", 0),
	]
	text += "状态: %s | %s" % [_run_controller._state, msg]
	_label_status.text = text


func _refresh_options() -> void:
	var options: Array[Dictionary] = _run_controller.get_current_node_options()
	var log_text: String = ""
	for i in range(options.size()):
		var opt: Dictionary = options[i]
		log_text += "[%d] %s: %s\n" % [i, opt.get("node_name", ""), opt.get("description", "")]
	_label_log.text = log_text
