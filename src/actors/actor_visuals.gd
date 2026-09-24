class_name ActorVisuals
extends Node3D

## ผูกสถานะของ actor เข้ากับ animation ของโมเดล glTF
## แยกออกมาเป็น Node ต่างหาก เพื่อให้เปลี่ยนโมเดลได้โดยไม่แตะโค้ดการต่อสู้

## ชุด animation ของ Quaternius ทุกตัวในแพ็กใช้ชื่อเดียวกันหมด
const STATE_ANIMATION := {
	"idle": "Idle",
	"walk": "Walk",
	"run": "Run",
	"attack": "Punch",
	"hurt": "HitReact",
	"dodge": "Jump",
	"die": "Death",
	## ท่าสกิล แยกจากท่าตีปกติเพื่อให้ผู้เล่นแยกออกว่ากดอะไรไป
	"skill_attack": "Weapon",
	"cast": "Wave",
}

## สถานะที่เล่นจบแล้วกลับไปสถานะการเคลื่อนที่เอง
const ONE_SHOT_STATES := ["attack", "hurt", "dodge", "skill_attack", "cast"]

const WALK_THRESHOLD := 0.2
const RUN_THRESHOLD := 6.0

@export var model_scene: PackedScene
@export var model_scale: float = 0.6
@export var model_yaw_degrees: float = 0.0

var _animation_player: AnimationPlayer
var _state: String = ""
var _locomotion_state: String = "idle"
var _is_dead: bool = false


func _ready() -> void:
	if model_scene == null:
		return
	var model := model_scene.instantiate()
	add_child(model)
	model.scale = Vector3.ONE * model_scale
	model.rotation_degrees.y = model_yaw_degrees

	_animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animation_player == null:
		push_warning("โมเดลไม่มี AnimationPlayer: %s" % model_scene.resource_path)
		return
	_animation_player.animation_finished.connect(_on_animation_finished)
	_enable_looping()
	play_state("idle")


## glTF importer ไม่ตั้ง loop ให้ ต้องเปิดเองไม่งั้น idle/walk/run เล่นรอบเดียวแล้วค้าง
func _enable_looping() -> void:
	for state in ["idle", "walk", "run"]:
		var animation_name: String = STATE_ANIMATION[state]
		if _animation_player.has_animation(animation_name):
			_animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR


## เลือก idle/walk/run จากความเร็วแนวราบ
func update_locomotion(horizontal_speed: float) -> void:
	if horizontal_speed >= RUN_THRESHOLD:
		_locomotion_state = "run"
	elif horizontal_speed >= WALK_THRESHOLD:
		_locomotion_state = "walk"
	else:
		_locomotion_state = "idle"

	if _state in ONE_SHOT_STATES or _is_dead:
		return
	play_state(_locomotion_state)


func play_state(state: String, blend_time: float = 0.12) -> void:
	if _animation_player == null or _is_dead:
		return
	if state == _state:
		return
	var animation_name: String = STATE_ANIMATION.get(state, "")
	if animation_name.is_empty() or not _animation_player.has_animation(animation_name):
		return
	_state = state
	if state == "die":
		_is_dead = true
	_animation_player.play(animation_name, blend_time)


func revive() -> void:
	_is_dead = false
	_state = ""
	play_state("idle", 0.25)


func _on_animation_finished(_animation_name: StringName) -> void:
	if _is_dead:
		return
	if _state in ONE_SHOT_STATES:
		_state = ""
		play_state(_locomotion_state)
