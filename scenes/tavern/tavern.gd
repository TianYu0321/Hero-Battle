## res://scenes/tavern/tavern.gd
## 模块: TavernUI
## 职责: 展示可用伙伴，玩家选择2名首发伙伴组成初始队伍
## 依赖: EventBus, ConfigManager
## 被依赖: 无
## class_name: TavernUI

class_name TavernUI
extends Control

@onready var _partner_grid: GridContainer = %PartnerGrid
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _confirm_btn: Button = %ConfirmBtn
@onready var _back_btn: Button = %BackBtn

var _partner_ids: Array[String] = []
var _selected_partners: Array[String] = []

func _ready() -> void:
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_partner_ids = _get_available_partner_ids()
	_update_confirm_button()
	_populate_partner_slots()

func _get_available_partner_ids() -> Array[String]:
	var user_id: String = SaveManager.get_user_id()
	var unlock_state: Dictionary = SaveManager.load_unlock_state(user_id)
	var unlocked_ids: Array = unlock_state.get("unlocked_partners", [])
	var unlocked: Array = []
	for pid in unlocked_ids:
		unlocked.append(str(pid))

	var all_ids: Array[String] = ConfigManager.get_all_partner_ids()
	var result: Array[String] = []
	for pid in all_ids:
		var cfg: Dictionary = ConfigManager.get_partner_config(pid)
		var is_default: bool = cfg.get("is_default_unlock", false)
		var pid_str: String = str(cfg.get("id", ""))
		if is_default or (pid_str in unlocked):
			result.append(pid)
	return result

func _populate_partner_slots() -> void:
	var slot_index: int = 0
	for partner_id in _partner_ids:
		var config: Dictionary = ConfigManager.get_partner_config(partner_id)
		if config.is_empty():
			continue

		var slot: Control = _partner_grid.get_child(slot_index)
		if slot == null:
			continue

		var card_bg: TextureRect = slot.get_node("CardBg")
		var portrait: TextureRect = slot.get_node("Margin/VBox/Portrait")
		var name_label: Label = slot.get_node("Margin/VBox/NameLabel")
		var role_label: Label = slot.get_node("Margin/VBox/RoleLabel")
		var lv_label: Label = slot.get_node("Margin/VBox/LvLabel")
		var check_box: CheckBox = slot.get_node("Margin/VBox/SelectCheck")

		## 卡片框背景（酒馆伙伴默认 Lv.1）
		card_bg.texture = load(ConfigManager.get_partner_card_path(partner_id, 1))
		
		## 头像（优先 avatar_path → icon_path → 卡片图 fallback）
		var avatar_path: String = config.get("avatar_path", "")
		if avatar_path.is_empty():
			avatar_path = config.get("icon_path", "")
		if avatar_path.is_empty():
			avatar_path = ConfigManager.get_partner_card_path(partner_id, 1)
		var tex: Texture2D = _resolve_texture_from_path(avatar_path)
		if tex != null:
			portrait.texture = tex
		
		## 修复：使用 "name" 字段显示中文名，避免回退到 partner_id 代码 key
		name_label.text = config.get("name", partner_id)
		## 修复：使用 "title" 字段显示职业定位，并格式化为简短标签
		role_label.text = _format_role_label(config.get("title", ""))
		lv_label.text = "Lv.1"
		check_box.text = "加入队伍"
		check_box.toggled.connect(_on_partner_toggled.bind(partner_id))
		## 修复文字拥挤：增大卡片内部垂直间距
		var vbox: VBoxContainer = slot.get_node("Margin/VBox")
		vbox.add_theme_constant_override("separation", 12)
		## 点击整张卡牌即可切换选中状态（提升交互感）
		card_bg.mouse_filter = Control.MOUSE_FILTER_PASS
		card_bg.gui_input.connect(_on_card_clicked.bind(partner_id, check_box, slot))
		slot.visible = true

		slot_index += 1
	
	# 隐藏多余的伙伴槽位
	for i in range(slot_index, _partner_grid.get_child_count()):
		var slot: Control = _partner_grid.get_child(i)
		if slot != null:
			slot.visible = false

func _resolve_texture_from_path(path: String) -> Texture2D:
	## 支持 Texture2D 和 SpriteFrames（自动取第一帧）
	if path.is_empty():
		return null
	var res: Resource = load(path)
	if res == null:
		return null
	if res is Texture2D:
		return res as Texture2D
	if res is SpriteFrames:
		var frames: SpriteFrames = res
		var anim_names: PackedStringArray = frames.get_animation_names()
		for anim_name in anim_names:
			var frame_count: int = frames.get_frame_count(anim_name)
			if frame_count > 0:
				return frames.get_frame_texture(anim_name, 0)
	return null

## 将职业 title 格式化为简短标签（避免长文本挤压）
func _format_role_label(title: String) -> String:
	if title.contains("输出"):
		return "⚔️ 输出"
	elif title.contains("防御"):
		return "🛡️ 防御"
	elif title.contains("辅助"):
		return "💚 辅助"
	elif title.contains("控场"):
		return "🔮 控场"
	elif title.contains("斩杀"):
		return "⚡ 斩杀"
	return title

func _on_partner_toggled(pressed: bool, partner_id: String) -> void:
	if pressed:
		if not _selected_partners.has(partner_id):
			_selected_partners.append(partner_id)
	else:
		_selected_partners.erase(partner_id)

	_update_checkbox_states()
	_update_confirm_button()
	_animate_card_for_partner(partner_id, pressed)

## 点击卡牌任意区域切换选中
func _on_card_clicked(event: InputEvent, partner_id: String, check_box: CheckBox, _slot: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		check_box.button_pressed = not check_box.button_pressed

## 根据 partner_id 找到对应 slot 并播放选中/取消动画
func _animate_card_for_partner(partner_id: String, selected: bool) -> void:
	var slot_index: int = 0
	for pid in _partner_ids:
		if pid == partner_id:
			var slot: Control = _partner_grid.get_child(slot_index)
			if slot != null:
				_animate_card_selected(slot, selected)
			return
		slot_index += 1

## 卡牌选中/取消时的发光+微抬动画
func _animate_card_selected(slot: Control, selected: bool) -> void:
	var card_bg: TextureRect = slot.get_node("CardBg")
	var border: Panel = slot.get_node_or_null("SelectBorder")
	if border == null:
		border = Panel.new()
		border.name = "SelectBorder"
		border.anchors_preset = Control.PRESET_FULL_RECT
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = Color("#FFD700")
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		border.add_theme_stylebox_override("panel", style)
		slot.add_child(border)

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if selected:
		border.visible = true
		tween.tween_property(slot, "position:y", slot.position.y - 8, 0.2)
		tween.parallel().tween_property(card_bg, "modulate", Color(1.3, 1.3, 1.15), 0.2)
	else:
		tween.tween_property(slot, "position:y", slot.position.y + 8, 0.2)
		tween.parallel().tween_property(card_bg, "modulate", Color.WHITE, 0.2)
		tween.finished.connect(func(): border.visible = false)

func _update_checkbox_states() -> void:
	var is_full: bool = _selected_partners.size() >= 2
	var slot_index: int = 0
	for partner_id in _partner_ids:
		var slot: Control = _partner_grid.get_child(slot_index)
		if slot == null:
			continue
		var check_box: CheckBox = slot.get_node("Margin/VBox/SelectCheck")
		if not check_box.button_pressed:
			check_box.disabled = is_full
		slot_index += 1

var _confirm_breathe_tween: Tween

func _update_confirm_button() -> void:
	var count: int = _selected_partners.size()
	_subtitle_label.text = "已选择: %d/2" % count
	if count < 2:
		_subtitle_label.add_theme_color_override("font_color", Color("#E74C3C"))
	else:
		_subtitle_label.add_theme_color_override("font_color", Color("#2ECC71"))

	_confirm_btn.disabled = count != 2
	if count == 2:
		_confirm_btn.modulate = Color.WHITE
		_start_confirm_breathe()
	else:
		_stop_confirm_breathe()
		_confirm_btn.modulate = Color(1, 1, 1, 0.5)

## 确认按钮金色呼吸灯（满足 2/2 后高亮提示）
func _start_confirm_breathe() -> void:
	if _confirm_breathe_tween and _confirm_breathe_tween.is_valid():
		_confirm_breathe_tween.kill()
	_confirm_breathe_tween = create_tween().set_loops()
	_confirm_breathe_tween.tween_property(_confirm_btn, "modulate", Color("#FFEA70"), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_confirm_breathe_tween.tween_property(_confirm_btn, "modulate", Color("#B8860B"), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_confirm_breathe() -> void:
	if _confirm_breathe_tween and _confirm_breathe_tween.is_valid():
		_confirm_breathe_tween.kill()
	_confirm_breathe_tween = null

func _on_confirm_pressed() -> void:
	if _selected_partners.size() != 2:
		return
	EventBus.team_confirmed.emit(_selected_partners.duplicate())

func _on_back_pressed() -> void:
	EventBus.back_to_hero_select.emit()

func get_selected_partners() -> Array[String]:
	return _selected_partners.duplicate()
