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

@onready var partner_slots: Array[ColorRect] = [
	$PartnerContainer/PartnerSlot1,
	$PartnerContainer/PartnerSlot2,
	$PartnerContainer/PartnerSlot3,
	$PartnerContainer/PartnerSlot4,
	$PartnerContainer/PartnerSlot5,
]

@onready var training_panel: VBoxContainer = $TrainingPanel
@onready var option_container: VBoxContainer = $OptionContainer
@onready var shop_panel: Panel = $ShopPanel

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
var _last_rescue_candidates: Array[Dictionary] = []

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


func _ready() -> void:
	print("[RunMain] _ready 开始")
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
	EventBus.enemy_encountered.connect(_on_enemy_encountered)
	EventBus.node_resolved.connect(_on_node_resolved)

	# --- 暂停菜单信号 ---
	pause_menu.resume_requested.connect(_on_resume_game)
	pause_menu.main_menu_requested.connect(_on_return_main_menu)

	# --- 菜单按钮 ---
	menu_button.pressed.connect(_on_menu_button_pressed)

	# --- 救援面板按钮绑定 ---
	for i in range(rescue_candidate_buttons.size()):
		rescue_candidate_buttons[i].pressed.connect(_on_rescue_partner_selected.bind(i))
	
	# --- 商店关闭按钮 ---
	var shop_close_button: Button = $ShopPanel/CloseButton
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
		else:
			push_error("[RunMain] 存档恢复失败，回到主菜单")
			get_tree().change_scene_to_file("res://scenes/main_menu/menu.tscn")
	else:
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
	if event.is_action_pressed("ui_cancel"):
		if pause_menu.visible:
			pause_menu.hide_menu()
		else:
			pause_menu.show_menu()

func _on_node_button_pressed(index: int) -> void:
	if _run_controller == null:
		push_warning("[RunMain] RunController not available")
		return
	_run_controller.select_node(index)


func _on_training_attr_selected(attr_type: int) -> void:
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


func _on_node_options_presented(node_options: Array[Dictionary]) -> void:
	print("[RunMain] _on_node_options_presented: 选项数=%d" % node_options.size())
	_transition_ui_state(UISceneState.OPTION_SELECT)
	
	# 更新按钮内容
	for i in range(option_buttons.size()):
		if i < node_options.size():
			var opt = node_options[i]
			option_buttons[i].text = opt.get("node_name", "???")
			option_buttons[i].visible = true
			option_buttons[i].disabled = false
		else:
			option_buttons[i].visible = false
			option_buttons[i].disabled = true
	
	_update_monster_info(node_options)


func _on_panel_opened(panel_name: String, panel_data: Dictionary) -> void:
	print("[RunMain] _on_panel_opened: 面板=%s" % panel_name)
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
			# TODO: 显示商店


func _on_panel_closed(_panel_name: String, _close_reason: String) -> void:
	# 面板关闭后回到选项状态
	_transition_ui_state(UISceneState.OPTION_SELECT)


func _on_training_completed(attr_code: int, attr_name: String, gain_value: int, new_total: int, proficiency_stage: String, bonus_applied: int) -> void:
	_update_hud()
	print("[RunMain] 训练完成: %s +%d (当前%d, %s, 伙伴加成%d)" % [attr_name, gain_value, new_total, proficiency_stage, bonus_applied])


func _on_floor_advanced(new_floor: int, floor_type: String, is_special: bool) -> void:
	# 楼层推进后清空按钮（等待下一轮选项）
	for btn in option_buttons:
		btn.text = "..."
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


func _show_rescue_panel_details(candidates: Array[Dictionary]) -> void:
	for i in range(rescue_candidate_buttons.size()):
		if i < candidates.size():
			rescue_candidate_buttons[i].visible = true
			var candidate = candidates[i]
			rescue_candidate_labels[i].text = "%s\n%s" % [candidate.get("name", "???"), candidate.get("role", "")]
			rescue_candidate_buttons[i].disabled = false
		else:
			rescue_candidate_buttons[i].visible = false
			rescue_candidate_buttons[i].disabled = true

func _on_rescue_partner_selected(index: int) -> void:
	if index < _last_rescue_candidates.size():
		var partner_config_id = int(_last_rescue_candidates[index].get("partner_id", 0))
		if partner_config_id > 0:
			_run_controller.select_rescue_partner(partner_config_id)
			# UI状态切换由 RunController 的下一个 panel_opened 信号驱动

func _on_shop_close_pressed() -> void:
	print("[RunMain] 商店关闭")
	if _run_controller != null:
		_run_controller.close_shop_panel()

func _on_node_resolved(node_type: String, result: Dictionary) -> void:
	if node_type == "OUTING":
		_show_event_result(result.get("logs", []), result.get("rewards", []))

func _show_event_result(logs: Array, _rewards: Array) -> void:
	var msg = ""
	for log in logs:
		msg += log + "\n"
	if not msg.is_empty():
		print("[RunMain Event] %s" % msg)

func _on_gold_changed(new_amount: int, delta: int, _reason: String) -> void:
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
	print("[RunMain] 返回主菜单")
	if _run_controller != null:
		var summary = _run_controller.get_current_run_summary()
		if not summary.is_empty():
			SaveManager.save_run_state(summary, false)
			print("[RunMain] 返回主菜单前已保存进度")
	get_tree().change_scene_to_file("res://scenes/main_menu/menu.tscn")


func _on_enemy_encountered(enemy_data: Dictionary) -> void:
	update_enemy_info(enemy_data)


func update_enemy_info(enemy_data: Dictionary) -> void:
	enemy_info_panel.visible = true
	enemy_name_label.text = "敌人: %s" % enemy_data.get("name", "???")
	var max_hp: int = enemy_data.get("max_hp", 0)
	var current_hp: int = enemy_data.get("current_hp", max_hp)
	enemy_hp_label.text = "HP: %d/%d" % [current_hp, max_hp]
	var estimated_damage: int = enemy_data.get("estimated_damage", 0)
	predicted_damage_label.text = "预计损失血量: %d" % estimated_damage


## v2: 更新怪物信息和预计损失血量
func _update_monster_info(node_options: Array[Dictionary]) -> void:
	## 查找包含敌人信息的节点
	var has_enemy: bool = false
	var enemy_name: String = "???"
	var enemy_hp: int = 0
	var enemy_stats: Dictionary = {}

	for opt in node_options:
		var node_type: int = opt.get("node_type", 0)
		## 战斗节点: 普通战斗(2), 精英(3), 终局(7)
		if node_type == 2 or node_type == 3 or node_type == 7:
			has_enemy = true
			var enemy_cfg: Dictionary = opt.get("enemy_config", {})
			if enemy_cfg.is_empty():
				enemy_cfg = _fetch_enemy_config_for_option(opt)
			enemy_name = enemy_cfg.get("name", "???")
			enemy_hp = enemy_cfg.get("hp", 0)
			enemy_stats = enemy_cfg
			break

	if not has_enemy:
		enemy_info_panel.visible = false
		return

	enemy_info_panel.visible = true
	enemy_name_label.text = "敌人: %s" % enemy_name
	enemy_hp_label.text = "HP: %d" % enemy_hp

	## v2: 计算预计损失血量
	if enemy_stats.is_empty():
		enemy_info_panel.visible = false
		return
	var hero_stats: Dictionary = _get_current_hero_stats()
	var prediction: Dictionary = DamagePredictor.predict_battle_outcome(
		_get_current_hero_hp(), hero_stats, enemy_stats
	)

	predicted_damage_label.text = "预计损失: %d/击" % prediction.get("per_hit", 0)
	var risk: String = prediction.get("risk_level", "unknown")
	risk_label.text = DamagePredictor.get_risk_display_text(risk)
	risk_label.modulate = DamagePredictor.get_risk_color(risk)


## 从节点选项获取敌人配置
func _fetch_enemy_config_for_option(opt: Dictionary) -> Dictionary:
	var enemy_id: String = ""
	var result: Dictionary = _run_controller.get_current_run_summary() if _run_controller != null else {}
	var node_type: int = opt.get("node_type", 0)

	match node_type:
		2: ## 普通战斗
			enemy_id = opt.get("enemy_config_id", "")
		3: ## 精英战
			enemy_id = opt.get("enemy_config_id", "")
		7: ## 终局战
			enemy_id = opt.get("enemy_config_id", "")

	if enemy_id.is_empty():
		return {}
	return ConfigManager.get_enemy_config(enemy_id)


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
