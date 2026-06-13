extends Panel

const PolishedOutgameUI := preload("res://scenes/ui/polished_outgame_ui.gd")

@onready var ranking_container: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var close_button: Button = $CloseButton
@onready var title_label: Label = $TitleLabel
@onready var bg: TextureRect = $Bg
@onready var summary_panel: PanelContainer = $SummaryPanel
@onready var summary_title: Label = $SummaryPanel/SummaryVBox/SummaryTitle
@onready var champion_label: Label = $SummaryPanel/SummaryVBox/ChampionLabel
@onready var champion_record_label: Label = $SummaryPanel/SummaryVBox/ChampionRecordLabel
@onready var player_rank_label: Label = $SummaryPanel/SummaryVBox/PlayerRankLabel
@onready var summary_hint_label: Label = $SummaryPanel/SummaryVBox/SummaryHintLabel

signal closed

var _font_cn: Font = null

func _ready() -> void:
	visible = false
	_font_cn = _load_font("res://assets/fonts/SourceHanSerifSC-Bold.otf")
	_apply_outgame_style()
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
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(0, 54 if rank <= 3 else 48)
		PolishedOutgameUI.apply_panel(frame, "leaderboard_row_top.png" if rank <= 3 or is_player else "leaderboard_row.png", 24, 8)
		frame.add_child(row)
		PolishedOutgameUI.apply_recursive(frame)
		ranking_container.add_child(frame)
	
	_update_summary(rankings)
	move_to_front()
	visible = true

func _on_close() -> void:
	visible = false
	closed.emit()


func _apply_outgame_style() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	PolishedOutgameUI.apply_label(title_label, "title")
	PolishedOutgameUI.apply_button(close_button)
	PolishedOutgameUI.apply_panel(summary_panel, "honor_summary.png", 34, 18)
	PolishedOutgameUI.apply_label(summary_title, "section")
	PolishedOutgameUI.apply_label(champion_label, "dark")
	PolishedOutgameUI.apply_label(champion_record_label, "dark")
	PolishedOutgameUI.apply_label(player_rank_label, "dark")
	PolishedOutgameUI.apply_label(summary_hint_label, "muted")
	_apply_font_recursive(self)
	_apply_readability_recursive(self)
	title_label.add_theme_font_size_override("font_size", 36)
	close_button.add_theme_font_size_override("font_size", 22)
	summary_title.add_theme_font_size_override("font_size", 24)
	summary_hint_label.add_theme_font_size_override("font_size", 16)


func _update_summary(rankings: Array[Dictionary]) -> void:
	if rankings.is_empty():
		champion_label.text = "冠军：暂无"
		champion_record_label.text = "净胜场：0"
		player_rank_label.text = "我的排名：尚未上榜"
		summary_hint_label.text = "完成竞技场对战后，战绩会被刻入荣耀大厅。"
		return

	var champion: Dictionary = rankings[0]
	var champion_name: String = champion.get("name", champion.get("hero_name", champion.get("player_name", "???")))
	var champion_net_wins: int = champion.get("net_wins", 0)
	var champion_wins: int = champion.get("wins", 0)
	var champion_losses: int = champion.get("losses", 0)
	champion_label.text = "冠军：%s" % champion_name
	champion_record_label.text = "净胜场：%d    胜/负：%d/%d" % [champion_net_wins, champion_wins, champion_losses]

	var player_summary := "尚未上榜"
	for entry in rankings:
		if entry.get("is_player", false):
			var player_rank: int = entry.get("rank", 0)
			var player_name: String = entry.get("name", entry.get("hero_name", entry.get("player_name", "???")))
			var player_net_wins: int = entry.get("net_wins", 0)
			player_summary = "#%d  %s（净胜 %d）" % [player_rank, player_name, player_net_wins]
			break
	player_rank_label.text = "我的排名：%s" % player_summary
	summary_hint_label.text = "前三名占据荣耀榜主位；当前玩家会以金色铭牌高亮。"


func _apply_font_recursive(node: Node) -> void:
	if _font_cn == null:
		return
	if node is Label:
		node.add_theme_font_override("font", _font_cn)
	elif node is Button:
		node.add_theme_font_override("font", _font_cn)
	for child in node.get_children():
		_apply_font_recursive(child)


func _apply_readability_recursive(node: Node) -> void:
	if node is Label:
		node.add_theme_constant_override("outline_size", 2)
		node.add_theme_color_override("font_outline_color", Color(0.09, 0.045, 0.02, 0.88))
	elif node is Button:
		node.add_theme_constant_override("outline_size", 2)
		node.add_theme_color_override("font_outline_color", Color(0.09, 0.045, 0.02, 0.84))
	for child in node.get_children():
		_apply_readability_recursive(child)


func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return null
