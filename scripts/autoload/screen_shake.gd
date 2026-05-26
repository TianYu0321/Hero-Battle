## res://scripts/autoload/screen_shake.gd
## 模块: ScreenShake
## 职责: 屏幕震动（trauma衰减模型 + FastNoiseLite）
## 参考: KidsCanCode Godot 4 Screen Shake + Sparkle Lite
## 依赖: 无
## 被依赖: FeedbackManager, 战斗场景

extends Node

signal shake_started(amount: float)
signal shake_ended()

@export var decay: float = 3.0
@export var max_offset: Vector2 = Vector2(30, 20)
@export var max_rotation: float = 2.0

var _trauma: float = 0.0
var _trauma_power: int = 2
var _noise: FastNoiseLite = null
var _noise_y: float = 0.0
var _camera: Camera2D = null
var _original_offset: Vector2 = Vector2.ZERO
var _is_shaking: bool = false

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 0.5
	
	get_tree().node_added.connect(_on_node_added)
	_find_camera()
	set_process(false)

func _on_node_added(node: Node) -> void:
	if node is Camera2D:
		_camera = node
		_original_offset = node.offset

func _find_camera() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var cameras := tree.get_nodes_in_group("shake_camera")
	if cameras.size() > 0:
		_camera = cameras[0]
		_original_offset = _camera.offset
	else:
		var current := tree.current_scene
		if current != null:
			var cam := current.find_child("Camera2D", true, false)
			if cam is Camera2D:
				_camera = cam
				_original_offset = cam.offset

func add_trauma(amount: float) -> void:
	if not GameManager.screen_shake_enabled:
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)
	if not _is_shaking and _trauma > 0:
		_is_shaking = true
		shake_started.emit(_trauma)
		set_process(true)

func shake_once(direction: Vector2, strength: float, duration: float) -> void:
	if _camera == null:
		_find_camera()
	if _camera == null:
		return
	
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var offset := -direction.normalized() * strength
	tween.tween_property(_camera, "offset", _original_offset + offset, duration * 0.3)
	tween.tween_property(_camera, "offset", _original_offset, duration * 0.7).set_trans(Tween.TRANS_ELASTIC)

func _process(delta: float) -> void:
	if _camera == null:
		_find_camera()
		if _camera == null:
			return
	
	if _trauma > 0:
		_trauma = maxf(_trauma - decay * delta, 0.0)
		_apply_shake()
	else:
		_is_shaking = false
		_camera.offset = _original_offset
		_camera.rotation_degrees = 0
		set_process(false)
		shake_ended.emit()

func _apply_shake() -> void:
	var amount := pow(_trauma, _trauma_power)
	_noise_y += 1
	
	## 使用不同的种子偏移获取独立的噪声通道，实现真正的 2D 采样
	var seed_off_x := _noise.seed + 1000
	var seed_off_y := _noise.seed + 2000
	var seed_off_r := _noise.seed + 3000
	
	var offset_x := max_offset.x * amount * _noise.get_noise_2d(seed_off_x + _noise_y, _noise_y * 0.7)
	var offset_y := max_offset.y * amount * _noise.get_noise_2d(seed_off_y + _noise_y * 0.7, _noise_y)
	var rotation := max_rotation * amount * _noise.get_noise_2d(seed_off_r + _noise_y * 0.5, _noise_y * 0.3)
	
	_camera.offset = _original_offset + Vector2(offset_x, offset_y)
	_camera.rotation_degrees = rotation
