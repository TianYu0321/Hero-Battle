@tool
extends ProgrammaticTheme

const UPDATE_ON_SAVE = true
const VERBOSITY = Verbosity.QUIET

# ==========================================
# 赛璐璐手绘风配色 (Cel-shaded Chibi Style)
# ==========================================
# 参考：暖色纸张底、马克笔颜色、木质边框、圆润手感

# --- 纸张/背景层 ---
var bg_paper     = Color(0.18, 0.14, 0.10)   # 暖棕纸色 (深)
var bg_panel     = Color(0.26, 0.20, 0.14)   # 面板纸色
var bg_highlight = Color(0.36, 0.28, 0.20)   # 高亮/悬停

# --- 文字色 ---
var text_main    = Color(0.96, 0.92, 0.86)   # 暖白主文字
var text_second  = Color(0.78, 0.72, 0.64)   # 次要文字
var text_label   = Color(0.55, 0.48, 0.40)   # 标签/禁用

# --- 马克笔阵营色 ---
var red_main  = Color(0.86, 0.32, 0.28)   # 珊瑚红（敌方/伤害）
var red_deep  = Color(0.52, 0.16, 0.14)   # 红暗面
var blue_main = Color(0.28, 0.60, 0.82)   # 天蓝（我方/英雄）
var blue_deep = Color(0.14, 0.32, 0.48)   # 蓝暗面
var gold      = Color(0.95, 0.72, 0.25)   # 柠檬金（强调/奖励）

# --- 辅助色 ---
var green_main = Color(0.35, 0.75, 0.45)  # 薄荷绿（治疗/正面）
var purple_main = Color(0.65, 0.40, 0.80) # 紫罗兰（Chain/魔法）

# --- 圆角参数 ---
var corner_rounded  = corner_radius(12)    # 通用圆角
nvar corner_soft    = corner_radius(8)     # 小圆角
var corner_pill     = corner_radius(20)    # 胶囊圆角（按钮、血条）

var default_font_size = 16

func setup():
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("themes"):
		dir.make_dir("themes")
	if not dir.dir_exists("themes/generated"):
		dir.make_dir("themes/generated")
	set_save_path("res://themes/generated/dark_theme.tres")

func define_theme():
	define_default_font_size(default_font_size)
	
	# ==========================================
	# 通用 StyleBox
	# ==========================================
	var panel_style = stylebox_flat({
		bg_color = bg_panel,
		corner_radius = corner_rounded,
		border_ = border_width(2),
		border_color = Color(0.45, 0.35, 0.25),
		shadow_color = Color(0.08, 0.06, 0.04, 0.5),
		shadow_size = 4,
		shadow_offset = Vector2(2, 3)
	})
	var highlight_style = stylebox_flat({
		bg_color = bg_highlight,
		corner_radius = corner_rounded,
		border_ = border_width(2),
		border_color = Color(0.55, 0.45, 0.35),
		shadow_color = Color(0.08, 0.06, 0.04, 0.4),
		shadow_size = 3,
		shadow_offset = Vector2(1, 2)
	})
	var deep_style = stylebox_flat({
		bg_color = bg_paper,
		corner_radius = corner_rounded,
		border_ = border_width(2),
		border_color = Color(0.35, 0.25, 0.18),
	})
	
	# ==========================================
	# Label
	# ==========================================
	define_style("Label", {
		font_color = text_main,
		font_size = default_font_size
	})
	
	# ==========================================
	# Button（手绘粗边框 + 按压反馈）
	# ==========================================
	var button_style = stylebox_flat({
		bg_color = bg_highlight,
		corner_radius = corner_pill,
		border_ = border_width(3),
		border_color = Color(0.60, 0.50, 0.38),
		content_margin_ = content_margins(10, 6)
	})
	var button_hover = inherit(button_style, {
		bg_color = Color(0.42, 0.32, 0.24),
		border_color = gold,
		shadow_color = Color(gold.r, gold.g, gold.b, 0.3),
		shadow_size = 6
	})
	var button_pressed = inherit(button_style, {
		bg_color = bg_paper,
		border_color = red_main,
		shadow_size = 0,
		shadow_offset = Vector2(0, 0)
	})
	var button_disabled = inherit(button_style, {
		bg_color = Color(0.20, 0.16, 0.12),
		border_color = Color(0.35, 0.28, 0.22),
		bg_color.a = 0.6
	})
	define_style("Button", {
		font_color = text_main,
		font_hover_color = gold,
		font_pressed_color = red_main,
		font_disabled_color = text_label,
		font_size = default_font_size,
		normal = button_style,
		hover = button_hover,
		pressed = button_pressed,
		disabled = button_disabled
	})
	
	# ==========================================
	# ProgressBar（血条/经验条）
	# ==========================================
	# 背景槽
	var hp_bg = stylebox_flat({
		bg_color = bg_paper,
		corner_radius = corner_pill,
		border_ = border_width(2),
		border_color = Color(0.40, 0.30, 0.22)
	})
	# 前景填充（通用，代码里按阵营覆盖颜色）
	var hp_fg = stylebox_flat({
		bg_color = blue_main,
		corner_radius = corner_pill
	})
	define_style("ProgressBar", {
		font_color = text_second,
		font_size = 12,
		background = hp_bg,
		fill = hp_fg
	})
	
	# ==========================================
	# Panel / PanelContainer
	# ==========================================
	define_style("Panel", {
		panel = panel_style
	})
	define_style("PanelContainer", {
		panel = panel_style
	})
	
	# ==========================================
	# LineEdit
	# ==========================================
	var line_edit_normal = stylebox_flat({
		bg_color = bg_paper,
		corner_radius = corner_soft,
		border_ = border_width(2),
		border_color = Color(0.50, 0.40, 0.30),
		content_margin_ = content_margins(8, 5)
	})
	var line_edit_focus = inherit(line_edit_normal, {
		border_color = blue_main
	})
	define_style("LineEdit", {
		font_color = text_main,
		normal = line_edit_normal,
		focus = line_edit_focus,
		read_only = inherit(line_edit_normal, {bg_color = Color(0.15, 0.12, 0.08)})
	})
	
	# ==========================================
	# RichTextLabel
	# ==========================================
	define_style("RichTextLabel", {
		font_color = text_main,
		font_size = default_font_size
	})
	
	# ==========================================
	# 自定义颜色常量（供代码里动态读取）
	# ==========================================
	current_theme.set_color("bg_paper",     "custom", bg_paper)
	current_theme.set_color("bg_panel",     "custom", bg_panel)
	current_theme.set_color("text_main",    "custom", text_main)
	current_theme.set_color("text_second",  "custom", text_second)
	current_theme.set_color("text_label",   "custom", text_label)
	current_theme.set_color("red_main",     "custom", red_main)
	current_theme.set_color("red_deep",     "custom", red_deep)
	current_theme.set_color("blue_main",    "custom", blue_main)
	current_theme.set_color("blue_deep",    "custom", blue_deep)
	current_theme.set_color("gold",         "custom", gold)
	current_theme.set_color("green_main",   "custom", green_main)
	current_theme.set_color("purple_main",  "custom", purple_main)
