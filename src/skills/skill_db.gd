class_name SkillDB
extends RefCounted

## โหลดตารางสกิลและชื่อสายย่อยจาก JSON

const SKILL_PATH := "res://data/skills.json"

## ลำดับปลดล็อกตามเอกสาร: Lv10 -> 13 -> 16 -> 19 -> 22 (Ultimate)
const CHOICE_LEVELS := [13, 16, 19]
const CORE_LEVEL := 10
const ULTIMATE_LEVEL := 22

const CLASS_KEY := {
	CharacterClass.Id.ALCHEMIST: "alchemist",
	CharacterClass.Id.FIELD_MEDIC: "field_medic",
	CharacterClass.Id.TOXICOLOGIST: "toxicologist",
	CharacterClass.Id.HERB_VANGUARD: "herb_vanguard",
}

static var _skills: Dictionary = {}
static var _branches: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(SKILL_PATH, FileAccess.READ)
	if file == null:
		push_error("เปิดไฟล์สกิลไม่ได้: %s" % SKILL_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("รูปแบบ JSON ของสกิลไม่ถูกต้อง")
		return
	_branches = parsed.get("_branches", {})
	for key in parsed:
		if not key.begins_with("_"):
			_skills[key] = Skill.from_dict(key, parsed[key])


static func class_key(class_id: CharacterClass.Id) -> String:
	return str(CLASS_KEY.get(class_id, ""))


static func skill(skill_id: String) -> Skill:
	ensure_loaded()
	return _skills.get(skill_id, null)


static func all_skills() -> Array:
	ensure_loaded()
	return _skills.values()


static func skills_for_class(class_id: CharacterClass.Id) -> Array:
	ensure_loaded()
	var key := class_key(class_id)
	var found := []
	for item in _skills.values():
		if item.class_key == key:
			found.append(item)
	return found


## สกิลที่ให้เลือกที่เลเวลนั้น ปกติได้คู่ A/B ยกเว้น Lv10 ที่มีตัวเดียว
static func choices_at(class_id: CharacterClass.Id, level: int) -> Array:
	var found := []
	for item in skills_for_class(class_id):
		if item.level == level:
			found.append(item)
	found.sort_custom(func(a, b): return a.branch < b.branch)
	return found


static func core_skill(class_id: CharacterClass.Id) -> Skill:
	var found := choices_at(class_id, CORE_LEVEL)
	return found[0] if found.size() > 0 else null


static func branch_name(class_id: CharacterClass.Id, branch: String) -> String:
	ensure_loaded()
	var key := class_key(class_id)
	return str(_branches.get(key, {}).get(branch, branch))


static func branch_names(class_id: CharacterClass.Id) -> Dictionary:
	ensure_loaded()
	return _branches.get(class_key(class_id), {})
