extends SceneTree

func _init() -> void:
	print("=== RunMain Load Test ===")
	
	# Test 1: Load run_main.tscn (triggers GDScript compilation)
	print("\n[Test 1] Loading run_main.tscn...")
	var packed: PackedScene = load("res://scenes/run_main/run_main.tscn")
	if packed == null:
		print("FAIL: run_main.tscn load returned null")
		quit()
		return
	print("PASS: run_main.tscn loaded")
	
	# Test 2: Instantiate
	print("\n[Test 2] Instantiating RunMain...")
	var instance: Node = packed.instantiate()
	if instance == null:
		print("FAIL: Instantiate returned null")
		quit()
		return
	print("PASS: Instantiated, class=", instance.get_class(), ", name=", instance.name)
	
	# Test 3: Check script
	var script: Script = instance.get_script()
	if script == null:
		print("FAIL: No script attached")
	else:
		print("PASS: Script attached: ", script.resource_path)
	
	# Test 4: Add to tree (this triggers _ready)
	print("\n[Test 3] Adding to scene tree (triggers _ready)...")
	root.add_child(instance)
	print("PASS: Added to tree")
	
	# Test 5: Check RunController
	if instance.has_node("RunController"):
		var rc := instance.get_node("RunController")
		print("PASS: RunController found, script=", rc.get_script())
	else:
		print("INFO: RunController not found as child (may be created dynamically in _ready)")
	
	# Cleanup
	instance.queue_free()
	
	print("\n=== Test Complete ===")
	quit()
