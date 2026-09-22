class_name ActiveEffect
extends RefCounted

## ยา 1 ขนานที่กำลังเดินอยู่ในร่างกาย ผ่าน 3 ช่วง: รอออกฤทธิ์ (onset) -> ออกฤทธิ์ -> หมดฤทธิ์

enum Phase { PENDING, ACTIVE, FINISHED }

var substance_id: String = ""
var zone: Pharmacokinetics.Zone = Pharmacokinetics.Zone.NO_EFFECT
var effective_dose: float = 0.0
var dose_ratio: float = 0.0
var onset_remaining: float = 0.0
var duration_remaining: float = 0.0
var phase: Phase = Phase.PENDING
var applied_stat_key: String = ""
var applied_stat_amount: float = 0.0


static func from_evaluation(evaluation: Dictionary) -> ActiveEffect:
	var effect := ActiveEffect.new()
	effect.substance_id = str(evaluation["substance_id"])
	effect.zone = evaluation["zone"]
	effect.effective_dose = float(evaluation["effective_dose"])
	effect.dose_ratio = float(evaluation["dose_ratio"])
	effect.onset_remaining = float(evaluation["onset"])
	effect.duration_remaining = float(evaluation["duration"])
	return effect


func substance() -> Substance:
	return PharmacyDB.substance(substance_id)


## ผลที่จะเกิดจริง ขึ้นกับว่าขนาดยาตกอยู่โซนไหน
func payload() -> Dictionary:
	match zone:
		Pharmacokinetics.Zone.THERAPEUTIC:
			return substance().therapeutic_effect
		Pharmacokinetics.Zone.TOXIC:
			return substance().toxic_effect
		_:
			return {}


## ยาที่ไม่ถึง ED ไม่มีอะไรเกิดขึ้น ไม่ต้องเข้าคิวรอ
func is_inert() -> bool:
	return zone == Pharmacokinetics.Zone.NO_EFFECT or duration_remaining <= 0.0


func advance(delta: float) -> void:
	if phase == Phase.FINISHED:
		return
	if phase == Phase.PENDING:
		onset_remaining -= delta
		if onset_remaining <= 0.0:
			phase = Phase.ACTIVE
		return
	duration_remaining -= delta
	if duration_remaining <= 0.0:
		phase = Phase.FINISHED
