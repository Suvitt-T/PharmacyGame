extends SceneTree

## เครื่องมือ dev: เปิดซีนหลัก รอให้ฉากเดินไประยะหนึ่ง แล้วบันทึกภาพหน้าจอ
## รัน: godot --resolution 1280x720 --script res://tools/capture_screenshot.gd -- <frames> <output.png>

const DEFAULT_FRAMES := 420
const DEFAULT_OUTPUT := "user://capture.png"

var _frames := 0
var _target_frames := DEFAULT_FRAMES
var _output := DEFAULT_OUTPUT


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_target_frames = int(args[0])
	if args.size() > 1:
		_output = args[1]
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _target_frames:
		return false
	var error := root.get_texture().get_image().save_png(_output)
	if error != OK:
		push_error("บันทึกภาพไม่สำเร็จ: %s" % _output)
	else:
		print("บันทึกภาพแล้ว: %s" % _output)
	return true
