@tool
extends ProgrammaticTheme

const UPDATE_ON_SAVE = true
const VERBOSITY = Verbosity.QUIET

# === 语义化颜色 ===
var bg_deep = Color(0.024, 0.012, 0.047)       # 最深层背景
var bg_panel = Color(0.035, 0.020, 0.055)      # 面板背景
var bg_highlight = Color(0.047, 0.031, 0.071)  # 高亮背景

var text_main = Color(0.90, 0.90, 0.92)        # 主文字
var text_second = Color(0.68, 0.68, 0.71)     # 次要文字
var text_label = Color(0.45, 0.45, 0.48)        # 标签文字

var red_main = Color(0.85, 0.22, 0.15)          # 红方（敌人）
var red_deep = Color(0.35, 0.06, 0.04)          # 红方暗
var blue_main = Color(0.25, 0.55, 0.85)        # 蓝方（英雄）
var blue_deep = Color(0.08, 0.18, 0.35)         # 蓝方暗
var gold = Color(0.90, 0.75, 0.35)              # 暗金强调

var default_font_size = 16

func setup():
	# 确保目录存在
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("themes"):
		dir.make_dir("themes")
	if not dir.dir_exists("themes/generated"):
		dir.make_dir("themes/generated")
	set_save_path("res://themes/generated/dark_theme.tres")

func define_theme():
	define_default_font_size(default_font_size)
	
	# === 通用 StyleBox ===
	var panel_style = stylebox_flat({
		bg_color = bg_panel,
		corner_radius = corner_radius(0)
	})
	var highlight_style = stylebox_flat({
		bg_color = bg_highlight,
		corner_radius = corner_radius(0)
	})
	var deep_style = stylebox_flat({
		bg_color = bg_deep,
		corner_radius = corner_radius(0)
	})
	
	# === Label ===
	define_style("Label", {
		font_color = text_main,
		font_size = default_font_size
	})
	
	# === Button ===
	var button_style = stylebox_flat({
		bg_color = bg_highlight,
		corner_radius = corner_radius(0),
		border_ = border_width(1),
		border_color = text_label
	})
	var button_hover = inherit(button_style, {
		bg_color = bg_panel,
		border_color = gold
	})
	var button_pressed = inherit(button_style, {
		bg_color = bg_deep,
		border_color = red_main
	})
	define_style("Button", {
		font_color = text_main,
		font_hover_color = gold,
		font_pressed_color = red_main,
		font_size = default_font_size,
		normal = button_style,
		hover = button_hover,
		pressed = button_pressed
	})
	
	# === ProgressBar（血条通用） ===
	define_style("ProgressBar", {
		font_color = text_second,
		font_size = 12
	})
	
	# === Panel ===
	define_style("Panel", {
		panel = panel_style
	})
	define_style("PanelContainer", {
		panel = panel_style
	})
	
	# === 自定义颜色常量（供代码里动态读取） ===
	current_theme.set_color("bg_deep", "custom", bg_deep)
	current_theme.set_color("bg_panel", "custom", bg_panel)
	current_theme.set_color("text_main", "custom", text_main)
	current_theme.set_color("text_second", "custom", text_second)
	current_theme.set_color("text_label", "custom", text_label)
	current_theme.set_color("red_main", "custom", red_main)
	current_theme.set_color("red_deep", "custom", red_deep)
	current_theme.set_color("blue_main", "custom", blue_main)
	current_theme.set_color("blue_deep", "custom", blue_deep)
	current_theme.set_color("gold", "custom", gold)
