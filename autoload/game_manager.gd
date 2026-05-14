## res://autoload/game_manager.gd
## 模块: GameManager
## 职责: 维护游戏主场景状态机，负责场景切换与过渡动画
## 依赖: EventBus
## 被依赖: UIManager, RunController, 所有UI场景
## class_name: GameManager

extends Node

enum GameState {
	MENU,
	HERO_SELECT,
	TAVERN,
	RUNNING,
	FINAL_BATTLE,
	SETTLEMENT,
}

const _SCENE_PATHS: Dictionary = {
	"MENU": "res://scenes/main_menu/menu.tscn",
	"HERO_SELECT": "res://scenes/hero_select/hero_select.tscn",
	"TAVERN": "res://scenes/tavern/tavern.tscn",
	"RUNNING": "res://scenes/run_main/run_main.tscn",
	"FINAL_BATTLE": "res://scenes/battle/battle.tscn",
	"SETTLEMENT": "res://scenes/settlement/settlement.tscn",
	"ARCHIVE_VIEW": "res://scenes/archive_view/archive_view.tscn",
	"PVP_LOBBY": "res://scenes/pvp_lobby/pvp_lobby.tscn",
	"SHOP": "res://scenes/shop/shop.tscn",
}

# 字符串ID → 数字ID 映射（供RunMain启动RunController时使用）
const _HERO_STRING_TO_ID: Dictionary = {
	"hero_warrior": 1,
	"hero_shadow_dancer": 2,
	"hero_iron_guard": 3,
}
const _PARTNER_STRING_TO_ID: Dictionary = {
	"partner_swordsman": 1001,
	"partner_scout": 1002,
	"partner_shieldguard": 1003,
	"partner_pharmacist": 1004,
	"partner_sorcerer": 1005,
	"partner_hunter": 1006,
}

var pending_archive: Dictionary = {}

# 运行时选择数据（供RunMain读取启动新局）
var selected_hero_config_id: int = 0
var selected_partner_config_ids: Array[int] = []
var pending_save_data: Dictionary = {}

# 当前PVP出战档案
var current_pvp_archive: Dictionary = {}

func set_pvp_archive(archive: Dictionary) -> void:
	current_pvp_archive = archive.duplicate(true)
	print("[GameManager] 设置PVP出战档案: %s" % archive.get("hero_name", "???"))

func get_pvp_archive() -> Dictionary:
	if current_pvp_archive.is_empty():
		# 如果没有设置，自动取最新档案
		var archives: Array[Dictionary] = SaveManager.load_archives("date", 1, "")
		if not archives.is_empty() and archives[0].get("is_fixed", false):
			current_pvp_archive = archives[0]
	return current_pvp_archive

var _current_state: String = "MENU"
var _is_transitioning: bool = false

func _ready() -> void:
	EventBus.new_game_requested.connect(_on_new_game_requested)
	EventBus.continue_game_requested.connect(_on_continue_game_requested)
	EventBus.hero_selected.connect(_on_hero_selected)
	EventBus.team_confirmed.connect(_on_team_confirmed)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.back_to_menu_requested.connect(_on_back_to_menu_requested)
	EventBus.back_to_hero_select.connect(_on_back_to_hero_select)
	EventBus.archive_view_requested.connect(_on_archive_view_requested)
	EventBus.pvp_lobby_requested.connect(_on_pvp_lobby_requested)
	EventBus.shop_requested.connect(_on_shop_requested)

func change_scene(to_state: String, transition_type: String = "fade") -> void:
	if _is_transitioning:
		push_warning("[GameManager] Scene transition already in progress, ignoring request to %s" % to_state)
		return

	var from_state: String = _current_state
	_is_transitioning = true
	var success: bool = false

	if transition_type == "fade":
		success = await _do_fade_transition(to_state)
	else:
		success = _do_instant_transition(to_state)

	if success:
		_current_state = to_state
	_is_transitioning = false
	EventBus.scene_state_changed.emit(from_state, _current_state, {})

func _do_fade_transition(to_state: String) -> bool:
	var fade_color: ColorRect = _create_fade_overlay()
	get_tree().root.call_deferred("add_child", fade_color)

	# Fade in
	var tween_in: Tween = get_tree().create_tween()
	tween_in.tween_property(fade_color, "modulate:a", 1.0, 0.25).from(0.0)
	await tween_in.finished

	# Change scene
	var success: bool = _do_instant_transition(to_state)

	# Fade out
	var tween_out: Tween = get_tree().create_tween()
	tween_out.tween_property(fade_color, "modulate:a", 0.0, 0.25).from(1.0)
	await tween_out.finished

	fade_color.queue_free()
	return success

func _do_instant_transition(to_state: String) -> bool:
	var path: String = _SCENE_PATHS.get(to_state, "")
	if path.is_empty():
		push_error("[GameManager] No scene path defined for state: %s" % to_state)
		return false

	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("[GameManager] Failed to change scene to %s (error: %d)" % [path, err])
		return false
	return true

func _create_fade_overlay() -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.modulate.a = 0.0
	rect.z_index = 999
	return rect

func get_current_state() -> String:
	return _current_state

# --- EventBus callbacks ---

func _on_new_game_requested(_hero_id: String) -> void:
	pending_save_data = {}
	pending_archive = {}
	change_scene("HERO_SELECT", "fade")

func _on_continue_game_requested() -> void:
	var save_data: Dictionary = SaveManager.load_latest_run()
	print("[GameManager] 继续游戏存档: %s" % JSON.stringify(save_data).substr(0, 200))
	if not SaveManager.is_valid_save(save_data):
		push_warning("[GameManager] 存档数据无效，无法继续")
		return
	pending_save_data = save_data.duplicate()
	selected_hero_config_id = save_data.get("hero_config_id", 0)
	selected_partner_config_ids.clear()
	for p in save_data.get("partners", []):
		selected_partner_config_ids.append(p.get("config_id", p.get("partner_config_id", 0)))
	change_scene("RUNNING", "fade")

func _on_hero_selected(hero_id: String) -> void:
	selected_hero_config_id = _HERO_STRING_TO_ID.get(hero_id, 1)
	change_scene("TAVERN", "fade")

func _on_team_confirmed(partner_ids: Array[String]) -> void:
	pending_save_data = {}
	selected_partner_config_ids.clear()
	for pid in partner_ids:
		selected_partner_config_ids.append(_PARTNER_STRING_TO_ID.get(pid, 1001))
	change_scene("RUNNING", "fade")

func _on_run_ended(_ending_type: String, _final_score: int, archive: Dictionary) -> void:
	pending_archive = archive.duplicate()
	change_scene("SETTLEMENT", "fade")

func _on_back_to_menu_requested() -> void:
	pending_save_data = {}
	pending_archive = {}
	change_scene("MENU", "fade")

func _on_back_to_hero_select() -> void:
	change_scene("HERO_SELECT", "fade")

func _on_archive_view_requested(_archive_id: String = "") -> void:
	change_scene("ARCHIVE_VIEW", "fade")

func _on_pvp_lobby_requested() -> void:
	change_scene("PVP_LOBBY", "fade")

func _on_shop_requested() -> void:
	change_scene("SHOP", "fade")
