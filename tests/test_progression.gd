extends RefCounted

var runner


func test_cumulative_matches_doc_table() -> void:
	runner.equal_int(Progression.cumulative_xp_for(1), 0, "Lv1 สะสม 0")
	runner.equal_int(Progression.cumulative_xp_for(2), 100, "Lv2 สะสม 100")
	runner.equal_int(Progression.cumulative_xp_for(10), 4170, "Lv10 สะสม 4,170")
	runner.equal_int(Progression.cumulative_xp_for(15), 14670, "Lv15 สะสม 14,670")
	runner.equal_int(Progression.cumulative_xp_for(20), 43670, "Lv20 สะสม 43,670")
	runner.equal_int(Progression.cumulative_xp_for(25), 123670, "Lv25 สะสม 123,670")


func test_level_lookup_roundtrip() -> void:
	for level in range(1, Progression.MAX_LEVEL + 1):
		var xp := Progression.cumulative_xp_for(level)
		runner.equal_int(Progression.level_for_cumulative_xp(xp), level, "XP %d = Lv %d" % [xp, level])


func test_level_lookup_boundaries() -> void:
	runner.equal_int(Progression.level_for_cumulative_xp(99), 1, "99 XP ยัง Lv1")
	runner.equal_int(Progression.level_for_cumulative_xp(100), 2, "100 XP ขึ้น Lv2")
	runner.equal_int(Progression.level_for_cumulative_xp(999999), 25, "XP ล้นหยุดที่ Lv25")


func test_stat_points() -> void:
	runner.equal_int(Progression.total_stat_points(15), 45, "Lv15 ได้ 45 แต้ม ตามตัวอย่างในเอกสาร")
	runner.equal_int(Progression.total_stat_points(25), 75, "Lv25 ได้ 75 แต้ม")


func test_act_mapping() -> void:
	runner.ok(Progression.act_for_level(9) == "prologue", "Lv9 อยู่บทนำ")
	runner.ok(Progression.act_for_level(10) == "act_1", "Lv10 เข้า Act 1")
	runner.ok(Progression.act_for_level(19) == "act_2", "Lv19 อยู่ Act 2")
	runner.ok(Progression.act_for_level(25) == "act_3", "Lv25 อยู่ Act 3")
