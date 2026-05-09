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
			return RuntimeBuff.from_dict(data)
		"RuntimeTrainingLog":
			return RuntimeTrainingLog.from_dict(data)
		"RuntimeFinalBattle":
			return RuntimeFinalBattle.from_dict(data)
		"PlayerAccount":
			return PlayerAccount.from_dict(data)
		"FighterArchiveMain":
			return FighterArchiveMain.from_dict(data)
		"FighterArchivePartner":
			return FighterArchivePartner.from_dict(data)
		"FighterArchiveScore":
			return FighterArchiveScore.from_dict(data)
		"BattleMain":
			return BattleMain.from_dict(data)
		"BattleRound":
			return BattleRound.from_dict(data)
		"BattleAction":
			return BattleAction.from_dict(data)
		"BattleFinalResult":
			return BattleFinalResult.from_dict(data)
		_:
			push_error("[ModelsSerializer] Unknown model type: %s" % model_type)
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
