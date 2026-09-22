class_name Enemy
extends CharacterBody3D

## ศัตรูพื้นฐานสำหรับทดสอบลูปการต่อสู้ใน Phase 1
## Phase 5 จะแทนด้วย AI Archetype 4 แบบ + Corruption Aura ตามเอกสาร

signal died(enemy: Enemy)

@export var display_name: String = "หมาป่าเถื่อน"
@export var tier: String = "common"
@export var zone_level: int = 1
@export var aggro_range: float = 12.0
@export var attack_range: float = 2.2
@export var move_speed: float = 3.2
@export var attack_cooldown: float = 1.6
@export var xp_reward: int = 40

const TIER_BASE := {
	"common": {"hp": 60.0, "damage": 8.0},
	"elite": {"hp": 250.0, "damage": 20.0},
	"miniboss": {"hp": 800.0, "damage": 35.0},
}

@onready var combatant: Combatant = $Combatant

var _target: Node3D
var _cooldown := 0.0


func _ready() -> void:
	var base: Dictionary = TIER_BASE.get(tier, TIER_BASE["common"])
	combatant.weapon_base_damage = Formulas.enemy_damage(float(base["damage"]), zone_level)
	combatant.died.connect(_on_died)
	await get_tree().process_frame
	_scale_hp_to_tier(float(base["hp"]))


## HP ของศัตรูมาจากตาราง Tier ไม่ใช่สูตร VIT ของตัวละครผู้เล่น
## จึงคำนวณ VIT ย้อนกลับจาก HP เป้าหมาย เพื่อใช้ Combatant ตัวเดียวกันได้ทั้งสองฝั่ง
func _scale_hp_to_tier(base_hp: float) -> void:
	var target_hp := Formulas.enemy_hp(base_hp, zone_level)
	var implied_vitality := (target_hp - 80.0 - float(combatant.sheet.level) * 5.0) / 8.0
	combatant.sheet.allocated.vitality = maxf(implied_vitality - CharacterSheet.BASE_STAT_VALUE, 0.0)
	combatant.restore_all()


func _physics_process(delta: float) -> void:
	if not combatant.is_alive:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_acquire_target()

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 24.0) * delta
	else:
		velocity.y = 0.0

	if _target == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()

	if distance > attack_range:
		var direction := to_target.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 8.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _cooldown <= 0.0:
			_cooldown = attack_cooldown
			var target_combatant: Combatant = _target.get_node_or_null("Combatant")
			if target_combatant != null:
				combatant.attack(target_combatant)

	move_and_slide()


func _acquire_target() -> void:
	if _target != null and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position) <= aggro_range * 1.5:
			return
		_target = null

	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Node3D
		if player != null and global_position.distance_to(player.global_position) <= aggro_range:
			_target = player
			return


func _on_died() -> void:
	died.emit(self)
	set_physics_process(false)
	$CollisionShape3D.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.4)
	tween.tween_callback(queue_free)
