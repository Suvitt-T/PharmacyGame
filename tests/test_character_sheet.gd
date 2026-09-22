extends RefCounted

var runner


## ตัวอย่างคำนวณจริงในเอกสาร: นักรบพฤกษา Lv15 แจก VIT 25 / STR 15 / AGI 5
func _doc_example() -> CharacterSheet:
	var sheet := CharacterSheet.new(15)
	sheet.class_id = CharacterClass.Id.HERB_VANGUARD
	sheet.class_chosen_at_level = 10
	sheet.allocate("vitality", 25)
	sheet.allocate("strength", 15)
	sheet.allocate("agility", 5)
	return sheet


func test_doc_example_stats() -> void:
	var sheet := _doc_example()
	var stats := sheet.final_stats()
	runner.equal_int(sheet.unspent_points(), 0, "ใช้แต้มครบ 45")
	runner.equal_float(stats.strength, 22.5, "STR = 5 + 15 + 2.5")
	runner.equal_float(stats.vitality, 35.0, "VIT = 5 + 25 + 5")
	runner.equal_float(stats.agility, 10.0, "AGI = 5 + 5")
	runner.equal_float(stats.intellect, 5.0, "INT = 5")


func test_doc_example_derived() -> void:
	var sheet := _doc_example()
	runner.equal_float(sheet.max_hp(), 435.0, "HP = 435")
	runner.equal_float(sheet.max_mana(), 130.0, "Mana = 130")
	runner.equal_float(sheet.crit_chance(), 1.5, "Crit = 1.5%")


func test_class_growth_starts_at_unlock() -> void:
	var sheet := CharacterSheet.new(10)
	sheet.class_id = CharacterClass.Id.ALCHEMIST
	sheet.class_chosen_at_level = 10
	runner.equal_float(sheet.final_stats().intellect, 5.0, "เพิ่งเลือกอาชีพ ยังไม่มีโบนัส")
	sheet.level = 20
	runner.equal_float(sheet.final_stats().intellect, 15.0, "Lv20 นักปรุงยา = +10 INT")


func test_no_class_no_growth() -> void:
	var sheet := CharacterSheet.new(20)
	runner.equal_int(sheet.class_growth_levels(), 0, "ยังไม่มีอาชีพ = ไม่มีโบนัส")
	runner.equal_float(sheet.final_stats().intellect, 5.0, "INT คงที่ 5")


func test_allocation_limits() -> void:
	var sheet := CharacterSheet.new(1)
	runner.equal_int(sheet.unspent_points(), 3, "Lv1 มี 3 แต้ม")
	runner.ok(sheet.allocate("strength", 3), "แจกครบ 3 แต้มได้")
	runner.ok(not sheet.allocate("strength", 1), "แจกเกินไม่ได้")
	runner.ok(not sheet.allocate("charisma", 1), "stat ที่ไม่มีจริงแจกไม่ได้")
	sheet.respec()
	runner.equal_int(sheet.unspent_points(), 3, "respec คืนแต้มครบ")


func test_xp_and_level_up() -> void:
	var sheet := CharacterSheet.new(1)
	runner.equal_int(sheet.add_xp(99), 0, "99 XP ยังไม่อัพ")
	runner.equal_int(sheet.add_xp(1), 1, "ครบ 100 XP อัพ 1 เลเวล")
	runner.equal_int(sheet.level, 2, "อยู่ Lv2")
	runner.equal_int(sheet.add_xp(370), 2, "370 XP ข้าม 2 เลเวลรวด")
	runner.equal_int(sheet.level, 4, "อยู่ Lv4")
	runner.equal_int(sheet.xp_into_current_level(), 0, "เข้าเลเวลใหม่พอดี")


func test_class_choice_gate() -> void:
	var sheet := CharacterSheet.new(9)
	runner.ok(not sheet.choose_class(CharacterClass.Id.FIELD_MEDIC), "Lv9 เลือกอาชีพไม่ได้")
	sheet.level = 10
	runner.ok(sheet.choose_class(CharacterClass.Id.FIELD_MEDIC), "Lv10 เลือกได้")
	runner.ok(not sheet.choose_class(CharacterClass.Id.ALCHEMIST), "เลือกซ้ำไม่ได้")
	runner.equal_int(sheet.unlocked_skill_slots(), 1, "Lv10 ปลดล็อกสกิล 1 ช่อง")
	sheet.level = 22
	runner.equal_int(sheet.unlocked_skill_slots(), 5, "Lv22 ปลดล็อกครบ 5 ช่อง")


func test_save_roundtrip() -> void:
	var sheet := _doc_example()
	var restored := CharacterSheet.from_dict(sheet.to_dict())
	runner.equal_int(restored.level, 15, "เลเวลกลับมาครบ")
	runner.equal_float(restored.final_stats().vitality, 35.0, "VIT กลับมาครบ")
	runner.equal_float(restored.max_hp(), 435.0, "HP กลับมาครบ")
	runner.ok(restored.class_id == CharacterClass.Id.HERB_VANGUARD, "อาชีพกลับมาครบ")
