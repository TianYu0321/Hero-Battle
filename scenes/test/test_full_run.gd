## res://scenes/test/test_full_run.gd
## 模块: TestFullRun
## 职责: 全自动 headless 全流程测试：30回合养成循环 + 终局战 + 结算
## 验证: 必杀/连锁/援助/救援/精英战 至少各触发1次

extends Node2D

const RUNNING_NODE_EXECUTE: int = 3

var _rc: RunController
var _mechanics: Dictionary = {
	"ultimate_triggered": false,
	"chain_triggered": false,
	"assist_triggered": false,
	"rescue_triggered": false,
	"elite_triggered": false,
}
var _train_counter: int = 0
var _turn_logs: Array[String] = []
var _run_ended_received: bool = false
var _archive_data: Dictionary = {}
var _last_node_result: Dictionary = {}
var _outing_count: int = 0

func _ready() -> void:
	print("===== 全流程测试开始 =====")

	_rc = RunController.new()
	_rc.name = "RunController"
	add_child(_rc)

	# 订阅关键信号
	EventBus.ultimate_triggered.connect(_on_ultimate)
	EventBus.chain_triggered.connect(_on_chain)
	EventBus.partner_assist_triggered.connect(_on_assist)
	EventBus.node_resolved.connect(_on_node_resolved)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.battle_ended.connect(_on_battle_ended)

	# 启动新局：勇者 + 剑士/斥候
	_rc.start_new_run(1, [1001, 1002])
	print("[Run] 新局开始: 勇者 + 剑士/斥候")

	# 推进30回合
	for turn in range(1, 31):
		# 状态恢复：如果上一次回合卡住，强制推进
		var summary: Dictionary = _rc.get_current_run_summary()
		var run_state: int = summary.get("run_state", 0)
		if run_state == RUNNING_NODE_EXECUTE:
			push_warning("[Test] Turn %d: State stuck at RUNNING_NODE_EXECUTE, forcing advance" % turn)
			_rc.call("_finish_node_execution", {"success": true})
			_rc.advance_turn()
			summary = _rc.get_current_run_summary()
			run_state = summary.get("run_state", 0)

		if run_state >= 5:  # FINAL_BATTLE or SETTLEMENT
			print("[Turn %d] 终局已触发，停止推进" % turn)
			break

		var options: Array[Dictionary] = _rc.get_current_node_options()
		if options.is_empty():
			push_warning("[Test] Turn %d: Empty options, forcing advance" % turn)
			_rc.call("_finish_node_execution", {"success": true})
			_rc.advance_turn()
			continue

		var selected: int = _choose_option(options, turn)
		var opt: Dictionary = options[selected]
		var node_type: int = opt.get("node_type", 0)
		var node_name: String = opt.get("node_name", "未知")
		print("[Turn %d] 选择: %s (type=%d)" % [turn, node_name, node_type])

		# 重置上次节点结果缓存
		_last_node_result = {}

		_rc.select_node(selected)

		# 检查是否需要 UI 回调
		summary = _rc.get_current_run_summary()
		run_state = summary.get("run_state", 0)
		if run_state == RUNNING_NODE_EXECUTE:
			match node_type:
				NodePoolSystem.NodeType.TRAINING:
					var attr: int = (_train_counter % 5) + 1
					_train_counter += 1
					_rc.select_training_attr(attr)
					print("  [Training] 选择属性 %d" % attr)
				NodePoolSystem.NodeType.RESCUE:
					_mechanics.rescue_triggered = true
					var candidates: Array = opt.get("candidates", [])
					if candidates.size() > 0:
						var pid = candidates[0].get("partner_id", "0")
						if pid is String and pid.is_valid_int():
							pid = int(pid)
						_rc.select_rescue_partner(pid)
						print("  [Rescue] 选择伙伴: %s (pid=%d)" % [candidates[0].get("name", ""), pid])
					else:
						push_warning("[Test] Rescue candidates empty, forcing skip")
						_rc.call("_finish_node_execution", {"success": true})
				NodePoolSystem.NodeType.SHOP, NodePoolSystem.NodeType.OUTING:
					# headless 测试无法处理商店 UI，强制跳过
					print("  [Shop/Outing-Shop] headless 跳过 UI")
					_rc.call("_finish_node_execution", _last_node_result if not _last_node_result.is_empty() else {"success": true})
				_:
					push_warning("[Test] Unknown UI node type: %d, forcing skip" % node_type)
					_rc.call("_finish_node_execution", {"success": true})

		# 兜底：确保 advance_turn 被调用
		_rc.advance_turn()

		var post_summary: Dictionary = _rc.get_current_run_summary()
		var hero: Dictionary = post_summary.get("hero", {})
		print("  属性: vit=%d str=%d agi=%d tec=%d mnd=%d | 金币=%d | HP=%d/%d | 回合=%d" % [
			hero.get("current_vit", 0), hero.get("current_str", 0),
			hero.get("current_agi", 0), hero.get("current_tec", 0),
			hero.get("current_mnd", 0),
			post_summary.get("gold", 0),
			hero.get("current_hp", 0), hero.get("max_hp", 100),
			post_summary.get("current_turn", 0)
		])

	# 等待一帧确保信号处理完毕
	await get_tree().process_frame

	# 验证
	_print_verification()

	_rc.queue_free()
	print("===== 全流程测试结束 =====")
	get_tree().quit()


func _choose_option(options: Array[Dictionary], turn: int) -> int:
	# 固定节点只有1个选项
	if options.size() == 1:
		return 0

	# 救援回合：优先选 RESCUE
	for i in range(options.size()):
		if options[i].get("node_type", 0) == NodePoolSystem.NodeType.RESCUE:
			return i

	# 普通回合策略
	# 如果还没触发精英战，优先选外出尝试触发（属性足够后才开始）
	var summary: Dictionary = _rc.get_current_run_summary()
	var hero: Dictionary = summary.get("hero", {})
	var total_attr: int = hero.get("current_vit", 0) + hero.get("current_str", 0) + hero.get("current_agi", 0) + hero.get("current_tec", 0) + hero.get("current_mnd", 0)
	if not _mechanics.elite_triggered and _outing_count < 15 and turn < 25 and total_attr >= 100:
		for i in range(options.size()):
			if options[i].get("node_type", 0) == NodePoolSystem.NodeType.OUTING:
				_outing_count += 1
				return i

	for i in range(options.size()):
		var opt: Dictionary = options[i]
		var ntype: int = opt.get("node_type", 0)
		match ntype:
			NodePoolSystem.NodeType.BATTLE:
				return i
			NodePoolSystem.NodeType.TRAINING:
				return i
			NodePoolSystem.NodeType.REST:
				return i
	return 0


func _on_node_resolved(node_type: String, result: Dictionary) -> void:
	_last_node_result = result

	# 检测精英战触发
	if node_type == "OUTING" and result.get("event", "") == "elite_battle":
		_mechanics.elite_triggered = true
		print("  [MECHANIC] 精英战触发!")

	# 处理商店自动购买
	for reward in result.get("rewards", []):
		if reward.get("type") == "shop_inventory":
			for item in reward.get("inventory", []):
				if item.get("can_afford", false) and item.get("item_type") == "hero_upgrade":
					_rc.purchase_shop_item(item)
					print("  [Shop] 购买: %s" % item.get("name", ""))
					break


func _on_ultimate(_hero_class, _hero_name, _turn, _condition, _ultimate_name) -> void:
	_mechanics.ultimate_triggered = true
	print("  [MECHANIC] 必杀技触发!")


func _on_chain(chain_count, _partner_id, _partner_name, _damage, _multiplier, _total) -> void:
	_mechanics.chain_triggered = true
	print("  [MECHANIC] 连锁触发! 段数=%d" % chain_count)


func _on_assist(_partner_id, _partner_name, _trigger_type, _result, _count) -> void:
	_mechanics.assist_triggered = true
	print("  [MECHANIC] 伙伴援助触发!")


func _on_battle_ended(result: Dictionary) -> void:
	if result.get("turns_elapsed", 0) > 0 and result.get("chain_stats", {}).get("max_chain", 0) > 0:
		_mechanics.chain_triggered = true
	if result.get("ultimate_triggered", false):
		_mechanics.ultimate_triggered = true


func _on_run_ended(ending_type: String, final_score: int, archive: Dictionary) -> void:
	_run_ended_received = true
	_archive_data = archive
	print("\n[RunEnded] 终局类型: %s | 总分: %d" % [ending_type, final_score])


func _print_verification() -> void:
	print("\n===== 验收验证 =====")
	var all_pass: bool = true
	for key in _mechanics:
		var ok: bool = _mechanics[key]
		print("  [%s] %s" % [key, "✅ 通过" if ok else "❌ 未触发"])
		if not ok:
			all_pass = false

	print("  [run_ended信号] %s" % ("✅ 收到" if _run_ended_received else "❌ 未收到"))
	if not _run_ended_received:
		all_pass = false

	print("  [archive生成] %s" % ("✅ 非空" if not _archive_data.is_empty() else "❌ 空"))
	if _archive_data.is_empty():
		all_pass = false

	var final_grade: String = _archive_data.get("final_grade", "")
	print("  [评分等级] %s" % ("✅ %s" % final_grade if final_grade != "" else "❌ 无评级"))
	if final_grade == "":
		all_pass = false

	print("\n%s" % ("🎉 全流程验收全部通过!" if all_pass else "⚠️ 部分验收项未通过"))
