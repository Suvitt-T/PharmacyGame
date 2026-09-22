class_name PlayerController
extends CharacterBody3D

## การเคลื่อนที่ + โจมตีเบา แบบ 2.5D: กล้องมุมคงที่ ทิศทางเดินอิงแกนโลก

signal attacked(hits: int)

const WALK_SPEED := 5.0
const SPRINT_MULTIPLIER := 1.7
const SPRINT_STAMINA_PER_SECOND := 18.0
const ACCELERATION := 14.0
const TURN_SPEED := 12.0
const DODGE_SPEED := 12.0
const DODGE_DURATION := 0.22
const DODGE_STAMINA_COST := 22.0

const ATTACK_WINDUP := 0.12
const ATTACK_ACTIVE := 0.10
const ATTACK_RECOVERY := 0.28

@onready var combatant: Combatant = $Combatant
@onready var hitbox: Area3D = $AttackHitbox

var _facing := Vector3.FORWARD
var _dodge_time := 0.0
var _attack_time := 0.0
var _attack_state := "idle"
var _already_hit: Array[Combatant] = []


func _ready() -> void:
	InputActions.ensure_registered()
	combatant.is_player = true
	hitbox.monitoring = false


func _physics_process(delta: float) -> void:
	if not combatant.is_alive:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_tick_attack(delta)
	_apply_gravity(delta)

	if _dodge_time > 0.0:
		_dodge_time -= delta
		velocity.x = _facing.x * DODGE_SPEED
		velocity.z = _facing.z * DODGE_SPEED
	else:
		_handle_movement(delta)

	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 24.0) * delta
	else:
		velocity.y = 0.0


func _handle_movement(delta: float) -> void:
	var input := Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_FORWARD, InputActions.MOVE_BACK
	)
	var direction := Vector3(input.x, 0.0, input.y)
	if direction.length() > 1.0:
		direction = direction.normalized()

	var speed := WALK_SPEED
	if Input.is_action_pressed(InputActions.SPRINT) and direction.length() > 0.1:
		if combatant.spend_stamina(SPRINT_STAMINA_PER_SECOND * delta):
			speed *= SPRINT_MULTIPLIER

	if _attack_state != "idle":
		speed *= 0.25

	var target_velocity := direction * speed
	velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta * 10.0)
	velocity.z = move_toward(velocity.z, target_velocity.z, ACCELERATION * delta * 10.0)

	if direction.length() > 0.1:
		_facing = direction.normalized()
		var target_angle := atan2(_facing.x, _facing.z)
		rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not combatant.is_alive:
		return
	if event.is_action_pressed(InputActions.ATTACK):
		_start_attack()
	elif event.is_action_pressed(InputActions.DODGE):
		_start_dodge()


func _start_dodge() -> void:
	if _dodge_time > 0.0 or _attack_state != "idle":
		return
	if not combatant.spend_stamina(DODGE_STAMINA_COST):
		return
	_dodge_time = DODGE_DURATION


func _start_attack() -> void:
	if _attack_state != "idle" or _dodge_time > 0.0:
		return
	_attack_state = "windup"
	_attack_time = ATTACK_WINDUP
	_already_hit.clear()


func _tick_attack(delta: float) -> void:
	if _attack_state == "idle":
		return
	_attack_time -= delta
	if _attack_time > 0.0:
		if _attack_state == "active":
			_scan_hitbox()
		return

	match _attack_state:
		"windup":
			_attack_state = "active"
			_attack_time = ATTACK_ACTIVE
			hitbox.monitoring = true
		"active":
			_attack_state = "recovery"
			_attack_time = ATTACK_RECOVERY
			hitbox.monitoring = false
			attacked.emit(_already_hit.size())
		"recovery":
			_attack_state = "idle"
			_attack_time = 0.0


func _scan_hitbox() -> void:
	for body in hitbox.get_overlapping_bodies():
		var target: Combatant = body.get_node_or_null("Combatant")
		if target == null or target in _already_hit or not target.is_alive:
			continue
		_already_hit.append(target)
		combatant.attack(target)
