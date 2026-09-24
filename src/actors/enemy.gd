class_name Enemy
extends CharacterBody3D

## ศัตรู 1 ตัว ขับด้วย AI Archetype ตามตารางในหัวข้อ "ระบบศัตรูทั่วไป"
## ค่าพื้นฐานมาจาก data/enemies.json ส่วนพฤติกรรมมาจาก EnemyArchetype

signal died(enemy: Enemy)
signal loot_dropped(enemy: Enemy, drops: Array)
signal called_for_help(enemy: Enemy, responders: int)

enum State { IDLE, CHASE, WINDUP, ATTACK, FLEE, REPOSITION }

const TURN_SPEED := 8.0
const FLANK_DISTANCE := 3.0

@export var enemy_id: String = "feral_rootwolf"

@onready var combatant: Combatant = $Combatant
@onready var visuals: ActorVisuals = $Visuals

var definition: Dictionary = {}
var archetype: EnemyArchetype.Kind = EnemyArchetype.Kind.BRAWLER
var display_name: String = ""
var tier: String = "common"
var biome: String = "hub"
var zone_level: int = 1
var xp_reward: int = 40
var move_speed: float = 3.2

var _state: State = State.IDLE
var _target: Node3D
var _cooldown := 0.0
var _state_timer := 0.0
var _combo_left := 0
var _called_help := false
var _flank_offset := 0.0
var _killed_by_venom := false
var _root_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_definition()
	combatant.died.connect(_on_died)
	combatant.damage_taken.connect(func(_amount, _critical): visuals.play_state("hurt"))
	add_to_group("enemies")
	await get_tree().process_frame
	_apply_tier_stats()
	if EnemyArchetype.has_corruption_aura(tier, biome):
		CorruptionAura.attach_to(self)


func _load_definition() -> void:
	definition = EnemyDB.definition(enemy_id)
	display_name = str(definition.get("name", enemy_id))
	tier = str(definition.get("tier", "common"))
	biome = str(definition.get("biome", "hub"))
	zone_level = int(definition.get("zone_level", 1))
	xp_reward = int(definition.get("xp", 40))
	archetype = EnemyArchetype.from_key(str(definition.get("archetype", "brawler")))
	move_speed = EnemyArchetype.move_speed(archetype) * float(definition.get("speed_bonus", 1.0))
	_flank_offset = _pick_flank_offset()


## Pack Hunter ล้อมโจมตี 2 ทิศ จึงสุ่มมุมเข้าหาคนละข้างกัน
func _pick_flank_offset() -> float:
	if archetype != EnemyArchetype.Kind.PACK_HUNTER:
		return 0.0
	var angles: Array = EnemyArchetype.value(archetype, "flank_angles", [0.0])
	return float(angles[_rng.randi() % angles.size()])


## HP/ดาเมจมาจากตาราง Tier ไม่ใช่สูตร VIT ของผู้เล่น จึงคำนวณ VIT ย้อนกลับ
func _apply_tier_stats() -> void:
	var target_hp := Formulas.enemy_hp(EnemyArchetype.base_hp(tier), zone_level)
	var damage := Formulas.enemy_damage(EnemyArchetype.base_damage(tier), zone_level)
	combatant.weapon_base_damage = damage * float(definition.get("damage_bonus", 1.0))
	combatant.max_hp_override = target_hp
	combatant.restore_all()


func _physics_process(delta: float) -> void:
	if not combatant.is_alive:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_state_timer = maxf(_state_timer - delta, 0.0)
	_root_timer = maxf(_root_timer - delta, 0.0)
	_acquire_target()
	_apply_gravity(delta)

	if is_rooted():
		_halt()
		move_and_slide()
		visuals.update_locomotion(0.0)
		return

	if _target == null:
		_set_state(State.IDLE)
		_halt()
	else:
		_run_behaviour(delta)

	move_and_slide()
	visuals.update_locomotion(Vector2(velocity.x, velocity.z).length())


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 24.0) * delta
	else:
		velocity.y = 0.0


func _halt() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


# --- การเลือกเป้า ---

func _acquire_target() -> void:
	var aggro: float = EnemyArchetype.value(archetype, "aggro_range", 10.0)
	if _target != null and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position) <= aggro * 1.6:
			return
		_target = null

	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Node3D
		if player != null and global_position.distance_to(player.global_position) <= aggro:
			_target = player
			return


# --- พฤติกรรมแยกตาม Archetype ---

func _run_behaviour(delta: float) -> void:
	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()

	match archetype:
		EnemyArchetype.Kind.SKITTISH:
			_behave_skittish(distance, to_target, delta)
		EnemyArchetype.Kind.KITER:
			_behave_kiter(distance, to_target, delta)
		EnemyArchetype.Kind.PACK_HUNTER:
			_behave_pack_hunter(distance, to_target, delta)
		_:
			_behave_brawler(distance, to_target, delta)


## ขี้กลัว: หนีจนกว่า HP จะต่ำกว่าเกณฑ์ จนมุมแล้วสู้สวนแรงขึ้น
func _behave_skittish(distance: float, to_target: Vector3, delta: float) -> void:
	var hp_ratio := combatant.current_hp / maxf(combatant.max_hp(), 1.0)
	var desperate: float = EnemyArchetype.value(archetype, "desperate_hp_ratio", 0.2)
	var cornered_bonus: float = EnemyArchetype.value(archetype, "cornered_damage_bonus", 0.5)

	if hp_ratio > desperate:
		_set_state(State.FLEE)
		_move_along(-to_target.normalized(), delta)
		if is_cornered():
			_try_attack(distance, cornered_bonus)
		return

	_set_state(State.CHASE)
	_move_along(to_target.normalized(), delta)
	_try_attack(distance, cornered_bonus)


## บุกประชิด: พุ่งเข้าหาเป็นเส้นตรง มี windup ให้หลบ แล้วออกคอมโบ 2-3 ฮิต
func _behave_brawler(distance: float, to_target: Vector3, delta: float) -> void:
	var reach: float = EnemyArchetype.value(archetype, "attack_range", 2.2)

	if _state == State.WINDUP:
		_halt()
		_face(to_target, delta)
		if _state_timer <= 0.0:
			_combo_left = _rng.randi_range(
				int(EnemyArchetype.value(archetype, "combo_min", 2)),
				int(EnemyArchetype.value(archetype, "combo_max", 3))
			)
			_set_state(State.ATTACK)
		return

	if _state == State.ATTACK:
		_halt()
		_face(to_target, delta)
		if _state_timer > 0.0:
			return
		if _combo_left > 0 and distance <= reach * 1.4:
			_strike()
			_combo_left -= 1
			_state_timer = EnemyArchetype.value(archetype, "combo_gap", 0.35)
			return
		_cooldown = EnemyArchetype.value(archetype, "attack_cooldown", 1.6)
		_set_state(State.CHASE)
		return

	if distance > reach:
		_set_state(State.CHASE)
		_move_along(to_target.normalized(), delta)
		return

	_halt()
	_face(to_target, delta)
	if _cooldown <= 0.0:
		_set_state(State.WINDUP)
		_state_timer = EnemyArchetype.value(archetype, "windup", 0.55)


## Kiter: รักษาระยะ 8-12m ถอยเมื่อผู้เล่นเข้าใกล้กว่า 5m
func _behave_kiter(distance: float, to_target: Vector3, delta: float) -> void:
	var retreat: float = EnemyArchetype.value(archetype, "retreat_range", 5.0)
	var preferred_min: float = EnemyArchetype.value(archetype, "preferred_min", 8.0)
	var preferred_max: float = EnemyArchetype.value(archetype, "preferred_max", 12.0)

	if _state == State.WINDUP:
		_halt()
		_face(to_target, delta)
		if _state_timer <= 0.0:
			_strike()
			_cooldown = EnemyArchetype.value(archetype, "attack_cooldown", 2.2)
			_set_state(State.REPOSITION)
		return

	if distance < retreat:
		_set_state(State.FLEE)
		_move_along(-to_target.normalized(), delta)
		return

	if distance > preferred_max:
		_set_state(State.CHASE)
		_move_along(to_target.normalized(), delta)
		return

	_halt()
	_face(to_target, delta)
	if distance >= preferred_min and _cooldown <= 0.0:
		_set_state(State.WINDUP)
		_state_timer = EnemyArchetype.value(archetype, "windup", 0.7)
	elif distance < preferred_min:
		_set_state(State.REPOSITION)
		_move_along(-to_target.normalized(), delta * 0.6)


## ฝูง: เข้าหาเป็นมุมเฉียงเพื่อล้อม และเรียกพวกเมื่อ HP ต่ำกว่าครึ่ง
func _behave_pack_hunter(distance: float, to_target: Vector3, delta: float) -> void:
	var hp_ratio := combatant.current_hp / maxf(combatant.max_hp(), 1.0)
	if not _called_help and hp_ratio < EnemyArchetype.value(archetype, "call_hp_ratio", 0.5):
		call_for_help()

	var reach: float = EnemyArchetype.value(archetype, "attack_range", 2.0)
	if distance > reach:
		_set_state(State.CHASE)
		var approach := to_target.normalized()
		if distance > FLANK_DISTANCE:
			approach = approach.rotated(Vector3.UP, _flank_offset)
		_move_along(approach, delta)
		return

	_halt()
	_face(to_target, delta)
	_try_attack(distance, 0.0)


## เรียกพวกในรัศมีให้หันมาสนใจเป้าเดียวกัน
func call_for_help() -> int:
	_called_help = true
	var radius: float = EnemyArchetype.value(archetype, "call_radius", 20.0)
	var responders := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other == null or other == self or not other.combatant.is_alive:
			continue
		if global_position.distance_to(other.global_position) > radius:
			continue
		other.aggro_onto(_target)
		responders += 1
	called_for_help.emit(self, responders)
	return responders


func aggro_onto(target: Node3D) -> void:
	if target != null:
		_target = target


# --- การโจมตี ---

func _try_attack(distance: float, damage_bonus: float) -> void:
	var reach: float = EnemyArchetype.value(archetype, "attack_range", 2.2)
	if distance > reach or _cooldown > 0.0:
		return
	_cooldown = EnemyArchetype.value(archetype, "attack_cooldown", 1.5)
	_strike(damage_bonus)


func _strike(damage_bonus: float = 0.0) -> void:
	if _target == null:
		return
	var target_combatant: Combatant = _target.get_node_or_null("Combatant")
	if target_combatant == null:
		return
	visuals.play_state("attack")
	var power := combatant.weapon_base_damage * (1.0 + damage_bonus)
	var result := combatant.attack(target_combatant, CombatMath.AttackKind.PHYSICAL, power)

	var lifesteal := float(definition.get("lifesteal", 0.0))
	if lifesteal > 0.0 and not result.is_empty():
		combatant.heal(float(result.get("damage", 0.0)) * lifesteal)

	var status := str(definition.get("applies_status", ""))
	if not status.is_empty():
		var metabolism := _target.get_node_or_null("Metabolism") as Metabolism
		if metabolism != null:
			metabolism.apply_status(status)


## ติดอยู่กับที่ทั้งที่พยายามหนี = จนมุม
func is_cornered() -> bool:
	return _state == State.FLEE and Vector2(velocity.x, velocity.z).length() < 0.5


func mark_killed_by_venom() -> void:
	_killed_by_venom = true


## ถูกตรึงกับพื้น ขยับไม่ได้แต่ยังเสียดาเมจได้ตามปกติ
func apply_root(seconds: float) -> void:
	_root_timer = maxf(_root_timer, seconds)


func is_rooted() -> bool:
	return _root_timer > 0.0


# --- การเคลื่อนที่ ---

func _move_along(direction: Vector3, delta: float) -> void:
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_face(direction, delta)


func _face(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), TURN_SPEED * delta)


func _set_state(new_state: State) -> void:
	_state = new_state


func current_state() -> State:
	return _state


# --- ตาย ---

func _on_died() -> void:
	var drops := LootTable.roll(tier, biome, zone_level, _killed_by_venom, _rng)
	loot_dropped.emit(self, drops)
	died.emit(self)
	set_physics_process(false)
	$CollisionShape3D.set_deferred("disabled", true)
	var aura := get_node_or_null("CorruptionAura")
	if aura != null:
		aura.queue_free()
	visuals.play_state("die")
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(self, "position:y", position.y - 2.0, 0.6)
	tween.tween_callback(queue_free)
