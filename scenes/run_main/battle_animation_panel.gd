class_name BattleAnimationPanel
extends Control


@onready var turn_label: Label = $TopBar/CenterInfo/TurnLabel
@onready var hero_name_label: Label = $TopBar/HeroPanel/HeroNameLabel
@onready var hero_hp_bar: ProgressBar = $TopBar/HeroPanel/HeroHPBar
@onready var enemy_name_label: Label = $TopBar/EnemyPanel/EnemyNameLabel
@onready var enemy_hp_bar: ProgressBar = $TopBar/EnemyPanel/EnemyHPBar
@onready var bottom_hint: RichTextLabel = $BottomHint
@onready var skip_button: Button = $SkipButton
@onready var damage_container: Node = $DamageContainer
@onready var hero_sprite: Control = $BattleArea/HeroSprite
@onready var enemy_sprite: Control = $BattleArea/EnemySprite
@onready var turn_timer: Timer = $TurnTimer

var _recorder: BattlePlaybackRecorder = null
var _events_by_turn: Dictionary = {}
var _turn_keys: Array = []
var _current_turn_index: int = 0
var _is_playing: bool = false
var _hero_hp: int = 0
var _hero_max_hp: int = 0
var _enemy_hp: int = 0
var _enemy_max_hp: int = 0
var _turn_duration: float = 2.0
var _playback_generation: int = 0
var _result_emitted: bool = false
var _is_frenzy_active: bool = false

signal confirmed

func _ready() -> void:
	turn_timer.timeout.connect(_on_turn_timer_timeout)
	turn_timer.one_shot = true # 确保只触发一次，_play_turn()里重新start()
	_setup_hero_hp_bar_style(hero_hp_bar)
	_setup_enemy_hp_bar_style(enemy_hp_bar)

func start_playback(recorder: BattlePlaybackRecorder, hero_name: String, enemy_name: String,
						hero_max_hp: int, enemy_max_hp: int, _hero_partners: Array, _enemy_partners: Array) -> void:
	_playback_generation += 1
	_result_emitted = false
	_is_frenzy_active = false
	_recorder = recorder
	_events_by_turn = recorder.get_events_by_turn()
	_turn_keys = _events_by_turn.keys()
	_current_turn_index = 0
	_hero_max_hp = hero_max_hp
	_enemy_max_hp = enemy_max_hp
	_hero_hp = hero_max_hp
	_enemy_hp = enemy_max_hp
	_is_playing = true
	visible = true
	
	# 清理残留状态
	bottom_hint.text = ""
	_clear_damage_numbers()
	
	hero_name_label.text = hero_name
	enemy_name_label.text = enemy_name
	_update_hp_display()
	
	if not skip_button.pressed.is_connected(_on_skip):
		skip_button.pressed.connect(_on_skip)
	
	print("[BattleAnimation] 开始回放: gen=%d, %d个回合" % [_playback_generation, _turn_keys.size()])
	_play_turn()

func _play_turn() -> void:
	var gen: int = _playback_generation
	
	if not _is_playing or _current_turn_index >= _turn_keys.size():
		print("[BattleAnimation] _play_turn 结束条件触发: gen=%d, _is_playing=%s, _current_turn_index=%d, _turn_keys.size=%d" % [
			gen, _is_playing, _current_turn_index, _turn_keys.size()
		])
		_show_result()
		return
	
	var turn: int = _turn_keys[_current_turn_index]
	var events: Array = _events_by_turn[turn]
	if turn == 0:
		turn_label.text = "战斗开始"
	else:
		turn_label.text = "回合 %d" % turn
	bottom_hint.text = ""
	
	var partner_events: int = 0
	for evt in events:
		if evt["type"] in ["partner_assist", "chain_triggered"]:
			partner_events += 1
	var duration: float = _turn_duration + partner_events * 0.5
	
	print("[BattleAnimation] gen=%d 播放回合 %d, 事件数=%d, duration=%.1f" % [gen, turn + 1, events.size(), duration])
	
	for evt in events:
		_process_event(evt)
	
	# 用 Timer 节点，可以被 stop()
	turn_timer.start(duration)

func _on_turn_timer_timeout() -> void:
	if not _is_playing:
		return
	_current_turn_index += 1
	_play_turn()

func _process_event(evt: Dictionary) -> void:
	var type: String = evt["type"]
	var data: Dictionary = evt["data"]
	
	match type:
		"turn_started":
			var order: Array = data.get("order", [])
			if order.size() > 0:
				var actor: String = order[0].get("name", "???")
				bottom_hint.append_text("[color=yellow]%s 的行动[/color]  " % actor)
		
		"action_executed":
			var actor: String = data.get("actor_name", "???")
			var target: String = data.get("target_name", "???")
			var summary: Dictionary = data.get("result_summary", {})
			var is_miss: bool = summary.get("is_miss", false)
			var is_crit: bool = summary.get("is_crit", false)
			var value: int = summary.get("value", 0)
			
			if is_miss:
				bottom_hint.append_text("[color=gray]%s → %s miss[/color]  " % [actor, target])
				AudioManager.play_sfx("miss")
			elif is_crit:
				bottom_hint.append_text("[color=red]%s → %s 暴击 %d！[/color]  " % [actor, target, value])
				AudioManager.play_sfx("crit")
				_screen_shake()
			else:
				bottom_hint.append_text("%s → %s %d  " % [actor, target, value])
				AudioManager.play_sfx("attack")
		
		"unit_damaged":
			var unit_id: String = data.get("unit_id", "")
			var damage: int = data.get("damage", 0)
			var hp: int = data.get("hp", 0)
			var is_crit: bool = data.get("is_crit", false)
			
			if unit_id == "hero" or unit_id.begins_with("hero"):
				_hero_hp = maxi(0, hp)
				_update_hp_display()
				_show_damage_number(damage, is_crit, false)
				AudioManager.play_sfx("hero_hit")
			else:
				_enemy_hp = maxi(0, hp)
				_update_hp_display()
				_show_damage_number(damage, is_crit, true)
				AudioManager.play_sfx("enemy_hit")
			
			_flash_sprite(unit_id)
		
		"unit_died":
			var uname: String = data.get("name", "???")
			bottom_hint.append_text("[color=red]%s 被击败！[/color]  " % uname)
			AudioManager.play_sfx("defeat")
		
		"partner_assist":
			var pname: String = data.get("partner_name", "???")
			bottom_hint.append_text("[color=cyan]%s 援助！[/color]  " % pname)
			_flash_partner_icon(pname)
			AudioManager.play_sfx("partner_assist")
		
		"chain_triggered":
			var chain_count: int = data.get("chain_count", 0)
			var pname: String = data.get("partner_name", "???")
			var dmg: int = data.get("damage", 0)
			bottom_hint.append_text("[color=purple]CHAIN x%d! %s %d[/color]  " % [chain_count, pname, dmg])
			_show_damage_number(dmg, false, false, true, chain_count)
			AudioManager.play_sfx("chain")
		
		"ultimate_triggered":
			var log_text: String = data.get("log", "")
			bottom_hint.append_text("[color=gold]%s[/color]  " % log_text)
			_screen_shake()
			AudioManager.play_sfx("ultimate")
		
		"frenzy_triggered":
			_is_frenzy_active = true
			var msg: String = data.get("message", "狂暴阶段触发！")
			bottom_hint.append_text("\n[color=red]★ %s ★[/color]\n" % msg)
			turn_label.modulate = Color(1, 0.2, 0.2)
			_update_hp_display()
			AudioManager.play_sfx("frenzy_alert")

func _update_hp_display() -> void:
	hero_hp_bar.value = float(_hero_hp) / maxi(1, _hero_max_hp) * 100
	enemy_hp_bar.value = float(_enemy_hp) / maxi(1, _enemy_max_hp) * 100
	
	var hero_ratio: float = float(_hero_hp) / maxi(1, _hero_max_hp)
	
	# 低血量闪烁（英雄，低于30%）
	if hero_ratio < 0.3 and not _is_frenzy_active:
		var tween := create_tween().set_loops()
		tween.tween_property(hero_hp_bar, "modulate", Color(1, 0.3, 0.3), 0.3)
		tween.tween_property(hero_hp_bar, "modulate", Color(1, 1, 1), 0.3)
	elif not _is_frenzy_active:
		hero_hp_bar.modulate = Color(1, 1, 1)
	
	# 狂暴阶段血条变红提示
	if _is_frenzy_active:
		hero_hp_bar.modulate = Color(1, 0.2, 0.2)
		enemy_hp_bar.modulate = Color(1, 0.2, 0.2)
	else:
		enemy_hp_bar.modulate = Color(1, 1, 1)

func _show_damage_number(damage: int, is_crit: bool, is_enemy_side: bool, is_chain: bool = false, chain_count: int = 0) -> void:
	var label := Label.new()
	
	if is_chain:
		label.text = "CHAIN x%d! %d" % [chain_count, damage]
		label.add_theme_font_size_override("font_size", 28)
		label.modulate = Color(0.8, 0.3, 1.0)  # 紫色
	elif is_crit:
		label.text = str(damage)
		label.add_theme_font_size_override("font_size", 36)
		label.modulate = Color(1, 0.1, 0.1)  # 鲜红
	else:
		label.text = str(damage)
		label.add_theme_font_size_override("font_size", 26)
		label.modulate = Color(1, 0.9, 0.3)  # 金黄
	
	# 黑色描边/阴影效果：用 OutlineLabel 或双层 Label
	# 简版：加 LabelSettings outline
	var label_settings := LabelSettings.new()
	label_settings.font_size = label.get_theme_font_size("font_size")
	label_settings.font_color = label.modulate
	label_settings.outline_size = 2
	label_settings.outline_color = Color(0, 0, 0, 0.8)
	label_settings.shadow_size = 2
	label_settings.shadow_color = Color(0, 0, 0, 0.5)
	label.label_settings = label_settings
	
	var target_sprite: Control = enemy_sprite if is_enemy_side else hero_sprite
	var sprite_pos: Vector2 = target_sprite.global_position
	var sprite_size: Vector2 = target_sprite.size
	label.position = Vector2(
		sprite_pos.x + float(sprite_size.x) / 2.0 - label.size.x / 2.0,
		sprite_pos.y - 10
	)
	damage_container.add_child(label)
	
	# 动画：抛物线轨迹（先上后下）+ 淡出
	var tween := create_tween()
	var start_y: float = label.position.y
	
	if is_crit:
		# 暴击：缩放弹跳 + 抛物线 + 震动
		label.scale = Vector2(1.5, 1.5)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "position:y", start_y - 80, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "position:y", start_y + 20, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(label, "modulate:a", 0, 0.3)
		# 暴击额外震动
		_screen_shake()
	elif is_chain:
		# 连击：快速上飘 + 旋转
		tween.tween_property(label, "position:y", start_y - 100, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(label, "rotation", deg_to_rad(10), 0.3)
		tween.tween_property(label, "modulate:a", 0, 0.4)
	else:
		# 普通伤害：抛物线
		tween.tween_property(label, "position:y", start_y - 60, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "position:y", start_y + 10, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(label, "modulate:a", 0, 0.3)
	
	tween.tween_callback(label.queue_free)

func _flash_sprite(unit_id: String) -> void:
	var is_enemy: bool = not (unit_id == "hero" or unit_id.begins_with("hero"))
	var sprite: Control = enemy_sprite if is_enemy else hero_sprite
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)

func _flash_partner_icon(_partner_name: String) -> void:
	pass

func _screen_shake() -> void:
	var viewport := get_viewport()
	var original_transform := viewport.canvas_transform
	var tween := create_tween()
	# 复合震动：作用于整个视口，而非面板本身
	for i in range(6):
		var offset := Vector2(randf_range(-8, 8), randf_range(-4, 4))
		tween.tween_callback(func() -> void:
			viewport.canvas_transform = original_transform.translated(offset)
		)
		tween.tween_interval(0.03)
	tween.tween_callback(func() -> void:
		viewport.canvas_transform = original_transform
	)

func _on_skip() -> void:
	print("[BattleAnimation] 跳过按钮点击, gen=%d" % _playback_generation)
	_is_playing = false
	turn_timer.stop()
	_show_result()

func _show_result() -> void:
	_is_playing = false
	turn_timer.stop()
	if _result_emitted:
		print("[BattleAnimation] _show_result 已发射过 confirmed，跳过")
		return
	# 调试日志：记录调用位置
	print("[Battle] _show_result at index=%d, total=%d" % [_current_turn_index, _turn_keys.size()])
	
	_result_emitted = true
	bottom_hint.append_text("\n[color=yellow]=== 战斗结束 ===[/color]")
	print("[BattleAnimation] _show_result 发射 confirmed, gen=%d" % _playback_generation)
	confirmed.emit()

func reset_panel() -> void:
	_is_playing = false
	turn_timer.stop()
	_current_turn_index = 0
	_turn_keys = []
	_events_by_turn = {}
	bottom_hint.text = ""
	turn_label.text = "回合 1"
	turn_label.modulate = Color(1, 1, 1)
	_is_frenzy_active = false
	_clear_damage_numbers()
	# 重置血条到满血（由 start_playback 重新设置）
	_hero_hp = _hero_max_hp
	_enemy_hp = _enemy_max_hp
	_update_hp_display()

func _clear_damage_numbers() -> void:
	for child in damage_container.get_children():
		child.queue_free()


func _setup_hero_hp_bar_style(bar: ProgressBar) -> void:
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.2, 0.8, 0.3)
	fg.corner_radius_top_left = 4
	fg.corner_radius_top_right = 4
	fg.corner_radius_bottom_left = 4
	fg.corner_radius_bottom_right = 4
	fg.border_width_left = 2
	fg.border_width_top = 2
	fg.border_width_right = 2
	fg.border_width_bottom = 2
	fg.border_color = Color(0.1, 0.4, 0.15, 0.8)
	
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	
	bar.add_theme_stylebox_override("fill", fg)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_constant_override("separation", 0)


func _setup_enemy_hp_bar_style(bar: ProgressBar) -> void:
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.85, 0.15, 0.15)
	fg.corner_radius_top_left = 4
	fg.corner_radius_top_right = 4
	fg.corner_radius_bottom_left = 4
	fg.corner_radius_bottom_right = 4
	fg.border_width_left = 2
	fg.border_width_top = 2
	fg.border_width_right = 2
	fg.border_width_bottom = 2
	fg.border_color = Color(0.5, 0.05, 0.05, 0.9)
	
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.05, 0.05, 0.8)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	
	bar.add_theme_stylebox_override("fill", fg)
	bar.add_theme_stylebox_override("background", bg)
