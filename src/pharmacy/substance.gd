class_name Substance
extends RefCounted

## สารออกฤทธิ์ 1 ชนิด โหลดจาก data/substances.json

var id: String = ""
var display_name: String = ""
var compound: String = ""
var source_note: String = ""
var unit: String = "mg"
var effective_dose: float = 1.0
var toxic_dose: float = 2.0
var half_life_seconds: float = 30.0
var base_onset_seconds: float = 40.0
var real_half_life_hours: float = 1.0
var mechanism: String = ""
var mechanism_note: String = ""
var preparation_efficiency: Dictionary = {}
var therapeutic_effect: Dictionary = {}
var toxic_effect: Dictionary = {}
var antidote_for: Array = []
var act_available: int = 0
var risk_level: String = "low"
var risk_note: String = ""

## ระดับความเสี่ยงมาจากคอลัมน์ "ความเสี่ยง" ในเอกสาร ไม่ได้คำนวณจาก TI
## เพราะยาบางตัว TI ตัวเลขกว้างแต่อันตรายจริงสูง เช่น มอร์ฟีนที่กดการหายใจ
const RISK_LABEL := {
	"lowest": "ต่ำสุด",
	"low": "ต่ำ",
	"medium": "กลาง",
	"medium_high": "กลาง-สูง",
	"high": "สูง",
	"very_high": "สูงมาก",
	"extreme": "อันตรายสุด",
}

const RISK_ORDER := ["lowest", "low", "medium", "medium_high", "high", "very_high", "extreme"]


static func from_dict(substance_id: String, data: Dictionary) -> Substance:
	var substance := Substance.new()
	substance.id = substance_id
	substance.display_name = str(data.get("display_name", substance_id))
	substance.compound = str(data.get("compound", ""))
	substance.source_note = str(data.get("source_note", ""))
	substance.unit = str(data.get("unit", "mg"))
	substance.effective_dose = float(data.get("effective_dose", 1.0))
	substance.toxic_dose = float(data.get("toxic_dose", 2.0))
	substance.half_life_seconds = float(data.get("half_life_seconds", 30.0))
	substance.base_onset_seconds = float(data.get("base_onset_seconds", 40.0))
	substance.real_half_life_hours = float(data.get("real_half_life_hours", 1.0))
	substance.mechanism = str(data.get("mechanism", ""))
	substance.mechanism_note = str(data.get("mechanism_note", ""))
	substance.preparation_efficiency = data.get("preparation_efficiency", {})
	substance.therapeutic_effect = data.get("therapeutic_effect", {})
	substance.toxic_effect = data.get("toxic_effect", {})
	substance.antidote_for = data.get("antidote_for", [])
	substance.act_available = int(data.get("act_available", 0))
	substance.risk_level = str(data.get("risk_level", "low"))
	substance.risk_note = str(data.get("risk_note", ""))
	return substance


func therapeutic_index() -> float:
	return Pharmacokinetics.therapeutic_index(effective_dose, toxic_dose)


## ความกว้างของ Therapeutic Window ล้วน ๆ คำนวณจาก TI
func window_label() -> String:
	var index := therapeutic_index()
	if index >= 50.0:
		return "กว้างมาก"
	if index >= 10.0:
		return "กว้าง"
	if index >= 5.0:
		return "ปานกลาง"
	if index >= 2.5:
		return "แคบ"
	return "แคบที่สุด"


func risk_label() -> String:
	return RISK_LABEL.get(risk_level, risk_level)


func risk_rank() -> int:
	return RISK_ORDER.find(risk_level)


## TI กว้างแต่เสี่ยงสูง คือกับดักที่ผู้เล่นต้องเรียนรู้ ไม่ใช่ความผิดพลาดของข้อมูล
func is_deceptively_safe() -> bool:
	return therapeutic_index() >= 10.0 and risk_rank() >= RISK_ORDER.find("high")


func efficiency_for(method: Preparation.Method) -> float:
	return float(preparation_efficiency.get(Preparation.key_of(method), 0.0))


func best_method() -> Preparation.Method:
	var best: Preparation.Method = Preparation.Method.DECOCTION
	var best_value := -1.0
	for method in Preparation.all():
		var value := efficiency_for(method)
		if value > best_value:
			best_value = value
			best = method
	return best


func counters(status: String) -> bool:
	return antidote_for.has(status)
