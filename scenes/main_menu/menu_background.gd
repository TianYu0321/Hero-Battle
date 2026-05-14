extends CanvasLayer

func _ready() -> void:
	layer = -1
	
	# 渐变背景
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	# 创建渐变纹理
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.05, 0.05, 0.15, 1.0))
	gradient.add_point(1.0, Color(0.0, 0.0, 0.0, 1.0))
	var gradient_tex := GradientTexture2D.new()
	gradient_tex.gradient = gradient
	gradient_tex.fill = GradientTexture2D.FILL_LINEAR
	gradient_tex.fill_from = Vector2(0.5, 0.0)
	gradient_tex.fill_to = Vector2(0.5, 1.0)
	gradient_tex.width = 1280
	gradient_tex.height = 720
	bg.texture = gradient_tex
	add_child(bg)
	
	# 火星粒子
	var particles := CPUParticles2D.new()
	particles.position = Vector2(640, 500)
	particles.amount = 100
	particles.lifetime = 3.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(600, 200)
	particles.direction = Vector2(0, -1)
	particles.spread = 20.0
	particles.gravity = Vector2(0, -20)
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 50.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 2.0
	particles.color = Color(1, 0.5, 0, 0.8)
	
	var color_ramp := Gradient.new()
	color_ramp.add_point(0.0, Color(1, 0.8, 0.2, 0.9))
	color_ramp.add_point(0.5, Color(1, 0.3, 0, 0.6))
	color_ramp.add_point(1.0, Color(0.5, 0.1, 0, 0.0))
	particles.color_ramp = color_ramp
	add_child(particles)
	
	# 远景视差层（程序化绘制）
	var parallax := ParallaxBackground.new()
	add_child(parallax)
	
	var far_layer := ParallaxLayer.new()
	far_layer.motion_scale = Vector2(0.3, 0.3)
	parallax.add_child(far_layer)
	
	var far_sprite := ColorRect.new()
	far_sprite.custom_minimum_size = Vector2(1280, 720)
	far_sprite.color = Color(0.02, 0.02, 0.08, 0.5)
	far_layer.add_child(far_sprite)
	
	# 中景视差层
	var mid_layer := ParallaxLayer.new()
	mid_layer.motion_scale = Vector2(0.6, 0.6)
	parallax.add_child(mid_layer)
	
	var mid_sprite := ColorRect.new()
	mid_sprite.custom_minimum_size = Vector2(1280, 720)
	mid_sprite.color = Color(0.04, 0.04, 0.1, 0.3)
	mid_layer.add_child(mid_sprite)
