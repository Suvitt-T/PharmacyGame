class_name Skill
extends RefCounted

## สกิล 1 ตัว โหลดจาก data/skills.json

enum Kind { ACTIVE, PASSIVE, TOGGLE, TRIGGERED }

const UNLIMITED_USES := -1

var id: String = ""
var class_key: String = ""
var level: int = 10
var branch: String = "core"
var source: String = "designed"
var name: String = ""
var kind: Kind = Kind.ACTIVE
var mana_cost: float = 0.0
var mana_per_second: float = 0.0
var cooldown: float = 0.0
var uses_per_fight: int = UNLIMITED_USES
var effect: Dictionary = {}
var note: String = ""


const KIND_FROM_TEXT := {
	"active": Kind.ACTIVE,
	"passive": Kind.PASSIVE,
	"toggle": Kind.TOGGLE,
	"triggered": Kind.TRIGGERED,
}


static func from_dict(skill_id: String, data: Dictionary) -> Skill:
	var skill := Skill.new()
	skill.id = skill_id
	skill.class_key = str(data.get("class", ""))
	skill.level = int(data.get("level", 10))
	skill.branch = str(data.get("branch", "core"))
	skill.source = str(data.get("source", "designed"))
	skill.name = str(data.get("name", skill_id))
	skill.kind = KIND_FROM_TEXT.get(str(data.get("kind", "active")), Kind.ACTIVE)
	skill.mana_cost = float(data.get("mana_cost", 0.0))
	skill.mana_per_second = float(data.get("mana_per_second", 0.0))
	skill.cooldown = float(data.get("cooldown", 0.0))
	skill.uses_per_fight = int(data.get("uses_per_fight", UNLIMITED_USES))
	skill.effect = data.get("effect", {})
	skill.note = str(data.get("note", ""))
	return skill


func is_core() -> bool:
	return branch == "core"


func is_ultimate() -> bool:
	return level >= 22


func is_from_doc() -> bool:
	return source == "doc"


func effect_kind() -> String:
	return str(effect.get("kind", ""))


func magnitude() -> float:
	return float(effect.get("magnitude", 0.0))


func duration() -> float:
	return float(effect.get("duration", 0.0))


func radius() -> float:
	return float(effect.get("radius", 0.0))


## สกิลที่ขัดจังหวะวงจรของบอสได้ เอกสารระบุว่าใช้ "วิเคราะห์จุดอ่อน หรือเทียบเท่า"
func can_interrupt() -> bool:
	return bool(effect.get("interrupt", false))


## สกิลที่อ่านค่าจังหวะหัวใจในบอสท้ายบทได้
func can_reveal_vitals() -> bool:
	return effect_kind() == "reveal_vitals"


func cost_text() -> String:
	if kind == Kind.TOGGLE:
		return "%d Mana/วิ" % int(mana_per_second)
	if mana_cost <= 0.0:
		return "ไม่ใช้ Mana"
	return "%d Mana" % int(mana_cost)


func cooldown_text() -> String:
	if uses_per_fight > 0:
		return "%d ครั้ง/ไฟต์" % uses_per_fight
	if cooldown <= 0.0:
		return "ไม่มีคูลดาวน์"
	return "%d วิ" % int(cooldown)
