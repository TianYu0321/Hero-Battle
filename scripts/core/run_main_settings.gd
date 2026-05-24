## 局内UI（爬塔主场景）集中配置
## 勇者奇幻风格：冒险者公会木牌 + 羊皮纸 + 蜡封
class_name RunMainSettings
extends RefCounted

# ============================================================
# 勇者木调配色
# ============================================================
const COLOR_WOOD_DARK := Color(0.29, 0.20, 0.14, 1.0)      # 深木底色 #4A3428
const COLOR_WOOD_MEDIUM := Color(0.45, 0.32, 0.22, 1.0)    # 中木色 #735238
const COLOR_WOOD_LIGHT := Color(0.63, 0.45, 0.32, 1.0)     # 浅木色 #A17352
const COLOR_WOOD_PANEL := Color(0.83, 0.65, 0.46, 1.0)     # 木牌面板 #D4A574
const COLOR_PARCHMENT := Color(0.96, 0.90, 0.78, 1.0)      # 羊皮纸 #F5E6C8
const COLOR_PARCHMENT_DARK := Color(0.88, 0.80, 0.65, 1.0) # 暗羊皮纸 #E0CC94
const COLOR_INK := Color(0.17, 0.09, 0.06, 1.0)            # 墨水黑 #2C1810
const COLOR_HERO_RED := Color(0.75, 0.22, 0.17, 1.0)       # 勇者红 #C0392B
const COLOR_HERO_RED_DARK := Color(0.55, 0.12, 0.08, 1.0)  # 暗红 #8C1A0E
const COLOR_GOLD := Color(0.83, 0.69, 0.21, 1.0)           # 公会金 #D4AF37
const COLOR_GOLD_DARK := Color(0.60, 0.48, 0.10, 1.0)      # 暗金 #997A1A
const COLOR_IRON := Color(0.50, 0.55, 0.55, 1.0)           # 铁灰色 #7F8C8D
const COLOR_SHADOW := Color(0.10, 0.06, 0.04, 0.35)        # 木板阴影

# ============================================================
# 圆角
# ============================================================
const CORNER_WOOD := 6
const CORNER_PARCHMENT := 4
const CORNER_BADGE := 8

# ============================================================
# 动画时长
# ============================================================
const DURATION_HOVER := 0.15
const DURATION_POPUP_ENTRANCE := 0.35
const DURATION_POPUP_EXIT := 0.25
const DURATION_GOLD_BOUNCE := 0.3
const DURATION_SWING := 0.4

# ============================================================
# 尺寸
# ============================================================
const BUTTON_HEIGHT := 52
const BUTTON_ICON_SIZE := 40
const HUD_HEIGHT := 52
const WOOD_BADGE_WIDTH := 130
const WOOD_BADGE_HEIGHT := 40
const PARTNER_SLOT_WIDTH := 140
const PARTNER_SLOT_HEIGHT := 180

# ============================================================
# 字体路径
# ============================================================
const FONT_CN_PATH := "res://assets/fonts/cute/ZCOOLKuaiLe-Regular.ttf"
const FONT_EN_PATH := "res://assets/fonts/cute/FredokaOne-Regular.ttf"

# ============================================================
# 程序化纹理生成
# ============================================================

static func create_wood_texture(width: int = 128, height: int = 128) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.025
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	
	for y in range(height):
		# 纵向木纹基础色变化
		var streak := sin(y * 0.08) * 0.06 + sin(y * 0.03) * 0.04
		for x in range(width):
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var brightness := clampf(n + streak, 0.0, 1.0)
			# 棕木色调
			var r := lerpf(0.35, 0.58, brightness)
			var g := lerpf(0.22, 0.38, brightness)
			var b := lerpf(0.12, 0.24, brightness)
			image.set_pixel(x, y, Color(r, g, b, 1.0))
	
	return ImageTexture.create_from_image(image)


static func create_wood_dark_texture(width: int = 128, height: int = 128) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	
	for y in range(height):
		var streak := sin(y * 0.06) * 0.05
		for x in range(width):
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var brightness := clampf(n + streak, 0.0, 1.0)
			var r := lerpf(0.22, 0.35, brightness)
			var g := lerpf(0.14, 0.24, brightness)
			var b := lerpf(0.08, 0.16, brightness)
			image.set_pixel(x, y, Color(r, g, b, 1.0))
	
	return ImageTexture.create_from_image(image)


static func create_parchment_texture(width: int = 128, height: int = 128) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.04
	noise.fractal_octaves = 2
	
	for y in range(height):
		for x in range(width):
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var age := n * 0.08  # 老化斑驳效果
			var r := clampf(0.96 - age, 0.85, 1.0)
			var g := clampf(0.90 - age * 1.2, 0.78, 0.95)
			var b := clampf(0.78 - age * 1.5, 0.60, 0.85)
			image.set_pixel(x, y, Color(r, g, b, 1.0))
	
	return ImageTexture.create_from_image(image)


# ============================================================
# StyleBox 工厂
# ============================================================

static func create_wood_style(dark: bool = false, corner_radius: int = CORNER_WOOD) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = create_wood_dark_texture() if dark else create_wood_texture()
	style.texture_margin_left = 4
	style.texture_margin_top = 4
	style.texture_margin_right = 4
	style.texture_margin_bottom = 4
	style.expand_margin_left = 2
	style.expand_margin_top = 2
	style.expand_margin_right = 2
	style.expand_margin_bottom = 2
	return style


static func create_wood_flat_style(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0, corner_radius: int = CORNER_WOOD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	if border_width > 0:
		style.border_color = border_color
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	# 木板厚度内阴影
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	style.shadow_color = COLOR_SHADOW
	return style


static func create_parchment_style(corner_radius: int = CORNER_PARCHMENT) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = create_parchment_texture()
	style.texture_margin_left = 6
	style.texture_margin_top = 6
	style.texture_margin_right = 6
	style.texture_margin_bottom = 6
	return style


static func create_parchment_flat_style(corner_radius: int = CORNER_PARCHMENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_color = COLOR_WOOD_MEDIUM
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	style.shadow_color = COLOR_SHADOW
	return style


static func create_iron_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_IRON
	style.border_color = Color(0.35, 0.38, 0.38, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	style.shadow_color = COLOR_SHADOW
	return style
