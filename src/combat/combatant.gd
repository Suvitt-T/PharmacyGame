class_name Combatant
extends Node

## Component เก็บสถานะการต่อสู้ปัจจุบัน (HP/Mana/Stamina) ของ actor 1 ตัว
## ใช้ร่วมกันได้ทั้ง Player, Enemy และ Companion NPC ที่จะเพิ่มใน Phase ถัดไป

signal hp_changed(current: float, maximum: float)
signal mana_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal damage_taken(amount: float, critical: bool)
signal attack_evaded()
signal died()
signal revived()
signal shield_changed(current: float)

## ไม่ระบุในเอกสาร ตัดสินใจเอง: HP ไม่ฟื้นเอง ต้องพึ่งยา/สกิล ตามแก่นเกมเภสัชกรรม
const MANA_REGEN_PER_SECOND_RATIO := 0.015
const STAMINA_REGEN_PER_SECOND := 14.0
const STAMINA_REGEN_DELAY := 0.8

@export var is_player: bool = false
@export var starting_level: int = 1
@export var character_class: CharacterClass.Id = CharacterClass.Id.NONE

@export var weapon_base_damage: float = 12.0
@export var defense: float = 0.0

## ศัตรูใช้ HP จากตาราง Tier ตรง ๆ ไม่ผ่านสูตร VIT ของผู้เล่น
## เพราะสูตร HP = 80 + VIT*8 + Lv*5 มีพื้นต่ำสุด 125 จึงทำ HP 60 ตามตารางไม่ได้
## ค่า 0 แปลว่าใช้สูตรปกติ
@export var max_hp_override: float = 0.0

var sheet: CharacterSheet
var current_hp: float = 0.0
var current_mana: float = 0.0
var current_stamina: float = 0.0
## เกราะดูดซับดาเมจจากสกิล เช่น เกราะรากไม้ของนักรบพฤกษา
var shield_points: float = 0.0
## ลดดาเมจที่ได้รับทุกชนิด มาจากสกิล passive และ prop อื่น ๆ (0.0 - 0.9)
var damage_reduction: float = 0.0
var is_alive: bool = true

var _rng := RandomNumberGenerator.new()
var _stamina_idle_time: float = 0.0


func _ready() -> void:
	_rng.randomize()
	if sheet == null:
		sheet = CharacterSheet.new(starting_level)
		sheet.class_id = character_class
	sheet.stats_changed.connect(_on_stats_changed)
	sheet.leveled_up.connect(_on_leveled_up)
	restore_all()


func _process(delta: float) -> void:
	if not is_alive:
		return
	_regenerate(delta)


func _regenerate(delta: float) -> void:
	var mana_max := sheet.max_mana()
	if current_mana < mana_max:
		set_mana(current_mana + mana_max * MANA_REGEN_PER_SECOND_RATIO * delta)

	_stamina_idle_time += delta
	if _stamina_idle_time >= STAMINA_REGEN_DELAY:
		var stamina_max := sheet.max_stamina()
		if current_stamina < stamina_max:
			set_stamina(current_stamina + STAMINA_REGEN_PER_SECOND * delta)


## HP สูงสุดจริง เคารพ override ของศัตรูก่อนเสมอ
func max_hp() -> float:
	return max_hp_override if max_hp_override > 0.0 else sheet.max_hp()


func restore_all() -> void:
	var was_dead := not is_alive
	current_hp = max_hp()
	current_mana = sheet.max_mana()
	current_stamina = sheet.max_stamina()
	is_alive = true
	shield_points = 0.0
	emit_all()
	if was_dead:
		revived.emit()


# --- ทรัพยากร ---

func set_hp(value: float) -> void:
	current_hp = clampf(value, 0.0, max_hp())
	hp_changed.emit(current_hp, max_hp())
	if current_hp <= 0.0 and is_alive:
		is_alive = false
		died.emit()


func set_mana(value: float) -> void:
	current_mana = clampf(value, 0.0, sheet.max_mana())
	mana_changed.emit(current_mana, sheet.max_mana())


func set_stamina(value: float) -> void:
	current_stamina = clampf(value, 0.0, sheet.max_stamina())
	stamina_changed.emit(current_stamina, sheet.max_stamina())


func heal(amount: float) -> void:
	if not is_alive or amount <= 0.0:
		return
	set_hp(current_hp + amount)


func spend_mana(amount: float) -> bool:
	if current_mana < amount:
		return false
	set_mana(current_mana - amount)
	return true


func spend_stamina(amount: float) -> bool:
	if current_stamina < amount:
		return false
	set_stamina(current_stamina - amount)
	_stamina_idle_time = 0.0
	return true


# --- การต่อสู้ ---

func attack(target: Combatant, kind: CombatMath.AttackKind = CombatMath.AttackKind.PHYSICAL, base_power: float = -1.0) -> Dictionary:
	if target == null or not target.is_alive:
		return {}
	var power := base_power if base_power >= 0.0 else weapon_base_damage
	var result := CombatMath.resolve(
		kind, power, sheet.final_stats(), target.sheet.final_stats(), target.defense, _rng
	)
	target.apply_attack_result(result)
	return result


func apply_attack_result(result: Dictionary) -> void:
	if not is_alive:
		return
	if result.get("evaded", false):
		attack_evaded.emit()
		return
	var amount := float(result.get("damage", 0.0)) * (1.0 - clampf(damage_reduction, 0.0, 0.9))
	amount = _absorb_with_shield(amount)
	if amount <= 0.0:
		return
	set_hp(current_hp - amount)
	damage_taken.emit(amount, bool(result.get("critical", false)))


## เกราะกินดาเมจก่อน ที่เหลือจึงลง HP
func _absorb_with_shield(amount: float) -> float:
	if shield_points <= 0.0:
		return amount
	var absorbed := minf(shield_points, amount)
	shield_points -= absorbed
	shield_changed.emit(shield_points)
	return amount - absorbed


func add_shield(amount: float) -> void:
	shield_points = maxf(shield_points + amount, 0.0)
	shield_changed.emit(shield_points)


func clear_shield() -> void:
	shield_points = 0.0
	shield_changed.emit(shield_points)


func _on_stats_changed() -> void:
	set_hp(current_hp)
	set_mana(current_mana)
	set_stamina(current_stamina)


func _on_leveled_up(_new_level: int) -> void:
	restore_all()


func emit_all() -> void:
	hp_changed.emit(current_hp, max_hp())
	mana_changed.emit(current_mana, sheet.max_mana())
	stamina_changed.emit(current_stamina, sheet.max_stamina())
