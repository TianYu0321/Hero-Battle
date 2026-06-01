class_name PvpLobby
extends Control

## ========== 子节点引用（运行时查找）==========
var _battle_summary_panel: BattleSummaryPanel = null
var _battle_animation_panel: BattleAnimationPanel = null

## ========== 动态 UI 节点 ==========
var _top_bar: HBoxContainer = null
var _main_content: HBoxContainer = null
var _left_panel: VBoxContainer = null
var _center_panel: VBoxContainer = null
var _right_panel: VBoxContainer = null
var _bottom_bar: HBoxContainer = null

## 左侧
var _player_card: PanelContainer = null
var _net_wins_badge: Label = null
var _wins_label: Label = null
var _losses_label: Label = null
var _streak_label: Label = null
var _deck_preview: VBoxContainer = null
var _update_deck_btn: Button = null

## 中间
var _daily_reward_dots: HBoxContainer = null
var _match_btn: Button = null
var _matching_anim: Control = null
var _opponent_preview: PanelContainer = null

## 右侧
var _leaderboard_scroll: ScrollContainer = null
var _leaderboard_vbox: VBoxContainer = null

## 弹层
var _match_result_popup: PanelContainer = null
var _history_popup: PanelContainer = null

## ========== 运行时状态 ==========
var _current_opponent: Dictionary = {}
var _pending_pvp_result: Dictionary = {}
var _virtual_pool: VirtualArchivePool = null

func _ready() -> void:
	_battle_summary_panel = $BattleSummaryPanel
	_battle_animation_panel = $BattleAnimationPanel
	_battle_summary_panel.visible = false
	_battle_animation_panel.visible = false

	_virtual_pool = VirtualArchivePool.new()
	_virtual_pool._load_virtual_archives()

	_build_ui()
	_setup_styles()
	_refresh_all()

	PVPManager.match_found.connect(_on_match_found)
	PVPManager.match_result.connect(_on_match_result)
	PVPManager.daily_reward_updated.connect(_on_daily_reward_updated)
	_battle_summary_panel.confirmed.connect(_on_battle_confirmed)


## ==================== UI 构建 ====================

func _build_ui() -> void:
	## 背景
	var bg := ColorRect.new()
	bg.name = "BgPanel"
	bg.color = OutgameUIStyle.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

	## 主布局 VBox
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.offset_left = 20
	root_vbox.offset_top = 20
	root_vbox.offset_right = -20
	root_vbox.offset_bottom = -20
	root_vbox.add_theme_constant_override("separation", 12)
	add_child(root_vbox)

	## 顶部栏
	_top_bar = HBoxContainer.new()
	_top_bar.add_theme_constant_override("separation", 12)
	root_vbox.add_child(_top_bar)

	var back_btn := Button.new()
	back_btn.text = "← 返回"
	back_btn.pressed.connect(_on_back_pressed)
	_top_bar.add_child(back_btn)

	var title := Label.new()
	title.text = "竞技场"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar.add_child(title)

	var coin_hbox := HBoxContainer.new()
	coin_hbox.add_theme_constant_override("separation", 6)
	var coin_label := Label.new()
	coin_label.name = "CoinLabel"
	coin_label.add_theme_font_size_override("font_size", 16)
	coin_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.8, 1))
	coin_hbox.add_child(coin_label)
	_top_bar.add_child(coin_hbox)

	## 主内容区（三栏）
	_main_content = HBoxContainer.new()
	_main_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_content.add_theme_constant_override("separation", 16)
	root_vbox.add_child(_main_content)

	## 左侧面板
	_left_panel = VBoxContainer.new()
	_left_panel.custom_minimum_size = Vector2(280, 0)
	_left_panel.add_theme_constant_override("separation", 12)
	_main_content.add_child(_left_panel)

	_player_card = _build_player_card()
	_left_panel.add_child(_player_card)

	_deck_preview = VBoxContainer.new()
	_deck_preview.add_theme_constant_override("separation", 6)
	var deck_title := Label.new()
	deck_title.text = "出战队伍"
	deck_title.add_theme_font_size_override("font_size", 14)
	deck_title.add_theme_color_override("font_color", Color(0.8, 0.78, 0.75, 1))
	_deck_preview.add_child(deck_title)
	_left_panel.add_child(_deck_preview)

	_update_deck_btn = Button.new()
	_update_deck_btn.text = "更新队伍快照"
	_update_deck_btn.pressed.connect(_on_update_deck_pressed)
	_left_panel.add_child(_update_deck_btn)

	## 中间面板
	_center_panel = VBoxContainer.new()
	_center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_panel.add_theme_constant_override("separation", 16)
	_main_content.add_child(_center_panel)

	_daily_reward_dots = HBoxContainer.new()
	_daily_reward_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_daily_reward_dots.add_theme_constant_override("separation", 8)
	_center_panel.add_child(_daily_reward_dots)

	_match_btn = Button.new()
	_match_btn.text = "寻找对手"
	_match_btn.custom_minimum_size = Vector2(240, 64)
	_match_btn.pressed.connect(_on_match_pressed)
	_center_panel.add_child(_match_btn)

	_matching_anim = _build_matching_animation()
	_matching_anim.visible = false
	_center_panel.add_child(_matching_anim)

	_opponent_preview = _build_opponent_preview()
	_opponent_preview.visible = false
	_center_panel.add_child(_opponent_preview)

	## 右侧面板
	_right_panel = VBoxContainer.new()
	_right_panel.custom_minimum_size = Vector2(300, 0)
	_right_panel.add_theme_constant_override("separation", 8)
	_main_content.add_child(_right_panel)

	var lb_title := Label.new()
	lb_title.text = "排行榜"
	lb_title.add_theme_font_size_override("font_size", 18)
	lb_title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1))
	_right_panel.add_child(lb_title)

	_leaderboard_scroll = ScrollContainer.new()
	_leaderboard_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_panel.add_child(_leaderboard_scroll)

	_leaderboard_vbox = VBoxContainer.new()
	_leaderboard_vbox.add_theme_constant_override("separation", 6)
	_leaderboard_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leaderboard_scroll.add_child(_leaderboard_vbox)

	## 底部栏
	_bottom_bar = HBoxContainer.new()
	_bottom_bar.add_theme_constant_override("separation", 12)
	root_vbox.add_child(_bottom_bar)

	var history_btn := Button.new()
	history_btn.text = "对战记录"
	history_btn.pressed.connect(_on_history_pressed)
	_bottom_bar.add_child(history_btn)

	var rules_label := Label.new()
	rules_label.text = "每日限领 5 次胜利奖励 | 每次 20 魔城币"
	rules_label.add_theme_font_size_override("font_size", 12)
	rules_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.52, 1))
	_bottom_bar.add_child(rules_label)


func _build_player_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 180)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	_net_wins_badge = Label.new()
	_net_wins_badge.add_theme_font_size_override("font_size", 24)
	_net_wins_badge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1))
	_net_wins_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_net_wins_badge)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	vbox.add_child(grid)

	_wins_label = Label.new()
	_wins_label.add_theme_font_size_override("font_size", 13)
	_wins_label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.75, 1))
	grid.add_child(_wins_label)

	_losses_label = Label.new()
	_losses_label.add_theme_font_size_override("font_size", 13)
	_losses_label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.75, 1))
	grid.add_child(_losses_label)

	_streak_label = Label.new()
	_streak_label.add_theme_font_size_override("font_size", 13)
	_streak_label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.75, 1))
	grid.add_child(_streak_label)

	return card


func _build_matching_animation() -> Control:
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(240, 80)

	var label := Label.new()
	label.name = "MatchingLabel"
	label.text = "匹配中..."
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	ctrl.add_child(label)

	## 旋转小圆点
	var dot := ColorRect.new()
	dot.name = "SpinDot"
	dot.custom_minimum_size = Vector2(12, 12)
	dot.color = Color(0.9, 0.7, 0.3, 1)
	dot.position = Vector2(114, 48)
	ctrl.add_child(dot)

	return ctrl


func _start_matching_spin() -> void:
	var dot: ColorRect = _matching_anim.get_node_or_null("SpinDot")
	if dot == null:
		return
	var tween := create_tween().set_loops()
	tween.tween_property(dot, "rotation", TAU, 0.6).from(0)
	dot.set_meta("spin_tween", tween)

func _stop_matching_spin() -> void:
	var dot: ColorRect = _matching_anim.get_node_or_null("SpinDot")
	if dot == null:
		return
	var tween: Tween = dot.get_meta("spin_tween", null)
	if tween != null and tween.is_valid():
		tween.kill()
	dot.rotation = 0

func _build_opponent_preview() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 160)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.name = "OppNameLabel"
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var net_label := Label.new()
	net_label.name = "OppNetLabel"
	net_label.add_theme_font_size_override("font_size", 14)
	net_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1))
	net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(net_label)

	var start_btn := Button.new()
	start_btn.name = "StartBattleBtn"
	start_btn.text = "开始对战"
	start_btn.custom_minimum_size = Vector2(200, 48)
	vbox.add_child(start_btn)

	return panel


func _setup_styles() -> void:
	_apply_button_styles_recursive(self)

	## 个人信息卡样式
	if _player_card != null:
		OutgameUIStyle.apply_panel(_player_card)

	## 匹配按钮样式
	if _match_btn != null:
		OutgameUIStyle.apply_button(_match_btn, true)

	## 对手预览样式
	if _opponent_preview != null:
		OutgameUIStyle.apply_panel(_opponent_preview, true)


func _apply_button_styles_recursive(node: Node) -> void:
	if node == _battle_summary_panel or node == _battle_animation_panel:
		return
	if node is Button:
		OutgameUIStyle.apply_button(node as Button)
	for child in node.get_children():
		_apply_button_styles_recursive(child)


## ==================== 数据刷新 ====================

func _refresh_all() -> void:
	_update_player_info()
	_update_daily_rewards()
	_update_leaderboard()
	_update_deck_preview()
	_update_magic_coins()


func _update_player_info() -> void:
	var stats: Dictionary = PVPManager.get_stats()

	_net_wins_badge.text = "净胜场: %d" % stats["net_wins"]
	_wins_label.text = "胜: %d" % stats["wins"]
	_losses_label.text = "败: %d" % stats["losses"]

	var history: Array = stats.get("history", [])
	var streak: int = 0
	for record in history:
		if record.get("result") == "win":
			streak += 1
		else:
			break
	_streak_label.text = "连胜: %d" % streak


func _update_daily_rewards() -> void:
	var stats: Dictionary = PVPManager.get_stats()
	var remaining: int = stats.get("remaining_rewards", 5)

	## 清空旧圆点
	for child in _daily_reward_dots.get_children():
		child.queue_free()

	for i in range(PVPManager.DAILY_MAX_REWARDS):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if i < remaining:
			dot.color = Color(0.3, 0.8, 0.4, 1.0)
		else:
			dot.color = Color(0.4, 0.4, 0.42, 1.0)
		_daily_reward_dots.add_child(dot)


func _update_magic_coins() -> void:
	var stats: Dictionary = PVPManager.get_stats()
	var coin_label: Label = _top_bar.get_node_or_null("CoinLabel")
	if coin_label != null:
		coin_label.text = "魔城币: %d" % stats["magic_coins"]


func _update_leaderboard() -> void:
	for child in _leaderboard_vbox.get_children():
		child.queue_free()

	var entries: Array[Dictionary] = PVPManager.get_leaderboard()
	for entry in entries:
		var row := _create_leaderboard_row(entry)
		_leaderboard_vbox.add_child(row)


func _create_leaderboard_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 36)
	row.add_theme_constant_override("separation", 8)

	var rank_label := Label.new()
	rank_label.text = "#%d" % entry["rank"]
	rank_label.custom_minimum_size = Vector2(36, 0)
	rank_label.add_theme_font_size_override("font_size", 13)
	if entry.get("is_player", false):
		rank_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1))
	else:
		rank_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.62, 1))
	row.add_child(rank_label)

	var name_label := Label.new()
	name_label.text = entry["name"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	if entry.get("is_player", false):
		name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.9, 1))
	else:
		name_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.65, 1))
	row.add_child(name_label)

	var net_label := Label.new()
	net_label.text = "%d胜/%d负" % [entry["wins"], entry["losses"]]
	net_label.custom_minimum_size = Vector2(80, 0)
	net_label.add_theme_font_size_override("font_size", 11)
	net_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55, 0.8))
	row.add_child(net_label)

	var net_value := Label.new()
	net_value.text = "净%d" % entry["net_wins"]
	net_value.custom_minimum_size = Vector2(44, 0)
	net_value.add_theme_font_size_override("font_size", 13)
	net_value.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4, 1))
	row.add_child(net_value)

	if entry.get("is_player", false):
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.25, 0.2, 0.15, 0.5)
		bg.corner_radius_top_left = 6
		bg.corner_radius_top_right = 6
		bg.corner_radius_bottom_left = 6
		bg.corner_radius_bottom_right = 6
		row.add_theme_stylebox_override("panel", bg)

	return row


func _update_deck_preview() -> void:
	## 清除旧内容（保留标题）
	while _deck_preview.get_child_count() > 1:
		var c := _deck_preview.get_child(1)
		if c != null:
			c.queue_free()

	var deck: Dictionary = PVPManager.get_deck_snapshot()
	if deck.is_empty():
		var warn := Label.new()
		warn.text = "未设置队伍"
		warn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1))
		warn.add_theme_font_size_override("font_size", 12)
		_deck_preview.add_child(warn)
		return

	var hero_name: String = deck.get("hero_name", "???")
	var hero_label := Label.new()
	hero_label.text = "英雄: %s" % hero_name
	hero_label.add_theme_font_size_override("font_size", 12)
	hero_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75, 1))
	_deck_preview.add_child(hero_label)

	var partners: Array = deck.get("partner_ids", [])
	if partners.size() > 0:
		var partner_label := Label.new()
		var partner_names: Array[String] = []
		for pid in partners:
			var pid_str: String = str(pid)
			var cfg: Dictionary = ConfigManager.get_partner_config(pid_str)
			var display_name: String = cfg.get("name", pid_str)
			partner_names.append(display_name)
		partner_label.text = "伙伴: %s" % ", ".join(partner_names)
		partner_label.add_theme_font_size_override("font_size", 11)
		partner_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.65, 1))
		_deck_preview.add_child(partner_label)


## ==================== 交互回调 ====================

func _on_match_pressed() -> void:
	AudioManager.play_ui("confirm")

	if not PVPManager.has_deck_snapshot():
		_show_confirm_dialog("请先设置PVP队伍", "你还没有设置PVP对战用的队伍，是否更新队伍快照？")
		return

	_match_btn.visible = false
	_matching_anim.visible = true
	_opponent_preview.visible = false

	## 启动旋转动画
	_start_matching_spin()

	## 模拟匹配延迟
	var tween := create_tween()
	tween.tween_callback(func():
		PVPManager.find_match()
	).set_delay(randf_range(1.0, 2.0))


func _on_match_found(opponent: Dictionary) -> void:
	_stop_matching_spin()
	_matching_anim.visible = false
	_opponent_preview.visible = true
	_current_opponent = opponent

	var name_label: Label = _opponent_preview.get_node("OppNameLabel")
	var net_label: Label = _opponent_preview.get_node("OppNetLabel")
	var start_btn: Button = _opponent_preview.get_node("StartBattleBtn")

	name_label.text = opponent.get("name", "???")
	net_label.text = "净胜场: %d" % opponent.get("net_wins", 0)

	## 断开旧连接
	for conn: Dictionary in start_btn.pressed.get_connections():
		start_btn.pressed.disconnect(conn["callable"])
	start_btn.pressed.connect(_on_start_battle)


func _on_start_battle() -> void:
	AudioManager.play_ui("confirm")
	_opponent_preview.visible = false
	_match_btn.visible = true

	## 复用现有 PvpDirector 执行战斗
	var pvp_director := PvpDirector.new()
	add_child(pvp_director)

	var archive: Dictionary = GameManager.get_pvp_archive()
	var pvp_config: Dictionary = {
		"turn_number": 30,
		"player_gold": 0,
		"player_hp": archive.get("max_hp_reached", 100),
		"player_hero": _archive_to_battle_dict(archive),
		"run_seed": randi(),
		"use_archive": true,
		"opponent_archive": _current_opponent.get("_archive", {}),
	}

	var result: Dictionary = pvp_director.execute_pvp(pvp_config)
	var recorder: BattlePlaybackRecorder = result.get("playback_recorder", null)
	pvp_director.queue_free()

	_pending_pvp_result = result
	_process_pvp_result(result.get("won", false))

	var combat_summary: Dictionary = result.get("combat_summary", {})
	var total_rounds: int = combat_summary.get("turns", 0)

	var hero_sprite_path: String = ConfigManager.get_hero_sprite_path(GameManager.selected_hero_config_id)
	var enemy_data: Dictionary = result.get("enemies", [{}])[0]
	var enemy_sprite_path: String = enemy_data.get("sprite_path", "")
	if enemy_sprite_path.is_empty():
		enemy_sprite_path = "res://assets/characters/gorgen/gorgen.tres"

	if recorder != null and recorder.get_events().size() > 0:
		var hero_data: Dictionary = result.get("hero", {})
		var hero_name: String = hero_data.get("name", "英雄")
		var enemy_name: String = enemy_data.get("name", "???")
		var hero_max_hp: int = hero_data.get("max_hp", 100)
		var enemy_max_hp: int = enemy_data.get("max_hp", 100)

		_battle_animation_panel.reset_panel()
		_battle_animation_panel.visible = true
		_battle_animation_panel.z_index = 100
		_battle_animation_panel.battle_finished_callback = _on_battle_animation_finished
		_battle_animation_panel.start_playback(
			recorder, hero_name, enemy_name,
			hero_max_hp, enemy_max_hp,
			[], [], total_rounds,
			hero_max_hp, enemy_max_hp,
			hero_sprite_path, enemy_sprite_path
		)
	else:
		_show_pvp_summary(result)


func _on_battle_animation_finished() -> void:
	print("[PvpLobby] PVP战斗动画播放完毕，显示结算")
	_battle_animation_panel.battle_finished_callback = Callable()
	_battle_animation_panel.visible = false
	_show_pvp_summary(_pending_pvp_result)


func _show_pvp_summary(result: Dictionary) -> void:
	var battle_result: Dictionary = {
		"winner": "player" if result.get("won", false) else "enemy",
		"enemies": [{"name": _current_opponent.get("name", "???")}],
		"turns_elapsed": result.get("combat_summary", {}).get("turns", 0),
		"hero_remaining_hp": 100,
		"hero_max_hp": 100,
		"gold_reward": 0,
		"max_chain_count": result.get("combat_summary", {}).get("max_chain", 0),
		"opponent_source": _current_opponent.get("_source", "ai"),
	}
	_battle_summary_panel.show_result(battle_result)
	_battle_summary_panel.visible = true
	_refresh_all()  ## 立即刷新数据

	## 3秒后自动关闭面板（用户提前点击确认也不会重复刷新）
	await get_tree().create_timer(3.0).timeout
	_battle_summary_panel.visible = false


func _process_pvp_result(won: bool) -> void:
	PVPManager.calculate_match_result(won)


func _on_match_result(won: bool, net_wins: int, magic_coins_earned: int) -> void:
	print("[PvpLobby] 结算回调: won=%s net=%d coins=%d" % [won, net_wins, magic_coins_earned])


func _on_daily_reward_updated(remaining: int) -> void:
	_update_daily_rewards()
	_update_magic_coins()


func _on_update_deck_pressed() -> void:
	AudioManager.play_ui("click")
	PVPManager.update_deck_snapshot()
	_update_deck_preview()
	_show_toast("PVP队伍已更新")


func _on_history_pressed() -> void:
	_show_history_popup()


func _show_history_popup() -> void:
	if _history_popup != null and is_instance_valid(_history_popup):
		_history_popup.queue_free()

	_history_popup = PanelContainer.new()
	_history_popup.set_anchors_preset(Control.PRESET_CENTER)
	_history_popup.custom_minimum_size = Vector2(480, 400)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_history_popup.add_child(vbox)

	var title_hbox := HBoxContainer.new()
	var title := Label.new()
	title.text = "对战记录（最近10场）"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): _history_popup.queue_free())
	title_hbox.add_child(close_btn)
	vbox.add_child(title_hbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	var stats: Dictionary = PVPManager.get_stats()
	var history: Array = stats.get("history", [])
	if history.is_empty():
		var empty := Label.new()
		empty.text = "暂无记录"
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.52, 1))
		list.add_child(empty)
	else:
		for record in history:
			var row := HBoxContainer.new()
			var result_color := Color(0.3, 0.8, 0.4, 1) if record.get("result") == "win" else Color(0.8, 0.3, 0.3, 1)
			var result_text := "胜" if record.get("result") == "win" else "负"

			var result_label := Label.new()
			result_label.text = result_text
			result_label.add_theme_color_override("font_color", result_color)
			result_label.custom_minimum_size = Vector2(30, 0)
			row.add_child(result_label)

			var opp_label := Label.new()
			opp_label.text = record.get("opponent_name", "???")
			opp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(opp_label)

			var coin_label := Label.new()
			var coins: int = record.get("magic_coins", 0)
			coin_label.text = "+%d" % coins if coins > 0 else "-"
			coin_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.8, 1))
			row.add_child(coin_label)

			var time_label := Label.new()
			time_label.text = record.get("timestamp", "") as String
			time_label.add_theme_font_size_override("font_size", 10)
			time_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
			row.add_child(time_label)

			list.add_child(row)

	add_child(_history_popup)


func _on_battle_confirmed() -> void:
	_battle_summary_panel.visible = false

func _on_back_pressed() -> void:
	AudioManager.play_ui("cancel")
	EventBus.back_to_menu_requested.emit()


## ==================== 辅助 ====================

func _archive_to_battle_dict(archive: Dictionary) -> Dictionary:
	return {
		"hero_id": ConfigManager.get_hero_id_by_config_id(archive.get("hero_config_id", 1)),
		"stats": {
			"physique": archive.get("attr_snapshot_vit", 10),
			"strength": archive.get("attr_snapshot_str", 10),
			"agility": archive.get("attr_snapshot_agi", 10),
			"technique": archive.get("attr_snapshot_tec", 10),
			"spirit": archive.get("attr_snapshot_mnd", 10),
		},
		"max_hp": archive.get("max_hp_reached", 100),
		"hp": archive.get("max_hp_reached", 100),
	}


func _show_toast(text: String) -> void:
	var toast := Label.new()
	toast.text = text
	toast.position = Vector2(540, 80)
	toast.z_index = 200
	toast.add_theme_font_size_override("font_size", 14)
	toast.add_theme_color_override("font_color", Color(0.3, 0.7, 0.4, 1))
	add_child(toast)

	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tween.finished.connect(func(): toast.queue_free())


func _show_confirm_dialog(title: String, message: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = "更新队伍"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(func():
		PVPManager.update_deck_snapshot()
		_update_deck_preview()
	)
	add_child(dialog)
	dialog.popup_centered()
