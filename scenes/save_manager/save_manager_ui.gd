extends Control

signal slot_loaded(slot_id: int)
signal back_requested

@onready var slot_grid: HBoxContainer = $MainPanel/VBoxContainer/SlotGrid
@onready var back_btn: Button = $MainPanel/VBoxContainer/BottomBar/BackButton
@onready var confirm_dialog: AcceptDialog = $ConfirmDialog

var _slot_cards: Array[PanelContainer] = []
var _slot_infos: Array[Dictionary] = []
var _pending_action: String = ""    # "overwrite" / "delete"
var _pending_slot: int = 0

func _ready() -> void:
	_setup_styles()
	_build_slot_cards()
	_refresh_slots()
	back_btn.pressed.connect(_on_back)

func _setup_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.98, 0.98, 0.96, 1.0)
	panel_style.border_color = Color(0.8, 0.8, 0.82, 1.0)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 4
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.shadow_color = Color(0, 0, 0, 0.12)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 4)
	$MainPanel.add_theme_stylebox_override("panel", panel_style)

func _build_slot_cards() -> void:
	for i in range(3):
		var card := _create_slot_card(i + 1)
		slot_grid.add_child(card)
		_slot_cards.append(card)

func _create_slot_card(slot_id: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 320)
	card.name = "SlotCard%d" % slot_id
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	style.border_color = Color(0.75, 0.75, 0.78, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 3
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.06)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	card.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)
	
	## 槽位号
	var num_label := Label.new()
	num_label.name = "SlotNumber"
	num_label.text = "槽位 %d" % slot_id
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.add_theme_font_size_override("font_size", 18)
	num_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.48, 1))
	vbox.add_child(num_label)
	
	## 主角图标占位
	var icon := TextureRect.new()
	icon.name = "HeroIcon"
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon)
	
	## 信息区
	var info_vbox := VBoxContainer.new()
	info_vbox.name = "InfoVBox"
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(info_vbox)
	
	var hero_name := Label.new()
	hero_name.name = "HeroName"
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_name.add_theme_font_size_override("font_size", 16)
	hero_name.add_theme_color_override("font_color", Color(0.25, 0.25, 0.28, 1))
	info_vbox.add_child(hero_name)
	
	var floor_label := Label.new()
	floor_label.name = "FloorLabel"
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_label.add_theme_font_size_override("font_size", 13)
	floor_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58, 1))
	info_vbox.add_child(floor_label)
	
	var time_label := Label.new()
	time_label.name = "TimeLabel"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 11)
	time_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.68, 1))
	info_vbox.add_child(time_label)
	
	var auto_label := Label.new()
	auto_label.name = "AutoLabel"
	auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_label.add_theme_font_size_override("font_size", 11)
	info_vbox.add_child(auto_label)
	
	## 操作按钮区
	var action_vbox := VBoxContainer.new()
	action_vbox.name = "ActionVBox"
	action_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(action_vbox)
	
	var save_btn := Button.new()
	save_btn.name = "SaveBtn"
	save_btn.custom_minimum_size = Vector2(120, 36)
	save_btn.pressed.connect(_on_slot_save.bind(slot_id))
	action_vbox.add_child(save_btn)
	
	var load_btn := Button.new()
	load_btn.name = "LoadBtn"
	load_btn.text = "读取"
	load_btn.custom_minimum_size = Vector2(120, 36)
	load_btn.visible = false
	load_btn.pressed.connect(_on_slot_load.bind(slot_id))
	action_vbox.add_child(load_btn)
	
	var delete_btn := Button.new()
	delete_btn.name = "DeleteBtn"
	delete_btn.text = "删除"
	delete_btn.custom_minimum_size = Vector2(120, 36)
	delete_btn.visible = false
	delete_btn.pressed.connect(_on_slot_delete.bind(slot_id))
	action_vbox.add_child(delete_btn)
	
	return card

func _refresh_slots() -> void:
	_slot_infos = SaveManager.get_all_slots_info()
	
	for i in range(3):
		var info: Dictionary = _slot_infos[i]
		var card: PanelContainer = _slot_cards[i]
		var has_data: bool = info.get("has_data", false)
		
		var hero_name: Label = card.get_node("VBoxContainer/InfoVBox/HeroName")
		var floor_label: Label = card.get_node("VBoxContainer/InfoVBox/FloorLabel")
		var time_label: Label = card.get_node("VBoxContainer/InfoVBox/TimeLabel")
		var auto_label: Label = card.get_node("VBoxContainer/InfoVBox/AutoLabel")
		var save_btn: Button = card.get_node("VBoxContainer/ActionVBox/SaveBtn")
		var load_btn: Button = card.get_node("VBoxContainer/ActionVBox/LoadBtn")
		var delete_btn: Button = card.get_node("VBoxContainer/ActionVBox/DeleteBtn")
		
		## 高亮活跃槽位
		var is_active: bool = info.get("is_active", false)
		var card_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
		if is_active:
			card_style.border_color = Color(0.25, 0.55, 0.9, 0.6)
			card_style.border_width_bottom = 4
		card.add_theme_stylebox_override("panel", card_style)
		
		if has_data:
			hero_name.text = info.get("hero_name", "???")
			floor_label.text = "第%d层" % info.get("floor", 1)
			
			var timestamp: int = info.get("timestamp", 0)
			if timestamp > 0:
				var dt := Time.get_datetime_dict_from_unix_time(timestamp)
				time_label.text = "%02d-%02d %02d:%02d" % [dt.month, dt.day, dt.hour, dt.minute]
			else:
				time_label.text = "未知时间"
			
			if info.get("is_auto_save", false):
				auto_label.text = "自动保存"
				auto_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58, 1))
			else:
				auto_label.text = "手动保存"
				auto_label.add_theme_color_override("font_color", Color(0.25, 0.55, 0.9, 1))
			
			## 按钮
			save_btn.text = "覆盖保存"
			_apply_button_style(save_btn, true)
			load_btn.visible = true
			_apply_button_style(load_btn, true)
			delete_btn.visible = true
			_apply_button_style(delete_btn, false)
		else:
			hero_name.text = ""
			floor_label.text = ""
			time_label.text = ""
			auto_label.text = ""
			
			save_btn.text = "新建存档"
			_apply_button_style(save_btn, true)
			load_btn.visible = false
			delete_btn.visible = false

func _apply_button_style(btn: Button, primary: bool) -> void:
	var style := StyleBoxFlat.new()
	if primary:
		style.bg_color = Color(0.25, 0.55, 0.9, 1.0)
	else:
		style.bg_color = Color(0.92, 0.92, 0.94, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.WHITE if primary else Color(0.35, 0.35, 0.38, 1))

## ========== 槽位操作 ==========

func _on_slot_save(slot_id: int) -> void:
	if SaveManager.slot_has_data(slot_id):
		## 覆盖确认
		_pending_action = "overwrite"
		_pending_slot = slot_id
		confirm_dialog.title = "覆盖存档"
		confirm_dialog.dialog_text = "槽位 %d 已有存档，确定要覆盖吗？" % slot_id
		confirm_dialog.ok_button_text = "覆盖"
		confirm_dialog.cancel_button_text = "取消"
		if not confirm_dialog.confirmed.is_connected(_on_confirm_action):
			confirm_dialog.confirmed.connect(_on_confirm_action, CONNECT_ONE_SHOT)
		confirm_dialog.popup_centered()
	else:
		## 新建存档
		_perform_save(slot_id)

func _on_slot_load(slot_id: int) -> void:
	var data: Dictionary = SaveManager.load_from_slot(slot_id)
	if not data.is_empty():
		print("[SaveManagerUI] 从槽位 %d 加载存档" % slot_id)
		slot_loaded.emit(slot_id)
		## 通过 EventBus 走现有继续游戏流程
		EventBus.continue_game_requested.emit()
	else:
		push_error("[SaveManagerUI] 槽位 %d 加载失败" % slot_id)

func _on_slot_delete(slot_id: int) -> void:
	_pending_action = "delete"
	_pending_slot = slot_id
	confirm_dialog.title = "删除存档"
	confirm_dialog.dialog_text = "确定要删除槽位 %d 的存档吗？此操作不可恢复。" % slot_id
	confirm_dialog.ok_button_text = "删除"
	confirm_dialog.cancel_button_text = "取消"
	if not confirm_dialog.confirmed.is_connected(_on_confirm_action):
		confirm_dialog.confirmed.connect(_on_confirm_action, CONNECT_ONE_SHOT)
	confirm_dialog.popup_centered()

func _on_confirm_action() -> void:
	match _pending_action:
		"overwrite":
			_perform_save(_pending_slot)
		"delete":
			SaveManager.delete_slot(_pending_slot)
			_refresh_slots()
			AudioManager.play_ui("cancel")
	_pending_action = ""

func _perform_save(slot_id: int) -> void:
	## 获取当前RUN数据
	var run_data: Dictionary = {}
	var run_controller = get_tree().root.get_node_or_null("RunMain/RunController")
	if run_controller != null and run_controller.has_method("get_run_data"):
		run_data = run_controller.get_run_data()
	else:
		## 尝试从 GameManager 获取
		run_data = GameManager.pending_save_data.duplicate() if not GameManager.pending_save_data.is_empty() else {}
	
	if run_data.is_empty():
		push_warning("[SaveManagerUI] 没有可保存的RUN数据")
		return
	
	SaveManager.save_to_slot(slot_id, run_data, false)  ## 手动保存
	_refresh_slots()
	AudioManager.play_ui("success")
	
	## 保存成功提示
	_show_toast("已保存到槽位 %d" % slot_id)

func _show_toast(text: String) -> void:
	var panel := PanelContainer.new()
	panel.z_index = 300
	panel.position = Vector2(440, 260)
	panel.custom_minimum_size = Vector2(240, 60)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.7, 0.4, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	
	add_child(panel)
	
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.8).set_delay(0.5)
	tween.finished.connect(func(): panel.queue_free())

func _on_back() -> void:
	AudioManager.play_ui("cancel")
	back_requested.emit()
	queue_free()
