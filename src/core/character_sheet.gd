class_name CharacterSheet
extends RefCounted

## รวม Stat + เลเวล + XP + อาชีพ ของตัวละคร 1 ตัว
## ไม่ผูกกับ Node ใด เพื่อให้ Player, Companion NPC และเทสต์ใช้ร่วมกันได้

signal leveled_up(new_level: int)
signal xp_gained(amount: int, total: int)
signal stats_changed()

const BASE_STAT_VALUE := 5.0

var character_name: String = "ผู้ตื่น"
var level: int = 1
var total_xp: int = 0
var class_id: CharacterClass.Id = CharacterClass.Id.NONE
var class_chosen_at_level: int = CharacterClass.UNLOCK_LEVEL

## แต้มที่ผู้เล่นแจกเอง ไม่รวม base 5 และไม่รวมโบนัสอาชีพ
var allocated: StatBlock = StatBlock.new()

## โบนัสชั่วคราวจากยาและบัฟ ระบบเภสัชกรรมเขียนลงตรงนี้ ไม่แตะ allocated
var temporary: StatBlock = StatBlock.new()


func _init(p_level: int = 1) -> void:
	level = clampi(p_level, 1, Progression.MAX_LEVEL)
	total_xp = Progression.cumulative_xp_for(level)


# --- Stat ---

func base_stats() -> StatBlock:
	return StatBlock.uniform(BASE_STAT_VALUE)


func class_growth_levels() -> int:
	if class_id == CharacterClass.Id.NONE:
		return 0
	return maxi(0, level - class_chosen_at_level)


func class_bonus() -> StatBlock:
	return CharacterClass.growth_for(class_id, class_growth_levels())


func final_stats() -> StatBlock:
	return base_stats().plus(allocated).plus(class_bonus()).plus(temporary)


func spent_points() -> int:
	return int(round(allocated.total()))


func unspent_points() -> int:
	return Progression.total_stat_points(level) - spent_points()


func allocate(stat_key: String, points: int = 1) -> bool:
	if points <= 0 or points > unspent_points():
		return false
	if not StatBlock.KEYS.has(stat_key):
		return false
	allocated.add_stat(stat_key, float(points))
	stats_changed.emit()
	return true


func respec() -> void:
	allocated = StatBlock.new()
	stats_changed.emit()


# --- ค่าที่คำนวณต่อ ---

func max_hp() -> float:
	return Formulas.max_hp(final_stats().vitality, level)


func max_mana() -> float:
	return Formulas.max_mana(final_stats().intellect, level)


func max_stamina() -> float:
	var stats := final_stats()
	return Formulas.max_stamina(stats.vitality, stats.agility)


func crit_chance() -> float:
	return Formulas.crit_chance_percent(final_stats().agility)


func evasion_chance() -> float:
	return Formulas.evasion_chance_percent(final_stats().agility)


func craft_speed() -> float:
	return Formulas.craft_speed(final_stats().agility)


func therapeutic_window_bonus() -> float:
	return Formulas.therapeutic_window_bonus_percent(final_stats().intellect)


# --- XP / เลเวล ---

func add_xp(amount: int) -> int:
	if amount <= 0 or level >= Progression.MAX_LEVEL:
		return 0
	total_xp += amount
	xp_gained.emit(amount, total_xp)
	var new_level := Progression.level_for_cumulative_xp(total_xp)
	var gained := new_level - level
	if gained > 0:
		level = new_level
		leveled_up.emit(level)
		stats_changed.emit()
	return gained


func xp_into_current_level() -> int:
	return total_xp - Progression.cumulative_xp_for(level)


func xp_needed_for_next_level() -> int:
	return Progression.xp_to_next(level)


func level_progress_ratio() -> float:
	var needed := xp_needed_for_next_level()
	if needed <= 0:
		return 1.0
	return clampf(float(xp_into_current_level()) / float(needed), 0.0, 1.0)


# --- อาชีพ ---

func can_choose_class() -> bool:
	return class_id == CharacterClass.Id.NONE and level >= CharacterClass.UNLOCK_LEVEL


func choose_class(new_class: CharacterClass.Id) -> bool:
	if not can_choose_class():
		return false
	class_id = new_class
	class_chosen_at_level = level
	stats_changed.emit()
	return true


func unlocked_skill_slots() -> int:
	if class_id == CharacterClass.Id.NONE:
		return 0
	var count := 0
	for unlock_level in CharacterClass.SKILL_UNLOCK_LEVELS:
		if level >= unlock_level:
			count += 1
	return count


# --- Save / Load ---

func to_dict() -> Dictionary:
	return {
		"character_name": character_name,
		"level": level,
		"total_xp": total_xp,
		"class_id": int(class_id),
		"class_chosen_at_level": class_chosen_at_level,
		"allocated": allocated.to_dict(),
	}


static func from_dict(data: Dictionary) -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.character_name = str(data.get("character_name", "ผู้ตื่น"))
	sheet.level = int(data.get("level", 1))
	sheet.total_xp = int(data.get("total_xp", 0))
	sheet.class_id = int(data.get("class_id", CharacterClass.Id.NONE)) as CharacterClass.Id
	sheet.class_chosen_at_level = int(data.get("class_chosen_at_level", CharacterClass.UNLOCK_LEVEL))
	sheet.allocated = StatBlock.from_dict(data.get("allocated", {}))
	return sheet
