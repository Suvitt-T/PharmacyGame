class_name ItemTier
extends RefCounted

## 4 Tier ตามตารางในหัวข้อ Itemization

enum Tier { COMMON, UNCOMMON, RARE, EPIC }

const PROFILE := {
	Tier.COMMON: {"name": "ธรรมดา", "multiplier": 1.00, "affix_slots": 0, "vial_slots": 0, "color": Color(0.78, 0.78, 0.78)},
	Tier.UNCOMMON: {"name": "ไม่ธรรมดา", "multiplier": 1.15, "affix_slots": 1, "vial_slots": 0, "color": Color(0.45, 0.82, 0.45)},
	Tier.RARE: {"name": "หายาก", "multiplier": 1.35, "affix_slots": 2, "vial_slots": 1, "color": Color(0.38, 0.62, 0.95)},
	Tier.EPIC: {"name": "มหากาพย์", "multiplier": 1.60, "affix_slots": 3, "vial_slots": 2, "color": Color(0.72, 0.45, 0.92)},
}


static func multiplier(tier: Tier) -> float:
	return PROFILE[tier]["multiplier"]


static func affix_slots(tier: Tier) -> int:
	return PROFILE[tier]["affix_slots"]


static func vial_slots(tier: Tier) -> int:
	return PROFILE[tier]["vial_slots"]


static func display_name(tier: Tier) -> String:
	return PROFILE[tier]["name"]


static func color(tier: Tier) -> Color:
	return PROFILE[tier]["color"]


static func all() -> Array:
	return [Tier.COMMON, Tier.UNCOMMON, Tier.RARE, Tier.EPIC]
