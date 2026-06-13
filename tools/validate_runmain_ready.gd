extends Node

func _ready():
	print("[Test] Instantiating RunMain...")
	var run_main = preload("res://scenes/run_main/run_main.tscn").instantiate()
	print("[Test] RunMain instantiated, adding to tree...")
	add_child(run_main)
	print("[Test] RunMain added to tree (_ready finished).")
	get_tree().quit()
