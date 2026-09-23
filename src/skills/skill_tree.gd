class_name SkillTree
extends RefCounted

## สกิลที่ผู้เล่นเลือกไว้ และกติกาการล็อกสายย่อย
##
## กติกาตามเอกสาร: เลือกทีละอันจากคู่ A/B ที่ Lv13/16/19
## ล็อกเข้าสายเมื่อเลือกครบ 2 ครั้งในสายเดียวกัน แล้ว Lv22 ได้ Ultimate ของสายนั้น
## ถ้า 2 ครั้งแรกเลือกคนละสาย การเลือกที่ Lv19 จะเป็นตัวตัดสิน

signal skill_learned(skill: Skill)
signal branch_locked(branch: String)

const PICKS_TO_LOCK := 2

var class_id: CharacterClass.Id = CharacterClass.Id.NONE
## level -> skill_id
var picks: Dictionary = {}


func _init(p_class_id: CharacterClass.Id = CharacterClass.Id.NONE) -> void:
	class_id = p_class_id
	SkillDB.ensure_loaded()


func branch_pick_count(branch: String) -> int:
	var count := 0
	for level in picks:
		var skill := SkillDB.skill(picks[level])
		if skill != null and skill.branch == branch:
			count += 1
	return count


## สายที่ถูกล็อกแล้ว คืนสตริงว่างถ้ายังไม่ล็อก
func locked_branch() -> String:
	for branch in ["a", "b"]:
		if branch_pick_count(branch) >= PICKS_TO_LOCK:
			return branch
	return ""


func is_locked() -> bool:
	return not locked_branch().is_empty()


func branch_display_name() -> String:
	var branch := locked_branch()
	return SkillDB.branch_name(class_id, branch) if not branch.is_empty() else "ยังไม่ล็อกสาย"


## สกิลที่เลือกได้ที่เลเวลนั้น กรองตามสายที่ล็อกไว้แล้ว
func available_choices(level: int) -> Array:
	if class_id == CharacterClass.Id.NONE:
		return []
	var locked := locked_branch()
	var found := []
	for skill in SkillDB.choices_at(class_id, level):
		if level == SkillDB.ULTIMATE_LEVEL:
			# Ultimate ได้เฉพาะสายที่ล็อกไว้ ยังไม่ล็อกก็ยังเลือกไม่ได้
			if not locked.is_empty() and skill.branch == locked:
				found.append(skill)
			continue
		if locked.is_empty() or skill.branch == locked or skill.is_core():
			found.append(skill)
	return found


func can_learn(skill: Skill, character_level: int) -> bool:
	if skill == null or class_id == CharacterClass.Id.NONE:
		return false
	if skill.class_key != SkillDB.class_key(class_id):
		return false
	if character_level < skill.level:
		return false
	if picks.has(skill.level):
		return false
	return available_choices(skill.level).has(skill)


func learn(skill: Skill, character_level: int) -> bool:
	if not can_learn(skill, character_level):
		return false
	var was_locked := is_locked()
	picks[skill.level] = skill.id
	skill_learned.emit(skill)
	if not was_locked and is_locked():
		branch_locked.emit(locked_branch())
	return true


## เรียนสกิล Lv10 ที่ทุกสายได้เหมือนกัน
func learn_core(character_level: int) -> bool:
	var core := SkillDB.core_skill(class_id)
	return learn(core, character_level) if core != null else false


func learned_skills() -> Array:
	var found := []
	var levels := picks.keys()
	levels.sort()
	for level in levels:
		var skill := SkillDB.skill(picks[level])
		if skill != null:
			found.append(skill)
	return found


func has_skill(skill_id: String) -> bool:
	return picks.values().has(skill_id)


func skill_at_level(level: int) -> Skill:
	return SkillDB.skill(picks.get(level, ""))


## เลเวลถัดไปที่ยังไม่ได้เลือกสกิล -1 ถ้าเลือกครบแล้ว
func next_choice_level(character_level: int) -> int:
	var levels := [SkillDB.CORE_LEVEL] + SkillDB.CHOICE_LEVELS + [SkillDB.ULTIMATE_LEVEL]
	for level in levels:
		if character_level >= level and not picks.has(level):
			return level
	return -1


func active_skills() -> Array:
	var found := []
	for skill in learned_skills():
		if skill.kind != Skill.Kind.PASSIVE:
			found.append(skill)
	return found


func passive_skills() -> Array:
	var found := []
	for skill in learned_skills():
		if skill.kind == Skill.Kind.PASSIVE:
			found.append(skill)
	return found


## ใช้ตรวจว่าบิลด์นี้ทำกลไกของบอสได้ไหม
func has_interrupt() -> bool:
	for skill in learned_skills():
		if skill.can_interrupt():
			return true
	return false


func can_read_vitals() -> bool:
	for skill in learned_skills():
		if skill.can_reveal_vitals():
			return true
	return false


func reset() -> void:
	picks.clear()


func to_dict() -> Dictionary:
	return {"class_id": int(class_id), "picks": picks.duplicate()}


static func from_dict(data: Dictionary) -> SkillTree:
	var tree := SkillTree.new(int(data.get("class_id", 0)) as CharacterClass.Id)
	for level in data.get("picks", {}):
		tree.picks[int(level)] = str(data["picks"][level])
	return tree
