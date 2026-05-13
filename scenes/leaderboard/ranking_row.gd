extends HBoxContainer

@onready var rank_label: Label = $RankLabel
@onready var player_name_label: Label = $PlayerNameLabel
@onready var net_wins_label: Label = $NetWinsLabel
@onready var max_floor_label: Label = $MaxFloorLabel

func setup(rank: int, player_name: String, net_wins: int, max_floor: int) -> void:
	rank_label.text = str(rank)
	player_name_label.text = player_name
	net_wins_label.text = str(net_wins)
	max_floor_label.text = str(max_floor)
	
	# 前3名特殊颜色
	match rank:
		1:
			rank_label.modulate = Color(1, 0.84, 0)
			player_name_label.modulate = Color(1, 0.84, 0)
		2:
			rank_label.modulate = Color(0.75, 0.75, 0.75)
			player_name_label.modulate = Color(0.75, 0.75, 0.75)
		3:
			rank_label.modulate = Color(0.8, 0.5, 0.2)
			player_name_label.modulate = Color(0.8, 0.5, 0.2)
		_:
			rank_label.modulate = Color(1, 1, 1)
			player_name_label.modulate = Color(1, 1, 1)
