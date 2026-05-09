extends Control

var _run_main: Node = null
var _rc: Node = null
var _turn_count: int = 0
var _max_test_turns: int = 30
var _completed: bool = false

func _ready() -> void:
	print("=== 30-Turn Full Run Test ===")
	
	# Setup GameManager
	GameManager.selected_hero_config_id = 1
	GameManager.selected_partner_config_ids = [1001, 1002]
	
	# Load and instantiate RunMain
	var packed: PackedScene = load("res://scenes/run_main/run_main.tscn")
	_run_main = packed.instantiate()
	add_child(_run_main)
	
	# Wait a frame for _ready to complete
	await get_tree().process_frame
	
	_rc = _run_main.get_node("RunController")
	if _rc == null:
		print("FAIL: RunController not found")
		_quit()
		return
	
	print("Starting 30-turn simulation...")
	_progress_turn()


func _progress_turn() -> void:
	if _completed:
		return
	
	var summary: Dictionary = _rc.get_current_run_summary()
	var current_turn: int = summary.get("current_turn", 0)
	var state: int = summary.get("run_state", 0)
	
	if current_turn > _max_test_turns:
		print("\n=== Test Complete: Reached turn %d ===" % current_turn)
		_completed = true
		_quit()
		return
	
	if state == 5:  # SETTLEMENT
		print("\n=== Test Complete: Settlement reached at turn %d ===" % current_turn)
		_completed = true
		_quit()
		return
	
	if state != 2:  # Not RUNNING_NODE_SELECT
		print("  [Turn %d] State=%d, waiting..." % [current_turn, state])
		await get_tree().process_frame
		_progress_turn.call_deferred()
		return
	
	var options: Array[Dictionary] = _rc.get_current_node_options()
	if options.is_empty():
		print("  [Turn %d] No options, waiting..." % current_turn)
		await get_tree().process_frame
		_progress_turn.call_deferred()
		return
	
	print("  [Turn %d] Options: %s" % [current_turn, options.map(func(o): return o.get("node_name", "?"))])
	
	# Click first button
	_run_main._on_node_button_pressed(0)
	
	# Wait for processing
	await get_tree().process_frame
	await get_tree().process_frame
	
	_progress_turn.call_deferred()


func _quit() -> void:
	if _run_main != null:
		_run_main.queue_free()
	get_tree().quit()
