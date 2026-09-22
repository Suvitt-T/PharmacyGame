class_name CombatMath
extends RefCounted

## คำนวณผลการโจมตี 1 ครั้ง เป็น pure function รับ rng จากภายนอกเพื่อให้เทสต์ผลลัพธ์แน่นอนได้

enum AttackKind { PHYSICAL, SKILL }


static func resolve(
	kind: AttackKind,
	base_power: float,
	attacker: StatBlock,
	defender: StatBlock,
	defender_defense: float,
	rng: RandomNumberGenerator,
	can_evade: bool = true
) -> Dictionary:
	if can_evade and rng.randf() * 100.0 < Formulas.evasion_chance_percent(defender.agility):
		return {"damage": 0.0, "evaded": true, "critical": false, "raw": 0.0}

	var raw := 0.0
	match kind:
		AttackKind.PHYSICAL:
			raw = Formulas.physical_damage(base_power, attacker.strength)
		AttackKind.SKILL:
			raw = Formulas.skill_damage(base_power, attacker.intellect)

	var critical := rng.randf() * 100.0 < Formulas.crit_chance_percent(attacker.agility)
	if critical:
		raw *= Formulas.CRIT_MULTIPLIER

	return {
		"damage": Formulas.damage_after_defense(raw, defender_defense),
		"evaded": false,
		"critical": critical,
		"raw": raw,
	}
