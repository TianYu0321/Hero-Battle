extends Node

## 音效管理器 — 简化版占位系统
## 三层总线：SFX（战斗音效）/ UI（界面音效）/ Music（背景音乐）

enum AudioBus { MASTER, MUSIC, SFX, UI }

# 预加载音效资源（占位，后续替换为实际文件）
var _sfx_streams: Dictionary = {}
var _music_streams: Dictionary = {}

# 池化播放器（避免频繁创建/销毁）
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _max_sfx_players: int = 8
var _max_ui_players: int = 4

# BGM播放器（跨场景持续）
var _music_player: AudioStreamPlayer = null

func _ready() -> void:
	# 初始化音频总线
	_ensure_bus_exists("Music")
	_ensure_bus_exists("SFX")
	_ensure_bus_exists("UI")
	
	# 初始化SFX播放器池
	for i in range(_max_sfx_players):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)
	
	# 初始化UI播放器池
	for i in range(_max_ui_players):
		var player := AudioStreamPlayer.new()
		player.bus = "UI"
		add_child(player)
		_ui_players.append(player)
	
	# 初始化BGM播放器
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	
	print("[AudioManager] 初始化完成，SFX池=%d，UI池=%d" % [_max_sfx_players, _max_ui_players])

func _ensure_bus_exists(bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
		print("[AudioManager] 创建音频总线: %s" % bus_name)


## ===== 播放接口 =====

func play_sfx(sound_id: String) -> void:
	var stream = _sfx_streams.get(sound_id)
	if stream == null:
		print("[AudioManager] 音效未加载: %s" % sound_id)
		return
	
	# 找空闲播放器
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	
	# 全部忙，强制复用第一个
	_sfx_players[0].stream = stream
	_sfx_players[0].play()

func play_ui(sound_id: String) -> void:
	var stream = _sfx_streams.get(sound_id)
	if stream == null:
		print("[AudioManager] UI音效未加载: %s" % sound_id)
		return
	
	for player in _ui_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	
	_ui_players[0].stream = stream
	_ui_players[0].play()

func play_music(track_id: String, fade_duration: float = 1.0) -> void:
	var stream = _music_streams.get(track_id)
	if stream == null:
		print("[AudioManager] 音乐未加载: %s" % track_id)
		return
	
	# 如果正在播放其他音乐，先淡出
	if _music_player.playing and _music_player.stream != stream:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -80.0, fade_duration)
		tween.tween_callback(func() -> void:
			_music_player.stop()
			_music_player.stream = stream
			_music_player.volume_db = 0.0
			_music_player.play()
		)
		return
	
	_music_player.stream = stream
	_music_player.play()

func stop_music(fade_duration: float = 0.5) -> void:
	if not _music_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, fade_duration)
	tween.tween_callback(func() -> void:
		_music_player.stop()
		_music_player.volume_db = 0.0
	)


## ===== 音量控制 =====

func set_bus_volume_db(bus_name: String, volume_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, volume_db)

func set_bus_volume_linear(bus_name: String, volume: float) -> void:
	## volume: 0.0 ~ 1.0
	set_bus_volume_db(bus_name, linear_to_db(clampf(volume, 0.0, 1.0)))

func get_bus_volume_linear(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return db_to_linear(AudioServer.get_bus_volume_db(idx))
	return 1.0

func mute_bus(bus_name: String, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)


## ===== 资源加载 =====

func load_sfx(sound_id: String, path: String) -> void:
	if not FileAccess.file_exists(path):
		print("[AudioManager] 音效文件不存在: %s" % path)
		return
	var stream := load(path) as AudioStream
	if stream != null:
		_sfx_streams[sound_id] = stream
		print("[AudioManager] 加载音效: %s -> %s" % [sound_id, path])
	else:
		print("[AudioManager] 加载音效失败: %s" % path)

func load_music(track_id: String, path: String) -> void:
	if not FileAccess.file_exists(path):
		print("[AudioManager] 音乐文件不存在: %s" % path)
		return
	var stream := load(path) as AudioStream
	if stream != null:
		_music_streams[track_id] = stream
		print("[AudioManager] 加载音乐: %s -> %s" % [track_id, path])
	else:
		print("[AudioManager] 加载音乐失败: %s" % path)

func load_sfx_batch(dict: Dictionary) -> void:
	## dict: {"sound_id": "res://path/to/file.wav", ...}
	for sound_id in dict:
		load_sfx(sound_id, dict[sound_id])


## ===== 便捷方法 =====

func is_sfx_playing() -> bool:
	for player in _sfx_players:
		if player.playing:
			return true
	return false

func is_music_playing() -> bool:
	return _music_player.playing if _music_player != null else false
