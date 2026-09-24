class_name SkillExecutor
extends Node

## ลงผลของสกิลที่ต้องเล็งเป้าหรือกินพื้นที่ ซึ่ง SkillRuntime ทำเองไม่ได้
## เพราะ SkillRuntime ไม่รู้จักฉากหรือศัตรู มันแค่ตรวจ Mana/คูลดาวน์แล้วยิงสัญญาณออกมา
##
## ตัวนี้คือผู้รับสัญญาณนั้น แปลงเป็นดาเมจจริง พร้อมเอฟเฟกต์ที่ผู้เล่นมองเห็น

signal skill_resolved(skill: Skill, hits: int, total_damage: float)

## รัศมีเริ่มต้นของสกิลเป้าเดี่ยว ใช้หาเป้าที่อยู่ตรงหน้า
const SINGLE_TARGET_RANGE := 6.0
const DEFAULT_DOT_DURATION := 8.0

@export var runtime_path: NodePath = NodePath("../SkillRuntime")
@export var combatant_path: NodePath = NodePath("../Combatant")

var _runtime: SkillRuntime
var _combatant: Combatant
var _owner_body: Node3D
var _aura_timer := 0.0


func _ready() -> void:
	_owner_body = get_parent() as Node3D
	_runtime = get_node_or_null(runtime_path) as SkillRuntime
	_combatant = get_node_or_null(combatant_path) as Combatant
	if _runtime != null:
		_runtime.skill_activated.connect(_on_skill_activated)
	if _combatant != null:
		_combatant.damage_taken.connect(_on_owner_damaged)


func _process(delta: float) -> void:
	_tick_damage_auras(delta)


# --- จุดเข้าหลัก ---

func _on_skill_activated(skill: Skill) -> void:
	match skill.effect_kind():
		"skill_damage":
			_area_damage(skill)
		"apply_dot":
			_single_target_dot(skill)
		"execute_dot":
			_execute(skill)
		"spreading_aoe_dot":
			_area_dot(skill)
		"root":
			_root_area(skill)
		"dash_attack":
			_dash_attack(skill)
		"convert_to_aoe", "craft_zone", "instant_craft", "potency_buff":
			_show_support_ring(skill)
		"heal", "shield", "team_regen", "team_shield", "team_status_resistance", "regen_aura":
			_show_support_ring(skill)
		"reveal_vitals", "reveal_weakness":
			_reveal(skill)


# --- การหาเป้า ---

func _enemies_within(radius: float) -> Array:
	var found := []
	if _owner_body == null:
		return found
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.combatant.is_alive:
			continue
		if _owner_body.global_position.distance_to(enemy.global_position) <= radius:
			found.append(enemy)
	return found


## เป้าที่ใกล้ที่สุดในระยะ ใช้กับสกิลเป้าเดี่ยว
func _nearest_enemy(radius: float) -> Enemy:
	var best: Enemy = null
	var best_distance := radius
	for enemy in _enemies_within(radius):
		var distance: float = _owner_body.global_position.distance_to((enemy as Enemy).global_position)
		if distance <= best_distance:
			best_distance = distance
			best = enemy
	return best


# --- ผลแต่ละแบบ ---

func _area_damage(skill: Skill) -> void:
	var radius: float = skill.radius() if skill.radius() > 0.0 else SINGLE_TARGET_RANGE
	SkillBurst.spawn(_owner_body, radius, "offensive")
	var total := 0.0
	var hits := 0
	for node in _enemies_within(radius):
		var enemy := node as Enemy
		total += _strike(enemy, skill.magnitude())
		hits += 1
	skill_resolved.emit(skill, hits, total)


func _single_target_dot(skill: Skill) -> void:
	var target := _nearest_enemy(SINGLE_TARGET_RANGE)
	if target == null:
		skill_resolved.emit(skill, 0, 0.0)
		return
	SkillBurst.spawn_line(_owner_body, target, "offensive")
	var damage := _strike(target, skill.magnitude())
	_apply_enemy_status(target, "venom", _dot_seconds(skill))
	skill_resolved.emit(skill, 1, damage)


## อัดทั้งหมดลงเป้าที่ HP น้อยที่สุด เพื่อให้ Ultimate ของสายเฉียบพลันเก็บเป้าได้จริง
func _execute(skill: Skill) -> void:
	var candidates := _enemies_within(SINGLE_TARGET_RANGE * 1.5)
	if candidates.is_empty():
		skill_resolved.emit(skill, 0, 0.0)
		return
	var weakest: Enemy = candidates[0]
	for node in candidates:
		var enemy := node as Enemy
		if enemy.combatant.current_hp < weakest.combatant.current_hp:
			weakest = enemy
	SkillBurst.spawn_line(_owner_body, weakest, "offensive")
	var damage := _strike(weakest, skill.magnitude())
	skill_resolved.emit(skill, 1, damage)


func _area_dot(skill: Skill) -> void:
	var radius: float = skill.radius() if skill.radius() > 0.0 else SINGLE_TARGET_RANGE
	SkillBurst.spawn(_owner_body, radius, "offensive")
	var hits := 0
	var total := 0.0
	for node in _enemies_within(radius):
		var enemy := node as Enemy
		total += _strike(enemy, skill.magnitude() * 0.5)
		_apply_enemy_status(enemy, "venom", _dot_seconds(skill))
		hits += 1
	skill_resolved.emit(skill, hits, total)


func _root_area(skill: Skill) -> void:
	var radius: float = skill.radius() if skill.radius() > 0.0 else SINGLE_TARGET_RANGE
	SkillBurst.spawn(_owner_body, radius, "control")
	var hits := 0
	for node in _enemies_within(radius):
		var enemy := node as Enemy
		enemy.apply_root(skill.duration())
		DamageNumber.spawn_text(_owner_body, enemy.global_position + Vector3.UP * 1.6, "ตรึง", "status")
		hits += 1
	skill_resolved.emit(skill, hits, 0.0)


func _dash_attack(skill: Skill) -> void:
	var distance := float(skill.effect.get("distance", 8.0))
	var target := _nearest_enemy(distance)
	if target != null and _owner_body is CharacterBody3D:
		var direction := (target.global_position - _owner_body.global_position).normalized()
		_owner_body.global_position = target.global_position - direction * 1.6
	SkillBurst.spawn(_owner_body, 2.5, "offensive")
	if target == null:
		skill_resolved.emit(skill, 0, 0.0)
		return
	var damage := _strike(target, skill.magnitude())
	skill_resolved.emit(skill, 1, damage)


func _show_support_ring(skill: Skill) -> void:
	var radius: float = skill.radius() if skill.radius() > 0.0 else 2.5
	SkillBurst.spawn(_owner_body, radius, "support")
	skill_resolved.emit(skill, 0, 0.0)


## สกิลสแกน แสดง HP จริงของศัตรูรอบตัวให้เห็นเป็นตัวเลข
func _reveal(skill: Skill) -> void:
	var radius: float = skill.radius() if skill.radius() > 0.0 else 14.0
	SkillBurst.spawn(_owner_body, radius, "control")
	var hits := 0
	for node in _enemies_within(radius):
		var enemy := node as Enemy
		DamageNumber.spawn_text(
			_owner_body, enemy.global_position + Vector3.UP * 2.0,
			"%d/%d" % [roundi(enemy.combatant.current_hp), roundi(enemy.combatant.max_hp())],
			"skill"
		)
		hits += 1
	skill_resolved.emit(skill, hits, 0.0)


# --- Toggle ที่ทำงานต่อเนื่อง ---

func _tick_damage_auras(delta: float) -> void:
	if _runtime == null:
		return
	_aura_timer -= delta
	if _aura_timer > 0.0:
		return
	_aura_timer = 1.0

	for skill in _runtime.tree.active_skills():
		if skill.effect_kind() != "aura_dot" or not _runtime.is_toggled(skill.id):
			continue
		var radius: float = skill.radius()
		SkillBurst.spawn(_owner_body, radius, "offensive")
		for node in _enemies_within(radius):
			_strike(node as Enemy, skill.magnitude())


## หนามป้องกัน: สะท้อนดาเมจกลับไปหาคนตี
func _on_owner_damaged(amount: float, _critical: bool) -> void:
	if _runtime == null or _combatant == null:
		return
	for skill in _runtime.tree.active_skills():
		if skill.effect_kind() != "reflect_damage" or not _runtime.is_toggled(skill.id):
			continue
		var reflected: float = amount * skill.magnitude()
		for node in _enemies_within(3.0):
			var enemy := node as Enemy
			enemy.combatant.apply_attack_result({"damage": reflected, "evaded": false, "critical": false})
			DamageNumber.spawn(_owner_body, enemy.global_position + Vector3.UP * 1.6, reflected, "skill")
			break


# --- ตัวช่วย ---

## ดาเมจสกิลใช้สูตร SkillDMG = SkillBase x (1 + INT x 0.025) ตามเอกสาร
func _strike(enemy: Enemy, base_power: float) -> float:
	if enemy == null or _combatant == null:
		return 0.0
	var result := _combatant.attack(enemy.combatant, CombatMath.AttackKind.SKILL, base_power)
	if result.is_empty():
		return 0.0
	if result.get("evaded", false):
		DamageNumber.spawn(_owner_body, enemy.global_position + Vector3.UP * 1.6, 0.0, "miss")
		return 0.0
	var damage := float(result["damage"])
	DamageNumber.spawn(
		_owner_body, enemy.global_position + Vector3.UP * 1.6, damage,
		"critical" if result.get("critical", false) else "skill"
	)
	return damage


func _dot_seconds(skill: Skill) -> float:
	return skill.duration() if skill.duration() > 0.0 else DEFAULT_DOT_DURATION


func _apply_enemy_status(enemy: Enemy, status: String, seconds: float) -> void:
	var metabolism := enemy.get_node_or_null("Metabolism") as Metabolism
	if metabolism != null:
		metabolism.apply_status(status, seconds)
	DamageNumber.spawn_text(_owner_body, enemy.global_position + Vector3.UP * 2.0, Metabolism.status_name(status), "status")
