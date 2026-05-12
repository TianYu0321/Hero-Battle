## res://autoload/audio_manager.gd
## 模块: AudioManager
## 职责: 音效/BGM管理占位，预定义播放接口
## 依赖: EventBus
## 被依赖: MenuUI, RunHUD, BattleUI, BattleEngine
## class_name: AudioManager

extends Node

var _current_bgm: String = ""
var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const _MAX_SFX_PLAYERS: int = 8

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Music"
	add_child(_bgm_player)

	for i in range(_MAX_SFX_PLAYERS):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

	EventBus.audio_play_requested.connect(_on_audio_play_requested)

func play_bgm(track: String, _fade_in: float = 0.5) -> void:
	_current_bgm = track
	push_warning("[AudioManager] play_bgm called with track: %s (placeholder)" % track)

func play_sfx(name: String, _volume: float = 1.0) -> void:
	push_warning("[AudioManager] play_sfx called with name: %s (placeholder)" % name)

func set_volume(bus: String, value: float) -> void:
	var db: float = linear_to_db(clampf(value, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), db)

func stop_bgm(_fade_out: float = 0.5) -> void:
	_current_bgm = ""

func _on_audio_play_requested(audio_type: String, audio_name: String, volume: float) -> void:
	match audio_type:
		"bgm":
			play_bgm(audio_name, volume)
		"sfx":
			play_sfx(audio_name, volume)
		_:
			push_warning("[AudioManager] Unknown audio_type: %s" % audio_type)
