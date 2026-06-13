## res://scripts/core/party_assemble_settings.gd
## 模块: PartyAssembleSettings
## 职责: 酒馆集结界面的全局配置（布局尺寸/圆角从 JSON 加载，颜色/动画保留常量）
## 依赖: 无
## class_name: PartyAssembleSettings

class_name PartyAssembleSettings
extends RefCounted

## ========== 队伍规模 ==========
const MAX_TEAM_SIZE := 7

## ========== 卡片尺寸（从 JSON 加载）==========
static var CARD_WIDTH: int = 200
static var CARD_HEIGHT: int = 280
static var CARD_AVATAR_SIZE: int = 120
static var SLOT_CARD_WIDTH: int = 180
static var SLOT_CARD_HEIGHT: int = 240
static var SLOT_AVATAR_SIZE: int = 96

## ========== 动画时长（参考 UiCard motion speed）==========
const HOVER_DURATION := 0.15
const SELECT_DURATION := 0.2
const ENTRANCE_DURATION := 0.35
const TRANSITION_DURATION := 0.4
const FADE_DURATION := 0.12

## ========== 悬停参数（参考 UiCard hovered height/size）==========
const HOVER_SCALE := Vector2(1.08, 1.08)
const HOVER_LIFT_Y := -12
const HOVER_SHADOW_EXPAND := 12

## ========== 基础色（MainMenu-MP White主题）==========
const COLOR_BG_PANEL := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_BG_SELECTED := Color(0.96, 0.98, 1.0, 1.0)
const COLOR_BORDER := Color(0.85, 0.85, 0.85, 1.0)
const COLOR_BORDER_HOVER := Color(0.4, 0.6, 1.0, 1.0)
const COLOR_BORDER_SELECTED := Color(0.25, 0.55, 0.95, 1.0)

## ========== 文字色 ==========
const COLOR_TEXT_MAIN := Color(0.2, 0.2, 0.2, 1.0)
const COLOR_TEXT_SECOND := Color(0.5, 0.5, 0.5, 1.0)
const COLOR_TEXT_HOVER := Color(0.4, 0.6, 1.0, 1.0)
const COLOR_TEXT_GOLD := Color(0.85, 0.65, 0.15, 1.0)
const COLOR_TEXT_DISABLED := Color(0.5, 0.5, 0.52, 0.6)

## ========== 五维色 ==========
const STAT_COLORS: Dictionary = {
	"vit": Color(0.25, 0.75, 0.70, 1),
	"str": Color(0.90, 0.35, 0.30, 1),
	"agi": Color(0.90, 0.70, 0.20, 1),
	"tec": Color(0.25, 0.55, 0.85, 1),
	"mnd": Color(0.60, 0.35, 0.70, 1),
}

## ========== 阴影系统（MainMenu-MP标准）==========
const SHADOW_CARD_NORMAL := {"size": 6, "offset": Vector2(0, 2), "color": Color(0, 0, 0, 0.08)}
const SHADOW_CARD_HOVER := {"size": 12, "offset": Vector2(0, 4), "color": Color(0.4, 0.6, 1.0, 0.15)}
const SHADOW_CARD_SELECTED := {"size": 16, "offset": Vector2(0, 6), "color": Color(0.25, 0.55, 0.95, 0.2)}
const SHADOW_PANEL := {"size": 15, "offset": Vector2(0, 8), "color": Color(0, 0, 0, 0.12)}

## ========== 圆角（从 JSON 加载）==========
static var RADIUS_CARD: int = 12
static var RADIUS_PANEL: int = 16
static var RADIUS_BUTTON: int = 8
static var RADIUS_AVATAR: int = 8

## ========== 背景 ==========
const COLOR_BG_SCENE := Color(0.96, 0.97, 0.99, 1)
const BG_TEXTURE_MODULATE := Color(0.88, 0.92, 0.98, 0.4)

## ========== 拳皇99风格布局常量（从 JSON 加载）==========
static var ICON_CELL_WIDTH: int = 80
static var ICON_CELL_HEIGHT: int = 80
static var ICON_AVATAR_WIDTH: int = 64
static var ICON_AVATAR_HEIGHT: int = 64
static var ICON_NAME_HEIGHT: int = 16
static var GRID_COLUMNS: int = 5
static var GRID_H_SEPARATION: int = 8
static var GRID_V_SEPARATION: int = 8

static var PORTRAIT_SIZE: Vector2 = Vector2(520, 520)
static var TEAM_BAR_HEIGHT: int = 90
static var TEAM_SLOT_SIZE: Vector2 = Vector2(80, 80)
static var DETAIL_PANEL_HEIGHT: int = 220

static func _static_init() -> void:
	var json: Dictionary = _load_layout_json()
	if json.is_empty():
		return
	
	var layout: Dictionary = json.get("layout", {})
	
	CARD_WIDTH = int(layout.get("card_width", CARD_WIDTH))
	CARD_HEIGHT = int(layout.get("card_height", CARD_HEIGHT))
	CARD_AVATAR_SIZE = int(layout.get("card_avatar_size", CARD_AVATAR_SIZE))
	SLOT_CARD_WIDTH = int(layout.get("slot_card_width", SLOT_CARD_WIDTH))
	SLOT_CARD_HEIGHT = int(layout.get("slot_card_height", SLOT_CARD_HEIGHT))
	SLOT_AVATAR_SIZE = int(layout.get("slot_avatar_size", SLOT_AVATAR_SIZE))
	
	ICON_CELL_WIDTH = int(layout.get("icon_cell_width", ICON_CELL_WIDTH))
	ICON_CELL_HEIGHT = int(layout.get("icon_cell_height", ICON_CELL_HEIGHT))
	ICON_AVATAR_WIDTH = int(layout.get("icon_avatar_width", ICON_AVATAR_WIDTH))
	ICON_AVATAR_HEIGHT = int(layout.get("icon_avatar_height", ICON_AVATAR_HEIGHT))
	ICON_NAME_HEIGHT = int(layout.get("icon_name_height", ICON_NAME_HEIGHT))
	GRID_COLUMNS = int(layout.get("grid_columns", GRID_COLUMNS))
	GRID_H_SEPARATION = int(layout.get("grid_h_separation", GRID_H_SEPARATION))
	GRID_V_SEPARATION = int(layout.get("grid_v_separation", GRID_V_SEPARATION))
	
	var portrait_w: int = int(layout.get("portrait_width", 520))
	var portrait_h: int = int(layout.get("portrait_height", 520))
	PORTRAIT_SIZE = Vector2(portrait_w, portrait_h)
	
	TEAM_BAR_HEIGHT = int(layout.get("team_bar_height", TEAM_BAR_HEIGHT))
	
	var team_slot_w: int = int(layout.get("team_slot_width", 80))
	var team_slot_h: int = int(layout.get("team_slot_height", 80))
	TEAM_SLOT_SIZE = Vector2(team_slot_w, team_slot_h)
	
	DETAIL_PANEL_HEIGHT = int(layout.get("detail_panel_height", DETAIL_PANEL_HEIGHT))
	
	RADIUS_AVATAR = int(layout.get("radius_avatar", RADIUS_AVATAR))
	RADIUS_CARD = int(layout.get("radius_card", RADIUS_CARD))
	RADIUS_PANEL = int(layout.get("radius_panel", RADIUS_PANEL))
	RADIUS_BUTTON = int(layout.get("radius_button", RADIUS_BUTTON))

static func _load_layout_json() -> Dictionary:
	var file_path := "res://resources/configs/party_assemble_layout.json"
	if not FileAccess.file_exists(file_path):
		push_warning("[PartyAssembleSettings] 布局配置文件不存在，使用默认值: %s" % file_path)
		return {}
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("[PartyAssembleSettings] 无法读取布局配置文件")
		return {}
	
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	
	if result != OK:
		push_warning("[PartyAssembleSettings] 解析布局配置文件失败")
		return {}
	
	var parsed: Variant = json.get_data()
	if parsed is Dictionary:
		return parsed as Dictionary
	
	push_warning("[PartyAssembleSettings] 布局配置文件根节点必须是对象")
	return {}
