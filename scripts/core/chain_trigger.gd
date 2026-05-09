## res://scripts/core/chain_trigger.gd
## 模块: ChainTrigger
## 职责: 连锁系统：段数上限4，同伙伴单场上限2次
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
	if turn_chain_count >= 4:
		return {"triggered": false}

	# 找一个未达连锁上限的伙伴
	var valid_partners: Array = []
	for p in partners:
		if p.get("is_alive", true) and p.get("chain_count", 0) < 2:
			valid_partners.append(p)

	if valid_partners.is_empty():
		return {"triggered": false}

	# 随机选择一个伙伴触发连锁
	var partner: Dictionary = valid_partners[_rng.randi_range(0, valid_partners.size() - 1)]
	var target = _get_front_enemy(enemies)
	if target == null:
		return {"triggered": false}

	var scale: float = 0.4 + turn_chain_count * 0.1  # 连锁伤害递增
	var pkt: Dictionary = _dc.compute_damage(partner, target, scale, "CHAIN")
	_dc.apply_damage_packet(target, pkt)
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
