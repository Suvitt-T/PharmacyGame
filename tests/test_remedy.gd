extends RefCounted

var runner

const Zone := Pharmacokinetics.Zone


func test_potency_from_source() -> void:
	var foxglove := PharmacyDB.ingredient("foxglove_flower")
	var ideal := foxglove.potency("ice", Ingredient.Maturity.ANCIENT, Ingredient.Season.PEAK)
	var wrong := foxglove.potency("desert", Ingredient.Maturity.YOUNG, Ingredient.Season.DORMANT)
	runner.ok(ideal > wrong, "เก็บถูกที่ถูกเวลาได้ potency สูงกว่า (%.2f เทียบ %.2f)" % [ideal, wrong])
	runner.ok(ideal <= Ingredient.MAX_POTENCY, "potency ไม่ทะลุเพดาน")
	runner.ok(wrong >= Ingredient.MIN_POTENCY, "potency ไม่ต่ำกว่าพื้น")


func test_wrong_preparation_makes_inert_remedy() -> void:
	var injected_bark := Remedy.craft("willow_bark", 6, Preparation.Method.INJECTION_EXTRACT, 1.0)
	runner.ok(injected_bark.is_inert(), "เอาเปลือกหลิวไปสกัดฉีด ไม่ได้สารออกฤทธิ์")
	runner.equal_float(injected_bark.raw_dose, 0.0, "ขนาดยาเป็นศูนย์")

	var boiled_bark := Remedy.craft("willow_bark", 6, Preparation.Method.DECOCTION, 1.0)
	runner.ok(not boiled_bark.is_inert(), "ต้มแล้วได้ยาจริง")


func test_underdose_gives_no_effect() -> void:
	var remedy := Remedy.craft("willow_bark", 1, Preparation.Method.DECOCTION, 1.0)
	var result := remedy.evaluate()
	runner.ok(result["zone"] == Zone.NO_EFFECT, "เปลือกหลิว 1 ชิ้นไม่ถึง ED")
	runner.equal_float(result["duration"], 0.0, "ไม่ถึง ED จึงไม่มี duration")


func test_therapeutic_dose_has_duration() -> void:
	var remedy := Remedy.craft("willow_bark", 12, Preparation.Method.DECOCTION, 1.0)
	var result := remedy.evaluate()
	runner.ok(result["zone"] == Zone.THERAPEUTIC, "12 ชิ้นเข้า Therapeutic Window")
	runner.ok(result["duration"] > 0.0, "มีระยะเวลาออกฤทธิ์ใช้งานได้")


func test_overdose_is_toxic() -> void:
	var remedy := Remedy.craft("willow_bark", 400, Preparation.Method.DECOCTION, 1.0)
	var result := remedy.evaluate()
	runner.ok(result["zone"] == Zone.TOXIC, "400 ชิ้นเกิน TD")


## เอกสารกำหนดให้ฟ็อกซ์โกลฟแบบฉีดเป็นกลไกของบอสท้ายบท จึงต้องคาลิเบรตได้จริง
func test_digoxin_injection_is_calibratable() -> void:
	var substance := PharmacyDB.substance("digoxin")
	var found_therapeutic := false
	var found_toxic := false
	for units in range(1, 40):
		var remedy := Remedy.craft("foxglove_flower", units, Preparation.Method.INJECTION_EXTRACT, 1.0)
		var zone = remedy.evaluate()["zone"]
		if zone == Zone.THERAPEUTIC:
			found_therapeutic = true
		if zone == Zone.TOXIC:
			found_toxic = true
	runner.ok(found_therapeutic, "มีจำนวนชิ้นที่เข้า Therapeutic Window ได้")
	runner.ok(found_toxic, "ให้เกินแล้วเป็นพิษได้จริง")
	runner.equal_float(substance.therapeutic_index(), 2.0, "หน้าต่างแคบแค่ 2 เท่า")


func test_injection_is_faster_than_oral() -> void:
	var injected := Remedy.craft("foxglove_flower", 4, Preparation.Method.INJECTION_EXTRACT, 1.0)
	var swallowed := Remedy.craft("foxglove_flower", 4, Preparation.Method.POWDER, 1.0)
	runner.ok(
		injected.evaluate()["onset"] < swallowed.evaluate()["onset"],
		"ฉีดออกฤทธิ์เร็วกว่ากิน ตรงกับเฟสคาลิเบรตของบอส"
	)


func test_intellect_widens_usable_range() -> void:
	var remedy := Remedy.craft("foxglove_flower", 9, Preparation.Method.INJECTION_EXTRACT, 1.0)
	var novice = remedy.evaluate(5.0)
	var scholar = remedy.evaluate(60.0)
	runner.ok(
		scholar["toxic_threshold"] > novice["toxic_threshold"],
		"INT สูงขยายขอบบนของ Therapeutic Window"
	)


func test_potency_raises_dose_and_speed() -> void:
	var weak := Remedy.craft("cinchona_bark", 5, Preparation.Method.DECOCTION, 0.6)
	var strong := Remedy.craft("cinchona_bark", 5, Preparation.Method.DECOCTION, 1.8)
	runner.ok(strong.raw_dose > weak.raw_dose, "potency สูงได้สารมากกว่าจากจำนวนชิ้นเท่ากัน")
	runner.ok(strong.evaluate()["onset"] < weak.evaluate()["onset"], "potency สูงออกฤทธิ์เร็วกว่า")
