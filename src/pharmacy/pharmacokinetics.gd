class_name Pharmacokinetics
extends RefCounted

## สูตรเภสัชจลนศาสตร์ ตามหัวข้อ "สูตรคำนวณ Onset / Duration" ในเอกสาร
## ทุกฟังก์ชันเป็น pure function ไม่พึ่ง engine เพื่อให้เทสต์ค่าตัวเลขได้แน่นอน

enum Route { INJECTION, SUBLINGUAL, ORAL, TOPICAL }
enum Zone { NO_EFFECT, THERAPEUTIC, TOXIC }

## ตารางเดียวกับ ROUTE_PROFILE ในเอกสาร
const ROUTE_PROFILE := {
	Route.INJECTION: {"speed_factor": 6.0, "bioavailability": 1.00, "name": "ฉีด"},
	Route.SUBLINGUAL: {"speed_factor": 3.5, "bioavailability": 0.80, "name": "อมใต้ลิ้น"},
	Route.ORAL: {"speed_factor": 1.0, "bioavailability": 0.50, "name": "กิน"},
	Route.TOPICAL: {"speed_factor": 0.4, "bioavailability": 0.30, "name": "ทา"},
}

## เอกสารให้ TD ของบางสารเป็น mg/kg จึงต้องมีน้ำหนักตัวอ้างอิงเพื่อแปลงเป็นหน่วยเดียวกับ ED
## ไม่ระบุในเอกสาร ตัดสินใจเอง: ใช้ผู้ใหญ่มาตรฐาน 70 กก.
const REFERENCE_BODY_WEIGHT_KG := 70.0

## ผู้เล่นต้องให้เกิน ED เสมอถึงจะมี duration ใช้งานได้ ตามหลัก MEC
## ต่ำกว่านี้ถือว่าไม่มีผล แม้จะผ่านเกณฑ์ ED มาหวุดหวิด
const MIN_USEFUL_DOSE_RATIO := 1.05


static func bioavailability(route: Route) -> float:
	return ROUTE_PROFILE[route]["bioavailability"]


static func speed_factor(route: Route) -> float:
	return ROUTE_PROFILE[route]["speed_factor"]


static func route_name(route: Route) -> String:
	return ROUTE_PROFILE[route]["name"]


## ขนาดยาที่เข้าสู่กระแสเลือดจริง = ขนาดที่ให้ x bioavailability ของวิธีให้ยา
static func effective_dose(raw_dose: float, route: Route) -> float:
	return raw_dose * bioavailability(route)


## เวลาที่ยาเริ่มออกฤทธิ์ ยิ่ง route เร็วและ potency สูง ยิ่งออกฤทธิ์ไว
static func onset_seconds(base_onset: float, route: Route, potency: float) -> float:
	return base_onset / speed_factor(route) / maxf(potency, 0.01)


## ระยะเวลาที่ความเข้มข้นยังอยู่เหนือ ED
## ถ้าให้พอดี ED เป๊ะ (dose_ratio = 1.0) จะได้ 0 ตรงกับหลักจริง
static func duration_seconds(half_life: float, dose_ratio: float) -> float:
	if dose_ratio <= 1.0:
		return 0.0
	var elimination_rate := log(2.0) / half_life
	return log(dose_ratio) / elimination_rate


## โซนผลของยา: ต่ำกว่า ED ไม่ออกฤทธิ์, ระหว่าง ED ถึง TD คือ Therapeutic Window, เกิน TD เป็นพิษ
static func effect_zone(effective: float, ed: float, td: float) -> Zone:
	if effective < ed:
		return Zone.NO_EFFECT
	if effective <= td:
		return Zone.THERAPEUTIC
	return Zone.TOXIC


## Therapeutic Index = TD / ED ยิ่งมากยิ่งปลอดภัย
static func therapeutic_index(ed: float, td: float) -> float:
	if ed <= 0.0:
		return 0.0
	return td / ed


## ขอบบนของ Therapeutic Window ขยายได้ตาม INT ของผู้เล่น
## ทุก 10 INT ได้ +2% ตามสูตร TI_Window_Bonus ในหัวข้อระบบ Stat
static func widened_toxic_dose(td: float, intellect: float) -> float:
	return td * (1.0 + Formulas.therapeutic_window_bonus_percent(intellect) / 100.0)


## ความเข้มข้นในเลือด ณ เวลา t ตาม One-Compartment Model
## ใช้วาดกราฟ Therapeutic Window ใน UI และในมินิเกมคาลิเบรตขนาดยาของบอส
static func concentration_at(
	dose: float, route: Route, half_life: float, absorption_rate: float,
	volume_of_distribution: float, elapsed_seconds: float
) -> float:
	if elapsed_seconds <= 0.0:
		return 0.0
	var elimination_rate := log(2.0) / half_life
	if is_equal_approx(absorption_rate, elimination_rate):
		return 0.0
	var f := bioavailability(route)
	var scale := (dose * f * absorption_rate) / (volume_of_distribution * (absorption_rate - elimination_rate))
	return maxf(scale * (exp(-elimination_rate * elapsed_seconds) - exp(-absorption_rate * elapsed_seconds)), 0.0)


static func zone_name(zone: Zone) -> String:
	match zone:
		Zone.NO_EFFECT:
			return "ไม่ออกฤทธิ์"
		Zone.THERAPEUTIC:
			return "ออกฤทธิ์"
		_:
			return "เป็นพิษ"
