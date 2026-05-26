## res://autoload/transition_manager.gd
## 模块: TransitionManager
## 职责: 统一管理所有场景切换过渡动画
##        支持 Fade / Dissolve / Slide / Zoom / Scale / FadeInPlace
##        支持异步加载 + Loading Screen
## 依赖: 无
## 被依赖: GameManager, 所有UI场景

extends Node

# ==========================================
# 信号
# ==========================================
signal transition_started(transition_name: String)
signal fade_complete()           ## 遮罩完全覆盖时发射（适合在中间做保存/加载）
signal scene_loaded()            ## 新场景加载完成
signal transition_finished()     ## 整个过渡完成

# ==========================================
# 枚举
# ==========================================
enum TransitionType {
	NONE,           ## 直接切换
	FADE,           ## 纯色淡入淡出
	DISSOLVE,       ## Luma Mask 溶解（procedural 或 texture-based）
	SLIDE_LEFT,     ## 左滑（新场景从右向左覆盖）
	SLIDE_RIGHT,    ## 右滑
	SLIDE_UP,       ## 上滑
	SLIDE_DOWN,     ## 下滑
	ZOOM_IN,        ## 中心放大进入
	ZOOM_OUT,       ## 中心缩小退出
	SCALE_DOWN,     ## 缩放弹窗感
	FADE_IN_PLACE,  ## 原地淡入淡出（不切换场景）
}

# ==========================================
# 配置常量
# ==========================================
const DEFAULT_FADE_DURATION := 0.2
const DEFAULT_WAIT_TIME := 0.08
const DEFAULT_EASE := Tween.EASE_IN_OUT
const DEFAULT_TRANS := Tween.TRANS_CUBIC

const DISSOLVE_SHADER := preload("res://resources/shaders/transition_dissolve.gdshader")

## 过渡配置表
const TRANSITION_CONFIG: Dictionary = {
	"boot_to_menu": {
		"type": TransitionType.FADE,
		"color": Color.BLACK,
		"duration": 0.6,
		"wait_time": 0.3,
		"ease": Tween.EASE_OUT,
	},
	"menu_to_hero_select": {
		"type": TransitionType.DISSOLVE,
		"dissolve_shape": "curtains",
		"color": Color(0.96, 0.94, 0.91, 1),
		"duration": 0.6,
		"wait_time": 0.1,
		"ease": Tween.EASE_IN_OUT,
	},
	"hero_select_to_tavern": {
		"type": TransitionType.SLIDE_LEFT,
		"color": Color(0.96, 0.94, 0.91, 1),
		"duration": 0.35,
		"wait_time": 0.05,
		"ease": Tween.EASE_OUT,
	},
	"tavern_to_run_main": {
		"type": TransitionType.FADE,
		"color": Color(0.91, 0.93, 0.96, 1),
		"duration": 0.25,
		"wait_time": 0.10,
		"ease": Tween.EASE_IN_OUT,
	},
	"run_to_battle": {
		"type": TransitionType.DISSOLVE,
		"dissolve_shape": "circle",
		"color": Color(0.1, 0.02, 0.02, 1),
		"duration": 0.25,
		"wait_time": 0.07,
		"ease": Tween.EASE_IN,
	},
	"battle_to_run": {
		"type": TransitionType.FADE,
		"color": Color(0.91, 0.93, 0.96, 1),
		"duration": 0.20,
		"wait_time": 0.05,
		"ease": Tween.EASE_OUT,
	},
	"battle_to_settlement": {
		"type": TransitionType.FADE,
		"color": Color(0.1, 0.1, 0.1, 1),
		"duration": 0.40,
		"wait_time": 0.15,
		"ease": Tween.EASE_IN_OUT,
	},
	"any_to_menu": {
		"type": TransitionType.FADE,
		"color": Color.BLACK,
		"duration": 0.4,
		"wait_time": 0.1,
		"ease": Tween.EASE_OUT,
	},
	"popup_open": {
		"type": TransitionType.SCALE_DOWN,
		"color": Color(0, 0, 0, 0.5),
		"duration": 0.15,
		"wait_time": 0,
		"ease": Tween.EASE_OUT,
	},
	"popup_close": {
		"type": TransitionType.SCALE_DOWN,
		"color": Color(0, 0, 0, 0.5),
		"duration": 0.12,
		"wait_time": 0,
		"ease": Tween.EASE_IN,
		"reverse": true,
	},
	"pause_menu": {
		"type": TransitionType.FADE_IN_PLACE,
		"color": Color(0, 0, 0, 0.6),
		"duration": 0.12,
		"wait_time": 0,
		"ease": Tween.EASE_OUT,
	},
}

# ==========================================
# 成员变量
# ==========================================
var _is_transitioning: bool = false
var _canvas_layer: CanvasLayer = null
var _overlay: ColorRect = null
var _loading_screen: Control = null
var _loading_progress_bar: ProgressBar = null

# ==========================================
# 生命周期
# ==========================================
func _ready() -> void:
	_setup_overlay()
	_setup_loading_screen()
	process_mode = Node.PROCESS_MODE_ALWAYS  ## 暂停时仍然运行

func _setup_overlay() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "TransitionCanvasLayer"
	_canvas_layer.layer = 100
	_canvas_layer.visible = false
	add_child(_canvas_layer)
	
	_overlay = ColorRect.new()
	_overlay.name = "TransitionOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0, 0, 0, 0)
	_canvas_layer.add_child(_overlay)

func _setup_loading_screen() -> void:
	_loading_screen = Control.new()
	_loading_screen.name = "LoadingScreen"
	_loading_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_screen.visible = false
	_canvas_layer.add_child(_loading_screen)
	
	var bg := ColorRect.new()
	bg.name = "LoadingBg"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	_loading_screen.add_child(bg)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_loading_screen.add_child(vbox)
	
	var label := Label.new()
	label.name = "LoadingLabel"
	label.text = "加载中..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(label)
	
	_loading_progress_bar = ProgressBar.new()
	_loading_progress_bar.name = "LoadingProgress"
	_loading_progress_bar.custom_minimum_size = Vector2(400, 20)
	_loading_progress_bar.value = 0.0
	vbox.add_child(_loading_progress_bar)


# ==========================================
# 公共 API
# ==========================================

## 切换场景（同步加载，适合小场景）
func switch_scene(scene_path: String, transition_key: String = "fade") -> bool:
	if _is_transitioning:
		push_warning("[TransitionManager] Transition already in progress, ignoring request to %s" % scene_path)
		return false
	
	var config: Dictionary = TRANSITION_CONFIG.get(transition_key, {})
	if config.is_empty():
		config = {
			"type": TransitionType.FADE,
			"color": Color.BLACK,
			"duration": DEFAULT_FADE_DURATION,
			"wait_time": DEFAULT_WAIT_TIME,
			"ease": DEFAULT_EASE,
		}
	
	await _execute_transition(scene_path, config, false)
	return true


## 切换场景（异步加载 + Loading Screen，适合大场景）
func switch_scene_async(scene_path: String, transition_key: String = "fade") -> bool:
	if _is_transitioning:
		push_warning("[TransitionManager] Transition already in progress, ignoring request to %s" % scene_path)
		return false
	
	var config: Dictionary = TRANSITION_CONFIG.get(transition_key, {})
	if config.is_empty():
		config = {
			"type": TransitionType.FADE,
			"color": Color.BLACK,
			"duration": DEFAULT_FADE_DURATION,
			"wait_time": DEFAULT_WAIT_TIME,
			"ease": DEFAULT_EASE,
		}
	
	await _execute_transition(scene_path, config, true)
	return true


## 原地淡入淡出（不切换场景，如暂停菜单打开/关闭）
func fade_in_place(fade_in: bool = true, transition_key: String = "pause_menu") -> void:
	if _is_transitioning:
		return
	
	var config: Dictionary = TRANSITION_CONFIG.get(transition_key, {})
	if config.is_empty():
		config = {
			"type": TransitionType.FADE_IN_PLACE,
			"color": Color(0, 0, 0, 0.6),
			"duration": 0.12,
			"wait_time": 0,
			"ease": Tween.EASE_OUT,
		}
	
	_is_transitioning = true
	transition_started.emit(transition_key)
	
	var color: Color = config.get("color", Color(0, 0, 0, 0.6))
	var duration: float = config.get("duration", 0.25)
	var ease_type: int = config.get("ease", Tween.EASE_OUT)
	
	_canvas_layer.visible = true
	_overlay.material = null
	_overlay.color = Color(color.r, color.g, color.b, 0.0 if fade_in else color.a)
	
	var tween := create_tween().set_trans(DEFAULT_TRANS).set_ease(ease_type)
	tween.tween_property(_overlay, "color:a", color.a if fade_in else 0.0, duration)
	await tween.finished
	
	_is_transitioning = false
	transition_finished.emit()
	
	if not fade_in:
		_canvas_layer.visible = false


## 等待过渡完成（协程用）
func await_transition() -> void:
	if not _is_transitioning:
		return
	await transition_finished


## 获取当前是否正在过渡
func is_transitioning() -> bool:
	return _is_transitioning


# ==========================================
# 核心过渡执行
# ==========================================

func _execute_transition(scene_path: String, config: Dictionary, use_async: bool) -> void:
	_is_transitioning = true
	var trans_name: String = config.get("_name", "unknown")
	transition_started.emit(trans_name)
	
	var trans_type: TransitionType = config.get("type", TransitionType.FADE)
	var color: Color = config.get("color", Color.BLACK)
	var duration: float = config.get("duration", DEFAULT_FADE_DURATION)
	var wait_time: float = config.get("wait_time", DEFAULT_WAIT_TIME)
	var ease_type: int = config.get("ease", DEFAULT_EASE)
	var is_reverse: bool = config.get("reverse", false)
	
	_canvas_layer.visible = true
	
	## Phase 1: 遮罩出现（淡入/溶解/滑入/缩放）
	await _phase_in(trans_type, color, duration, ease_type, is_reverse, config)
	
	fade_complete.emit()
	
	## Phase 2: 场景切换
	var success: bool = false
	if scene_path != "":
		if use_async:
			success = await _load_scene_async(scene_path)
		else:
			success = _load_scene_sync(scene_path)
		scene_loaded.emit()
	
	if not success and scene_path != "":
		push_error("[TransitionManager] Failed to load scene: %s" % scene_path)
		_is_transitioning = false
		transition_finished.emit()
		return
	
	## 黑屏停留（给场景 _ready 缓冲时间）
	if wait_time > 0:
		await get_tree().create_timer(wait_time).timeout
	
	## Phase 3: 遮罩消失（淡出/溶解/滑出/恢复）
	await _phase_out(trans_type, color, duration, ease_type, is_reverse, config)
	
	_is_transitioning = false
	transition_finished.emit()
	
	## 如果类型不是 FADE_IN_PLACE，隐藏 canvas_layer
	if trans_type != TransitionType.FADE_IN_PLACE:
		_canvas_layer.visible = false


# ==========================================
# Phase 1: 遮罩出现
# ==========================================

func _phase_in(trans_type: TransitionType, color: Color, duration: float, ease_type: int, is_reverse: bool, config: Dictionary) -> void:
	match trans_type:
		TransitionType.NONE:
			pass
		TransitionType.FADE:
			await _phase_fade_in(color, duration, ease_type, is_reverse)
		TransitionType.DISSOLVE:
			await _phase_dissolve_in(color, duration, ease_type, config)
		TransitionType.SLIDE_LEFT, TransitionType.SLIDE_RIGHT, TransitionType.SLIDE_UP, TransitionType.SLIDE_DOWN:
			await _phase_slide_in(trans_type, color, duration, ease_type)
		TransitionType.ZOOM_IN, TransitionType.ZOOM_OUT:
			await _phase_zoom_in(trans_type, color, duration, ease_type)
		TransitionType.SCALE_DOWN:
			await _phase_scale_in(color, duration, ease_type, is_reverse)
		TransitionType.FADE_IN_PLACE:
			await _phase_fade_in(color, duration, ease_type, false)


# ==========================================
# Phase 3: 遮罩消失
# ==========================================

func _phase_out(trans_type: TransitionType, color: Color, duration: float, ease_type: int, is_reverse: bool, config: Dictionary) -> void:
	match trans_type:
		TransitionType.NONE:
			pass
		TransitionType.FADE:
			await _phase_fade_out(color, duration, ease_type, is_reverse)
		TransitionType.DISSOLVE:
			await _phase_dissolve_out(color, duration, ease_type, config)
		TransitionType.SLIDE_LEFT, TransitionType.SLIDE_RIGHT, TransitionType.SLIDE_UP, TransitionType.SLIDE_DOWN:
			await _phase_slide_out(trans_type, color, duration, ease_type)
		TransitionType.ZOOM_IN, TransitionType.ZOOM_OUT:
			await _phase_zoom_out(trans_type, color, duration, ease_type)
		TransitionType.SCALE_DOWN:
			await _phase_scale_out(color, duration, ease_type, is_reverse)
		TransitionType.FADE_IN_PLACE:
			await _phase_fade_out(color, duration, ease_type, false)


# ==========================================
# Fade 过渡
# ==========================================

func _phase_fade_in(color: Color, duration: float, ease_type: int, is_reverse: bool) -> void:
	_overlay.material = null
	var target_alpha := 1.0 if not is_reverse else 0.0
	var start_alpha := 0.0 if not is_reverse else 1.0
	_overlay.color = Color(color.r, color.g, color.b, start_alpha)
	
	var tween := create_tween().set_trans(DEFAULT_TRANS).set_ease(ease_type)
	tween.tween_property(_overlay, "color:a", target_alpha, duration)
	await tween.finished

func _phase_fade_out(color: Color, duration: float, ease_type: int, is_reverse: bool) -> void:
	var target_alpha := 0.0 if not is_reverse else 1.0
	var start_alpha := 1.0 if not is_reverse else 0.0
	_overlay.color = Color(color.r, color.g, color.b, start_alpha)
	
	var tween := create_tween().set_trans(DEFAULT_TRANS).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay, "color:a", target_alpha, duration)
	await tween.finished


# ==========================================
# Dissolve 溶解过渡
# ==========================================

func _setup_dissolve_material(config: Dictionary, color: Color) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = DISSOLVE_SHADER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("progress", 0.0)
	
	var shape: String = config.get("dissolve_shape", "circle")
	var texture_path: String = config.get("dissolve_texture", "")
	
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		mat.set_shader_parameter("use_texture", true)
		mat.set_shader_parameter("mask_texture", load(texture_path))
	else:
		mat.set_shader_parameter("use_texture", false)
		mat.set_shader_parameter("shape_type", _shape_type_to_int(shape))
	
	_overlay.material = mat
	_overlay.color = Color(1, 1, 1, 1)

func _shape_type_to_int(shape: String) -> int:
	match shape:
		"circle": return 0
		"diamond": return 1
		"horizontal": return 2
		"vertical": return 3
		"curtains": return 4
		_: return 0

func _set_dissolve_progress(progress: float) -> void:
	if _overlay.material is ShaderMaterial:
		_overlay.material.set_shader_parameter("progress", progress)

func _phase_dissolve_in(color: Color, duration: float, ease_type: int, config: Dictionary) -> void:
	_setup_dissolve_material(config, color)
	var tween := create_tween().set_trans(DEFAULT_TRANS).set_ease(ease_type)
	tween.tween_method(func(p: float): _set_dissolve_progress(p), 0.0, 1.0, duration)
	await tween.finished

func _phase_dissolve_out(color: Color, duration: float, ease_type: int, config: Dictionary) -> void:
	## 复用已有的 material，反向溶解（中心先透明，向两边拉开）
	if _overlay.material is ShaderMaterial:
		_overlay.material.set_shader_parameter("reverse", true)
	var tween := create_tween().set_trans(DEFAULT_TRANS).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(p: float): _set_dissolve_progress(p), 0.0, 1.0, duration)
	await tween.finished
	_overlay.material = null


# ==========================================
# Slide 滑动过渡
# ==========================================

func _get_slide_offset(direction: TransitionType) -> Vector2:
	var vp_size := get_viewport().get_visible_rect().size
	match direction:
		TransitionType.SLIDE_LEFT:
			return Vector2(-vp_size.x, 0)
		TransitionType.SLIDE_RIGHT:
			return Vector2(vp_size.x, 0)
		TransitionType.SLIDE_UP:
			return Vector2(0, -vp_size.y)
		TransitionType.SLIDE_DOWN:
			return Vector2(0, vp_size.y)
	return Vector2.ZERO

func _phase_slide_in(direction: TransitionType, color: Color, duration: float, ease_type: int) -> void:
	_overlay.material = null
	var slide_offset := _get_slide_offset(direction)
	_overlay.position = -slide_offset
	_overlay.color = Color(color.r, color.g, color.b, 1.0)
	
	var tween := create_tween().set_trans(DEFAULT_TRANS).set_ease(ease_type)
	tween.tween_property(_overlay, "position", Vector2.ZERO, duration)
	await tween.finished

func _phase_slide_out(direction: TransitionType, color: Color, duration: float, ease_type: int) -> void:
	var slide_offset := _get_slide_offset(direction)
	_overlay.position = Vector2.ZERO
	_overlay.color = Color(color.r, color.g, color.b, 1.0)
	
	var tween := create_tween().set_trans(DEFAULT_TRANS).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay, "position", slide_offset, duration)
	await tween.finished
	_overlay.position = Vector2.ZERO


# ==========================================
# Zoom 缩放过渡
# ==========================================

func _phase_zoom_in(direction: TransitionType, color: Color, duration: float, ease_type: int) -> void:
	_overlay.material = null
	var start_scale := 0.0 if direction == TransitionType.ZOOM_IN else 3.0
	var end_scale := 3.0 if direction == TransitionType.ZOOM_IN else 0.0
	
	_overlay.color = Color(color.r, color.g, color.b, 1.0)
	var vp_size := get_viewport().get_visible_rect().size
	_overlay.pivot_offset = vp_size / 2
	_overlay.scale = Vector2(start_scale, start_scale)
	
	var tween := create_tween().set_trans(DEFAULT_TRANS).set_ease(ease_type)
	tween.tween_property(_overlay, "scale", Vector2(end_scale, end_scale), duration)
	await tween.finished

func _phase_zoom_out(direction: TransitionType, color: Color, duration: float, ease_type: int) -> void:
	var target_scale := Vector2.ONE
	var vp_size := get_viewport().get_visible_rect().size
	_overlay.color = Color(color.r, color.g, color.b, 1.0)
	_overlay.pivot_offset = vp_size / 2
	
	var tween := create_tween().set_trans(DEFAULT_TRANS).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay, "scale", target_scale, duration)
	tween.parallel().tween_property(_overlay, "color:a", 0.0, duration)
	await tween.finished
	_overlay.scale = Vector2.ONE


# ==========================================
# Scale 弹窗过渡
# ==========================================

func _phase_scale_in(color: Color, duration: float, ease_type: int, is_reverse: bool) -> void:
	_overlay.material = null
	var start_scale := 0.8 if not is_reverse else 1.0
	var end_scale := 1.0 if not is_reverse else 0.8
	var start_alpha := 0.0 if not is_reverse else 1.0
	var end_alpha := 1.0 if not is_reverse else 0.0
	
	_overlay.color = Color(color.r, color.g, color.b, start_alpha)
	var vp_size := get_viewport().get_visible_rect().size
	_overlay.pivot_offset = vp_size / 2
	_overlay.scale = Vector2(start_scale, start_scale)
	
	var tween := create_tween().set_trans(DEFAULT_TRANS).set_ease(ease_type)
	tween.tween_property(_overlay, "scale", Vector2(end_scale, end_scale), duration)
	tween.parallel().tween_property(_overlay, "color:a", end_alpha, duration)
	await tween.finished

func _phase_scale_out(color: Color, duration: float, ease_type: int, is_reverse: bool) -> void:
	## scale 弹窗的 _phase_out 与 _phase_in 逻辑相同（只是 reverse 参数不同）
	await _phase_scale_in(color, duration, ease_type, not is_reverse)
	if not is_reverse:
		_overlay.scale = Vector2.ONE


# ==========================================
# 场景加载
# ==========================================

func _load_scene_sync(scene_path: String) -> bool:
	var err: Error = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("[TransitionManager] Failed to change scene to %s (error: %d)" % [scene_path, err])
		return false
	return true

func _load_scene_async(scene_path: String) -> bool:
	## 显示 loading screen
	_loading_screen.visible = true
	_loading_progress_bar.value = 0.0
	
	## 发起异步加载
	var err := ResourceLoader.load_threaded_request(scene_path)
	if err != OK:
		push_error("[TransitionManager] Failed to start async load: %s" % scene_path)
		_loading_screen.visible = false
		return false
	
	## 轮询加载状态
	while true:
		var status := ResourceLoader.load_threaded_get_status(scene_path)
		match status:
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("[TransitionManager] Invalid resource: %s" % scene_path)
				_loading_screen.visible = false
				return false
			
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				var progress_arr: Array = []
				ResourceLoader.load_threaded_get_status(scene_path, progress_arr)
				_loading_progress_bar.value = progress_arr[0] * 100.0
				await get_tree().process_frame
			
			ResourceLoader.THREAD_LOAD_LOADED:
				var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path)
				var change_err := get_tree().change_scene_to_packed(packed_scene)
				_loading_screen.visible = false
				if change_err != OK:
					push_error("[TransitionManager] Failed to change scene to packed: %s" % scene_path)
					return false
				return true
			
			ResourceLoader.THREAD_LOAD_FAILED:
				push_error("[TransitionManager] Async load failed: %s" % scene_path)
				_loading_screen.visible = false
				return false
	
	return false

