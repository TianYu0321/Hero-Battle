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
			elif is_crit:
				bottom_hint.append_text("[color=red]%s → %s 暴击 %d！[/color]  " % [actor, target, value])
			else:
				bottom_hint.append_text("%s → %s %d  " % [actor, target, value])
		
		"unit_damaged":
			var unit_id: String = data.get("unit_id", "")
			var damage: int = data.get("damage", 0)
			var hp: int = data.get("hp", 0)
			var is_crit: bool = data.get("is_crit", false)
			
			if unit_id == "hero" or unit_id.begins_with("hero"):
				_hero_hp = maxi(0, hp)
				_update_hp_display()
				_show_damage_number(damage, is_crit, false)
			else:
				_enemy_hp = maxi(0, hp)
				_update_hp_display()
				_show_damage_number(damage, is_crit, true)
			
			_flash_sprite(unit_id)
		
		"unit_died":
			var uname: String = data.get("name", "???")
			bottom_hint.append_text("[color=red]%s 被击败！[/color]  " % uname)
		
		"partner_assist":
			var pname: String = data.get("partner_name", "???")
			bottom_hint.append_text("[color=cyan]%s 援助！[/color]  " % pname)
			_flash_partner_icon(pname)
		
		"chain_triggered":
			var chain_count: int = data.get("chain_count", 0)
			var pname: String = data.get("partner_name", "???")
			var dmg: int = data.get("damage", 0)
			bottom_hint.append_text("[color=purple]CHAIN x%d! %s %d[/color]  " % [chain_count, pname, dmg])
		
		"ultimate_triggered":
			var log_text: String = data.get("log", "")
			bottom_hint.append_text("[color=gold]%s[/color]  " % log_text)
			_screen_shake()
		
		"frenzy_triggered":
			_is_frenzy_active = true
			var msg: String = data.get("message", "狂暴阶段触发！")
			bottom_hint.append_text("\n[color=red]★ %s ★[/color]\n" % msg)
			_turn_label.modulate = Color(1, 0.2, 0.2)
			_update_hp_display()

func _update_hp_display() -> void:
	hero_hp_bar.value = float(_hero_hp) / maxi(1, _hero_max_hp) * 100
	enemy_hp_bar.value = float(_enemy_hp) / maxi(1, _enemy_max_hp) * 100
	
	# 狂暴阶段血条变红提示
	if _is_frenzy_active:
		hero_hp_bar.modulate = Color(1, 0.3, 0.3)
		enemy_hp_bar.modulate = Color(1, 0.3, 0.3)
	else:
		hero_hp_bar.modulate = Color(1, 1, 1)
		enemy_hp_bar.modulate = Color(1, 1, 1)

func _show_damage_number(damage: int, is_crit: bool, is_enemy_side: bool) -> void:
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_font_size_override("font_size", 32 if is_crit else 24)
	label.modulate = Color(1, 0.2, 0.2) if is_crit else Color(1, 1, 1)
	
	var target_sprite: Control = enemy_sprite if is_enemy_side else hero_sprite
	var sprite_pos: Vector2 = target_sprite.global_position
	var sprite_size: Vector2 = target_sprite.size
	label.position = Vector2(
		sprite_pos.x + float(sprite_size.x) / 2.0 - 20,
		sprite_pos.y - 10
	)
	damage_container.add_child(label)
	
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 60, 0.6)
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
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + 5, 0.05)
	tween.tween_property(self, "position:x", position.x - 5, 0.05)
	tween.tween_property(self, "position:x", position.x, 0.05)

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
	# 关键排查：看在哪个回合被调用
	push_error("[Battle] _show_result at index=%d, total=%d" % [_current_turn_index, _turn_keys.size()])
	
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
