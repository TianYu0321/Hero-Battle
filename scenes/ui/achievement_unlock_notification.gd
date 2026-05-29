## achievement_unlock_notification.gd
extends PanelContainer

const SLIDE_DURATION := 0.5
const DISPLAY_DURATION := 3.0
const SLIDE_OUT_DURATION := 0.4

func setup(data: Dictionary) -> void:
	var name_label: Label = $VBoxContainer/NameLabel
	var desc_label: Label = $VBoxContainer/DescLabel
	var icon_tex: TextureRect = $VBoxContainer/HBoxContainer/IconTexture
	var reward_label: Label = $VBoxContainer/HBoxContainer/RewardLabel
	
	name_label.text = data.get("name", "???")
	desc_label.text = data.get("description", "")
	
	var icon_path: String = data.get("icon", "")
	if not icon_path.is_empty():
		var tex: Texture2D = load(icon_path)
		if tex != null:
			icon_tex.texture = tex
	
	var reward: int = data.get("reward_gold", 0)
	if reward > 0:
		reward_label.text = "+%d金币" % reward
		reward_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.15, 1))
	else:
		reward_label.visible = false
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.88, 1.0)
	style.border_color = Color(0.85, 0.65, 0.15, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.85, 0.65, 0.15, 0.25)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", style)
	
	custom_minimum_size = Vector2(360, 100)
	position = Vector2(1280, 80)
	
	_animate_in()


func _animate_in() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", 880, SLIDE_DURATION)
	
	scale = Vector2(0.8, 0.8)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, SLIDE_DURATION)
	
	modulate = Color(1.5, 1.5, 1.0, 1.0)
	tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.3)
	
	await tween.finished
	
	await get_tree().create_timer(DISPLAY_DURATION).timeout
	
	_animate_out()


func _animate_out() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:x", 1280 + size.x, SLIDE_OUT_DURATION)
	tween.parallel().tween_property(self, "modulate:a", 0.0, SLIDE_OUT_DURATION)
	
	await tween.finished
	queue_free()
