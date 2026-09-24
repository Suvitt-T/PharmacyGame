class_name SkillBurst
extends MeshInstance3D

## วงแหวนที่ขยายออกแล้วจางหาย บอกขอบเขตจริงของสกิลลงพื้นที่
## ทำให้ผู้เล่นเห็นว่าสกิลกินรัศมีเท่าไหร่ ไม่ต้องเดาจากตัวเลขในคำบรรยาย

const DURATION := 0.45

const COLOR_OFFENSIVE := Color(1.0, 0.55, 0.30, 0.55)
const COLOR_SUPPORT := Color(0.50, 0.90, 0.65, 0.50)
const COLOR_CONTROL := Color(0.65, 0.55, 1.00, 0.55)


static func spawn(origin: Node3D, radius: float, style: String = "offensive") -> void:
	if origin == null or not origin.is_inside_tree() or radius <= 0.0:
		return

	var ring := SkillBurst.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.08
	cylinder.radial_segments = 32
	ring.mesh = cylinder

	var material := StandardMaterial3D.new()
	material.albedo_color = _color_for(style)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = material

	origin.get_tree().current_scene.add_child(ring)
	ring.global_position = origin.global_position + Vector3.UP * 0.1
	ring.scale = Vector3(0.15, 1.0, 0.15)

	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(1.0, 1.0, 1.0), DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, DURATION)
	tween.chain().tween_callback(ring.queue_free)


static func _color_for(style: String) -> Color:
	match style:
		"support":
			return COLOR_SUPPORT
		"control":
			return COLOR_CONTROL
		_:
			return COLOR_OFFENSIVE


## เส้นชี้จากผู้ใช้ไปยังเป้าหมายเดี่ยว ใช้กับสกิลที่ไม่ได้กินพื้นที่
static func spawn_line(from: Node3D, to: Node3D, style: String = "offensive") -> void:
	if from == null or to == null or not from.is_inside_tree():
		return
	var start := from.global_position + Vector3.UP
	var end := to.global_position + Vector3.UP
	var span := end - start
	if span.length() < 0.05:
		return

	var beam := SkillBurst.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.14, span.length())
	beam.mesh = box

	var material := StandardMaterial3D.new()
	material.albedo_color = _color_for(style)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = material

	from.get_tree().current_scene.add_child(beam)
	beam.global_position = start + span * 0.5
	beam.look_at(end, Vector3.UP)

	var tween := beam.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, DURATION * 0.7)
	tween.tween_callback(beam.queue_free)
