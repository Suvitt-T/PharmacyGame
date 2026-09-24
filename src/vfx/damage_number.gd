class_name DamageNumber
extends Label3D

## ตัวเลขดาเมจลอยขึ้นเหนือเป้าหมาย เป็นสัญญาณหลักที่บอกผู้เล่นว่าโจมตีเข้าจริง

const RISE_HEIGHT := 1.6
const LIFETIME := 0.9
const SPREAD := 0.45

const COLOR_NORMAL := Color(1.0, 0.94, 0.85)
const COLOR_CRITICAL := Color(1.0, 0.72, 0.25)
const COLOR_SKILL := Color(0.72, 0.86, 1.0)
const COLOR_HEAL := Color(0.55, 0.95, 0.60)
const COLOR_STATUS := Color(0.78, 0.55, 0.95)
const COLOR_MISS := Color(0.75, 0.75, 0.75)


static func spawn(parent: Node3D, world_position: Vector3, amount: float, style: String = "normal") -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var label := DamageNumber.new()
	label.text = _format(amount, style)
	label.modulate = _color_for(style)
	label.font_size = 80 if style == "critical" else 64
	label.outline_size = 18
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.006

	parent.get_tree().current_scene.add_child(label)
	var jitter := Vector3(randf_range(-SPREAD, SPREAD), 0.0, randf_range(-SPREAD, SPREAD))
	label.global_position = world_position + jitter

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + RISE_HEIGHT, LIFETIME)
	tween.tween_property(label, "modulate:a", 0.0, LIFETIME).set_delay(LIFETIME * 0.4)
	tween.chain().tween_callback(label.queue_free)


static func _format(amount: float, style: String) -> String:
	match style:
		"miss":
			return "หลบ"
		"heal":
			return "+%d" % roundi(amount)
		"status":
			return "!"
		"critical":
			return "%d!" % roundi(amount)
		_:
			return str(roundi(amount))


static func _color_for(style: String) -> Color:
	match style:
		"critical":
			return COLOR_CRITICAL
		"skill":
			return COLOR_SKILL
		"heal":
			return COLOR_HEAL
		"status":
			return COLOR_STATUS
		"miss":
			return COLOR_MISS
		_:
			return COLOR_NORMAL


## ข้อความสั้น ๆ แทนตัวเลข เช่น ชื่อสถานะที่เพิ่งติด
static func spawn_text(parent: Node3D, world_position: Vector3, text: String, style: String = "status") -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var label := DamageNumber.new()
	label.text = text
	label.modulate = _color_for(style)
	label.font_size = 52
	label.outline_size = 16
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.006

	parent.get_tree().current_scene.add_child(label)
	label.global_position = world_position

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + RISE_HEIGHT * 0.8, LIFETIME)
	tween.tween_property(label, "modulate:a", 0.0, LIFETIME).set_delay(LIFETIME * 0.4)
	tween.chain().tween_callback(label.queue_free)
