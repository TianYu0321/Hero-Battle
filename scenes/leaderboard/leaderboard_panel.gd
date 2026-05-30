extends Panel

@onready var ranking_container: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var close_button: Button = $CloseButton
@onready var title_label: Label = $TitleLabel

signal closed

func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close)

func show_rankings(rankings: Array[Dictionary]) -> void:
	# 清空旧列表
	for child in ranking_container.get_children():
		child.queue_free()
	
	# 生成列表项
	for entry in rankings:
		var row = preload("res://scenes/leaderboard/ranking_row.tscn").instantiate()
		
		var rank: int = entry.get("rank", 0)
		var name: String = entry.get("name", entry.get("hero_name", entry.get("player_name", "???")))
		var net_wins: int = entry.get("net_wins", 0)
		var wins: int = entry.get("wins", 0)
		var losses: int = entry.get("losses", 0)
		var is_player: bool = entry.get("is_player", false)
		
		row.setup(rank, name, net_wins, wins, losses, is_player)
		ranking_container.add_child(row)
	
	visible = true

func _on_close() -> void:
	visible = false
	closed.emit()
