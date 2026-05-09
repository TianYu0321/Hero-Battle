extends Control

func _ready() -> void:
	print("=== RunMain Integration Test ===")
	
	# Step 1: Configure GameManager (simulating post-tavern state)
	print("\n[Step 1] Configuring GameManager...")
	GameManager.selected_hero_config_id = 1  # hero_warrior
	GameManager.selected_partner_config_ids = [1001, 1002]
	print("PASS: hero_config_id=1, partners=[1001, 1002]")
	
	# Step 2: Load run_main.tscn
	print("\n[Step 2] Loading run_main.tscn...")
	var packed: PackedScene = load("res://scenes/run_main/run_main.tscn")
	if packed == null:
		print("FAIL: load returned null")
		_quit()
		return
	print("PASS: run_main.tscn loaded")
	
	# Step 3: Instantiate
	print("\n[Step 3] Instantiating RunMain...")
	var run_main = packed.instantiate()
	if run_main == null:
		print("FAIL: instantiate returned null")
		_quit()
		return
	print("PASS: Instantiated")
	
	# Step 4: Add to tree (triggers _ready)
	print("\n[Step 4] Adding to tree (triggers _ready)...")
	add_child(run_main)
	print("PASS: Added to tree")
	
	# Step 5: Wait a frame for deferred calls
	await get_tree().process_frame
	
	# Step 6: Check RunController
	print("\n[Step 5] Checking RunController...")
	if run_main.has_node("RunController"):
		var rc = run_main.get_node("RunController")
		print("PASS: RunController found")
		if rc.has_method("get_current_run_summary"):
			var summary = rc.get_current_run_summary()
			print("      Summary: ", summary)
	else:
		print("FAIL: RunController NOT found")
	
	# Step 7: Check HUD state
	print("\n[Step 6] Checking HUD...")
	if run_main.has_node("HudContainer/RoundLabel"):
		print("      RoundLabel: ", run_main.get_node("HudContainer/RoundLabel").text)
	if run_main.has_node("HudContainer/GoldLabel"):
		print("      GoldLabel: ", run_main.get_node("HudContainer/GoldLabel").text)
	
	# Step 8: Check node buttons
	print("\n[Step 7] Checking node buttons...")
	for i in range(3):
		var btn_path = "NodeSelectContainer/NodeButton%d" % (i + 1)
		if run_main.has_node(btn_path):
			var btn = run_main.get_node(btn_path)
			print("      Button%d: text='%s' visible=%s" % [i + 1, btn.text, btn.visible])
	
	# Cleanup
	run_main.queue_free()
	
	print("\n=== Test Complete ===")
	_quit()


func _quit() -> void:
	get_tree().quit()
