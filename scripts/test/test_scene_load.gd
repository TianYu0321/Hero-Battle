extends SceneTree

func _init() -> void:
	var scenes: Array[String] = [
		"res://scenes/main_menu/menu.tscn",
		"res://scenes/run_main/run_main.tscn",
		"res://scenes/tavern/tavern.tscn",
	]
	
	for path in scenes:
		print("\nLoading: ", path)
		var packed: PackedScene = load(path)
		if packed == null:
			print("  FAIL: load returned null")
		else:
			print("  PASS: loaded successfully")
	
	quit()
