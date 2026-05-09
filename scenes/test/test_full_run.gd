## res://scenes/test/test_full_run.gd
## 模块: TestFullRun
## 职责: 全自动 headless 全流程测试：30回合养成循环 + 终局战 + 结算
## 验证: 必杀/连锁/援助/救援/精英战 至少各触发1次

extends Node2D

var _rc: RunController
var _mechanics: Dictionary = {
	"ultimate_triggered": false,
	"chain_triggered": false,
	"assist_triggered": false,
	"rescue_triggered": false,
	"elite_triggered": false,
}
var _train_counter: int = 0  # 用于交替锻炼体魄(1)和力量(2)
var _turn_logs: Array[String] = []
var _run_ended_received: bool = false
var _archive_data: Dictionary = {}

func _ready() -> void:
	print("===== 全流程测试开始 =====")

	_rc = RunController.new()
	_rc.name = "RunController"
	add_child(_rc)

	# 订阅关键信号
	EventBus.ultimate_triggered.connect(_on_ultimate)
	EventBus.chain_triggered.connect(_on_chain)
	EventBus.partner_assist_triggered.connect(_on_assist)
	EventBus.rescue_encountered.connect(_on_rescue)
	EventBus.node_resolved.connect(_on_node_resolved)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.battle_ended.connect(_on_battle_ended)

	# 启动新局：勇者 + 剑士/斥候
	_rc.start_new_run(1, [1001, 1002])
	print("[Run] 新局开始: 勇者 + 剑士/斥候")

	# 推进30回合
	for turn in range(1, 31):
		var summary: Dictionary = _rc.get_current_run_summary()
		if summary.get("run_state", 0) >= 5:  # FINAL_BATTLE or SETTLEMENT
			break

		var options: Array[Dictionary] = _rc.get_current_node_options()
		var selected: int = _choose_option(options, turn)
		var node_name: String = options[selected].get("node_name", "未知")
		print("[Turn %d] 选择: %s" % [turn, node_name])

		_rc.select_node(selected)
		# select_node 内部执行节点并进入 TURN_ADVANCE
		_rc.advance_turn()

		var post_summary: Dictionary = _rc.get_current_run_summary()
		var hero: Dictionary = post_summary.get("hero", {})
		print("  属性: vit=%d str=%d agi=%d tec=%d mnd=%d | 金币=%d" % [
			hero.get("current_vit", 0), hero.get("current_str", 0),
			hero.get("current_agi", 0), hero.get("current_tec", 0),
			hero.get("current_mnd", 0),
			post_summary.get("gold", 0)
		])

	# 等待一帧确保信号处理完毕
	await get_tree().process_frame

	# 验证
	_print_verification()

	_rc.queue_free()
	print("===== 全流程测试结束 =====")
	get_tree().quit()


func _choose_option(options: Array[Dictionary], _turn: int) -> int:
	# 固定节点只有1个选项
	if options.size() == 1:
		return 0

	# 普通回合优先策略：交替锻炼体魄/力量 > 战斗 > 精英 > 商店
	for i in range(options.size()):
		var opt: Dictionary = options[i]
		match opt.get("node_type", 0):
			1:  # TRAINING
				var attr: int = opt.get("attr_type", 1)
				var target_attr: int = 1 if _train_counter % 2 == 0 else 2
				if attr == target_attr:
					_train_counter += 1
					return i
			2:  return i  # BATTLE
			3:  return i  # ELITE
			4:  return i  # SHOP
	# 兜底：如果有锻炼选项就选第一个
	for i in range(options.size()):
		if options[i].get("node_type", 0) == 1:
			_train_counter += 1
			return i
	return 0


func _on_node_resolved(node_type: String, result: Dictionary) -> void:
	if node_type == "ELITE":
		_mechanics.elite_triggered = true
		print("  [MECHANIC] 精英战触发!")

	# 处理商店自动购买（第一个可负担的主角属性强化）
	for reward in result.get("rewards", []):
		if reward.get("type") == "shop_inventory":
			for item in reward.get("inventory", []):
				if item.get("can_afford", false) and item.get("item_type") == "hero_upgrade":
					_rc.purchase_shop_item(item)
					print("  [Shop] 购买: %s" % item.get("name", ""))
					break
		elif reward.get("type") == "rescue_candidates":
			var candidates: Array = reward.get("candidates", [])
			if candidates.size() > 0:
				var pid = candidates[0].get("partner_id", 0)
				if pid is String and pid.is_valid_int():
					pid = int(pid)
				_rc.select_rescue_partner(pid)
				print("  [Rescue] 选择伙伴: %s" % candidates[0].get("name", ""))
		elif reward.get("type") == "elite_reward_choice":
			var opts: Array = reward.get("options", [])
			if opts.size() > 0:
				# 自动选择金币奖励
				for opt in opts:
					if opt.get("type") == "gold":
						print("  [EliteReward] 选择: %s" % opt.get("name", ""))
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


func _on_rescue(_candidates, _turn) -> void:
	_mechanics.rescue_triggered = true
	print("  [MECHANIC] 救援触发!")


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
