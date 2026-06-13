extends Node

func _ready():
	print("[Test] Instantiating Tavern...")
	var tavern = preload("res://scenes/tavern/tavern.tscn").instantiate()
	print("[Test] Tavern instantiated, adding to tree...")
	add_child(tavern)
	print("[Test] Tavern added to tree (_ready finished).")
	get_tree().quit()
