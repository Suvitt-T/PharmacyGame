extends RefCounted

var runner

var _spawned: Array[Node] = []


## สร้าง Combatant + Metabolism โดยไม่ต้องมี SceneTree แล้วเดินเวลาด้วยมือ
func _make_body(level: int = 10) -> Array:
	var combatant := Combatant.new()
	combatant.sheet = CharacterSheet.new(level)
	combatant.restore_all()
	var metabolism := Metabolism.new()
	metabolism._combatant = combatant
	_spawned.append(combatant)
	_spawned.append(metabolism)
	return [combatant, metabolism]


## runner เรียกให้หลังจบแต่ละเทสต์ Node ที่ไม่ได้อยู่ใน tree ต้อง free เอง
func teardown() -> void:
	for node in _spawned:
		node.free()
	_spawned.clear()


func _run_for(metabolism: Metabolism, seconds: float, step: float = 0.1) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		metabolism._tick_statuses(step)
		metabolism._tick_effects(step)
		elapsed += step


func test_effect_waits_for_onset_then_expires() -> void:
	var body := _make_body()
	var metabolism: Metabolism = body[1]
	var remedy := Remedy.craft("guarana_seed", 8, Preparation.Method.DECOCTION, 1.0)
	var evaluation := metabolism.administer(remedy)

	runner.ok(evaluation["zone"] == Pharmacokinetics.Zone.THERAPEUTIC, "กัวรานา 8 ชิ้นเข้าโซนออกฤทธิ์")
	runner.equal_int(metabolism.active_substance_ids().size(), 0, "ยังไม่ถึง onset จึงยังไม่ออกฤทธิ์")

	_run_for(metabolism, float(evaluation["onset"]) + 0.5)
	runner.ok(metabolism.active_substance_ids().has("caffeine"), "พ้น onset แล้วออกฤทธิ์")

	_run_for(metabolism, float(evaluation["duration"]) + 1.0)
	runner.equal_int(metabolism.active_effects().size(), 0, "หมด duration แล้วฤทธิ์หายไป")


func test_stat_modifier_applies_and_reverts() -> void:
	var body := _make_body()
	var combatant: Combatant = body[0]
	var metabolism: Metabolism = body[1]
	var baseline := combatant.sheet.final_stats().agility

	var evaluation := metabolism.administer(Remedy.craft("guarana_seed", 8, Preparation.Method.DECOCTION, 1.0))
	_run_for(metabolism, float(evaluation["onset"]) + 0.5)
	runner.ok(combatant.sheet.final_stats().agility > baseline, "คาเฟอีนเพิ่ม AGI ระหว่างออกฤทธิ์")

	_run_for(metabolism, float(evaluation["duration"]) + 1.0)
	runner.equal_float(combatant.sheet.final_stats().agility, baseline, "หมดฤทธิ์แล้วคืนค่าเดิม")


func test_overdose_damages_over_time() -> void:
	var body := _make_body()
	var combatant: Combatant = body[0]
	var metabolism: Metabolism = body[1]
	var before := combatant.current_hp

	var evaluation := metabolism.administer(Remedy.craft("willow_bark", 400, Preparation.Method.DECOCTION, 1.0))
	runner.ok(evaluation["zone"] == Pharmacokinetics.Zone.TOXIC, "เกินขนาดเข้าโซนพิษ")

	_run_for(metabolism, float(evaluation["onset"]) + 3.0)
	runner.ok(combatant.current_hp < before, "โซนพิษกัด HP จริง (%.1f จาก %.1f)" % [combatant.current_hp, before])


func test_underdose_does_nothing() -> void:
	var body := _make_body()
	var combatant: Combatant = body[0]
	var metabolism: Metabolism = body[1]
	var before := combatant.current_hp

	metabolism.administer(Remedy.craft("willow_bark", 1, Preparation.Method.DECOCTION, 1.0))
	_run_for(metabolism, 120.0, 0.5)
	runner.equal_float(combatant.current_hp, before, "ต่ำกว่า ED ไม่มีผลใด ๆ")
	runner.equal_int(metabolism.active_effects().size(), 0, "ไม่เข้าคิวออกฤทธิ์เลย")


func test_antidote_clears_matching_status() -> void:
	var body := _make_body()
	var metabolism: Metabolism = body[1]
	metabolism.apply_status("cholinergic_crisis", 60.0)
	runner.ok(metabolism.has_status("cholinergic_crisis"), "ติดสถานะพิษโคลิเนอร์จิก")

	var evaluation := metabolism.administer(Remedy.craft("belladonna_flower", 5, Preparation.Method.INJECTION_EXTRACT, 1.0))
	runner.ok(evaluation["zone"] == Pharmacokinetics.Zone.THERAPEUTIC, "แอโทรพีนอยู่ในขนาดที่ใช้ได้")
	_run_for(metabolism, float(evaluation["onset"]) + 0.5)
	runner.ok(not metabolism.has_status("cholinergic_crisis"), "ยาแก้พิษตรงกลไกล้างสถานะได้")


func test_wrong_mechanism_does_not_clear_status() -> void:
	var body := _make_body()
	var metabolism: Metabolism = body[1]
	metabolism.apply_status("cholinergic_crisis", 60.0)

	var evaluation := metabolism.administer(Remedy.craft("willow_bark", 12, Preparation.Method.DECOCTION, 1.0))
	_run_for(metabolism, float(evaluation["onset"]) + 0.5)
	runner.ok(metabolism.has_status("cholinergic_crisis"), "ยาลดอักเสบแก้พิษโคลิเนอร์จิกไม่ได้")


## จุดสอนของกลไก Potentiation: ขนาดเดิมกลายเป็นพิษเพราะยาอีกตัวที่ยังออกฤทธิ์อยู่
func test_quinine_turns_a_safe_digoxin_dose_toxic() -> void:
	var body := _make_body()
	var metabolism: Metabolism = body[1]

	var quinine_eval := metabolism.administer(Remedy.craft("cinchona_bark", 9, Preparation.Method.DECOCTION, 1.0))
	_run_for(metabolism, float(quinine_eval["onset"]) + 0.5)
	runner.ok(metabolism.active_substance_ids().has("quinine"), "ควินินกำลังออกฤทธิ์")

	var digoxin_eval := metabolism.administer(Remedy.craft("foxglove_flower", 4, Preparation.Method.INJECTION_EXTRACT, 1.0))
	runner.ok(digoxin_eval["zone"] == Pharmacokinetics.Zone.TOXIC, "ขนาดที่ปกติปลอดภัยกลายเป็นพิษ")


func test_same_dose_is_safe_without_quinine() -> void:
	var body := _make_body()
	var metabolism: Metabolism = body[1]
	var evaluation := metabolism.administer(Remedy.craft("foxglove_flower", 4, Preparation.Method.INJECTION_EXTRACT, 1.0))
	runner.ok(evaluation["zone"] == Pharmacokinetics.Zone.THERAPEUTIC, "ขนาดเดียวกันใช้เดี่ยวปลอดภัย")


func test_resistance_shortens_status() -> void:
	var body := _make_body()
	var metabolism: Metabolism = body[1]
	var evaluation := metabolism.administer(Remedy.craft("willow_bark", 12, Preparation.Method.DECOCTION, 1.0))
	_run_for(metabolism, float(evaluation["onset"]) + 0.5)
	runner.ok(metabolism.resistance_to("inflammation") > 0.0, "ซาลิซินให้ความต้านทานการอักเสบ")

	metabolism.apply_status("inflammation", 10.0)
	runner.ok(metabolism.has_status("inflammation"), "ยังติดสถานะได้ แต่สั้นลง")
