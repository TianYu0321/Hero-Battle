## res://scripts/core/party_assemble_settings.gd
## 模块: PartyAssembleSettings
## 职责: 酒馆集结界面的全局配置常量（参考 card-framework 集中配置模式）
## 依赖: 无
## class_name: PartyAssembleSettings

class_name PartyAssembleSettings
extends RefCounted

## ========== 队伍规模 ==========
const MAX_TEAM_SIZE := 3

## ========== 卡片尺寸（像素精确值）==========
const CARD_WIDTH := 200
const CARD_HEIGHT := 280
const CARD_AVATAR_SIZE := 120            ## 卡片内头像正方形
const SLOT_CARD_WIDTH := 180
const SLOT_CARD_HEIGHT := 240
const SLOT_AVATAR_SIZE := 96

## ========== 动画时长（参考 UiCard motion speed）==========
const HOVER_DURATION := 0.15            ## 悬停动画 0.15s（card-framework标准）
const SELECT_DURATION := 0.2            ## 选中弹跳 0.2s
const ENTRANCE_DURATION := 0.35         ## 入场动画 0.35s
const TRANSITION_DURATION := 0.4        ## 场景切换 0.4s
const FADE_DURATION := 0.12             ## 立绘淡入淡出

## ========== 悬停参数（参考 UiCard hovered height/size）==========
const HOVER_SCALE := Vector2(1.08, 1.08)     ## 悬停放大1.08x
const HOVER_LIFT_Y := -12                     ## 悬停上浮12px（卡片厚度感）
const HOVER_SHADOW_EXPAND := 12               ## 悬停阴影扩散到12px

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
const COLOR_TEXT_DISABLED := Color(0.5, 0.5, 0.52, 0.6)   ## 参考UiCard disabled透明度

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

## ========== 圆角 ==========
const RADIUS_CARD := 12                    ## 卡片圆角
const RADIUS_PANEL := 16                   ## 面板圆角（弹窗感）
const RADIUS_BUTTON := 8                   ## 按钮圆角
const RADIUS_AVATAR := 8                   ## 头像框圆角

## ========== 背景 ==========
const COLOR_BG_SCENE := Color(0.96, 0.97, 0.99, 1)
const BG_TEXTURE_MODULATE := Color(0.88, 0.92, 0.98, 0.4)
