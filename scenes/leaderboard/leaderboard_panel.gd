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
	for i in range(rankings.size()):
		var entry: Dictionary = rankings[i]
		var row = preload("res://scenes/leaderboard/ranking_row.tscn").instantiate()
		row.setup(
			entry.get("rank", i + 1),
			entry.get("hero_name", entry.get("player_name", "???")),
			entry.get("net_wins", 0),
			entry.get("max_floor", entry.get("total_score", 0))
		)
		ranking_container.add_child(row)
	
	visible = true

func _on_close() -> void:
	visible = false
	closed.emit()
