class_name RunMain
extends Control


@onready var floor_label: Label = $HudContainer/FloorLabel
@onready var gold_label: Label = $HudContainer/GoldLabel
@onready var hp_label: Label = $HudContainer/HpLabel

@onready var player_vit_label: Label = $PlayerInfoPanel/PlayerVitLabel
@onready var player_str_label: Label = $PlayerInfoPanel/PlayerStrLabel
@onready var player_agi_label: Label = $PlayerInfoPanel/PlayerAgiLabel
@onready var player_tec_label: Label = $PlayerInfoPanel/PlayerTecLabel
@onready var player_mnd_label: Label = $PlayerInfoPanel/PlayerMndLabel

@onready var option_buttons: Array[Button] = [
	$OptionContainer/TrainButton,
	$OptionContainer/BattleButton,
	$OptionContainer/RestButton,
	$OptionContainer/OutingButton,
]

@onready var training_panel: VBoxContainer = $TrainingPanel
@onready var option_container: VBoxContainer = $OptionContainer
@onready var shop_panel: Panel = $ShopPanel
@onready var shop_item_container: VBoxContainer = $ShopPanel/ContentVBox/Scroll/ShopItemContainer
@onready var shop_gold_label: Label = $ShopPanel/ContentVBox/GoldDisplayLabel
@onready var battle_summary_panel = $BattleSummaryPanel
@onready var battle_animation_panel: BattleAnimationPanel = $BattleAnimationPanel
@onready var ui_modal_blocker: ColorRect = $UIModalBlocker

@onready var rescue_panel: Control = $RescuePanel
@onready var rescue_candidate_buttons: Array[Button] = [
	$RescuePanel/CandidateBtn1,
	$RescuePanel/CandidateBtn2,
	$RescuePanel/CandidateBtn3,
]
@onready var rescue_candidate_labels: Array[Label] = [
	$RescuePanel/CandidateBtn1/Label,
	$RescuePanel/CandidateBtn2/Label,
	$RescuePanel/CandidateBtn3/Label,
]

@onready var pause_menu: PauseMenu = $PauseMenu
@onready var menu_button: Button = $MenuButton

@onready var enemy_info_panel: VBoxContainer = $EnemyInfoPanel
@onready var enemy_name_label: Label = $EnemyInfoPanel/EnemyNameLabel
@onready var enemy_hp_label: Label = $EnemyInfoPanel/EnemyHpLabel
@onready var predicted_damage_label: Label = $EnemyInfoPanel/EstimatedDamageLabel
@onready var risk_label: Label = $EnemyInfoPanel/RiskLabel

@onready var combat_confirm_panel: Panel = $CombatConfirmPanel
@onready var enter_combat_button: Button = $CombatConfirmPanel/EnterCombatButton
@onready var return_button: Button = $CombatConfirmPanel/ReturnButton

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
var _last_rescue_candidates: Array = []
var _shop_item_buttons: Array = []
var _selected_rescue_partner_id: int = -1
var _combat_selected_index: int = -1
var _pending_battle_result: Dictionary = {}
var _cached_node_options: Array = []
var _cached_enemy_data: Dictionary = {}

enum UISceneState {
	LOADING,		   # 什么都不显示，等待初始化
	OPTION_SELECT,	 # 显示4个选项按钮
	TRAINING_SELECT,   # 显示训练属性面板
	RESCUE_SELECT,	 # 显示3个候选伙伴
	SHOP_BROWSE,	   # 显示商店（后续实现）
	EVENT_RESULT,	  # 显示外出事件结果
	BATTLE_PREVIEW,	# 显示敌人信息+战斗按钮
}

var _current_ui_state: UISceneState = UISceneState.LOADING


func _process(_delta: float) -> void:
	# 安全检测：UIModalBlocker 不应该在没有任何面板打开时保持 visible
	if ui_modal_blocker.visible:
		var any_modal_visible: bool = shop_panel.visible or battle_summary_panel.visible or rescue_panel.visible or training_panel.visible or combat_confirm_panel.visible
		if not any_modal_visible:
			print("[RunMain] 安全检测：UIModalBlocker 异常可见，自动隐藏")
			ui_modal_blocker.visible = false
			# 同时恢复选项状态
			if _current_ui_state == UISceneState.LOADING:
				_transition_ui_state(UISceneState.OPTION_SELECT)


func _ready() -> void:
	print("[RunMain] _ready 开始")
	# --- 按钮点击绑定 ---
	for i in range(option_buttons.size()):
		option_buttons[i].pressed.connect(_on_node_button_pressed.bind(i))

	# 训练属性选择按钮绑定
	for i in range(training_select_buttons.size()):
		training_select_buttons[i].pressed.connect(_on_training_attr_selected.bind(i + 1))

	# --- CombatConfirmPanel 按钮绑定 ---
	enter_combat_button.pressed.connect(_on_combat_confirmed)
	return_button.pressed.connect(_on_combat_cancelled)

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
	EventBus.enemy_encountered.connect(_on_enemy_encountered)
	EventBus.node_resolved.connect(_on_node_resolved)
	EventBus.battle_ended.connect(_on_battle_ended)

	# --- 暂停菜单信号 ---
	pause_menu.resume_requested.connect(_on_resume_game)
	pause_menu.main_menu_requested.connect(_on_return_main_menu)

	# --- 菜单按钮 ---
	menu_button.pressed.connect(_on_menu_button_pressed)

	# --- 救援面板按钮绑定 ---
	for i in range(rescue_candidate_buttons.size()):
		rescue_candidate_buttons[i].pressed.connect(_on_rescue_partner_selected.bind(i))
	
	# --- 商店关闭按钮 ---
	var shop_close_button: Button = $ShopPanel/ContentVBox/CloseButton
	shop_close_button.pressed.connect(_on_shop_close_pressed)

	# --- 实例化并启动 RunController ---
	_run_controller = RunController.new()
	_run_controller.name = "RunController"
	add_child(_run_controller)

	# 检查是否有待加载的存档（继续游戏）
	var pending_save: Dictionary = GameManager.pending_save_data
	if not pending_save.is_empty():
		print("[RunMain] 检测到待恢复存档")
		var success = _run_controller.continue_from_save(pending_save)
		if success:
			GameManager.pending_save_data = {}
			_update_hud()
			# 不要在这里手动调用 _show_option_container()
			# 让 _change_state -> _generate_node_options -> node_options_presented 信号来驱动UI显示
			return
		else:
			print("[RunMain] 存档恢复失败，返回主菜单")
			GameManager.pending_save_data = {}
			get_tree().change_scene_to_file("res://scenes/main_menu/menu.tscn")
			return

	# 正常新开局，确保清空残留存档数据
	GameManager.pending_save_data = {}
	var hero_config_id: int = GameManager.selected_hero_config_id
	var partner_config_ids: Array[int] = GameManager.selected_partner_config_ids.duplicate()

	if hero_config_id <= 0:
		push_error("[RunMain] No hero selected, cannot start run")
		return

	_run_controller.start_new_run(hero_config_id, partner_config_ids)


func _transition_ui_state(new_state: UISceneState) -> void:
	print("[RunMain] UI状态: %s → %s" % [_get_ui_state_name(_current_ui_state), _get_ui_state_name(new_state)])
	_current_ui_state = new_state
	
	# 先全部隐藏
	option_container.visible = false
	training_panel.visible = false
	rescue_panel.visible = false
	shop_panel.visible = false
	enemy_info_panel.visible = false
	
	# 再按需显示
	match new_state:
		UISceneState.OPTION_SELECT:
			option_container.visible = true
		UISceneState.TRAINING_SELECT:
			training_panel.visible = true
		UISceneState.RESCUE_SELECT:
			rescue_panel.visible = true
		UISceneState.SHOP_BROWSE:
			shop_panel.visible = true
		UISceneState.BATTLE_PREVIEW:
			pass  # TODO


func _get_ui_state_name(state: UISceneState) -> String:
	match state:
		UISceneState.LOADING: return "LOADING"
		UISceneState.OPTION_SELECT: return "OPTION_SELECT"
		UISceneState.TRAINING_SELECT: return "TRAINING_SELECT"
		UISceneState.RESCUE_SELECT: return "RESCUE_SELECT"
		UISceneState.SHOP_BROWSE: return "SHOP_BROWSE"
		UISceneState.EVENT_RESULT: return "EVENT_RESULT"
		UISceneState.BATTLE_PREVIEW: return "BATTLE_PREVIEW"
		_: return "UNKNOWN"


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

	player_vit_label.text = "体魄: %d" % hero_data.get("current_vit", 0)
	player_str_label.text = "力量: %d" % hero_data.get("current_str", 0)
	player_agi_label.text = "敏捷: %d" % hero_data.get("current_agi", 0)
	player_tec_label.text = "技巧: %d" % hero_data.get("current_tec", 0)
	player_mnd_label.text = "精神: %d" % hero_data.get("current_mnd", 0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[RunMain] 全局点击检测: pos=%s, blocker=%s, shop=%s, option=%s" % [
			event.position,
			ui_modal_blocker.visible,
			shop_panel.visible,
			option_container.visible
		])
	if event.is_action_pressed("ui_cancel"):
		if pause_menu.visible:
			pause_menu.hide_menu()
		else:
			pause_menu.show_menu()

func _on_node_button_pressed(index: int) -> void:
	AudioManager.play_ui("button_click")
	print("[RunMain] 按钮被点击: index=%d, RunController=%s" % [index, _run_controller != null])
	if _run_controller == null:
		push_warning("[RunMain] RunController not available")
		return
	
	var summary: Dictionary = _run_controller.get_current_run_summary()
	var node_options: Array = summary.get("node_options", [])
	
	if index < 0 or index >= node_options.size():
		return
	
	var opt: Dictionary = node_options[index]
	var node_type: int = opt.get("node_type", 0)
	
	if node_type == NodePoolSystem.NodeType.BATTLE:
		# 战斗选项特殊处理：先显示预览
		_show_combat_preview(opt, index)
	else:
		# 其他选项直接执行
		_run_controller.select_node(index)


func _show_combat_preview(opt: Dictionary, index: int) -> void:
	_combat_selected_index = index
	
	# 隐藏4选项
	option_container.visible = false
	
	# 显示敌人剪影预览（半透明）
	var enemy_cfg: Dictionary = opt.get("enemy_config", {})
	if enemy_cfg.is_empty() and not _cached_enemy_data.is_empty():
		enemy_cfg = _cached_enemy_data
	
	if not enemy_cfg.is_empty():
		enemy_info_panel.visible = true
		enemy_info_panel.modulate = Color(1, 1, 1, 0.6)  # 半透明
		## 复用 update_enemy_info 显示基础信息
		update_enemy_info(enemy_cfg)
		## 剪影模式：隐藏具体 HP，显示 ???
		enemy_hp_label.text = "HP: ???"
		predicted_damage_label.text = ""
		
		## 补充风险预测
		var hero_stats: Dictionary = _get_current_hero_stats()
		var prediction: Dictionary = DamagePredictor.predict_battle_outcome(
			_get_current_hero_hp(), hero_stats, enemy_cfg
		)
		var risk: String = prediction.get("risk_level", "unknown")
		risk_label.text = DamagePredictor.get_risk_display_text(risk)
		risk_label.modulate = DamagePredictor.get_risk_color(risk)
	else:
		enemy_info_panel.visible = false
	
	# 显示确认按钮（进入战斗 / 返回）
	combat_confirm_panel.visible = true
	print("[RunMain] summary_panel.visible=%s" % battle_summary_panel.visible)
	print("[RunMain] animation_panel.visible=%s" % battle_animation_panel.visible)
	print("[RunMain] 战斗预览: %s" % enemy_cfg.get("name", "???"))


func _on_combat_confirmed() -> void:
	AudioManager.play_ui("confirm")
	# 隐藏预览
	combat_confirm_panel.visible = false
	enemy_info_panel.visible = false
	battle_summary_panel.visible = false  # 确保结算面板隐藏
	
	# 执行战斗（战斗面板由 _on_battle_ended 统一打开）
	if _combat_selected_index >= 0:
		_run_controller.select_node(_combat_selected_index)
		_combat_selected_index = -1


func _on_combat_cancelled() -> void:
	AudioManager.play_ui("cancel")
	# 返回，恢复4选项
	combat_confirm_panel.visible = false
	enemy_info_panel.visible = false
	option_container.visible = true
	_combat_selected_index = -1
	_current_ui_state = UISceneState.OPTION_SELECT
	print("[RunMain] 取消战斗，恢复选项")


func _on_training_attr_selected(attr_type: int) -> void:
	AudioManager.play_ui("confirm")
	## 玩家从训练面板选择了具体属性
	if _run_controller != null:
		_run_controller.select_training_attr(attr_type)
	# 训练完成后 RunController 会发射 panel_closed 或 node_options_presented
	# 不要在这里手动切状态，让信号驱动


# --- EventBus 信号处理 ---

func _on_run_started(run_config: Dictionary) -> void:
	_update_hud()
	print("[RunMain] Run started with hero_id=%d, partners=%s" % [
		run_config.get("hero_id", 0),
		run_config.get("partner_ids", [])
	])


func _on_node_options_presented(node_options: Array) -> void:
	print("[RunMain] _on_node_options_presented: 选项数=%d, 当前blocker=%s" % [node_options.size(), ui_modal_blocker.visible])
	
	# 保护：如果战斗动画还在播放，缓存选项但不切换UI状态
	if battle_animation_panel.visible and battle_animation_panel._is_playing:
		print("[RunMain] 动画播放中，缓存 node_options")
		_cached_node_options = node_options.duplicate()
		return
	
	_transition_ui_state(UISceneState.OPTION_SELECT)
	
	# 获取事件透视系统
	var forecast_system: EventForecastSystem = get_node_or_null("RunController/EventForecastSystem")
	
	# 更新按钮内容
	for i in range(option_buttons.size()):
		var btn: Button = option_buttons[i]
		
		# **强制清理按钮上的旧透视标注**
		var old_tag = btn.get_node_or_null("EventTagLabel")
		if old_tag != null:
			old_tag.queue_free()
		
		# 恢复按钮默认颜色
		btn.remove_theme_color_override("font_color")
		
		if i < node_options.size():
			var opt = node_options[i]
			var btn_text: String = opt.get("node_name", "???")
			
			# 检查透视标注
			if forecast_system != null and forecast_system.is_active():
				var node_id: String = opt.get("node_id", "")
				var tag: Dictionary = forecast_system.get_event_tag(node_id)
				if not tag["text"].is_empty():
					_apply_event_tag_style(btn, tag)
			
			btn.text = btn_text
			btn.visible = true
			btn.disabled = false
		else:
			btn.text = ""
			btn.visible = false
			btn.disabled = true
	
	# 强制确保 OptionContainer 和按钮可见且可交互（防御性刷新）
	option_container.visible = true
	for i in range(option_buttons.size()):
		if i < node_options.size():
			var opt = node_options[i]
			option_buttons[i].text = opt.get("node_name", "???")
			option_buttons[i].visible = true
			option_buttons[i].disabled = false
	
	print("[RunMain] 按钮状态: option_container=%s, 按钮1text=%s, 按钮2text=%s, 按钮1disabled=%s, 按钮2disabled=%s" % [
		option_container.visible,
		option_buttons[0].text,
		option_buttons[1].text,
		option_buttons[0].disabled,
		option_buttons[1].disabled
	])
	
	# 默认界面不承载怪物信息，只有点击战斗后 _show_combat_preview 才显示剪影
	enemy_info_panel.visible = false

func _apply_event_tag_style(btn: Button, tag: Dictionary) -> void:
	# 删除已有的标注
	var existing_label = btn.get_node_or_null("EventTagLabel")
	if existing_label != null:
		existing_label.queue_free()
	
	var tag_label := Label.new()
	tag_label.name = "EventTagLabel"
	tag_label.text = tag["text"]
	tag_label.modulate = tag["color"]
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tag_label.position = Vector2(0, btn.size.y - 24)
	tag_label.custom_minimum_size = Vector2(btn.size.x, 24)
	btn.add_child(tag_label)


func _on_panel_opened(panel_name: String, panel_data: Dictionary) -> void:
	print("[RunMain] _on_panel_opened: 面板=%s" % panel_name)
	enemy_info_panel.visible = false
	match panel_name:
		"TRAINING_PANEL":
			_transition_ui_state(UISceneState.TRAINING_SELECT)
			_show_training_panel_details(panel_data)
		"RESCUE_PANEL":
			_transition_ui_state(UISceneState.RESCUE_SELECT)
			_last_rescue_candidates = panel_data.get("candidates", [])
			_show_rescue_panel_details(_last_rescue_candidates)
		"SHOP_PANEL":
			_transition_ui_state(UISceneState.SHOP_BROWSE)
			_show_shop_panel(panel_data.get("items", []))
			_show_modal_panel(shop_panel)


func _on_panel_closed(_panel_name: String, _close_reason: String) -> void:
	# 面板关闭后回到选项状态
	_transition_ui_state(UISceneState.OPTION_SELECT)
	_update_hud()


func _on_training_completed(_attr_code: int, attr_name: String, gain_value: int, new_total: int, proficiency_stage: String, bonus_applied: int) -> void:
	_update_hud()
	print("[RunMain] 训练完成: %s +%d (当前%d, %s, 伙伴加成%d)" % [attr_name, gain_value, new_total, proficiency_stage, bonus_applied])


func _on_floor_advanced(_new_floor: int, _floor_type: String, _is_special: bool) -> void:
	# 楼层推进后仅禁用按钮，不覆盖文本，避免与 node_options_presented 冲突
	for btn in option_buttons:
		btn.disabled = true


func _show_training_panel_details(_panel_data: Dictionary) -> void:
	## 显示训练属性选择面板
	# 更新各属性训练等级显示
	var summary: Dictionary = _run_controller.get_current_run_summary()
	var hero_data: Dictionary = summary.get("hero", {})
	var training_counts: Dictionary = hero_data.get("training_counts", {})
	var attr_names: Array[String] = ["vit", "str", "agi", "tec", "mnd"]
	for i in range(5):
		var count: int = training_counts.get(attr_names[i], 0)
		var level: int = (count / 5) + 1
		training_lv_labels[i].text = "LV:%d" % level


func _show_rescue_panel_details(candidates: Array) -> void:
	_selected_rescue_partner_id = -1
	for i in range(rescue_candidate_buttons.size()):
		if i < candidates.size():
			rescue_candidate_buttons[i].visible = true
			rescue_candidate_buttons[i].modulate = Color(1, 1, 1)
			var candidate = candidates[i]
			rescue_candidate_labels[i].text = "%s\n%s" % [candidate.get("name", "???"), candidate.get("role", "")]
			rescue_candidate_buttons[i].disabled = false
		else:
			rescue_candidate_buttons[i].visible = false
			rescue_candidate_buttons[i].disabled = true

func _on_rescue_partner_selected(index: int) -> void:
	print("[RunMain] _on_rescue_partner_selected 被调用: index=%d, candidates.size=%d" % [index, _last_rescue_candidates.size()])
	if index < _last_rescue_candidates.size():
		var candidate = _last_rescue_candidates[index]
		print("[RunMain] 候选伙伴字典: " + str(candidate))
		var partner_config_id = int(candidate.get("partner_id", 0))
		print("[RunMain] 解析 partner_config_id=%d" % partner_config_id)
		if partner_config_id > 0:
			_selected_rescue_partner_id = partner_config_id
			print("[RunMain] 选择救援伙伴: id=%d" % _selected_rescue_partner_id)
			# 高亮选中的按钮
			for btn in rescue_candidate_buttons:
				btn.modulate = Color(0.5, 0.5, 0.5)
			rescue_candidate_buttons[index].modulate = Color(1, 1, 1)
			_run_controller.select_rescue_partner(partner_config_id)
			# UI状态切换由 RunController 的下一个 panel_opened 信号驱动
		else:
			print("[RunMain] 警告: partner_config_id <= 0，不调用 select_rescue_partner")
	else:
		print("[RunMain] 警告: index >= candidates.size，忽略点击")

func _on_shop_close_pressed() -> void:
	print("[RunMain] 商店关闭")
	_hide_modal_panel(shop_panel)
	if _run_controller != null:
		_run_controller.close_shop_panel()


func _show_shop_panel(items: Array) -> void:
	# 清空旧按钮
	for btn in _shop_item_buttons:
		btn.queue_free()
	_shop_item_buttons.clear()
	
	# 刷新金币显示
	var summary = _run_controller.get_current_run_summary()
	var gold = summary.get("gold", 0)
	shop_gold_label.text = "持有金币: %d" % gold
	
	# 只生成伙伴升级按钮
	for item in items:
		if item.get("item_type", "") != "partner_upgrade":
			continue
		var btn = preload("res://scenes/run_main/shop_item_button.tscn").instantiate()
		shop_item_container.add_child(btn)
		btn.setup(item)
		btn.pressed.connect(_on_shop_item_purchased.bind(item))
		_shop_item_buttons.append(btn)
	
	if _shop_item_buttons.is_empty():
		var label = Label.new()
		label.text = "暂无可升级伙伴"
		shop_item_container.add_child(label)


func _on_shop_item_purchased(item_data: Dictionary) -> void:
	print("[RunMain] 购买商品: %s" % item_data.get("name", "???"))
	if _run_controller == null:
		return
	
	var result = _run_controller.purchase_shop_item(item_data)
	if result.get("success", false):
		var new_gold = result.get("new_gold", 0)
		shop_gold_label.text = "持有金币: %d" % new_gold
		gold_label.text = "金币: %d" % new_gold
		
		# 刷新整个商店面板，允许继续升级
		var fresh_items = _run_controller.get_current_shop_items()
		_show_shop_panel(fresh_items)
		
		print("[RunMain] 商店已刷新，当前金币=%d" % new_gold)
	else:
		print("[RunMain] 购买失败: %s" % result.get("error", "???"))


func _refresh_shop_buttons_affordability(current_gold: int) -> void:
	for btn in _shop_item_buttons:
		if btn.is_sold_out:
			continue
		var price = btn.item_data.get("price", 0)
		btn.disabled = current_gold < price
		btn.modulate = Color(0.5, 0.5, 0.5) if current_gold < price else Color(1, 1, 1)


func _show_modal_panel(panel: Control) -> void:
	print("[RunMain] _show_modal_panel: panel=%s" % panel.name)
	ui_modal_blocker.visible = true
	ui_modal_blocker.z_index = panel.z_index - 1 if panel.z_index > 0 else 50
	_current_ui_state = UISceneState.LOADING
	# 只隐藏 option_container，保留 HudContainer / PlayerInfoPanel / PartnerContainer
	option_container.visible = false
	panel.visible = true
	panel.z_index = 100


func _hide_modal_panel(panel: Control) -> void:
	print("[RunMain] _hide_modal_panel: panel=%s" % panel.name)
	panel.visible = false
	ui_modal_blocker.visible = false
	# 只恢复选项按钮
	option_container.visible = true
	_current_ui_state = UISceneState.OPTION_SELECT


func _on_battle_ended(battle_result: Dictionary) -> void:
	print("[RunMain] 战斗结束: winner=%s, turns=%d" % [
		battle_result.get("winner", "???"),
		battle_result.get("turns_elapsed", 0)
	])
	# HUD 在结算确认后再统一更新！
	_pending_battle_result = battle_result
	
	# 补充 sprite_path（爬塔/PVP 统一）
	var summary: Dictionary = _run_controller.get_current_run_summary()
	var runtime_hero: Dictionary = summary.get("hero", {})
	var hero_config_id: int = runtime_hero.get("hero_config_id", 0)
	var hero_sprite_path: String = ConfigManager.get_hero_sprite_path(hero_config_id)
	battle_result["hero_sprite_path"] = hero_sprite_path
	
	var enemies_arr: Array = battle_result.get("enemies", [{}])
	var enemy_data_for_sprite: Dictionary = enemies_arr[0] if enemies_arr.size() > 0 else {}
	var enemy_sprite_path: String = enemy_data_for_sprite.get("sprite_path", "")
	## fallback：如果 enemy_data 没有，再查 ConfigManager
	if enemy_sprite_path.is_empty():
		var enemy_config_id: int = enemy_data_for_sprite.get("config_id", 2001)
		enemy_sprite_path = ConfigManager.get_enemy_sprite_path(enemy_config_id)
	battle_result["enemy_sprite_path"] = enemy_sprite_path
	
	var recorder = battle_result.get("playback_recorder", null)
	if recorder != null and recorder.get_events().size() > 0:
		var hero_data = battle_result.get("hero", {})
		var enemies: Array = battle_result.get("enemies", [{}])
		var enemy_data: Dictionary = enemies[0] if enemies.size() > 0 else {}
		var hero_name = hero_data.get("name", "英雄")
		var enemy_name = enemy_data.get("name", "敌人")
		var hero_max_hp = hero_data.get("max_hp", 100)
		var enemy_max_hp = enemy_data.get("max_hp", 100)
		var turns_elapsed = battle_result.get("turns_elapsed", 0)
		var hero_start_hp = hero_data.get("hp", hero_max_hp)
		var enemy_start_hp = enemy_data.get("hp", enemy_max_hp)
		
		battle_animation_panel.reset_panel()
		_show_modal_panel(battle_animation_panel)
		
		battle_animation_panel.start_playback(
			recorder, hero_name, enemy_name,
			hero_max_hp, enemy_max_hp,
			[], [],
			turns_elapsed,
			hero_start_hp,
			enemy_start_hp,
			battle_result.get("hero_sprite_path", ""),
			battle_result.get("enemy_sprite_path", "")
		)
		
		if not battle_animation_panel.confirmed.is_connected(_on_battle_animation_finished):
			battle_animation_panel.confirmed.connect(_on_battle_animation_finished, CONNECT_ONE_SHOT)
	else:
		# 没有录像，直接显示结算面板
		_show_battle_summary(battle_result)

func _on_battle_animation_finished() -> void:
	print("[RunMain] 战斗动画播放完毕，显示结算面板")
	_show_battle_summary(_pending_battle_result)

func _show_battle_summary(battle_result: Dictionary) -> void:
	# 先隐藏战斗动画面板，避免叠加混乱
	battle_animation_panel.visible = false
	
	battle_summary_panel.show_result(battle_result)
	_show_modal_panel(battle_summary_panel)
	if not battle_summary_panel.confirmed.is_connected(_on_battle_summary_confirmed):
		battle_summary_panel.confirmed.connect(_on_battle_summary_confirmed, CONNECT_ONE_SHOT)

func _on_battle_summary_confirmed() -> void:
	print("[RunMain] 战斗结算确认关闭")
	_hide_modal_panel(battle_summary_panel)
	
	# 在这里统一更新HUD（战斗后的最终状态）
	_update_hud()
	
	# 推进游戏状态
	if _run_controller != null:
		_run_controller.confirm_battle_result()
	
	# 清理缓存
	_pending_battle_result = {}
	
	# 如果有缓存的选项（动画播放期间到达的 node_options），现在处理
	if _cached_node_options.size() > 0:
		var cached = _cached_node_options.duplicate()
		_cached_node_options.clear()
		_on_node_options_presented(cached)

func _on_node_resolved(node_type: String, result: Dictionary) -> void:
	if node_type == "OUTING":
		_show_event_result(result.get("logs", []), result.get("rewards", []))

func _show_event_result(logs: Array, _rewards: Array) -> void:
	var msg = ""
	for log in logs:
		msg += log + "\n"
	if not msg.is_empty():
		print("[RunMain Event] %s" % msg)

func _on_gold_changed(new_amount: int, _delta: int, _reason: String) -> void:
	gold_label.text = "金币: %d" % new_amount


func _on_stats_changed(_unit_id: String, stat_changes: Dictionary) -> void:
	for attr_code in stat_changes.keys():
		var change: Dictionary = stat_changes[attr_code]
		var code: int = int(attr_code)
		match code:
			0:  # HP
				var new_hp: int = change.get("new", 0)
				var max_hp: int = change.get("max_hp", 0)
				if max_hp <= 0:
					var summary = _run_controller.get_current_run_summary() if _run_controller != null else {}
					var hero_data = summary.get("hero", {})
					max_hp = hero_data.get("max_hp", 100)
				hp_label.text = "生命: %d/%d" % [new_hp, max_hp]
			1:
				player_vit_label.text = "体魄: %d" % change.get("new", 0)
			2:
				player_str_label.text = "力量: %d" % change.get("new", 0)
			3:
				player_agi_label.text = "敏捷: %d" % change.get("new", 0)
			4:
				player_tec_label.text = "技巧: %d" % change.get("new", 0)
			5:
				player_mnd_label.text = "精神: %d" % change.get("new", 0)


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

func _on_menu_button_pressed() -> void:
	print("[RunMain] 菜单按钮被点击")
	if pause_menu.visible:
		pause_menu.hide_menu()
	else:
		pause_menu.show_menu()

func _on_resume_game() -> void:
	pass

func _on_return_main_menu() -> void:
	print("[RunMain] 返回主菜单, _run_controller=%s" % _run_controller)
	if _run_controller != null:
		print("[RunMain] 调用 _save_at_floor_entrance()")
		_run_controller._save_at_floor_entrance()
		print("[RunMain] 存档完成")
	else:
		print("[RunMain] ⚠️ _run_controller 为 null，无法存档！")
	get_tree().change_scene_to_file("res://scenes/main_menu/menu.tscn")


func _on_enemy_encountered(enemy_data: Dictionary) -> void:
	## 只缓存数据，不直接显示面板（默认界面不承载怪物信息）
	_cached_enemy_data = enemy_data.duplicate()
	print("[RunMain] 缓存敌人数据: %s" % enemy_data.get("name", "???"))


func update_enemy_info(enemy_data: Dictionary) -> void:
	## 此函数保留供 CombatConfirmPanel / BattleAnimationPanel 显式调用
	enemy_info_panel.visible = true
	enemy_name_label.text = "敌人: %s" % enemy_data.get("name", "???")
	var max_hp: int = enemy_data.get("max_hp", 0)
	var current_hp: int = enemy_data.get("current_hp", max_hp)
	enemy_hp_label.text = "HP: %d/%d" % [current_hp, max_hp]
	var estimated_damage: int = enemy_data.get("estimated_damage", 0)
	predicted_damage_label.text = "预计损失血量: %d" % estimated_damage


## 获取当前主角属性
func _get_current_hero_stats() -> Dictionary:
	if _run_controller == null:
		return {"vit": 10, "str": 10, "agi": 10, "tec": 10, "mnd": 10}
	var summary: Dictionary = _run_controller.get_current_run_summary()
	var hero: Dictionary = summary.get("hero", {})
	return {
		"vit": hero.get("current_vit", 10),
		"str": hero.get("current_str", 10),
		"agi": hero.get("current_agi", 10),
		"tec": hero.get("current_tec", 10),
		"mnd": hero.get("current_mnd", 10),
	}


## 获取当前主角血量
func _get_current_hero_hp() -> int:
	if _run_controller == null:
		return 100
	var summary: Dictionary = _run_controller.get_current_run_summary()
	var hero: Dictionary = summary.get("hero", {})
	return hero.get("current_hp", 100)
