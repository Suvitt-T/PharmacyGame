class_name InputActions
extends RefCounted

## ลงทะเบียน input action ด้วยโค้ด แทนการฝัง event blob ลง project.godot
## แก้ปุ่มได้ที่เดียว และ diff ใน git อ่านรู้เรื่อง

const MOVE_FORWARD := "move_forward"
const MOVE_BACK := "move_back"
const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const ATTACK := "attack"
const SPRINT := "sprint"
const DODGE := "dodge"

const BINDINGS := {
	MOVE_FORWARD: [KEY_W, KEY_UP],
	MOVE_BACK: [KEY_S, KEY_DOWN],
	MOVE_LEFT: [KEY_A, KEY_LEFT],
	MOVE_RIGHT: [KEY_D, KEY_RIGHT],
	SPRINT: [KEY_SHIFT],
	DODGE: [KEY_SPACE],
}

const MOUSE_BINDINGS := {
	ATTACK: [MOUSE_BUTTON_LEFT],
}

## ปุ่มดีบักสำหรับเทสต์ระบบเลเวลระหว่างพัฒนา
const DEBUG_BINDINGS := {
	"debug_add_xp": [KEY_X],
	"debug_damage_self": [KEY_C],
	"debug_respec": [KEY_R],
	"remedy_1": [KEY_1],
	"remedy_2": [KEY_2],
	"remedy_3": [KEY_3],
	"remedy_4": [KEY_4],
	"remedy_5": [KEY_5],
}

static var _registered := false


static func ensure_registered() -> void:
	if _registered:
		return
	_registered = true
	var all_keys := {}
	all_keys.merge(BINDINGS)
	all_keys.merge(DEBUG_BINDINGS)

	for action in all_keys:
		_add_action(action)
		for keycode in all_keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)

	for action in MOUSE_BINDINGS:
		_add_action(action)
		for button in MOUSE_BINDINGS[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)


static func _add_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	else:
		InputMap.action_erase_events(action)
