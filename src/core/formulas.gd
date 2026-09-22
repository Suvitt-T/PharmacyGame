class_name Formulas
extends RefCounted

## สูตรคำนวณกลางทั้งเกม ตามหัวข้อ "ระบบ Stat" ในเอกสารออกแบบ
## ทุกฟังก์ชันเป็น pure function ไม่พึ่ง engine state เพื่อให้เทสต์แบบ headless ได้

const CRIT_CHANCE_CAP := 40.0
const EVASION_CHANCE_CAP := 30.0

# ไม่ระบุในเอกสาร ตัดสินใจเอง
const CRIT_MULTIPLIER := 1.75
const DEFENSE_CONSTANT := 100.0


static func max_hp(vitality: float, level: int) -> float:
	return 80.0 + vitality * 8.0 + float(level) * 5.0


static func max_mana(intellect: float, level: int) -> float:
	return 40.0 + intellect * 6.0 + float(level) * 4.0


## ไม่ระบุในเอกสาร ตัดสินใจเอง: Stamina อิง VIT เป็นหลัก เสริมด้วย AGI
static func max_stamina(vitality: float, agility: float) -> float:
	return 100.0 + vitality * 2.0 + agility * 3.0


static func physical_damage(weapon_base: float, strength: float) -> float:
	return weapon_base * (1.0 + strength * 0.02)


static func skill_damage(skill_base: float, intellect: float) -> float:
	return skill_base * (1.0 + intellect * 0.025)


static func crit_chance_percent(agility: float) -> float:
	return minf(agility * 0.15, CRIT_CHANCE_CAP)


static func evasion_chance_percent(agility: float) -> float:
	return minf(agility * 0.10, EVASION_CHANCE_CAP)


static func craft_speed(agility: float) -> float:
	return 1.0 + agility * 0.005


## ทุก 10 INT ขยายขอบ Therapeutic Window ในมินิเกมคาลิเบรตขนาดยา +2%
static func therapeutic_window_bonus_percent(intellect: float) -> float:
	return floorf(intellect / 10.0) * 2.0


## ไม่ระบุในเอกสาร ตัดสินใจเอง: mitigation แบบ diminishing return
## DEF 100 = ลดดาเมจ 50%, ไม่มีทางลดถึง 100%
static func damage_after_defense(raw_damage: float, defense: float) -> float:
	return raw_damage * (DEFENSE_CONSTANT / (DEFENSE_CONSTANT + maxf(defense, 0.0)))


static func weapon_base_damage(item_level: int) -> float:
	return 8.0 + float(item_level) * 2.2


static func armor_base_defense(item_level: int) -> float:
	return 5.0 + float(item_level) * 1.5


static func enemy_hp(base_hp: float, zone_level: int) -> float:
	return base_hp * (1.0 + float(zone_level - 1) * 0.12)


static func enemy_damage(base_damage: float, zone_level: int) -> float:
	return base_damage * (1.0 + float(zone_level - 1) * 0.08)
