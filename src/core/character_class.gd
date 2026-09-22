class_name CharacterClass
extends RefCounted

## 4 สายอาชีพ ปลดล็อกที่ Lv 10 ตามหัวข้อ "ระบบอาชีพ"

enum Id { NONE, ALCHEMIST, FIELD_MEDIC, TOXICOLOGIST, HERB_VANGUARD }

const UNLOCK_LEVEL := 10

## โบนัสอัตโนมัติต่อเลเวล นับตั้งแต่เลเวลที่ปลดล็อกอาชีพเป็นต้นไป
const GROWTH_PER_LEVEL := {
	Id.NONE: {},
	Id.ALCHEMIST: {"intellect": 1.0},
	Id.FIELD_MEDIC: {"intellect": 1.0, "vitality": 0.5},
	Id.TOXICOLOGIST: {"intellect": 1.0, "agility": 0.5},
	Id.HERB_VANGUARD: {"vitality": 1.0, "strength": 0.5},
}

const DISPLAY_NAME := {
	Id.NONE: "ผู้ตื่น",
	Id.ALCHEMIST: "นักปรุงยา",
	Id.FIELD_MEDIC: "หมอสนาม",
	Id.TOXICOLOGIST: "นักพิษวิทยา",
	Id.HERB_VANGUARD: "นักรบพฤกษา",
}

## แขนงเภสัชศาสตร์ที่แต่ละอาชีพเน้น
const PHARMACY_BRANCH := {
	Id.NONE: "",
	Id.ALCHEMIST: "Pharmaceutics",
	Id.FIELD_MEDIC: "Pharmacology",
	Id.TOXICOLOGIST: "Toxicology",
	Id.HERB_VANGUARD: "Pharmacognosy",
}

## ศาลรากประจำทิศใน Hub ใช้ตอนพิธีเลือกเส้นทาง Lv 10
const SHRINE_DIRECTION := {
	Id.ALCHEMIST: "east",
	Id.FIELD_MEDIC: "south",
	Id.TOXICOLOGIST: "west",
	Id.HERB_VANGUARD: "north",
}

const SKILL_UNLOCK_LEVELS := [10, 13, 16, 19, 22]


static func growth_for(class_id: Id, levels_gained: int) -> StatBlock:
	var block := StatBlock.new()
	if levels_gained <= 0:
		return block
	var growth: Dictionary = GROWTH_PER_LEVEL.get(class_id, {})
	for key in growth:
		block.set_stat(key, float(growth[key]) * float(levels_gained))
	return block


static func display_name(class_id: Id) -> String:
	return DISPLAY_NAME.get(class_id, "?")


static func all_playable() -> Array:
	return [Id.ALCHEMIST, Id.FIELD_MEDIC, Id.TOXICOLOGIST, Id.HERB_VANGUARD]
