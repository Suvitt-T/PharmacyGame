extends RefCounted

var runner

var _spawned: Array[Node] = []


func teardown() -> void:
	for node in _spawned:
		node.free()
	_spawned.clear()


func _make_caster(class_id: CharacterClass.Id, level: int = 22) -> SkillRuntime:
	var combatant := Combatant.new()
	combatant.sheet = CharacterSheet.new(level)
	combatant.sheet.class_id = class_id
	combatant.sheet.class_chosen_at_level = 10
	combatant.restore_all()

	var metabolism := Metabolism.new()
	metabolism._combatant = combatant

	var runtime := SkillRuntime.new()
	runtime._combatant = combatant
	runtime._metabolism = metabolism
	runtime.tree.class_id = class_id

	_spawned.append(combatant)
	_spawned.append(metabolism)
	_spawned.append(runtime)
	return runtime


func _learn(runtime: SkillRuntime, skill_id: String) -> void:
	runtime.tree.learn(SkillDB.skill(skill_id), runtime._combatant.sheet.level)
	runtime.refresh_passives()


func test_cannot_use_unlearned_skill() -> void:
	var runtime := _make_caster(CharacterClass.Id.FIELD_MEDIC)
	runner.ok(not runtime.use("medic_first_aid"), "ยังไม่ได้เรียน ใช้ไม่ได้")
	runner.ok(runtime.can_use(SkillDB.skill("medic_first_aid")) == "ยังไม่ได้เรียนสกิลนี้", "บอกเหตุผลถูก")


func test_heal_spends_mana_and_starts_cooldown() -> void:
	var runtime := _make_caster(CharacterClass.Id.FIELD_MEDIC)
	_learn(runtime, "medic_first_aid")
	var combatant := runtime._combatant
	combatant.set_hp(combatant.current_hp - 80.0)
	var mana_before := combatant.current_mana
	var hp_before := combatant.current_hp

	runner.ok(runtime.use("medic_first_aid"), "ใช้สกิลได้")
	runner.ok(combatant.current_hp > hp_before, "HP เพิ่มขึ้น")
	runner.equal_float(mana_before - combatant.current_mana, 25.0, "เสีย Mana 25 ตามตาราง")
	runner.equal_float(runtime.remaining_cooldown("medic_first_aid"), 10.0, "คูลดาวน์ 10 วิ")
	runner.ok(not runtime.use("medic_first_aid"), "ติดคูลดาวน์ ใช้ซ้ำไม่ได้")

	runtime._tick_cooldowns(10.1)
	runner.ok(runtime.use("medic_first_aid"), "พ้นคูลดาวน์แล้วใช้ได้อีก")


func test_not_enough_mana_blocks_use() -> void:
	var runtime := _make_caster(CharacterClass.Id.ALCHEMIST)
	_learn(runtime, "alch_mobile_lab")
	runtime._combatant.set_mana(10.0)
	runner.ok(not runtime.use("alch_mobile_lab"), "Mana ไม่พอ ใช้ไม่ได้")
	runner.equal_float(runtime.remaining_cooldown("alch_mobile_lab"), 0.0, "ไม่กินคูลดาวน์ตอนใช้ไม่สำเร็จ")


func test_shield_absorbs_damage_then_expires() -> void:
	var runtime := _make_caster(CharacterClass.Id.HERB_VANGUARD)
	_learn(runtime, "vang_root_armor")
	var combatant := runtime._combatant

	runtime.use("vang_root_armor")
	runner.equal_float(combatant.shield_points, 60.0, "ได้เกราะ 60")

	var hp_before := combatant.current_hp
	combatant.apply_attack_result({"damage": 40.0, "evaded": false, "critical": false})
	runner.equal_float(combatant.current_hp, hp_before, "เกราะกินดาเมจไว้หมด HP ไม่ลด")
	runner.equal_float(combatant.shield_points, 20.0, "เกราะเหลือ 20")

	combatant.apply_attack_result({"damage": 50.0, "evaded": false, "critical": false})
	runner.ok(combatant.current_hp < hp_before, "เกราะไม่พอ ส่วนเกินลง HP")

	runtime.use("vang_root_armor")
	runtime._tick_self_buffs(11.0)
	runner.equal_float(combatant.shield_points, 0.0, "หมดเวลาแล้วเกราะหาย")


func test_stat_buff_applies_and_reverts() -> void:
	var runtime := _make_caster(CharacterClass.Id.HERB_VANGUARD)
	_learn(runtime, "vang_strength_extract")
	var sheet := runtime._combatant.sheet
	var before := sheet.final_stats().strength

	runtime.use("vang_strength_extract")
	runner.equal_float(sheet.final_stats().strength, before + 8.0, "STR เพิ่มระหว่างบัฟ")

	runtime._tick_self_buffs(19.0)
	runner.equal_float(sheet.final_stats().strength, before, "หมดเวลาแล้วคืนค่าเดิม")


func test_toggle_drains_mana_until_empty() -> void:
	var runtime := _make_caster(CharacterClass.Id.HERB_VANGUARD)
	_learn(runtime, "vang_thorn_guard")
	runner.ok(runtime.use("vang_thorn_guard"), "เปิด toggle ได้")
	runner.ok(runtime.is_toggled("vang_thorn_guard"), "อยู่ในสถานะเปิด")

	var combatant := runtime._combatant
	var mana_before := combatant.current_mana
	runtime._tick_toggles(2.0)
	runner.equal_float(mana_before - combatant.current_mana, 10.0, "2 วินาที เสีย 10 Mana")

	combatant.set_mana(0.0)
	runtime._tick_toggles(1.0)
	runner.ok(not runtime.is_toggled("vang_thorn_guard"), "Mana หมดแล้วปิดเอง")


func test_once_per_fight_quota() -> void:
	var runtime := _make_caster(CharacterClass.Id.FIELD_MEDIC)
	# Ultimate เลือกได้ต่อเมื่อล็อกสายแล้ว จึงต้องเลือกสาย A ครบ 2 ครั้งก่อน
	_learn(runtime, "medic_detox")
	_learn(runtime, "medic_field_suture")
	_learn(runtime, "medic_miracle")
	runner.ok(runtime.tree.has_skill("medic_miracle"), "เรียน Ultimate ของสายที่ล็อกไว้ได้")
	runtime.start_fight()

	runner.ok(runtime.use("medic_miracle"), "ใช้ครั้งแรกได้")
	runner.ok(not runtime.use("medic_miracle"), "ไฟต์เดียวกันใช้ซ้ำไม่ได้")

	runtime.start_fight()
	runtime._combatant.restore_all()
	runner.ok(runtime.use("medic_miracle"), "ไฟต์ใหม่ใช้ได้อีก")


func test_passive_damage_reduction_reaches_the_combatant() -> void:
	var runtime := _make_caster(CharacterClass.Id.HERB_VANGUARD)
	var combatant := runtime._combatant
	runner.equal_float(combatant.damage_reduction, 0.0, "ยังไม่มี passive")

	_learn(runtime, "vang_bark_skin")
	runner.equal_float(combatant.damage_reduction, 0.12, "ผิวเปลือกไม้ลดดาเมจ 12%")

	var hp_before := combatant.current_hp
	combatant.apply_attack_result({"damage": 100.0, "evaded": false, "critical": false})
	runner.equal_float(hp_before - combatant.current_hp, 88.0, "โดน 100 เหลือ 88")


func test_passive_cannot_be_activated() -> void:
	var runtime := _make_caster(CharacterClass.Id.TOXICOLOGIST)
	_learn(runtime, "tox_stacking_venom")
	runner.ok(not runtime.use("tox_stacking_venom"), "สกิล Passive กดใช้ไม่ได้")


func test_self_tolerance_trades_hp_for_power() -> void:
	var runtime := _make_caster(CharacterClass.Id.TOXICOLOGIST)
	_learn(runtime, "tox_self_tolerance")
	var combatant := runtime._combatant
	var hp_before := combatant.current_hp

	runner.ok(runtime.use("tox_self_tolerance"), "ใช้ได้")
	runner.ok(combatant.current_hp < hp_before, "แลก HP ไปจริง")


func test_cleanse_clears_every_status() -> void:
	var runtime := _make_caster(CharacterClass.Id.FIELD_MEDIC)
	_learn(runtime, "medic_detox")
	var metabolism := runtime._metabolism
	metabolism.apply_status("cyclic_fever", 30.0)
	metabolism.apply_status("infection", 30.0)

	runtime.use("medic_detox")
	runner.equal_int(metabolism.status_list().size(), 0, "ล้างสถานะผิดปกติทั้งหมด")
