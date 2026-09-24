class_name EnemyArchetype
extends RefCounted

## AI Behavior 4 แบบ ตามตารางในหัวข้อ "ระบบศัตรูทั่วไป"
## ตัวคูณความเร็วมาจากเอกสาร ส่วนความเร็วฐานไม่ได้ระบุ ตัดสินใจเอง 3.2 หน่วย/วินาที
## ซึ่งช้ากว่าผู้เล่นเดิน (5.0) เล็กน้อย ทำให้ถอยหนีได้แต่ไม่ถึงกับหลุดง่าย

enum Kind { SKITTISH, BRAWLER, KITER, PACK_HUNTER }

const BASE_MOVE_SPEED := 3.2

const PROFILE := {
	Kind.SKITTISH: {
		"key": "skittish",
		"name": "หลบหนี/ขี้กลัว",
		"aggro_range": 8.0,
		"speed_multiplier": 1.4,
		"attack_range": 2.0,
		"attack_cooldown": 1.4,
		## ต่ำกว่านี้เลิกหนีแล้วสู้สวน
		"desperate_hp_ratio": 0.20,
		## จนมุมแล้วโจมตีแรงขึ้น
		"cornered_damage_bonus": 0.50,
		"flee_distance": 12.0,
	},
	Kind.BRAWLER: {
		"key": "brawler",
		"name": "บุกประชิด",
		"aggro_range": 12.0,
		"speed_multiplier": 1.0,
		"attack_range": 2.2,
		"attack_cooldown": 1.6,
		## คอมโบ 2-3 ฮิต มี windup ให้หลบทัน
		"combo_min": 2,
		"combo_max": 3,
		"combo_gap": 0.35,
		"windup": 0.55,
	},
	Kind.KITER: {
		"key": "kiter",
		"name": "ระยะไกล/Kiter",
		"aggro_range": 15.0,
		"speed_multiplier": 1.0,
		"attack_range": 12.0,
		"attack_cooldown": 2.2,
		"windup": 0.7,
		## ถอยเมื่อผู้เล่นเข้าใกล้กว่านี้
		"retreat_range": 5.0,
		## ระยะที่พยายามรักษาไว้
		"preferred_min": 8.0,
		"preferred_max": 12.0,
	},
	Kind.PACK_HUNTER: {
		"key": "pack_hunter",
		"name": "ฝูง (Pack Hunter)",
		"aggro_range": 10.0,
		"speed_multiplier": 1.2,
		"attack_range": 2.0,
		"attack_cooldown": 1.3,
		## HP ต่ำกว่านี้เรียกพวกในรัศมี call_radius
		"call_hp_ratio": 0.50,
		"call_radius": 20.0,
		## ล้อมโจมตี 2 ทิศพร้อมกัน
		"flank_angles": [0.9, -0.9],
	},
}

const TIER_BASE := {
	"common": {"hp": 60.0, "damage": 8.0, "name": "ธรรมดา"},
	"elite": {"hp": 250.0, "damage": 20.0, "name": "ชนชั้นสูง"},
	"miniboss": {"hp": 800.0, "damage": 35.0, "name": "มินิบอส"},
}


static func from_key(key: String) -> Kind:
	for kind in PROFILE:
		if PROFILE[kind]["key"] == key:
			return kind
	return Kind.BRAWLER


static func profile(kind: Kind) -> Dictionary:
	return PROFILE[kind]


static func value(kind: Kind, field: String, fallback = 0.0):
	return PROFILE[kind].get(field, fallback)


static func move_speed(kind: Kind) -> float:
	return BASE_MOVE_SPEED * float(PROFILE[kind]["speed_multiplier"])


static func display_name(kind: Kind) -> String:
	return PROFILE[kind]["name"]


static func base_hp(tier: String) -> float:
	return float(TIER_BASE.get(tier, TIER_BASE["common"])["hp"])


static func base_damage(tier: String) -> float:
	return float(TIER_BASE.get(tier, TIER_BASE["common"])["damage"])


## เอกสารระบุว่า Elite มี Corruption Aura เสมอ และศัตรูตั้งแต่ Act 2 ก็มีทุกตัว
static func has_corruption_aura(tier: String, biome: String) -> bool:
	if tier == "elite" or tier == "miniboss":
		return true
	return biome != "hub"
