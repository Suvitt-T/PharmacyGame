class_name SkillRuntime
extends Node

## คุมการใช้สกิล: ตรวจ Mana/คูลดาวน์/จำนวนครั้งต่อไฟต์ แล้วลงผลกับตัวผู้ใช้เอง
##
## ผลที่กระทบตัวเอง (รักษา เกราะ บัฟ ล้างสถานะ) ลงที่นี่ตรง ๆ
## ส่วนผลที่ต้องเล็งเป้าหรือเป็นวง จะยิงสัญญาณ skill_activated ให้ระบบต่อสู้รับไปทำ
## แบ่งแบบนี้เพราะระบบเล็งเป้ายังไม่มีจนกว่าจะถึง Phase 5

signal skill_activated(skill: Skill)
signal skill_failed(skill: Skill, reason: String)
signal toggle_changed(skill: Skill, enabled: bool)
signal cooldown_changed(skill_id: String, remaining: float)

@export var combatant_path: NodePath = NodePath("../Combatant")
@export var metabolism_path: NodePath = NodePath("../Metabolism")

var tree := SkillTree.new()

var _combatant: Combatant
var _metabolism: Metabolism
## skill_id -> วินาทีที่เหลือ
var _cooldowns: Dictionary = {}
## skill_id -> จำนวนครั้งที่ใช้ไปแล้วในไฟต์นี้
var _uses_this_fight: Dictionary = {}
var _active_toggles: Dictionary = {}
## skill_id -> วินาทีที่เหลือของบัฟที่กระทบตัวเอง
var _self_buffs: Dictionary = {}


func _ready() -> void:
	SkillDB.ensure_loaded()
	_combatant = get_node_or_null(combatant_path) as Combatant
	_metabolism = get_node_or_null(metabolism_path) as Metabolism
	if _combatant != null:
		tree.class_id = _combatant.sheet.class_id
		_combatant.died.connect(end_fight)


func _process(delta: float) -> void:
	_tick_cooldowns(delta)
	_tick_toggles(delta)
	_tick_self_buffs(delta)


# --- การใช้สกิล ---

func can_use(skill: Skill) -> String:
	if skill == null:
		return "ไม่มีสกิลนี้"
	if not tree.has_skill(skill.id):
		return "ยังไม่ได้เรียนสกิลนี้"
	if skill.kind == Skill.Kind.PASSIVE:
		return "สกิล Passive ทำงานเอง"
	if remaining_cooldown(skill.id) > 0.0:
		return "ยังติดคูลดาวน์"
	if skill.uses_per_fight > 0 and int(_uses_this_fight.get(skill.id, 0)) >= skill.uses_per_fight:
		return "ใช้ครบโควตาของไฟต์นี้แล้ว"
	if _combatant != null and skill.kind != Skill.Kind.TOGGLE and _combatant.current_mana < skill.mana_cost:
		return "Mana ไม่พอ"
	return ""


func use(skill_id: String) -> bool:
	var skill := SkillDB.skill(skill_id)
	var reason := can_use(skill)
	if not reason.is_empty():
		skill_failed.emit(skill, reason)
		return false

	if skill.kind == Skill.Kind.TOGGLE:
		return _set_toggle(skill, not is_toggled(skill.id))

	if _combatant != null and not _combatant.spend_mana(skill.mana_cost):
		skill_failed.emit(skill, "Mana ไม่พอ")
		return false

	if skill.cooldown > 0.0:
		_set_cooldown(skill.id, skill.cooldown)
	if skill.uses_per_fight > 0:
		_uses_this_fight[skill.id] = int(_uses_this_fight.get(skill.id, 0)) + 1

	_apply_self_effect(skill)
	skill_activated.emit(skill)
	return true


## ผลที่ลงกับตัวผู้ใช้เองได้ทันที ผลที่ต้องเล็งเป้าปล่อยให้สัญญาณไปจัดการ
func _apply_self_effect(skill: Skill) -> void:
	if _combatant == null:
		return
	match skill.effect_kind():
		"heal":
			_combatant.heal(Formulas.skill_damage(skill.magnitude(), _combatant.sheet.final_stats().intellect))
		"shield":
			_combatant.add_shield(skill.magnitude())
			_self_buffs[skill.id] = skill.duration()
		"stat_buff":
			var stat := str(skill.effect.get("stat", "strength"))
			_combatant.sheet.temporary.add_stat(stat, skill.magnitude())
			_combatant.sheet.stats_changed.emit()
			_self_buffs[skill.id] = skill.duration()
		"cleanse_all":
			if _metabolism != null:
				for status in _metabolism.status_list():
					_metabolism.clear_status(status)
		"hp_for_power":
			var cost := _combatant.sheet.max_hp() * float(skill.effect.get("hp_cost_percent", 0.0))
			_combatant.set_hp(_combatant.current_hp - cost)
			_self_buffs[skill.id] = skill.duration()
		"revive":
			if not _combatant.is_alive:
				_combatant.restore_all()
				_combatant.set_hp(_combatant.sheet.max_hp() * skill.magnitude())


# --- Toggle ---

func is_toggled(skill_id: String) -> bool:
	return _active_toggles.has(skill_id)


func _set_toggle(skill: Skill, enabled: bool) -> bool:
	if enabled:
		_active_toggles[skill.id] = true
	else:
		_active_toggles.erase(skill.id)
	toggle_changed.emit(skill, enabled)
	return true


func _tick_toggles(delta: float) -> void:
	if _combatant == null:
		return
	for skill_id in _active_toggles.keys():
		var skill := SkillDB.skill(skill_id)
		if skill == null:
			continue
		if not _combatant.spend_mana(skill.mana_per_second * delta):
			_set_toggle(skill, false)


# --- คูลดาวน์และบัฟ ---

func remaining_cooldown(skill_id: String) -> float:
	return float(_cooldowns.get(skill_id, 0.0))


func _set_cooldown(skill_id: String, seconds: float) -> void:
	_cooldowns[skill_id] = seconds
	cooldown_changed.emit(skill_id, seconds)


func _tick_cooldowns(delta: float) -> void:
	for skill_id in _cooldowns.keys():
		var remaining := float(_cooldowns[skill_id]) - delta
		if remaining <= 0.0:
			_cooldowns.erase(skill_id)
			cooldown_changed.emit(skill_id, 0.0)
		else:
			_cooldowns[skill_id] = remaining


func _tick_self_buffs(delta: float) -> void:
	for skill_id in _self_buffs.keys():
		var remaining := float(_self_buffs[skill_id]) - delta
		if remaining > 0.0:
			_self_buffs[skill_id] = remaining
			continue
		_self_buffs.erase(skill_id)
		_expire_buff(SkillDB.skill(skill_id))


func _expire_buff(skill: Skill) -> void:
	if skill == null or _combatant == null:
		return
	match skill.effect_kind():
		"shield":
			_combatant.clear_shield()
		"stat_buff":
			_combatant.sheet.temporary.add_stat(str(skill.effect.get("stat", "strength")), -skill.magnitude())
			_combatant.sheet.stats_changed.emit()


# --- Passive ---

## รวมผลของสกิล Passive ที่มีอยู่ แล้วเขียนลง Combatant
func refresh_passives() -> void:
	if _combatant == null:
		return
	var reduction := 0.0
	var window_bonus := 0.0
	for skill in tree.passive_skills():
		match skill.effect_kind():
			"damage_reduction":
				reduction += skill.magnitude()
			"therapeutic_window_bonus":
				window_bonus += skill.magnitude()
	_combatant.damage_reduction = clampf(reduction, 0.0, 0.9)
	passive_window_bonus = window_bonus


var passive_window_bonus: float = 0.0


# --- รอบการต่อสู้ ---

func start_fight() -> void:
	_uses_this_fight.clear()


func end_fight() -> void:
	_uses_this_fight.clear()
	for skill_id in _active_toggles.keys():
		_set_toggle(SkillDB.skill(skill_id), false)


func learn(skill: Skill) -> bool:
	if _combatant == null:
		return false
	var learned := tree.learn(skill, _combatant.sheet.level)
	if learned:
		refresh_passives()
	return learned
