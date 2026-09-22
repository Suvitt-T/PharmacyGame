extends RefCounted

var runner

## ลำดับ TI จากกว้างไปแคบ เรียงด้วยตัวเลข TD/ED ล้วน ๆ
const EXPECTED_TI_ORDER := [
	"penicillin", "caffeine", "salicin", "morphine", "atropine", "quinine", "warfarin", "digoxin"
]

## ลำดับความเสี่ยงจากคอลัมน์ "ความเสี่ยง" ในเอกสาร ซึ่งไม่ตรงกับลำดับ TI
const EXPECTED_RISK_ORDER := [
	"penicillin", "salicin", "caffeine", "quinine", "atropine", "morphine", "warfarin", "digoxin"
]


func test_all_eight_substances_present() -> void:
	runner.equal_int(PharmacyDB.all_substances().size(), 8, "มีสารออกฤทธิ์ 8 ชนิดตามเอกสาร")
	for substance_id in EXPECTED_TI_ORDER:
		runner.ok(PharmacyDB.substance(substance_id) != null, "มีสาร %s" % substance_id)


func test_all_eight_ingredients_present() -> void:
	runner.equal_int(PharmacyDB.all_ingredients().size(), 8, "มีวัตถุดิบ 8 ชนิด")
	for entry in PharmacyDB.all_ingredients():
		var ingredient: Ingredient = entry
		runner.ok(
			PharmacyDB.substance(ingredient.substance_id) != null,
			"วัตถุดิบ %s ชี้ไปยังสารที่มีอยู่จริง" % ingredient.id
		)


## เอกสารระบุว่า Penicillin TI กว้างที่สุด และ Digoxin แคบที่สุด (~2x)
func test_therapeutic_index_ordering() -> void:
	var previous := INF
	for substance_id in EXPECTED_TI_ORDER:
		var index: float = PharmacyDB.substance(substance_id).therapeutic_index()
		runner.ok(index <= previous, "TI ของ %s (%.1f) ไม่กว้างกว่าตัวก่อนหน้า" % [substance_id, index])
		previous = index


func test_digoxin_is_narrowest() -> void:
	var digoxin := PharmacyDB.substance("digoxin")
	runner.equal_float(digoxin.therapeutic_index(), 2.0, "Digoxin TI = 2x ตามเอกสาร")
	runner.ok(digoxin.window_label() == "แคบที่สุด", "หน้าต่างแคบที่สุด")
	runner.ok(digoxin.risk_label() == "อันตรายสุด", "ติดป้ายอันตรายสุดตามเอกสาร")
	runner.equal_int(digoxin.act_available, 3, "Digoxin ผูกกับ Act 3")


func test_risk_ordering_follows_doc_not_ti() -> void:
	var previous := -1
	for substance_id in EXPECTED_RISK_ORDER:
		var rank: int = PharmacyDB.substance(substance_id).risk_rank()
		runner.ok(rank >= previous, "ความเสี่ยงของ %s ไม่ต่ำกว่าตัวก่อนหน้า" % substance_id)
		previous = rank


## บทเรียนจริง: TI กว้างไม่ได้แปลว่าปลอดภัย มอร์ฟีน TI 20 เท่าแต่กดการหายใจ
func test_wide_index_does_not_mean_safe() -> void:
	var morphine := PharmacyDB.substance("morphine")
	var atropine := PharmacyDB.substance("atropine")
	runner.ok(morphine.therapeutic_index() > atropine.therapeutic_index(), "มอร์ฟีน TI กว้างกว่าแอโทรพีน")
	runner.ok(morphine.risk_rank() > atropine.risk_rank(), "แต่เอกสารจัดว่าเสี่ยงกว่า")
	runner.ok(morphine.is_deceptively_safe(), "ติดธงว่าเป็นกับดัก TI กว้างแต่อันตราย")
	runner.ok(not morphine.risk_note.is_empty(), "มีคำอธิบายเหตุผลไว้ให้ Pharmacopedia")


func test_penicillin_is_widest() -> void:
	var penicillin := PharmacyDB.substance("penicillin")
	runner.ok(penicillin.therapeutic_index() > 100.0, "Penicillin TI > 100x ตามเอกสาร")
	runner.ok(penicillin.window_label() == "กว้างมาก", "หน้าต่างกว้างมาก")
	runner.ok(penicillin.risk_rank() == 0, "Penicillin ปลอดภัยที่สุดในเกม")


func test_every_substance_has_a_working_preparation() -> void:
	for entry in PharmacyDB.all_substances():
		var substance: Substance = entry
		var best: float = substance.efficiency_for(substance.best_method())
		runner.ok(best >= 0.8, "%s มีวิธีเตรียมที่ได้ผลอย่างน้อย 1 วิธี (ดีสุด %.2f)" % [substance.id, best])


func test_salicin_cannot_be_injected() -> void:
	var salicin := PharmacyDB.substance("salicin")
	runner.equal_float(salicin.efficiency_for(Preparation.Method.INJECTION_EXTRACT), 0.0, "เปลือกหลิวดิบฉีดไม่ได้")
	runner.equal_float(salicin.efficiency_for(Preparation.Method.DECOCTION), 1.0, "ต้มคือวิธีที่ถูกต้อง")


func test_atropine_is_the_cholinergic_antidote() -> void:
	var antidotes := PharmacyDB.antidotes_for("cholinergic_crisis")
	runner.equal_int(antidotes.size(), 1, "มียาแก้พิษตรงกลไก 1 ตัว")
	runner.ok(antidotes[0].id == "atropine", "คือแอโทรพีน ตรงกับเควสที่ 3 ในเอกสาร")
	runner.ok(PharmacyDB.substance("atropine").mechanism == "muscarinic_antagonism", "กลไกเป็น receptor antagonist")


func test_biome_lookup() -> void:
	var ice_ingredients := PharmacyDB.ingredients_in_biome("ice")
	var ids := []
	for entry in ice_ingredients:
		ids.append((entry as Ingredient).id)
	runner.ok(ids.has("foxglove_flower"), "ฟ็อกซ์โกลฟอยู่ยอดเขาน้ำแข็งตามเอกสาร")
	runner.ok(not ids.has("cinchona_bark"), "ซิงโคนาไม่ได้อยู่ยอดเขาน้ำแข็ง")
