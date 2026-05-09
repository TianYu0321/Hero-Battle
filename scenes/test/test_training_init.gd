## res://scenes/test/test_training_init.gd
## 模块: TestTrainingInit
## 职责: 验证养成系统初始化时主角属性从 JSON 正确读取

extends Node2D

func _ready() -> void:
	print("===== 养成系统初始化测试 =====")
	
	var cm: CharacterManager = CharacterManager.new()
	add_child(cm)
	
	# 测试勇者初始化
	var hero: RuntimeHero = cm.initialize_hero(1)
	assert(hero != null, "勇者初始化失败")
	print("勇者 current_vit: %d (期望 12)" % hero.current_vit)
	print("勇者 current_str: %d (期望 16)" % hero.current_str)
	print("勇者 current_agi: %d (期望 10)" % hero.current_agi)
	print("勇者 current_tec: %d (期望 12)" % hero.current_tec)
	print("勇者 current_mnd: %d (期望 8)" % hero.current_mnd)
	assert(hero.current_vit == 12, "勇者体魄应为12")
	assert(hero.current_str == 16, "勇者力量应为16")
	assert(hero.current_agi == 10, "勇者敏捷应为10")
	assert(hero.current_tec == 12, "勇者技巧应为12")
	assert(hero.current_mnd == 8, "勇者精神应为8")
	print("✅ 勇者属性验证通过")
	
	# 测试影舞者初始化
	cm.initialize_hero(2)
	var hero2: RuntimeHero = cm.get_hero()
	assert(hero2 != null, "影舞者初始化失败")
	print("影舞者 current_agi: %d (期望 16)" % hero2.current_agi)
	assert(hero2.current_agi == 16, "影舞者敏捷应为16")
	print("✅ 影舞者属性验证通过")
	
	# 测试铁卫初始化
	cm.initialize_hero(3)
	var hero3: RuntimeHero = cm.get_hero()
	assert(hero3 != null, "铁卫初始化失败")
	print("铁卫 current_vit: %d (期望 16)" % hero3.current_vit)
	assert(hero3.current_vit == 16, "铁卫体魄应为16")
	print("✅ 铁卫属性验证通过")
	
	# 测试伙伴初始化
	var partners: Array = cm.initialize_partners([1001, 1002, 1003])
	assert(partners.size() == 3, "应初始化3个伙伴")
	print("✅ 伙伴初始化通过 (count=%d)" % partners.size())
	
	cm.queue_free()
	print("===== 养成系统初始化测试结束 =====")
	get_tree().quit()
