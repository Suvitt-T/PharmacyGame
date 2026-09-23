extends RefCounted

var runner


func _rng(seed_value: int) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


func test_tier_table_matches_doc() -> void:
	runner.equal_float(ItemTier.multiplier(ItemTier.Tier.COMMON), 1.00, "Common x1.0")
	runner.equal_float(ItemTier.multiplier(ItemTier.Tier.UNCOMMON), 1.15, "Uncommon x1.15")
	runner.equal_float(ItemTier.multiplier(ItemTier.Tier.RARE), 1.35, "Rare x1.35")
	runner.equal_float(ItemTier.multiplier(ItemTier.Tier.EPIC), 1.60, "Epic x1.6")

	runner.equal_int(ItemTier.affix_slots(ItemTier.Tier.COMMON), 0, "Common ไม่มีช่อง affix")
	runner.equal_int(ItemTier.affix_slots(ItemTier.Tier.UNCOMMON), 1, "Uncommon 1 ช่อง")
	runner.equal_int(ItemTier.affix_slots(ItemTier.Tier.RARE), 2, "Rare 2 ช่อง")
	runner.equal_int(ItemTier.affix_slots(ItemTier.Tier.EPIC), 3, "Epic 3 ช่อง")

	runner.equal_int(ItemTier.vial_slots(ItemTier.Tier.COMMON), 0, "Common ไม่มี Vial Slot")
	runner.equal_int(ItemTier.vial_slots(ItemTier.Tier.UNCOMMON), 0, "Uncommon ไม่มี Vial Slot")
	runner.equal_int(ItemTier.vial_slots(ItemTier.Tier.RARE), 1, "Rare 1 Vial Slot")
	runner.equal_int(ItemTier.vial_slots(ItemTier.Tier.EPIC), 2, "Epic 2 Vial Slot")


## ตัวอย่างในเอกสาร: ดาบ Rare itemLevel 18 สุ่มได้ +6% STR และ +4% Crit
## WeaponBaseDMG(18) = 47.6 แล้ว FinalDMG = 47.6 x 1.35 x 1.06
##
## เอกสารเขียนผลลัพธ์ไว้ 68.15 แต่คูณจริงได้ 68.1156 เป็นการปัดเศษคลาดเคลื่อนในเอกสาร
## ยึดสูตรเป็นหลัก เพราะตัวเลขนี้ไปโผล่ในการคำนวณดาเมจทุกครั้ง
func test_doc_worked_example() -> void:
	var sword := Equipment.new()
	sword.base_id = "root_blade"
	sword.tier = ItemTier.Tier.RARE
	sword.item_level = 18
	sword.affixes.append(Affix.make("strength", 6.0))
	sword.affixes.append(Affix.make("crit", 4.0))

	runner.equal_float(sword.base_value(), 47.6, "WeaponBaseDMG(18) = 47.6")
	runner.equal_float(sword.final_value(), 68.1156, "FinalDMG = 47.6 x 1.35 x 1.06", 0.001)
	runner.equal_float(sword.crit_bonus_percent(), 4.0, "affix Crit ให้ผลแยก ไม่เข้าสูตร")


func test_armor_uses_defense_formula() -> void:
	var chest := Equipment.new()
	chest.base_id = "bark_cuirass"
	chest.tier = ItemTier.Tier.EPIC
	chest.item_level = 18
	runner.equal_float(chest.base_value(), 32.0, "ArmorBaseDEF(18) = 32")
	runner.equal_float(chest.final_value(), 51.2, "Epic x1.6 = 51.2")
	runner.equal_float(chest.weapon_damage(), 0.0, "เกราะไม่ให้ดาเมจ")


func test_only_scaling_affixes_enter_the_formula() -> void:
	var sword := Equipment.new()
	sword.base_id = "root_blade"
	sword.tier = ItemTier.Tier.COMMON
	sword.item_level = 10
	var plain := sword.final_value()

	sword.affixes.append(Affix.make("intellect", 8.0))
	runner.equal_float(sword.final_value(), plain, "affix INT ไม่ขยายดาเมจดาบที่สเกลด้วย STR")
	runner.ok(sword.stat_bonus().intellect > 0.0, "แต่ไม่หายไปเฉย ๆ กลายเป็นแต้ม INT")

	sword.affixes.append(Affix.make("strength", 10.0))
	runner.ok(sword.final_value() > plain, "affix STR ขยายดาเมจ")


func test_rolled_affix_counts_and_ranges() -> void:
	var rng := _rng(7)
	for tier in ItemTier.all():
		var item := ItemDB.roll_equipment("root_blade", tier, 12, rng)
		runner.equal_int(item.affixes.size(), ItemTier.affix_slots(tier), "จำนวน affix ตรงกับ Tier")
		for affix in item.affixes:
			runner.ok(
				affix.percent >= Affix.MIN_PERCENT and affix.percent <= Affix.MAX_PERCENT,
				"affix อยู่ในช่วง 3-8%% (ได้ %.1f)" % affix.percent
			)


func test_rolls_are_deterministic_per_seed() -> void:
	var first := ItemDB.roll_equipment("root_blade", ItemTier.Tier.EPIC, 20, _rng(99))
	var second := ItemDB.roll_equipment("root_blade", ItemTier.Tier.EPIC, 20, _rng(99))
	runner.equal_float(first.final_value(), second.final_value(), "seed เดียวกันได้ของเหมือนกัน")


func test_vial_slots_limited_by_tier() -> void:
	var rare := ItemDB.roll_equipment("root_blade", ItemTier.Tier.RARE, 15, _rng(3))
	runner.ok(rare.insert_vial("caffeine_vial"), "Rare เสียบหลอดแรกได้")
	runner.ok(not rare.insert_vial("salicin_vial"), "Rare มีช่องเดียว เสียบหลอดที่สองไม่ได้")

	var epic := ItemDB.roll_equipment("root_blade", ItemTier.Tier.EPIC, 15, _rng(3))
	runner.ok(epic.insert_vial("caffeine_vial"), "Epic หลอดแรก")
	runner.ok(epic.insert_vial("salicin_vial"), "Epic หลอดที่สอง")
	runner.ok(not epic.insert_vial("quinine_vial"), "Epic เต็มที่ 2 หลอด")

	var common := ItemDB.roll_equipment("root_blade", ItemTier.Tier.COMMON, 15, _rng(3))
	runner.ok(not common.insert_vial("caffeine_vial"), "Common ไม่มี Vial Slot เลย")


## Vial ผูกระบบเก็บวัตถุดิบเข้ากับระบบอุปกรณ์ ตามที่เอกสารตั้งใจ
func test_vials_come_from_the_same_ingredients_as_remedies() -> void:
	for vial_id in ItemDB.all_vial_ids():
		var cost := ItemDB.vial_cost(vial_id)
		runner.ok(
			PharmacyDB.ingredient(cost["ingredient"]) != null,
			"หลอด %s ใช้วัตถุดิบที่มีอยู่จริงในระบบยา" % vial_id
		)


func test_caffeine_vial_gives_crit_as_doc_describes() -> void:
	var sword := ItemDB.roll_equipment("root_blade", ItemTier.Tier.RARE, 15, _rng(5))
	sword.insert_vial("caffeine_vial")
	var loadout := Loadout.new()
	loadout.equip(sword)
	runner.ok(loadout.vial_crit_percent() > 0.0, "สกัดคาเฟอีน = +Crit% ถาวร ตามตัวอย่างในเอกสาร")


func test_willow_vial_reduces_damage_over_time() -> void:
	var chest := ItemDB.roll_equipment("bark_cuirass", ItemTier.Tier.EPIC, 15, _rng(5))
	chest.insert_vial("salicin_vial")
	var loadout := Loadout.new()
	loadout.equip(chest)
	runner.ok(loadout.dot_resistance() > 0.0, "สกัดเปลือกหลิว = ลดดาเมจต่อเนื่อง ตามตัวอย่างในเอกสาร")


func test_loadout_aggregates_across_slots() -> void:
	var rng := _rng(11)
	var loadout := Loadout.new()
	loadout.equip(ItemDB.roll_equipment("root_blade", ItemTier.Tier.RARE, 18, rng))
	loadout.equip(ItemDB.roll_equipment("bark_cuirass", ItemTier.Tier.RARE, 18, rng))
	loadout.equip(ItemDB.roll_equipment("bark_helm", ItemTier.Tier.UNCOMMON, 18, rng))

	runner.ok(loadout.weapon_damage() > 0.0, "มีดาเมจจากอาวุธ")
	runner.ok(loadout.total_defense() > 0.0, "มีค่าป้องกันจากเกราะ 2 ชิ้นรวมกัน")
	runner.equal_int(loadout.all_items().size(), 3, "สวมอยู่ 3 ชิ้น")

	var previous := loadout.equip(ItemDB.roll_equipment("apothecary_stave", ItemTier.Tier.EPIC, 18, rng))
	runner.ok(previous != null, "สวมอาวุธใหม่ทับ ชิ้นเดิมเด้งออกมา")
	runner.equal_int(loadout.all_items().size(), 3, "ยังสวม 3 ชิ้น ไม่ใช่ 4")
