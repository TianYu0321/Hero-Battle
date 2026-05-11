extends Control

const SCREEN_DIR := "res://Screen/"
var run_main: Control = null

func _ready():
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("Screen"):
		dir.make_dir("Screen")
	
	run_main = $RunMain
	
	# 等待游戏初始化完成
	await get_tree().create_timer(3.0).timeout
	await _capture("01_initial")
	
	# 第1层：点击训练按钮（第1个选项）
	await _click_option_and_wait(0, 1.5)
	await _capture("02_training_panel")
	
	# 点击第一个训练属性
	_click_training_attr(0)
	await get_tree().create_timer(2.5).timeout
	await _capture("03_training_complete")
	
	# 等待回到选项
	await get_tree().create_timer(2.0).timeout
	await _capture("04_options_turn2")
	
	# 第2层：点击战斗按钮（第2个选项）
	await _click_option_and_wait(1, 1.0)
	
	# 等待战斗结束
	await get_tree().create_timer(8.0).timeout
	await _capture("05_battle_result")
	
	_click_battle_confirm()
	await get_tree().create_timer(2.5).timeout
	await _capture("06_after_battle")
	
	# 第3层：点击休息按钮（第3个选项）
	await get_tree().create_timer(2.0).timeout
	await _capture("07_options_turn3")
	await _click_option_and_wait(2, 4.0)
	await _capture("08_after_rest")
	
	# 第4层：点击外出按钮（第4个选项）
	await get_tree().create_timer(2.0).timeout
	await _capture("09_options_turn4")
	await _click_option_and_wait(3, 4.0)
	await _capture("10_after_outing")
	
	# 第5层：救援层（自动弹出救援面板）
	await get_tree().create_timer(4.0).timeout
	await _capture("11_rescue_panel")
	
	_click_rescue_candidate(0)
	await get_tree().create_timer(2.5).timeout
	await _capture("12_shop_panel")
	
	_click_shop_close()
	await get_tree().create_timer(2.5).timeout
	await _capture("13_after_shop")
	
	print("=== 自动截图序列完成 ===")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func _click_option_and_wait(button_index: int, wait_time: float):
	var buttons = _get_option_buttons()
	if button_index < buttons.size():
		var btn = buttons[button_index]
		if btn.visible and not btn.disabled:
			btn.pressed.emit()
			print("[AutoScreenshot] 点击选项按钮: index=" + str(button_index))
		else:
			print("[AutoScreenshot] 选项按钮不可用: index=" + str(button_index))
	else:
		print("[AutoScreenshot] 选项按钮不存在: index=" + str(button_index))
	await get_tree().create_timer(wait_time).timeout

func _get_option_buttons() -> Array:
	var container = run_main.get_node_or_null("OptionContainer")
	if container:
		return container.get_children()
	return []

func _click_training_attr(index: int):
	var rows = [
		"TrainingPanel/AttrRow1/SelectBtn",
		"TrainingPanel/AttrRow2/SelectBtn",
		"TrainingPanel/AttrRow3/SelectBtn",
		"TrainingPanel/AttrRow4/SelectBtn",
		"TrainingPanel/AttrRow5/SelectBtn",
	]
	if index < rows.size():
		var btn = run_main.get_node_or_null(rows[index])
		if btn:
			btn.pressed.emit()
			print("[AutoScreenshot] 点击训练属性: index=" + str(index))

func _click_battle_confirm():
	var panel = run_main.get_node_or_null("BattleSummaryPanel")
	if panel:
		var btn = panel.get_node_or_null("ConfirmButton")
		if btn:
			btn.pressed.emit()
			print("[AutoScreenshot] 点击战斗确认")

func _click_rescue_candidate(index: int):
	var panel = run_main.get_node_or_null("RescuePanel")
	if panel:
		var names = ["CandidateBtn1", "CandidateBtn2", "CandidateBtn3"]
		if index < names.size():
			var btn = panel.get_node_or_null(names[index])
			if btn:
				btn.pressed.emit()
				print("[AutoScreenshot] 点击救援候选: index=" + str(index))

func _click_shop_close():
	var panel = run_main.get_node_or_null("ShopPanel/ContentVBox")
	if panel:
		var btn = panel.get_node_or_null("CloseButton")
		if btn:
			btn.pressed.emit()
			print("[AutoScreenshot] 点击商店关闭")

func _capture(name: String):
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var path = SCREEN_DIR + name + ".png"
	var err = img.save_png(path)
	if err == OK:
		print("[AutoScreenshot] 截图已保存: " + path)
	else:
		print("[AutoScreenshot] 截图保存失败: " + path + " 错误码=" + str(err))
