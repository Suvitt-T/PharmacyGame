extends RefCounted

var runner


func test_hp_and_mana() -> void:
	runner.equal_float(Formulas.max_hp(35.0, 15), 435.0, "HP ตัวอย่างในเอกสาร")
	runner.equal_float(Formulas.max_mana(5.0, 15), 130.0, "Mana ตัวอย่างในเอกสาร")
	runner.equal_float(Formulas.max_hp(5.0, 1), 125.0, "HP เริ่มต้น Lv1")
	runner.equal_float(Formulas.max_mana(5.0, 1), 74.0, "Mana เริ่มต้น Lv1")


func test_damage_scaling() -> void:
	runner.equal_float(Formulas.physical_damage(100.0, 50.0), 200.0, "STR 50 = ดาเมจ x2")
	runner.equal_float(Formulas.skill_damage(100.0, 40.0), 200.0, "INT 40 = สกิลดาเมจ x2")


func test_crit_and_evasion_caps() -> void:
	runner.equal_float(Formulas.crit_chance_percent(10.0), 1.5, "Crit ตัวอย่างในเอกสาร")
	runner.equal_float(Formulas.crit_chance_percent(1000.0), 40.0, "Crit ชนเพดาน 40%")
	runner.equal_float(Formulas.evasion_chance_percent(1000.0), 30.0, "Evasion ชนเพดาน 30%")
	runner.equal_float(Formulas.evasion_chance_percent(100.0), 10.0, "Evasion AGI 100")


func test_craft_and_window() -> void:
	runner.equal_float(Formulas.craft_speed(40.0), 1.2, "CraftSpd AGI 40")
	runner.equal_float(Formulas.therapeutic_window_bonus_percent(29.0), 4.0, "INT 29 = +4%")
	runner.equal_float(Formulas.therapeutic_window_bonus_percent(30.0), 6.0, "INT 30 = +6%")
	runner.equal_float(Formulas.therapeutic_window_bonus_percent(9.0), 0.0, "INT 9 = +0%")


func test_itemization() -> void:
	runner.equal_float(Formulas.weapon_base_damage(18), 47.6, "WeaponBaseDMG itemLevel 18")
	runner.equal_float(Formulas.armor_base_defense(18), 32.0, "ArmorBaseDEF itemLevel 18")


func test_enemy_scaling() -> void:
	runner.equal_float(Formulas.enemy_hp(60.0, 1), 60.0, "ZoneLevel 1 ไม่สเกล")
	runner.equal_float(Formulas.enemy_hp(60.0, 6), 96.0, "ZoneLevel 6 HP +60%")
	runner.equal_float(Formulas.enemy_damage(8.0, 6), 11.2, "ZoneLevel 6 DMG +40%")


func test_defense_mitigation() -> void:
	runner.equal_float(Formulas.damage_after_defense(100.0, 0.0), 100.0, "ไม่มี DEF = ดาเมจเต็ม")
	runner.equal_float(Formulas.damage_after_defense(100.0, 100.0), 50.0, "DEF 100 = ลดครึ่ง")
	runner.ok(Formulas.damage_after_defense(100.0, 100000.0) > 0.0, "DEF สูงมากยังกินดาเมจอยู่บ้าง")
