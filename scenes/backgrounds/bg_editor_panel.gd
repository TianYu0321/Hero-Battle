extends PanelContainer

## 运行时背景编辑器 - 按 F7 呼出/隐藏

var _target_bg: Control = null
var _sliders: Dictionary = {}
var _layer_vbox: VBoxContainer = null
var _current_stage_label: Label = null
var _base_check: CheckBox = null

func setup(target_bg: Control) -> void:
	_target_bg = target_bg
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size = Vector2(420, 720)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 700)
	add_child(scroll)
	
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	scroll.add_child(main)
	
	# 标题
	var title := Label.new()
	title.text = "背景编辑器 (F7隐藏)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	main.add_child(title)
	
	# 当前阶段
	_current_stage_label = Label.new()
	_current_stage_label.text = "当前: 森林 (1-10层)"
	_current_stage_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	main.add_child(_current_stage_label)
	
	# 阶段预览按钮
	var stage_hbox := HBoxContainer.new()
	stage_hbox.add_theme_constant_override("separation", 4)
	main.add_child(stage_hbox)
	for s_name in ["森林", "城堡", "露台"]:
		var btn := Button.new()
		btn.text = s_name
		btn.custom_minimum_size = Vector2(90, 32)
		btn.pressed.connect(_on_preview_stage.bind(s_name))
		stage_hbox.add_child(btn)
	
	# 显示底图开关
	var base_hbox := HBoxContainer.new()
	base_hbox.add_theme_constant_override("separation", 4)
	main.add_child(base_hbox)
	_base_check = CheckBox.new()
	_base_check.text = "显示底图"
	_base_check.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_base_check.pressed.connect(_on_base_visible_toggled)
	base_hbox.add_child(_base_check)
	
	_add_separator(main, "图层设置 (深度 / 大小 / 位置 / 漂移 / 顺序)")
	_layer_vbox = VBoxContainer.new()
	_layer_vbox.add_theme_constant_override("separation", 6)
	main.add_child(_layer_vbox)
	
	_add_separator(main, "雾效")
	_add_slider(main, "雾透明度", 0.0, 0.3, 0.01, "fog_alpha")
	_add_slider(main, "雾R", 0.0, 1.0, 0.01, "fog_r")
	_add_slider(main, "雾G", 0.0, 1.0, 0.01, "fog_g")
	_add_slider(main, "雾B", 0.0, 1.0, 0.01, "fog_b")
	
	_add_separator(main, "落叶/飘雪粒子")
	_add_slider(main, "粒子数量", 0, 200, 1, "particle_amount")
	_add_slider(main, "粒子速度", 0, 100, 1, "particle_speed")
	_add_slider(main, "粒子大小", 0.1, 3.0, 0.1, "particle_size")
	
	_add_separator(main, "蝙蝠飞行")
	_add_slider(main, "飞行速度", 0, 300, 5, "flyer_speed")
	_add_slider(main, "飞行高度", 0, 600, 10, "flyer_y")
	_add_slider(main, "波浪幅度", 0, 150, 5, "flyer_amp")
	
	_add_separator(main, "自动漂移")
	_add_slider(main, "漂移速度", 0.0, 2.0, 0.1, "drift_speed")
	_add_slider(main, "漂移幅度", 0, 60, 1, "drift_amp")
	
	_add_separator(main, "")
	var save_btn := Button.new()
	save_btn.text = "保存到 JSON"
	save_btn.custom_minimum_size = Vector2(200, 40)
	var save_style := StyleBoxFlat.new()
	save_style.bg_color = Color(0.15, 0.35, 0.15)
	save_style.corner_radius_top_left = 6
	save_style.corner_radius_top_right = 6
	save_style.corner_radius_bottom_left = 6
	save_style.corner_radius_bottom_right = 6
	save_btn.add_theme_stylebox_override("normal", save_style)
	save_btn.pressed.connect(_on_save)
	main.add_child(save_btn)

func _add_separator(parent: VBoxContainer, text: String) -> void:
	if not text.is_empty():
		var label := Label.new()
		label.text = text
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		label.add_theme_font_size_override("font_size", 12)
		parent.add_child(label)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(380, 1)
	line.color = Color(0.25, 0.25, 0.3, 0.5)
	parent.add_child(line)

func _add_slider(parent: VBoxContainer, label_text: String, min_v: float, max_v: float, step: float, key: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)
	
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(90, 24)
	label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(label)
	
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = min_v
	slider.custom_minimum_size = Vector2(140, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)
	
	var val_label := Label.new()
	val_label.text = str(min_v)
	val_label.custom_minimum_size = Vector2(40, 24)
	val_label.add_theme_font_size_override("font_size", 11)
	hbox.add_child(val_label)
	
	slider.value_changed.connect(_on_slider_changed.bind(key, val_label))
	_sliders[key] = slider

func refresh_layer_sliders() -> void:
	if _target_bg == null:
		return
	# 清除旧图层控件
	for child in _layer_vbox.get_children():
		child.queue_free()
	
	var layers: Array = _target_bg._stage_config.get(_target_bg._current_stage, {}).get("layers", [])
	var sprites: Array[Sprite2D] = _target_bg._parallax_sprites
	
	for i in range(layers.size()):
		var layer_data: Dictionary = layers[i]
		var sprite: Sprite2D = sprites[i] if i < sprites.size() else null
		
		# 图层标题行
		var title_hbox := HBoxContainer.new()
		title_hbox.add_theme_constant_override("separation", 4)
		_layer_vbox.add_child(title_hbox)
		
		var name_label := Label.new()
		name_label.text = "L%d %s" % [i, layer_data.get("path", "").get_file()]
		name_label.custom_minimum_size = Vector2(140, 22)
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		title_hbox.add_child(name_label)
		
		# 上移按钮
		if i > 0:
			var up_btn := Button.new()
			up_btn.text = "▲"
			up_btn.custom_minimum_size = Vector2(28, 22)
			up_btn.pressed.connect(_on_layer_move.bind(i, -1))
			title_hbox.add_child(up_btn)
		
		# 下移按钮
		if i < layers.size() - 1:
			var down_btn := Button.new()
			down_btn.text = "▼"
			down_btn.custom_minimum_size = Vector2(28, 22)
			down_btn.pressed.connect(_on_layer_move.bind(i, 1))
			title_hbox.add_child(down_btn)
		
		# 深度滑块
		var depth_hbox := HBoxContainer.new()
		depth_hbox.add_theme_constant_override("separation", 4)
		_layer_vbox.add_child(depth_hbox)
		
		var depth_label := Label.new()
		depth_label.text = "深度"
		depth_label.custom_minimum_size = Vector2(40, 22)
		depth_label.add_theme_font_size_override("font_size", 11)
		depth_hbox.add_child(depth_label)
		
		var depth_slider := HSlider.new()
		depth_slider.min_value = 0.0
		depth_slider.max_value = 2.0
		depth_slider.step = 0.05
		depth_slider.value = layer_data.get("depth", 0.5)
		depth_slider.custom_minimum_size = Vector2(100, 22)
		depth_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		depth_hbox.add_child(depth_slider)
		
		var depth_val := Label.new()
		depth_val.text = "%.2f" % depth_slider.value
		depth_val.custom_minimum_size = Vector2(36, 22)
		depth_val.add_theme_font_size_override("font_size", 11)
		depth_hbox.add_child(depth_val)
		
		depth_slider.value_changed.connect(_on_layer_depth_changed.bind(i, depth_val))
		
		# 大小滑块 (乘数)
		var scale_hbox := HBoxContainer.new()
		scale_hbox.add_theme_constant_override("separation", 4)
		_layer_vbox.add_child(scale_hbox)
		
		var scale_label := Label.new()
		scale_label.text = "大小"
		scale_label.custom_minimum_size = Vector2(40, 22)
		scale_label.add_theme_font_size_override("font_size", 11)
		scale_hbox.add_child(scale_label)
		
		var scale_slider := HSlider.new()
		scale_slider.min_value = 0.1
		scale_slider.max_value = 3.0
		scale_slider.step = 0.05
		var current_scale: float = layer_data.get("scale", 1.0)
		scale_slider.value = current_scale
		scale_slider.custom_minimum_size = Vector2(100, 22)
		scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scale_hbox.add_child(scale_slider)
		
		var scale_val := Label.new()
		scale_val.text = "%.2f" % scale_slider.value
		scale_val.custom_minimum_size = Vector2(36, 22)
		scale_val.add_theme_font_size_override("font_size", 11)
		scale_hbox.add_child(scale_val)
		
		scale_slider.value_changed.connect(_on_layer_scale_changed.bind(i, scale_val))
		
		# 位置 X 滑块
		var posx_hbox := HBoxContainer.new()
		posx_hbox.add_theme_constant_override("separation", 4)
		_layer_vbox.add_child(posx_hbox)
		
		var posx_label := Label.new()
		posx_label.text = "X偏移"
		posx_label.custom_minimum_size = Vector2(40, 22)
		posx_label.add_theme_font_size_override("font_size", 11)
		posx_hbox.add_child(posx_label)
		
		var posx_slider := HSlider.new()
		posx_slider.min_value = -3000.0
		posx_slider.max_value = 3000.0
		posx_slider.step = 1.0
		posx_slider.value = layer_data.get("offset_x", 0.0)
		posx_slider.custom_minimum_size = Vector2(100, 22)
		posx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		posx_hbox.add_child(posx_slider)
		
		var posx_val := Label.new()
		posx_val.text = str(int(posx_slider.value))
		posx_val.custom_minimum_size = Vector2(36, 22)
		posx_val.add_theme_font_size_override("font_size", 11)
		posx_hbox.add_child(posx_val)
		
		posx_slider.value_changed.connect(_on_layer_pos_changed.bind(i, "offset_x", posx_val))
		
		# 位置 Y 滑块
		var posy_hbox := HBoxContainer.new()
		posy_hbox.add_theme_constant_override("separation", 4)
		_layer_vbox.add_child(posy_hbox)
		
		var posy_label := Label.new()
		posy_label.text = "Y偏移"
		posy_label.custom_minimum_size = Vector2(40, 22)
		posy_label.add_theme_font_size_override("font_size", 11)
		posy_hbox.add_child(posy_label)
		
		var posy_slider := HSlider.new()
		posy_slider.min_value = -3000.0
		posy_slider.max_value = 3000.0
		posy_slider.step = 1.0
		posy_slider.value = layer_data.get("offset_y", 0.0)
		posy_slider.custom_minimum_size = Vector2(100, 22)
		posy_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		posy_hbox.add_child(posy_slider)
		
		var posy_val := Label.new()
		posy_val.text = str(int(posy_slider.value))
		posy_val.custom_minimum_size = Vector2(36, 22)
		posy_val.add_theme_font_size_override("font_size", 11)
		posy_hbox.add_child(posy_val)
		
		posy_slider.value_changed.connect(_on_layer_pos_changed.bind(i, "offset_y", posy_val))
		
		# 漂移相位滑块
		var phase_hbox := HBoxContainer.new()
		phase_hbox.add_theme_constant_override("separation", 4)
		_layer_vbox.add_child(phase_hbox)
		
		var phase_label := Label.new()
		phase_label.text = "漂移相位"
		phase_label.custom_minimum_size = Vector2(56, 22)
		phase_label.add_theme_font_size_override("font_size", 11)
		phase_hbox.add_child(phase_label)
		
		var phase_slider := HSlider.new()
		phase_slider.min_value = 0.0
		phase_slider.max_value = 6.28
		phase_slider.step = 0.1
		phase_slider.value = layer_data.get("drift_phase", i * 0.7)
		phase_slider.custom_minimum_size = Vector2(84, 22)
		phase_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		phase_hbox.add_child(phase_slider)
		
		var phase_val := Label.new()
		phase_val.text = "%.1f" % phase_slider.value
		phase_val.custom_minimum_size = Vector2(36, 22)
		phase_val.add_theme_font_size_override("font_size", 11)
		phase_hbox.add_child(phase_val)
		
		phase_slider.value_changed.connect(_on_layer_drift_phase_changed.bind(i, phase_val))
		
		# 漂移幅度滑块
		var damp_hbox := HBoxContainer.new()
		damp_hbox.add_theme_constant_override("separation", 4)
		_layer_vbox.add_child(damp_hbox)
		
		var damp_label := Label.new()
		damp_label.text = "漂移幅度"
		damp_label.custom_minimum_size = Vector2(56, 22)
		damp_label.add_theme_font_size_override("font_size", 11)
		damp_hbox.add_child(damp_label)
		
		var damp_slider := HSlider.new()
		damp_slider.min_value = 0.0
		damp_slider.max_value = 3.0
		damp_slider.step = 0.05
		damp_slider.value = layer_data.get("drift_amp", 1.0)
		damp_slider.custom_minimum_size = Vector2(84, 22)
		damp_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		damp_hbox.add_child(damp_slider)
		
		var damp_val := Label.new()
		damp_val.text = "%.2f" % damp_slider.value
		damp_val.custom_minimum_size = Vector2(36, 22)
		damp_val.add_theme_font_size_override("font_size", 11)
		damp_hbox.add_child(damp_val)
		
		damp_slider.value_changed.connect(_on_layer_drift_amp_changed.bind(i, damp_val))
		
		# 分隔线
		var sep := ColorRect.new()
		sep.custom_minimum_size = Vector2(380, 1)
		sep.color = Color(0.2, 0.2, 0.25, 0.4)
		_layer_vbox.add_child(sep)

func sync_from_bg() -> void:
	if _target_bg == null:
		return
	var stage_names := {0: "森林 (1-10层)", 1: "城堡 (11-20层)", 2: "露台 (21-30层)"}
	_current_stage_label.text = "当前: " + stage_names.get(_target_bg._current_stage, "未知")
	refresh_layer_sliders()
	
	var cfg: Dictionary = _target_bg._stage_config.get(_target_bg._current_stage, {})
	if _base_check != null:
		_base_check.button_pressed = cfg.get("base_visible", true)
	var fc: Color = cfg.get("fog_color", Color.GRAY)
	_set_slider("fog_alpha", cfg.get("fog_alpha", 0.05))
	_set_slider("fog_r", fc.r)
	_set_slider("fog_g", fc.g)
	_set_slider("fog_b", fc.b)
	
	_set_slider("particle_amount", float(cfg.get("particle_amount", _target_bg.effect_particles.amount)))
	_set_slider("particle_speed", cfg.get("particle_speed", _target_bg.effect_particles.initial_velocity_max))
	_set_slider("particle_size", cfg.get("particle_size", _target_bg.effect_particles.scale_amount_max))
	
	_set_slider("flyer_speed", cfg.get("flyer_speed", _target_bg.get_meta("flyer_speed", 90.0)))
	_set_slider("flyer_y", cfg.get("flyer_y", _target_bg.get_meta("flyer_y", 200.0)))
	_set_slider("flyer_amp", cfg.get("flyer_amp", _target_bg.get_meta("flyer_amp", 35.0)))
	_set_slider("drift_speed", cfg.get("drift_speed", _target_bg.get_meta("drift_speed", 0.3)))
	_set_slider("drift_amp", cfg.get("drift_amp", _target_bg.get_meta("drift_amp", 1.0)))

func _set_slider(key: String, value: float) -> void:
	var slider: HSlider = _sliders.get(key)
	if slider == null:
		return
	slider.value = value
	var hbox: HBoxContainer = slider.get_parent()
	if hbox == null or hbox.get_child_count() < 3:
		return
	var val_label: Label = hbox.get_child(2)
	match key:
		"fog_alpha", "fog_r", "fog_g", "fog_b":
			val_label.text = "%.2f" % value
		"particle_size", "drift_speed", "drift_amp":
			val_label.text = "%.1f" % value
		_:
			val_label.text = str(int(value)) if abs(value - round(value)) < 0.001 else str(value)

func _update_fog_color() -> void:
	var cfg: Dictionary = _target_bg._stage_config.get(_target_bg._current_stage, {})
	var fc: Color = cfg.get("fog_color", Color.GRAY)
	var fog_img := Image.create(int(_target_bg._screen_size.x), int(_target_bg._screen_size.y), false, Image.FORMAT_RGBA8)
	fog_img.fill(fc)
	_target_bg.fog_overlay.texture = ImageTexture.create_from_image(fog_img)

func _on_slider_changed(value: float, key: String, val_label: Label) -> void:
	val_label.text = str(value)
	if _target_bg == null:
		return
	var cfg: Dictionary = _target_bg._stage_config.get(_target_bg._current_stage, {})
	match key:
		"fog_alpha":
			_target_bg.fog_overlay.modulate.a = value
			cfg["fog_alpha"] = value
		"fog_r", "fog_g", "fog_b":
			var c: Color = cfg.get("fog_color", Color.GRAY)
			match key:
				"fog_r": c.r = value
				"fog_g": c.g = value
				"fog_b": c.b = value
			cfg["fog_color"] = c
			_target_bg.fog_overlay.modulate = Color(1, 1, 1, cfg.get("fog_alpha", 0.05))
			_update_fog_color()
		"particle_amount":
			_target_bg.effect_particles.amount = int(value)
			cfg["particle_amount"] = int(value)
		"particle_speed":
			_target_bg.effect_particles.initial_velocity_max = value
			_target_bg.effect_particles.initial_velocity_min = value * 0.3
			cfg["particle_speed"] = value
		"particle_size":
			_target_bg.effect_particles.scale_amount_max = value
			_target_bg.effect_particles.scale_amount_min = value * 0.4
			cfg["particle_size"] = value
		"flyer_speed":
			_target_bg.set_meta("flyer_speed", value)
			cfg["flyer_speed"] = value
		"flyer_y":
			_target_bg.set_meta("flyer_y", value)
			cfg["flyer_y"] = value
		"flyer_amp":
			_target_bg.set_meta("flyer_amp", value)
			cfg["flyer_amp"] = value
		"drift_speed":
			_target_bg.set_meta("drift_speed", value)
			cfg["drift_speed"] = value
		"drift_amp":
			_target_bg.set_meta("drift_amp", value)
			cfg["drift_amp"] = value

func _on_layer_depth_changed(value: float, index: int, val_label: Label) -> void:
	val_label.text = "%.2f" % value
	if _target_bg == null:
		return
	var cfg: Dictionary = _target_bg._stage_config.get(_target_bg._current_stage, {})
	var layers: Array = cfg.get("layers", [])
	if index < layers.size():
		layers[index]["depth"] = value

func _on_layer_scale_changed(value: float, index: int, val_label: Label) -> void:
	val_label.text = "%.2f" % value
	if _target_bg == null:
		return
	var cfg: Dictionary = _target_bg._stage_config.get(_target_bg._current_stage, {})
	var layers: Array = cfg.get("layers", [])
	if index < layers.size():
		layers[index]["scale"] = value
	
	var sprites: Array[Sprite2D] = _target_bg._parallax_sprites
	if index >= sprites.size() or not is_instance_valid(sprites[index]):
		return
	var sprite: Sprite2D = sprites[index]
	var tex_w: float = sprite.texture.get_width() if sprite.texture else 1.0
	var base_scale: float = _target_bg._screen_size.x / tex_w
	sprite.scale = Vector2(base_scale * value, base_scale * value)
	# 重新计算 Y 位置（因为大小变了，base_y 也会变）
	var tex_h: float = sprite.texture.get_height() if sprite.texture else 0.0
	var base_y: float = _target_bg._screen_size.y - tex_h * base_scale * value
	var off_x: float = layers[index].get("offset_x", 0.0)
	var off_y: float = layers[index].get("offset_y", 0.0)
	sprite.position = Vector2(off_x, base_y + off_y)

func _on_layer_pos_changed(value: float, index: int, key: String, val_label: Label) -> void:
	val_label.text = str(int(value))
	if _target_bg == null:
		return
	var cfg: Dictionary = _target_bg._stage_config.get(_target_bg._current_stage, {})
	var layers: Array = cfg.get("layers", [])
	if index >= layers.size():
		return
	layers[index][key] = value
	
	var sprites: Array[Sprite2D] = _target_bg._parallax_sprites
	if index >= sprites.size() or not is_instance_valid(sprites[index]):
		return
	var sprite: Sprite2D = sprites[index]
	
	# 重新计算基础位置 + 新偏移
	var tex_h: float = sprite.texture.get_height() if sprite.texture else 0.0
	var tex_w: float = sprite.texture.get_width() if sprite.texture else 1.0
	var base_scale: float = _target_bg._screen_size.x / tex_w
	var layer_scale: float = layers[index].get("scale", 1.0)
	var base_y: float = _target_bg._screen_size.y - tex_h * base_scale * layer_scale
	var off_x: float = layers[index].get("offset_x", 0.0)
	var off_y: float = layers[index].get("offset_y", 0.0)
	sprite.position = Vector2(off_x, base_y + off_y)

func _on_layer_drift_phase_changed(value: float, index: int, val_label: Label) -> void:
	val_label.text = "%.1f" % value
	if _target_bg == null:
		return
	var cfg: Dictionary = _target_bg._stage_config.get(_target_bg._current_stage, {})
	var layers: Array = cfg.get("layers", [])
	if index < layers.size():
		layers[index]["drift_phase"] = value

func _on_layer_drift_amp_changed(value: float, index: int, val_label: Label) -> void:
	val_label.text = "%.2f" % value
	if _target_bg == null:
		return
	var cfg: Dictionary = _target_bg._stage_config.get(_target_bg._current_stage, {})
	var layers: Array = cfg.get("layers", [])
	if index < layers.size():
		layers[index]["drift_amp"] = value

func _on_layer_move(index: int, direction: int) -> void:
	if _target_bg == null:
		return
	var cfg: Dictionary = _target_bg._stage_config.get(_target_bg._current_stage, {})
	var layers: Array = cfg.get("layers", [])
	var sprites: Array[Sprite2D] = _target_bg._parallax_sprites
	var container: Node2D = _target_bg.parallax_container
	
	var new_index: int = index + direction
	if new_index < 0 or new_index >= layers.size():
		return
	
	# 先交换场景树中的子节点顺序（在交换数组引用之前）
	if is_instance_valid(sprites[index]):
		container.move_child(sprites[index], new_index)
	
	# 再交换配置数组
	var tmp_cfg: Dictionary = layers[index]
	layers[index] = layers[new_index]
	layers[new_index] = tmp_cfg
	
	# 再交换精灵引用数组
	var tmp_sprite: Sprite2D = sprites[index]
	sprites[index] = sprites[new_index]
	sprites[new_index] = tmp_sprite
	
	# 刷新UI
	refresh_layer_sliders()

func _on_base_visible_toggled() -> void:
	if _target_bg == null:
		return
	var cfg: Dictionary = _target_bg._stage_config.get(_target_bg._current_stage, {})
	var visible: bool = not _target_bg.base_layer.visible
	_target_bg.base_layer.visible = visible
	cfg["base_visible"] = visible

func _on_preview_stage(stage_name: String) -> void:
	if _target_bg == null:
		return
	var stage_map := {"森林": 0, "城堡": 1, "露台": 2}
	var stage: int = stage_map.get(stage_name, 0)
	_target_bg.load_stage_for_floor(1 if stage == 0 else 11 if stage == 1 else 21)
	sync_from_bg()

func _on_save() -> void:
	if _target_bg == null:
		return
	var json_data := {"stages": {}}
	for s_key in [0, 1, 2]:
		var s_name: String = {0: "forest", 1: "castle", 2: "terrace"}[s_key]
		var cfg: Dictionary = _target_bg._stage_config.get(s_key, {})
		var layers: Array = []
		for layer in cfg.get("layers", []):
			layers.append({
				"path": layer.get("path", ""),
				"depth": layer.get("depth", 0.5),
				"scale": layer.get("scale", 1.0),
				"offset_x": layer.get("offset_x", 0.0),
				"offset_y": layer.get("offset_y", 0.0),
				"drift_phase": layer.get("drift_phase", 0.0),
				"drift_amp": layer.get("drift_amp", 1.0)
			})
		var fc: Color = cfg.get("fog_color", Color.GRAY)
		json_data["stages"][s_name] = {
			"base": cfg.get("base", ""),
			"base_visible": cfg.get("base_visible", true),
			"layers": layers,
			"effect": cfg.get("effect", ""),
			"fog_color": [fc.r, fc.g, fc.b, fc.a],
			"fog_alpha": cfg.get("fog_alpha", 0.05),
			"flyer_enabled": cfg.get("flyer_enabled", false),
			"flyer_speed": cfg.get("flyer_speed", 90.0),
			"flyer_y": cfg.get("flyer_y", 200.0),
			"flyer_amp": cfg.get("flyer_amp", 35.0),
			"drift_speed": cfg.get("drift_speed", 0.3),
			"drift_amp": cfg.get("drift_amp", 1.0),
			"particle_amount": cfg.get("particle_amount", 30),
			"particle_speed": cfg.get("particle_speed", 30.0),
			"particle_size": cfg.get("particle_size", 2.0)
		}
	
	var file := FileAccess.open(_target_bg.CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(json_data, "\t"))
		file.close()
		print("[BgEditor] 配置已保存到: " + _target_bg.CONFIG_PATH)
	else:
		push_error("[BgEditor] 保存失败")
