extends SceneTree

func _init() -> void:
	print("=== RunMain _ready Integration Test ===")
	
	# Set up GameManager data (simulating post-tavern state)
	print("\n[Setup] Configuring GameManager...")
	var gm = load("res://autoload/game_manager.gd")
	if gm == null:
		print("FAIL: Cannot load game_manager.gd")
		quit()
		return
	
	var game_manager = gm.new()
	game_manager.name = "GameManager"
	root.add_child(game_manager)
	game_manager.selected_hero_config_id = 1  # hero_warrior
	game_manager.selected_partner_config_ids = [1001, 1002]
	print("PASS: GameManager configured with hero=1, partners=[1001, 1002]")
	
	# Load and instantiate RunMain
	print("\n[Test 1] Loading run_main.tscn...")
	var packed: PackedScene = load("res://scenes/run_main/run_main.tscn")
	if packed == null:
		print("FAIL: Cannot load run_main.tscn")
		quit()
		return
	print("PASS: run_main.tscn loaded")
	
	print("\n[Test 2] Instantiating RunMain...")
	var run_main = packed.instantiate()
	if run_main == null:
		print("FAIL: Cannot instantiate")
		quit()
		return
	print("PASS: Instantiated, script=", run_main.get_script().resource_path)
	
	# Add to tree - this triggers _ready()
	print("\n[Test 3] Adding to tree (triggers _ready)...")
	root.add_child(run_main)
	
	# Wait a frame for _ready to complete and deferred calls
	await create_timer(0.1).timeout
	
	# Check results
	print("\n[Test 4] Checking RunController...")
	if run_main.has_node("RunController"):
		var rc = run_main.get_node("RunController")
		print("PASS: RunController found")
		print("      Script: ", rc.get_script())
		if rc.has_method("get_current_run_summary"):
			var summary = rc.get_current_run_summary()
			print("      Summary: ", summary)
		else:
			print("INFO: get_current_run_summary not available")
	else:
		print("FAIL: RunController NOT found")
	
	# Check HUD labels
	print("\n[Test 5] Checking HUD...")
	if run_main.has_node("HudContainer/RoundLabel"):
		var label = run_main.get_node("HudContainer/RoundLabel")
		print("      RoundLabel: ", label.text)
	
	# Cleanup
	run_main.queue_free()
	game_manager.queue_free()
	
	print("\n=== Test Complete ===")
	quit()
