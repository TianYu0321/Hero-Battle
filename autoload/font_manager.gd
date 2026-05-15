extends Node

## FontManager — 全局字体管理
## 从 res://assets/fonts/ 加载 Cinzel/Oxanium/NotoSansSC
## 提供按用途获取字体的方法，支持 fallback 到系统字体

var _title_font: FontFile = null   # Cinzel — 展示/标题/角色名
var _number_font: FontFile = null  # Oxanium — 数字/血条/数据
var _body_font: FontFile = null    # Noto Sans SC — 中文正文/按钮/日志

const FONT_DIR := "res://assets/fonts/"

func _ready() -> void:
	_load_all_fonts()

func _load_all_fonts() -> void:
	_title_font = _try_load_font("Cinzel-Bold.ttf")
	if _title_font == null:
		_title_font = _try_load_font("Cinzel-SemiBold.ttf")
	
	_number_font = _try_load_font("Oxanium-Bold.ttf")
	if _number_font == null:
		_number_font = _try_load_font("Oxanium-SemiBold.ttf")
	if _number_font == null:
		_number_font = _try_load_font("Oxanium-Medium.ttf")
	
	_body_font = _try_load_font("NotoSansSC-Bold.otf")
	if _body_font == null:
		_body_font = _try_load_font("NotoSansSC-Regular.otf")
	
	print("[FontManager] 字体加载: title=%s, number=%s, body=%s" % [
		_title_font != null, _number_font != null, _body_font != null
	])

func _try_load_font(filename: String) -> FontFile:
	var path: String = FONT_DIR + filename
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is FontFile:
			return res as FontFile
	return null

func _get_fallback_font() -> Font:
	return SystemFont.new()

# ============================================================================
# 公共 API
# ============================================================================

## 获取标题字体（Cinzel），用于角色名、大标题
func get_title_font() -> Font:
	return _title_font if _title_font != null else _get_fallback_font()

## 获取数字字体（Oxanium），用于血条数值、伤害数字、回合数
func get_number_font() -> Font:
	return _number_font if _number_font != null else _get_fallback_font()

## 获取正文字体（Noto Sans SC），用于按钮、日志、描述文字
func get_body_font() -> Font:
	return _body_font if _body_font != null else _get_fallback_font()

# ============================================================================
# 便捷应用方法
# ============================================================================

## 为 Label 设置字体和大小
func apply_label(label: Label, type: String, size: int) -> void:
	match type:
		"title":
			label.add_theme_font_override("font", get_title_font())
		"number":
			label.add_theme_font_override("font", get_number_font())
		_:
			label.add_theme_font_override("font", get_body_font())
	label.add_theme_font_size_override("font_size", size)

## 为 Button 设置字体
func apply_button(button: Button, size: int = 16) -> void:
	button.add_theme_font_override("font", get_body_font())
	button.add_theme_font_size_override("font_size", size)

## 为 RichTextLabel 设置字体
func apply_rich_text(rtl: RichTextLabel, size: int = 14) -> void:
	rtl.add_theme_font_override("normal_font", get_body_font())
	rtl.add_theme_font_override("bold_font", get_title_font())
	rtl.add_theme_font_size_override("normal_font_size", size)
	rtl.add_theme_font_size_override("bold_font_size", size + 2)

## 为 ProgressBar 设置字体（血条上方的数值标签）
func apply_progress_bar(bar: ProgressBar, size: int = 12) -> void:
	bar.add_theme_font_override("font", get_number_font())
	bar.add_theme_font_size_override("font_size", size)

# ============================================================================
# 批量应用 — 递归设置 Control 下所有子节点的字体
# ============================================================================

## 递归应用字体到整个控件树
func apply_to_tree(root: Control) -> void:
	_apply_recursive(root)

func _apply_recursive(node: Node) -> void:
	if node is Label:
		var label: Label = node as Label
		var text: String = label.text
		if _is_number_string(text):
			apply_label(label, "number", label.get_theme_font_size("font_size"))
		elif label.get_theme_font_size("font_size") >= 20:
			apply_label(label, "title", label.get_theme_font_size("font_size"))
		else:
			apply_label(label, "body", label.get_theme_font_size("font_size"))
	
	elif node is Button:
		apply_button(node as Button, (node as Button).get_theme_font_size("font_size"))
	
	elif node is RichTextLabel:
		apply_rich_text(node as RichTextLabel, (node as RichTextLabel).get_theme_font_size("normal_font_size"))
	
	elif node is ProgressBar:
		apply_progress_bar(node as ProgressBar, (node as ProgressBar).get_theme_font_size("font_size"))
	
	for child in node.get_children():
		_apply_recursive(child)

func _is_number_string(s: String) -> bool:
	if s.is_empty():
		return false
	var cleaned: String = s.strip_edges()
	for prefix in ["HP:", "金币:", "层数:", "生命:", "回合:", "预计损失:", "-", "+"]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length()).strip_edges()
			break
	var has_digit: bool = false
	for c in cleaned:
		if c.is_valid_int():
			has_digit = true
			break
	return has_digit and (cleaned.is_valid_int() or cleaned.is_valid_float() or cleaned.contains("/"))
