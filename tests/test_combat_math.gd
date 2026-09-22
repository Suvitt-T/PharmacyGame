extends RefCounted

var runner


func _rng(seed_value: int) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


func test_no_evasion_no_crit() -> void:
	var attacker := StatBlock.make(50.0, 0.0, 0.0, 0.0)
	var defender := StatBlock.make(0.0, 0.0, 0.0, 0.0)
	var result := CombatMath.resolve(
		CombatMath.AttackKind.PHYSICAL, 100.0, attacker, defender, 0.0, _rng(1)
	)
	runner.ok(not result["evaded"], "AGI 0 หลบไม่ได้")
	runner.ok(not result["critical"], "AGI 0 คริติคอลไม่ได้")
	runner.equal_float(result["damage"], 200.0, "STR 50 กับ base 100 = 200")


func test_defense_reduces_damage() -> void:
	var attacker := StatBlock.make(0.0, 0.0, 0.0, 0.0)
	var defender := StatBlock.make(0.0, 0.0, 0.0, 0.0)
	var result := CombatMath.resolve(
		CombatMath.AttackKind.PHYSICAL, 100.0, attacker, defender, 100.0, _rng(1)
	)
	runner.equal_float(result["damage"], 50.0, "DEF 100 ลดดาเมจครึ่งหนึ่ง")


func test_guaranteed_evasion() -> void:
	var attacker := StatBlock.make(0.0, 0.0, 0.0, 0.0)
	var defender := StatBlock.make(0.0, 0.0, 0.0, 1000.0)
	var evaded_count := 0
	for i in range(200):
		var result := CombatMath.resolve(
			CombatMath.AttackKind.PHYSICAL, 100.0, attacker, defender, 0.0, _rng(i)
		)
		if result["evaded"]:
			evaded_count += 1
	runner.ok(evaded_count > 40 and evaded_count < 80, "Evasion เพดาน 30%% ได้ %d/200" % evaded_count)


func test_guaranteed_crit() -> void:
	var attacker := StatBlock.make(0.0, 0.0, 0.0, 1000.0)
	var defender := StatBlock.make(0.0, 0.0, 0.0, 0.0)
	var crit_count := 0
	for i in range(200):
		var result := CombatMath.resolve(
			CombatMath.AttackKind.PHYSICAL, 100.0, attacker, defender, 0.0, _rng(i)
		)
		if result["critical"]:
			crit_count += 1
	runner.ok(crit_count > 55 and crit_count < 105, "Crit เพดาน 40%% ได้ %d/200" % crit_count)


func test_skill_uses_intellect() -> void:
	var attacker := StatBlock.make(0.0, 40.0, 0.0, 0.0)
	var defender := StatBlock.make(0.0, 0.0, 0.0, 0.0)
	var result := CombatMath.resolve(
		CombatMath.AttackKind.SKILL, 100.0, attacker, defender, 0.0, _rng(1)
	)
	runner.equal_float(result["damage"], 200.0, "INT 40 กับสกิล base 100 = 200")


func test_cannot_evade_flag() -> void:
	var attacker := StatBlock.make(0.0, 0.0, 0.0, 0.0)
	var defender := StatBlock.make(0.0, 0.0, 0.0, 1000.0)
	for i in range(50):
		var result := CombatMath.resolve(
			CombatMath.AttackKind.PHYSICAL, 100.0, attacker, defender, 0.0, _rng(i), false
		)
		if result["evaded"]:
			runner.ok(false, "can_evade=false ต้องไม่หลบเลย")
			return
	runner.ok(true, "can_evade=false ไม่หลบเลยครบ 50 ครั้ง")
