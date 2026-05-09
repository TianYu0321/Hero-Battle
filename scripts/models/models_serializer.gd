## res://scripts/models/models_serializer.gd
## 模块: ModelsSerializer
## 职责: 全局序列化器，所有模型 <-> JSON 互转
## 依赖: 所有数据模型类
## class_name: ModelsSerializer

class_name ModelsSerializer
extends RefCounted


func serialize(obj: Object) -> String:
	if obj == null:
		return "{}"
	if obj.has_method("to_dict"):
		var dict: Dictionary = obj.call("to_dict")
		return JSON.stringify(dict)
	push_warning("[ModelsSerializer] Object has no to_dict method: %s" % obj.get_class())
	return "{}"


func serialize_to_dict(obj: Object) -> Dictionary:
	if obj == null:
		return {}
	if obj.has_method("to_dict"):
		return obj.call("to_dict")
	push_warning("[ModelsSerializer] Object has no to_dict method: %s" % obj.get_class())
	return {}


func deserialize(json_text: String, model_type: String) -> Object:
	var parsed = JSON.parse_string(json_text)
	if parsed == null:
		push_error("[ModelsSerializer] JSON parse failed")
		return null
	if parsed is Dictionary:
		return deserialize_from_dict(parsed, model_type)
	push_error("[ModelsSerializer] JSON root is not Dictionary")
	return null


func deserialize_from_dict(data: Dictionary, model_type: String) -> Object:
	# 安全加载：已确认存在的类直接调用，可能不存在的类通过动态加载避免编译错误
	match model_type:
		"RuntimeRun":
			return RuntimeRun.from_dict(data)
		"RuntimeHero":
			return RuntimeHero.from_dict(data)
		"RuntimePartner":
			return RuntimePartner.from_dict(data)
		"RuntimeMastery":
			return RuntimeMastery.from_dict(data)
		"RuntimeBuff":
			return _safe_load_and_call("res://scripts/models/runtime_buff.gd", data)
		"RuntimeTrainingLog":
			return _safe_load_and_call("res://scripts/models/runtime_training_log.gd", data)
		"RuntimeFinalBattle":
			return _safe_load_and_call("res://scripts/models/runtime_final_battle.gd", data)
		"PlayerAccount":
			return PlayerAccount.from_dict(data)
		"FighterArchiveMain":
			return FighterArchiveMain.from_dict(data)
		"FighterArchivePartner":
			return _safe_load_and_call("res://scripts/models/fighter_archive_partner.gd", data)
		"FighterArchiveScore":
			return _safe_load_and_call("res://scripts/models/fighter_archive_score.gd", data)
		"BattleMain":
			return _safe_load_and_call("res://scripts/models/battle_main.gd", data)
		"BattleRound":
			return _safe_load_and_call("res://scripts/models/battle_round.gd", data)
		"BattleAction":
			return _safe_load_and_call("res://scripts/models/battle_action.gd", data)
		"BattleFinalResult":
			return _safe_load_and_call("res://scripts/models/battle_final_result.gd", data)
		_:
			push_error("[ModelsSerializer] Unknown model type: %s" % model_type)
			return null


func _safe_load_and_call(script_path: String, data: Dictionary) -> Object:
	var script = load(script_path)
	if script == null:
		push_warning("[ModelsSerializer] Script not found: %s, returning null" % script_path)
		return null
	if script.has_method("from_dict"):
		return script.from_dict(data)
	push_warning("[ModelsSerializer] Script %s has no from_dict method, returning null" % script_path)
	return null


func roundtrip_test(obj: Object, model_type: String) -> bool:
	var dict1: Dictionary = serialize_to_dict(obj)
	var json_text: String = JSON.stringify(dict1)
	var parsed = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		return false
	var restored: Object = deserialize_from_dict(parsed, model_type)
	if restored == null:
		return false
	var dict2: Dictionary = serialize_to_dict(restored)
	return dict1.hash() == dict2.hash()


static func load_json_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_warning("[ModelsSerializer] File not found: %s" % file_path)
		return {}
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[ModelsSerializer] Cannot open file: %s" % file_path)
		return {}
	var text: String = file.get_as_text()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("[ModelsSerializer] JSON parse error in: %s" % file_path)
		return {}
	if parsed is Dictionary:
		return parsed
	push_error("[ModelsSerializer] JSON root is not Dictionary: %s" % file_path)
	return {}
