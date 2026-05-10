## res://scripts/core/chain_trigger.gd
## 模块: ChainTrigger
## 职责: 连锁系统：不限制段数，满足条件即可触发
## 依赖: DamageCalculator
## 被依赖: BattleEngine
## class_name: ChainTrigger

class_name ChainTrigger
extends RefCounted

var _dc: DamageCalculator
var _rng: RandomNumberGenerator

func _init(dc: DamageCalculator, rng: RandomNumberGenerator):
	_dc = dc
	_rng = rng

## 尝试触发连锁
## 返回 {triggered: bool, packet: Dictionary, partner_id: String, partner_name: String}
func try_trigger_chain(hero: Dictionary, enemies: Array, partners: Array, turn_chain_count: int) -> Dictionary:
	## v2.0: 不限制段数，不限制伙伴触发次数
	
	# 找所有存活的伙伴
	var valid_partners: Array = []
	for p in partners:
		if p.get("is_alive", true):
			valid_partners.append(p)

	if valid_partners.is_empty():
		return {"triggered": false}

	# 连锁触发概率（随段数递减，防止死循环）
	var base_prob: float = 0.6
	var trigger_prob: float = base_prob * pow(0.7, turn_chain_count)
	if _rng.randf() >= trigger_prob:
		return {"triggered": false}

	# 随机选择一个伙伴触发连锁
	var partner: Dictionary = valid_partners[_rng.randi_range(0, valid_partners.size() - 1)]
	var target = _get_front_enemy(enemies)
	if target == null or target.is_empty():
		return {"triggered": false}

	## 连锁伤害递增
	var scale: float = 0.4 + turn_chain_count * 0.1
	var pkt: Dictionary = _dc.compute_damage(partner, target, scale, "CHAIN")
	_dc.apply_damage_packet(target, pkt)
	
	## v2.0: 不增加chain_count限制（概率递减已防止死循环）
	partner.chain_count = partner.get("chain_count", 0) + 1

	return {
		"triggered": true,
		"packet": pkt,
		"partner_id": partner.get("partner_id", ""),
		"partner_name": partner.get("partner_name", ""),
		"chain_count": turn_chain_count + 1,
	}

func _get_front_enemy(enemies: Array) -> Dictionary:
	for e in enemies:
		if e.get("is_alive", false):
			return e
	return {}
