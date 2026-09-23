class_name Affix
extends RefCounted

## Affix ที่สุ่มลงช่องของอุปกรณ์ ตามหัวข้อ Itemization: สุ่ม +3% ถึง +8% ต่อช่อง
##
## เอกสารระบุว่า affix "ผูกกับ Stat หลัก (STR/INT/VIT/AGI)" แต่ตัวอย่างคำนวณ
## มีดาบที่ได้ +6% STR และ +4% Crit% แล้วนำเฉพาะ +6% STR เข้าสูตร FinalStat
## จึงแยกเป็น 2 ชนิด: affix ที่ตรงกับ scaling_stat ของอุปกรณ์เข้าสูตร
## ส่วน affix พิเศษ (Crit/Evasion) ให้ผลตรง ๆ ไม่เข้าสูตร ผลลัพธ์ตรงกับตัวอย่างพอดี

const MIN_PERCENT := 3.0
const MAX_PERCENT := 8.0

const PRIMARY_STATS := ["strength", "intellect", "vitality", "agility"]
const SPECIAL_STATS := ["crit", "evasion"]

const DISPLAY_NAME := {
	"strength": "พละกำลัง",
	"intellect": "ปัญญา",
	"vitality": "พลังชีวิต",
	"agility": "ความคล่องแคล่ว",
	"crit": "โอกาสคริติคอล",
	"evasion": "โอกาสหลบ",
}

## โอกาสที่ช่องหนึ่งจะได้ affix พิเศษแทน Stat หลัก
const SPECIAL_CHANCE := 0.25

var stat: String = "strength"
var percent: float = 3.0


static func make(p_stat: String, p_percent: float) -> Affix:
	var affix := Affix.new()
	affix.stat = p_stat
	affix.percent = p_percent
	return affix


static func roll(rng: RandomNumberGenerator) -> Affix:
	var pool := SPECIAL_STATS if rng.randf() < SPECIAL_CHANCE else PRIMARY_STATS
	var stat_key: String = pool[rng.randi() % pool.size()]
	var value := snappedf(rng.randf_range(MIN_PERCENT, MAX_PERCENT), 0.1)
	return make(stat_key, value)


func is_special() -> bool:
	return SPECIAL_STATS.has(stat)


func is_primary() -> bool:
	return PRIMARY_STATS.has(stat)


func display_name() -> String:
	return DISPLAY_NAME.get(stat, stat)


func to_text() -> String:
	return "+%.1f%% %s" % [percent, display_name()]


func to_dict() -> Dictionary:
	return {"stat": stat, "percent": percent}


static func from_dict(data: Dictionary) -> Affix:
	return make(str(data.get("stat", "strength")), float(data.get("percent", MIN_PERCENT)))
