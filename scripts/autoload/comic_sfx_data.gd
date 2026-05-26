## res://scripts/autoload/comic_sfx_data.gd
## 模块: ComicSFXData
## 职责: 漫画拟声词数据定义
## 依赖: 无
## 被依赖: ComicSFXLabel, FeedbackManager

class_name ComicSFXData

enum SFXType {
	HIT_LIGHT,      ## 轻击
	HIT_NORMAL,     ## 普通攻击
	HIT_HEAVY,      ## 重击
	HIT_CRIT,       ## 暴击
	SLASH,          ## 斩击
	MAGIC,          ## 魔法
	HEAL,           ## 治疗
	BLOCK,          ## 格挡
	MISS,           ## 闪避
	KILL,           ## 击杀
}

const SFX_LIBRARY: Dictionary = {
	SFXType.HIT_LIGHT: {
		"words": ["Tap", "Pok", "Bop", "Thud", "Pat"],
		"color": Color(0.9, 0.9, 0.9, 1),
		"font_size": 20,
		"scale_bounce": 1.1,
		"duration": 0.6,
		"shake_amount": 0.0,
	},
	SFXType.HIT_NORMAL: {
		"words": ["Pow", "Bam", "Smack", "Whack", "Thwack"],
		"color": Color(1.0, 0.85, 0.2, 1),
		"font_size": 28,
		"scale_bounce": 1.3,
		"duration": 0.8,
		"shake_amount": 0.15,
	},
	SFXType.HIT_HEAVY: {
		"words": ["BOOM", "WHAM", "CRASH", "SLAM", "THUD"],
		"color": Color(0.95, 0.5, 0.1, 1),
		"font_size": 36,
		"scale_bounce": 1.5,
		"duration": 1.0,
		"shake_amount": 0.3,
	},
	SFXType.HIT_CRIT: {
		"words": ["KA-BOOM!", "POW!", "BAM!", "CRITICAL!", "SMASH!"],
		"color": Color(1.0, 0.2, 0.2, 1),
		"font_size": 42,
		"scale_bounce": 1.8,
		"duration": 1.2,
		"shake_amount": 0.5,
	},
	SFXType.SLASH: {
		"words": ["SLASH", "SHING", "SWIPE", "CUT", "SLICE"],
		"color": Color(0.7, 0.8, 0.95, 1),
		"font_size": 28,
		"scale_bounce": 1.2,
		"duration": 0.7,
		"shake_amount": 0.1,
	},
	SFXType.MAGIC: {
		"words": ["ZAP", "ZING", "POP", "POOF", "BLAST"],
		"color": Color(0.4, 0.6, 1.0, 1),
		"font_size": 26,
		"scale_bounce": 1.3,
		"duration": 0.8,
		"shake_amount": 0.1,
	},
	SFXType.HEAL: {
		"words": ["Swoosh", "Ahh", "Glow", "Warm", "Renew"],
		"color": Color(0.3, 0.9, 0.5, 1),
		"font_size": 24,
		"scale_bounce": 1.2,
		"duration": 0.8,
		"shake_amount": 0.0,
	},
	SFXType.BLOCK: {
		"words": ["CLINK", "TING", "BLOCK", "DEFLECT", "PARRY"],
		"color": Color(0.8, 0.8, 0.85, 1),
		"font_size": 24,
		"scale_bounce": 1.0,
		"duration": 0.5,
		"shake_amount": 0.0,
	},
	SFXType.MISS: {
		"words": ["Whoosh", "Swish", "Miss", "Dodge", "Evade"],
		"color": Color(0.6, 0.6, 0.65, 1),
		"font_size": 20,
		"scale_bounce": 0.9,
		"duration": 0.5,
		"shake_amount": 0.0,
	},
	SFXType.KILL: {
		"words": ["KO!", "BAMF!", "FINISH!", "DOWN!", "OUT!"],
		"color": Color(1.0, 0.15, 0.15, 1),
		"font_size": 48,
		"scale_bounce": 2.0,
		"duration": 1.5,
		"shake_amount": 0.6,
	},
}

static func get_random_word(sfx_type: SFXType) -> String:
	var data: Dictionary = SFX_LIBRARY.get(sfx_type, SFX_LIBRARY[SFXType.HIT_NORMAL])
	var words: Array = data.get("words", ["Pow"])
	return words[randi() % words.size()]

static func get_sfx_data(sfx_type: SFXType) -> Dictionary:
	return SFX_LIBRARY.get(sfx_type, SFX_LIBRARY[SFXType.HIT_NORMAL])
