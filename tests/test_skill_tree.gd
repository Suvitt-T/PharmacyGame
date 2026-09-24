extends RefCounted

var runner

const ALL_CLASSES := [
	CharacterClass.Id.ALCHEMIST,
	CharacterClass.Id.FIELD_MEDIC,
	CharacterClass.Id.TOXICOLOGIST,
	CharacterClass.Id.HERB_VANGUARD,
]


func test_every_class_has_the_full_ladder() -> void:
	for class_id in ALL_CLASSES:
		runner.equal_int(SkillDB.choices_at(class_id, 10).size(), 1, "Lv10 มีสกิลเดียวทุกสายได้เหมือนกัน")
		for level in SkillDB.CHOICE_LEVELS:
			runner.equal_int(SkillDB.choices_at(class_id, level).size(), 2, "Lv%d มีคู่ A/B ให้เลือก" % level)
		runner.equal_int(SkillDB.choices_at(class_id, 22).size(), 2, "Lv22 มี Ultimate 2 สาย")
		runner.equal_int(SkillDB.skills_for_class(class_id).size(), 9, "รวม 9 สกิลต่ออาชีพ")


## เอกสารบอกว่ามี 8 playstyle รวมทั้งเกม = 4 อาชีพ x 2 สาย
func test_eight_playstyles_exist() -> void:
	var branch_count := 0
	for class_id in ALL_CLASSES:
		var names := SkillDB.branch_names(class_id)
		runner.equal_int(names.size(), 2, "%s มี 2 สายย่อย" % CharacterClass.display_name(class_id))
		branch_count += names.size()
	runner.equal_int(branch_count, 8, "รวม 8 playstyle ตามเอกสาร")


## ค่าที่เอกสารระบุไว้ต้องไม่ถูกแก้โดยไม่ตั้งใจ
func test_doc_skill_values_are_preserved() -> void:
	var expected := {
		"alch_flash_distill": [20.0, 8.0, "กลั่นเร่งด่วน"],
		"alch_concentrate": [25.0, 15.0, "สูตรเข้มข้น"],
		"alch_diffusion": [35.0, 20.0, "การกระจายฤทธิ์"],
		"alch_mobile_lab": [80.0, 90.0, "ห้องทดลองเคลื่อนที่"],
		"medic_first_aid": [25.0, 10.0, "ปฐมพยาบาลฉับไว"],
		"medic_detox": [20.0, 15.0, "คลายพิษ"],
		"medic_immune_boost": [30.0, 25.0, "กระตุ้นภูมิคุ้มกัน"],
		"medic_rapid_diagnosis": [15.0, 5.0, "วิเคราะห์อาการเร่งด่วน"],
		"tox_venom_needle": [15.0, 6.0, "เข็มพิษ"],
		"tox_weak_point": [10.0, 8.0, "วิเคราะห์จุดอ่อน"],
		"tox_self_tolerance": [20.0, 30.0, "ดื้อพิษตนเอง"],
		"tox_epidemiology": [90.0, 90.0, "ระบาดวิทยา"],
		"vang_root_armor": [20.0, 12.0, "เกราะรากไม้"],
		"vang_strength_extract": [25.0, 20.0, "สารสกัดพลังกาย"],
		"vang_entangle": [30.0, 18.0, "รากยึดเหนี่ยว"],
		"vang_reborn_forest": [85.0, 100.0, "ป่าเกิดใหม่"],
	}
	for skill_id in expected:
		var skill := SkillDB.skill(skill_id)
		runner.ok(skill != null and skill.is_from_doc(), "%s มาจากเอกสาร" % skill_id)
		runner.equal_float(skill.mana_cost, expected[skill_id][0], "%s Mana ตรงตาราง" % skill_id)
		runner.equal_float(skill.cooldown, expected[skill_id][1], "%s Cooldown ตรงตาราง" % skill_id)
		runner.ok(skill.name == expected[skill_id][2], "%s ชื่อตรงตาราง" % skill_id)


func test_doc_special_cases() -> void:
	var miracle := SkillDB.skill("medic_miracle")
	runner.equal_int(miracle.uses_per_fight, 1, "ปาฏิหาริย์แห่งชีพจร ใช้ได้ 1 ครั้ง/ไฟต์")
	runner.equal_float(miracle.mana_cost, 100.0, "Mana 100")

	var thorns := SkillDB.skill("vang_thorn_guard")
	runner.ok(thorns.kind == Skill.Kind.TOGGLE, "หนามป้องกันเป็น Toggle")
	runner.equal_float(thorns.mana_per_second, 5.0, "5 Mana ต่อวินาที")

	var stacking := SkillDB.skill("tox_stacking_venom")
	runner.ok(stacking.kind == Skill.Kind.PASSIVE, "พิษสะสมเป็น Passive")
	runner.equal_float(stacking.mana_cost, 0.0, "ไม่ใช้ Mana")

	var balance := SkillDB.skill("alch_reaction_balance")
	runner.ok(balance.kind == Skill.Kind.TRIGGERED, "สมดุลปฏิกิริยาเป็นแบบทำงานเอง")
	runner.equal_float(balance.mana_cost, 10.0, "เสีย Mana 10 ต่อครั้ง")
	runner.equal_float(balance.cooldown, 0.0, "ไม่มีคูลดาวน์")


func test_branch_locks_after_two_picks() -> void:
	var tree := SkillTree.new(CharacterClass.Id.ALCHEMIST)
	runner.ok(tree.learn_core(10), "เรียนสกิล Lv10 ได้")
	runner.ok(not tree.is_locked(), "สกิล core ไม่ทำให้ล็อกสาย")

	runner.ok(tree.learn(SkillDB.skill("alch_firebrand_flask"), 13), "เลือกสาย A ที่ Lv13")
	runner.ok(not tree.is_locked(), "เลือกครั้งเดียวยังไม่ล็อก")

	runner.ok(tree.learn(SkillDB.skill("alch_diffusion"), 16), "เลือกสาย A อีกครั้งที่ Lv16")
	runner.ok(tree.is_locked(), "ครบ 2 ครั้งในสายเดียวกันแล้วล็อก")
	runner.ok(tree.locked_branch() == "a", "ล็อกเข้าสาย A")


func test_locked_branch_filters_later_choices() -> void:
	var tree := SkillTree.new(CharacterClass.Id.ALCHEMIST)
	tree.learn(SkillDB.skill("alch_firebrand_flask"), 13)
	tree.learn(SkillDB.skill("alch_diffusion"), 16)

	var choices := tree.available_choices(19)
	runner.equal_int(choices.size(), 1, "ล็อกแล้วเหลือให้เลือกสายเดียว")
	runner.ok(choices[0].branch == "a", "เป็นสาย A")
	runner.ok(not tree.learn(SkillDB.skill("alch_reaction_balance"), 19), "ข้ามไปเลือกสาย B ไม่ได้")


## เอกสารบอกว่าเลือกทีละอันจากคู่ A/B ถ้า 2 ครั้งแรกแยกสาย ครั้งที่ 3 เป็นตัวตัดสิน
func test_split_picks_leave_the_third_choice_open() -> void:
	var tree := SkillTree.new(CharacterClass.Id.FIELD_MEDIC)
	tree.learn(SkillDB.skill("medic_detox"), 13)
	tree.learn(SkillDB.skill("medic_immune_boost"), 16)
	runner.ok(not tree.is_locked(), "เลือกคนละสายอย่างละครั้ง ยังไม่ล็อก")
	runner.equal_int(tree.available_choices(19).size(), 2, "Lv19 ยังเลือกได้ทั้งสองสาย")

	tree.learn(SkillDB.skill("medic_rapid_diagnosis"), 19)
	runner.ok(tree.locked_branch() == "a", "ครั้งที่ 3 ตัดสินให้เข้าสาย A")


func test_ultimate_requires_a_locked_branch() -> void:
	var tree := SkillTree.new(CharacterClass.Id.TOXICOLOGIST)
	runner.equal_int(tree.available_choices(22).size(), 0, "ยังไม่ล็อกสาย ยังไม่มี Ultimate ให้เลือก")

	tree.learn(SkillDB.skill("tox_contagion_vector"), 13)
	tree.learn(SkillDB.skill("tox_miasma"), 16)
	var ultimates := tree.available_choices(22)
	runner.equal_int(ultimates.size(), 1, "ล็อกสาย B แล้วได้ Ultimate ของสาย B ตัวเดียว")
	runner.ok(ultimates[0].id == "tox_epidemiology", "คือระบาดวิทยา ตรงกับชื่อสายนักระบาดวิทยา")


func test_cannot_learn_twice_at_the_same_level() -> void:
	var tree := SkillTree.new(CharacterClass.Id.HERB_VANGUARD)
	runner.ok(tree.learn(SkillDB.skill("vang_bark_skin"), 13), "เลือกครั้งแรกได้")
	runner.ok(not tree.learn(SkillDB.skill("vang_strength_extract"), 13), "เลเวลเดียวกันเลือกซ้ำไม่ได้")


func test_cannot_learn_above_character_level() -> void:
	var tree := SkillTree.new(CharacterClass.Id.HERB_VANGUARD)
	runner.ok(not tree.learn(SkillDB.skill("vang_entangle"), 15), "เลเวล 15 เรียนสกิล Lv19 ไม่ได้")
	runner.ok(tree.learn(SkillDB.skill("vang_entangle"), 19), "ถึง Lv19 แล้วเรียนได้")


func test_cannot_learn_another_class_skill() -> void:
	var tree := SkillTree.new(CharacterClass.Id.ALCHEMIST)
	runner.ok(not tree.learn(SkillDB.skill("medic_first_aid"), 25), "เรียนสกิลอาชีพอื่นไม่ได้")


## บอสท้ายบทต้องอ่านจังหวะหัวใจให้ได้ ทั้งสองสายของหมอสนามจึงต้องทำได้
func test_both_medic_branches_can_read_vitals() -> void:
	for skill_id in ["medic_rapid_diagnosis", "medic_pulse_sense"]:
		var tree := SkillTree.new(CharacterClass.Id.FIELD_MEDIC)
		tree.learn(SkillDB.skill(skill_id), 19)
		runner.ok(tree.can_read_vitals(), "%s อ่านจังหวะหัวใจได้" % skill_id)


## บอส Act 2 ต้องขัดจังหวะวงจร Overdose ทั้งสองสายของนักพิษวิทยาจึงต้องทำได้
func test_both_toxicologist_branches_can_interrupt() -> void:
	for skill_id in ["tox_weak_point", "tox_contagion_vector"]:
		var tree := SkillTree.new(CharacterClass.Id.TOXICOLOGIST)
		tree.learn(SkillDB.skill(skill_id), 13)
		runner.ok(tree.has_interrupt(), "%s ขัดจังหวะได้" % skill_id)


func test_save_roundtrip() -> void:
	var tree := SkillTree.new(CharacterClass.Id.ALCHEMIST)
	tree.learn_core(10)
	tree.learn(SkillDB.skill("alch_concentrate"), 13)
	tree.learn(SkillDB.skill("alch_forbidden_formula"), 16)

	var restored := SkillTree.from_dict(tree.to_dict())
	runner.equal_int(restored.learned_skills().size(), 3, "สกิลกลับมาครบ")
	runner.ok(restored.locked_branch() == "b", "สายที่ล็อกไว้กลับมาด้วย")
	runner.ok(restored.has_skill("alch_forbidden_formula"), "สกิลเฉพาะตัวกลับมาถูก")


## สกิลทุกตัวต้องมีท่าเล่น ไม่งั้นผู้เล่นกดแล้วไม่เห็นอะไรเกิดขึ้น
func test_every_active_skill_has_an_animation() -> void:
	for entry in SkillDB.all_skills():
		var skill: Skill = entry
		if skill.kind == Skill.Kind.PASSIVE:
			runner.ok(skill.animation_state().is_empty(), "%s เป็น Passive ไม่ต้องมีท่า" % skill.id)
			continue
		var state: String = skill.animation_state()
		runner.ok(
			ActorVisuals.STATE_ANIMATION.has(state),
			"%s ใช้ท่าที่มีอยู่จริง (%s)" % [skill.id, state]
		)


func test_offensive_and_support_skills_use_different_animations() -> void:
	runner.ok(SkillDB.skill("tox_venom_needle").animation_state() == "skill_attack", "เข็มพิษใช้ท่าโจมตี")
	runner.ok(SkillDB.skill("alch_firebrand_flask").animation_state() == "skill_attack", "ขวดเพลิงใช้ท่าโจมตี")
	runner.ok(SkillDB.skill("medic_first_aid").animation_state() == "cast", "ปฐมพยาบาลใช้ท่าร่าย")
	runner.ok(SkillDB.skill("vang_root_armor").animation_state() == "cast", "เกราะรากไม้ใช้ท่าร่าย")
