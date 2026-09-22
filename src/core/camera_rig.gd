class_name CameraRig
extends Node3D

## กล้อง 2.5D มุมคงที่ ตามตัวละครแบบหน่วง ไม่หมุนตามการหันของผู้เล่น

@export var target_path: NodePath
@export var follow_speed: float = 7.0
@export var offset := Vector3(0.0, 11.0, 9.0)
@export var look_height_offset: float = 1.2

@onready var camera: Camera3D = $Camera3D

var _target: Node3D


func _ready() -> void:
	if target_path.is_empty():
		return
	_target = get_node_or_null(target_path) as Node3D
	if _target != null:
		global_position = _target.global_position + offset
		_aim()


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var desired := _target.global_position + offset
	global_position = global_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
	_aim()


func _aim() -> void:
	if _target == null:
		return
	var focus := _target.global_position + Vector3.UP * look_height_offset
	camera.look_at(focus, Vector3.UP)
