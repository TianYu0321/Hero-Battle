extends HBoxContainer

@onready var rank_label: Label = $RankLabel
@onready var player_name_label: Label = $PlayerNameLabel
@onready var net_wins_label: Label = $NetWinsLabel
@onready var detail_label: Label = $MaxFloorLabel

func setup(rank: int, player_name: String, net_wins: int, wins: int = 0, losses: int = 0, is_player: bool = false) -> void:
	if rank_label != null:
		rank_label.text = str(rank)
	if player_name_label != null:
		player_name_label.text = player_name
	if net_wins_label != null:
		net_wins_label.text = str(net_wins)
	if detail_label != null:
		detail_label.text = "%d胜 / %d败" % [wins, losses]
	
	# 当前玩家蓝色高亮，否则前3名金银铜
	if player_name_label != null:
		if is_player:
			player_name_label.add_theme_color_override("font_color", Color(0.25, 0.55, 0.9, 1.0))
		else:
			player_name_label.remove_theme_color_override("font_color")
			match rank:
				1:
					player_name_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
				2:
					player_name_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
				3:
					player_name_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
	
	# 排名颜色
	if rank_label != null:
		match rank:
			1:
				rank_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
			2:
				rank_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
			3:
				rank_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
			_:
				rank_label.remove_theme_color_override("font_color")
