extends RefCounted

var runner


func test_quinine_potentiates_digoxin() -> void:
	var rule := Interaction.find("digoxin", "quinine")
	runner.ok(not rule.is_empty(), "มีกฎปฏิกิริยาควินิน-ดิจอกซิน")
	runner.ok(rule["kind"] == Interaction.Kind.POTENTIATION, "เป็น Potentiation")
	runner.ok(Interaction.is_dangerous(rule), "จัดเป็นคู่อันตราย")

	var alone := Interaction.dose_multiplier_for("digoxin", [])
	var with_quinine := Interaction.dose_multiplier_for("digoxin", ["quinine"])
	runner.equal_float(alone, 1.0, "ใช้เดี่ยวไม่มีตัวคูณ")
	runner.ok(with_quinine > 1.0, "มีควินินอยู่ ดิจอกซินแรงขึ้นทั้งที่ขนาดเท่าเดิม")


## จุดสำคัญของกลไกนี้: ขนาดยาเท่าเดิมแต่ถูกดันข้ามเส้น TD เพราะยาอีกตัว
func test_potentiation_can_push_a_safe_dose_into_toxic() -> void:
	var remedy := Remedy.craft("foxglove_flower", 4, Preparation.Method.INJECTION_EXTRACT, 1.0)
	var multiplier := Interaction.dose_multiplier_for("digoxin", ["quinine"])
	var safe = remedy.evaluate(5.0, 1.0)
	var with_quinine = remedy.evaluate(5.0, multiplier)
	runner.ok(safe["zone"] == Pharmacokinetics.Zone.THERAPEUTIC, "ขนาดนี้ใช้เดี่ยวปลอดภัย")
	runner.ok(with_quinine["zone"] == Pharmacokinetics.Zone.TOXIC, "ขนาดเดิมกลายเป็นพิษเมื่อมีควินิน")


func test_warfarin_salicin_synergism() -> void:
	var rule := Interaction.find("warfarin", "salicin")
	runner.ok(rule["kind"] == Interaction.Kind.SYNERGISM, "เป็น Synergism")
	runner.ok(Interaction.dose_multiplier_for("warfarin", ["salicin"]) > 1.0, "วาร์ฟารินแรงขึ้น")
	runner.equal_float(
		Interaction.dose_multiplier_for("salicin", ["warfarin"]), 1.0,
		"กฎระบุ affects เป็นวาร์ฟาริน ซาลิซินจึงไม่ถูกกระทบกลับ"
	)


func test_antagonism_reduces_effect() -> void:
	var multiplier := Interaction.dose_multiplier_for("morphine", ["caffeine"])
	runner.ok(multiplier < 1.0, "คาเฟอีนหักล้างมอร์ฟีน")
	var rule := Interaction.find("morphine", "caffeine")
	runner.ok(not Interaction.is_dangerous(rule), "การหักล้างไม่ใช่คู่อันตราย")


func test_lookup_is_symmetric() -> void:
	var forward := Interaction.find("caffeine", "salicin")
	var reverse := Interaction.find("salicin", "caffeine")
	runner.ok(not forward.is_empty() and forward == reverse, "ค้นหาได้ทั้งสองทิศทาง")


func test_unrelated_pair_has_no_rule() -> void:
	runner.ok(Interaction.find("penicillin", "caffeine").is_empty(), "คู่ที่ไม่มีปฏิกิริยาไม่เจอกฎ")
	runner.equal_float(
		Interaction.dose_multiplier_for("penicillin", ["caffeine", "salicin"]), 1.0,
		"ไม่มีกฎ ตัวคูณคงที่ 1.0"
	)


func test_multiple_interactions_stack() -> void:
	var single := Interaction.dose_multiplier_for("morphine", ["caffeine"])
	var both := Interaction.dose_multiplier_for("morphine", ["caffeine", "atropine"])
	runner.ok(both < single, "หักล้างสองตัวลดแรงกว่าตัวเดียว")
