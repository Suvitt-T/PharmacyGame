class_name CorruptionAura
extends Area3D

## รัศมีปนเปื้อนรอบตัวศัตรู ตามหัวข้อ "Corruption Aura" ในเอกสาร
## เข้าใกล้ 3m ติด Blight DOT 5 ดาเมจ/วิ นาน 4 วิ ล้างได้ด้วย "คลายพิษ" หรือยาแก้พิษทั่วไป
##
## นี่คือจุดที่ทำให้ระบบเภสัชกรรมมีบทบาทในการต่อสู้ทั่วไป ไม่ใช่แค่ตอนบอส

const RADIUS := 3.0
const DAMAGE_PER_SECOND := 5.0
const DURATION := 4.0
const STATUS := "blight"

## เว้นจังหวะก่อนต่อสถานะใหม่ ไม่งั้นยืนในวงแล้วเวลาจะค้างที่ 4 วิตลอด
const REFRESH_INTERVAL := 1.0

var _inside: Array[Metabolism] = []
var _refresh_timer := 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	add_child(shape)
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _inside.is_empty():
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = REFRESH_INTERVAL
	for metabolism in _inside:
		if is_instance_valid(metabolism):
			metabolism.apply_status(STATUS, DURATION)


func _on_body_entered(body: Node3D) -> void:
	var metabolism := body.get_node_or_null("Metabolism") as Metabolism
	if metabolism == null or _inside.has(metabolism):
		return
	_inside.append(metabolism)
	metabolism.apply_status(STATUS, DURATION)
	_refresh_timer = REFRESH_INTERVAL


func _on_body_exited(body: Node3D) -> void:
	var metabolism := body.get_node_or_null("Metabolism") as Metabolism
	if metabolism != null:
		_inside.erase(metabolism)


## สร้าง Aura แล้วผูกเข้ากับ actor ตั้ง mask ให้จับเฉพาะผู้เล่น
static func attach_to(actor: Node3D) -> CorruptionAura:
	var aura := CorruptionAura.new()
	aura.name = "CorruptionAura"
	aura.collision_layer = 0
	aura.collision_mask = 2
	actor.add_child(aura)
	return aura
