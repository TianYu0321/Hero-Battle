extends HBoxContainer

const PolishedOutgameUI := preload("res://scenes/ui/polished_outgame_ui.gd")

@onready var rank_label: Label = $RankLabel
@onready var player_name_label: Label = $PlayerNameLabel
@onready var net_wins_label: Label = $NetWinsLabel
@onready var detail_label: Label = $MaxFloorLabel

var _rank := 0
var _player_name := "Player"
var _net_wins := 0
var _wins := 0
var _losses := 0
var _is_player := false


func _ready() -> void:
	_apply_setup()


func setup(rank: int, player_name: String, net_wins: int, wins: int = 0, losses: int = 0, is_player: bool = false) -> void:
	_rank = rank
	_player_name = player_name
	_net_wins = net_wins
	_wins = wins
	_losses = losses
	_is_player = is_player
	if is_node_ready():
		_apply_setup()


func _apply_setup() -> void:
	add_theme_constant_override("separation", 14)

	if rank_label != null:
		rank_label.text = str(_rank)
		_apply_readable_label(rank_label, true)
	if player_name_label != null:
		player_name_label.text = _player_name
		_apply_readable_label(player_name_label)
		if _is_player:
			player_name_label.add_theme_color_override("font_color", Color("#1f5f87"))
	if net_wins_label != null:
		net_wins_label.text = str(_net_wins)
		_apply_readable_label(net_wins_label, true)
	if detail_label != null:
		detail_label.text = "%d胜 / %d负" % [_wins, _losses]
		_apply_readable_label(detail_label)


func _apply_readable_label(label: Label, strong: bool = false) -> void:
	PolishedOutgameUI.apply_label(label, "dark")
	label.add_theme_color_override("font_color", Color("#2f1a10"))
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_font_size_override("font_size", 18 if strong else 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
