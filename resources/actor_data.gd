class_name ActorData
extends Resource

## 角色数据配置（受 FNF CharacterFile 启发）
## 所有外观、动画、偏移外置化，不用改代码就能添加新角色

@export_group("基础信息")
@export var display_name: String = "角色"
@export var description: String = ""

@export_group("外观")
@export var sprite_frames: SpriteFrames
@export var scale: float = 1.0
@export var position_offset: Vector2 = Vector2.ZERO
@export var camera_offset: Vector2 = Vector2.ZERO

@export_group("动画配置")
@export var animations: Array[ActorAnimData] = []
@export var idle_return_time: float = 0.8

## 动作名称映射：统一动作名 -> SpriteFrames 中的动画名
## 例如 {"attack": "attack_1", "ultimate": "special"}
@export var action_map: Dictionary = {
	"attack": "attack",
	"hurt": "hurt",
	"dead": "dead",
	"ultimate": "ultimate",
	"idle": "idle"
}

@export_group("战斗")
@export var healthbar_color: Color = Color(0.28, 0.60, 0.82)
@export var healthbar_color_low: Color = Color(0.86, 0.32, 0.28)
@export var healthbar_color_mid: Color = Color(0.95, 0.72, 0.25)

@export_group("音效")
@export var attack_sound: String = "attack"
@export var hit_sound: String = "hit"
@export var death_sound: String = "defeat"
@export var ultimate_sound: String = "ultimate"


## 获取指定动画的偏移
func get_offset(anim_name: String) -> Vector2:
	for anim in animations:
		if anim.name == anim_name:
			return anim.offset
	return Vector2.ZERO


## 获取血条颜色（根据血量比例）
func get_health_color(ratio: float) -> Color:
	if ratio < 0.3:
		return healthbar_color_low
	elif ratio < 0.6:
		return healthbar_color_mid
	return healthbar_color
