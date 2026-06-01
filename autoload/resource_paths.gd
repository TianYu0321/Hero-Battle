## res://autoload/resource_paths.gd
## 模块: ResourcePaths
## 职责: 统一管理所有图片资源路径，提供安全加载与兜底
## 依赖: 无
## 被依赖: 所有UI场景、战斗场景

extends Node

const BASE_PATH := "res://assets/"

## ========== 纹理缓存 ==========
var _texture_cache: Dictionary = {}

## ========== 英雄头像（64x64）==========

static func get_hero_avatar(hero_id: String) -> String:
	match hero_id:
		"hero_shadow_dancer":
			return BASE_PATH + "characters/shinobi/shinobiIcon.png"
		_:
			push_warning("[ResourcePaths] Hero avatar not configured: %s" % hero_id)
			return _get_fallback_avatar()

## ========== 英雄立绘（512x512）==========

static func get_hero_portrait(hero_id: String) -> String:
	match hero_id:
		"hero_shadow_dancer":
			return BASE_PATH + "characters/shinobi/shinobi.png"
		_:
			push_warning("[ResourcePaths] Hero portrait not configured: %s" % hero_id)
			return _get_fallback_portrait()

## ========== 伙伴头像（64x64）==========

static func get_partner_avatar(partner_id: String) -> String:
	match partner_id:
		"partner_swordsman":
			return BASE_PATH + "characters/card/partners/aibo icon/sword icon.png"
		"partner_scout":
			return BASE_PATH + "characters/card/partners/aibo icon/archor icon.png"
		"partner_hunter":
			return BASE_PATH + "characters/card/partners/aibo icon/assassin icon.png"
		"partner_sorcerer":
			return BASE_PATH + "characters/card/partners/aibo icon/maho icon.png"
		"partner_pharmacist":
			return BASE_PATH + "characters/card/partners/aibo icon/wizard icon.png"
		_:
			push_warning("[ResourcePaths] Partner avatar not configured: %s" % partner_id)
			return _get_fallback_avatar()

## ========== 伙伴立绘/卡片大图 ==========

static func get_partner_portrait(partner_id: String) -> String:
	var mapped_id: String = _map_partner_id(partner_id)
	if mapped_id.is_empty():
		push_warning("[ResourcePaths] Partner portrait unknown ID: %s" % partner_id)
		return _get_fallback_portrait()
	var path := BASE_PATH + "characters/card/partners/%s_lv1.png" % mapped_id
	if _file_exists(path):
		return path
	push_warning("[ResourcePaths] Partner portrait not found: %s" % path)
	return _get_fallback_portrait()

## ========== 伙伴卡片框路径（支持专用卡片 + 通用等级 fallback）==========

static func get_partner_card_path(partner_id: String, level: int) -> String:
	level = clampi(level, 1, 5)
	var mapped_id: String = _map_partner_id(partner_id)
	if mapped_id.is_empty():
		return BASE_PATH + "characters/card/LV%d.png" % level
	var dedicated: String = BASE_PATH + "characters/card/partners/partner_%s_lv%d.png" % [mapped_id, level]
	if _file_exists(dedicated):
		return dedicated
	return BASE_PATH + "characters/card/LV%d.png" % level

## ========== 敌人头像 ==========

static func get_enemy_avatar(enemy_id: String) -> String:
	## 当前敌人只有通用姿势图，按 enemy_id 映射
	var path := BASE_PATH + "characters/enemy/poses/idle/enemy_idle_%s.png" % enemy_id
	if _file_exists(path):
		return path
	push_warning("[ResourcePaths] Enemy avatar not found: %s" % path)
	return _get_fallback_enemy_avatar()

## ========== 敌人立绘 ==========

static func get_enemy_portrait(enemy_id: String) -> String:
	## 敌人立绘复用 idle 姿势图
	return get_enemy_avatar(enemy_id)

## ========== 背景图 ==========

static func get_menu_background() -> String:
	return BASE_PATH + "backgrounds/menu_bg.png"

static func get_menu_bg_layer(layer_index: int) -> String:
	match layer_index:
		0: return BASE_PATH + "backgrounds/menu/layer_0_sky.png"
		1: return BASE_PATH + "backgrounds/menu/layer_1_mountains.png"
		2: return BASE_PATH + "backgrounds/menu/layer_2_hills.png"
		3: return BASE_PATH + "backgrounds/menu/layer_3_trees.png"
		4: return BASE_PATH + "backgrounds/menu/layer_4_ground.png"
		_: return ""

static func get_hero_select_background() -> String:
	## 暂无专用选人背景，复用菜单背景
	return get_menu_background()

static func get_battle_background(battle_type: String = "normal") -> String:
	match battle_type:
		"elite": return BASE_PATH + "backgrounds/pve/stages2/castle.png"
		"boss": return BASE_PATH + "backgrounds/pve/stages3/terrace.png"
		_: return BASE_PATH + "backgrounds/pve/stages1/dead forest.png"

static func get_tower_background() -> String:
	## 暂无专用爬塔背景，复用第一层战斗背景
	return BASE_PATH + "backgrounds/pve/stages1/1.png"

## ========== UI 图标 ==========

static func get_icon(icon_name: String) -> String:
	var path := BASE_PATH + "ui/icons/%s.png" % icon_name
	if _file_exists(path):
		return path
	push_warning("[ResourcePaths] UI icon not found: %s" % path)
	return ""

## ========== 粒子纹理 ==========

static func get_particle_texture(particle_name: String) -> String:
	var path := BASE_PATH + "ui/particles/%s.png" % particle_name
	if _file_exists(path):
		return path
	push_warning("[ResourcePaths] Particle texture not found: %s" % path)
	return ""

## ========== 特效纹理 ==========

static func get_effect_texture(effect_name: String) -> String:
	var path := BASE_PATH + "effects/%s.png" % effect_name
	if _file_exists(path):
		return path
	push_warning("[ResourcePaths] Effect texture not found: %s" % path)
	return ""

## ========== 安全加载（实例方法，支持缓存）==========

func load_texture_safe(path: String) -> Texture2D:
	if path.is_empty():
		push_warning("[ResourcePaths] Empty path provided, returning placeholder")
		return _generate_placeholder_texture(Color.GRAY, 64, 64)
	## 缓存命中且不是占位图时直接返回（占位图键用特殊前缀避免误缓存）
	if _texture_cache.has(path) and not _texture_cache[path] is ImageTexture:
		return _texture_cache[path]
	var tex: Texture2D = resolve_texture_from_path(path)
	if tex == null:
		push_warning("[ResourcePaths] Failed to load texture: %s, returning placeholder" % path)
		return _generate_placeholder_texture(Color.GRAY, 64, 64)
	_texture_cache[path] = tex
	return tex

func load_texture_cached(path: String) -> Texture2D:
	return load_texture_safe(path)

func resolve_texture_from_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	var res: Resource = load(path)
	if res == null:
		return null
	if res is Texture2D:
		_texture_cache[path] = res as Texture2D
		return _texture_cache[path]
	if res is SpriteFrames:
		var frames: SpriteFrames = res
		for anim_name in frames.get_animation_names():
			if frames.get_frame_count(anim_name) > 0:
				var tex := frames.get_frame_texture(anim_name, 0)
				_texture_cache[path] = tex
				return tex
	return null

func clear_cache() -> void:
	_texture_cache.clear()

## ========== 兜底资源 ==========

static func _get_fallback_avatar() -> String:
	return BASE_PATH + "ui/icons/unknown_avatar.png"

static func _get_fallback_enemy_avatar() -> String:
	return BASE_PATH + "ui/icons/unknown_enemy.png"

static func _get_fallback_portrait() -> String:
	return BASE_PATH + "ui/icons/unknown_portrait.png"

## ========== 运行时占位图生成 ==========

static func _generate_placeholder_texture(color: Color, width: int, height: int) -> Texture2D:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(color)
	## 白色边框
	for x in range(width):
		img.set_pixel(x, 0, Color.WHITE)
		img.set_pixel(x, height - 1, Color.WHITE)
	for y in range(height):
		img.set_pixel(0, y, Color.WHITE)
		img.set_pixel(width - 1, y, Color.WHITE)
	## 红色叉号
	var min_dim := mini(width, height)
	for i in range(min_dim):
		img.set_pixel(i, i, Color.RED)
		img.set_pixel(i, min_dim - 1 - i, Color.RED)
	return ImageTexture.create_from_image(img)

## ========== 辅助函数 ==========

static func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)

## 将 partner_id（如 "partner_swordsman" 或 "1001"）映射到文件名前缀
static func _map_partner_id(partner_id: String) -> String:
	var id_map: Dictionary = {
		## partner_id → filename prefix
		"partner_swordsman": "swordsman",
		"partner_scout": "scout",
		"partner_shieldguard": "shieldguard",
		"partner_pharmacist": "pharmacist",
		"partner_sorcerer": "sorcerer",
		"partner_hunter": "hunter",
		## numeric ID → filename prefix
		"1001": "swordsman",
		"1002": "scout",
		"1003": "shieldguard",
		"1004": "pharmacist",
		"1005": "sorcerer",
		"1006": "hunter",
		## Chinese name → filename prefix（兼容 battle_animation_panel 传参）
		"剑士": "swordsman",
		"斥候": "scout",
		"盾卫": "shieldguard",
		"药师": "pharmacist",
		"术士": "sorcerer",
		"猎人": "hunter",
	}
	return id_map.get(partner_id, "")
