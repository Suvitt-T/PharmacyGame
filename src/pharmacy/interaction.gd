class_name Interaction
extends RefCounted

## ปฏิกิริยาระหว่างยา ตามหัวข้อ "ปฏิกิริยาระหว่างยา" ในเอกสาร
## คู่ที่ใส่ไว้อ้างอิงปฏิกิริยาจริงทางคลินิก ไม่ได้แต่งขึ้น

enum Kind { SYNERGISM, ANTAGONISM, POTENTIATION }

## affects = สารที่ถูกกระทบ ถ้าเว้นว่างแปลว่ากระทบทั้งคู่
const RULES := [
	{
		"a": "warfarin", "b": "salicin", "kind": Kind.SYNERGISM,
		"factor": 1.45, "affects": "warfarin",
		"note": "ทั้งคู่ทำให้เลือดหยุดยาก ใช้ร่วมกันเสี่ยงเลือดออกรุนแรงกว่าผลรวมของแต่ละตัว",
	},
	{
		"a": "quinine", "b": "digoxin", "kind": Kind.POTENTIATION,
		"factor": 1.60, "affects": "digoxin",
		"note": "ควินินลดการขับดิจอกซินออกจากร่างกาย ระดับดิจอกซินจึงพุ่งขึ้นทั้งที่ให้ขนาดเท่าเดิม",
	},
	{
		"a": "caffeine", "b": "salicin", "kind": Kind.POTENTIATION,
		"factor": 1.25, "affects": "salicin",
		"note": "คาเฟอีนไม่ได้แก้ปวดเอง แต่ทำให้ยาแก้ปวดออกฤทธิ์ได้ดีขึ้น",
	},
	{
		"a": "caffeine", "b": "morphine", "kind": Kind.ANTAGONISM,
		"factor": 0.70, "affects": "morphine",
		"note": "ตัวกระตุ้นกับตัวกด หักล้างกันเอง",
	},
	{
		"a": "atropine", "b": "morphine", "kind": Kind.ANTAGONISM,
		"factor": 0.85, "affects": "morphine",
		"note": "แอโทรพีนลดอาการข้างเคียงบางอย่างของมอร์ฟีน แต่ไม่ได้แก้การกดการหายใจ",
	},
]


static func find(first_id: String, second_id: String) -> Dictionary:
	for rule in RULES:
		var matches_forward: bool = rule["a"] == first_id and rule["b"] == second_id
		var matches_reverse: bool = rule["a"] == second_id and rule["b"] == first_id
		if matches_forward or matches_reverse:
			return rule
	return {}


## ตัวคูณขนาดยาที่ได้ผลของ target เมื่อมีสารอื่นในรายการออกฤทธิ์อยู่ด้วย
static func dose_multiplier_for(target_id: String, present_ids: Array) -> float:
	var multiplier := 1.0
	for other_id in present_ids:
		if other_id == target_id:
			continue
		var rule := find(target_id, other_id)
		if rule.is_empty():
			continue
		var affects: String = str(rule.get("affects", ""))
		if affects.is_empty() or affects == target_id:
			multiplier *= float(rule["factor"])
	return multiplier


static func kind_name(kind: Kind) -> String:
	match kind:
		Kind.SYNERGISM:
			return "เสริมฤทธิ์"
		Kind.ANTAGONISM:
			return "หักล้างฤทธิ์"
		_:
			return "เสริมแต่ไม่ออกฤทธิ์เอง"


## คู่ที่ดันสารเข้าเขตพิษ ใช้เตือนผู้เล่นและเป็นเงื่อนไขสกิล "สมดุลปฏิกิริยา" ของนักปรุงยา
static func is_dangerous(rule: Dictionary) -> bool:
	if rule.is_empty():
		return false
	return rule["kind"] != Kind.ANTAGONISM and float(rule["factor"]) > 1.0
