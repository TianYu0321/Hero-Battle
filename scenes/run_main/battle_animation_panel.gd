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

var _frenzy_border: ColorRect = null
var _frenzy_tween: Tween = null
var _hero_id_hint: int = 1
var _enemy_type_hint: String = ""
var _is_boss_hint: bool = false

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
	_setup_shader_hp_bars()
	_setup_frenzy_border()
	_setup_placeholder_draw()

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
	var hero_ratio: float = float(_hero_hp) / maxi(1, _hero_max_hp)
	var enemy_ratio: float = float(_enemy_hp) / maxi(1, _enemy_max_hp)
	
	# 通过shader uniform更新进度
	if hero_hp_bar.material != null:
		hero_hp_bar.material.set_shader_parameter("progress", hero_ratio)
		hero_hp_bar.material.set_shader_parameter("flash_speed", 5.0 if (hero_ratio < 0.3 and not _is_frenzy_active) else 0.0)
	if enemy_hp_bar.material != null:
		enemy_hp_bar.material.set_shader_parameter("progress", enemy_ratio)
		enemy_hp_bar.material.set_shader_parameter("flash_speed", 0.0)
	
	# 狂暴阶段血条变红提示（shader已处理颜色，这里保留modulate作为额外强调）
	if _is_frenzy_active:
		hero_hp_bar.modulate = Color(1, 0.5, 0.5)
		enemy_hp_bar.modulate = Color(1, 0.5, 0.5)
		_start_frenzy_border_pulse()
	else:
		hero_hp_bar.modulate = Color(1, 1, 1)
		enemy_hp_bar.modulate = Color(1, 1, 1)
		_stop_frenzy_border_pulse()

func _show_damage_number(damage: int, is_crit: bool, is_enemy_side: bool, is_chain: bool = false, chain_count: int = 0) -> void:
	if not GameManager.damage_numbers_enabled:
		return
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var target_sprite: Control = enemy_sprite if is_enemy_side else hero_sprite
	var sprite_pos: Vector2 = target_sprite.global_position
	var sprite_size: Vector2 = target_sprite.size
	
	if is_chain:
		label.text = "CHAIN x%d! %d" % [chain_count, damage]
		label.add_theme_font_size_override("font_size", 28)
		label.modulate = Color(0.8, 0.2, 1.0)  # 紫色
		
		# 连锁动画：旋转上飘 + 淡出
		label.position = Vector2(
			sprite_pos.x + sprite_size.x / 2.0 - 40,
			sprite_pos.y - 10
		)
		damage_container.add_child(label)
		
		var tween := create_tween()
		tween.tween_property(label, "position:y", label.position.y - 100, 0.8)
		tween.parallel().tween_property(label, "rotation", 0.17, 0.8)  # 10度
		tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
		tween.tween_callback(label.queue_free)
		
	elif is_crit:
		label.text = str(damage)
		label.add_theme_font_size_override("font_size", 36)
		label.modulate = Color(1, 0.2, 0.2)  # 鲜红
		
		# 暴击动画：缩放弹跳
		label.position = Vector2(
			sprite_pos.x + sprite_size.x / 2.0 - 20,
			sprite_pos.y - 10
		)
		label.scale = Vector2.ZERO
		damage_container.add_child(label)
		
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2.ONE * 1.5, 0.15)
		tween.tween_property(label, "scale", Vector2.ONE, 0.1)
		tween.tween_property(label, "position:y", label.position.y - 80, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "modulate:a", 0, 0.3)
		tween.tween_callback(label.queue_free)
		
		# 屏幕震动
		_screen_shake()
		
	else:
		label.text = str(damage)
		label.add_theme_font_size_override("font_size", 26)
		label.modulate = Color(1, 0.9, 0.4)  # 金黄
		
		# 普通动画：抛物线上飘
		label.position = Vector2(
			sprite_pos.x + sprite_size.x / 2.0 - 15,
			sprite_pos.y - 10
		)
		damage_container.add_child(label)
		
		var tween := create_tween()
		var start_y: float = label.position.y
		tween.tween_property(label, "position:y", start_y - 60, 0.5)
		tween.tween_property(label, "position:y", start_y - 50, 0.3)
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(label.queue_free)
	
	# 统一描边
	var label_settings := LabelSettings.new()
	label_settings.font_size = label.get_theme_font_size("font_size")
	label_settings.font_color = label.modulate
	label_settings.outline_size = 2
	label_settings.outline_color = Color(0, 0, 0, 0.8)
	label_settings.shadow_size = 2
	label_settings.shadow_color = Color(0, 0, 0, 0.5)
	label.label_settings = label_settings

func _flash_sprite(unit_id: String) -> void:
	var is_enemy: bool = not (unit_id == "hero" or unit_id.begins_with("hero"))
	var sprite: Control = enemy_sprite if is_enemy else hero_sprite
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)

func _flash_partner_icon(_partner_name: String) -> void:
	pass

func _screen_shake() -> void:
	if not GameManager.screen_shake_enabled:
		return
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


# ==================== Shader HP Bars ====================

func _setup_shader_hp_bars() -> void:
	var shader := load("res://shaders/health_bar.gdshader")
	if shader == null:
		push_warning("[BattleAnimation] 血条shader加载失败")
		return
	
	var hero_mat := ShaderMaterial.new()
	hero_mat.shader = shader
	hero_hp_bar.material = hero_mat
	
	var enemy_mat := ShaderMaterial.new()
	enemy_mat.shader = shader
	enemy_hp_bar.material = enemy_mat


# ==================== Frenzy Border Pulse ====================

func _setup_frenzy_border() -> void:
	_frenzy_border = ColorRect.new()
	_frenzy_border.name = "FrenzyBorder"
	_frenzy_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frenzy_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frenzy_border.color = Color(1, 0, 0, 0)
	add_child(_frenzy_border)
	move_child(_frenzy_border, 1)

func _start_frenzy_border_pulse() -> void:
	if _frenzy_border == null:
		return
	_frenzy_border.visible = true
	# 停止旧动画
	if _frenzy_tween != null:
		_frenzy_tween.kill()
	_frenzy_tween = create_tween().set_loops()
	_frenzy_tween.tween_property(_frenzy_border, "color:a", 0.3, 0.5)
	_frenzy_tween.tween_property(_frenzy_border, "color:a", 0.0, 0.5)

func _stop_frenzy_border_pulse() -> void:
	if _frenzy_border == null:
		return
	_frenzy_border.visible = false
	_frenzy_border.color = Color(1, 0, 0, 0)
	if _frenzy_tween != null:
		_frenzy_tween.kill()
		_frenzy_tween = null


# ==================== Placeholder Draw ====================

func _setup_placeholder_draw() -> void:
	hero_sprite.draw.connect(_on_draw_hero_placeholder)
	enemy_sprite.draw.connect(_on_draw_enemy_placeholder)
	hero_sprite.queue_redraw()
	enemy_sprite.queue_redraw()

func _on_draw_hero_placeholder() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, hero_sprite.size)
	_draw_hero_placeholder(rect, _hero_id_hint, _hero_hp > 0)

func _on_draw_enemy_placeholder() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, enemy_sprite.size)
	_draw_enemy_placeholder(rect, _enemy_type_hint, _is_boss_hint)

func _draw_hero_placeholder(rect: Rect2, hero_id: int, is_alive: bool) -> void:
	var color: Color = Color(0.2, 0.6, 0.9) if is_alive else Color(0.3, 0.3, 0.3)
	var center: Vector2 = rect.position + rect.size / 2
	var radius: float = min(rect.size.x, rect.size.y) / 2 - 8
	
	# 外圈发光边框
	hero_sprite.draw_circle(center, radius + 4, Color(color.r, color.g, color.b, 0.3))
	# 主体圆形
	hero_sprite.draw_circle(center, radius, color)
	# 内部几何图案区分英雄
	match hero_id:
		2:  # 影舞者 - 六角星
			_draw_star(hero_sprite, center, radius * 0.5, 6, Color.WHITE)
		3:  # 铁卫 - 方块
			var r2 = radius * 0.4
			hero_sprite.draw_rect(Rect2(center - Vector2(r2, r2), Vector2(r2 * 2, r2 * 2)), Color.WHITE)
		_:  # 默认/战士 - 十字
			hero_sprite.draw_line(center - Vector2(radius * 0.4, 0), center + Vector2(radius * 0.4, 0), Color.WHITE, 3)
			hero_sprite.draw_line(center - Vector2(0, radius * 0.4), center + Vector2(0, radius * 0.4), Color.WHITE, 3)
	
	# 死亡时加X标记
	if not is_alive:
		hero_sprite.draw_line(center - Vector2(radius * 0.5, radius * 0.5), center + Vector2(radius * 0.5, radius * 0.5), Color.RED, 4)
		hero_sprite.draw_line(center + Vector2(-radius * 0.5, radius * 0.5), center + Vector2(radius * 0.5, -radius * 0.5), Color.RED, 4)

func _draw_enemy_placeholder(rect: Rect2, enemy_type: String, is_boss: bool) -> void:
	var color: Color
	match enemy_type:
		"slime": color = Color(0.4, 0.8, 0.2)
		"demon": color = Color(0.8, 0.2, 0.2)
		"heavy": color = Color(0.5, 0.5, 0.6)
		_: color = Color(0.6, 0.1, 0.1)
	
	if is_boss:
		color = Color(0.9, 0.1, 0.9)
	
	var center: Vector2 = rect.position + rect.size / 2
	var radius: float = min(rect.size.x, rect.size.y) / 2 - 8
	
	# 外圈
	enemy_sprite.draw_circle(center, radius + (6 if is_boss else 3), Color(color.r, color.g, color.b, 0.5))
	# 主体
	enemy_sprite.draw_circle(center, radius, color)
	# Boss加皇冠标记
	if is_boss:
		var crown_points: Array[Vector2] = [
			center + Vector2(0, -radius * 0.7),
			center + Vector2(-radius * 0.25, -radius * 0.4),
			center + Vector2(radius * 0.25, -radius * 0.4)
		]
		enemy_sprite.draw_polygon(crown_points, PackedColorArray([Color(1, 0.84, 0)]))
		# 眼睛
		enemy_sprite.draw_circle(center + Vector2(-radius * 0.3, -radius * 0.1), radius * 0.15, Color(1, 1, 1))
		enemy_sprite.draw_circle(center + Vector2(radius * 0.3, -radius * 0.1), radius * 0.15, Color(1, 1, 1))
	else:
		# 普通敌人眼睛
		enemy_sprite.draw_circle(center + Vector2(-radius * 0.25, -radius * 0.1), radius * 0.12, Color(0.1, 0.1, 0.1))
		enemy_sprite.draw_circle(center + Vector2(radius * 0.25, -radius * 0.1), radius * 0.12, Color(0.1, 0.1, 0.1))

func _draw_star(canvas: Control, center: Vector2, outer_radius: float, points: int, color: Color) -> void:
	var polygon: Array[Vector2] = []
	var inner_radius: float = outer_radius * 0.4
	for i in range(points * 2):
		var angle: float = PI / 2 + i * PI / points
		var r: float = outer_radius if i % 2 == 0 else inner_radius
		polygon.append(center + Vector2(cos(angle), -sin(angle)) * r)
	canvas.draw_polygon(polygon, PackedColorArray([color]))
